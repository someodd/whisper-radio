#!/usr/bin/env bash

# Usage:
#   get_fosstodon.sh
#
# This gets various information/posts from the Fosstodon Mastodon instance.

# Stop on error
set -e

# Function to fetch, parse, and sort trending tags from Fosstodon
get_fosstodon_top_tags () {
    # Mastodon API endpoint for trending tags
    local apiEndpoint="https://fosstodon.org/api/v1/trends/tags?limit=5"

    # Use curl to fetch the JSON data from the API
    # Then use jq to extract tag names and the number of uses, sort by uses, and then get the top ten
    curl -s "$apiEndpoint" | 
    jq '.[] | {name: .name, uses: .history[0].uses} | select(.uses | tonumber > 0)' | 
    jq -s 'sort_by(.uses | tonumber) | reverse | .[0:5]' | 
    jq -r '.[] | "\(.name) with \(.uses) uses."'
}

get_fosstodon_top_links () {
    # Mastodon API endpoint for trending links
    local apiEndpoint="https://fosstodon.org/api/v1/trends/links?limit=5"

    # Use curl to fetch the JSON data from the API
    # Then use jq to extract link titles and the number of uses, sort by uses, and then get the top ten
    curl -s "$apiEndpoint" | 
    jq '.[] | {title: .title, uses: .history[0].uses} | select(.uses | tonumber > 0)' | 
    jq -s 'sort_by(.uses | tonumber) | reverse | .[0:5]' | 
    jq -r '.[] | "\(.title). with \(.uses) uses."'
}

get_fosstodon_latest_gopher () {
    # Mastodon API endpoint for the "gopher" tag timeline
    local apiEndpoint="https://fosstodon.org/api/v1/timelines/tag/gopher?limit=1"

    # Use curl to fetch the JSON data from the API
    curl -s "$apiEndpoint" | 
    jq -r 'if type=="array" then .[0] | .content else .content end' | 
    sed -e 's/<[^>]*>//g'
}

get_fosstodon_latest_public_post () {
    # Mastodon API endpoint for the public timeline
    local apiEndpoint="https://fosstodon.org/api/v1/timelines/public?limit=1"

    # Use curl to fetch the JSON data from the API
    # Then use jq to extract the content of the latest post and strip HTML tags
    curl -s "$apiEndpoint" | 
    jq -r 'if type=="array" then .[0] | .content else .content end' | 
    sed -e 's/<[^>]*>//g'
}

echo "Welcome to the Fosstodon segment. Fosstodon is a Mastodon instance. Let's see what's happening on this segment of the fediverse."
echo "Let's start with the top five trending tags on Fosstodon. The top five trending tags are: $(get_fosstodon_top_tags)."
echo "The top five links on Fosstodon are: $(get_fosstodon_top_links)."
echo "Latest post in the Gopher tag on Fosstodon: $(get_fosstodon_latest_gopher)."
echo "Latest public post on Fosstodon: $(get_fosstodon_latest_public_post)."