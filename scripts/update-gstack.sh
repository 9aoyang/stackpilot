#!/usr/bin/env bash
# Stackpilot gstack auto-updater
# Run weekly: every Monday at 3:00 AM via cron
# Usage: ./scripts/update-gstack.sh [--gstack-dir PATH]

set -euo pipefail

GSTACK_DIR="${GSTACK_DIR:-$HOME/.claude/skills/gstack}"
LOG_FILE="${LOG_FILE:-/tmp/stackpilot-gstack-update.log}"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gstack-dir) GSTACK_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

notify() {
  local title="$1" message="$2"
  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# Core skills that must exist after update
REQUIRED_SKILLS=(
  "plan-eng-review"
  "qa"
  "ship"
  "review"
  "investigate"
)

verify_skills() {
  local dir="$1"
  for skill in "${REQUIRED_SKILLS[@]}"; do
    # Skills may be .md files or directories - just check they exist
    if ! ls "$dir/$skill"* >/dev/null 2>&1 && ! [ -d "$dir/$skill" ]; then
      log "MISSING skill: $skill"
      return 1
    fi
  done
  log "All required skills verified: ${REQUIRED_SKILLS[*]}"
  return 0
}

log "=== gstack update started ==="

# Check if gstack dir exists
if [ ! -d "$GSTACK_DIR" ]; then
  log "ERROR: gstack directory not found: $GSTACK_DIR"
  notify "Stackpilot: gstack update failed" "gstack not installed at $GSTACK_DIR. Run: git clone https://github.com/garrytan/gstack $GSTACK_DIR"
  exit 1
fi

# Save current HEAD for rollback
cd "$GSTACK_DIR"
PREV_HEAD=$(git rev-parse HEAD)
log "Current HEAD: $PREV_HEAD"

# Attempt pull
if ! git pull --ff-only origin main >> "$LOG_FILE" 2>&1; then
  log "Pull failed (non-fast-forward or network error)"
  notify "Stackpilot: gstack update failed" "git pull failed — see $LOG_FILE"
  exit 1
fi

NEW_HEAD=$(git rev-parse HEAD)

if [ "$PREV_HEAD" = "$NEW_HEAD" ]; then
  log "Already up to date, no changes"
  exit 0
fi

log "Updated to: $NEW_HEAD"

# Verify required skills exist
if ! verify_skills "$GSTACK_DIR"; then
  log "Verification failed — rolling back to $PREV_HEAD"
  git reset --hard "$PREV_HEAD" >> "$LOG_FILE" 2>&1
  notify "Stackpilot: gstack update rolled back" "Skill verification failed after update. Rolled back to $PREV_HEAD. See $LOG_FILE"
  exit 1
fi

log "=== gstack update completed successfully ==="
# Silent on success — no notification needed
