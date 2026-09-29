#!/usr/bin/env bash
#
# Usage:
#   echo "some text here" | out_tts_ai_fast.sh /path/to/piper output_filename project_root
#
# Reads all of stdin and writes 'output_filename.mp3' using piper. The piper
# model (en_US-hfc_female-medium.onnx) is looked up in project_root.

set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
  echo "Usage: $0 <piper_path> <output_filename> <project_root>" >&2
  exit 1
fi

piper_path="$1"
output_file="$2"
project_root="$3"
model="${project_root}/en_US-hfc_female-medium.onnx"

if [[ ! -x "$piper_path" ]]; then
  echo "out_tts_ai_fast: piper not executable: $piper_path" >&2
  exit 1
fi
if [[ ! -f "$model" ]]; then
  echo "out_tts_ai_fast: model not found: $model" >&2
  exit 1
fi

input_text="$(cat)"
if [[ -z "${input_text//[[:space:]]/}" ]]; then
  echo "out_tts_ai_fast: no text on stdin, nothing to say" >&2
  exit 1
fi

temp_wav="$(mktemp --suffix=.wav)"
trap 'rm -f "$temp_wav"' EXIT

echo "piper tts -> ${output_file}.mp3" >&2
printf '%s\n' "$input_text" \
  | timeout 20m "${piper_path}" --model "$model" --sentence-silence 1.2 --output_file "$temp_wav"

ffmpeg -y -nostdin -hide_banner -loglevel error -i "$temp_wav" \
  -ar 22050 -ac 1 -ab 64k -f mp3 "${output_file}.mp3"
