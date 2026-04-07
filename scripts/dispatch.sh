#!/usr/bin/env bash
# Stackpilot Dispatcher — model-agnostic agent execution
# Routes agent prompts to the configured AI provider CLI.
#
# Usage:
#   dispatch.sh --agent <name> --prompt "<text>" [options]
#
# Options:
#   --agent <name>        Agent name (matches claude-config/agents/<name>.md)
#   --prompt <text>       Task-specific prompt to send
#   --tools <list>        Comma-separated tool list (claude only, ignored by others)
#   --project-dir <path>  Project root (reads stackpilot.config.yml from here)
#   --background          Run in background
#   --log <path>          Redirect output to log file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKPILOT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

# ── Parse arguments ──────────────────────────────────────────────────────────

AGENT=""
PROMPT=""
TOOLS=""
PROJECT_DIR=""
BACKGROUND=false
LOG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)      AGENT="$2"; shift 2 ;;
    --prompt)     PROMPT="$2"; shift 2 ;;
    --tools)      TOOLS="$2"; shift 2 ;;
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --background) BACKGROUND=true; shift ;;
    --log)        LOG_FILE="$2"; shift 2 ;;
    *) echo "[dispatch] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AGENT" ] || [ -z "$PROMPT" ]; then
  echo "[dispatch] Error: --agent and --prompt are required" >&2
  exit 1
fi

# ── Load config ──────────────────────────────────────────────────────────────

CONFIG_FILE=""
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/stackpilot.config.yml" ]; then
  CONFIG_FILE="$PROJECT_DIR/stackpilot.config.yml"
fi

PROVIDER="$(config_get_or "provider.name" "claude" "${CONFIG_FILE:-/dev/null}")"

# ── Read timeout from config (default 2 hours) ─────────────────────────────

TIMEOUT_HOURS="$(config_get_or "coordinator.timeout_hours" "2" "${CONFIG_FILE:-/dev/null}")"
TIMEOUT_SECS=$(( TIMEOUT_HOURS * 3600 ))

# ── Load agent prompt ────────────────────────────────────────────────────────

AGENT_FILE="$STACKPILOT_DIR/claude-config/agents/${AGENT}.md"
if [ ! -f "$AGENT_FILE" ]; then
  echo "[dispatch] Error: agent file not found: $AGENT_FILE" >&2
  exit 1
fi

AGENT_PROMPT="$(strip_frontmatter "$AGENT_FILE")"

# For claude provider, extract tools from frontmatter if --tools not provided
if [ "$PROVIDER" = "claude" ] && [ -z "$TOOLS" ]; then
  FM_TOOLS="$(get_frontmatter_field "$AGENT_FILE" "tools" 2>/dev/null || true)"
  if [ -n "$FM_TOOLS" ]; then
    TOOLS="$FM_TOOLS"
  fi
fi

# Combine agent system prompt with task prompt
FULL_PROMPT="${AGENT_PROMPT}

${PROMPT}"

# ── Build provider-specific command ──────────────────────────────────────────

# resolve_model <provider> <agent> <config_file>
# Lookup order: models.<provider>.<agent> → models.<provider>.default → provider.model
resolve_model() {
  local prov="$1" agent="$2" cfg="$3"
  local model=""
  # 1. Per-provider per-agent: models.claude.sp-dev
  model="$(config_get_or "models.${prov}.${agent}" "" "$cfg")"
  # 2. Per-provider default: models.claude.default
  if [ -z "$model" ]; then
    model="$(config_get_or "models.${prov}.default" "" "$cfg")"
  fi
  # 3. Global fallback: provider.model
  if [ -z "$model" ]; then
    model="$(config_get_or "provider.model" "" "$cfg")"
  fi
  echo "$model"
}

build_cmd() {
  local model
  case "$PROVIDER" in
    claude)
      CMD=(claude -p "$FULL_PROMPT")
      if [ -n "$TOOLS" ]; then
        IFS=',' read -ra TOOL_ARRAY <<< "$TOOLS"
        for tool in "${TOOL_ARRAY[@]}"; do
          tool="$(echo "$tool" | xargs)"  # trim whitespace
          CMD+=(--allowedTools "$tool")
        done
      fi
      model="$(resolve_model "$PROVIDER" "$AGENT" "${CONFIG_FILE:-/dev/null}")"
      if [ -n "$model" ]; then
        CMD+=(--model "$model")
      fi
      ;;
    codex)
      local approval
      approval="$(config_get_or "provider.codex.approval_mode" "full-auto" "${CONFIG_FILE:-/dev/null}")"
      CMD=(codex --quiet "--approval-mode" "$approval" "$FULL_PROMPT")
      model="$(resolve_model "$PROVIDER" "$AGENT" "${CONFIG_FILE:-/dev/null}")"
      if [ -n "$model" ]; then
        CMD+=(--model "$model")
      fi
      ;;
    gemini)
      CMD=(gemini -p "$FULL_PROMPT")
      model="$(resolve_model "$PROVIDER" "$AGENT" "${CONFIG_FILE:-/dev/null}")"
      if [ -n "$model" ]; then
        CMD+=(--model "$model")
      fi
      ;;
    custom)
      local custom_cmd
      custom_cmd="$(config_get_or "provider.command" "" "${CONFIG_FILE:-/dev/null}")"
      if [ -z "$custom_cmd" ]; then
        echo "[dispatch] Error: provider.command is required when provider.name=custom" >&2
        exit 1
      fi
      # Split custom command into array (supports multi-word commands)
      read -ra CMD <<< "$custom_cmd"
      CMD+=("$FULL_PROMPT")
      ;;
    *)
      echo "[dispatch] Error: unknown provider '$PROVIDER'" >&2
      exit 1
      ;;
  esac
}

build_cmd

# ── Check CLI availability ───────────────────────────────────────────────────

CLI_BIN="${CMD[0]}"
if ! command -v "$CLI_BIN" >/dev/null 2>&1; then
  echo "[dispatch] Error: $CLI_BIN not found in PATH — cannot run $AGENT" >&2
  # Write to NEEDS_REVIEW.md so the user is alerted
  if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/.stackpilot/tasks" ]; then
    REVIEW_FILE="$PROJECT_DIR/.stackpilot/tasks/NEEDS_REVIEW.md"
    {
      echo ""
      echo "[DISPATCH] CLI '$CLI_BIN' not found — agent '$AGENT' could not be started"
      echo "Option A: Install $CLI_BIN and retry"
      echo "Option B: Change provider in stackpilot.config.yml"
      echo "Recommendation: Option A"
    } >> "$REVIEW_FILE"
  fi
  exit 1
fi

# ── Git worktree isolation for background agents ────────────────────────────
# When running in background with a project dir, create a git worktree so
# the agent works on an isolated copy of the repo (no interference with
# other agents or the user's working directory).

WORKTREE_DIR=""
if $BACKGROUND && [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/.git" ]; then
  WORKTREE_BASE="$PROJECT_DIR/.stackpilot/.worktrees"
  mkdir -p "$WORKTREE_BASE" 2>/dev/null || true
  WORKTREE_DIR="$WORKTREE_BASE/${AGENT}-$$"
  WORKTREE_BRANCH="stackpilot/${AGENT}-$$"

  # Create worktree from current HEAD
  if git -C "$PROJECT_DIR" worktree add -q -b "$WORKTREE_BRANCH" "$WORKTREE_DIR" HEAD 2>/dev/null; then
    echo "[dispatch] Created worktree: $WORKTREE_DIR (branch: $WORKTREE_BRANCH)"
    # Agent prompt gets the worktree path
    FULL_PROMPT="${FULL_PROMPT}

Working directory (git worktree): ${WORKTREE_DIR}
Run all commands in this directory. When done, commit your changes to branch ${WORKTREE_BRANCH}."
  else
    echo "[dispatch] Warning: could not create worktree — running in project dir" >&2
    WORKTREE_DIR=""
  fi
fi

# ── State file locking helper ────────────────────────────────────────────────
# Wraps commands that write to shared state files (.stackpilot/tasks/*.yml)
# Uses flock if available, falls back to mkdir-based locking

LOCK_DIR=""
if [ -n "$PROJECT_DIR" ]; then
  LOCK_DIR="$PROJECT_DIR/.stackpilot/.locks"
  mkdir -p "$LOCK_DIR" 2>/dev/null || true
fi

# ── Timeout wrapper ─────────────────────────────────────────────────────────
# Prefix for background commands — enforces max runtime from config

TIMEOUT_CMD=()
if $BACKGROUND && [ "$TIMEOUT_SECS" -gt 0 ] 2>/dev/null; then
  # macOS ships with GNU coreutils timeout via brew, or use perl fallback
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD=(timeout "$TIMEOUT_SECS")
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD=(gtimeout "$TIMEOUT_SECS")
  fi
  # If neither available, skip timeout (logged below)
fi

# ── Execute ──────────────────────────────────────────────────────────────────

if [ ${#TIMEOUT_CMD[@]} -gt 0 ]; then
  FULL_CMD=("${TIMEOUT_CMD[@]}" "${CMD[@]}")
else
  FULL_CMD=("${CMD[@]}")
fi

if $BACKGROUND; then
  if [ ${#TIMEOUT_CMD[@]} -eq 0 ]; then
    echo "[dispatch] Warning: timeout command not found — agent has no time limit" >&2
  fi
  if [ -n "$LOG_FILE" ]; then
    "${FULL_CMD[@]}" >> "$LOG_FILE" 2>&1 &
  else
    "${FULL_CMD[@]}" >/dev/null 2>&1 &
  fi
  AGENT_PID=$!
  echo "[dispatch] $AGENT started in background (PID $AGENT_PID, provider=$PROVIDER, timeout=${TIMEOUT_HOURS}h)"
  # Write PID to lock dir for crash recovery
  if [ -n "$LOCK_DIR" ]; then
    echo "$AGENT_PID" > "$LOCK_DIR/${AGENT}.pid"
  fi
  # Schedule worktree cleanup after agent exits
  if [ -n "$WORKTREE_DIR" ]; then
    (
      wait "$AGENT_PID" 2>/dev/null
      # Check if agent made commits on its branch
      if git -C "$PROJECT_DIR" log --oneline "${WORKTREE_BRANCH}" -1 2>/dev/null | grep -qv "$(git -C "$PROJECT_DIR" log --oneline HEAD -1 2>/dev/null)"; then
        echo "[dispatch] $AGENT completed with changes on branch $WORKTREE_BRANCH"
      fi
      # Remove worktree (branch preserved for merging)
      git -C "$PROJECT_DIR" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
      rm -f "$LOCK_DIR/${AGENT}.pid" 2>/dev/null
    ) &
  fi
else
  if [ -n "$LOG_FILE" ]; then
    "${FULL_CMD[@]}" >> "$LOG_FILE" 2>&1
  else
    "${FULL_CMD[@]}"
  fi
fi
