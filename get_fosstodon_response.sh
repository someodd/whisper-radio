#!/usr/bin/env bash

# Usage:
#   get_fosstodon_response.sh sometag openai_key
#
# Finds the latest post on Fosstodon tagged with 'sometag' and generates a response using
# OpenAI/ChatGPT using 'openai_key'.

# Stop on error
set -e

# Check for required argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <fostodon_tag>"
  exit 1
fi

# Check for required argument
if [[ -z "$2" ]]; then
  echo "Usage: $0 <openai_key>"
  exit 1
fi

FOSSTODON_TAG="$1" # This is what gets replied to
OPENAI_API_KEY="$2"

# Respond to the latest Mastodon message under the hashtag #whisperradio (or whatever is
# configured)

echo "Now it's time where I reply to the latest message under the hashtag ${FOSSTODON_TAG}."

# Get the latest message under the hashtag $FOSSTODON_TAG
latestMessageData=$(curl -s "https://fosstodon.org/api/v1/timelines/tag/${FOSSTODON_TAG}?limit=1" | jq -r 'if type=="array" then .[0] else . end')

latestMessage=$(echo "$latestMessageData" | jq -r '.content' | sed -e 's/<[^>]*>//g')
messageId=$(echo "$latestMessageData" | jq -r '.id')

# The file where we store the ID of the last message we responded to and the response
cacheFile="response_cache.txt"

# Check if the cache file exists and contains the ID of the latest message
if [[ -f "$cacheFile" && $(head -n 1 "$cacheFile") == "$messageId" ]]; then
    # If the ID matches, read the response from the cache file
    response=$(tail -n 1 "$cacheFile")
else
    # If the ID doesn't match, generate a new response
    response=$(curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
        "model": "gpt-3.5-turbo",
        "messages": [
        {
            "role": "system",
            "content": "Respond as Fellinis Casanova. Have the restrait of Thomas Mann and the lyrical wit and contradiction of Petrarch. Everything you say must be bitter sweet, yearning, lovely, and caring toward all. However, keep your responses somewhat short, about two or three sentences. When you see #${FOSSTODON_TAG} it is referring to you/Whisper Radio."
        },
        {
            "role": "user",
            "content": "'"$latestMessage"'"
        }
        ]
    }' | jq -r '.choices[0].message.content')

    # Store the ID of the latest message and the response in the cache file
    echo "$messageId" > "$cacheFile"
    echo "$response" >> "$cacheFile"
fi

echo "Here's the message: ${latestMessage}."
echo "."
echo "$response"
echo "."
echo "If you want me to respond to your message just use the hash tag ${FOSSTODON_TAG} in your post on Fosstodon."
