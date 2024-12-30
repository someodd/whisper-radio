#!/bin/bash

# Stop on error
set -e

# Get the script's own directory
SCRIPT_DIR=$(dirname "$0")

# Source the configuration
source "${SCRIPT_DIR}/config.sh"


# For chron, mostly
echo "$(date)"

# FIXME: is this even working?
# Check the number of directories in the output directory
DIR_COUNT=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "$DIR_COUNT" -gt 1 ]; then
    echo "More than one directory found in the output directory. Deleting the oldest directory."
    OLDEST_DIR=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)
    echo "Deleting directory: $OLDEST_DIR"
    rm -rf "$OLDEST_DIR"
fi

# Used for creating batch directory!
BATCH_TIMESTAMP=$(date +%Y%m%dT%H%M%S)
BATCH_DIR="${OUTPUT_DIR}/${BATCH_TIMESTAMP}/"

mkdir -p "${BATCH_DIR}"

# Other host, used for longer stuff.
piper_tts() {
  echo "piper tts"
  local input_text="$1"
  local output_file="$2"
  local temp_wav="$(mktemp).wav" # Creates a temporary WAV file

  # Use piper to generate the WAV file
  echo "$input_text" | piper --model "${PROJECT_ROOT}/en_US-hfc_female-medium.onnx" --sentence-silence 1.2 --output_file "$temp_wav"

  # Use ffmpeg to convert the WAV file to an MP3 file
  ffmpeg -i "$temp_wav" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/${output_file}.mp3"

  # Delete the temporary WAV file
  rm "$temp_wav"
}

# Prepare espeak command with specified settings
whisper_tts() {
    ESPEAK_VOICE="en-us+whisper" # Voice setting for espeak
	ESPEAK_VOLUME="200" # Volume setting for espeak (0-200)
	ESPEAK_SPEED="130" # Speed setting for espeak (80-500)
	ESPEAK_COMMAND="espeak -v $ESPEAK_VOICE -a $ESPEAK_VOLUME -s $ESPEAK_SPEED"

	FFMPEG_AUDIO_SAMPLING_RATE="22050"
	FFMPEG_AUDIO_CHANNELS="1"
	FFMPEG_AUDIO_BITRATE="64k"

	local input_text="$1"
    local output_file="$2"

	$ESPEAK_COMMAND "$input_text" --stdout | ffmpeg -i - -ar "$FFMPEG_AUDIO_SAMPLING_RATE" -ac "$FFMPEG_AUDIO_CHANNELS" -ab "$FFMPEG_AUDIO_BITRATE" -f mp3 "${BATCH_DIR}/${output_file}.mp3"
}

get_gopher() {
    thread=$(curl gopher://gopher.someodd.zip:7070/ | awk '/^0View as File/ {getline; sub(/./, "", $0); sub(/\t.*/, "", $0); print; exit}')
    echo "Time to talk about gopherspace. Do you know about the Gopher Protocol? The freshest thread on gopher.someodd.zip port 7070 reads as follows: $thread"
}

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

get_fosstodon () {
    echo "Welcome to the Fosstodon segment. Fosstodon is a Mastodon instance. Let's see what's happening on this segment of the fediverse."
    echo "Let's start with the top five trending tags on Fosstodon. The top five trending tags are: $(get_fosstodon_top_tags)."
    echo "The top five links on Fosstodon are: $(get_fosstodon_top_links)."
    echo "Latest post in the Gopher tag on Fosstodon: $(get_fosstodon_latest_gopher)."
    echo "Latest public post on Fosstodon: $(get_fosstodon_latest_public_post)."
}

# Respond to the latest Mastodon message under the hashtag #whisperradio (or whatever is
# configured)
get_respond_to_latest_fosstodon () {
    # Get the latest message under the hashtag $FOSSTODON_TAG
    local latestMessageData=$(curl -s "https://fosstodon.org/api/v1/timelines/tag/${FOSSTODON_TAG}?limit=1" | jq -r 'if type=="array" then .[0] else . end')

    local latestMessage=$(echo "$latestMessageData" | jq -r '.content' | sed -e 's/<[^>]*>//g')
    local messageId=$(echo "$latestMessageData" | jq -r '.id')

    # The file where we store the ID of the last message we responded to and the response
    local cacheFile="response_cache.txt"

    # Check if the cache file exists and contains the ID of the latest message
    if [[ -f "$cacheFile" && $(head -n 1 "$cacheFile") == "$messageId" ]]; then
        # If the ID matches, read the response from the cache file
        local response=$(tail -n 1 "$cacheFile")
    else
        # If the ID doesn't match, generate a new response
        local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d '{
            "model": "gpt-3.5-turbo",
            "messages": [
            {
                "role": "system",
                "content": "You are basically a comedically dumb-as-hell, sassy, and obnoxious radio show host responding to callers. Keep your responses somewhat short, about two or three sentences. When you see #${FOSSTODON_TAG} it is referring to you/Whisper Radio."
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
}

readable_date() {
	# Get day, month, and year
	day=$(date +%d)
	month=$(date +%B)
	year=$(date +%Y)
	weekday=$(date +%A)

	# Determine the suffix for the day
	if (( day == 1 || day == 21 || day == 31 )); then
	  suffix="st"
	elif (( day == 2 || day == 22 )); then
	  suffix="nd"
	elif (( day == 3 || day == 23 )); then
	  suffix="rd"
	else
	  suffix="th"
	fi

	# Remove leading zero from day if present
	day=$(echo $day | sed 's/^0*//')

	# Combine to form friendly date
	echo "$weekday the $day$suffix of $month, $year."
}

fetch_feed() {
    local feed_url="$1"
    
    # Fetch the feed content
    feed_content="$(curl -s "$feed_url")"
    
    # Parse the feed content using xmlstarlet
    # Adjust the parsing to extract text from the first <title> within an <item> or <entry>
    latest_headline=$(echo "$feed_content" | xmlstarlet sel -N atom="http://www.w3.org/2005/Atom" -t -m '//item/title | //atom:entry/atom:title' -v '.' -n | head -1)

    # Output the latest headline
    echo "$latest_headline"
}

get_the_news() {
    echo "Hello and welcome to the rapid-fire headline segment on Whisper Radio. The date is $(readable_date). Let's read some headlines."
    echo "Latest article on someodd's personal blog: $(fetch_feed 'https://www.someodd.zip/feed.xml'). "
    echo "..."
    echo "Some OpenAI news: $(fetch_feed 'https://openai.com/blog/rss.xml'). "
    echo "..."
    echo "CGTN world news: $(fetch_feed 'https://www.cgtn.com/subscribe/rss/section/world.xml'). "
    echo "..."
    echo "New York Times headline reads: $(fetch_feed 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'). "
    echo "..."
    echo "And now a Planet Debian update: $(fetch_feed 'https://planet.debian.org/rss20.xml'). "
    echo "This concludes the headlines segment. Stay tuned for more content."
}

get_the_weather() {
    # Fetch weather data for Antarctica
    echo "Time for the weather. Information from a METAR station in Antarctica. $WEATHER_COMMAND"
}

output_fosstodon() {
    echo "Fosstodon"
    piper_tts "$(get_fosstodon)" "fosstodon"
}

output_gopher() {
    echo "Gopher"
    piper_tts "$(get_gopher)" "gopher"
}

output_news() {
    piper_tts "$(get_the_news)" "news"
}

output_weather() {
    whisper_tts "$(get_the_weather)" "weather"
}

output_motd() {
    # Read and convert the MOTD file to speech
    echo "The MOTD"
    whisper_tts "$(cat ${MOTD_FILE})" "motd"
}

get_random_text_file() {
	echo "Time for Text. In this segment a piece of text is read. Let's begin."
	RANDOM_TEXT_FILE=$(find "$TEXT_DIR" -type f | shuf -n 1)
	echo "$(cat ${RANDOM_TEXT_FILE})"
}

output_random_text_file() {
    # Randomly select a text file and use espeak to read it
    echo "random text file"
    piper_tts "$(get_random_text_file)" "random_text_file"
}

# Uses FFMPEG to ensure consistent sample rate and the sort, I guess.
#
# I could instead use mktemp.
output_random_audio_file() {
    local TAG="$1"
    # Select a random song from the audio directory
    RANDOM_SONG=$(find "$AUDIO_DIR" -type f | shuf -n 1)
    
    # Extract title and artist separately
    TITLE=$(ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$RANDOM_SONG")
    ARTIST=$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$RANDOM_SONG")

    # Concatenate title and artist in the format "Title by Artist"
    METADATA="${TITLE} by ${ARTIST}"

    # Prepare a file list for ffmpeg concat demuxer
    FILE_LIST_PATH="${BATCH_DIR}/file_list.txt"

    # If metadata is found, use espeak to convert the metadata to speech
    if [ -n "$TITLE" ]; then
        whisper_tts "Welcome to the audio segment of the program. Now let's play: $METADATA" "metadata"

        # Create a file list for concatenation
        echo "file '${BATCH_DIR}/metadata.mp3'" > "$FILE_LIST_PATH"
        echo "file '$RANDOM_SONG'" >> "$FILE_LIST_PATH"

        # Concatenate the speech audio file with the song file using the file list
        ffmpeg -f concat -safe 0 -i "$FILE_LIST_PATH" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_song_${TAG}.mp3"

        # Clean up the temporary files
        rm "${BATCH_DIR}/metadata.mp3" "$FILE_LIST_PATH"
    else
        # If no metadata is found, just output the song file
        ffmpeg -i "$RANDOM_SONG" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_song_${TAG}.mp3"
    fi
}

output_respond_to_latest_fosstodon () {
    echo "Now it's time where I reply to the latest message under the hashtag ${FOSSTODON_TAG}."
    piper_tts "$(get_respond_to_latest_fosstodon)" "respond_to_latest_fosstodon"
}

output_motd

output_respond_to_latest_fosstodon

output_fosstodon

output_news

output_weather

output_gopher

output_random_text_file

output_random_audio_file "one"

output_random_audio_file "two"

output_random_audio_file "three"

# Function to manage EZStream based on playlist comparison
#
# Basically, two things can happen:
# 1. If EZStream is not running, start it.
# 2. If the main and pending playlists are different, reload EZStream
manage_ezstream() {
    # Not escaping/handling the path safely, but it wasn't working with two other methods I tried, I think FIXME
    local EZSTREAM_CMD="ezstream -c ${PROJECT_ROOT}/ezstream.xml"

    # Check if EZStream is running. It should always be running.
    if ! pgrep -f "$EZSTREAM_CMD" > /dev/null; then
        echo "EZStream is not running. Starting EZStream..."
        nohup $EZSTREAM_CMD &>/dev/null &
    else 
        echo "EZStream is already running."
    fi
}

manage_ezstream
