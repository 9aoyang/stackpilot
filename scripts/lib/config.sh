#!/usr/bin/env bash
# Stackpilot config helpers — pure bash YAML reader and frontmatter parser
# Source this file: source "$(dirname "$0")/lib/config.sh"

# config_get <key> <config_file>
# Read a value from a simple YAML file. Supports dotted keys up to 2 levels deep.
# Examples:
#   config_get "qa.test_command" config.yml     → "npm test"
#   config_get "qa.coverage_threshold" config.yml → "80"
config_get() {
  local key="$1" file="$2"
  [ -f "$file" ] || return 1

  local seg1="" seg2=""
  IFS='.' read -r seg1 seg2 <<< "$key"

  if [ -n "$seg2" ]; then
    # Two-level: parent.child
    awk -v parent="$seg1" -v child="$seg2" '
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
  else
    # Top-level key
    sed -n "s/^${seg1}:[[:space:]]*//p" "$file" | head -1 | sed 's/[[:space:]]*#.*$//'
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
