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

if ! pgrep -f "$EZSTREAM_CMD" > /dev/null; then
    echo "EZStream is not running. Starting EZStream..."
    # Kill any zombie processes first
    pkill -f "$EZSTREAM_CMD" 2>/dev/null || true
    # Start with nohup
    nohup $EZSTREAM_CMD &>/dev/null &
    echo "EZStream started with PID $(pgrep -f "$EZSTREAM_CMD")"
else
    # Verify it's actually working by checking if the process is responding
    if kill -0 $(pgrep -f "$EZSTREAM_CMD") 2>/dev/null; then
        echo "EZStream is running and responsive."
    else
        echo "EZStream process exists but may be stuck. Restarting..."
        pkill -f "$EZSTREAM_CMD" 2>/dev/null || true
        nohup $EZSTREAM_CMD &>/dev/null &
        echo "EZStream restarted with PID $(pgrep -f "$EZSTREAM_CMD")"
    fi
fi
