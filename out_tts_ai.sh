#!/usr/bin/env bash
# Usage:
#   script.sh path_to_ctts.py output_filename project_root
#   echo "some text here" | script.sh ./ctts.py output_filename /home/tilde/Projects/whisper-radio/

set -e

# 1) Check for required argument (ctts.py path)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>"
  exit 1
fi

# 2) Output filename (no extension)
if [[ -z "$2" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>"
  exit 1
fi

# 3) Project root (contains speaker.wav)
if [[ -z "$3" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>"
  exit 1
fi

ctts_path="$1"
output_file="$2"
project_root="$3"

speaker_wav="${project_root}/speaker.wav"
if [[ ! -f "$speaker_wav" ]]; then
  echo "Missing speaker.wav in $project_root"
  exit 1
fi

# Read all stdin as the text
input_text=$(cat)

# Temp wav path
temp_wav="$(mktemp).wav"

echo "XTTS voice clone..."

# Generate speech using ctts.py
"$project_root/tts/bin/python" "$ctts_path" "$input_text" "$temp_wav" "$speaker_wav"

# Convert to MP3 (same settings as before)
ffmpeg -y -i "$temp_wav" -ar 22050 -ac 1 -ab 64k -f mp3 "${output_file}.mp3"

rm "$temp_wav"

echo "Wrote ${output_file}.mp3"

