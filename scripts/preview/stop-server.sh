#!/usr/bin/env bash
# Stop a preview server.
#
# Modes:
#   stop-server.sh <session_dir>      Legacy: kill the brainstorm server tracked
#                                     under <session_dir>/state/server.pid. Only
#                                     /tmp/ sessions are deleted; persistent
#                                     dirs (.superpowers/) are kept for review.
#   stop-server.sh --slug <name>      v2.0 sprint mode: resolve the server tied
#                                     to that sprint slug by reading
#                                     .stackpilot/views/<name>/.server-info.json
#                                     (written by server.cjs when started with
#                                     --sprint-slug). Then performs the same
#                                     graceful kill + cleanup as legacy mode.
#   stop-server.sh --help             Print this usage block.

set -u

usage() {
  sed -n '2,16p' "$0" | sed 's/^# //'
}

MODE="legacy"
SLUG=""
SESSION_DIR=""
PROJECT_ROOT="${STACKPILOT_ROOT:-$PWD}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --slug)
      MODE="sprint"
      SLUG="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    *)
      if [[ -z "$SESSION_DIR" ]]; then
        SESSION_DIR="$1"
      fi
      shift
      ;;
  esac
done

# Resolve sprint mode → session_dir via marker file
if [[ "$MODE" == "sprint" ]]; then
  if [[ -z "$SLUG" ]]; then
    echo '{"error": "--slug requires a value"}'; exit 1
  fi
  MARKER="$PROJECT_ROOT/.stackpilot/views/$SLUG/.server-info.json"
  if [[ ! -f "$MARKER" ]]; then
    echo "{\"status\": \"not_running\", \"slug\": \"$SLUG\", \"reason\": \"no marker at $MARKER\"}"
    exit 0
  fi
  # Extract session_dir without jq dependency (POSIX-friendly)
  SESSION_DIR=$(sed -n 's/.*"session_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MARKER" | head -1)
  if [[ -z "$SESSION_DIR" ]]; then
    echo "{\"error\": \"could not parse session_dir from $MARKER\"}"; exit 1
  fi
fi

if [[ -z "$SESSION_DIR" ]]; then
  usage
  exit 1
fi

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"

if [[ -f "$PID_FILE" ]]; then
  pid=$(cat "$PID_FILE")

  kill "$pid" 2>/dev/null || true

  for i in {1..20}; do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.1
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
    sleep 0.1
  fi

  if kill -0 "$pid" 2>/dev/null; then
    echo '{"status": "failed", "error": "process still running"}'
    exit 1
  fi

  rm -f "$PID_FILE" "${STATE_DIR}/server.log"

  # Clean sprint marker if applicable
  if [[ -n "$SLUG" ]]; then
    rm -f "$PROJECT_ROOT/.stackpilot/views/$SLUG/.server-info.json" 2>/dev/null || true
  fi

  if [[ "$SESSION_DIR" == /tmp/* ]]; then
    rm -rf "$SESSION_DIR"
  fi

  echo '{"status": "stopped"}'
else
  echo '{"status": "not_running"}'
fi
