#!/usr/bin/env bash

# Usage: get_interlog.sh [interlog_menu_uri]
#
# Reads the freshest interlog thread: thread title + first line (original post)
# + last non-empty line (latest reply). The /1/interlog menu is sorted
# newest-first by activity timestamp, so the first type-0 entry is the freshest.
# Interlog files use "newest entry concatenated to the end" semantics.

set -e

INTERLOG_URI="${1:-gopher://gopher.someodd.zip:70/1/interlog}"
HOST="gopher.someodd.zip"
PORT=70

menu=$(curl -sS --max-time 15 "$INTERLOG_URI")

# Gopher menu line format: <type><display>\t<selector>\t<host>\t<port>\r
# Pick the first "0" type line that points to /interlog/log/ (skip the
# "Raw logs" autoindex which is type 1).
first=$(printf '%s' "$menu" | awk -F'\t' '/^0.*\/interlog\/log\// { print; exit }')

if [[ -z "$first" ]]; then
  echo "The interlog phorum has no readable threads right now."
  exit 0
fi

display=$(printf '%s' "$first" | cut -f1)
display=${display#0}
thread_title=$(printf '%s' "$display" | sed -E 's/[[:space:]]*\[[^]]*\][[:space:]]*$//')

selector=$(printf '%s' "$first" | cut -f2)
file_url="gopher://${HOST}:${PORT}/0${selector}"

# Filter lone "." (gopher protocol terminator, in case curl leaves it) and blanks.
body=$(curl -sS --max-time 15 "$file_url" | tr -d '\r' | grep -vE '^\.$' | grep -vE '^[[:space:]]*$')

if [[ -z "$body" ]]; then
  echo "The freshest interlog thread, ${thread_title}, appears to be empty."
  exit 0
fi

first_line=$(printf '%s\n' "$body" | head -n1)
last_line=$(printf '%s\n' "$body" | tail -n1)

if [[ "$first_line" == "$last_line" ]]; then
  echo "From the interlog phorum on gopher.someodd.zip, the freshest thread is titled '${thread_title}'. It contains a single entry: ${first_line}"
else
  echo "From the interlog phorum on gopher.someodd.zip, the freshest thread is titled '${thread_title}'. It opened with: ${first_line} ... and the latest reply reads: ${last_line}"
fi
