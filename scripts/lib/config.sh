#!/usr/bin/env bash
# Stackpilot config helpers — pure bash YAML reader, frontmatter parser, and file locking
# Source this file: source "$(dirname "$0")/lib/config.sh"

# locked_write <lock_name> <command...>
# Executes a command while holding an exclusive lock on the named resource.
# Uses flock when available, falls back to mkdir-based spinlock.
# Example: locked_write "backlog" cp temp.yml backlog.yml
locked_write() {
  local lock_name="$1"; shift
  local lock_base="${STACKPILOT_LOCK_DIR:-.stackpilot/.locks}"
  mkdir -p "$lock_base" 2>/dev/null || true

  if command -v flock >/dev/null 2>&1; then
    local lock_file="$lock_base/${lock_name}.lock"
    (
      flock -w 30 200 || { echo "[stackpilot] Warning: failed to acquire lock '$lock_name' after 30s" >&2; return 1; }
      "$@"
    ) 200>"$lock_file"
  else
    # mkdir-based spinlock fallback (atomic on all POSIX systems)
    local lock_dir="$lock_base/${lock_name}.lk"
    local attempts=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 60 ]; then
        echo "[stackpilot] Warning: failed to acquire lock '$lock_name' after 30s — removing stale lock" >&2
        rm -rf "$lock_dir"
      fi
      sleep 0.5
    done
    # Ensure lock is released on exit
    trap 'rm -rf "'"$lock_dir"'"' EXIT
    "$@"
    rm -rf "$lock_dir"
    trap - EXIT
  fi
}

# config_get <key> <config_file>
# Read a value from a simple YAML file. Supports dotted keys for one level of nesting.
# Example: config_get "provider.name" stackpilot.config.yml → "claude"
config_get() {
  local key="$1" file="$2"
  [ -f "$file" ] || return 1

  local parent child
  if [[ "$key" == *.* ]]; then
    parent="${key%%.*}"
    child="${key#*.}"
  else
    parent=""
    child="$key"
  fi

  if [ -z "$parent" ]; then
    # Top-level key: match "key: value" not indented, strip inline comments
    sed -n "s/^${child}:[[:space:]]*//p" "$file" | head -1 | sed 's/[[:space:]]*#.*$//'
  else
    # Nested key: find parent block, then match indented child
    awk -v parent="$parent" -v child="$child" '
      BEGIN { in_block = 0 }
      /^[^ #]/ {
        if ($0 ~ "^" parent ":") { in_block = 1; next }
        else { in_block = 0 }
      }
      in_block && $0 ~ "^[[:space:]]+" child ":" {
        sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "")
        sub(/[[:space:]]*#.*$/, "")
        print
        exit
      }
    ' "$file"
  fi
}

# config_get_or <key> <default> <config_file>
# Like config_get but returns default if key is missing or empty.
config_get_or() {
  local key="$1" default="$2" file="$3"
  local val
  val="$(config_get "$key" "$file" 2>/dev/null)"
  if [ -z "$val" ] || [ "$val" = "~" ] || [ "$val" = "null" ]; then
    echo "$default"
  else
    echo "$val"
  fi
}

# strip_frontmatter <file>
# Remove YAML frontmatter (--- ... ---) from a markdown file, output the body.
strip_frontmatter() {
  local file="$1"
  [ -f "$file" ] || return 1
  awk '
    BEGIN { in_fm = 0; past_fm = 0 }
    /^---[[:space:]]*$/ {
      if (!past_fm) {
        if (in_fm) { past_fm = 1; next }
        else { in_fm = 1; next }
      }
    }
    past_fm { print }
    !in_fm && !past_fm { print }
  ' "$file"
}

# get_frontmatter_field <file> <field>
# Extract a specific field from YAML frontmatter.
# Example: get_frontmatter_field agent.md "tools" → "Read, Write, Bash"
get_frontmatter_field() {
  local file="$1" field="$2"
  [ -f "$file" ] || return 1
  awk -v field="$field" '
    BEGIN { in_fm = 0 }
    /^---[[:space:]]*$/ {
      if (in_fm) { exit }
      in_fm = 1; next
    }
    in_fm && $0 ~ "^" field ":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      print
      exit
    }
  ' "$file"
}
