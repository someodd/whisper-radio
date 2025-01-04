#!/usr/bin/env bash

# Usage:
#   get_feed.sh uri

# Stop on error
set -e

# 1) Check for required argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <uri>"
  exit 1
fi

feed_url="$1"

# Fetch the feed content
feed_content="$(curl -s "$feed_url")"

# Parse the feed content using xmlstarlet
# Adjust the parsing to extract text from the first <title> within an <item> or <entry>
latest_headline=$(echo "$feed_content" | xmlstarlet sel -N atom="http://www.w3.org/2005/Atom" -t -m '//item/title | //atom:entry/atom:title' -v '.' -n | head -1)

# Output the latest headline
echo "$latest_headline"