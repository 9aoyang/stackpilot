---
name: stackpilot
description: Sprint orchestration for Claude Code. Turns feature requests into working code through a design→spec→plan→code→QA pipeline. Use when starting, resuming, or checking on development work. Drives Claude Code's native Agent tool for multi-agent execution with worktree isolation.
license: Apache-2.0
compatibility: Requires Claude Code (uses native Agent tool, TaskCreate, worktree isolation)
metadata:
  author: stackpilot
  version: "2.0"
---

# Stackpilot

## Step 1: Show Current State (always run first)

```bash
[ -d .stackpilot ] && echo "initialized" || echo "NOT_INITIALIZED"
cat .stackpilot/NEEDS_REVIEW.md 2>/dev/null
ls -t .stackpilot/plans/*.md 2>/dev/null || echo "NO_PLANS"
ls -t .stackpilot/specs/*.md 2>/dev/null || echo "NO_SPECS"
```

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

Re-run Step 1 after init. Only mention config if test_command binary was not found.

---

### Sprint Clean

Ask what to build, then choose path by scope.

> If the request is about **improving something measurable** (performance, error rate, bundle size), read [references/optimize-sprint.md](references/optimize-sprint.md) and follow the Optimize Sprint path.

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

Skip when running via `/stackpilot-auto`. <!-- CONFIRM-GATE: pre-coding -->

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
Agent(description="QA: TASK-NNN", prompt="<qa-12-dimensions skill instructions> + <task> + <dev result>")
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

Read [references/sprint-finish.md](references/sprint-finish.md) and follow the Sprint Finish flow.
