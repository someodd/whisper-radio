#!/bin/bash

# Stop on error
set -e

# Do not have any spaces, also escape special characters!
PROJECT_ROOT="/path/to/whisper-radio"
TEXT_DIR="${PROJECT_ROOT}/text" # Default directory containing text files
MOTD_FILE="${PROJECT_ROOT}/motd.txt" # Path to your MOTD file
WEATHER_COMMAND=$(metar -d NZSP | tail -n +2)
AUDIO_DIR="${PROJECT_ROOT}/audio" # Default directory with MP3 files for music
OUTPUT_DIR="${PROJECT_ROOT}/output" # Output directory. I feel like it should go in /tmp or something.

MAIN_PLAYLIST="${PROJECT_ROOT}/playlist-main.m3u"
PENDING_PLAYLIST="${PROJECT_ROOT}/playlist-pending.m3u"