#!/usr/bin/env bash
#
# Usage:
#   echo "some text here" | out_tts_oldschool.sh output_filename
#
# Reads all of stdin and writes 'output_filename.mp3' using espeak.

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <output_filename>" >&2
  exit 1
fi

ESPEAK_VOICE="en-us+whisper"     # Voice setting for espeak
ESPEAK_VOLUME="200"              # Volume setting for espeak (0-200)
ESPEAK_SPEED="130"               # Speed setting for espeak (80-500)

FFMPEG_AUDIO_SAMPLING_RATE="22050"
FFMPEG_AUDIO_CHANNELS="1"
FFMPEG_AUDIO_BITRATE="64k"

input_text="$(cat)"
output_file="$1"

if [[ -z "${input_text//[[:space:]]/}" ]]; then
  echo "out_tts_oldschool: no text on stdin, nothing to say" >&2
  exit 1
fi

# --stdin keeps text out of argv (no length limit, no leading-dash issues).
printf '%s\n' "$input_text" \
  | espeak -v "$ESPEAK_VOICE" -a "$ESPEAK_VOLUME" -s "$ESPEAK_SPEED" --stdin --stdout \
  | ffmpeg -y -nostdin -hide_banner -loglevel error -i - \
      -ar "$FFMPEG_AUDIO_SAMPLING_RATE" \
      -ac "$FFMPEG_AUDIO_CHANNELS" \
      -ab "$FFMPEG_AUDIO_BITRATE" \
      -f mp3 "${output_file}.mp3"
