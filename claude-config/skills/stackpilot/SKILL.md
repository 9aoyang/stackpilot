---
name: stackpilot
description: Use when starting, resuming, or checking on autonomous development work. Acts as a project standup — always shows current status first, then guides next action.
---

# Stackpilot

## Step 1: Show Current State (always run first)

```bash
[ -d .stackpilot ] && echo "initialized" || echo "NOT_INITIALIZED"
cat .stackpilot/tasks/backlog.yml 2>/dev/null || echo "NO_BACKLOG"
cat .stackpilot/tasks/NEEDS_REVIEW.md 2>/dev/null
cat .stackpilot/tasks/in-progress.yml 2>/dev/null
ls .stackpilot/specs/*.md 2>/dev/null || echo "NO_SPECS"
```

Display the status panel in this format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  implement login page    done
🔄 TASK-002  integrate payment API   in-progress
⏳ TASK-003  write unit tests        pending
❌ TASK-004  dashboard layout        failed
❓ TASK-005  multi-user approach     blocked
━━━━━━━━━━━━━━━━━━━━━━━━━
Pending reviews: 1
```

Legend: ✅ done  🔄 in-progress  ⏳ pending  ❌ failed  ❓ blocked

---

## Step 2: Route by State

### Not Initialized

```bash
bash ~/Documents/github/stackpilot/scripts/init.sh
```

Prompt user to edit `stackpilot.config.yml` and set `qa.test_command`, then return to Step 1.

---

### Sprint Clean (no tasks, or all done)

Ask the user what feature they want to build, then **choose path by scope**:

> If the user's request is about **improving / optimizing / fixing degradation** of something measurable (performance, test pass rate, error rate, bundle size, etc.), use the **Optimize Sprint** path below instead of the feature paths.

#### Optimize Sprint (quantifiable improvement goal)

Use when the user says "make X faster", "reduce Y", "improve Z score", "fix the failing tests", etc.

<HARD-GATE>
Do NOT start any optimization until Goal, Scope, Metric, and Verify are all defined. Vague goals produce wasted iterations.
</HARD-GATE>

**Step 1 — Define the 4 parameters** (ask all at once if any are missing):

```
Goal:    What should improve? (e.g., "reduce p95 latency of /api/search")
Scope:   Which files are allowed to change? (glob pattern, e.g., "src/search/**")
Metric:  How is success measured? (must produce a number: ms, %, bytes, count)
Verify:  Shell command that outputs the metric as a number (exit 0 on any result)
---
Guard:   Optional — command that must still pass (e.g., existing test suite)
Limit:   Optional — max iterations (default: 10)
```

**Step 2 — Baseline**: Run `Verify` command once and record the baseline number. This is the score to beat.

**Step 3 — Iteration loop** (repeat up to `Limit` times):

1. **Review**: Run `git log --oneline -10` — what has been tried? What improved? What failed?
2. **Ideate**: Pick the highest-leverage change NOT already tried. Priority:
   - Fix crashes/errors first
   - Then exploit successful patterns from prior iterations
   - Then explore new directions
   - If stuck (3 consecutive no-improvements): switch to a radically different approach
3. **Modify**: Make ONE atomic change (describable in one sentence)
4. **Commit**: `git commit -m "experiment(<scope>): <description>"`
5. **Verify**: Run the `Verify` command → extract the metric value
6. **Guard check** (if defined): run Guard command — must still pass
7. **Decide**:
   - Metric improved AND Guard passes → **Keep** (log result, continue)
   - Metric worse OR Guard fails → **Revert** (`git revert HEAD --no-edit`) and log
8. **Log to `.stackpilot/optimize-log.tsv`**:
   ```
   iteration	commit	metric	delta	outcome	description
   1	abc1234	245ms	-12ms	keep	removed N+1 query in getUserList
   ```

**Step 4 — Summary**: After loop ends (limit reached or user stops), output:
- Best result achieved vs baseline
- Top 3 changes that helped most (from log)
- Ask: "What would you like to do with the changes?" → same finish options as Sprint Finish



#### Light Feature (user says "simple change" / single clear requirement / ≤ 2 sentences)

<HARD-GATE>
Do NOT start any implementation until a plan is written and committed.
</HARD-GATE>

1. **Map file structure** — list all files that will be touched and what changes each needs
2. **Write plan** → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`
   - Decompose into bite-sized tasks (2–5 minutes each)
   - Every task must include: `title`, `description`, `type`, `complexity: light`, `depends_on`, `relevant_files`
   - No placeholders — no TBD, TODO, "similar to Task N", or vague descriptions
   - Every step must contain actual content: specific file paths, specific changes
3. **Plan self-review:**
   - Do all steps map to concrete spec requirements?
   - Any placeholders or vague steps? → fix inline
   - Are types consistent? (dev / qa / docs)
4. **Create feature branch** → commit plan → run Coordinator

#### Standard Feature (multi-module, ambiguous requirements, architectural decisions)

**Phase 1: Exploration**

1. Explore current project state: read `CLAUDE.md`, relevant source files, recent commits
2. Assess scope: if the request spans multiple independent subsystems, flag it immediately and help the user decompose before proceeding
3. Ask all clarifying questions in **one single message** (not one at a time):
   - What is the goal?
   - What are the constraints?
   - What does success look like?
   - Does it involve UI? (PC / mobile / primary interaction path)

**Phase 2: Design**

4. Propose the recommended approach (with 1–2 alternatives briefly noted) including:
   - Architecture overview
   - Components and data flow
   - Error handling strategy
   - Testing approach
5. Send this as **one message** and **wait for user reply**. Revise once if user requests changes, then proceed. <!-- CONFIRM-GATE: design review -->

**Phase 3: Spec + Auto-Verify Loop**

6. Write spec → `.stackpilot/specs/YYYY-MM-DD-<topic>-design.md`
7. **Run mechanical verification** (up to 3 self-fix rounds before escalating):

   ```bash
   # Check 1 — no placeholders
   grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/specs/*.md | wc -l
   # must be 0

   # Check 2 — required sections present
   grep -c "^## " .stackpilot/specs/*.md
   # must be >= 4

   # Check 3 — non-trivial content
   wc -w .stackpilot/specs/*.md | tail -1
   # must be >= 300 words
   ```

   For each failing check:
   - Fix the spec inline
   - Re-run the check
   - Increment attempt counter

   **If all 3 checks pass** → print a one-line summary and auto-proceed to Phase 4. No user prompt.

   **If checks still fail after 3 rounds** → stop, show the specific failing checks only, ask the user for targeted input.

**Phase 4: Plan + Auto-Verify Loop**

8. **Map file structure** — list all files that will be touched and what changes each needs
9. **Write plan** → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`
    - Decompose into bite-sized tasks (2–5 minutes each)
    - Every task must include: `title`, `description`, `type`, `complexity`, `depends_on`, `relevant_files`
    - No placeholders — no TBD, TODO, "similar to Task N", or vague descriptions
    - Every step must contain actual content: specific file paths, specific changes
10. **Run mechanical verification** (same pattern as spec):

    ```bash
    # Check 1 — no placeholders
    grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/plans/*.md | wc -l
    # must be 0

    # Check 2 — at least 3 tasks defined
    grep -c "^### TASK-" .stackpilot/plans/*.md
    # must be >= 3

    # Check 3 — every task has required fields
    grep -cE "relevant_files:|depends_on:|complexity:" .stackpilot/plans/*.md
    # must equal (task_count * 3)
    ```

    **If all checks pass** → auto-proceed.
    **If checks fail after 3 rounds** → escalate with specific failures only.

11. **Create feature branch** → commit spec and plan → run Coordinator

---

### Sprint In-Progress (pending / in-progress tasks exist)

Show options:

```
A. Continue current sprint (run Coordinator to advance tasks)
B. Add a new feature to the current sprint
C. View details of a specific task
```

- **A** → Run Coordinator
- **B** → Follow the feature flow above → commit new spec/plan → Run Coordinator
- **C** → Read `.stackpilot/tasks/done/TASK-ID.md` or `.stackpilot/tasks/arch-review/TASK-ID.md`

---

### Blocked Tasks / NEEDS_REVIEW Has Content (handle first)

Display the blocking issue, analyze options, and guide the user to a decision.

Once user decides, append to `.stackpilot/tasks/NEEDS_REVIEW.md`:

```
REPLY: <decision>
```

Then run Coordinator to unblock.

---

### Failed Tasks

Display failure reason and ask the user:

- **Retry** → set task back to `status: pending` in `backlog.yml`, run Coordinator
- **Skip** → mark task with a disposition note
- **Manual intervention** → help user analyze the problem

---

## Run Coordinator

Execute sp-coordinator's Entry Checklist directly in the current session (no branch switch needed):

1. **Process `.stackpilot/tasks/NEEDS_REVIEW.md`**: has `REPLY:` → unblock; has content but no `REPLY:` → tell user, stop
2. **Process soft-blocked tasks**: `attempt_count < 3` → re-schedule; `≥ 3` → escalate to blocked
3. **Check timed-out tasks** → mark failed
4. **Pre-coding confirmation** — Before dispatching any dev/qa agents, show the task list and ask:

> "Plan is ready. Proceed with coding in this session?"
>
> A. Yes, start coding (continue in current session)
> B. I'll handle it elsewhere (stop here, tasks stay pending for another tool to pick up)

   - **A** → continue to step 5
   - **B** → stop. Do NOT dispatch agents. Tasks remain `pending` in backlog.yml for the user to execute with other tools.

   **Skip this gate when running via `/stackpilot:auto` or triggered by git hook / background dispatch.** <!-- CONFIRM-GATE: pre-coding -->

5. **Dispatch pending tasks** by `complexity` field:
   - `light`: sp-dev → sp-qa (skip sp-architect and sp-docs)
   - `standard`: sp-architect → sp-dev → sp-qa → sp-docs
6. **If no pending / in-progress / soft-blocked** → Sprint complete:

**Sprint Finish:**

After all tasks are done, run the test command from `stackpilot.config.yml` to confirm all tests pass, then **start the dev server for user preview before cleanup or merge**.

**Step 1 — Detect dev server command** (auto-detect from project files, no config needed):

Only detect when there is a clear web server signal. CLI tools, daemons, and batch programs should NOT be started.

```
Check in order, use the first match:
1. package.json exists → read scripts:
   a. Has "dev" script AND dependencies include vite/next/nuxt/webpack/remix/astro/svelte → npm run dev
   b. Has "dev" script with no web framework signal → skip (could be non-web tooling)
   c. No "dev" script → skip
2. manage.py exists + contains "django" → python manage.py runserver
3. Gemfile exists + config/routes.rb exists → bundle exec rails server
4. No match → skip preview, go directly to Step 3
```

Do NOT blindly run `cargo run`, `go run .`, `python app.py`, or `npm start` — these are too ambiguous.

**Step 2 — Start server and present preview URL**:

1. Start the detected command in the background, capture its PID: `<command> & echo $!`
2. Wait for output containing `http://localhost:` or similar URL (timeout 15s)
3. If no URL detected within timeout, kill the process and skip preview
4. Present to user:

> "Sprint complete. All tests passing. Dev server running at:"
>
> `http://localhost:XXXX`  (PID: XXXX)
>
> "Please review the changes in your browser, then tell me how to proceed."

**Wait for user to finish reviewing before continuing.**

**Step 3 — After user confirms review is done**, present options:

> A. Merge into base branch
> B. Push and create a PR
> C. Leave as-is (handle later)
> D. Discard all changes (destructive — confirm first)

**Step 4 — Execute user's choice, THEN cleanup:**

- **A**: Determine base branch (ask if unclear: main / master / dev), then `git merge`
- **B**: `git push -u origin <branch>` then create PR with title and summary describing all completed tasks
- **C**: Do nothing, return sprint status
- **D**: Confirm once with user, then `git checkout <base-branch> && git branch -D <feature-branch>`

**Step 5 — Sprint Cleanup** (only after user's choice is executed, NOT before):

```bash
rm -f .stackpilot/tasks/done/*.md
rm -f .stackpilot/tasks/arch-review/*.md
printf "tasks: []\n" > .stackpilot/tasks/backlog.yml
printf "" > .stackpilot/tasks/NEEDS_REVIEW.md
printf "tasks: []\n" > .stackpilot/tasks/in-progress.yml
```

Stop the dev server if it was started: `kill <PID> 2>/dev/null`
