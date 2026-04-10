---
name: stackpilot-tidy
description: Housekeeping for stackpilot projects. Scans for uncommitted changes, stale branches, orphaned worktrees, and leftover artifacts from sprints or other workflows. Reports findings and cleans up with one confirmation.
---

# Stackpilot Tidy

Project housekeeping — run when entering a project or when the workspace feels cluttered.

## Step 1: Scan

Run all detection commands silently. Collect results into two buckets: **will clean** (safe, automatic) and **needs attention** (user must handle manually).

### Will Clean

```bash
# Stale stackpilot plans/specs (only if no active sprint — check TaskList first)
ls .stackpilot/plans/*.md 2>/dev/null
ls .stackpilot/specs/*.md 2>/dev/null

# NEEDS_REVIEW.md with leftover content
[ -s .stackpilot/NEEDS_REVIEW.md ] && echo "NEEDS_REVIEW has content"

# Claude Code plan files (non-git-tracked only)
for f in .claude/plans/*.md; do
  [ -f "$f" ] && ! git ls-files --error-unmatch "$f" 2>/dev/null && echo "$f"
done

# Superpowers artifacts
ls -d .superpowers/ 2>/dev/null

# Orphaned worktrees
git worktree prune --dry-run 2>/dev/null

# Remote-deleted tracking branches
git remote prune origin --dry-run 2>/dev/null

# Merged local branches (excluding main/master/develop and current)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git branch --merged "$DEFAULT_BRANCH" --no-color 2>/dev/null | grep -v '^\*' | grep -vE '^\s*(main|master|develop)$'
```

### Needs Attention (report only)

```bash
# Uncommitted changes
git status --porcelain 2>/dev/null

# Stale stashes
git stash list 2>/dev/null
```

**Edge cases:**
- Not a git repo (`git rev-parse --git-dir` fails) → print error, stop
- `.stackpilot/` does not exist → skip stackpilot-related items, scan the rest
- Active sprint (TaskList has in-progress tasks) → do NOT touch plans/specs, note in report

---

## Step 2: Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Tidy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Will clean:
    · 2 plan files
    · 1 spec file
    · 4 Claude plan files (.claude/plans/)
    · .superpowers/ (3 files)
    · 1 orphaned worktree
    · 2 merged branches: feature/old, fix/typo

  Needs attention:
    · 3 uncommitted changes
    · 2 stashed entries

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If everything is clean:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Tidy — All clean
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Stop here if nothing to clean.

---

## Step 3: Confirm and Execute

> Proceed with cleanup? (Y/n)

On confirmation, execute in order:

```bash
# 1. Prune worktrees
git worktree prune

# 2. Prune remote tracking branches
git remote prune origin

# 3. Delete merged local branches
git branch -d <branch> # for each merged branch found in Step 1

# 4. Delete stackpilot plans/specs
rm -f .stackpilot/plans/*.md 2>/dev/null
rm -f .stackpilot/specs/*.md 2>/dev/null

# 5. Clear NEEDS_REVIEW
printf "" > .stackpilot/NEEDS_REVIEW.md

# 6. Delete Claude plan files (non-git-tracked only)
rm -f .claude/plans/*.md 2>/dev/null

# 7. Delete superpowers artifacts
rm -rf .superpowers/ 2>/dev/null

# 8. Commit if stackpilot files changed
git add .stackpilot/plans/ .stackpilot/specs/ 2>/dev/null
git diff --cached --quiet || git commit -m "chore(stackpilot): tidy"
```

---

## Step 4: Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Done
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Deleted: 3 plans/specs, 4 Claude plans, 3 superpowers files
  Pruned: 1 worktree, 2 branches
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
