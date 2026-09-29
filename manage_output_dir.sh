#!/usr/bin/env bash
#
# Prepare OUTPUT_DIR for a new batch and print the path of a *staging*
# directory to build it in. The caller renames the staging directory to its
# final YYYYMMDDTHHMMSS name once the batch is complete (see whisper.sh), so
# playlist.sh never sees a half-built batch.
#
# Cleanup: every finished batch except the one the cursor is playing from is
# deleted, as are leftover staging directories from crashed runs. Nothing
# outside OUTPUT_DIR is ever touched, and only directories matching the
# batch naming pattern are considered.
#
# Usage: manage_output_dir.sh <output_dir>

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <output_dir>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

OUTPUT_DIR="$(realpath -m "$1")"
mkdir -p "$OUTPUT_DIR"

if [[ "$OUTPUT_DIR" == "/" || "$OUTPUT_DIR" == "$HOME" ]]; then
  echo "Refusing to manage $OUTPUT_DIR as an output directory" >&2
  exit 1
fi

CURSOR_DIRECTORY=""
if [[ -s "${CURSOR_FILE:-}" ]]; then
  CURSOR_DIRECTORY="$(realpath -m "$(dirname "$(head -n 1 "$CURSOR_FILE")")")"
fi

while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  if [[ "$(realpath -m "$dir")" == "$CURSOR_DIRECTORY" ]]; then
    continue
  fi
  echo "Cleanup: deleting ${dir}" >&2
  rm -rf -- "$dir"
done < <(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended \
           -regex '.*/(\.build_)?[0-9]{8}T[0-9]{6}$')

BATCH_TIMESTAMP="$(date +%Y%m%dT%H%M%S)"
STAGING_DIR="${OUTPUT_DIR}/.build_${BATCH_TIMESTAMP}"
mkdir -p "$STAGING_DIR"
echo "$STAGING_DIR"
