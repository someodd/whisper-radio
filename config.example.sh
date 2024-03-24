#!/bin/bash

# Stop on error
set -e

PROJECT_ROOT="/home/tilde/Projects/whisper-radio/"
TEXT_DIR="${PROJECT_ROOT}/text" # Default directory containing text files
MOTD_FILE="${PROJECT_ROOT}/motd.txt" # Path to your MOTD file
WEATHER_COMMAND=$(metar -d NZSP | tail -n +2)
AUDIO_DIR="${PROJECT_ROOT}/audio" # Default directory with MP3 files for music
OUTPUT_DIR="${PROJECT_ROOT}/output" # Output directory. I feel like it should go in /tmp or something.
CURSOR_FILE="${PROJECT_ROOT}/cursor"