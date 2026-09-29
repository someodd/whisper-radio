#!/usr/bin/env bash
#
# Keep ezstream alive and actually streaming.
#
#   manage_ezstream.sh <project_root>
#
# - Tracks ezstream by pidfile (ezstream -p), not by grepping process names.
# - Logs ezstream's own output to EZSTREAM_LOG so a crash leaves evidence.
# - Treats "process exists" as insufficient: it also asks Icecast whether the
#   mountpoint is live. A running ezstream whose mount has been gone is
#   restarted. (ezstream reconnects on its own after a *dropped* connection,
#   but it exits when the initial connection fails or after 100 consecutive
#   unreadable tracks, and it can wedge on a stuck playlist program.)
# - Starts ezstream fully detached (setsid) so it outlives the cron job.

set -uo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <project_root>" >&2
  exit 1
fi

PROJECT_ROOT="$(realpath -m "$1")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

EZSTREAM_CONFIG="${EZSTREAM_CONFIG:-${PROJECT_ROOT}/ezstream.xml}"
EZSTREAM_PIDFILE="${EZSTREAM_PIDFILE:-${PROJECT_ROOT}/ezstream.pid}"
EZSTREAM_LOG="${EZSTREAM_LOG:-${PROJECT_ROOT}/ezstream.log}"

log() { echo "[ezstream] $*" >&2; }

if [[ ! -r "$EZSTREAM_CONFIG" ]]; then
  log "config not found: $EZSTREAM_CONFIG"
  exit 1
fi

# --- Icecast details from the ezstream config -------------------------------
xml() { xmlstarlet sel -t -v "$1" "$EZSTREAM_CONFIG" 2>/dev/null | head -n 1; }
ICE_HOST="$(xml '/ezstream/servers/server/hostname')"; ICE_HOST="${ICE_HOST:-127.0.0.1}"
ICE_PORT="$(xml '/ezstream/servers/server/port')";     ICE_PORT="${ICE_PORT:-8000}"
ICE_MOUNT="$(xml '/ezstream/streams/stream/mountpoint')"
[[ "$ICE_MOUNT" == /* ]] || ICE_MOUNT="/${ICE_MOUNT}"

# --- helpers ----------------------------------------------------------------
running_pid() {
  # Prints the pid from the pidfile if that pid is a live ezstream.
  local pid
  [[ -s "$EZSTREAM_PIDFILE" ]] || return 1
  pid="$(tr -dc '0-9' < "$EZSTREAM_PIDFILE")"
  [[ -n "$pid" && -d "/proc/$pid" ]] || return 1
  tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'ezstream' || return 1
  echo "$pid"
}

# 0 = mount is live, 1 = mount missing, 2 = icecast unreachable
mount_status() {
  local json
  json="$(curl -fsS --max-time 10 "http://${ICE_HOST}:${ICE_PORT}/status-json.xsl" 2>/dev/null)" || return 2
  jq -e --arg m "$ICE_MOUNT" '
      [ .icestats.source // [] | if type == "array" then .[] else . end ]
      | map(select((.listenurl // "") | endswith($m)))
      | length > 0' <<<"$json" >/dev/null 2>&1
}

stop_ezstream() {
  local pid="$1"
  log "stopping pid $pid"
  kill -TERM "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -d "/proc/$pid" ]] || break
    sleep 1
  done
  if [[ -d "/proc/$pid" ]]; then
    log "pid $pid ignored TERM, sending KILL"
    kill -KILL "$pid" 2>/dev/null || true
    sleep 1
  fi
  rm -f "$EZSTREAM_PIDFILE"
}

start_ezstream() {
  log "starting ezstream (log: $EZSTREAM_LOG)"
  echo "=== $(date) manage_ezstream.sh starting ezstream ===" >> "$EZSTREAM_LOG"
  (
    cd "$PROJECT_ROOT" || exit 1
    setsid nohup ezstream -c "$EZSTREAM_CONFIG" -p "$EZSTREAM_PIDFILE" \
      >> "$EZSTREAM_LOG" 2>&1 < /dev/null &
  )
  sleep 3
  local pid
  if pid="$(running_pid)"; then
    log "ezstream running with pid $pid"
  else
    log "ezstream failed to start; see $EZSTREAM_LOG"
    tail -n 5 "$EZSTREAM_LOG" >&2 || true
    return 1
  fi
}

# --- main -------------------------------------------------------------------
if pid="$(running_pid)"; then
  mount_status
  case $? in
    0) log "running (pid $pid) and mount ${ICE_MOUNT} is live" ;;
    1) log "running (pid $pid) but mount ${ICE_MOUNT} is not on Icecast; restarting"
       stop_ezstream "$pid"
       start_ezstream ;;
    2) log "running (pid $pid); Icecast at ${ICE_HOST}:${ICE_PORT} unreachable, leaving ezstream to reconnect" ;;
    *) log "running (pid $pid); could not parse Icecast status, leaving it alone" ;;
  esac
else
  rm -f "$EZSTREAM_PIDFILE"
  mount_status
  if [[ $? -eq 2 ]]; then
    log "not running and Icecast at ${ICE_HOST}:${ICE_PORT} is unreachable; will retry next run"
    exit 1
  fi
  log "not running"
  start_ezstream
fi
