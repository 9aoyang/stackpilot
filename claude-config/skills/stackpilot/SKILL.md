---
name: stackpilot
description: Sprint orchestration for Claude Code. Turns feature requests into working code through a design→spec→plan→code→QA pipeline. Use when starting, resuming, tidying, or checking on development work. Drives Claude Code's native Agent tool for multi-agent execution with worktree isolation.
license: Apache-2.0
compatibility: Requires Claude Code (uses native Agent tool, TaskCreate, worktree isolation)
metadata:
  author: stackpilot
  version: "1.4.0"
---

# Stackpilot

## Step 1: Show Current State (always run first)

```bash
[ -d .stackpilot ] && echo "initialized" || echo "NOT_INITIALIZED"
[ -f .stackpilot/ARCHITECTURE.md ] && echo "ARCH_EXISTS" || echo "ARCH_MISSING"
cat .stackpilot/NEEDS_REVIEW.md 2>/dev/null
ls -t .stackpilot/plans/*.md 2>/dev/null || echo "NO_PLANS"
ls -t .stackpilot/specs/*.md 2>/dev/null || echo "NO_SPECS"
```

Also check TaskList for any in-progress sprint tasks from the current session.

Additionally, scan for workspace debris:

```bash
# Workflow artifacts
ls .claude/plans/*.md 2>/dev/null
ls -d .superpowers/ 2>/dev/null
git worktree prune --dry-run 2>/dev/null
git remote prune origin --dry-run 2>/dev/null
git status --porcelain 2>/dev/null | head -10
```

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

Re-run Step 1 after init. Only mention config if test_command binary was not found.

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
4. Write `.stackpilot/ARCHITECTURE.md` covering:
   - Tech stack
   - Route/module structure
   - Data layer (DB tables, API surface)
   - Key directories and their purpose
   - Core data flows
   - Design patterns in use
   - Known constraints or gotchas
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

If Step 1 found workflow artifacts (.claude/plans/, .superpowers/, orphaned worktrees, remote-deleted tracking branches), run cleanup before proceeding.

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
- Clear `.stackpilot/NEEDS_REVIEW.md`

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

**3. Check blockers:**

Read `.stackpilot/NEEDS_REVIEW.md` — if has content, present to user first.

**4. Show status and offer choices:**

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
</HARD-GATE>

1. **Map file structure** — list files to touch and changes each needs
2. **Write plan** → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`
   - Bite-sized tasks (2–5 min each)
   - Every task: `title`, `description`, `type`, `complexity: light`, `depends_on`, `relevant_files`
   - No placeholders — no TBD, TODO, vague descriptions
3. **Plan self-review** — types consistent? Placeholders? Method names match across tasks?
4. **Create feature branch** → commit plan → Run Sprint

#### Standard Feature (multi-module, ambiguous, architectural decisions)

**Phase 1: Exploration**

1. Read `CLAUDE.md`, source files, recent commits
2. If request spans multiple subsystems, flag and decompose first
3. **Ask clarifying questions one at a time** — prefer multiple choice, focus on purpose/constraints/success criteria

**Phase 1.5: Visual Companion** (only when a design question benefits from visualization)

Read [references/visual-companion.md](references/visual-companion.md) for setup and usage. Key rule: decide **per question** whether browser or terminal communicates better.

**Phase 2: Design**

4. Propose 2–3 approaches with trade-offs and recommendation
5. Present in sections, get user approval per section <!-- CONFIRM-GATE: design review -->
6. Stop visual companion server if used

**Phase 3: Spec + Auto-Verify Loop**

6. Write spec → `.stackpilot/specs/YYYY-MM-DD-<topic>-design.md`
7. Run verification (up to 3 self-fix rounds):
   ```bash
   grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/specs/*.md | wc -l  # must be 0
   grep -c "^## " .stackpilot/specs/*.md  # must be >= 4
   wc -w .stackpilot/specs/*.md | tail -1  # must be >= 300
   ```
   All pass → auto-proceed. Fail after 3 → escalate specific failures.

**Phase 3.5: Spec 12-QA**

After spec passes auto-verify, review it against the 12 scenario dimensions. For each dimension, check whether the spec adequately addresses it — mark as ✅ covered, ⚠️ partially covered, ❌ missing, or N/A:

| # | Dimension | Check against spec |
|---|-----------|-------------------|
| 1 | **Happy path** | Is the primary success flow clearly defined? |
| 2 | **Error / failure** | Are error cases and failure modes specified? |
| 3 | **Edge case** | Are boundary values and limits addressed? |
| 4 | **Abuse / invalid** | Are invalid inputs and misuse scenarios covered? |
| 5 | **Scale** | Are performance/scale considerations mentioned? |
| 6 | **Concurrent** | Are race conditions or parallel access addressed? |
| 7 | **Temporal** | Are timeouts, retries, ordering dependencies covered? |
| 8 | **Data variation** | Are different valid input shapes considered? |
| 9 | **Permission** | Are auth/access control requirements defined? |
| 10 | **Integration** | Are integration points and contracts specified? |
| 11 | **Recovery** | Is partial failure recovery behavior defined? |
| 12 | **State transition** | Are before/after states clearly described? |

**Rules:**
- Any ❌ on dimensions 1-4 → **must fix spec** before proceeding (these are fundamental)
- Any ❌ on dimensions 5-12 → fix if applicable, mark N/A with reason if genuinely not relevant
- ⚠️ items → add a one-line note to the spec clarifying the gap
- Output the 12-QA result table, then update the spec if needed
- Re-run auto-verify after any spec changes

**Phase 4: Plan + Auto-Verify Loop**

8. Map file structure
9. Write plan → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`
10. Verify:
    ```bash
    grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/plans/*.md | wc -l  # 0
    grep -c "^### TASK-" .stackpilot/plans/*.md  # >= 3
    grep -cE "relevant_files:|depends_on:|complexity:" .stackpilot/plans/*.md  # task_count * 3
    ```
    Check 4 — type consistency across tasks (manual scan).
    All pass → auto-proceed.

**Phase 4.5: Plan 12-QA**

After plan passes auto-verify, review it against the same 12 dimensions — but now checking whether the **tasks** cover each scenario:

| # | Dimension | Check against plan |
|---|-----------|-------------------|
| 1 | **Happy path** | Is there a task for the primary success flow? |
| 2 | **Error / failure** | Are error handling tasks included? |
| 3 | **Edge case** | Do tasks cover boundary/edge conditions? |
| 4 | **Abuse / invalid** | Are input validation tasks present? |
| 5 | **Scale** | Are performance-related tasks included if needed? |
| 6 | **Concurrent** | Are concurrency-safe implementations planned? |
| 7 | **Temporal** | Are timeout/retry tasks included if needed? |
| 8 | **Data variation** | Do tasks handle multiple input shapes? |
| 9 | **Permission** | Are auth/permission tasks included? |
| 10 | **Integration** | Are integration/contract tasks present? |
| 11 | **Recovery** | Are rollback/cleanup tasks included? |
| 12 | **State transition** | Do tasks verify state before/after? |

**Rules:**
- Cross-reference against Phase 3.5 results: every ✅/⚠️ from the spec review must have a corresponding task in the plan
- Any spec-covered dimension that has no plan task → **add a task**
- Any plan task that doesn't trace back to a spec requirement → flag as scope creep
- Output the 12-QA result table, then update the plan if needed
- Re-run auto-verify after any plan changes

11. **Create feature branch** → commit spec and plan → Run Sprint

---

### Sprint In-Progress

```
A. Continue current sprint (Run Sprint)
B. Add a new feature to the current sprint
```

### NEEDS_REVIEW Has Content

Display issue, guide user to decision, clear file, continue sprint.

---

## Run Sprint

Core coding phase. Reads plan, creates tasks, dispatches specialist agents.

### Pre-Sprint

1. Check NEEDS_REVIEW.md — resolve if content exists
2. Read latest `.stackpilot/plans/*.md`, parse `### TASK-` sections
3. Read `stackpilot.config.yml` for `qa.test_command` and `qa.coverage_threshold`

### Pre-coding confirmation

> "Plan ready. Proceed with coding?"
> A. Yes  B. I'll handle it elsewhere

<!-- CONFIRM-GATE: pre-coding -->

### Sprint Execution Loop

For each task in dependency order:

**1. Track**: `TaskCreate` + `TaskUpdate(in_progress)`

**2. Architecture review** (standard complexity only):
```
Agent(description="Arch: TASK-NNN", prompt="<architecture-review skill instructions> + <task context>", model="opus")
```

**3. Development**:
```
Agent(description="Dev: TASK-NNN", prompt="<tdd-development skill instructions> + <task> + <arch review>", isolation="worktree")
```

**4. Handle dev result**:
- `[ESCALATION]` → present to user, wait
- `[SOFT-BLOCKED]` → retry up to 3 times, then ask user

**5. QA review**:
```
Agent(description="QA: TASK-NNN", prompt="<qa-12-dimensions skill instructions> + <task> + <dev result> + Risk level: <from arch review, or LOW> + Review patterns: <.stackpilot/review-patterns.md content>")
```

**6. Handle QA result**:
- `[CRITICAL]` → present to user
- `[SOFT-BLOCKED]` → retry dev+QA cycle

**7. Complete**: `TaskUpdate(completed)`, print progress line:
```
✅ TASK-001  add user model          dev → QA passed     (1/5)
```

**Pause only when**: 3x soft-blocked, QA critical, new external dependency.

### Sprint Complete

**YOU MUST complete the Sprint Finish flow before ending the conversation. Do NOT stop after printing a summary.**

Read [references/sprint-finish.md](references/sprint-finish.md) and follow every step. You MUST present the A/B/C/D branch options and wait for user input.
