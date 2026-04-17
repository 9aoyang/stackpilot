#!/usr/bin/env bash
set -euo pipefail

# reset-worktree.sh — Reset the benchmark sandbox to fixture state.
#
# Usage: reset-worktree.sh <worktree_path> <sandbox_source_dir>
#
# Sandbox model (v2):
#   The workload operates inside <worktree_path>/bench-sandbox/, NOT at the
#   worktree root. This preserves the rest of the worktree's files (CLAUDE.md,
#   claude-config/, .stackpilot/, etc.) so dispatched agents have context.
#
#   The script:
#     1. git reset --hard <base_sha> in the worktree (undoes ALL changes from
#        the prior leg, including anything stray written outside bench-sandbox/)
#     2. rm -rf <worktree>/bench-sandbox && cp -r <sandbox_source>/ to it
#     3. git add bench-sandbox/ && git commit with --no-verify (creates a
#        "leg start" commit; its SHA is printed on stdout for the runner to
#        use as the diff base when capturing post-leg diffs).
#
# Output on success (stdout):
#   reset-worktree: OK <leg_start_sha>
#
# Exit codes:
#   0  success
#   2  usage / bad arguments
#   3  base-SHA marker missing
#   1  git or rsync operation failed

WORKTREE_PATH="${1:-}"
SANDBOX_SOURCE_DIR="${2:-}"

# ---------------------------------------------------------------------------
# Step 1: Validate inputs
# ---------------------------------------------------------------------------

if [[ -z "$WORKTREE_PATH" || -z "$SANDBOX_SOURCE_DIR" ]]; then
  echo "reset-worktree: ERROR: usage: reset-worktree.sh <worktree_path> <sandbox_source_dir>" >&2
  exit 2
fi

WORKTREE_PATH="$(cd "$WORKTREE_PATH" 2>/dev/null && pwd)" || {
  echo "reset-worktree: ERROR: worktree_path does not exist: ${1}" >&2
  exit 2
}

SANDBOX_SOURCE_DIR="$(cd "$SANDBOX_SOURCE_DIR" 2>/dev/null && pwd)" || {
  echo "reset-worktree: ERROR: sandbox_source_dir does not exist: ${2}" >&2
  exit 2
}

if [[ "$WORKTREE_PATH" != *"/.worktrees/"* ]]; then
  echo "reset-worktree: ERROR: worktree_path must be inside .worktrees/ — got: $WORKTREE_PATH" >&2
  exit 2
fi

if [[ ! -d "$SANDBOX_SOURCE_DIR" ]]; then
  echo "reset-worktree: ERROR: sandbox_source_dir is not a directory: $SANDBOX_SOURCE_DIR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 2: Read base SHA marker
# ---------------------------------------------------------------------------

MARKER_FILE="$WORKTREE_PATH/.bench-base-sha"

if [[ ! -f "$MARKER_FILE" ]]; then
  echo "reset-worktree: ERROR: marker file missing — expected $MARKER_FILE" >&2
  exit 3
fi

BASE_SHA="$(< "$MARKER_FILE")"
BASE_SHA="${BASE_SHA//[[:space:]]/}"

if [[ -z "$BASE_SHA" ]]; then
  echo "reset-worktree: ERROR: marker file is empty: $MARKER_FILE" >&2
  exit 3
fi

# ---------------------------------------------------------------------------
# Step 3: Reset worktree to base SHA (undo prior leg)
# ---------------------------------------------------------------------------

git -C "$WORKTREE_PATH" reset --hard "$BASE_SHA" >/dev/null || {
  echo "reset-worktree: ERROR: git reset --hard $BASE_SHA failed" >&2
  exit 1
}

# Clean untracked files BUT preserve the marker file we wrote ourselves.
# Move marker out, clean, move back.
cp "$MARKER_FILE" "/tmp/.bench-base-sha.$$"
git -C "$WORKTREE_PATH" clean -fdx >/dev/null || {
  rm -f "/tmp/.bench-base-sha.$$"
  echo "reset-worktree: ERROR: git clean -fdx failed" >&2
  exit 1
}
mv "/tmp/.bench-base-sha.$$" "$MARKER_FILE"

# ---------------------------------------------------------------------------
# Step 4: Install sandbox fixture
# ---------------------------------------------------------------------------

SANDBOX_TARGET="$WORKTREE_PATH/bench-sandbox"

rm -rf "$SANDBOX_TARGET"
cp -R "$SANDBOX_SOURCE_DIR" "$SANDBOX_TARGET" || {
  echo "reset-worktree: ERROR: cp -R $SANDBOX_SOURCE_DIR $SANDBOX_TARGET failed" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Step 5: Commit the fixture so a scoped diff is clean after the leg runs
# ---------------------------------------------------------------------------

git -C "$WORKTREE_PATH" add bench-sandbox/ >/dev/null || {
  echo "reset-worktree: ERROR: git add bench-sandbox/ failed" >&2
  exit 1
}

# --no-verify: skip the main-repo pre-commit hook (VERSION / CHANGELOG / etc.
# checks). The bench worktree has disposable commits; hook enforcement
# belongs on main, not here.
#
# Use a fixed author/committer so identity config isn't required in worktrees.
GIT_AUTHOR_NAME="stackpilot-bench" \
GIT_AUTHOR_EMAIL="bench@stackpilot.local" \
GIT_COMMITTER_NAME="stackpilot-bench" \
GIT_COMMITTER_EMAIL="bench@stackpilot.local" \
  git -C "$WORKTREE_PATH" commit --no-verify -m "bench: leg-start fixture" >/dev/null || {
    echo "reset-worktree: ERROR: git commit failed" >&2
    exit 1
  }

LEG_START_SHA="$(git -C "$WORKTREE_PATH" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Step 6: Success
# ---------------------------------------------------------------------------

echo "reset-worktree: OK $LEG_START_SHA"
