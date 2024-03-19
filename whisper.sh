#!/bin/bash

# Stop on error
set -e

# Constants
TEXT_DIR="./text" # Default directory containing text files
MOTD_FILE="./motd.txt" # Path to your MOTD file
RSS_FEED_URL="https://planet.debian.org/rss20.xml" # URL of the RSS feed
WEATHER_API_URL="http://api.weatherapi.com/v1/current.json" # URL of the weather API
WEATHER_API_KEY="your_api_key" # API key for the weather service
WEATHER_LOCATION="-75.250973,0.071389" # Coordinates for a location in Antarctica
AUDIO_DIR="./audio" # Default directory with MP3 files for music
OUTPUT_DIR="./output" # Output directory. I feel like it should go in /tmp or something.
ESPEAK_VOICE="en-us+whisper" # Voice setting for espeak
ESPEAK_VOLUME="200" # Volume setting for espeak (0-200)
ESPEAK_SPEED="130" # Speed setting for espeak (80-500)
FFMPEG_AUDIO_SAMPLING_RATE="22050"
FFMPEG_AUDIO_CHANNELS="1"
FFMPEG_AUDIO_BITRATE="64k"
MAIN_PLAYLIST="./playlist-main.m3u"
PENDING_PLAYLIST="./playlist-pending.m3u"

# Recreate the output dir
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Prepare espeak command with specified settings
ESPEAK_COMMAND="espeak -v $ESPEAK_VOICE -a $ESPEAK_VOLUME -s $ESPEAK_SPEED"

# Fetch the latest headline from an RSS feed
LATEST_HEADLINE=$(curl -s "$RSS_FEED_URL" | grep -o '<title>[^<]*' | head -2 | tail -1 | sed 's/<title>//')

# Fetch weather data for Antarctica
WEATHER_DATA=$(curl -s "${WEATHER_API_URL}?key=${WEATHER_API_KEY}&q=${WEATHER_LOCATION}&aqi=no")

# Extract relevant parts of the weather data
WEATHER_CONDITION=$(echo $WEATHER_DATA | jq -r '.current.condition.text')
TEMPERATURE=$(echo $WEATHER_DATA | jq -r '.current.temp_c')

# Prepare text for espeak
ESPEAK_TEXT="Latest headline is: $LATEST_HEADLINE. Weather in Antarctica: $WEATHER_CONDITION with a temperature of $TEMPERATURE."

# Read and convert the MOTD file to speech
echo "The MOTD"
$ESPEAK_COMMAND -f "$MOTD_FILE" --stdout | ffmpeg -i - -ar "$FFMPEG_AUDIO_SAMPLING_RATE" -ac "$FFMPEG_AUDIO_CHANNELS" -ab "$FFMPEG_AUDIO_BITRATE" -f mp3 "${OUTPUT_DIR}/motd_output.mp3"

# Use espeak for TTS, save output to a file for the prepared text
echo "The summary"
$ESPEAK_COMMAND "$ESPEAK_TEXT" --stdout | ffmpeg -i - -ar "$FFMPEG_AUDIO_SAMPLING_RATE" -ac "$FFMPEG_AUDIO_CHANNELS" -ab "$FFMPEG_AUDIO_BITRATE" -f mp3 "${OUTPUT_DIR}/espeak_output.mp3"

# Randomly select a text file and use espeak to read it
echo "random text file"
RANDOM_TEXT_FILE=$(find "$TEXT_DIR" -type f | shuf -n 1)
$ESPEAK_COMMAND -f "$RANDOM_TEXT_FILE" --stdout | ffmpeg -i - -ar "$FFMPEG_AUDIO_SAMPLING_RATE" -ac "$FFMPEG_AUDIO_CHANNELS" -ab "$FFMPEG_AUDIO_BITRATE" -f mp3 "${OUTPUT_DIR}/random_text_output.mp3"

# Select a random song from the audio directory
echo "random song file"
RANDOM_SONG=$(find "$AUDIO_DIR" -type f | shuf -n 1)

# Create a symbolic link to the random song in the output directory
ln -s "$RANDOM_SONG" "${OUTPUT_DIR}/random_song.mp3"

# Ezstream XML configuration file needs to be set up to play espeak_output.mp3, motd_output.mp3, random_text_output.mp3, and RANDOM_SONG in sequence

final_output_dir="./output-final/"
mkdir -p "${final_output_dir}"

# Iterate over all files in the output directory
for file in "$OUTPUT_DIR"/*.mp3; do
    # Check if the file is an MP3 file
    if [ -f "$file" ]; then
        # Generate a SHA-256 hash of the file
        hash=$(sha256sum "$file" | cut -d ' ' -f 1)
        
        # Extract the filename and extension
        filename=$(basename "$file")
        extension="${filename##*.}"
        filename="${filename%.*}"

        # Rename the file to include the hash in its filename
	new_filename="$OUTPUT_DIR/${filename}_${hash}.${extension}"
        mv "$file" "$new_filename"
	echo "$new_filename" >> $PENDING_PLAYLIST
    fi
done

# Placeholder for stream configuration
echo "Prepared to stream: $ESPEAK_TEXT, then MOTD from $MOTD_FILE, content from $RANDOM_TEXT_FILE, followed by music from $RANDOM_SONG"
# Build new temp playlist

# Function to manage EZStream based on playlist comparison
manage_ezstream() {
    local EZSTREAM_CMD="ezstream -c ./ezstream.xml"

    # Check if EZStream is running
    if ! pgrep -f "$EZSTREAM_CMD" > /dev/null; then
        echo "EZStream is not running. Starting EZStream..."
        nohup $EZSTREAM_CMD &>/dev/null &
    else
        echo "EZStream is running."

        # Compare the main and pending playlists
        if ! cmp -s "$MAIN_PLAYLIST" "$PENDING_PLAYLIST"; then
            echo "Playlists are different. Reloading EZStream..."
	    mv "$PENDING_PLAYLIST" "$MAIN_PLAYLIST"
            # Find EZStream's PID and send SIGHUP to force config reload
            pkill -HUP -f "$EZSTREAM_CMD"

            # Optionally, update MAIN_PLAYLIST to reflect the changes
            #cp "$PENDING_PLAYLIST" "$MAIN_PLAYLIST"
        else
            echo "Playlists are the same. No action needed."
        fi
    fi
}

# ezstream here...
# could even generate an m3u?
# check if there's a difference between main and temp. if there is, replace!
manage_ezstream
