#!/usr/bin/env bash
#
# Usage:
#   get_feed.sh <uri>
#
# Prints the latest headline (first <item>/<entry> title) of an RSS or Atom feed.

set -uo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <uri>" >&2
  exit 1
fi

feed_url="$1"

feed_content="$(curl -fsSL --max-time 30 "$feed_url" 2>/dev/null)" || {
  echo "get_feed: could not fetch $feed_url" >&2
  echo "no headline available"
  exit 0
}

latest_headline="$(printf '%s' "$feed_content" \
  | xmlstarlet sel -N atom="http://www.w3.org/2005/Atom" -t \
      -m '//item/title | //atom:entry/atom:title' -v '.' -n 2>/dev/null \
  | head -n 1)"

if [[ -z "$latest_headline" ]]; then
  echo "get_feed: no headline parsed from $feed_url" >&2
  echo "no headline available"
  exit 0
fi

echo "$latest_headline"
