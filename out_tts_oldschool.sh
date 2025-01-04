#!/usr/bin/env bash

# Usage:
#   script.sh output_filename
#   echo "some text here" | script.sh output_filename
#
# This reads all of stdin into 'input_text' and generates an MP3 file named
# 'output_filename.mp3' in the BATCH_DIR.

# Stop on error
set -e

# 1) Check for required argument (output file name)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <output_filename>"
  exit 1
fi

# 2) Setup configuration for espeak and ffmpeg
ESPEAK_VOICE="en-us+whisper"     # Voice setting for espeak
ESPEAK_VOLUME="200"              # Volume setting for espeak (0-200)
ESPEAK_SPEED="130"               # Speed setting for espeak (80-500)
ESPEAK_COMMAND="espeak -v $ESPEAK_VOICE -a $ESPEAK_VOLUME -s $ESPEAK_SPEED"

FFMPEG_AUDIO_SAMPLING_RATE="22050"
FFMPEG_AUDIO_CHANNELS="1"
FFMPEG_AUDIO_BITRATE="64k"

# 3) Read entire STDIN into a single variable
input_text=$(cat)

# 4) Use the output filename from the first argument
output_file="$1"

# 5) Generate MP3 from the text read from stdin
$ESPEAK_COMMAND "$input_text" --stdout | ffmpeg -i - \
  -ar "$FFMPEG_AUDIO_SAMPLING_RATE" \
  -ac "$FFMPEG_AUDIO_CHANNELS" \
  -ab "$FFMPEG_AUDIO_BITRATE" \
  -f mp3 "${output_file}.mp3"
