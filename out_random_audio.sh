#!/usr/bin/env bash
#
# Usage:
#   out_random_audio.sh <audio_directory> <output_directory> <file_tag>
#
# Picks a random file from audio_directory (symlinks are followed, so a
# directory of `ln -s` links works) and writes
# <output_directory>/random_song_<file_tag>.mp3, prefixed with a spoken
# "now playing" line when the file has a title tag.

set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
  echo "Usage: $0 <audio_directory> <output_directory> <file_tag>" >&2
  exit 1
fi

AUDIO_DIR="$1"
BATCH_DIR="$2"
TAG="$3"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_FILE="${BATCH_DIR}/random_song_${TAG}.mp3"

RANDOM_SONG="$(find -L "$AUDIO_DIR" -type f \( -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.opus' \) | shuf -n 1 || true)"
if [[ -z "$RANDOM_SONG" ]]; then
  echo "out_random_audio: no audio files found in $AUDIO_DIR" >&2
  exit 1
fi

TITLE="$(ffprobe -loglevel error -show_entries format_tags=title  -of default=noprint_wrappers=1:nokey=1 "$RANDOM_SONG" 2>/dev/null | head -n1 || true)"
ARTIST="$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$RANDOM_SONG" 2>/dev/null | head -n1 || true)"

if [[ -n "$TITLE" ]]; then
  METADATA="${TITLE} by ${ARTIST:-an unknown artist}"
  INTRO="${BATCH_DIR}/metadata_${TAG}.mp3"
  trap 'rm -f "$INTRO"' EXIT

  echo "Welcome to the audio segment of the program. Now let's play: $METADATA" \
    | "${SCRIPT_DIR}/out_tts_oldschool.sh" "${BATCH_DIR}/metadata_${TAG}"

  # The concat *filter* (not the demuxer) re-samples both inputs, so an
  # espeak mp3 and a 44.1 kHz stereo song join cleanly.
  ffmpeg -y -nostdin -hide_banner -loglevel error \
    -i "$INTRO" -i "$RANDOM_SONG" \
    -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1[a]" -map "[a]" \
    -ar 22050 -ac 1 -ab 64k -f mp3 "$OUT_FILE"
else
  ffmpeg -y -nostdin -hide_banner -loglevel error \
    -i "$RANDOM_SONG" -vn -ar 22050 -ac 1 -ab 64k -f mp3 "$OUT_FILE"
fi
