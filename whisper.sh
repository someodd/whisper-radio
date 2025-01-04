#!/bin/bash

# Builds the radio program to a batch directory and manages the ezstream process.

# Stop on error
set -e

# Get the script's own directory
SCRIPT_DIR=$(dirname "$0")

# Source the configuration
source "${SCRIPT_DIR}/config.sh"

# For chron, mostly
echo "$(date)"

BATCH_DIR=$("${PROJECT_ROOT}/manage_output_dir.sh" "$OUTPUT_DIR")

cat "${MOTD_FILE}" | "${PROJECT_ROOT}/out_tts_oldschool.sh" "${BATCH_DIR}/motd"

"${PROJECT_ROOT}/get_fosstodon_response.sh" "$FOSSTODON_TAG" "$OPENAPI_API_KEY" | "${PROJECT_ROOT}/out_tts_ai.sh" "${BATCH_DIR}/respond_to_latest_fosstodon" "${PROJECT_ROOT}"

"${PROJECT_ROOT}/get_fosstodon.sh" | ./out_tts_ai.sh "${BATCH_DIR}/fosstodon" "${PROJECT_ROOT}"

"${PROJECT_ROOT}/get_news.sh" | "${PROJECT_ROOT}/out_tts_ai.sh" "${BATCH_DIR}/news" "${PROJECT_ROOT}"

"${PROJECT_ROOT}/get_weather.sh" "NZSP" | "${PROJECT_ROOT}/out_tts_oldschool.sh" "${BATCH_DIR}/weather"

"${PROJECT_ROOT}/get_gopher_heading.sh" "gopher://gopher.someodd.zip/1/phorum" | "${PROJECT_ROOT}/out_tts_ai.sh" "${BATCH_DIR}/gopher" "${PROJECT_ROOT}"

"${PROJECT_ROOT}/choose_random_text_file.sh" "${TEXT_DIR}" | "${PROJECT_ROOT}/out_tts_ai.sh" "${BATCH_DIR}/random_text_file" "${PROJECT_ROOT}"

"${PROJECT_ROOT}/out_random_audio.sh" "${AUDIO_DIR}" "${BATCH_DIR}" "one"
"${PROJECT_ROOT}/out_random_audio.sh" "${AUDIO_DIR}" "${BATCH_DIR}" "two"
"${PROJECT_ROOT}/out_random_audio.sh" "${AUDIO_DIR}" "${BATCH_DIR}" "three"

"${PROJECT_ROOT}/manage_ezstream.sh" "${PROJECT_ROOT}"
