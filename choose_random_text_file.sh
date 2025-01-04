#!/usr/bin/env bash

# Usage:
#   choose_random_text_file.sh directory
#
# This will echo the contents of a random text file from the directory.

# Stop on error
set -e

# 1) Check for required argument (directory to select from)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

echo "Time for Text. In this segment a piece of text is read. Let's begin."
RANDOM_TEXT_FILE=$(find "${1}" -type f | shuf -n 1)
echo "$(cat ${RANDOM_TEXT_FILE})"