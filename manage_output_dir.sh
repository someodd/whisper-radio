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
# The point of this script is to prepare the output directory for a new batch (queue) of
# audio to be ran as a radio program.

# Stop on error
set -e

# 1) Check for required argument (metar station)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <outputdir>"
  exit 1
fi

# This script manages the batch directory (output dir).
OUTPUT_DIR="${1}"
# FIXME: is this even working?
# Check the number of directories in the output directory
DIR_COUNT=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "$DIR_COUNT" -gt 1 ]; then
    # "More than one directory found in the output directory. Deleting the oldest directory.
    OLDEST_DIR=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)
    rm -rf "$OLDEST_DIR"
    rm -f cursor
fi

# Used for creating batch directory!
BATCH_TIMESTAMP=$(date +%Y%m%dT%H%M%S)
BATCH_DIR="${OUTPUT_DIR}/${BATCH_TIMESTAMP}/"

mkdir -p "${BATCH_DIR}"
echo "${BATCH_DIR}"