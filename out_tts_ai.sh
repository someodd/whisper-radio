#!/usr/bin/env bash

# Usage:
#   script.sh path_to_piper output_filename project_root
#   echo "some text here" | script.sh /bin/piper output_filename /home/tilde/Projects/whisper-radio/
#
# This reads all of stdin into 'input_text' and generates an MP3 file named
# 'output_filename.mp3' in the BATCH_DIR. It also looks for the model file in
# /home/tilde/Projects/whisper-radio/. It also uses the defined path to piper
# as the piper-tts binary.

# Stop on error
set -e

# 1) Check for required argument (piper binary path)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <piper_path>"
  exit 1
fi

# 2) Check for required argument (output file name)
if [[ -z "$2" ]]; then
  echo "Usage: $0 <output_filename>"
  exit 1
fi

# 3) Check for required argument (output file name)
if [[ -z "$3" ]]; then
  echo "Usage: $0 <project_root>"
  exit 1
fi


echo "piper tts"
input_text=$(cat)
piper_path="$1"
output_file="$2"
project_root="$3"
temp_wav="$(mktemp).wav" # Creates a temporary WAV file

# Use piper to generate the WAV file
echo "$input_text" | "${piper_path}" --model "${project_root}/en_US-hfc_female-medium.onnx" --sentence-silence 1.2 --output_file "$temp_wav"

# Use ffmpeg to convert the WAV file to an MP3 file
ffmpeg -i "$temp_wav" -ar 22050 -ac 1 -ab 64k -f mp3 "${output_file}.mp3"

# Delete the temporary WAV file
rm "$temp_wav"
