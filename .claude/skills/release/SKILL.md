---
name: release
description: Use when releasing a new version of stackpilot — bumps version across all three required files, updates CHANGELOG, validates, commits, tags, and pushes.
args:
  - name: version
    description: New version number in X.Y.Z format (e.g. 1.4.0). Do not include "v" prefix.
    required: true
---

# Release

Bump stackpilot version consistently across all required files, validate, and publish.

## Files That Must Be Updated (all three, always)

| File | Field | Example |
|------|-------|---------|
| `VERSION` | entire file content | `1.4.0` |
| `claude-config/skills/stackpilot/SKILL.md` | `version:` in frontmatter (line ~8) | `version: "1.4.0"` |
| `.claude-plugin/plugin.json` | `"version"` field | `"version": "1.4.0"` |

Missing any one of these will fail the pre-commit hook.

## Release Steps

**1. Verify clean working tree**

```bash
git status --porcelain
```

Must be empty. If not, commit or stash pending changes first.

**2. Update CHANGELOG.md**

Move content from `## [Unreleased]` into a new versioned section:

```markdown
## [Unreleased]

## [1.4.0] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

Date format: `YYYY-MM-DD`. Only include sections that have content.

**3. Bump version in all three files**

```bash
NEW_VER="$ARGUMENTS"

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
