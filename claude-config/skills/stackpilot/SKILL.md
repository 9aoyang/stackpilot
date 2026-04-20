---
name: stackpilot
description: Sprint orchestration for Claude Code and Codex. Turns feature requests into working code through a design→spec→plan→code→QA pipeline. Use when starting, resuming, tidying, or checking on development work. Claude uses native Agent/TaskCreate; Codex uses update_plan plus explorer/worker fallback.
license: Apache-2.0
compatibility: Claude Code native; Codex via references/codex-dispatch.md. Sync skills through skillshare as the single target sync source.
metadata:
  author: stackpilot
  version: "1.10.0"
---

# Stackpilot

## Runtime

This skill is synchronized to all targets by skillshare. Do not install a
separate Codex-only `stackpilot` skill.

- Claude Code: use the Agent / TaskCreate examples in this file directly.
- Codex: translate task tracking and subagent dispatch using
  [references/codex-dispatch.md](references/codex-dispatch.md).

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

Core coding phase. Reads plan, creates tasks, dispatches specialist agents.

If running inside Codex, first read
[references/codex-dispatch.md](references/codex-dispatch.md). In Codex,
`TaskCreate` / `TaskUpdate` means `update_plan`, and each `Agent(...)` block
below is delegated through the Codex dispatch mapping. Do not require Claude
Code's `subagent_type` registry inside Codex.

### Pre-Sprint

1. Read latest `.stackpilot/plans/*.md`, parse `### TASK-` sections
2. Read `stackpilot.config.yml` for `qa.test_command` and `qa.coverage_threshold`

### Pre-coding confirmation

> "Plan ready. Proceed with coding?"
> A. Yes  B. I'll handle it elsewhere

<!-- CONFIRM-GATE: pre-coding -->

### Sprint Execution Loop

For each task in dependency order:

**1. Track**: `TaskCreate` + `TaskUpdate(in_progress)`

**2. Architecture review** (standard complexity only):
```
Agent(description="Arch: TASK-NNN",
      subagent_type="sp-architect",
      prompt="<task context>")
```
sp-architect's methodology is loaded from its registered agent file (frontmatter pins `model: opus` and `tools: Read, Glob, Grep, WebSearch` — enforces read-only). Main agent passes only the task context.

**3. Development** (route by task.type):

For `type: docs` tasks → `sp-docs` (haiku, cheaper for mechanical doc updates):
```
Agent(description="Docs: TASK-NNN",
      subagent_type="sp-docs",
      prompt="<task>",
      isolation="worktree")
```

All other types → `sp-dev`:
```
Agent(description="Dev: TASK-NNN",
      subagent_type="sp-dev",
      prompt="<task> + <arch review output>",
      isolation="worktree")
```

**4. Handle dev result**:
- `[ESCALATION]` → present to user, wait
- `[SOFT-BLOCKED]` → retry up to 3 times, then ask user

**5. QA review** (standard complexity only — light tasks rely on sp-dev's TDD verify/fix loop; Claude 4.7 self-catches unit-level issues during dev):
```
Agent(description="QA: TASK-NNN",
      subagent_type="sp-qa",
      prompt="<task> + <dev result> + Risk level: <from arch review, or LOW> + Project memory: <.stackpilot/ARCHITECTURE.md content>")
```

For light tasks, skip the sp-qa dispatch. Main agent still runs the Stage 4 consistency audit grep checks inline (absolute-claim / scope-completeness / dead-reference) since these are deterministic and cheap.

**5.5. Deep Review (default on, HIGH risk only)**:

Read `qa.deep_review` from `stackpilot.config.yml`. Default is `true` if absent. Unless explicitly set to `false`, if Risk level is HIGH, dispatch a fresh-context reviewer to catch scope/consistency issues sp-qa may have anchored past:

```
Agent(description="DeepReview: TASK-NNN",
      subagent_type="general-purpose",
      model="sonnet",
      prompt="You are an independent reviewer. You have NO prior context on this task — that is intentional. Review the following diff purely for scope/consistency issues:\n\n<git diff <pre-task-sha>..HEAD -- <relevant_files> output>\n\nTask description: <task.description>\n\nFind:\n1. Absolute claims (sole/only/never/always) that are factually wrong given the rest of the codebase\n2. Unmigrated call sites, dead references, or renamed symbols still appearing in unchanged files\n3. Cross-file inconsistencies (e.g., doc claims X but code says Y)\n\nReport confidence >= 80 with file:line evidence. Under 200 words. If no findings, reply 'No scope/consistency issues found.'")
```

Merge findings into the QA report before Step 6. If `qa.deep_review: false` is explicitly set, skip silently.

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

> **Note:** A `pre-merge-commit` git hook enforces squash-only merges on main/master. Non-squash merges will be rejected by the hook.
