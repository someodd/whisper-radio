#!/usr/bin/env bash

# Usage: get_bartleby.sh [feed_uri]
#
# Fetches the latest entry (title + summary) from the bartleby atom feed
# and emits TTS-friendly narration about the most recent library accession.

set -e

FEED_URL="${1:-gopher://gopher.someodd.zip:70/0/catalog/feed.xml}"

feed=$(curl -sS --max-time 20 "$FEED_URL")

title=$(printf '%s' "$feed" | xmlstarlet sel -N a="http://www.w3.org/2005/Atom" \
  -t -m '//a:entry[1]' -v 'a:title' -n 2>/dev/null | head -n1)
summary=$(printf '%s' "$feed" | xmlstarlet sel -N a="http://www.w3.org/2005/Atom" \
  -t -m '//a:entry[1]' -v 'a:summary' -n 2>/dev/null | head -n1)

# Strip a trailing ".md" from titles since it's noise to TTS.
title=${title%.md}

if [[ -z "$title" ]]; then
  echo "The bartleby library is currently quiet. No new accessions to report."
  exit 0
fi

if [[ -n "$summary" && "$summary" != "$title" ]]; then
  echo "And now an update from someodd's bartleby library. The latest accession is titled: ${title}. Here is the summary. ${summary}"
else
  echo "And now an update from someodd's bartleby library. The latest accession is titled: ${title}."
fi
