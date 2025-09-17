#!/bin/bash

# This script simply echoes the name of the file that should be played next.
#
# Looks through the batches jobs of the output directory while maintaining a "cursor."
#
# The batch jobs each get their own directory, containing all the files that were
# outputted. The directory is simply named after the timestamp of the batch job.
#
# The cursor contains the name of the directory batch job and the name of the file that is
# selected for playing. The cursor is updated every time this script is run.
#
# One-by-one this script will first output the oldest 
#
# The script which is cron'd to run the batch jobs will not generate a new batch job if
# the cursor is behind the latest batch job. This is to prevent generating too many batch
# jobs in the future, which the cursor may never catch up to.
#
#
# For example, the output directory may look like this:
#    output/
#    ├── 20250101T000000
#    │   ├── 0001.mp3
#    │   ├── 0002.mp3
#    │   └── 0003.mp3
#    ├── 20250101T010000
#    │   ├── 0001.mp3
#    │   ├── 0002.mp3
#    │   └── 0003.mp3
#


# Stop on error
set -e
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/config.sh"

# --- LOCKING ---
# Function to clean up the lock file
cleanup_lock() {
    rm -f "$LOCK_FILE"
}

# Trap signals to ensure the lock file is removed
trap cleanup_lock EXIT HUP INT TERM

# Wait for the lock file to be removed if it exists
while [ -f "$LOCK_FILE" ]; do
    sleep 1
done

# Create the lock file
touch "$LOCK_FILE"
# --- END LOCKING ---

# Directory where the batch jobs are stored
OUTPUT_DIR="output"

# Function to get the oldest directory
get_oldest_directory() {
    find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2-
}

# Function to get the oldest file in a directory
get_oldest_file() {
    find "$1" -type f -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2-
}

# Function to update the cursor
update_cursor() {
    # Check if the cursor file exists, if not, create it and write the path to the oldest file in the newest directory
    if [ ! -f "$CURSOR_FILE" ]; then
        # Find the newest directory
        NEWEST_DIRECTORY=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)
        # Find the oldest file in the newest directory
        OLDEST_FILE=$(find "$NEWEST_DIRECTORY" -type f -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2-)
        echo "$OLDEST_FILE" > "$CURSOR_FILE"
        return
    fi

    # Get the current file and its directory
    CURSOR_FILE_PATH=$(cat "$CURSOR_FILE")
    CURSOR_DIRECTORY=$(dirname "$CURSOR_FILE_PATH")

    # Find the next file in the same directory
    NEXT_FILE=$(find "$CURSOR_DIRECTORY" -type f -newer "$CURSOR_FILE_PATH" ! -wholename "$CURSOR_FILE_PATH" -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2-)

    if [ -z "$NEXT_FILE" ]; then
        # If there's no next file, find the next directory
        NEXT_DIRECTORY=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -newer "$CURSOR_DIRECTORY" -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2-)

        if [ -z "$NEXT_DIRECTORY" ]; then
            # If there's no next directory, loop back to the oldest file in the current directory
            NEXT_FILE=$(get_oldest_file "$CURSOR_DIRECTORY")
        else
            # If there's a next directory, switch to its oldest file
            NEXT_FILE=$(get_oldest_file "$NEXT_DIRECTORY")
        fi
    fi

    # Update the cursor file
    echo "$NEXT_FILE" > "$CURSOR_FILE"
}

# Update the cursor
update_cursor

cat "$CURSOR_FILE"

# --- LOCKING ---
# Remove the lock file
rm -f "$LOCK_FILE"
# --- END LOCKING ---
