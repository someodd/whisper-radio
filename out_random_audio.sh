#!/usr/bin/env bash

# Usage:
#   out_random_audio.sh choose_directory output_directory file_tag

# Stop on error
set -e

# 1) Check for required argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <choose_directory>"
  exit 1
fi

# 2) Check for required argument
if [[ -z "$2" ]]; then
  echo "Usage: $0 <output_path>"
  exit 1
fi

# 2) Check for required argument
if [[ -z "$3" ]]; then
  echo "Usage: $0 <file_tag>"
  exit 1
fi

# Uses FFMPEG to ensure consistent sample rate and the sort, I guess.
#
# I could instead use mktemp.
AUDIO_DIR="$1"
BATCH_DIR="$2"
TAG="$3"
# Select a random song from the audio directory
RANDOM_SONG=$(find "$AUDIO_DIR" -type f | shuf -n 1)

# Extract title and artist separately
TITLE=$(ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$RANDOM_SONG")
ARTIST=$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$RANDOM_SONG")

# Concatenate title and artist in the format "Title by Artist"
METADATA="${TITLE} by ${ARTIST}"

# Prepare a file list for ffmpeg concat demuxer
FILE_LIST_PATH="${BATCH_DIR}/file_list.txt"

# If metadata is found, use espeak to convert the metadata to speech
if [ -n "$TITLE" ]; then
    echo "Welcome to the audio segment of the program. Now let's play: $METADATA" | ./out_tts_oldschool.sh "${BATCH_DIR}/metadata"

    # Create a file list for concatenation
    echo "file '${BATCH_DIR}/metadata.mp3'" > "$FILE_LIST_PATH"
    echo "file '$RANDOM_SONG'" >> "$FILE_LIST_PATH"

    # Concatenate the speech audio file with the song file using the file list
    ffmpeg -f concat -safe 0 -i "$FILE_LIST_PATH" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_song_${TAG}.mp3"

    # Clean up the temporary files
    rm "${BATCH_DIR}/metadata.mp3" "$FILE_LIST_PATH"
else
    # If no metadata is found, just output the song file
    ffmpeg -i "$RANDOM_SONG" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_song_${TAG}.mp3"
fi
