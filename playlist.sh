#!/bin/bash
#
# Prints the absolute path of the next file ezstream should play, and
# advances the cursor. Called by ezstream (intake type "program") before
# every track.
#
# Batches live in OUTPUT_DIR as directories named YYYYMMDDTHHMMSS. Only
# finished batches match that pattern; a batch under construction is named
# .build_* and is ignored here. Within a batch, files play in modification
# time order (the order they were generated).
#
# The cursor file holds the absolute path of the track being played. If the
# cursor is missing, empty, or points outside OUTPUT_DIR / at a file that no
# longer exists, it is reset to the first track of the newest batch instead
# of spiralling into arbitrary files.
#
# Printing an empty line makes ezstream call this script again immediately,
# in a tight loop. So when there is nothing to play we sleep first.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

: "${OUTPUT_DIR:=${SCRIPT_DIR}/output}"
: "${CURSOR_FILE:=${SCRIPT_DIR}/cursor}"
: "${LOCK_FILE:=${SCRIPT_DIR}/playlist.lock}"
OUTPUT_DIR="$(realpath -m "$OUTPUT_DIR")"

# Serialise concurrent callers. flock is released automatically when this
# process exits, however it exits, so a crash can never leave a stale lock.
exec 9>"$LOCK_FILE"
if ! flock -w 30 9; then
  echo "playlist: could not acquire lock $LOCK_FILE" >&2
  sleep 5
  exit 1
fi

BATCH_RE='^[0-9]{8}T[0-9]{6}$'

# Finished batch directories, oldest first (names sort chronologically).
list_batches() {
  [[ -d "$OUTPUT_DIR" ]] || return 0
  find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | grep -E "$BATCH_RE" | sort
}

# Playable files in a batch, oldest first.
list_tracks() {
  find "$1" -mindepth 1 -maxdepth 1 -type f -name '*.mp3' -size +0 -printf '%T@ %p\n' \
    | sort -n | cut -d' ' -f2-
}

first_track_of_newest_batch() {
  local b
  b="$(list_batches | tail -n 1)"
  [[ -n "$b" ]] || return 0
  list_tracks "${OUTPUT_DIR}/${b}" | head -n 1
}

cursor_is_valid() {
  local cur="$1" dir base
  [[ -n "$cur" && "$cur" == /* && -f "$cur" && "$cur" == *.mp3 ]] || return 1
  dir="$(dirname "$cur")"
  base="$(basename "$dir")"
  [[ "$(dirname "$dir")" == "$OUTPUT_DIR" && "$base" =~ $BATCH_RE ]]
}

next_track() {
  local cur="$1" dir batch next nb
  dir="$(dirname "$cur")"
  batch="$(basename "$dir")"

  # Next file in the same batch.
  next="$(list_tracks "$dir" | awk -v cur="$cur" 'found { print; exit } $0 == cur { found = 1 }')"
  if [[ -n "$next" ]]; then
    printf '%s\n' "$next"
    return
  fi

  # Otherwise the first file of the next batch, or loop the current one.
  nb="$(list_batches | awk -v b="$batch" 'found { print; exit } $0 == b { found = 1 }')"
  if [[ -n "$nb" ]]; then
    next="$(list_tracks "${OUTPUT_DIR}/${nb}" | head -n 1)"
  fi
  if [[ -z "$next" ]]; then
    next="$(list_tracks "$dir" | head -n 1)"
  fi
  printf '%s\n' "$next"
}

current=""
if [[ -f "$CURSOR_FILE" ]]; then
  current="$(head -n 1 "$CURSOR_FILE")"
fi

if cursor_is_valid "$current"; then
  next="$(next_track "$current")"
else
  [[ -z "$current" ]] || echo "playlist: cursor '$current' is invalid, resetting" >&2
  next="$(first_track_of_newest_batch)"
fi

if [[ -z "$next" ]]; then
  echo "playlist: nothing playable in $OUTPUT_DIR" >&2
  sleep 30
  exit 0
fi

printf '%s\n' "$next" > "${CURSOR_FILE}.tmp" && mv -f "${CURSOR_FILE}.tmp" "$CURSOR_FILE"
printf '%s\n' "$next"
