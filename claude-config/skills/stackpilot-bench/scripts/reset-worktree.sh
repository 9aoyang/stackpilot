#!/usr/bin/env bash
set -euo pipefail

# reset-worktree.sh — Reset a benchmark worktree to fixture state.
#
# Usage: reset-worktree.sh <worktree_path> <fixture_source_dir>
#
# Steps:
#   1. Validate inputs
#   2. Read base SHA from marker file .bench-base-sha
#   3. git reset --hard <base_sha> + git clean -fdx
#   4. rsync fixture contents on top (--delete removes leg-added files)
#   5. Print OK on success

WORKTREE_PATH="${1:-}"
FIXTURE_SOURCE_DIR="${2:-}"

# ---------------------------------------------------------------------------
# Step 1: Input validation
# ---------------------------------------------------------------------------

if [[ -z "$WORKTREE_PATH" || -z "$FIXTURE_SOURCE_DIR" ]]; then
  echo "reset-worktree: ERROR: usage: reset-worktree.sh <worktree_path> <fixture_source_dir>" >&2
  exit 2
fi

# Resolve to absolute paths for reliable comparison
WORKTREE_PATH="$(cd "$WORKTREE_PATH" 2>/dev/null && pwd)" || {
  echo "reset-worktree: ERROR: worktree_path does not exist: ${1}" >&2
  exit 2
}

FIXTURE_SOURCE_DIR="$(cd "$FIXTURE_SOURCE_DIR" 2>/dev/null && pwd)" || {
  echo "reset-worktree: ERROR: fixture_source_dir does not exist: ${2}" >&2
  exit 2
}

# worktree_path must be inside .worktrees/
if [[ "$WORKTREE_PATH" != *"/.worktrees/"* ]]; then
  echo "reset-worktree: ERROR: worktree_path must be inside .worktrees/ — got: $WORKTREE_PATH" >&2
  exit 2
fi

# fixture_source_dir must be a directory
if [[ ! -d "$FIXTURE_SOURCE_DIR" ]]; then
  echo "reset-worktree: ERROR: fixture_source_dir is not a directory: $FIXTURE_SOURCE_DIR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 2: Read base SHA from marker file
# ---------------------------------------------------------------------------

MARKER_FILE="$WORKTREE_PATH/.bench-base-sha"

if [[ ! -f "$MARKER_FILE" ]]; then
  echo "reset-worktree: ERROR: marker file missing — expected $MARKER_FILE (runner must write this when creating the worktree)" >&2
  exit 3
fi

BASE_SHA="$(< "$MARKER_FILE")"
BASE_SHA="${BASE_SHA// /}"  # strip any accidental whitespace

if [[ -z "$BASE_SHA" ]]; then
  echo "reset-worktree: ERROR: marker file is empty: $MARKER_FILE" >&2
  exit 3
fi

# ---------------------------------------------------------------------------
# Step 3: Reset worktree to base SHA
# ---------------------------------------------------------------------------

git -C "$WORKTREE_PATH" reset --hard "$BASE_SHA" 2>&1 || {
  echo "reset-worktree: ERROR: git reset --hard $BASE_SHA failed in $WORKTREE_PATH" >&2
  exit 1
}

git -C "$WORKTREE_PATH" clean -fdx 2>&1 || {
  echo "reset-worktree: ERROR: git clean -fdx failed in $WORKTREE_PATH" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Step 4: Copy fixture contents on top (idempotent via --delete)
# ---------------------------------------------------------------------------

rsync -a --delete "$FIXTURE_SOURCE_DIR/" "$WORKTREE_PATH/" 2>&1 || {
  echo "reset-worktree: ERROR: rsync failed (fixture_source_dir=$FIXTURE_SOURCE_DIR, worktree_path=$WORKTREE_PATH)" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Step 5: Success
# ---------------------------------------------------------------------------

echo "reset-worktree: OK $WORKTREE_PATH"
