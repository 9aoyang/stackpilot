---
name: release
description: Use when releasing a new version of stackpilot — auto-generates CHANGELOG from git log, detects bump type, bumps all version files, validates, commits, tags, and pushes.
---

# Release

Full automated release: git log → CHANGELOG → version bump → validate → tag → push.

## Files That Must Be Updated (all three, always)

| File | Field |
|------|-------|
| `VERSION` | entire file content |
| `claude-config/skills/stackpilot/SKILL.md` | `version:` in frontmatter |
| `.claude-plugin/plugin.json` | `"version"` field |

## Release Steps

**1. Verify clean working tree**

```bash
git status --porcelain
```

Must be empty. If not, commit or stash pending changes first.

**2. Collect commits since last tag**

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  git log "${LAST_TAG}..HEAD" --pretty=format:"%s"
else
  git log --pretty=format:"%s"
fi
```

If no commits since last tag → **abort**, nothing to release.

**3. Map commits to CHANGELOG sections**

Use conventional commit prefixes to categorize:

| Commit prefix | CHANGELOG section |
|---------------|-------------------|
| `feat:` / `feat(…):` | `### Added` |
| `fix:` / `fix(…):` | `### Fixed` |
| `docs:` / `docs(…):` | `### Changed` |
| `chore:` / `refactor:` | `### Changed` (only if user-visible) |
| `BREAKING CHANGE` in body or `!` after type | `### Breaking Changes` |

Strip the prefix and scope from each message (e.g. `feat(stackpilot): foo` → `foo`). Skip pure-internal chores (e.g. `chore: tidy`, `chore(stackpilot): tidy`).

**4. Auto-detect bump type**

| Condition | Bump |
|-----------|------|
| Any `### Breaking Changes` entry | **major** |
| Any `### Added` entry | **minor** |
| Only `### Fixed` / `### Changed` | **patch** |

If `$ARGUMENTS` is provided (`patch`, `minor`, `major`, or explicit `X.Y.Z`), use that instead.

**5. Calculate new version**

```bash
CURRENT="$(cat VERSION)"
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP" in
  patch) NEW_VER="$MAJOR.$MINOR.$((PATCH + 1))" ;;
  minor) NEW_VER="$MAJOR.$((MINOR + 1)).0" ;;
  major) NEW_VER="$((MAJOR + 1)).0.0" ;;
  *)     NEW_VER="$BUMP" ;;
esac

echo "→ $BUMP bump: $CURRENT → $NEW_VER"
```

Show the detected bump type and list of commits that drove the decision. Confirm before proceeding.

**6. Write CHANGELOG entry**

Insert above the first `## [` line, after `## [Unreleased]`:

```markdown
## [Unreleased]

## [<NEW_VER>] - <TODAY>

### Added
- foo
- bar

### Fixed
- baz
```

Only include sections that have content. Date format: `YYYY-MM-DD`.

**7. Bump version in all three files**

Use the Edit tool (not sed/bash substitution) to update each file directly:

- `VERSION` — replace entire content with `$NEW_VER`
- `.claude-plugin/plugin.json` — replace `"version": "X.Y.Z"` line
- `claude-config/skills/stackpilot/SKILL.md` — replace `version: "X.Y.Z"` line in frontmatter

Verify all three match after editing:
```bash
cat VERSION
jq -r '.version' .claude-plugin/plugin.json
grep -m1 'version:' claude-config/skills/stackpilot/SKILL.md
# all three must show the same value
```

**8. Update architecture evolution notes**

The pre-commit hook requires docs updates whenever skill files change. Since step 7 always modifies `SKILL.md`, you must update the evolution notes in both architecture docs.

Append a row to the `## Evolution Notes` table in `docs/architecture.md`:

```markdown
| <TODAY> | **v<NEW_VER>**: <one-line summary of CHANGELOG sections> |
```

Do the same for `docs/architecture.zh.md` (Chinese translation, under `## 演进记录`).

**9. Run pre-commit validation**

```bash
bash .githooks/pre-commit
```

Fix any failures before proceeding.

**10. Commit, tag, push**

```bash
git add VERSION .claude-plugin/plugin.json claude-config/skills/stackpilot/SKILL.md CHANGELOG.md docs/architecture.md docs/architecture.zh.md
git commit -m "chore: release v$NEW_VER"
git tag "v$NEW_VER"
git push origin main --tags
```

## Common Mistakes

| Mistake | Result |
|---------|--------|
| Updating VERSION but not plugin.json | pre-commit FAIL: version mismatch |
| Updating plugin.json but not SKILL.md frontmatter | pre-commit FAIL: version mismatch |
| Pushing tag before main | GitHub Actions may fail |
| Not including docs in release commit | pre-commit FAIL: skill files changed but docs not updated |
