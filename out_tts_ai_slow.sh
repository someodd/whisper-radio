#!/usr/bin/env bash
# Usage:
#   script.sh path_to_ctts.py output_filename project_root
#   echo "some text here" | script.sh ./ctts.py output_filename /home/tilde/Projects/whisper-radio/

set -euo pipefail

# 1) Check for required argument (ctts.py path)
if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>"
  exit 1
fi

# 2) Output filename (no extension)
if [[ -z "${2:-}" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>"
  exit 1
fi

# 3) Project root (contains speaker.wav and bg.wav)
if [[ -z "${3:-}" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>"
  exit 1
fi

ctts_path="$1"
output_file="$2"
project_root="$3"

speaker_wav="${project_root}/speaker.wav"
bg_wav="${project_root}/bg.wav"

if [[ ! -f "$speaker_wav" ]]; then
  echo "Missing speaker.wav in $project_root"
  exit 1
fi

if [[ ! -f "$bg_wav" ]]; then
  echo "Missing bg.wav in $project_root"
  exit 1
fi

# Read all stdin as the text
input_text=$(cat)

# Temp files
temp_speech_wav="$(mktemp).wav"
temp_padded_speech_wav="$(mktemp).wav"
temp_bg_looped_wav="$(mktemp).wav"

echo "XTTS voice clone..."

# Generate speech using ctts.py (writes WAV)
"$project_root/tts/bin/python" "$ctts_path" "$input_text" "$temp_speech_wav" "$speaker_wav"

# Pad speech with 2 seconds of silence before and after
# (apad pads end; we also add start pad via adelay)
ffmpeg -y -hide_banner -loglevel error \
  -i "$temp_speech_wav" \
  -filter_complex "adelay=2000|2000,apad=pad_dur=2" \
  -t 36000 \
  "$temp_padded_speech_wav"

# Get padded speech duration (seconds, float)
speech_dur="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$temp_padded_speech_wav")"

# Loop (or trim) bg.wav to EXACTLY match padded speech duration
# -stream_loop -1 loops indefinitely; -t trims to desired duration.
ffmpeg -y -hide_banner -loglevel error \
  -stream_loop -1 -i "$bg_wav" \
  -t "$speech_dur" \
  "$temp_bg_looped_wav"

# Mix:
# - BG at half volume of speech => -6 dB (volume=0.5)
# - Keep output clean: normalize off (we want stable levels), force mono + 22050 later
ffmpeg -y -hide_banner -loglevel error \
  -i "$temp_padded_speech_wav" \
  -i "$temp_bg_looped_wav" \
  -filter_complex "[1:a]volume=0.5[bg];[0:a][bg]amix=inputs=2:normalize=0[m]" \
  -map "[m]" \
  -ar 22050 -ac 1 -ab 64k -f mp3 \
  "${output_file}.mp3"

rm -f "$temp_speech_wav" "$temp_padded_speech_wav" "$temp_bg_looped_wav"

echo "Wrote ${output_file}.mp3"

