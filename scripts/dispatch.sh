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

build_cmd() {
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
      # Optional: model override
      local model
      model="$(config_get_or "provider.model" "" "${CONFIG_FILE:-/dev/null}")"
      if [ -n "$model" ]; then
        CMD+=(--model "$model")
      fi
      ;;
    codex)
      local approval
      approval="$(config_get_or "provider.codex.approval_mode" "full-auto" "${CONFIG_FILE:-/dev/null}")"
      CMD=(codex --quiet "--approval-mode" "$approval" "$FULL_PROMPT")
      local model
      model="$(config_get_or "provider.model" "" "${CONFIG_FILE:-/dev/null}")"
      if [ -n "$model" ]; then
        CMD+=(--model "$model")
      fi
      ;;
    gemini)
      CMD=(gemini -p "$FULL_PROMPT")
      local model
      model="$(config_get_or "provider.model" "" "${CONFIG_FILE:-/dev/null}")"
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
  echo "[dispatch] Warning: $CLI_BIN not found in PATH — skipping $AGENT" >&2
  exit 0
fi

# ── Execute ──────────────────────────────────────────────────────────────────

if $BACKGROUND; then
  if [ -n "$LOG_FILE" ]; then
    "${CMD[@]}" >> "$LOG_FILE" 2>&1 &
  else
    "${CMD[@]}" >/dev/null 2>&1 &
  fi
  echo "[dispatch] $AGENT started in background (PID $!, provider=$PROVIDER)"
else
  if [ -n "$LOG_FILE" ]; then
    "${CMD[@]}" >> "$LOG_FILE" 2>&1
  else
    "${CMD[@]}"
  fi
fi
