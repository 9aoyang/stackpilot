#!/usr/bin/env bash
# Sync stackpilot skills to ~/.claude/skills/ (idempotent, fast)
# Adds missing skills without touching existing ones. Safe to run from hooks.
#
# Modes:
#   (default)        symlink — for developers working in the repo
#   --copy           copy    — for users who installed via install.sh
#   --auto-update    check remote for updates, pull if needed, then sync
set -euo pipefail

SKILLS_DST="$HOME/.claude/skills"
LAST_CHECK_FILE="$SKILLS_DST/.stackpilot-last-check"
CHECK_INTERVAL=86400  # 24 hours

# --- Locate the stackpilot repo ---
find_repo() {
  # 1. Script is inside the repo (developer path)
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local candidate="$(dirname "$script_dir")"
  if [ -d "$candidate/.git" ] && [ -d "$candidate/claude-config/skills" ]; then
    echo "$candidate"; return
  fi
  # 2. Explicit env var
  if [ -n "${STACKPILOT_DIR:-}" ] && [ -d "$STACKPILOT_DIR/.git" ]; then
    echo "$STACKPILOT_DIR"; return
  fi
  # 3. Follow symlink from installed skill
  local skill_link="$SKILLS_DST/stackpilot"
  if [ -L "$skill_link" ]; then
    local target
    target="$(readlink "$skill_link")"
    local repo="${target%/claude-config/skills/stackpilot*}"
    if [ -d "$repo/.git" ]; then
      echo "$repo"; return
    fi
  fi
  # 4. Default install location
  if [ -d "$HOME/.stackpilot/.git" ]; then
    echo "$HOME/.stackpilot"; return
  fi
  return 1
}

REPO_DIR="$(find_repo)" || { echo "[stackpilot] Cannot locate repo" >&2; exit 1; }
SKILLS_SRC="$REPO_DIR/claude-config/skills"
MODE="symlink"

# --- Parse flags ---
AUTO_UPDATE=false
for arg in "$@"; do
  case "$arg" in
    --copy) MODE="copy" ;;
    --auto-update) AUTO_UPDATE=true ;;
  esac
done

# --- Auto-update: fetch + pull if stale ---
if $AUTO_UPDATE; then
  should_check() {
    [ ! -f "$LAST_CHECK_FILE" ] && return 0
    local last_check now
    last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    [ $((now - last_check)) -ge $CHECK_INTERVAL ]
  }

  if should_check; then
    mkdir -p "$SKILLS_DST"
    date +%s > "$LAST_CHECK_FILE"

    if git -C "$REPO_DIR" fetch --quiet 2>/dev/null; then
      LOCAL_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)
      REMOTE_HEAD=$(git -C "$REPO_DIR" rev-parse origin/main 2>/dev/null || echo "")

      if [ -n "$REMOTE_HEAD" ] && [ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]; then
        LOCAL_VER=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "?")
        if git -C "$REPO_DIR" pull --ff-only origin main 2>/dev/null; then
          REMOTE_VER=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "?")
          echo "[stackpilot] Updated $LOCAL_VER → $REMOTE_VER"
          # After pull, force re-sync all skills
          if [ "$MODE" = "symlink" ]; then
            # Symlinks auto-resolve, just add missing ones
            :
          else
            # Copy mode: re-copy all stackpilot skills to pick up changes
            for skill_dir in "$SKILLS_SRC/"*/; do
              [ -d "$skill_dir" ] || continue
              skill_name="$(basename "$skill_dir")"
              rm -rf "$SKILLS_DST/$skill_name"
              cp -r "$skill_dir" "$SKILLS_DST/$skill_name"
            done
            echo "[stackpilot] Skills refreshed"
            exit 0
          fi
        else
          echo "[stackpilot] Update available but auto-pull failed (local changes?)"
          echo "  Run: cd $REPO_DIR && git pull"
        fi
      fi
    fi
  fi
fi

# --- Sync: add missing skills ---
mkdir -p "$SKILLS_DST"

changed=0
for skill_dir in "$SKILLS_SRC/"*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DST/$skill_name"

  # Skip if already installed (symlink or directory)
  [ -e "$target" ] && continue

  if [ "$MODE" = "symlink" ]; then
    ln -sf "$skill_dir" "$target"
  else
    cp -r "$skill_dir" "$target"
  fi
  echo "  ✓ $skill_name"
  changed=$((changed + 1))
done

[ $changed -gt 0 ] && echo "[stackpilot] Synced $changed new skill(s)"
exit 0
