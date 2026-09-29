#!/usr/bin/env bash
#
# Usage:
#   choose_random_text_file.sh <directory>
#
# Echoes the contents of a random text file from the directory.

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <directory>" >&2
  exit 1
fi

RANDOM_TEXT_FILE="$(find -L "$1" -type f -name '*.txt' | shuf -n 1 || true)"
if [[ -z "$RANDOM_TEXT_FILE" ]]; then
  echo "choose_random_text_file: no .txt files in $1" >&2
  exit 1
fi

echo "Time for Text. In this segment a piece of text is read. Let's begin."
cat -- "$RANDOM_TEXT_FILE"
