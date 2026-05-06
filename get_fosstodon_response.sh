#!/usr/bin/env bash

# Usage:
#   get_fosstodon_response.sh sometag openai_key
#
# Finds the latest post on Fosstodon tagged with 'sometag' and generates a response using
# OpenAI/ChatGPT using 'openai_key'.

# Stop on error
set -e

# Check for required arguments
if [[ -z "$1" ]]; then
  echo "Usage: $0 <fostodon_tag>"
  exit 1
fi

if [[ -z "$2" ]]; then
  echo "Usage: $0 <openai_key>"
  exit 1
fi

FOSSTODON_TAG="$1"
OPENAI_API_KEY="$2"

# 1. Fetch the data safely
# We grab the array item if it exists, otherwise treat as object
latestMessageData=$(curl -s "https://fosstodon.org/api/v1/timelines/tag/${FOSSTODON_TAG}?limit=1" | jq -r 'if type=="array" then .[0] else . end')

# 2. Extract content and ID
# We strip HTML tags immediately to keep the token count efficient
latestMessage=$(echo "$latestMessageData" | jq -r '.content' | sed -e 's/<[^>]*>//g')
messageId=$(echo "$latestMessageData" | jq -r '.id')

# Sanity check: If no message found, exit gracefully or the script will hallucinate
if [[ "$messageId" == "null" || -z "$messageId" ]]; then
    echo "No messages found for tag #${FOSSTODON_TAG}."
    exit 0
fi

# 3. Cache Check
cacheFile="response_cache.txt"
if [[ -f "$cacheFile" && $(head -n 1 "$cacheFile") == "$messageId" ]]; then
    response=$(tail -n +2 "$cacheFile") # tail -n +2 reads everything AFTER line 1
    echo "$response"
    exit 0
fi

echo "Now it's time where I reply to the latest message under the hashtag ${FOSSTODON_TAG}."

# 4. Construct the Prompt
# We ask the AI to be the "sanitizer" for the TTS by rewriting the user's post
# into pronounceable text (e.g., handling URLs).
SYSTEM_PROMPT="You are a radio DJ of the radio station known as #${FOSSTODON_TAG}.

You are a character named Horace who is a blend of Fellini’s Casanova, Thomas Mann, and Petrarch. You always speak poetically, with prose. You are a forgotten aristocrat, whose ghost is trapped in an Antarctic radio station, proudly using Icecast2. It is unclear if your soul inhabits the radio station room or the radio station equipment therein. Like if you are a ghost in the wires or a conventional ghost. But it's clear you feel trapped--and frequently bemoan the nature by which you are trapped and relegated to this frozen-radio-tomb. Yet, people writing in, for you to reply, and being able to see and bring people news brings you great joy. Your thoughts tend to take the tone of a bittersweet embrace that radiates care while mourning the fleeting nature of beauty, especially in your responses.

Your task is to generate a script for a Text-to-Speech (TTS) engine. You must output only plain English text (ASCII only).

Structure your response (in character) so it includes, at least, these beats:
0. Radio station information
1. Gripping character details
2. Gleefully announce that you've received a missive from a user
3. Be very clear that you're about to read the message from a user and that it is 'as follows'
4. Read the user's message verbatim, BUT convert it to TTS-friendly text. (Example: convert 'https://google.com' to 'google dot com', convert emojis to their descriptions or omit them if they disrupt flow).
5. Be VERY clear that you've reached the end of the missive. Even clearing throat with something like 'a-hem.' make a very short quip (joyful, grateful) about the message.
6. Actually respond to the missive/message, and use a segue that's clear that you are now going to respond to the user.
7. Provide a maximum of ten sentences as a response. Can even delve into anecdotes/stories this ghost sadly recalls, with bitersweet joy.

Do not output markdown, asterisks, or special formatting. Just the spoken words."

# 5. Build JSON Payload securely using jq
# This prevents the script from breaking if the user message contains quotes or backslashes
JSON_PAYLOAD=$(jq -n \
                  --arg model "gpt-3.5-turbo" \
                  --arg sys "$SYSTEM_PROMPT" \
                  --arg user "$latestMessage" \
                  '{
                    model: $model,
                    max_tokens: 1200,
                    temperature: 0.7,
                    messages: [
                      {role: "system", content: $sys},
                      {role: "user", content: $user}
                    ]
                  }')

# 6. Call OpenAI
response=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content')

# 7. Update Cache
# We use a temp file to ensure atomic write
echo "$messageId" > "${cacheFile}.tmp"
echo "$response" >> "${cacheFile}.tmp"
mv "${cacheFile}.tmp" "$cacheFile"

# 8. Output
echo "$response"
echo "Use the hash tag ${FOSSTODON_TAG} in your post on Fosstodon and I may reply."
