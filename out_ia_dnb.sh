#!/usr/bin/env bash

# Usage:
#   out_ia_dnb.sh download_temp_dir output_directory file_tag

# Stop on error
set -e

# 1) Check for required arguments
if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "Usage: $0 <temp_download_dir> <output_dir> <file_tag>"
  exit 1
fi

TEMP_DIR="$1"
BATCH_DIR="$2"
TAG="$3"

# --- CONFIGURATION ---
MAX_SIZE_MB=25
MIN_SIZE_MB=2
SEARCH_QUERY='subject:("Drum & Bass") AND mediatype:audio AND date:[1990-01-01 TO 2005-12-31]'
SEARCH_QUERY="$SEARCH_QUERY AND NOT title:(sample OR loop OR test)"

MAX_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
MIN_BYTES=$((MIN_SIZE_MB * 1024 * 1024))

echo "Searching Internet Archive for retro DnB..."

# 2) Loop until a valid file is found
ID_LIST=$(curl -sL "https://archive.org/advancedsearch.php?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$SEARCH_QUERY'''))")&fl[]=identifier&rows=300&output=json" | jq -r '.response.docs[].identifier' 2>/dev/null)

TARGET_FILE=""
RANDOM_ID=""

while [ -z "$TARGET_FILE" ] || [ "$TARGET_FILE" == "null" ]; do
    RANDOM_ID=$(echo "$ID_LIST" | shuf -n 1)
    FILES_JSON=$(curl -sL "https://archive.org/metadata/$RANDOM_ID/files")

    TARGET_FILE=$(echo "$FILES_JSON" | jq -r --arg max "$MAX_BYTES" --arg min "$MIN_BYTES" '
        .result[]?
        | select(.name | endswith(".mp3") or endswith(".ogg"))
        | select(.format != "Metadata" and .format != "VBR MP3")
        | select((.size | tonumber? // 0) <= ($max | tonumber) and (.size | tonumber? // 0) >= ($min | tonumber))
        | .name' | head -n 1)

    if [ -z "$TARGET_FILE" ] || [ "$TARGET_FILE" == "null" ]; then
        ID_LIST=$(echo "$ID_LIST" | grep -v "^$RANDOM_ID$")
    fi
done

# 3) Download to temp directory
ENCODED_FILE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$TARGET_FILE'''))")
DOWNLOAD_PATH="${TEMP_DIR}/${RANDOM_ID}_${TARGET_FILE}"

echo "Fetching: $TARGET_FILE"
curl -sL -o "$DOWNLOAD_PATH" "https://archive.org/download/$RANDOM_ID/$ENCODED_FILE"

# 4) Metadata Extraction (Matching your radio system)
TITLE=$(ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$DOWNLOAD_PATH" || echo "")
ARTIST=$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$DOWNLOAD_PATH" || echo "")

# Fallback if ID3 tags are empty (common on Archive)
if [[ -z "$TITLE" ]]; then TITLE=$(echo "$TARGET_FILE" | sed 's/\.[^.]*$//'); fi
if [[ -z "$ARTIST" ]]; then ARTIST="Unknown Artist"; fi

METADATA="${TITLE} by ${ARTIST}"

# 5) TTS Announcement & Concatenation
FILE_LIST_PATH="${BATCH_DIR}/ia_file_list.txt"

echo "Randomly discovered from the Internet Archive... This is retro drum and bass. Now playing: $METADATA" | ./out_tts_oldschool.sh "${BATCH_DIR}/ia_metadata"

# Create concat list
echo "file '${BATCH_DIR}/ia_metadata.mp3'" > "$FILE_LIST_PATH"
echo "file '$DOWNLOAD_PATH'" >> "$FILE_LIST_PATH"

# Output final processed file to BATCH_DIR
ffmpeg -y -f concat -safe 0 -i "$FILE_LIST_PATH" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_ia_dnb_song_${TAG}.mp3"

# 6) Cleanup
rm "${BATCH_DIR}/ia_metadata.mp3" "$FILE_LIST_PATH" "$DOWNLOAD_PATH"

echo "------------------------------------------"
echo "Segment ${TAG} complete."
