# Sprint Finish

Run after all tasks are done. Confirms tests pass, optionally starts dev
server for preview, then surfaces the sprint outcome via `finish-report.html`
(or terminal fallback) and executes the user's merge/PR/keep/discard choice.

Inputs assumed present: `.stackpilot/runs/<slug>/TASK-*/state.json` for
elapsed/phase data, `.stackpilot/specs/<slug>-criteria.md` for criteria,
agent reports for Pattern/Decision Candidates, `git log <base>..HEAD` for
the commits list.

## Step 0 — Pre-merge verification gate

Before anything else, run the project's verification suite. Read `stackpilot.config.yml` for `qa.test_command`.

```bash
# 1. Type check (if available)
npx tsc --noEmit 2>&1 || true
# 2. Lint (if available)
npm run lint 2>&1 || true
# 3. Test suite
<test_command from config>
```

Auto-detect which checks exist (don't fail on missing tools). Report results:

```
━━━━━━━━━━━━━━━━━━━━━━━━━
  Pre-Merge Gate
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Type check     passed
⚠️  Lint           3 warnings (non-blocking)
✅ Tests          47/47 passed
━━━━━━━━━━━━━━━━━━━━━━━━━
```

- All green → proceed to Step 1
- Test failures → report and ask: "Tests failing. Fix before merge, or proceed anyway?"
- Type errors → report and ask: same pattern

Do NOT silently skip verification.

## Step 0.5 — Sprint Closure Gate

After Step 0 tech checks pass, verify sprint **business completeness** before allowing merge. 3 sub-gates.

### Gate 1: Acceptance criteria all green

```bash
CRITERIA=$(ls -t .stackpilot/specs/*-criteria.md 2>/dev/null | head -1)
if [ -z "${CRITERIA}" ]; then
  echo "⚠ Gate 1: no acceptance-criteria.md found — Phase 3.6 may have been skipped (legacy sprint?)"
  # Don't block merge for legacy sprints that pre-date Phase 3.6
else
  NOT_GREEN=$(grep -E '^\| C[0-9]+ \|' "${CRITERIA}" \
    | awk -F'|' '{print $5}' | tr -d ' ' \
    | grep -cE 'untested|fail')
  if [ "${NOT_GREEN}" -gt 0 ]; then
    echo "❌ Gate 1: ${NOT_GREEN} criterion(s) not green in ${CRITERIA}"
    grep -E '\| (untested|fail) \|' "${CRITERIA}"
    GATE_FAILED=1
  else
    echo "✅ Gate 1: all acceptance criteria green"
  fi
fi
```

Allowed Status values: `pass`, `n-a-this-task`. Both count as green. `untested` and `fail` block merge.

### Gate 2: CHANGELOG updated

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)
SPRINT_COMMITS=$(git log "${BASE}..HEAD" --format='%s')
UNRELEASED=$(awk '/^## \[Unreleased\]/,/^## \[[0-9]/' CHANGELOG.md 2>/dev/null | head -200)

MISSING_SCOPES=()
while IFS= read -r commit_msg; do
  [ -z "${commit_msg}" ] && continue
  # Extract scope from conventional commit (e.g. "feat(auth): ..." → "auth")
  SCOPE=$(echo "${commit_msg}" | grep -oP '^\w+\(\K[^)]+' || echo "")
  if [ -n "${SCOPE}" ] && ! echo "${UNRELEASED}" | grep -qi "${SCOPE}"; then
    MISSING_SCOPES+=("${SCOPE}")
  fi
done <<< "${SPRINT_COMMITS}"

# Dedupe
UNIQUE_MISSING=$(printf '%s\n' "${MISSING_SCOPES[@]}" | sort -u | grep -v '^$' | wc -l | tr -d ' ')
if [ "${UNIQUE_MISSING}" -gt 0 ]; then
  echo "❌ Gate 2: ${UNIQUE_MISSING} sprint scope(s) missing from CHANGELOG Unreleased:"
  printf '%s\n' "${MISSING_SCOPES[@]}" | sort -u | grep -v '^$' | sed 's/^/  · /'
  GATE_FAILED=1
else
  echo "✅ Gate 2: CHANGELOG Unreleased covers sprint scopes"
fi
```

Skip Gate 2 if `CHANGELOG.md` does not exist (project doesn't keep a changelog).

### Gate 3: Review Patterns candidates surfaced

```bash
# sp-qa reports may contain "## Pattern Candidates" blocks during the sprint
# Look for unprocessed candidates (warning only, Step 4a handles the merge prompt)
CANDIDATES=$(find .stackpilot/runs -name "qa-report*.md" -newer .stackpilot/ARCHITECTURE.md 2>/dev/null \
  | xargs awk '/^## Pattern Candidates/,/^## [^P]/' 2>/dev/null \
  | grep -cE '^- \[' || echo 0)

if [ "${CANDIDATES}" -gt 0 ]; then
  echo "⚠ Gate 3: ${CANDIDATES} Pattern Candidate(s) from sp-qa pending → Step 4a will prompt for merge"
else
  echo "✅ Gate 3: no pending Pattern Candidates"
fi
```

Gate 3 is informational only — does not block merge. Step 4a handles the merge prompt.

### Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━
  Sprint Closure Gate
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Gate 1 (criteria)      all 5 green
✅ Gate 2 (CHANGELOG)     3 scopes covered
⚠️  Gate 3 (patterns)      2 candidates pending (handled in Step 4a)
━━━━━━━━━━━━━━━━━━━━━━━━━
```

- All `✅` (or only `⚠️` warnings) → proceed to Step 1
- Any `❌` (`GATE_FAILED=1`) → present to user:
  > "Closure gate failed: <reasons>. Fix before merge, or proceed anyway (override gate)?"
  
  If user fixes → return control, do not proceed until re-run shows green.
  If user overrides → log override reason and proceed to Step 1.

**Skip Step 0.5 only in:** auto mode B AND no criteria file exists (legacy sprint). Otherwise gates always run.

## Step 1 — Detect dev server command

Auto-detect from project files. Only detect when there is a clear web server signal.

```
Check in order, use the first match:
1. package.json exists → read scripts:
   a. Has "dev" script AND dependencies include vite/next/nuxt/webpack/remix/astro/svelte → npm run dev
   b. Has "dev" script with no web framework signal → skip
   c. No "dev" script → skip
2. manage.py exists + contains "django" → python manage.py runserver
3. Gemfile exists + config/routes.rb exists → bundle exec rails server
4. No match → skip preview, go directly to Step 3
```

Do NOT blindly run `cargo run`, `go run .`, `python app.py`, or `npm start`.

## Step 2 — Start server, verify response, present preview URL

1. Start detected command in background, capture PID: `<command> & echo $!`
2. Wait for output containing `http://localhost:` (timeout 15s)
3. If no URL detected → kill process, skip preview
4. **Auto-verify the URL responds** before handing off to the user:
   ```bash
   HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo "ERR")"
   ```
   - `2xx` or `3xx` → report `✅ URL responded (HTTP $HTTP_CODE)`
   - `4xx` / `5xx` / `ERR` → report the code and the last 20 lines of the server log; ask user whether to proceed anyway or investigate
5. Present to user:

> "Sprint complete. All tests passing. Dev server running at:"
>
> `http://localhost:XXXX`  (PID: XXXX) — responded HTTP 200
>
> "Please review in your browser, then tell me how to proceed."

**Wait for user to finish reviewing.**

## Step 3 — Present options (HTML view + terminal fallback)

### 3a. Generate finish-report.html

Aggregate sprint data into JSON, fill `references/views/finish-report.html`
tokens, write to `.stackpilot/views/<slug>/finish-report.html`:

```bash
SLUG="<sprint-slug>"
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)
BRANCH=$(git branch --show-current)

# Build DATA_JSON in a temp file (commits / tasks / criteria / patterns / decisions / branch)
# Then sed-replace tokens in the template
cp ~/Documents/github/stackpilot/claude-config/skills/stackpilot/references/views/finish-report.html \
   ".stackpilot/views/${SLUG}/finish-report.html"
# Tokens to replace: {{SPRINT_SLUG}}, {{BRANCH}}, {{DATA_JSON}}
```

The dashboard server is still running from Node 4; the same instance
serves this view at `http://localhost:<port>/sprints/<slug>/finish-report.html`.

Print URL once to terminal alongside this prompt:

> A. Squash merge into `${BASE}`
> B. Push and create a PR
> C. Leave as-is (handle later)
> D. Discard (destructive — confirm first)
>
> Click in browser OR reply A/B/C/D here.

### 3b. Wait for action

Poll `.stackpilot/views/<slug>/finish-action.json` every 2 seconds. **First
to arrive wins** (HTML click or terminal reply). If 30 seconds elapse with
no action.json AND no terminal response, fall back to terminal-only prompt
(do not regenerate the HTML; user can still type the choice).

## Step 4 — Pre-merge commits on feature branch (A and B)

Commit all housekeeping on the feature branch **before** touching the base branch. These commits will be squashed away and never appear on main.

**4a. Architecture Memory Check:**

> "需要更新 `.stackpilot/ARCHITECTURE.md` 吗？（结构 / 设计决策 / Conventions & Gotchas / Review Patterns 有变化都在这里更新）"
> A. 要  B. 不用

- **A**: Before editing, scan this sprint's agent completion reports:
  - `sp-architect` reports — collect any `## Decision Candidates` blocks; surface as suggested additions to `## Key Design Decisions`
  - `sp-qa` reports — collect any `## Pattern Candidates` blocks; surface as suggested additions to `## Review Patterns` (merge counts for "merge with existing" candidates, append as new entries for others; enforce the 20-entry cap by pruning lowest-count entries, ties broken by oldest)

  Then update `.stackpilot/ARCHITECTURE.md` in-place — sections include Stack / Key Directories / Data Flow / Key Design Decisions / Conventions & Gotchas / Review Patterns. Commit:
  ```bash
  git add .stackpilot/ARCHITECTURE.md
  git commit -m "docs(arch): update after sprint"
  ```
- **B**: Skip silently. Any surfaced Pattern Candidates / Decision Candidates are discarded — sp-qa and sp-architect will re-surface them next sprint if the underlying issues or decisions recur.

**4b. Clear sprint artifacts:**

```bash
find .stackpilot/plans -name '*.md' -delete 2>/dev/null || true
find .stackpilot/specs -name '*.md' -delete 2>/dev/null || true
git add .stackpilot/
git commit -m "chore(stackpilot): clear sprint artifacts"
```

## Step 5 — Execute choice

- **A**: Squash merge — produces exactly one commit on base branch:
  ```bash
  git checkout <base-branch>
  git merge --squash <feature-branch>
  git commit -m "<descriptive summary of the sprint>"
  git branch -d <feature-branch>
  ```
- **B**: Push and create PR (squash merge policy enforced on the PR, not locally):
  ```bash
  git push -u origin <feature-branch>
  # create PR — title becomes the squash commit message on merge
  ```
- **C**: Do nothing
- **D**: Confirm once, then `git checkout <base-branch> && git branch -D <feature-branch>`

## Step 6 — Stop dev server + sprint server

```bash
# Dev server (the project's app server started in Step 2, if any)
kill <PID> 2>/dev/null

# Sprint server (started in Node 4 of SKILL.md)
bash ~/Documents/github/stackpilot/scripts/preview/stop-server.sh --slug "${SLUG}"
```

Stopping the sprint server removes `.stackpilot/views/<slug>/.server-info.json`
so a future `/stackpilot` invocation won't try to reuse a dead server.
