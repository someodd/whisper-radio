#!/usr/bin/env bash

# Usage:
#   manage_ezstream.sh ezstream_config_directory

# Stop on error
set -e

# 1) Check for required argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <ezstream_config_directory>"
  exit 1
fi

PROJECT_ROOT="$1"

# Function to manage EZStream based on playlist comparison
#
# Basically, two things can happen:
# 1. If EZStream is not running, start it.
# 2. If the main and pending playlists are different, reload EZStream
# Not escaping/handling the path safely, but it wasn't working with two other methods I tried, I think FIXME
EZSTREAM_CMD="ezstream -c ${PROJECT_ROOT}/ezstream.xml"

# Check if EZStream is running. It should always be running.
if ! pgrep -f "$EZSTREAM_CMD" > /dev/null; then
    echo "EZStream is not running. Starting EZStream..."
    nohup $EZSTREAM_CMD &>/dev/null &
else 
    echo "EZStream is already running."
fi