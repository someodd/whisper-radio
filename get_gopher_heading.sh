#!/usr/bin/env bash
#
# Get the latest thread from a phorum (gopher) menu.
#
# Usage:
#   get_gopher_heading.sh "gopher://gopher.someodd.zip/1/phorum"

set -uo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <phorum_uri>" >&2
  exit 1
fi

GOPHERPAGE="$1"
thread="$(curl -sS --max-time 20 "$GOPHERPAGE" 2>/dev/null \
  | awk '/^0View as File/ {getline; sub(/./, "", $0); sub(/\t.*/, "", $0); print; exit}')"

if [[ -z "$thread" ]]; then
  echo "get_gopher_heading: nothing found at $GOPHERPAGE" >&2
  echo "Time to talk about gopherspace. Do you know about the Gopher Protocol? The phorum on gopher.someodd.zip could not be reached this hour."
  exit 0
fi

echo "Time to talk about gopherspace. Do you know about the Gopher Protocol? The freshest thread on gopher.someodd.zip slash phorum reads as follows: $thread"
