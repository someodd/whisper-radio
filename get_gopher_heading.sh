
#!/usr/bin/env bash

# Get the latest message from a phorum (gopher) thread.
#
# Usage:
#   get_gopher_heading.sh "gopher://gopher.someodd.zip/1/phorum"
#
# This outputs the latest thread content from the specified phorum index menu.

# Stop on error
set -e

# 1) Check for required argument (metar station)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <phorumuri>"
  exit 1
fi

GOPHERPAGE="$1"
thread=$(curl "$GOPHERPAGE" | awk '/^0View as File/ {getline; sub(/./, "", $0); sub(/\t.*/, "", $0); print; exit}')
echo "Time to talk about gopherspace. Do you know about the Gopher Protocol? The freshest thread on gopher.someodd.zip slash phorum reads as follows: $thread"