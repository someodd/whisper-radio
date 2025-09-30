#!/usr/bin/env bash

# Get the latest message from a phorum (gopher) thread.
#
# Usage:
#   manage_output_dir.sh "outputdir/"
#
# This checks the output directory for the number of directories and deletes the oldest
# one and resets the cursor if there are more than one. Returns the path to the batch
# directory created if no error.
#
# Will not delete a directory found in cursor.
#
# The point of this script is to prepare the output directory for a new batch (queue) of
# audio to be ran as a radio program.

# Stop on error
set -e

# 1) Check for required argument (metar station)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <outputdir>"
  exit 1
fi

OUTPUT_DIR="${1}"

# Source the config to get the cursor file path
# This assumes the script is run from the project root, so config.sh is findable
source "./config.sh"

# Get the PARENT DIRECTORY that the cursor is currently pointing to.
CURSOR_DIRECTORY=""
if [ -s "$CURSOR_FILE" ]; then
    # Get the directory from the cursor file
    CURSOR_DIR_RAW=$(dirname "$(cat "$CURSOR_FILE")")
    # Standardize the path to an absolute path
    CURSOR_DIRECTORY=$(realpath "$CURSOR_DIR_RAW")
fi

# Find all directories
ALL_DIRS=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d)
DIR_COUNT=$(echo "$ALL_DIRS" | wc -l)

if [ "$DIR_COUNT" -gt 1 ]; then
    # --- NEW, MORE AGGRESSIVE CLEANUP LOGIC ---
    # Delete all directories except for the one the cursor is in.
    for dir in $ALL_DIRS; do
        # Standardize the path to an absolute path
        dir_to_check=$(realpath "$dir")
        if [ "$dir_to_check" != "$CURSOR_DIRECTORY" ]; then
            echo "Cleanup: Deleting old directory ${dir_to_check}."
            rm -rf "$dir"
        fi
    done
    # --- END NEW CLEANUP LOGIC ---
fi

# Create the new batch directory
BATCH_TIMESTAMP=$(date +%Y%m%dT%H%M%S)
BATCH_DIR="${OUTPUT_DIR}/${BATCH_TIMESTAMP}/"

mkdir -p "${BATCH_DIR}"
echo "${BATCH_DIR}"
