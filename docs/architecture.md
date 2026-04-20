# Stackpilot Architecture

> Last updated: 2026-04-20

Stackpilot is a methodology-driven sprint orchestration layer for Claude Code
and Codex. It turns a specification into working code by driving the host
agent's native planning and delegation primitives, with no custom service
infrastructure.

---

## Mental Model

```
User describes feature → design discussion → spec + plan → agents build it → review + ship
```

The user's interface is the `/stackpilot` skill. The skill orchestrates everything using Claude Code's native tools.

---

## Directory Layout

```
stackpilot/                        ← framework installation
├── claude-config/
│   ├── agents/                    ← agent methodology prompts (sp-*.md)
│   │   ├── sp-architect.md        ← read-only architecture review
│   │   ├── sp-dev.md              ← TDD implementation
│   │   ├── sp-qa.md               ← code review + testing
│   │   └── sp-docs.md             ← documentation updates
│   └── skills/
│       ├── stackpilot/
│       │   └── SKILL.md           ← /stackpilot main entry point
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot-compete competitive gap analysis
│       ├── stackpilot-research/
│       │   └── SKILL.md           ← /stackpilot-research deep research (横纵分析法)
│       ├── stackpilot-sync/
│       │   └── SKILL.md           ← /stackpilot-sync external skill tracking
│       └── systematic-debugging/
│           └── SKILL.md           ← /systematic-debugging (portable)
├── codex-config/
│   └── agents/                    ← Codex-native sp-* prompts
├── scripts/
│   ├── init.sh                    ← project setup (minimal: dirs + test command detection)
│   ├── lib/
│   │   └── config.sh              ← YAML config reader
│   ├── sync-skills.sh             ← idempotent Claude skill sync for non-skillshare installs
│   ├── hooks/
│   │   ├── post-commit            ← auto-sync new skills after commit
│   │   ├── pre-merge-commit       ← blocks non-squash merges on main/master
│   │   └── README.md
│   └── preview/
│       ├── start-server.sh        ← visual design companion server
│       └── stop-server.sh
└── templates/
    ├── stackpilot.config.yml      ← config template (qa section only)
    └── stackpilot-inner-gitignore

<project-root>/                    ← user's project
├── stackpilot.config.yml          ← qa settings (test_command, coverage_threshold)
└── .stackpilot/                   ← specs and plans are git-tracked
    ├── specs/                     ← design documents (current sprint)
    └── plans/                     ← implementation plans (current sprint)
```

---

## Agent Pipeline

### Standard Task (multi-module, architectural decisions)

```
sp-architect → sp-dev → sp-qa
```

### Light Task (single-file, clear requirements)

```
sp-dev → sp-qa
```

sp-architect is skipped for light tasks. sp-docs runs when plan includes docs tasks.

> **Note:** sp-qa dispatches immediately after each sp-dev task completes (inline review, not batch).

---

## /stackpilot-bench (sibling skill)

`/stackpilot-bench` is a standalone benchmark skill. Its primary output is
a **scorecard** comparing stackpilot to native Claude Code across five
dimensions — correctness, over-engineering resistance, bug catch rate,
token efficiency, and wall-clock speed — on 0-100 scales. The scorecard
answers "is stackpilot worth using over native Claude Code / Codex?".
Current benchmark runs dispatch two legs (`zero` / `stackpilot`) against a
single high-discrimination workload, append rows to
`.stackpilot/benchmarks/history.csv`, and write a scorecard to
`runs/<timestamp>/`.

**Installed workload** (v4, 2026-04-20 Codex discrimination rebuild):

| ID | Complexity | Task | Why /stackpilot matters |
|---|---|---|---|
| `01-regional-billing-ledger-cutover` | ultimate (30+ files) | Move billing writes to a regional ledger while preserving subscription API, webhooks, refunds, exports, reconciliation, rollback, and backfill safety | hidden constraints across docs/tests/source; native zero can produce plausible code while missing idempotency, PII, response-shape, rollback, or migration invariants |

The v1/v2/v3 workloads all let native zero-shot score near the ceiling
on current Codex, so they were removed from the active benchmark. The v4
workload intentionally removes the `savvy` leg and measures only the real
decision: native zero-shot versus explicit `/stackpilot` orchestration.
See
`docs/bench-implementation.md § Workload selection error (2026-04-20
post-mortem)` for the full lesson.

Every trap carries `category: over-engineering | correctness`.
Scorecard automatically flags any workload where the zero leg scores
>90 as `🚫 NON-DISCRIMINATIVE` and excludes it from the overall
composite (see `references/scoring.md § Discrimination check`).

**Sandbox isolation**: each leg dispatch operates inside
`.worktrees/bench-run/bench-sandbox/`, a throwaway subdirectory populated
from the workload's `sandbox/` fixture. The rest of the bench worktree
retains main's files so sub-agents have project context;
`reset-worktree.sh` resets to `base_sha` between legs and commits a fresh
leg-start SHA for scoped diff capture.

**Hidden evaluator**: workload contract tests live outside the sandbox under
`workloads/<id>/evaluator/`. The model cannot see them during implementation.
After a leg finishes and after the scoped diff is captured, the runner copies
that evaluator into `bench-sandbox/.stackpilot-hidden-evaluator/` and executes
`verification_commands` against the final code. This prevents the benchmark
from becoming an open-book test while preserving durable raw artifacts.

**Headless execution** (scaffolded 2026-04-20, not yet default): each leg
runs as an isolated `claude --print` subprocess via `run-leg-headless.sh`,
removing the parent-session prompt-cache leak that biased v1 token
counts. See `claude-config/skills/stackpilot-bench/references/headless-mode.md`
for the flip checklist.

**Codex execution** (added 2026-04-20): Codex runs use
`run-codex-bench.sh`, which dispatches each leg through
`codex exec --json --ephemeral`, parses `turn.completed.usage`, captures
tool calls from `command_execution` events, and writes the same
`history.csv` / `scorecard.md` outputs as the Claude runner. Before
scoring, the runner performs `git add -N` on `bench-sandbox/` so newly
created files are visible in the diff without staging content.

For the `stackpilot` leg, the runner also verifies the Codex execution
contract: `bench-sandbox/.stackpilot-bench/architect.md`,
`dev-report.md`, and `qa-report.md` must exist and contain phase-specific
evidence. Missing or generic phase evidence marks the row
`orchestration_invalid`, and the scorecard treats that leg as zero quality
instead of scoring it as a normal Stackpilot result.

---

## Agent Responsibilities

| Agent | Role | Key Protocol |
|-------|------|-------------|
| **sp-architect** | Reviews task against codebase; returns architecture decision | Non-negotiable boundaries at top of prompt (read-only, one decision not a list, justified risk). Extended thinking on every review (not HIGH-only). Multi-persona: full 3 on HIGH, single on LOW/MEDIUM. Reads `.stackpilot/ARCHITECTURE.md § Key Design Decisions`, cites prior decisions verbatim. Prescriptive Process 1-5 steps replaced by general "what to ground in" instructions per Anthropic's Claude 4.x guidance ("prefer general instructions over prescriptive steps"). Emits `## Decision Candidates` on HIGH; returns `[ESCALATION]` for new deps or structural conflicts |
| **sp-dev** | Implements the task | Six explicit "Don't add X" boundaries at the top (primacy position, mirroring Anthropic's "Avoid over-engineering" template): no error handling for impossible cases, no defensive validation on trusted inputs, no comments explaining well-named code, no single-use helpers, no unrelated refactors, no unrequested tests. Reads `git log` to avoid repeating failed approaches. TDD (RED-GREEN-REFACTOR). Verify/fix loop with stuck detection; reverts on failure; `[SOFT-BLOCKED]` after 2 failed rounds |
| **sp-qa** | Reviews code, writes tests | Opens with adversarial KPI ("your job is finding reasons this PR should not ship"). Every finding requires `file:line` + concrete failure scenario + ≥80% confidence. Mandatory "Adversarial Angles Tried" completion field so "no findings" is earned, not assumed. Prescriptive Stages 1-3 replaced by open adversarial angles; deterministic Consistency Audit (absolute-claim / scope-completeness / dead-reference, HIGH-risk mandatory) preserved verbatim — stackpilot's unique value. Reads `.stackpilot/ARCHITECTURE.md` for Review Patterns; emits `## Pattern Candidates`. **Dispatches on standard complexity** — light tasks rely on sp-dev's TDD. |
| **sp-docs** | Updates README, comments, API docs | **Uses haiku 4.5** (mechanical task); runs after QA passes; documentation only. |

---

## How Agents Are Dispatched

### Claude Code

The Claude `/stackpilot` skill orchestrates agents using Claude Code's native
tools:

```
Agent(
  description="Implement TASK-001",
  prompt="<sp-dev methodology> + <task context> + <arch review>",
  isolation="worktree"    ← Claude Code creates/manages the worktree
)
```

**Key benefits over v1 dispatch.sh:**
- Fork pattern cache sharing (~66% input token savings)
- Automatic worktree creation and cleanup
- Built-in timeout and abort handling
- Direct result return (no file I/O for inter-agent communication)
- Agent results flow as prompt context: architect output → dev prompt → QA prompt

**Task tracking** uses Claude Code's native `TaskCreate`/`TaskUpdate` instead of YAML files.

### Codex

The Codex `/stackpilot` skill is the same shared skill synchronized by
skillshare. It uses `references/codex-dispatch.md` for visible task tracking
and dispatches the same methodology prompts through Codex subagents:

| Stackpilot role | Codex dispatch |
|---|---|
| `sp-architect` | named role if available, otherwise `explorer` with `codex-config/agents/sp-architect.md` |
| `sp-dev` | named role if available, otherwise `worker` with explicit file ownership |
| `sp-qa` | named role if available, otherwise `worker` with QA-only ownership |
| `sp-docs` | named role if available, otherwise `worker` with docs-only ownership |

This keeps skillshare as the single synchronization source for shared skills
and avoids a false dependency on Claude Code's `subagent_type` registry inside
Codex.

Codex runs must leave auditable phase evidence (`architect.md`,
`dev-report.md`, `qa-report.md`) and QA must inspect the final diff. This
prevents `/stackpilot` in Codex from degrading into a style hint; consumers
that cannot verify the evidence mark the run `orchestration_invalid`.

---

## Event Flow

### User-triggered (via `/stackpilot` skill)

```
/stackpilot [feature description]
  └─ Show sprint status + scan workspace
       └─ Route by state:
            not initialized    → run init.sh
            workspace dirty    → tidy (clean workflow artifacts, prune branches/worktrees)
            sprint interrupted → resume (match plan tasks to git log, offer continue/fresh)
            sprint clean       → ask what to build → choose auto or interactive → feature flow
            in-progress        → continue sprint
```

**Standard Feature — human intervention points:**

```
Phase 1: scout code first (grep + read 2-5 files) → clarifying questions (one at a time) → canonical refs captured in spec
Phase 1.5: visual companion (browser-based mockups, only when visual helps)
Phase 2: design proposal (sectioned, user approves each)
Phase 3: spec auto-verify loop (self-fix, escalates only on 3x failure)
Phase 3.5: spec 12-QA (12-dimension scenario coverage review of spec)
Phase 4: plan auto-verify loop (self-fix, escalates only on 3x failure)
Phase 4.5: plan traceability check (spec→task forward trace + task→spec reverse trace; no re-run of 12 dimensions)
Pre-coding: confirm to start
Coding: autonomous with per-task progress reporting
Sprint finish: squash merge (1 commit on main) / PR / leave / discard choice
  ↳ pre-merge-commit hook rejects non-squash merges on main as a hard guard
```

---

## Task Lifecycle

```
pending → in-progress → done
                     ↘ soft-blocked (retry ≤ 3) → done
                     ↘ blocked (3x failures → user decision)
```

- `soft-blocked`: agent returned `[SOFT-BLOCKED]`; main session retries up to 3 times
- `blocked`: 3 retries exhausted, escalated to user for decision
- Tracking via Claude Code's `TaskCreate`/`TaskUpdate` (session-scoped)
- Persistence via plan files (git-tracked, survives session restarts)

---

## Configuration

`stackpilot.config.yml` (project root, v2 — minimal):

```yaml
qa:
  coverage_threshold: 80
  test_command: npm test    # auto-detected by init.sh
```

Model routing is handled by Claude Code natively (agent frontmatter `model:` field).

---

## Skill Entry Points

| Slash Command | Purpose |
|--------------|---------|
| `/stackpilot` | Main entry: tidy + resume + status + auto/interactive mode + sprint execution. Claude and Codex share the same skill; Codex dispatch is described in `references/codex-dispatch.md`. |
| `/stackpilot-compete` | Competitive gap analysis from power-user persona |
| `/stackpilot-research` | Deep research reports using cross-longitudinal analysis (横纵分析法) |
| `/stackpilot-sync` | External skill tracking and sync (developer maintenance) |
| `/tdd-development` | **Portable** — TDD + verify/fix + rationalization blockers |
| `/qa-12-dimensions` | **Portable** — 12-dimension test coverage + code review |
| `/architecture-review` | **Portable** — Codebase pattern analysis + blueprint |
| `/systematic-debugging` | **Portable** — 4-phase root cause investigation + red flags |

---

## Agent Skills Compliance

Stackpilot follows the [Agent Skills open standard](https://agentskills.io) maintained by Anthropic.

**Portable methodology skills** — work in any Agent Skills-compatible product (Cursor, VS Code Copilot, Gemini CLI, OpenAI Codex, JetBrains Junie, and 25+ more):

| Skill | What it does | Portable? |
|-------|-------------|-----------|
| `tdd-development` | TDD cycle + verify/fix loop + rationalization blockers | Yes |
| `qa-12-dimensions` | Two-stage code review + 12-dimension test coverage | Yes |
| `architecture-review` | Pattern analysis + decisive architecture choice + blueprint | Yes |
| `systematic-debugging` | 4-phase root cause investigation + red flag detection | Yes |

**Orchestration skills** — Claude Code-specific (use native Agent tool, TaskCreate):

| Skill | What it does |
|-------|-------------|
| `stackpilot` | Full sprint lifecycle: tidy → resume → design → spec → plan → code → QA → ship. Includes auto mode (skip confirmations) and workspace cleanup. |

**Progressive disclosure** — SKILL.md stays under 500 lines. Heavy content (visual companion, optimize sprint, sprint finish) lives in `references/` and loads on demand.

---

## Key Design Decisions

**Claude Code-native orchestration (v2).** Agents are dispatched via Claude Code's Agent tool with `isolation: "worktree"`. No custom bash dispatcher, no git worktree management, no file locking. Claude Code handles all infrastructure.

**Prompt-based inter-agent communication.** Agent outputs flow directly as prompt context to downstream agents. No intermediate files (arch-review/, done/). The main session is the coordinator.

**Plan as persistence layer.** Tasks are tracked in-session via TaskCreate. Plan files are the persistent source of truth. The resume flow reconstructs state from plan + git log.

**Zero external dependencies.** All agent protocols are inlined. The skill works without any external plugin installed.

**Complexity routing at the task level.** Each task carries `complexity: light | standard`. Light tasks skip architect, cutting ~60% of agent overhead for simple changes.

**Soft-blocked retry.** Agents self-report failure via `[SOFT-BLOCKED]` output. The main session retries up to 3 times before requiring human input.

**Git as memory.** sp-dev reads `git log --oneline -20` before every task. Prior failed approaches are visible in commit history.

**Agents dispatch via explicit subagent_type.** SKILL.md's `Agent()` calls pass `subagent_type="sp-architect"` / `"sp-dev"` / `"sp-qa"` / `"sp-docs"` so Claude Code routes to the registered agent (with its frontmatter-declared model and tool restrictions) rather than falling back to `general-purpose`. Required path: agents must be registered at `~/.claude/agents/` or within an installed plugin. Claude Code caches the registry at session start — after install, restart Claude Code to activate. sp-docs is routed by task.type: `type: docs` tasks go to sp-docs (haiku), all others to sp-dev (sonnet).

**Don't re-teach Claude what it knows.** Agent methodology files specify the stackpilot orchestration contract — input format, completion output format, escalation signals, cross-sprint memory hooks. They do NOT include generic engineering advice (how to TDD, how to review, how to debug) because Claude 4.7 does those natively. This principle drove a ~47% trim of sp-dev and sp-qa methodologies on 2026-04-17.

**Agent-prompt engineering principles (adopted 2026-04-20).** After a cross-sourced review of Anthropic docs (Claude 4.x prompting guide, effective context engineering, Claude Code best practices), academic literature (Lost in the Middle, Curse of Instructions, Sprague 2024 "To CoT or not to CoT"), and the 2026-04-20 survey in `research/260420-1130-prompt-length-claims/`, sp-* agent prompts follow these rules:

1. **Non-negotiable boundaries at the TOP of every prompt.** First-position tokens have the highest attention weight (primacy + attention-sink), so hard red lines go there — not buried in the middle. U-shape design: repeat critical reminders at the bottom.
2. **≤5 hard rules per agent.** Research on instruction count (Curse of Instructions, IFScale) shows following-rate decays toward ~80% once you exceed ~5 instructions. Anything beyond that belongs as guidance, not as an invariant.
3. **Prefer general instructions over prescriptive steps** (official Anthropic Claude 4.x guidance). Explicit "step 1, step 2, step 3" lists now often *reduce* quality on strong models with adaptive thinking; they're kept only where the structure is part of the output contract (e.g., sp-dev's Completion Output schema).
4. **Explicit negative boundaries for over-engineering.** sp-dev carries six `Don't add X` lines matching Anthropic's own "Avoid over-engineering" template. Anthropic has publicly acknowledged Claude Opus 4.5/4.6 over-engineer by default (FeatBench 2025: 73.6% of coding-agent failures are scope creep). A concrete negative boundary is the single biggest quality lever for a code agent.
5. **No positive-example filler.** "You are a senior engineer who takes pride in…" filler drops the signal-to-token ratio without measurable benefit on Claude 4.x.

**Self-verification at Sprint Finish.** When Step 2 starts the dev server, the main agent auto-curls the preview URL and reports HTTP status before handing control to the user. Non-2xx/3xx or connection failure is surfaced with the last 20 lines of server log — catches the "server binds but app 500s" class of regression without any per-task overhead.

**Single-file project memory.** `.stackpilot/ARCHITECTURE.md` is the sole per-project memory surface. Fixed sections: What This Project Is / Stack / Key Directories / Data Flow / Key Design Decisions / Conventions & Gotchas / Review Patterns. Only the main agent writes it, and only at Sprint Finish (Step 4a). Sub-agents are read-only: `sp-architect` reads `§ Key Design Decisions` and surfaces new HIGH-risk decisions via a `## Decision Candidates` block in its report; `sp-qa` reads `§ Review Patterns` & `§ Conventions & Gotchas` and surfaces new patterns via a `## Pattern Candidates` block. The main agent merges both at Sprint Finish. This keeps writes serial on the feature branch and avoids worktree-level write contention.

**TDD enforcement.** sp-dev enforces RED-GREEN-REFACTOR. Tests written before implementation.

**Root cause investigation.** 4-phase investigation (observe → reproduce → trace → hypothesize) before any fix.

---

## Evolution Notes

| Date | Change |
|------|--------|
| 2026-04-20 | **Closed-book benchmark evaluator.** Moved regional ledger contract tests out of the visible sandbox into `workloads/<id>/evaluator/`. The Codex bench runner now injects them only after model execution as `.stackpilot-hidden-evaluator/` and runs verification commands against that hidden suite, preventing zero-shot and stackpilot legs from reading or editing the answer key. |
| 2026-04-20 | **Codex Stackpilot execution contract.** Codex `/stackpilot` now requires auditable `architect.md`, `dev-report.md`, and `qa-report.md` phase artifacts for standard-or-higher tasks. `/stackpilot-bench` verifies those artifacts for the stackpilot leg, excludes `.stackpilot-bench/**` from implementation diff scoring, runs workload verification commands, and marks missing phase evidence as `orchestration_invalid` with zero quality score. |
| 2026-04-20 | **Single ultimate workload + two-leg Codex benchmark.** Removed the three v3 workloads after Codex zero-shot scored near ceiling on all of them. Active bench now uses one high-discrimination regional billing ledger cutover workload and compares only `zero` vs `stackpilot`; `savvy` is no longer part of default runs. History was reset so obsolete native-enough rows do not pollute future analysis. |
| 2026-04-20 | **Codex benchmark runner.** Added `run-codex-bench.sh` and `run-leg-codex.sh` so `/stackpilot-bench` can measure Codex-side native zero / stackpilot legs through `codex exec --json --ephemeral`. The runner writes the same durable history and human-readable scorecard as the Claude protocol, normalizes Codex usage fields, and uses `git add -N` before diff capture so untracked new files are scored. |
| 2026-04-20 | **v3 workloads + scorecard discrimination check.** First post-baseline bench run (2026-04-20-0419) produced a misleading "stackpilot 明显落后" verdict because the v2 workloads were too simple — native zero scored 97/100, leaving no headroom for /stackpilot to earn its overhead. Post-mortem in `docs/bench-implementation.md § Workload selection error`. Fixes: (a) `compute-scorecard.sh` now marks any workload where zero-leg composite >90 as `🚫 NON-DISCRIMINATIVE` and excludes it from the overall composite; if all workloads are non-discriminative, headline reads `INCONCLUSIVE`. (b) v3 workloads installed — `01-saas-subscription-feature` (ambiguous scope), `02-search-migration-no-downtime` (dual-write hazards), `03-multi-tenant-audit-logging` (cross-system consistency) — designed around real /stackpilot usage patterns, not isolated well-specified tasks. These v3 workloads were later removed after Codex zero-shot also saturated them. |
| 2026-04-20 | **Bench transformation + agent prompt reshape.** (1) `/stackpilot-bench` headline output switched from regression verdict to product-comparison scorecard (5 dimensions × 0-100, per-workload breakdown). (2) Verdict quality gate now counts `traps_caught_in_qa` at 0.5 weight so sp-qa improvements are visible. (3) Three representative workloads installed — `01-stripe-invoice-api`, `02-rate-limit-middleware`, `03-moment-to-datefns-refactor` — replacing those deleted 2026-04-17. (4) Headless `claude --print` execution scaffolded (not yet default). (5) sp-dev adds 6 explicit "Don't add X" over-engineering boundaries at prompt top. (6) sp-architect swaps prescriptive Process 1-5 for general instructions per Anthropic Claude 4.x guidance. (7) sp-qa reshaped around adversarial KPI + required evidence schema; deterministic Consistency Audit preserved. All changes grounded in 2026-04-20 Anthropic-docs + academic research survey (see `research/260420-1130-prompt-length-claims/`). |
| 2026-04-17 | **v1.10.0**: Opus 4.7 pipeline adaptations: per-phase effort advisory in `stackpilot.config.yml` (architect/dev/qa/docs); effort posture lines in all 4 agents; cross-sprint memory via `.stackpilot/sprint-metrics.md` (appended by sprint-finish) and `.stackpilot/decisions.md` (appended by sp-architect on HIGH-risk); Sprint Clean surfaces 3-sprint trend advisory; auto-verify loops reduced 3→2 rounds; SKILL.md 12-QA tables extracted to `references/12-qa-matrix.md`. |
| 2026-04-16 | **v1.9.1**: Removed codex-plugin-cc cross-model review integration from sp-qa. Replaced with optional Claude Code `/ultrareview` for HIGH-risk tasks (requires Opus 4.7+). Cleaner single-source toolchain aligned with Claude Code native stance. |
| 2026-04-16 | **v1.9.0**: Hardened sprint pipeline with gstack-inspired improvements: sp-qa WTF self-monitoring heuristic (revert/fix ratio, hard cap 15 fixes), anti-sycophancy and forcing questions in Phase 1 Exploration, Step 0 pre-merge verification gate in sprint-finish (typecheck + lint + tests), 3-strike escalation rule in systematic-debugging, `--quick` flag for sync-skills. |
| 2026-04-13 | **v1.8.0**: Skill auto-sync (`sync-skills.sh --auto-update`), post-commit hook for new skill detection, version self-check in `/stackpilot` Step 0, fixed `install.sh` `cp -r` for `references/` subdirs. |
| 2026-04-13 | **v1.7.0**: Added `/stackpilot-research` skill — cross-longitudinal analysis (横纵分析法) for deep research reports. 3-wave research strategy, narrative output, quality self-check. Explicit invocation only. |
| 2026-04-12 | **v1.6.1**: Sharpened agent prompts (sp-dev, sp-architect, sp-qa, sp-docs) and SKILL.md planning gates with Karpathy coding principles: positive traceability over negative constraints, assumption surfacing, simplicity self-checks, anti-scope-creep in plans. |
| 2026-04-11 | **v1.6.0**: Added `pre-merge-commit` git hook to enforce squash-only merges on main/master. Installed by `init.sh`. Bypass via `STACKPILOT_ALLOW_MERGE=1`. |
| 2026-04-11 | **v1.5.3**: Fixed 12-QA phases being skipped — replaced ambiguous `auto-proceed` with explicit phase references so LLMs don't jump over Phase 3.5/4.5. |
| 2026-04-11 | **v1.5.2**: Fixed `/release` skill to include architecture docs in release commit, satisfying pre-commit hook. |
| 2026-04-11 | **v1.5.1**: Removed unused `NEEDS_REVIEW.md` mechanism. Fixed zsh `no matches found` errors by replacing glob patterns with `find`. |
| 2026-04-11 | **v1.5.0**: Added 12-QA review gates after spec (Phase 3.5) and plan (Phase 4.5) — 12-dimension scenario coverage review with hard gates on dimensions 1-4. |
| 2026-04-11 | **v1.4.0**: Project-local `/release` skill — auto-generates CHANGELOG from git log (conventional commits), detects bump type (major/minor/patch), bumps all three version files atomically, validates with pre-commit, tags, and pushes. Added `.stackpilot/ARCHITECTURE.md` quick-reference. |
| 2026-04-11 | **v1.3.0**: Sprint Finish squash merge — feature branch commits folded into one commit on main. Pre-merge housekeeping (arch update, artifact cleanup) committed on feature branch before squash. Feature branch auto-deleted after merge. |
| 2026-04-10 | **v2.1 consolidation**: Merged stackpilot-auto, stackpilot-resume, stackpilot-tidy into main `/stackpilot` as state-routed flows (6→3 orchestration commands). Removed archive mechanism — plans/specs deleted directly (git history is sufficient). Added workspace tidy flow (clean .claude/plans/, .superpowers/, orphaned worktrees, merged branches). Added auto/interactive mode choice after user describes feature. |
| 2026-04-08 | **v2 architecture**: Replaced dispatch.sh with Claude Code native Agent tool; replaced backlog.yml with TaskCreate; removed sp-pm and sp-coordinator (inlined in skill); removed git hooks; simplified config to qa-only; added /stackpilot-resume; agents become pure methodology prompts with no file I/O. Adopted Agent Skills open standard: extracted 3 portable methodology skills (tdd-development, qa-12-dimensions, architecture-review) usable in any Agent Skills-compatible product; restructured SKILL.md with progressive disclosure (references/); all name fields comply with spec |
| 2026-04-07 | Tightened interaction flow; Visual Companion inline; auto-detect project stack; TDD + root cause investigation; per-task inline review; per-provider model routing; git worktree isolation; pre-commit validation; file locking; timeout enforcement; autonomous coding with progress reporting |
| 2026-04-07 | One-at-a-time clarifying questions; Visual Companion browser server; compete skill 12-dimension + 5-persona debate |
| 2026-04-04 | Integrated autoresearch patterns; 12-dimension testing; multi-persona review; Optimize Sprint; docs/sync.md |
| 2026-04-04 | Renamed to sp-* prefix; .stackpilot/ runtime state; inlined all external skill protocols |
| 2026-04-01 | Complexity routing, verify/fix loop, soft-blocked retry |
| 2026-03-29 | Initial implementation |
