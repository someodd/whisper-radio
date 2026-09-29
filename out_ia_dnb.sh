#!/usr/bin/env bash
# out_ia_dnb.sh
#
# Usage:
#   ./out_ia_dnb.sh <temp_download_dir> <output_dir> <file_tag>
#
# Produces:
#   <output_dir>/random_ia_dnb_song_<file_tag>.mp3
#
# Picks a random 1990-2005 Drum & Bass recording from the Internet Archive
# and wraps it in an espeak intro and outro.
#
# Notes:
# - The search result (list of item identifiers) is cached in the temp dir
#   for a day; archive.org rate-limits aggressively and this script runs
#   many times per hour.
# - Every network call has a timeout, and HTTP errors are errors (curl -f),
#   so a 429 page never gets saved as an "mp3".

set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
  echo "Usage: $0 <temp_download_dir> <output_dir> <file_tag>" >&2
  exit 1
fi

TEMP_DIR="$1"
BATCH_DIR="$2"
TAG="$3"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$TEMP_DIR" "$BATCH_DIR"

# --- CONFIG ---
MAX_SIZE_MB=25
MIN_SIZE_MB=2
MAX_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
MIN_BYTES=$((MIN_SIZE_MB * 1024 * 1024))
MAX_ATTEMPTS=10
ID_CACHE="${TEMP_DIR}/ia_dnb_identifiers.txt"
ID_CACHE_MAX_AGE_MIN=1440

SEARCH_QUERY='subject:("Drum & Bass") AND mediatype:audio AND date:[1990-01-01 TO 2005-12-31]'
SEARCH_QUERY="$SEARCH_QUERY AND NOT title:(sample OR loop OR test)"

TTS_SCRIPT="${SCRIPT_DIR}/out_tts_oldschool.sh"
if [[ ! -x "$TTS_SCRIPT" ]]; then
  echo "TTS script not found or not executable: $TTS_SCRIPT" >&2
  exit 1
fi

CURL=(curl -fsSL --retry 2 --retry-delay 5 --max-time 60)

urlencode() { jq -rn --arg s "$1" '$s | @uri'; }
# Encode each path segment but keep the slashes.
urlencode_path() { jq -rn --arg s "$1" '$s | split("/") | map(@uri) | join("/")'; }

DOWNLOAD_PATH=""
INTRO_MP3="${BATCH_DIR}/ia_intro_${TAG}.mp3"
OUTRO_MP3="${BATCH_DIR}/ia_outro_${TAG}.mp3"
cleanup() { rm -f "$INTRO_MP3" "$OUTRO_MP3" "${DOWNLOAD_PATH:-}"; }
trap cleanup EXIT

# --- Identifier list (cached) ---
if [[ ! -s "$ID_CACHE" || -n "$(find "$ID_CACHE" -mmin "+${ID_CACHE_MAX_AGE_MIN}" 2>/dev/null)" ]]; then
  echo "Searching Internet Archive for retro DnB..." >&2
  search_url="https://archive.org/advancedsearch.php?q=$(urlencode "$SEARCH_QUERY")&fl[]=identifier&rows=300&output=json"
  if ids="$("${CURL[@]}" "$search_url" | jq -r '.response.docs[].identifier' 2>/dev/null)" && [[ -n "$ids" ]]; then
    printf '%s\n' "$ids" > "${ID_CACHE}.tmp" && mv -f "${ID_CACHE}.tmp" "$ID_CACHE"
  else
    echo "IA search failed; using stale cache if any" >&2
  fi
fi

if [[ ! -s "$ID_CACHE" ]]; then
  echo "No IA identifiers available (network/search issue)." >&2
  exit 1
fi

# --- Pick an item with a suitably sized audio file ---
TARGET_FILE=""
RANDOM_ID=""
attempt=0
while [[ -z "$TARGET_FILE" ]]; do
  attempt=$((attempt + 1))
  if (( attempt > MAX_ATTEMPTS )); then
    echo "Gave up after ${MAX_ATTEMPTS} attempts to find a suitable file." >&2
    exit 1
  fi

  RANDOM_ID="$(shuf -n 1 "$ID_CACHE")"
  [[ -n "$RANDOM_ID" ]] || continue

  FILES_JSON="$("${CURL[@]}" "https://archive.org/metadata/$(urlencode "$RANDOM_ID")/files" || true)"
  [[ -n "$FILES_JSON" ]] || continue

  CANDIDATES="$(jq -r --argjson max "$MAX_BYTES" --argjson min "$MIN_BYTES" '
    .result[]?
    | select(.name | (endswith(".mp3") or endswith(".ogg")))
    | select(((.size // "0") | tonumber? // 0) as $s | $s <= $max and $s >= $min)
    | .name' <<<"$FILES_JSON" 2>/dev/null || true)"

  TARGET_FILE="$(printf '%s\n' "$CANDIDATES" | grep -v '^$' | shuf -n 1 || true)"
done

SAFE_FILENAME="$(printf '%s' "$TARGET_FILE" | tr -c 'A-Za-z0-9._-' '_')"
DOWNLOAD_PATH="${TEMP_DIR}/${RANDOM_ID}_${SAFE_FILENAME}"

echo "Fetching: $RANDOM_ID / $TARGET_FILE" >&2
curl -fsSL --retry 2 --retry-delay 5 --max-time 900 \
  -o "$DOWNLOAD_PATH" "https://archive.org/download/$(urlencode "$RANDOM_ID")/$(urlencode_path "$TARGET_FILE")"

if [[ ! -s "$DOWNLOAD_PATH" ]]; then
  echo "Download failed or empty file: $DOWNLOAD_PATH" >&2
  exit 1
fi

# Make sure it really is audio before spending time on it.
if ! ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$DOWNLOAD_PATH" >/dev/null 2>&1; then
  echo "Downloaded file is not decodable audio: $DOWNLOAD_PATH" >&2
  exit 1
fi

# --- Extract metadata (best-effort) ---
TITLE="$(ffprobe -loglevel error -show_entries format_tags=title  -of default=noprint_wrappers=1:nokey=1 "$DOWNLOAD_PATH" 2>/dev/null | tr -d '\r' | head -n1 || true)"
ARTIST="$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$DOWNLOAD_PATH" 2>/dev/null | tr -d '\r' | head -n1 || true)"

if [[ -z "$TITLE" ]]; then
  TITLE="$(basename "$TARGET_FILE" | sed 's/\.[^.]*$//')"
fi
if [[ -z "$ARTIST" ]]; then
  ARTIST="Unknown Artist"
fi

METADATA="${TITLE} by ${ARTIST}"

# --- TTS intro / outro ---
echo "Randomly discovered from the Internet Archive. This is retro drum and bass. Now playing: $METADATA." \
  | "$TTS_SCRIPT" "${BATCH_DIR}/ia_intro_${TAG}"

echo "That was $METADATA. Randomly selected from the Internet Archive, under drum and bass from the nineteen nineties and early two thousands." \
  | "$TTS_SCRIPT" "${BATCH_DIR}/ia_outro_${TAG}"

# --- Combine intro + song + outro (works for mp3 or ogg) ---
OUT_FILE="${BATCH_DIR}/random_ia_dnb_song_${TAG}.mp3"

ffmpeg -y -nostdin -hide_banner -loglevel error \
  -i "$INTRO_MP3" \
  -i "$DOWNLOAD_PATH" \
  -i "$OUTRO_MP3" \
  -filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[a]" \
  -map "[a]" \
  -metadata title="$TITLE" \
  -metadata artist="$ARTIST" \
  -metadata album="Internet Archive" \
  -metadata comment="IA item: $RANDOM_ID / $TARGET_FILE" \
  -ar 22050 -ac 1 -b:a 64k \
  -id3v2_version 3 \
  -f mp3 "$OUT_FILE"

echo "Segment ${TAG} complete: $OUT_FILE" >&2
