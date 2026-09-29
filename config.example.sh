#!/bin/bash
# shellcheck disable=SC2034  # variables are consumed by the scripts that source this file
# Whisper Radio configuration. This file is *sourced* by every script, so it
# must only set variables: no `set -e`, no commands that hit the network.
# (playlist.sh sources it once per track.)

# Project root defaults to the directory this file lives in.
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

TEXT_DIR="${PROJECT_ROOT}/text"       # Directory containing text files to read
MOTD_FILE="${PROJECT_ROOT}/motd.txt"  # Message that is read every batch
AUDIO_DIR="${PROJECT_ROOT}/audio"     # Directory with music files (symlinks are fine)
OUTPUT_DIR="${PROJECT_ROOT}/output"   # Where finished batches are written
CURSOR_FILE="${PROJECT_ROOT}/cursor"  # Absolute path of the track currently playing
LOCK_FILE="${PROJECT_ROOT}/playlist.lock"       # flock target for playlist.sh
RUN_LOCK_FILE="${PROJECT_ROOT}/whisper.lock"    # flock target for whisper.sh (cron overlap guard)
TEMP_DIR="${TMPDIR:-/tmp}/whisper-radio"        # Scratch space for downloads

# ezstream supervision
EZSTREAM_CONFIG="${PROJECT_ROOT}/ezstream.xml"
EZSTREAM_PIDFILE="${PROJECT_ROOT}/ezstream.pid"
EZSTREAM_LOG="${PROJECT_ROOT}/ezstream.log"

# Content sources
METAR_STATION="NZSP"
FOSSTODON_TAG="whisperradio"          # Posts with this tag get an AI reply on air
GOPHERPAGE="gopher://gopher.someodd.zip/1/phorum"

# OpenAI (used by get_fosstodon_response.sh). Keep this file chmod 600.
OPENAI_API_KEY="sk-1234567890abcdef1234567890abcdef"
OPENAI_MODEL="gpt-3.5-turbo"

# TTS
CTTS_PATH="${PROJECT_ROOT}/ctts.py"
PIPER_PATH="${HOME}/.local/bin/piper"
