---
name: release
description: Use when releasing a new version of stackpilot — auto-detects bump type from CHANGELOG, bumps version across all three required files, validates, commits, tags, and pushes.
---

# Release

Bump stackpilot version consistently across all required files, validate, and publish.

## Files That Must Be Updated (all three, always)

| File | Field |
|------|-------|
| `VERSION` | entire file content |
| `claude-config/skills/stackpilot/SKILL.md` | `version:` in frontmatter |
| `.claude-plugin/plugin.json` | `"version"` field |

Missing any one of these will fail the pre-commit hook.

## Release Steps

**1. Verify clean working tree**

```bash
git status --porcelain
```

Must be empty. If not, commit or stash pending changes first.

**2. Auto-detect bump type from CHANGELOG**

Read the `## [Unreleased]` section in `CHANGELOG.md` and determine bump type:

```bash
UNRELEASED=$(awk '/^## \[Unreleased\]/{found=1; next} found && /^## \[/{exit} found{print}' CHANGELOG.md)
```

Rules (in priority order):

| CHANGELOG content | Bump type |
|-------------------|-----------|
| Contains `BREAKING` (case-insensitive) | **major** |
| Has `### Added` or `### Changed` with content | **minor** |
| Has only `### Fixed` / `### Security` / `### Deprecated` | **patch** |
| `[Unreleased]` is empty | **abort** — nothing to release |

Show the detected bump type and the content it was inferred from. Then calculate:

```bash
CURRENT="$(cat VERSION)"
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP" in
  patch) NEW_VER="$MAJOR.$MINOR.$((PATCH + 1))" ;;
  minor) NEW_VER="$MAJOR.$((MINOR + 1)).0" ;;
  major) NEW_VER="$((MAJOR + 1)).0.0" ;;
esac

echo "Detected: $BUMP bump → $CURRENT → $NEW_VER"
```

If `$ARGUMENTS` is provided (e.g. `patch`, `minor`, `major`, or explicit `X.Y.Z`), skip auto-detection and use that directly.

**3. Update CHANGELOG.md**

Move content from `## [Unreleased]` into a new versioned section:

```markdown
## [Unreleased]

## [<NEW_VER>] - YYYY-MM-DD

### Added / Changed / Fixed
- ...
```

Date format: `YYYY-MM-DD`. Only include sections that have content.

**4. Bump version in all three files**

```bash
# VERSION file
echo "$NEW_VER" > VERSION

# plugin.json
sed -i '' "s/\"version\": \".*\"/\"version\": \"$NEW_VER\"/" .claude-plugin/plugin.json

# SKILL.md frontmatter (version: "X.Y.Z")
sed -i '' "s/version: \".*\"/version: \"$NEW_VER\"/" claude-config/skills/stackpilot/SKILL.md
```

Verify all three match before continuing:
```bash
cat VERSION
jq -r '.version' .claude-plugin/plugin.json
grep -m1 'version:' claude-config/skills/stackpilot/SKILL.md
# all three must output the same value
```

**4. Run pre-commit validation**

```bash
bash .githooks/pre-commit
```

Checks: version consistency across 3 files, CHANGELOG entry exists, tests pass. Fix any failures before proceeding.

**5. Commit, tag, push**

```bash
git add VERSION .claude-plugin/plugin.json claude-config/skills/stackpilot/SKILL.md CHANGELOG.md
git commit -m "chore: release v$NEW_VER"
git tag "v$NEW_VER"
git push origin main --tags
```

## Common Mistakes

| Mistake | Result |
|---------|--------|
| Updating VERSION but not plugin.json | pre-commit FAIL: version mismatch |
| Updating plugin.json but not SKILL.md frontmatter | pre-commit FAIL: version mismatch |
| No CHANGELOG entry for new version | pre-commit FAIL: no changelog entry |
| Including "v" prefix in VERSION file | `verify-version` script mismatch |
| Pushing tag before main | GitHub Actions may fail |

## Verify After Push

```bash
scripts/release.sh verify-version "v$NEW_VER"
scripts/release.sh release-notes "v$NEW_VER"
```
