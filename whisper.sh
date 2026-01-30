#!/bin/bash

# Builds the radio program to a batch directory and manages the ezstream process.

# Safer bash defaults for scripts with pipes
set -Eeuo pipefail
IFS=$'\n\t'

# --- helpers ---------------------------------------------------------------

trim() {
  # trim leading/trailing whitespace
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

clean_path() {
  # keep only the last line, collapse // (not after a URL scheme), drop trailing slash
  local p="$1"
  p="${p##*$'\n'}"
  p="$(trim "$p")"
  p="$(printf '%s' "$p" | sed -E 's#(^|[^:])/+#\1/#g')"
  p="${p%/}"
  printf '%s' "$p"
}

safe_base() {
  # (optional) ensure filename-safe basename if you ever pass dynamic names
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

# --------------------------------------------------------------------------

# Get the script's own directory
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# Source the configuration
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

# For cron, mostly
echo "$(date)"

# Use project root
cd "${PROJECT_ROOT}"

# Build/choose batch dir:
# - capture ALL stdout from manage_output_dir.sh, but only keep the LAST LINE for BATCH_DIR
# - let its logs go to stderr (kept visible)
BATCH_DIR_RAW="$(./manage_output_dir.sh "$OUTPUT_DIR" 2> >(sed 's/^/[manage_output_dir] /' >&2) | cat)"
BATCH_DIR="$(clean_path "$BATCH_DIR_RAW")"

# Ensure it exists and is writable
mkdir -p -- "$BATCH_DIR"
if [[ ! -w "$BATCH_DIR" ]]; then
  echo "Batch dir not writable: $BATCH_DIR" >&2
  exit 1
fi

# Log for sanity
echo "[whisper] Using batch dir: $BATCH_DIR" >&2

# If you ever generate dynamic basenames, sanitize like:
# NAME="$(safe_base "respond_to_latest_fosstodon")"
# but your current fixed basenames are already safe.

# Pipelines (unchanged), now with a clean $BATCH_DIR

cat "${MOTD_FILE}" \
  | ./out_tts_oldschool.sh "${BATCH_DIR}/motd"

./get_fosstodon_response.sh "$FOSSTODON_TAG" "$OPENAI_API_KEY" \
  | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/respond_to_latest_fosstodon" "${PROJECT_ROOT}"

./get_fosstodon.sh \
  | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/fosstodon" "${PROJECT_ROOT}"

./get_news.sh \
  | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/news" "${PROJECT_ROOT}"

./get_weather.sh "NZSP" \
  | ./out_tts_oldschool.sh "${BATCH_DIR}/weather"

./get_gopher_heading.sh "gopher://gopher.someodd.zip/1/phorum" \
  | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/gopher" "${PROJECT_ROOT}"

./choose_random_text_file.sh "${TEXT_DIR}" \
  | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/random_text_file" "${PROJECT_ROOT}"

./out_random_audio.sh "${AUDIO_DIR}" "${BATCH_DIR}" "one"

# Select a random  DnB song from Internet Archive
./out_ia_dnb.sh "/tmp" "${BATCH_DIR}" "iadnb1"
./out_ia_dnb.sh "/tmp" "${BATCH_DIR}" "iadnb2"
./out_ia_dnb.sh "/tmp" "${BATCH_DIR}" "iadnb2"
./out_ia_dnb.sh "/tmp" "${BATCH_DIR}" "iadnb2"

./manage_ezstream.sh "${PROJECT_ROOT}"

