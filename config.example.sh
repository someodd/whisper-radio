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
LOCK_FILE="${PROJECT_ROOT}/playlist.lock"
OPENAI_API_KEY="sk-1234567890abcdef1234567890abcdef" # OpenAI API key
FOSSTODON_TAG="whisperradio" # This is what gets replied to
GOPHERPAGE="gopher://gopher.someodd.zip:70/phorum"

CTTS_PATH="${PROJECT_ROOT/ctts.py"
