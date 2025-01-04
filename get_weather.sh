#!/usr/bin/env bash

# Usage:
#   get_weather.sh metarstationid
#   get_weather.sh NZSP
#
# This outputs the weather from antartica.

# Stop on error
set -e

# 1) Check for required argument (metar station)
if [[ -z "$1" ]]; then
  echo "Usage: $0 <metarstationid>"
  exit 1
fi

METAR_STATION="$1"

# Fetch weather data for Antarctica
WEATHER_COMMAND=$(metar -d "${METAR_STATION_ID}" | tail -n +2)
echo "Time for the weather. Information from a METAR station in Antarctica. $WEATHER_COMMAND"