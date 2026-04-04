# Stackpilot Architecture

> Last updated: 2026-04-04

Stackpilot is a git-hook-driven multi-agent sprint orchestration framework. It turns a specification file into working code by dispatching a pipeline of AI agents — automatically, without manual handoffs.

---

## Mental Model

```
User writes spec → commits it → agents run → code appears
```

The user's only interface is git and the `stackpilot` skill. Everything else is automated.

---

## Directory Layout

```
stackpilot/                        ← framework installation
├── claude-config/
│   ├── agents/                    ← agent system prompts (sp-*.md)
│   │   ├── sp-coordinator.md
│   │   ├── sp-pm.md
│   │   ├── sp-architect.md
│   │   ├── sp-dev.md
│   │   ├── sp-qa.md
│   │   └── sp-docs.md
│   └── skills/stackpilot/
│       ├── SKILL.md               ← user-facing entry point (slash command)
│       ├── skill-refs.md          ← track/sync referenced external skills
│       └── coordinator.md         ← coordinator intent summary
├── scripts/
│   ├── init.sh                    ← project setup
│   ├── dispatch.sh                ← provider-agnostic agent launcher
│   ├── restore.sh                 ← reset runtime state
│   ├── lib/config.sh              ← YAML config reader
│   └── hooks/
│       ├── post-commit.sh         ← triggers sp-pm on new spec/plan
│       └── post-checkout.sh       ← triggers sp-coordinator on branch switch
├── templates/
│   ├── stackpilot.config.yml      ← project config template
│   ├── backlog.yml                ← task list template
│   ├── in-progress.yml            ← active task tracking template
│   └── NEEDS_REVIEW.md            ← escalation inbox template
└── tests/

<project-root>/                    ← user's project
├── stackpilot.config.yml          ← provider, qa, coordinator settings
└── .stackpilot/                   ← runtime state (gitignore optional)
    ├── path                       ← path to stackpilot installation
    ├── specs/                     ← design documents
    ├── plans/                     ← implementation plans
    └── tasks/
        ├── backlog.yml            ← all tasks and their status
        ├── in-progress.yml        ← currently running tasks + started_at
        ├── NEEDS_REVIEW.md        ← escalation inbox (user reads this)
        ├── done/                  ← completion reports (TASK-ID.md)
        └── arch-review/           ← architect review outputs (TASK-ID.md)
```

---

## Agent Pipeline

### Standard Task (multi-module, architectural decisions)

```
sp-pm → sp-architect → sp-dev → sp-qa → sp-docs
```

### Light Task (single-file, clear requirements)

```
sp-pm → sp-dev → sp-qa
```

sp-architect and sp-docs are skipped for light tasks.

---

## Agent Responsibilities

| Agent | Role | Key Protocol |
|-------|------|-------------|
| **sp-pm** | Reads spec/plan from `.stackpilot/`, writes tasks to `backlog.yml` | Append-only; sets `complexity: light\|standard` per task |
| **sp-architect** | Reviews task against codebase; writes `arch-review/TASK-ID.md` | Analyzes existing patterns first; one decisive architecture choice; full implementation blueprint; multi-persona adversarial review (Security/Performance/Reliability) for HIGH-risk tasks |
| **sp-dev** | Implements the task | Reads `git log` before starting to avoid repeating failed approaches; traces entry point and call chain before writing; atomic-change verify/fix loop (BUILD/LINT/TEST/SCOPE) with stuck detection; soft-blocked after 3 failed rounds |
| **sp-qa** | Reviews code changes, writes and runs tests | Code review via `git diff` (confidence ≥ 80 to report); 12-dimension scenario testing matrix; verify/fix loop max 3 rounds; scoped production fixes allowed |
| **sp-docs** | Updates README, inline comments, API docs | Runs after QA passes; documentation only, never changes logic |
| **sp-coordinator** | Orchestrates the full pipeline | Reads NEEDS_REVIEW → handles timeouts → retries soft-blocked → dispatches pending tasks → checks sprint completion |

---

## Event Flow

### `git commit` — new spec or plan committed

```
post-commit.sh
  └─ detects .stackpilot/specs/*.md or .stackpilot/plans/*.md added
       └─ dispatch.sh --agent sp-pm (background)
            └─ sp-pm reads spec/plan → writes tasks to backlog.yml
```

### `git checkout` — branch switched

```
post-checkout.sh
  └─ dispatch.sh --agent sp-coordinator (background)
       └─ sp-coordinator Entry Checklist:
            1. Process NEEDS_REVIEW.md
            2. Handle timed-out tasks
            3. Retry soft-blocked tasks (attempt_count < 3)
            4. Detect circular dependencies
            5. Dispatch pending tasks → sp-architect / sp-dev / sp-qa / sp-docs
            6. Sprint completion check → cleanup → finish workflow
```

### User-triggered (via `stackpilot` skill)

```
/stackpilot
  └─ Show sprint status panel
       └─ Route by state:
            not initialized → run init.sh
            sprint clean    → feature flow (light or standard path)
            in-progress     → A/B/C options
            blocked         → show escalation, guide reply
            failed          → retry / skip / analyze
```

**Standard Feature — human intervention points:**

```
Phase 1: clarifying questions (1 message, 1 reply)
Phase 2: design proposal (1 message, 1 reply; 1 revision allowed)
Phase 3: spec auto-verify loop → only escalates if mechanical checks fail after 3 rounds
Phase 4: plan auto-verify loop → only escalates if mechanical checks fail after 3 rounds
Sprint finish: merge / PR / leave / discard choice
```

**Optimize Sprint — human intervention points:**

```
Step 1: define Goal + Scope + Metric + Verify (1 message if any missing)
Step 2: baseline measurement (automatic)
Step 3: autonomous iteration loop (no interruption unless stuck or limit reached)
Step 4: summary + finish choice
```

Mechanical checks replace blanket review gates. The agent self-fixes and only interrupts
the user with the specific check that failed — not a general "does this look good?" prompt.

---

## Task Lifecycle

```
pending → in-progress → done
                     ↘ soft-blocked (attempt_count++) → pending (retry ≤ 3) → blocked
                     ↘ failed (timeout)
```

- `soft-blocked`: agent self-reported failure (verify/fix loop exhausted); auto-retried up to 3 times
- `blocked`: hard escalation requiring user decision via `NEEDS_REVIEW.md`
- `failed`: coordinator-side timeout (exceeds `coordinator.timeout_hours`)

**NEEDS_REVIEW.md protocol:**
- Agent or coordinator appends an escalation block (options A/B/C)
- User appends `REPLY: <decision>` at the bottom
- Next coordinator run reads the reply, unblocks the task, clears the file

---

## Dispatch Layer

`scripts/dispatch.sh` is provider-agnostic. It:

1. Reads `provider.name` from `stackpilot.config.yml`
2. Loads the agent's system prompt from `claude-config/agents/<name>.md`
3. Strips frontmatter; appends task-specific prompt
4. Builds provider-specific CLI command:
   - `claude` — `claude -p <prompt> --allowedTools ...`
   - `codex` — `codex --approval-mode full-auto <prompt>`
   - `gemini` — `gemini -p <prompt>`
   - `custom` — `<provider.command> <prompt>`
5. Runs in background (hooks) or foreground (interactive use)

Tools per agent are declared in frontmatter (`tools: Read, Write, Bash, Glob`) and passed as `--allowedTools` flags for Claude.

---

## Configuration

`stackpilot.config.yml` (project root):

```yaml
provider:
  name: claude          # claude | codex | gemini | custom
  model: ~              # optional model override
  command: ~            # required when name=custom

qa:
  coverage_threshold: 80
  test_command: npm test

coordinator:
  worktree_limit: 3     # max parallel agent dispatches
  timeout_hours: 2      # task timeout before marking failed
```

---

## Skill Entry Points

| Slash Command | File | Purpose |
|--------------|------|---------|
| `/stackpilot` | `SKILL.md` | Main entry: status panel + feature flow + coordinator run |
| `/skill-refs add` | `skill-refs.md` | Add a new external skill to track/inline |
| `/skill-refs check` | `skill-refs.md` | Check tracked skills for updates |

---

## Key Design Decisions

**No runtime daemon.** The coordinator runs on git events (commit, checkout). No background process to manage.

**State in flat files.** `backlog.yml`, `in-progress.yml`, `NEEDS_REVIEW.md` — all human-readable, git-trackable if desired.

**`.stackpilot/` is gitignore-optional.** Runtime state is local by default. Teams that want shared sprint state can remove the gitignore entry.

**Zero external skill dependencies.** All agent protocols are inlined into the `claude-config/` files. The skill works without any external plugin installed.

**Complexity routing at the task level.** Each task carries `complexity: light | standard`. The coordinator routes accordingly — light tasks skip architect and docs agents, cutting ~60% of agent overhead for simple changes.

**Soft-blocked retry loop.** Agents self-report failure via `soft-blocked` status instead of immediately escalating. The coordinator retries up to 3 times before requiring human input. This handles transient failures (build flakes, minor context issues) without interrupting the user.

**Git as memory.** sp-dev reads `git log --oneline -20` before every task. Prior failed fix attempts are visible in the commit history — the agent learns from them rather than repeating them. The Optimize Sprint loop makes this explicit: every iteration is committed with `experiment(<scope>):` prefix so the history is legible.

**Atomic change principle.** In both sp-dev's verify/fix loop and the Optimize Sprint, each fix attempt is a single logical change describable in one sentence. This makes cause and effect clear, enables git revert on regression, and surfaces the stuck signal cleanly (identical error after identical fix = switch strategy).

**Optimize Sprint.** A purpose-built sprint type for quantifiable improvement goals (performance, error rate, bundle size, etc.). Requires Goal + Scope + Metric + Verify before starting. Runs an autonomous iteration loop with TSV logging and automatic git revert on regression. Inspired by autoresearch (uditgoenka/autoresearch).

---

## Evolution Notes

| Date | Change |
|------|--------|
| 2026-04-04 | Integrated autoresearch patterns: git-as-memory in sp-dev, atomic change + stuck detection in verify/fix loop, 12-dimension scenario testing in sp-qa, multi-persona adversarial review in sp-architect (HIGH risk), Optimize Sprint mode in SKILL.md; added docs/skill-refs.md |
| 2026-04-04 | Renamed all agents to `sp-*` prefix; moved runtime state to `.stackpilot/`; removed all external skill dependencies; inlined brainstorming, writing-plans, finishing, code-architect, code-explorer, code-reviewer protocols |
| 2026-04-01 | Added complexity routing (light/standard), verify/fix loop in sp-dev, soft-blocked retry in coordinator |
| 2026-03-29 | Initial implementation: coordinator + pm + architect + dev + qa + docs agents |
