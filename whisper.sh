#!/bin/bash
#
# Builds one radio "batch" (a directory of mp3 segments) and keeps ezstream
# running. Meant to be run hourly from cron:
#
#   0 * * * * /path/to/whisper-radio/whisper.sh >> /path/to/whisper-radio/logfile 2>&1
#
# Design notes
# - A failing segment is logged and skipped; it never aborts the batch, and
#   ezstream is always checked at the end.
# - The batch is built in a hidden staging directory and renamed into place
#   only when complete, so playlist.sh never picks up half-written files.
# - An flock on RUN_LOCK_FILE stops overlapping cron runs (a slow XTTS run or
#   a stalled download must not pile up hourly).

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"
set +e  # config.sh used to set -e; make sure it stays off here.

: "${PROJECT_ROOT:=$SCRIPT_DIR}"
: "${OUTPUT_DIR:=${PROJECT_ROOT}/output}"
: "${TEMP_DIR:=${TMPDIR:-/tmp}/whisper-radio}"
: "${RUN_LOCK_FILE:=${PROJECT_ROOT}/whisper.lock}"
: "${METAR_STATION:=NZSP}"
: "${GOPHERPAGE:=gopher://gopher.someodd.zip/1/phorum}"
: "${OPENAI_API_KEY:=}"
: "${OPENAI_MODEL:=gpt-3.5-turbo}"
export OPENAI_API_KEY OPENAI_MODEL

cd "${PROJECT_ROOT}" || { echo "[whisper] cannot cd to ${PROJECT_ROOT}" >&2; exit 1; }
mkdir -p "$TEMP_DIR"

log() { echo "[whisper] $(date '+%F %T') $*" >&2; }

# --- overlap guard ----------------------------------------------------------
exec 8>"$RUN_LOCK_FILE"
if ! flock -n 8; then
  log "another whisper.sh is still running; skipping batch generation"
  ./manage_ezstream.sh "${PROJECT_ROOT}"
  exit 0
fi

log "starting batch generation"

# Make sure the stream is up before spending minutes generating audio.
./manage_ezstream.sh "${PROJECT_ROOT}"

# --- staging directory ------------------------------------------------------
STAGING_DIR="$(./manage_output_dir.sh "$OUTPUT_DIR" | tail -n 1)"
if [[ -z "$STAGING_DIR" || ! -d "$STAGING_DIR" || ! -w "$STAGING_DIR" ]]; then
  log "no usable staging directory (got '${STAGING_DIR}')"
  exit 1
fi
log "building in $STAGING_DIR"

# Only one whisper.sh runs at a time (flock above), so an unfinished staging
# directory can be removed if we die mid-way.
cleanup() { [[ -d "$STAGING_DIR" ]] && rm -rf -- "$STAGING_DIR"; }
trap cleanup EXIT

# Run a segment; log failures instead of aborting.
segment() {
  local name="$1"; shift
  log "segment: $name"
  if ! "$@"; then
    log "segment FAILED (ignored): $name"
  fi
}

# Helpers so a pipeline can be passed to segment() as a single command.
tts_fast() { "$1" | ./out_tts_ai_fast.sh "${PIPER_PATH}" "$2" "${PROJECT_ROOT}"; }
tts_old()  { "$1" | ./out_tts_oldschool.sh "$2"; }
motd()     { cat "${MOTD_FILE}"; }
horace()   { ./get_fosstodon_response.sh "$FOSSTODON_TAG"; }
weather()  { ./get_weather.sh "$METAR_STATION"; }
gopher()   { ./get_gopher_heading.sh "$GOPHERPAGE"; }
randtext() { ./choose_random_text_file.sh "${TEXT_DIR}"; }
dnb()      { ./out_ia_dnb.sh "$TEMP_DIR" "${STAGING_DIR}" "$1"; }
horace_tts() { horace | ./out_tts_ai_slow.sh "${CTTS_PATH}" "${STAGING_DIR}/respond_to_latest_fosstodon" "${PROJECT_ROOT}"; }

segment motd            tts_old  motd "${STAGING_DIR}/motd"
segment horace          horace_tts
segment dnb00           dnb iadnb00
segment dnb01           dnb iadnb01
segment fosstodon       tts_fast ./get_fosstodon.sh "${STAGING_DIR}/fosstodon"
segment dnb02           dnb iadnb02
segment dnb03           dnb iadnb03
segment news            tts_fast ./get_news.sh "${STAGING_DIR}/news"
segment weather         tts_old  weather "${STAGING_DIR}/weather"
segment dnb04           dnb iadnb04
segment dnb05           dnb iadnb05
segment gopher          tts_fast gopher "${STAGING_DIR}/gopher"
segment dnb06           dnb iadnb06
segment dnb07           dnb iadnb07
segment interlog        tts_fast ./get_interlog.sh "${STAGING_DIR}/interlog"
segment dnb_il0         dnb iadnb_il0
segment dnb_il1         dnb iadnb_il1
segment bartleby        tts_fast ./get_bartleby.sh "${STAGING_DIR}/bartleby"
segment dnb_bt0         dnb iadnb_bt0
segment dnb_bt1         dnb iadnb_bt1
segment random_text     tts_fast randtext "${STAGING_DIR}/random_text_file"
segment dnb08           dnb iadnb08
segment dnb09           dnb iadnb09
segment random_audio    ./out_random_audio.sh "${AUDIO_DIR}" "${STAGING_DIR}" "one"

# --- publish the batch ------------------------------------------------------
# Drop anything that is not a real mp3 (leftover temp files), then rename the
# staging directory to its final name so playlist.sh can see it.
find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type f ! -name '*.mp3' -delete
find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.mp3' -size 0 -delete

track_count="$(find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.mp3' | wc -l)"
if [[ "$track_count" -eq 0 ]]; then
  log "batch produced no audio; discarding"
  exit 1
fi

BATCH_DIR="${OUTPUT_DIR}/$(basename "$STAGING_DIR" | sed 's/^\.build_//')"
if mv -- "$STAGING_DIR" "$BATCH_DIR"; then
  log "published $BATCH_DIR with $track_count tracks"
else
  log "failed to publish batch"
  exit 1
fi
trap - EXIT

# Prune old scratch downloads and XTTS cache (bounded disk/tmpfs use).
find "$TEMP_DIR" -type f -mtime +2 -delete 2>/dev/null
find "${TMPDIR:-/tmp}" -maxdepth 1 -type f -name 'ctts_*.wav' -mtime +7 -delete 2>/dev/null

./manage_ezstream.sh "${PROJECT_ROOT}"
log "done"
