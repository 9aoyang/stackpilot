# Stackpilot Architecture

> Last updated: 2026-04-07

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
│   └── skills/
│       ├── stackpilot/
│       │   ├── SKILL.md           ← /stackpilot main entry point
│       │   └── coordinator.md     ← coordinator intent summary (support file)
│       ├── stackpilot-auto/
│       │   └── SKILL.md           ← /stackpilot:auto full-auto mode
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot:compete competitive gap analysis
│       └── stackpilot-sync/
│           └── SKILL.md           ← /stackpilot:sync external skill tracking
├── scripts/
│   ├── init.sh                    ← project setup
│   ├── dispatch.sh                ← provider-agnostic agent launcher
│   ├── restore.sh                 ← reset runtime state
│   ├── lib/
│   │   ├── config.sh              ← YAML config reader
│   │   └── version.sh             ← auto-upgrade with user-customization preservation
│   └── hooks/
│       ├── pre-commit.sh          ← validates spec/plan format before commit
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
    ├── .locks/                    ← file-based locking for concurrent agents
    ├── .worktrees/                ← git worktree isolation for background agents
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

> **Note:** sp-qa dispatches immediately after each sp-dev task completes (inline review, not batch).

---

## Agent Responsibilities

| Agent | Role | Key Protocol |
|-------|------|-------------|
| **sp-pm** | Reads spec/plan from `.stackpilot/`, writes tasks to `backlog.yml` | Append-only; sets `complexity: light\|standard` per task; self-validation (ID uniqueness, depends_on integrity, circular deps); 5-field task descriptions (What/Where/How/Test hint/Verify); verification before completion |
| **sp-architect** | Reviews task against codebase; writes `arch-review/TASK-ID.md` | Analyzes existing patterns first; one decisive architecture choice; full implementation blueprint; multi-persona adversarial review (Security/Performance/Reliability) for HIGH-risk tasks |
| **sp-dev** | Implements the task | Reads `git log` before starting to avoid repeating failed approaches; traces entry point and call chain before writing; enforces TDD (RED-GREEN-REFACTOR mandatory); 4-phase root cause investigation before fixes (observe/reproduce/trace/hypothesize); atomic-change verify/fix loop (BUILD/LINT/TEST/SCOPE) with stuck detection; reverts uncommitted changes on failure; soft-blocked after 3 failed rounds |
| **sp-qa** | Reviews code changes, writes and runs tests | Two-stage code review (spec compliance + code quality); receiving-review protocol with technical pushback; 12-dimension scenario testing matrix; verify/fix loop max 3 rounds; scoped production fixes allowed |
| **sp-docs** | Updates README, inline comments, API docs | Runs after QA passes; documentation only, never changes logic; verification before completion |
| **sp-coordinator** | Orchestrates the full pipeline | Per-task inline review (dev→qa immediately, not batch); complete soft-blocked retry logic with attempt counting; reads NEEDS_REVIEW → handles timeouts → retries soft-blocked → dispatches pending tasks → checks sprint completion |

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
Phase 1: clarifying questions (one at a time, deep exploration)
Phase 2: design proposal (sectioned, user approves each)
Phase 3: spec auto-verify loop (self-fix, escalates only on 3x failure)
Phase 4: plan auto-verify loop (self-fix, escalates only on 3x failure)
Pre-coding: confirm to start
Coding: autonomous with per-task progress reporting (pauses only on block/critical/new-dep)
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
2. Resolves per-provider model routing via `models.<provider>.<agent>` (3-level config keys: agent-specific → provider default → global)
3. Loads the agent's system prompt from `claude-config/agents/<name>.md`
4. Strips frontmatter; appends task-specific prompt
5. Builds provider-specific CLI command:
   - `claude` — `claude -p <prompt> --allowedTools ...`
   - `codex` — `codex --approval-mode full-auto <prompt>`
   - `gemini` — `gemini -p <prompt>`
   - `custom` — `<provider.command> <prompt>`
6. Creates git worktree isolation for background agents (auto-create in `.stackpilot/.worktrees/`, auto-cleanup after completion)
7. Enforces timeout via `timeout`/`gtimeout` wrapper
8. Tracks agent PID in `.stackpilot/.locks/<agent>.pid`
9. Uses file-based locking (`locked_write` in config.sh, flock + mkdir fallback) for concurrent state updates
10. Runs in background (hooks) or foreground (interactive use)

Tools per agent are declared in frontmatter (`tools: Read, Write, Bash, Glob`) and passed as `--allowedTools` flags for Claude.

If the required CLI is missing, dispatch writes the issue to `NEEDS_REVIEW.md` instead of exiting silently.

---

## Configuration

`stackpilot.config.yml` (project root):

```yaml
provider:
  name: claude
  # model: ~
  # command: ~

qa:
  coverage_threshold: 80
  test_command: npm test    # auto-detected by init.sh

coordinator:
  worktree_limit: 3
  timeout_hours: 2

models:
  claude:
    default: sonnet
    sp-pm: haiku
    sp-architect: opus
    sp-docs: haiku
  codex:
    default: o4-mini
    sp-architect: o3
  gemini:
    default: gemini-2.5-flash
    sp-architect: gemini-2.5-pro
```

---

## Skill Entry Points

| Slash Command | Directory | Purpose |
|--------------|-----------|---------|
| `/stackpilot` | `stackpilot/` | Main entry: status panel + feature flow + coordinator run |
| `/stackpilot:auto` | `stackpilot-auto/` | Full-auto mode: skip all confirmations, end on feature branch |
| `/stackpilot:compete` | `stackpilot-compete/` | Competitive gap analysis from power-user persona |
| `/stackpilot:sync add` | `stackpilot-sync/` | Add a new external skill to track/inline |
| `/stackpilot:sync check` | `stackpilot-sync/` | Check tracked skills for updates |

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

**Test-Driven Development.** sp-dev enforces RED-GREEN-REFACTOR. Tests are written before implementation code. Each completion report records whether TDD was followed.

**Root cause investigation before fixes.** sp-dev runs 4-phase investigation (observe → reproduce → trace → hypothesize) before applying any fix. Prevents symptom-level patching.

**Per-provider model routing.** Config supports `models.<provider>.<agent>` so the same project can use Claude and Codex simultaneously with different model assignments per agent. Lookup: agent-specific → provider default → global.

**Git worktree isolation.** Background agents run in isolated git worktrees, preventing interference between parallel agents and the user's working directory. Worktrees auto-cleanup after agent completion.

**Safe version upgrades.** version.sh diffs before overwriting — user-customized agent/skill files get `.pre-upgrade.bak` backups. Removed agents are cleaned up.

**Auto-detected project configuration.** init.sh detects project language, test framework, and available AI CLI. Supports Node.js, Python, Go, Rust, Ruby, Java/Kotlin, Elixir, PHP, .NET.

---

## Evolution Notes

| Date | Change |
|------|--------|
| 2026-04-07 | Tightened stackpilot interaction flow: Step 1 now summarizes sprint state instead of echoing raw command output, and Visual Companion is invoked inline for specific design questions instead of via a separate permission prompt |
| 2026-04-07 | Auto-detect project stack in init.sh; TDD enforcement + root cause investigation in sp-dev; per-task inline review in coordinator; two-stage code review in sp-qa; per-provider model routing (models.\<provider\>.\<agent\>); git worktree isolation in dispatch; pre-commit hook for spec validation; file-based locking (flock/mkdir); timeout enforcement; safe version upgrades with .bak preservation; coding phase runs autonomously with per-task progress reporting |
| 2026-04-07 | Standard Feature: clarifying questions changed to one-at-a-time deep exploration (from batch); added Phase 1.5 Visual Companion (browser-based mockup/diagram server from superpowers brainstorming); compete skill upgraded with 12-dimension iterative exploration loop + 5-persona debate with consensus scoring and Devil's Advocate dissent |
| 2026-04-04 | Integrated autoresearch patterns: git-as-memory in sp-dev, atomic change + stuck detection in verify/fix loop, 12-dimension scenario testing in sp-qa, multi-persona adversarial review in sp-architect (HIGH risk), Optimize Sprint mode in SKILL.md; added docs/sync.md |
| 2026-04-04 | Renamed all agents to `sp-*` prefix; moved runtime state to `.stackpilot/`; removed all external skill dependencies; inlined brainstorming, writing-plans, finishing, code-architect, code-explorer, code-reviewer protocols |
| 2026-04-01 | Added complexity routing (light/standard), verify/fix loop in sp-dev, soft-blocked retry in coordinator |
| 2026-03-29 | Initial implementation: coordinator + pm + architect + dev + qa + docs agents |
