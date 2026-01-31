#!/usr/bin/env bash
# out_ia_dnb.sh
#
# Usage:
#   ./out_ia_dnb.sh <temp_download_dir> <output_dir> <file_tag>
#
# Produces:
#   <output_dir>/random_ia_dnb_song_<file_tag>.mp3
#
# Notes:
# - Works with arbitrary .mp3 or .ogg files from Internet Archive.
# - No ia_file_list.txt (uses concat FILTER, not concat DEMUXER).
# - Adds BOTH an intro and an outro TTS announcement.

set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
  echo "Usage: $0 <temp_download_dir> <output_dir> <file_tag>"
  exit 1
fi

TEMP_DIR="$1"
BATCH_DIR="$2"
TAG="$3"

mkdir -p "$TEMP_DIR" "$BATCH_DIR"

# --- CONFIG ---
MAX_SIZE_MB=25
MIN_SIZE_MB=2
MAX_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
MIN_BYTES=$((MIN_SIZE_MB * 1024 * 1024))

SEARCH_QUERY='subject:("Drum & Bass") AND mediatype:audio AND date:[1990-01-01 TO 2005-12-31]'
# keep this conservative: avoid junky "sample/test/loop" items
SEARCH_QUERY="$SEARCH_QUERY AND NOT title:(sample OR loop OR test)"

TTS_SCRIPT="./out_tts_oldschool.sh"
if [[ ! -x "$TTS_SCRIPT" ]]; then
  echo "TTS script not found or not executable: $TTS_SCRIPT"
  exit 1
fi

echo "Searching Internet Archive for retro DnB..."

ID_LIST="$(curl -sL "https://archive.org/advancedsearch.php?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$SEARCH_QUERY'''))")&fl[]=identifier&rows=300&output=json" \
  | jq -r '.response.docs[].identifier' 2>/dev/null || true)"

if [[ -z "$ID_LIST" ]]; then
  echo "No IA identifiers returned (network/jq/search issue)."
  exit 1
fi

TARGET_FILE=""
RANDOM_ID=""

# Loop until we find an item that has at least one suitable audio file
while [[ -z "$TARGET_FILE" || "$TARGET_FILE" == "null" ]]; do
  RANDOM_ID="$(echo "$ID_LIST" | shuf -n 1)"

  FILES_JSON="$(curl -sL "https://archive.org/metadata/$RANDOM_ID/files" || true)"
  if [[ -z "$FILES_JSON" ]]; then
    ID_LIST="$(echo "$ID_LIST" | grep -v "^$RANDOM_ID$" || true)"
    continue
  fi

  # Collect candidates, then choose randomly
  CANDIDATES="$(echo "$FILES_JSON" | jq -r --arg max "$MAX_BYTES" --arg min "$MIN_BYTES" '
    .result[]?
    | select(.name | (endswith(".mp3") or endswith(".ogg")))
    | select((.size | tonumber? // 0) <= ($max | tonumber) and (.size | tonumber? // 0) >= ($min | tonumber))
    | .name' || true)"

  TARGET_FILE="$(echo "$CANDIDATES" | shuf -n 1 || true)"

  # If no file worked, remove this ID and try again
  if [[ -z "$TARGET_FILE" || "$TARGET_FILE" == "null" ]]; then
    ID_LIST="$(echo "$ID_LIST" | grep -v "^$RANDOM_ID$" || true)"
  fi

  if [[ -z "$ID_LIST" ]]; then
    echo "Exhausted search results without finding a suitable file."
    exit 1
  fi
done

ENCODED_FILE="$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$TARGET_FILE'''))")"
SAFE_FILENAME="$(echo "$TARGET_FILE" | tr '/' '_')"
DOWNLOAD_PATH="${TEMP_DIR}/${RANDOM_ID}_${SAFE_FILENAME}"

echo "Fetching: $RANDOM_ID / $TARGET_FILE"
curl -sL -o "$DOWNLOAD_PATH" "https://archive.org/download/$RANDOM_ID/$ENCODED_FILE"

if [[ ! -s "$DOWNLOAD_PATH" ]]; then
  echo "Download failed or empty file: $DOWNLOAD_PATH"
  rm -f "$DOWNLOAD_PATH"
  exit 1
fi

# --- Extract metadata (best-effort) ---
TITLE="$(ffprobe -loglevel error -show_entries format_tags=title  -of default=noprint_wrappers=1:nokey=1 "$DOWNLOAD_PATH" || true)"
ARTIST="$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$DOWNLOAD_PATH" || true)"

# Fall back to filename
if [[ -z "$TITLE" ]]; then
  TITLE="$(basename "$TARGET_FILE" | sed 's/\.[^.]*$//')"
fi
if [[ -z "$ARTIST" ]]; then
  ARTIST="Unknown Artist"
fi

METADATA="${TITLE} by ${ARTIST}"

# --- TTS intro ---
INTRO_BASE="${BATCH_DIR}/ia_intro_${TAG}"
INTRO_MP3="${INTRO_BASE}.mp3"

echo "Randomly discovered from the Internet Archive. This is retro drum and bass. Now playing: $METADATA." \
  | "$TTS_SCRIPT" "$INTRO_BASE"

if [[ ! -f "$INTRO_MP3" ]]; then
  echo "Expected intro mp3 not found: $INTRO_MP3"
  rm -f "$DOWNLOAD_PATH"
  exit 1
fi

# --- TTS outro ---
OUTRO_BASE="${BATCH_DIR}/ia_outro_${TAG}"
OUTRO_MP3="${OUTRO_BASE}.mp3"

echo "That was $METADATA. Randomly selected from the Internet Archive, under drum and bass from the nineteen nineties and early two thousands." \
  | "$TTS_SCRIPT" "$OUTRO_BASE"

if [[ ! -f "$OUTRO_MP3" ]]; then
  echo "Expected outro mp3 not found: $OUTRO_MP3"
  rm -f "$INTRO_MP3" "$DOWNLOAD_PATH"
  exit 1
fi

# --- Combine intro + song + outro robustly (works for mp3 or ogg) ---
OUT_FILE="${BATCH_DIR}/random_ia_dnb_song_${TAG}.mp3"

ffmpeg -y \
  -i "$INTRO_MP3" \
  -i "$DOWNLOAD_PATH" \
  -i "$OUTRO_MP3" \
  -filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[a]" \
  -map "[a]" \
  -ar 22050 -ac 1 -b:a 64k \
  -f mp3 "$OUT_FILE" \
  -loglevel error

# --- Cleanup ---
rm -f "$INTRO_MP3" "$OUTRO_MP3" "$DOWNLOAD_PATH"

echo "------------------------------------------"
echo "Segment ${TAG} complete:"
echo "  $OUT_FILE"

