#!/bin/bash

# Stop on error
set -e

# Get the script's own directory
SCRIPT_DIR=$(dirname "$0")

# Source the configuration
source "${SCRIPT_DIR}/config.sh"


# For chron, mostly
echo "$(date)"

# Check the number of directories in the output directory
DIR_COUNT=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "$DIR_COUNT" -gt 1 ]; then
    echo "More than one directory found in the output directory. Exiting."
    echo "If you want to start a new batch and launch ezstream, delete the existing directories in the output directory and try again."
    exit 1
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
        ffmpeg -f concat -safe 0 -i "$FILE_LIST_PATH" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_song.mp3"

        # Clean up the temporary files
        rm "${BATCH_DIR}/metadata.mp3" "$FILE_LIST_PATH"
    else
        # If no metadata is found, just output the song file
        ffmpeg -i "$RANDOM_SONG" -ar 22050 -ac 1 -ab 64k -f mp3 "${BATCH_DIR}/random_song.mp3"
    fi
}

output_motd

output_news

output_weather

output_gopher

output_random_text_file

output_random_audio_file

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
