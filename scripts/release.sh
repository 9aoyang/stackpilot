#!/usr/bin/env bash
# Stackpilot release helpers

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/release.sh verify-version <tag> [version-file]
  scripts/release.sh release-notes <tag-or-version> [changelog-file]
EOF
}

normalize_tag() {
  local tag="$1"

  if [[ ! "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Invalid tag: $tag (expected format: vX.Y.Z)" >&2
    return 1
  fi

  printf '%s\n' "${tag#v}"
}

read_trimmed_file() {
  local path="$1"

  if [ ! -f "$path" ]; then
    echo "Missing file: $path" >&2
    return 1
  fi

  tr -d '[:space:]' < "$path"
}

verify_version() {
  local tag="$1"
  local version_file="${2:-VERSION}"
  local normalized_tag
  local file_version

  normalized_tag="$(normalize_tag "$tag")"
  file_version="$(read_trimmed_file "$version_file")"

  if [ "$normalized_tag" != "$file_version" ]; then
    echo "Version mismatch: tag=$normalized_tag VERSION=$file_version" >&2
    return 1
  fi
}

extract_release_notes() {
  local version_ref="$1"
  local changelog_file="${2:-CHANGELOG.md}"
  local version
  local body

  if [[ "$version_ref" == v* ]]; then
    version="$(normalize_tag "$version_ref")"
  else
    version="$version_ref"
  fi

  if [ ! -f "$changelog_file" ]; then
    echo "Release v$version"
    return 0
  fi

  body="$(
    awk -v version="$version" '
      $0 ~ "^## \\[" version "\\]" { in_section=1; next }
      in_section && $0 ~ "^## \\[" { exit }
      in_section { print }
    ' "$changelog_file"
  )"

  if [ -n "${body//[[:space:]]/}" ]; then
    printf '%s\n' "$body"
  else
    printf 'Release v%s\n' "$version"
  fi
}

main() {
  local command="${1:-}"

  case "$command" in
    verify-version)
      [ "$#" -ge 2 ] || { usage >&2; return 1; }
      verify_version "$2" "${3:-VERSION}"
      ;;
    release-notes)
      [ "$#" -ge 2 ] || { usage >&2; return 1; }
      extract_release_notes "$2" "${3:-CHANGELOG.md}"
      ;;
    *)
      usage >&2
      return 1
      ;;
  esac
}

main "$@"
