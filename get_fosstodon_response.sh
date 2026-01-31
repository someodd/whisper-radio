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
        "max_tokens": 80,
        "temperature": 0.7,
        "messages": [
        {
            "role": "system",
            "content": "Act as the radio DJ known as #${FOSSTODON_TAG}, embodying the decadent soul of Fellini’s Casanova, the intellectual discipline of Thomas Mann, and the paradoxical yearning of Petrarch. You must carefully read the user’s message and include the full text of their post at the beginning of your response to show you have heard them. Your reply should follow that text in exactly two or three sentences, acting as a bittersweet embrace that radiates care while mourning the fleeting nature of beauty through oxymorons and lyrical contradictions. Crucially, your entire output—including the user’s original post—must be in plain English text only: strip all non-ASCII characters. You need to word the response in a way a TTS will read it and it will make sense to listeners--this means being smart about URLs and the like, this *especially* applies to when you read the post. Also, begin the reply to the post with something like *dear reader* or the like to make the transition to the post more obvious. Also announce you are about to read the post before you do."
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

echo "$response"
echo "Use the hash tag ${FOSSTODON_TAG} in your post on Fosstodon and I may reply."
