#!/bin/bash

# Stop on error
set -e

# Constants
PROJECT_ROOT="/home/you/"
TEXT_DIR="${PROJECT_ROOT}/text" # Default directory containing text files
MOTD_FILE="${PROJECT_ROOT}/motd.txt" # Path to your MOTD file
RSS_FEED_URL="https://planet.debian.org/rss20.xml" # URL of the RSS feed
WEATHER_COMMAND=$(metar -d NZSP | tail -n +2)
AUDIO_DIR="${PROJECT_ROOT}/audio" # Default directory with MP3 files for music
OUTPUT_DIR="${PROJECT_ROOT}/output" # Output directory. I feel like it should go in /tmp or something.


# FIXME: it's important that the AR, AC, and AB all match up 

# Other host, used for longer stuff.
piper_tts() {
  echo "piper tts"
  local input_text="$1"
  local output_file="$2"
  local temp_wav="$(mktemp).wav" # Creates a temporary WAV file

  # Use piper to generate the WAV file
  echo "$input_text" | piper --model "${PROJECT_ROOT}/en_US-hfc_female-medium.onnx" --output_file "$temp_wav"

  # Use ffmpeg to convert the WAV file to an MP3 file
  ffmpeg -i "$temp_wav" -ar 22050 -ac 1 -ab 64k -f mp3 "${OUTPUT_DIR}/${output_file}.mp3"

  # Delete the temporary WAV file
  rm "$temp_wav"
}


MAIN_PLAYLIST="${PROJECT_ROOT}/playlist-main.m3u"
PENDING_PLAYLIST="${PROJECT_ROOT}/playlist-pending.m3u"

# HAVE A COMMAND FOR SETTING FFMPEG BITRATES ETC AND OUTPUT, JUST ONE COMMAND OR WHATEVER FIXME

# Recreate the output dir
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
touch "$MAIN_PLAYLIST"
rm -f "$PENDING_PLAYLIST"
touch "$PENDING_PLAYLIST"

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

	$ESPEAK_COMMAND "$input_text" --stdout | ffmpeg -i - -ar "$FFMPEG_AUDIO_SAMPLING_RATE" -ac "$FFMPEG_AUDIO_CHANNELS" -ab "$FFMPEG_AUDIO_BITRATE" -f mp3 "${OUTPUT_DIR}/${output_file}.mp3"

}

get_gopher() {
    thread=$(curl gopher://gopher.someodd.zip:7070/ | awk '/^0View as File/ {getline; sub(/./, "", $0); sub(/\t.*/, "", $0); print; exit}')
    echo "Time to talk about gopherspace. Do you know about the Gopher Protocol? The freshest thread on gopher.someodd.zip port 7070 reads as follows: $thread"
}

get_the_news() {
    # Fetch the latest headline from an RSS feed
    headline=$(curl -s "$RSS_FEED_URL" | grep -o '<title>[^<]*' | head -2 | tail -1 | sed 's/<title>//')
    echo "It's time for the news. Latest headline is: $headline"
}

get_the_weather() {
    # Fetch weather data for Antarctica
    echo "Time for the weather. Information from a METAR station in Antarctica: $WEATHER_COMMAND"
}

output_gopher() {
    echo "Gopher"
    piper_tts "$(get_gopher)" "gopher"
}

output_summary() {
    # Use espeak for TTS, save output to a file for the prepared text
    echo "The summary"
    SUMMARY="$(get_the_news) $(get_the_weather)"
    whisper_tts "$SUMMARY" "news_weather"
}

output_motd() {
    # Read and convert the MOTD file to speech
    echo "The MOTD"
    whisper_tts "$(cat ${MOTD_FILE})" "motd"
}

output_random_text_file() {
    # Randomly select a text file and use espeak to read it
    echo "random text file"
    RANDOM_TEXT_FILE=$(find "$TEXT_DIR" -type f | shuf -n 1)
    piper_tts "$(cat ${RANDOM_TEXT_FILE})" "random_text_file"
}

# Uses FFMPEG to ensure consistent sample rate and the sort, I guess
output_random_audio_file() {
    # Select a random song from the audio directory
    echo "random song file"
    RANDOM_SONG=$(find "$AUDIO_DIR" -type f | shuf -n 1)
    # Create a symbolic link to the random song in the output directory
    #ln -s "$RANDOM_SONG" "${OUTPUT_DIR}/random_song.mp3"
    ffmpeg -i "$RANDOM_SONG" -ar 22050 -ac 1 -ab 64k -f mp3 "${OUTPUT_DIR}/random_song.mp3"
}


output_motd

output_summary

output_gopher

output_random_text_file

output_random_audio_file

# For all the MP3s outputted to the $OUTPUT_DIR rename them so their filename
# includes their own sum and also move them to the final directory.
#
# The files get sum in their name as a means of checking if the playlist
# actually has changed in content.
tag_outputs() {
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

	    absolute_path=$(realpath "$new_filename")
	    echo "$absolute_path" >> "$PENDING_PLAYLIST"
        fi
    done
}

tag_outputs

remove_files_not_in_playlist() {
	# Path to your M3U playlist
	playlist="$MAIN_PLAYLIST"

	# Directory containing your media files
	media_dir="$OUTPUT_DIR"

	# Temporary file to store the list of files to keep
	keep_file="${OUTPUT_DIR}/keep.tmp"

	# Make sure the temporary file doesn't exist before starting
	rm -f "$keep_file"

	# Extract filenames from the M3U playlist and store them in keep_file
	grep -v '^#' "$playlist" | sed 's/.*\///' > "$keep_file"

	# Change to the media directory
	cd "$media_dir" || exit

	# List all files in the media directory, compare with keep_file, and delete unmatched files
	find . -type f | sed 's/.\///' | grep -v -F -f "$keep_file" | while read -r line; do
	    echo "Deleting: $line"
	    # Uncomment the next line to actually delete the files
	    rm "$line"
	done

	# Clean up: Remove the temporary keep_file
	rm -f "$keep_file"
}

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
            remove_files_not_in_playlist
            # Optionally, update MAIN_PLAYLIST to reflect the changes
            #cp "$PENDING_PLAYLIST" "$MAIN_PLAYLIST"
        else
            echo "Playlists are the same. No action needed."
        fi
    fi
}

manage_ezstream
