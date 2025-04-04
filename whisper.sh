#!/bin/bash

# Builds the radio program to a batch directory and manages the ezstream process.

# Stop on error
#set -e

# Get the script's own directory
SCRIPT_DIR=$(dirname "$0")

# Source the configuration
source "${SCRIPT_DIR}/config.sh"

# For chron, mostly
echo "$(date)"

# FIXME: why not just use script dir and not even have project_root...
cd "${PROJECT_ROOT}"

BATCH_DIR=$(./manage_output_dir.sh "$OUTPUT_DIR")

cat "${MOTD_FILE}" | ./out_tts_oldschool.sh "${BATCH_DIR}/motd"

./get_fosstodon_response.sh "$FOSSTODON_TAG" "$OPENAPI_API_KEY" | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/respond_to_latest_fosstodon" "${PROJECT_ROOT}"

./get_fosstodon.sh | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/fosstodon" "${PROJECT_ROOT}"

./get_news.sh | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/news" "${PROJECT_ROOT}"

./get_weather.sh "NZSP" | ./out_tts_oldschool.sh "${BATCH_DIR}/weather"

./get_gopher_heading.sh "gopher://gopher.someodd.zip/1/phorum" | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/gopher" "${PROJECT_ROOT}"

./choose_random_text_file.sh "${TEXT_DIR}" | ./out_tts_ai.sh "${PIPER_PATH}" "${BATCH_DIR}/random_text_file" "${PROJECT_ROOT}"

./out_random_audio.sh "${AUDIO_DIR}" "${BATCH_DIR}" "one"
./out_random_audio.sh "${AUDIO_DIR}" "${BATCH_DIR}" "two"
./out_random_audio.sh "${AUDIO_DIR}" "${BATCH_DIR}" "three"

./manage_ezstream.sh "${PROJECT_ROOT}"
