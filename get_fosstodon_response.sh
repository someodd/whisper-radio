#!/usr/bin/env bash
#
# Usage:
#   OPENAI_API_KEY=... get_fosstodon_response.sh <tag>
#
# Finds the latest post on Fosstodon tagged with <tag> and generates an
# in-character reply with OpenAI. The key is read from the environment so it
# never shows up in `ps`. (A second argument is still accepted for backwards
# compatibility but discouraged.)
#
# Replies are cached per post id in response_cache.txt next to this script.
# Failures are never cached and never read on air: on any error the script
# prints a short fallback line and exits 0 so the rest of the batch continues.

set -uo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <fosstodon_tag>" >&2
  exit 1
fi

FOSSTODON_TAG="$1"
OPENAI_API_KEY="${2:-${OPENAI_API_KEY:-}}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-3.5-turbo}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cacheFile="${SCRIPT_DIR}/response_cache.txt"

fallback() {
  echo "get_fosstodon_response: $1" >&2
  echo "The mailbag segment is unavailable this hour. Use the hash tag ${FOSSTODON_TAG} in your post on Fosstodon and I may reply."
  exit 0
}

if [[ -z "$OPENAI_API_KEY" ]]; then
  fallback "OPENAI_API_KEY is not set"
fi

# 1. Latest tagged post
latestMessageData="$(curl -fsS --max-time 30 "https://fosstodon.org/api/v1/timelines/tag/${FOSSTODON_TAG}?limit=1" \
  | jq -r 'if type=="array" then .[0] else . end' 2>/dev/null)" || fallback "could not fetch the Fosstodon timeline"

messageId="$(jq -r '.id // empty' <<<"$latestMessageData" 2>/dev/null)"
if [[ -z "$messageId" ]]; then
  echo "No messages found for tag #${FOSSTODON_TAG}. Use the hash tag ${FOSSTODON_TAG} in your post on Fosstodon and I may reply."
  exit 0
fi
latestMessage="$(jq -r '.content // ""' <<<"$latestMessageData" | sed -e 's/<[^>]*>//g')"

# 2. Cache check
if [[ -f "$cacheFile" && "$(head -n 1 "$cacheFile")" == "$messageId" ]]; then
  cached="$(tail -n +2 "$cacheFile")"
  if [[ -n "$cached" && "$cached" != "null" ]]; then
    echo "$cached"
    exit 0
  fi
fi

# 3. Prompt
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

JSON_PAYLOAD="$(jq -n \
  --arg model "$OPENAI_MODEL" \
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
  }')"

# 4. Call OpenAI. -f is deliberately omitted so the error body can be read.
raw="$(curl -sS --max-time 180 https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD")" || fallback "OpenAI request failed"

apiError="$(jq -r '.error.message // empty' <<<"$raw" 2>/dev/null)"
if [[ -n "$apiError" ]]; then
  fallback "OpenAI error: $apiError"
fi

response="$(jq -r '.choices[0].message.content // empty' <<<"$raw" 2>/dev/null)"
if [[ -z "$response" ]]; then
  fallback "OpenAI returned no content"
fi

# 5. Update cache atomically
{
  echo "$messageId"
  echo "$response"
} > "${cacheFile}.tmp" && mv -f "${cacheFile}.tmp" "$cacheFile"

# 6. Output
echo "Now it's time where I reply to the latest message under the hashtag ${FOSSTODON_TAG}."
echo "$response"
echo "Use the hash tag ${FOSSTODON_TAG} in your post on Fosstodon and I may reply."
