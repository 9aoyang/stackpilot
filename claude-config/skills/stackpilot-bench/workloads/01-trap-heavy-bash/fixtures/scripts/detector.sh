#!/usr/bin/env bash
# detector.sh — synthetic framework detector for stackpilot-bench workload 01
# Detects the primary language/framework of the current project and emits a
# single JSON object to stdout:  {"framework":"<name>","confidence":"high|low"}
# All diagnostic / error messages go to stderr.
#
# Usage: detector.sh [-q] [-h] [DIR]
#   -q        Quiet mode: suppress all stderr output
#   -h        Print this help and exit 0
#   DIR       Directory to inspect (default: current directory)

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
QUIET=0
TARGET_DIR="."
FRAMEWORK=""
CONFIDENCE="high"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
}

log() {
  # Write to stderr unless quiet mode is active
  if [[ "$QUIET" -eq 0 ]]; then
    printf '%s\n' "$*" >&2
  fi
}

die() {
  printf 'detector: error: %s\n' "$*" >&2
  exit 1
}

emit_result() {
  local fw="$1"
  local conf="$2"
  # JSON output always goes to stdout so callers can pipe:  detector.sh | jq .
  printf '{"framework":"%s","confidence":"%s"}\n' "$fw" "$conf"
}

# ---------------------------------------------------------------------------
# Detection checks
# ---------------------------------------------------------------------------

check_node() {
  local dir="$1"
  if [ -f "${dir}/package.json" ]; then
    # Exclude commented manifest lines that tooling sometimes leaves behind
    if grep -q '"name"' "${dir}/package.json" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

check_rust() {
  local dir="$1"
  if [ -f "${dir}/Cargo.toml" ]; then
    if grep -q '^\[package\]' "${dir}/Cargo.toml" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

check_go() {
  local dir="$1"
  if [ -f "${dir}/go.mod" ]; then
    if grep -q '^module ' "${dir}/go.mod" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

check_python() {
  local dir="$1"
  if [ -f "${dir}/pyproject.toml" ]; then
    if grep -q '^\[tool\.' "${dir}/pyproject.toml" 2>/dev/null; then
      return 0
    fi
  fi
  # Fallback: plain requirements or setup.py
  if [ -f "${dir}/requirements.txt" ] || [ -f "${dir}/setup.py" ]; then
    CONFIDENCE="low"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while getopts ":qh" opt; do
  case "$opt" in
    q) QUIET=1 ;;
    h) usage; exit 0 ;;
    :) die "option -${OPTARG} requires an argument" ;;
    \?) die "unknown option: -${OPTARG}" ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -gt 0 ]]; then
  TARGET_DIR="$1"
fi

[[ -d "$TARGET_DIR" ]] || die "directory not found: ${TARGET_DIR}"

# ---------------------------------------------------------------------------
# Main detection loop
# ---------------------------------------------------------------------------

log "Starting framework detection in: ${TARGET_DIR}"

if check_node "$TARGET_DIR"; then
  FRAMEWORK="node"
elif check_rust "$TARGET_DIR"; then
  FRAMEWORK="rust"
elif check_go "$TARGET_DIR"; then
  FRAMEWORK="go"
elif check_python "$TARGET_DIR"; then
  FRAMEWORK="python"
else
  FRAMEWORK="unknown"
  CONFIDENCE="low"
fi

log "Detection complete: framework=${FRAMEWORK} confidence=${CONFIDENCE}"

emit_result "$FRAMEWORK" "$CONFIDENCE"
