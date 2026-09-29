#!/usr/bin/env bash
#
# Usage:
#   get_weather.sh <metar_station_id>
#   get_weather.sh NZSP
#
# Outputs the decoded METAR report for the station (default: Antarctica).

set -uo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <metar_station_id>" >&2
  exit 1
fi

METAR_STATION="$1"

report="$(timeout 30 metar -d "${METAR_STATION}" 2>/dev/null | tail -n +2)"
if [[ -z "${report//[[:space:]]/}" ]]; then
  echo "get_weather: no METAR data for ${METAR_STATION}" >&2
  echo "Time for the weather. The METAR station in Antarctica is not reporting right now. Perhaps the wind took the antenna."
  exit 0
fi

echo "Time for the weather. Information from a METAR station in Antarctica. $report"
