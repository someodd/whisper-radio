#!/usr/bin/env bash
#
# Usage:
#   echo "some text here" | out_tts_ai_slow.sh /path/to/ctts.py output_filename project_root
#
# Voice-cloned XTTS speech (ctts.py) padded with silence and mixed over a
# looped bg.wav, written to 'output_filename.mp3'.

set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
  echo "Usage: $0 <ctts.py_path> <output_filename> <project_root>" >&2
  exit 1
fi

ctts_path="$1"
output_file="$2"
project_root="$3"

speaker_wav="${project_root}/speaker.wav"
bg_wav="${project_root}/bg.wav"
python_bin="${project_root}/tts/bin/python"

for f in "$speaker_wav" "$bg_wav" "$ctts_path"; do
  if [[ ! -f "$f" ]]; then
    echo "out_tts_ai_slow: missing $f" >&2
    exit 1
  fi
done
if [[ ! -x "$python_bin" ]]; then
  echo "out_tts_ai_slow: missing venv python at $python_bin (see ctts.py header)" >&2
  exit 1
fi

input_text="$(cat)"
if [[ -z "${input_text//[[:space:]]/}" ]]; then
  echo "out_tts_ai_slow: no text on stdin, nothing to say" >&2
  exit 1
fi

temp_speech_wav="$(mktemp --suffix=.wav)"
temp_padded_speech_wav="$(mktemp --suffix=.wav)"
temp_bg_looped_wav="$(mktemp --suffix=.wav)"
trap 'rm -f "$temp_speech_wav" "$temp_padded_speech_wav" "$temp_bg_looped_wav"' EXIT

echo "XTTS voice clone -> ${output_file}.mp3" >&2

# Coqui's first-run licence prompt reads stdin; under cron that raises
# EOFError and kills the run. Agree up front.
export COQUI_TOS_AGREED=1
# XTTS on CPU (the OOM fallback) can be very slow; cap it so one bad hour
# cannot stall the schedule for the rest of the day.
timeout 45m "$python_bin" "$ctts_path" "$input_text" "$temp_speech_wav" "$speaker_wav"

# Pad speech with 2 seconds of silence before and after.
ffmpeg -y -nostdin -hide_banner -loglevel error \
  -i "$temp_speech_wav" \
  -filter_complex "adelay=2000|2000,apad=pad_dur=2" \
  -t 36000 \
  "$temp_padded_speech_wav"

speech_dur="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$temp_padded_speech_wav")"

# Loop (or trim) bg.wav to exactly the padded speech duration.
ffmpeg -y -nostdin -hide_banner -loglevel error \
  -stream_loop -1 -i "$bg_wav" \
  -t "$speech_dur" \
  "$temp_bg_looped_wav"

# Mix: background at half volume under the speech.
ffmpeg -y -nostdin -hide_banner -loglevel error \
  -i "$temp_padded_speech_wav" \
  -i "$temp_bg_looped_wav" \
  -filter_complex "[1:a]volume=0.5[bg];[0:a][bg]amix=inputs=2:normalize=0[m]" \
  -map "[m]" \
  -ar 22050 -ac 1 -ab 64k -f mp3 \
  "${output_file}.mp3"

echo "Wrote ${output_file}.mp3" >&2
