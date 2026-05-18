---
name: stackpilot
description: Sprint orchestration for Claude Code and Codex. Turns feature requests into working code through a design→spec→plan→code→QA pipeline. Use when starting, resuming, tidying, or checking on development work. Claude uses native Agent/TaskCreate; Codex uses update_plan plus explorer/worker fallback.
license: Apache-2.0
compatibility: Claude Code native; Codex via references/codex-dispatch.md. Sync skills through skillshare as the single target sync source.
metadata:
  author: stackpilot
  version: "1.11.0"
---

# Stackpilot

## Runtime

This skill is synchronized to all targets by skillshare. Do not install a
separate Codex-only `stackpilot` skill.

- Claude Code: use the Agent / TaskCreate examples in this file directly.
- Codex: translate task tracking and subagent dispatch using
  [references/codex-dispatch.md](references/codex-dispatch.md).

Codex runs must obey the hard execution contract in
`references/codex-dispatch.md`: standard-or-higher tasks require auditable
`architect.md`, `dev-report.md`, and `qa-report.md` phase evidence, and QA
blockers require one scoped fix loop before completion. Treat a Codex run that
does not leave those artifacts as invalid orchestration rather than a successful
Stackpilot execution.

## Step 0+1: Initialize (single bash call — do NOT split into separate Bash calls)

```bash
# --- Version check (cache-gated, runs at most once/24h) ---
SP_DIR="${STACKPILOT_DIR:-$HOME/.stackpilot}"
[ -L ~/.claude/skills/stackpilot ] && SP_DIR="$(readlink ~/.claude/skills/stackpilot | sed 's|/claude-config/skills/stackpilot.*||')"
[ -L ~/.codex/skills/stackpilot ] && SP_DIR="$(readlink ~/.codex/skills/stackpilot | sed 's|/claude-config/skills/stackpilot.*||')"
[ -x "$SP_DIR/scripts/sync-skills.sh" ] && "$SP_DIR/scripts/sync-skills.sh" --auto-update --quick 2>&1 || true

# --- State scan ---
echo "---STATE---"
[ -d .stackpilot ] && echo "initialized" || echo "NOT_INITIALIZED"
[ -f .stackpilot/ARCHITECTURE.md ] && echo "ARCH_EXISTS" || echo "ARCH_MISSING"
ls -t .stackpilot/plans/*.md 2>/dev/null || echo "NO_PLANS"
ls -t .stackpilot/specs/*.md 2>/dev/null || echo "NO_SPECS"

# --- Fast debris (local-only, no network) ---
echo "---DEBRIS---"
ls .claude/plans/*.md 2>/dev/null || true
[ -d .superpowers ] && echo "SUPERPOWERS_EXISTS"
git status --porcelain 2>/dev/null | head -5
```

If the version check output shows an update was pulled, inform the user briefly. Otherwise proceed silently.

Also check TaskList for any in-progress sprint tasks from the current session.

Run checks silently. Default output: concise state summary + routing decision in 1-3 lines.

If detailed status needed, use this format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  implement login page    done
🔄 TASK-002  integrate payment API   in-progress
⏳ TASK-003  write unit tests        pending
━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Step 2: Route by State

### Not Initialized

```bash
bash ~/Documents/github/stackpilot/scripts/init.sh 2>&1
```

Re-run Step 0+1 after init. Only mention config if test_command binary was not found.

---

### Architecture Missing (ARCH_MISSING — first run only)

`.stackpilot/ARCHITECTURE.md` does not exist. Run a one-time project assessment before proceeding.

**Assessment steps:**

1. Read `CLAUDE.md` (project instructions)
2. Scan project structure:
   ```bash
   find src -type d | head -30 2>/dev/null || true
   ls package.json pyproject.toml Cargo.toml go.mod 2>/dev/null | head -5
   git log --oneline -10
   ```
3. Read key entry points (e.g. `src/app/`, `src/lib/`, main config files)
4. Write `.stackpilot/ARCHITECTURE.md` with these top-level sections (use `##` headings):
   - **What This Project Is** — one-paragraph overview
   - **Stack** — tech stack
   - **Key Directories** — purpose per directory
   - **Data Flow / Agent Pipeline** — core data flows and route/module structure
   - **Key Design Decisions** — design patterns in use
   - **Conventions & Gotchas** — project-specific conventions and gotchas discovered across sprints (leave empty initially with a one-line comment `<!-- project-specific conventions, decisions, gotchas; add entries as they surface -->`)
   - **Review Patterns** — recurring QA findings; max 20 entries; format `- [category] description ×N (TASK-NNN)` (leave empty initially with a one-line comment `<!-- maintained via Sprint Finish; sp-qa surfaces candidates, main agent merges -->`)
5. Commit:
   ```bash
   git add .stackpilot/ARCHITECTURE.md
   git commit -m "docs(arch): initial project assessment"
   ```

Then continue routing to the next applicable state (treat as ARCH_EXISTS from this point).

---

### Architecture Exists (ARCH_EXISTS — all subsequent runs)

**Before doing anything else**, read `.stackpilot/ARCHITECTURE.md` in full. This is the authoritative context for all routing and planning decisions. Do not re-explore the codebase for information already captured here.

---

### Tidy (workspace has debris)

If Step 0+1 found lightweight debris indicators (.claude/plans/, .superpowers/, uncommitted changes), run a deep scan first:

```bash
git worktree prune --dry-run 2>/dev/null
git remote prune origin --dry-run 2>/dev/null
git branch --merged main 2>/dev/null | grep -vE '^\*|main|master|develop'
git stash list 2>/dev/null
```

**Scan and report:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Tidy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Will clean:
    · 4 Claude plan files (.claude/plans/)
    · .superpowers/ (3 files)
    · 1 orphaned worktree
    · 2 merged branches: feature/old, fix/typo

  Needs attention:
    · 3 uncommitted changes
    · 2 stashed entries

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**"Will clean" items** (safe, automatic — ask once to confirm):
- `git worktree prune`
- `git remote prune origin`
- Delete merged local branches: `git branch -d <branch>` (only `--merged` branches, exclude main/master/develop)
- Delete `.claude/plans/*.md` (non-git-tracked only — check with `git ls-files --error-unmatch` first)
- Delete `.superpowers/`

**"Needs attention" items** (report only, never auto-handle):
- Uncommitted changes (`git status --porcelain`)
- Stale stashes (`git stash list`)

After cleanup, commit if stackpilot files changed:
```bash
git add .stackpilot/ 2>/dev/null
git diff --cached --quiet || git commit -m "chore(stackpilot): tidy"
```

Then continue routing to the next applicable state.

---

### Sprint Interrupted (plans exist, no active session tasks)

If `.stackpilot/plans/*.md` exists but TaskList has no in-progress tasks from the current session, this is an interrupted sprint from a previous session.

**1. Find the plan:**

```bash
ls -t .stackpilot/plans/*.md 2>/dev/null | head -1
```

Read the latest plan file and parse all `### TASK-` sections.

**2. Determine completed tasks:**

```bash
git log --oneline --all -50
```

For each TASK in the plan:
- Search git log for commit messages containing the TASK ID or task title keywords
- Check if the task's `relevant_files` exist and have recent modifications
- Evidence of completion → **done**; no evidence → **pending**

**3. Show status and offer choices:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Sprint Resume — <plan name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  add user model         done (commit abc1234)
✅ TASK-002  add auth middleware     done (commit def5678)
⏳ TASK-003  payment integration     pending
⏳ TASK-004  write unit tests        pending
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Completed: 2/4  |  Remaining: 2
```

> A. Resume from TASK-003
> B. Show me the plan details first
> C. Start fresh (re-run all tasks)
> D. Discard this sprint and start something new

- **A** → Create TaskCreate entries for pending tasks only, then Run Sprint from first pending task
- **B** → Display the full plan, then ask again
- **C** → Create TaskCreate entries for ALL tasks, Run Sprint from beginning
- **D** → Clear plans/specs, then proceed to Sprint Clean

---

### Sprint Clean

If no plans/specs exist (or they were just cleared), ask what to build.

> If the request is about **improving something measurable** (performance, error rate, bundle size), read [references/optimize-sprint.md](references/optimize-sprint.md) and follow the Optimize Sprint path.

After the user describes what to build, ask:

> How should I run this?
> A. Walk through design together (I'll check in at key points)
> B. Full auto (plan and code without stopping, result stays on feature branch)

If **B (auto mode)**: skip all `<!-- CONFIRM-GATE -->` prompts. At Sprint Finish, auto-select option C (leave as-is). Pick the most conservative non-destructive default at any decision point.

Then choose path by scope:

#### Light Feature (single clear requirement, ≤ 2 sentences)

<HARD-GATE>
Do NOT start implementation until a plan is written and committed.
Even "simple" tasks require a 30-second design check — silently-made assumptions here cause the most wasted work later.
</HARD-GATE>

**Phase 0.5: Mini-brainstorm (≤2 minutes, mandatory)**

Even Light tasks do NOT skip thinking. Run this lightweight check (sourced from `superpowers:brainstorming`'s "Too Simple to Need a Design" anti-pattern):

1. **Scout once** — grep the request's key terms + read 1-2 most relevant files (lighter than Standard's 2-5)
2. **At most one clarifying question** — only if there's a genuine ambiguity affecting implementation; otherwise skip and proceed
3. **State the chosen approach in 1-2 sentences** — ONE approach (not 2-3; Light's whole point is single approach), and explicitly what you'll NOT do (YAGNI)
4. **User confirms** with a one-word "go" or rejection <!-- CONFIRM-GATE: light design -->

Skip mini-brainstorm only when user explicitly said "just do it" / "skip planning" / chose auto mode B at Sprint Clean.

**Then:**

1. **Map file structure** — list files to touch and changes each needs
2. **Write plan** → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`
   - Bite-sized tasks (2–5 min each)
   - Every task: `title`, `description`, `type`, `complexity: light`, `depends_on`, `relevant_files`
   - No placeholders — no TBD, TODO, vague descriptions
3. **Plan self-review** — types consistent? Placeholders? Method names match across tasks?
4. **Create feature branch** → commit plan → Run Sprint

#### Standard Feature (multi-module, ambiguous, architectural decisions)

**Phase 1: Exploration**

1. **Scout first — before ANY clarifying question**: grep request's key terms across the codebase, read `CLAUDE.md` + 2-5 most relevant files + recent commits. No question to the user until this completes (otherwise you end up asking about things discoverable by grep).
2. If request spans multiple subsystems, flag and decompose first
3. **Ask clarifying questions one at a time** — prefer multiple choice, focus on purpose/constraints/success criteria

**Exploration rigor rules:**
- **Take a position.** Do NOT hedge with "That could work" or "There are many ways." If the user's direction has a gap, say so and state what you'd do instead.
- **Push for specificity.** Vague requirements ("make it better", "add analytics") → ask one forcing question: "Who specifically benefits, and what do they do differently after this exists?"
- **Challenge status-quo assumptions.** If the user describes a solution, ask "What problem does this solve that can't be solved by [simpler alternative]?" at least once.
- **Two-push rule.** If the first answer is still vague, push once more. After two pushes, accept and move on — don't interrogate.
- **Canonical Refs.** Any doc path the user cites mid-conversation → Read immediately; record with full relative path under a `## Canonical Refs` section in the spec (so sub-agents see the binding constraint, not just you).

**Phase 1.5: Visual Companion** (only when a design question benefits from visualization)

Read [references/visual-companion.md](references/visual-companion.md) for setup and usage. Key rule: decide **per question** whether browser or terminal communicates better.

**Phase 2: Design**

4. Propose 2–3 approaches with trade-offs and recommendation
5. Present in sections, get user approval per section <!-- CONFIRM-GATE: design review -->
6. Stop visual companion server if used

**Phase 3: Spec + Auto-Verify Loop**

6. Write spec → `.stackpilot/specs/YYYY-MM-DD-<topic>-design.md`
7. Run verification (up to 1 self-fix round — 4.7 catches most issues first pass; escalate on second failure):
   ```bash
   grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/specs/*.md | wc -l  # must be 0
   grep -c "^## " .stackpilot/specs/*.md  # must be >= 4
   wc -w .stackpilot/specs/*.md | tail -1  # must be >= 300
   ```
   All pass → proceed to **Phase 3.5: Spec 12-QA** (do NOT skip). Fail after 1 self-fix → escalate specific failures.

**Phase 3.5: Spec 12-QA**

After spec passes auto-verify, read [references/12-qa-matrix.md](references/12-qa-matrix.md) §Spec and mark each dimension ✅ / ⚠️ / ❌ / N/A against the spec.

**Rules:**
- Any ❌ on dimensions 1-4 → **must fix spec** before proceeding (these are fundamental)
- Any ❌ on dimensions 5-12 → fix if applicable, mark N/A with reason if genuinely not relevant
- ⚠️ items → add a one-line note to the spec clarifying the gap
- Output the 12-QA result table, then update the spec if needed
- Re-run auto-verify after any spec changes

**Phase 3.6: Derive Acceptance Criteria**

After Phase 3.5 passes, derive 3-7 mechanically verifiable acceptance criteria for this feature. These gate Sprint Finish — `merge` is only allowed when all criteria are green.

Write to `.stackpilot/specs/<date>-<feature>-criteria.md`:

```markdown
# Acceptance Criteria — <feature>

> Generated by stackpilot Phase 3.6 from spec. Edit if scope changes. sp-qa updates Status during sprint.

| ID | Description | Verify Command | Status | Notes |
|----|-------------|----------------|--------|-------|
| C1 | <mechanically verifiable check> | `<shell-runnable command>` | untested | |
| C2 | ... | ... | untested | |
```

**Rule:** every criterion must be mechanically verifiable — a `grep`, `test`, `curl`, `tsc`, or benchmark command whose output is parseable. No "looks correct" / "feels fast" / "passes review". If you can't write a command for it, it doesn't belong in criteria.

**Examples by feature type:**

| Feature type | Example criteria |
|--------------|------------------|
| New API endpoint | `curl -o /dev/null -w '%{http_code}' /api/X` returns `200`; `pytest tests/test_X.py` exits 0; p95 from `wrk` ≤ N ms |
| Bug fix | failing-test-from-repro now passes; no regression in `npm test`; specific log line no longer appears |
| Refactor | `npm test` still passes; LOC of target module decreases by ≥ X%; no new `any` types |
| Docs | `markdown-link-check` passes; word count of section ≥ N; required headings present |

sp-qa updates the Status column during Run Sprint (`pass` / `fail` / `n-a-this-task`). Sprint Finish reads this file as a gate — see `references/sprint-finish.md` Step 0.5.

Commit the criteria file alongside the spec:

```bash
git add .stackpilot/specs/<date>-<feature>-criteria.md
git commit -m "docs(criteria): acceptance criteria for <feature>"
```

In auto mode B, still write the criteria — sp-qa needs them.

**Phase 3.7: User Reviews Spec Gate**

After spec passes auto-verify AND 12-QA, present the committed spec to the user and pause for review (sourced from `superpowers:brainstorming` step 8):

> "Spec written and committed to `.stackpilot/specs/<file>`. Please review it and tell me if you want any changes before I write the implementation plan."

Wait for user response. If changes requested → edit spec, re-run Phase 3 auto-verify + Phase 3.5 12-QA, then re-present. Only proceed to Phase 4 once user approves.

<!-- CONFIRM-GATE: spec review -->

Skip this gate only in auto mode B (user explicitly chose "Full auto, no checkpoints" at Sprint Clean).

**Phase 4: Plan + Auto-Verify Loop**

8. Map file structure
9. Write plan → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`
10. Verify (up to 1 self-fix round):
    ```bash
    grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/plans/*.md | wc -l  # 0
    grep -c "^### TASK-" .stackpilot/plans/*.md  # >= 3
    grep -cE "relevant_files:|depends_on:|complexity:" .stackpilot/plans/*.md  # task_count * 3
    ```
    Check 4 — type consistency across tasks (manual scan).
    All pass → proceed to **Phase 4.5: Plan Traceability Check** (do NOT skip). Fail after 1 self-fix → escalate.

**Phase 4.5: Plan Traceability Check**

Spec 12-QA already evaluated 12 dimensions — don't re-run them. Read [references/12-qa-matrix.md](references/12-qa-matrix.md) §Plan and run the two-check trace:

- **Forward**: every ✅/⚠️ spec dimension → at least one plan task. Missing → add a task.
- **Reverse**: every plan task → traces to a spec requirement. Orphan → scope creep, remove.

Output a two-column table (spec item → task ID). If both sides clean, pass. If you edit the plan, re-run auto-verify.

11. **Create feature branch** → commit spec and plan → Run Sprint

---

### Sprint In-Progress

If the user's message indicates they want to merge/finish (e.g. "可以合并了", "merge it", "ship it"), skip to **Sprint Complete** below.

```
A. Continue current sprint (Run Sprint)
B. Add a new feature to the current sprint
```

---

## Run Sprint

Core coding phase. Reads plan, dispatches specialist agents in parallel waves, tracks per-task state in `.stackpilot/runs/`.

**Full protocol:** [references/run-sprint.md](references/run-sprint.md) — wave analysis (topological sort over `depends_on`), state.json schema, per-step agent dispatch templates, Sprint Interrupted recovery via state.json.

If running inside Codex, also read [references/codex-dispatch.md](references/codex-dispatch.md). In Codex, `TaskCreate` / `TaskUpdate` means `update_plan`, and each `Agent(...)` block is delegated through the Codex dispatch mapping.

### High-level execution

```
Pre-Sprint:
  1. Parse plan + read config (qa.max_parallel default 3, qa.test_command, qa.deep_review)
  2. Dependency wave analysis — topological sort over depends_on, cap per wave by max_parallel
  3. Init .stackpilot/runs/<sprint-slug>/TASK-NNN/state.json for each task

Sprint Execution Loop (for each wave):
  Dispatch ALL wave-tasks in PARALLEL via TaskCreate + simultaneous Agent calls.
  Each task pipeline (within wave):
    Track → Arch Review (HIGH only) → sp-dev (worktree) → Simplify (skip light)
    → sp-qa (skip light; sp-qa updates acceptance-criteria.md) → Deep Review (HIGH) → Complete
  Wait for ALL wave-tasks to finish before advancing to next wave.
  Pause sprint if any wave-task hits CRITICAL or 3x SOFT-BLOCKED.

Pre-coding confirmation:
  > "Plan ready. <N> tasks across <W> waves (max_parallel=<P>). Proceed?"
  A. Yes   B. I'll handle it elsewhere
```

Detailed bash, agent prompt templates, per-step `state.json` transitions (`pending → arch → dev → simplify → qa → deep-review → complete`), and Sprint Interrupted recovery all live in `references/run-sprint.md`.

### Sprint Complete

**YOU MUST complete the Sprint Finish flow before ending the conversation. Do NOT stop after printing a summary.**

Read [references/sprint-finish.md](references/sprint-finish.md) and follow every step. You MUST present the A/B/C/D branch options and wait for user input.

> **Note:** A `pre-merge-commit` git hook enforces squash-only merges on main/master. Non-squash merges will be rejected by the hook.
