# Stackpilot Architecture

> Last updated: 2026-06-10

StackPilot is a general methodology for coding agents. It turns a request into
verified software through exploration, design, spec, criteria, planning,
execution, review, and finish. Host adapters implement the same gates with each
agent platform's native tools; the Claude Code adapter is currently the most
complete implementation.

---

## Mental Model

```
User describes feature → StackPilot entry → internal gates route → host adapter executes → evidence gates → finish
```

The user's interface is StackPilot, not a flat catalog of process skills. In
Claude Code, the visible entry is `/stackpilot` or a natural-language request
routed by `stackpilot-bootstrap`. `stackpilot-methodology` and the smaller
portable skills are internal gates that keep the method strict across hosts; the
`/stackpilot` command is the Claude Code host adapter for autonomous sprint
execution.

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
│       ├── stackpilot-methodology/
│       │   └── SKILL.md           ← internal portable methodology core
│       ├── stackpilot-planning/
│       │   └── SKILL.md           ← internal implementation planning gate
│       ├── stackpilot-workspace/
│       │   └── SKILL.md           ← internal isolation/setup/baseline gate
│       ├── stackpilot-plan-execution/
│       │   └── SKILL.md           ← internal task-by-task execution gate
│       ├── stackpilot-parallel-agents/
│       │   └── SKILL.md           ← internal independent parallel dispatch gate
│       ├── stackpilot-review-response/
│       │   └── SKILL.md           ← internal review feedback handling gate
│       ├── stackpilot-completion-verification/
│       │   └── SKILL.md           ← internal evidence-before-claims finish gate
│       ├── stackpilot-skill-authoring/
│       │   └── SKILL.md           ← maintainer-only skill creation/update gate
│       ├── stackpilot/
│       │   ├── SKILL.md           ← /stackpilot main entry point
│       │   └── references/
│       │       ├── run-sprint.md
│       │       ├── sprint-finish.md
│       │       ├── 12-qa-matrix.md
│       │       └── views/         ← optional browser view templates
│       │           ├── design-options.html
│       │           ├── dashboard.html
│       │           ├── spec-review.html
│       │           ├── finish-report.html
│       │           └── architecture.html
│       ├── stackpilot-research/
│       │   └── SKILL.md           ← /stackpilot-research deep research (横纵分析法)
│       ├── stackpilot-sync/
│       │   └── SKILL.md           ← /stackpilot-sync external skill tracking
│       └── systematic-debugging/
│           └── SKILL.md           ← /systematic-debugging (portable)
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
│       ├── start-server.sh        ← sprint/visual server (v2: HTML view host + WS state stream)
│       ├── stop-server.sh
│       ├── server.cjs             ← extended with /sprints/<slug>, /api/action, /api/state
│       └── helper.js              ← WS client + window.sp.{action,state} sprint API
├── hooks/
│   ├── hooks.json                 ← Claude plugin SessionStart hook manifest
│   ├── hooks-cursor.json          ← Cursor plugin sessionStart hook manifest
│   ├── session-start              ← injects stackpilot-bootstrap at conversation start
│   └── pre-tool-use               ← blocks feature/bug/code tools before process skill activation
├── .claude-plugin/
│   └── plugin.json                ← Claude Code plugin metadata
├── .cursor-plugin/
│   └── plugin.json                ← Cursor StackPilot routing/package metadata
├── .codex-plugin/
│   └── plugin.json                ← Codex StackPilot package metadata
├── gemini-extension.json          ← Gemini extension metadata
├── GEMINI.md                      ← Gemini routing + tool mapping context
└── templates/
    ├── stackpilot.config.yml      ← config template (qa section only)
    └── stackpilot-inner-gitignore

<project-root>/                    ← user's project
├── stackpilot.config.yml          ← qa settings (test_command, coverage_threshold)
└── .stackpilot/
    ├── ARCHITECTURE.md            ← project memory (data layer)
    ├── specs/                     ← design documents + criteria (data layer)
    ├── plans/                     ← implementation plans (data layer)
    ├── feedback/                  ← external audit inbox (data layer)
    │   ├── open/*.md              ← unresolved human/external feedback
    │   └── resolved/*.md          ← handled feedback with # Resolution
    ├── runs/<sprint>/TASK-*/state.json   ← per-task phase state (data layer)
    ├── runs/<sprint>/events.jsonl        ← durable dispatch / verification / decision log
    ├── runs/<sprint>/handoff.json        ← compact phase/status/next-action resume contract
    ├── runs/<sprint>/sprint-evals.md     ← finish retrospective from events/state/criteria
    └── views/                     ← optional generated browser artifacts (view layer, gitignored)
        └── <sprint>/{design-options,dashboard,spec-review,finish-report}.html
```

---

## Agent Pipeline

### Standard Task (multi-module, architectural decisions)

```
sp-architect → sp-dev → /simplify → sp-qa
```

### Light Task (single-file, clear requirements)

```
sp-dev
```

sp-architect, /simplify, and sp-qa are skipped for light tasks (low ROI on small/mechanical diffs; sp-dev's TDD verify/fix loop covers correctness). sp-docs runs when plan includes docs tasks.

> **Note:** sp-qa dispatches immediately after /simplify on each task (inline review, not batch). /simplify runs scoped to the task's `relevant_files`, must preserve test pass status, and commits its diff separately so QA sees dev and simplify changes distinctly.

---

## Agent Responsibilities

| Agent | Role | Key Protocol |
|-------|------|-------------|
| **sp-architect** | Reviews task against codebase; returns architecture decision | Non-negotiable boundaries at top of prompt (read-only, one decision not a list, justified risk). Extended thinking on every review (not HIGH-only). Multi-persona: full 3 on HIGH, single on LOW/MEDIUM. Reads `.stackpilot/ARCHITECTURE.md § Key Design Decisions`, cites prior decisions verbatim. Prescriptive Process 1-5 steps replaced by general "what to ground in" instructions per Anthropic's Claude 4.x guidance ("prefer general instructions over prescriptive steps"). Emits `## Decision Candidates` on HIGH; returns `[ESCALATION]` for new deps or structural conflicts |
| **sp-dev** | Implements the task | Six explicit "Don't add X" boundaries at the top (primacy position, mirroring Anthropic's "Avoid over-engineering" template): no error handling for impossible cases, no defensive validation on trusted inputs, no comments explaining well-named code, no single-use helpers, no unrelated refactors, no unrequested tests. Reads `git log` to avoid repeating failed approaches. TDD (RED-GREEN-REFACTOR). Verify/fix loop with stuck detection; reverts on failure; `[SOFT-BLOCKED]` after 2 failed rounds |
| **sp-qa** | Reviews code, writes tests | Opens with adversarial KPI ("your job is finding reasons this PR should not ship"). Every finding requires `file:line` + concrete failure scenario + ≥80% confidence. Mandatory "Adversarial Angles Tried" completion field so "no findings" is earned, not assumed. Prescriptive Stages 1-3 replaced by open adversarial angles; deterministic Consistency Audit (absolute-claim / scope-completeness / dead-reference, HIGH-risk mandatory) preserved verbatim — stackpilot's unique value. Reads `.stackpilot/ARCHITECTURE.md` for Review Patterns; emits `## Pattern Candidates`. **Dispatches on standard complexity** — light tasks rely on sp-dev's TDD. |
| **sp-docs** | Updates README, comments, API docs | Uses the haiku model tier for mechanical documentation work; runs after QA passes; documentation only. |

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

---

## Event Flow

### User-triggered (via the StackPilot entry)

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

**Standard Feature — 5 nodes (terminal-first, browser when useful):**

```
Node 1 — Exploration: scout code first (grep + read 2-5 files) → one-question design interrogation with recommended answers → canonical refs and optional domain language captured in spec
Node 2 — Design: one recommended terminal approach + rejected alternatives; design-options.html with 2-3 selectable options only for visual layout, interaction, or nontrivial diagrams
Node 3 — Spec & Criteria: write spec (including Domain Language only when terms crystallize) → auto-verify (grep checks) → 12-QA matrix → derive acceptance criteria → terminal review, or spec-review.html when editable visual review helps
Node 4 — Plan & Run Sprint: write plan → auto-verify → traceability trace → branch + commit → initialize handoff.json/state.json/events.jsonl → optional dashboard.html for multi-wave/dense live progress → dispatch tasks in parallel waves → update handoff after each boundary
Node 5 — Finish: pre-merge gate (typecheck/lint/tests) → sprint-evals.md + feedback inbox gate → closure gate (criteria all green / CHANGELOG / patterns surfaced / critical feedback handled) → terminal A/B/C/D, or finish-report.html for dense timelines/reports
  ↳ pre-merge-commit hook rejects non-squash merges on main as a hard guard
```

Inline verifications (grep, 12-QA matrix, traceability check) are sub-steps
inside their node, not separate phases. Browser view artifacts are optional at
Nodes 2, 3, 4, 5; data-layer source-of-truth files (spec, plan, criteria,
handoff.json / state.json / events.jsonl / sprint-evals.md / feedback inbox)
remain markdown/JSON for sub-agent consumption.

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
- Persistence via plan files (git-tracked), per-task `state.json`, and sprint-level `events.jsonl`

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

## Entry Layers

StackPilot intentionally exposes one normal user entry. The other skill files
exist so hosts with Agent Skills can route to strict gates mechanically; they
are implementation surfaces, not a user-facing command taxonomy.

| Layer | Entry | Purpose |
|-------|-------|---------|
| User-facing | `/stackpilot` | **Claude Code primary entry** — tidy + resume + status + auto/interactive mode + sprint execution. Natural-language feature requests are routed here through bootstrap when possible. |
| Default internal gate | `stackpilot-methodology` | Host-neutral StackPilot flow: explore → design → spec/criteria → plan → execute → review → finish. |
| Default internal gate | `stackpilot-planning` | Implementation planning from approved spec/design to exact executable tasks. |
| Default internal gate | `stackpilot-workspace` | Workspace isolation, setup, and clean baseline verification before implementation. |
| Default internal gate | `stackpilot-plan-execution` | Task-by-task plan execution with TDD, spec review, quality review, and controller evidence gates. |
| Default internal gate | `stackpilot-parallel-agents` | Parallel dispatch for independent tasks, failures, review domains, or research targets. |
| Default internal gate | `stackpilot-review-response` | Code-review feedback handling with technical verification and scoped fixes. |
| Default internal gate | `stackpilot-completion-verification` | Fresh evidence gate before completion, merge, PR, or success claims. |
| Default internal gate | `tdd-development` | TDD + verify/fix + rationalization blockers. |
| Default internal gate | `qa-12-dimensions` | 12-dimension test coverage + code review. |
| Default internal gate | `architecture-review` | Codebase pattern analysis + blueprint. |
| Default internal gate | `systematic-debugging` | 4-phase root cause investigation + red flags. |
| Bootstrap only | `stackpilot-bootstrap` | SessionStart routing discipline; not a user-facing command. |
| Expert on-demand | `/stackpilot-research` | Deep research reports using cross-longitudinal analysis (横纵分析法). |
| Maintainer-only | `/stackpilot-sync` | External skill tracking and sync. |
| Maintainer-only | `stackpilot-skill-authoring` | StackPilot skill creation/update workflow with routing, docs, and tests. |

---

## Agent Skills Compliance

Stackpilot follows the [Agent Skills open standard](https://agentskills.io) maintained by Anthropic.

**Methodology gates** — portable internals used by the StackPilot route in any
Agent Skills-compatible product (Cursor, VS Code Copilot, Gemini CLI, OpenAI
Codex, JetBrains Junie, and 25+ more):

| Gate | What it does | Exposure |
|------|-------------|----------|
| `stackpilot-methodology` | Host-neutral sprint method and gates | Default internal |
| `stackpilot-planning` | Spec/design to executable implementation plan | Default internal |
| `stackpilot-workspace` | Workspace isolation, setup, and baseline verification | Default internal |
| `stackpilot-plan-execution` | Existing-plan execution with review and evidence gates | Default internal |
| `stackpilot-parallel-agents` | Independent parallel dispatch with controller integration | Default internal |
| `stackpilot-review-response` | Review feedback verification and response workflow | Default internal |
| `stackpilot-completion-verification` | Evidence-before-claims finish gate | Default internal |
| `stackpilot-skill-authoring` | Skill creation/update quality gate | Maintainer-only |
| `tdd-development` | TDD cycle + verify/fix loop + rationalization blockers | Default internal |
| `qa-12-dimensions` | Two-stage code review + 12-dimension test coverage | Default internal |
| `architecture-review` | Pattern analysis + decisive architecture choice + blueprint | Default internal |
| `systematic-debugging` | 4-phase root cause investigation + red flag detection | Default internal |

**Host Adapters** — implement the same Methodology Core with host-native tools:

| Skill | What it does |
|-------|-------------|
| `stackpilot` | Claude Code adapter: full sprint lifecycle using Agent, TaskCreate, worktree isolation, preview server, state, and event logs. |

**Packaged host surfaces**:

| Host | Package surface | Status |
|------|-----------------|--------|
| Claude Code | `.claude-plugin/` + `hooks/hooks.json` | Full autonomous sprint adapter + SessionStart auto-route |
| Cursor | `.cursor-plugin/` + `hooks/hooks-cursor.json` | StackPilot routing bootstrap + portable internal gates |
| OpenAI Codex | `.codex-plugin/plugin.json` | StackPilot package metadata + portable internal gates; full sprint adapter not yet implemented |
| Gemini CLI | `gemini-extension.json` + `GEMINI.md` | StackPilot routing context, tool mapping, and portable internal gates |

**Progressive disclosure** — SKILL.md stays under 500 lines. Heavy content such as Run Sprint, Sprint Finish, the 12-QA matrix, and browser view templates lives in `references/` and loads on demand.

**Superpowers gap audit** — `docs/superpowers-gap-audit.md` maps each
Superpowers workflow to the StackPilot gate or adapter that covers the same
product behavior. It is not a target for matching Superpowers' skill count or
public command shape.

---

## Key Design Decisions

**One StackPilot entry.** The normal product experience is "use StackPilot" and
let bootstrap, hooks, and the host adapter route into default gates. The smaller
portable skills remain real files for Agent Skills compatibility, triggering,
and tests, but they are not the public product shape.

**Methodology Core first.** StackPilot is a general methodology, not a
single-host script. The core defines gates and artifacts; adapters choose the
mechanics.

**Host Adapter Contract.** An adapter must preserve the core gates: design before
implementation, mechanical criteria, plan traceability, TDD or stated exemption,
spec-compliance review before quality review, independent verification before
phase advancement, completion verification, and safety gates for destructive or
external side effects.

**Claude Code adapter (v2).** Agents are dispatched via Claude Code's Agent tool with `isolation: "worktree"`. No custom bash dispatcher, no git worktree management, no file locking. Claude Code handles all infrastructure.

**Session bootstrap auto-route (v2.3).** Claude plugin installs
`hooks/session-start`, which injects `stackpilot-bootstrap` into each new
conversation. This replaces the old explicit-only posture: users may still type
`/stackpilot`, but natural feature work is routed there automatically before
file reads or implementation. User and project instructions remain highest
priority, so explicit "skip planning", "just answer", or "I'll verify myself"
requests override the route.

**PreToolUse routing gate.** Prompt-only routing is not sufficient for all
models. The Claude/Cursor package installs `hooks/pre-tool-use`, which blocks
implementation or inspection tools for natural feature/bug/code work until a
StackPilot process skill has been activated. The hook fails open if it cannot
inspect the transcript, and it respects explicit user opt-outs.

**Prompt-based inter-agent communication.** Agent outputs flow directly as prompt context to downstream agents. No intermediate files (arch-review/, done/). The main session is the coordinator.

**Controller contract gates.** Agent outputs flow as prompt context, but the
main controller must not trust success reports. Before advancing task phase, it
checks required Completion Output sections, independently inspects the git diff,
re-runs or verifies the reported command evidence, and confirms criteria Status
updates in the data layer.

**Plan + handoff + state + event log as persistence layer.** Tasks are tracked in-session via TaskCreate. Plan files define intended work; `handoff.json` records the controller phase and next action; per-task `state.json` records phase completion; sprint-level `events.jsonl` records dispatch, verification, safety, and user/action decisions. Resume reads handoff first, then state, then falls back to git history only for legacy sprints.

**Data-layer handoff as resume contract.** `.stackpilot/runs/<sprint>/handoff.json` records the controller phase, status, inputs/outputs, decisions, and next action. It is intentionally compact: use it to resume the phase boundary, then read `state.json` and `events.jsonl` for detailed evidence.

**Sprint evals from events/state/criteria.** Sprint Finish writes `.stackpilot/runs/<sprint>/sprint-evals.md` from `events.jsonl`, per-task `state.json`, and acceptance criteria. It summarizes task totals, retry and verify/fix rounds, common failing gates, plateau/stuck signals, and a stop/continue/change-strategy recommendation. This revives the useful eval loop without restoring the deleted `/stackpilot-bench` runner.

**Feedback inbox audit loop.** `.stackpilot/feedback/open/*.md` holds human or external audit feedback until Sprint Finish processes it. HIGH/CRITICAL unresolved feedback is surfaced before merge decisions; handled items move to `.stackpilot/feedback/resolved/` only after a `# Resolution` section records evidence and disposition.

**Zero external dependencies.** All agent protocols are inlined. The skill works without any external plugin installed.

**Complexity routing at the task level.** Each task carries `complexity: light | standard`. Light tasks skip architect, cutting ~60% of agent overhead for simple changes.

**Soft-blocked retry.** Agents self-report failure via `[SOFT-BLOCKED]` output. The main session retries up to 3 times before requiring human input.

**Git as memory.** sp-dev reads `git log --oneline -20` before every task. Prior failed approaches are visible in commit history.

**Agents dispatch via explicit subagent_type.** SKILL.md's `Agent()` calls pass `subagent_type="sp-architect"` / `"sp-dev"` / `"sp-qa"` / `"sp-docs"` so Claude Code routes to the registered agent (with its frontmatter-declared model and tool restrictions) rather than falling back to `general-purpose`. Required path: agents must be registered at `~/.claude/agents/` or within an installed plugin. Claude Code caches the registry at session start — after install, restart Claude Code to activate. sp-docs is routed by task.type: `type: docs` tasks go to sp-docs (haiku tier), all others to sp-dev (sonnet tier).

**Don't re-teach frontier coding models what they already handle.** Agent methodology files specify the stackpilot orchestration contract — input format, completion output format, escalation signals, safety gates, event logging, and cross-sprint memory hooks. They do NOT include generic engineering advice (how to TDD, how to review, how to debug). This principle drove a ~47% trim of sp-dev and sp-qa methodologies on 2026-04-17 and remains the prompt-shaping rule for newer Claude Code and OpenAI Codex model families.

**Agent-prompt engineering principles (adopted 2026-04-20).** After a cross-sourced review of Anthropic docs (Claude 4.x prompting guide, effective context engineering, Claude Code best practices), academic literature (Lost in the Middle, Curse of Instructions, Sprague 2024 "To CoT or not to CoT"), and the 2026-04-20 survey in `research/260420-1130-prompt-length-claims/`, sp-* agent prompts follow these rules:

1. **Non-negotiable boundaries at the TOP of every prompt.** First-position tokens have the highest attention weight (primacy + attention-sink), so hard red lines go there — not buried in the middle. U-shape design: repeat critical reminders at the bottom.
2. **≤5 hard rules per agent.** Research on instruction count (Curse of Instructions, IFScale) shows following-rate decays toward ~80% once you exceed ~5 instructions. Anything beyond that belongs as guidance, not as an invariant.
3. **Prefer general instructions over prescriptive steps** (official Anthropic Claude 4.x guidance). Explicit "step 1, step 2, step 3" lists now often *reduce* quality on strong models with adaptive thinking; they're kept only where the structure is part of the output contract (e.g., sp-dev's Completion Output schema).
4. **Explicit negative boundaries for over-engineering.** sp-dev carries six `Don't add X` lines matching Anthropic's "Avoid over-engineering" guidance. Recent Opus-family coding models are strong but can still be over-eager; concrete negative boundaries remain a high-leverage guardrail for code agents.
5. **No positive-example filler.** "You are a senior engineer who takes pride in…" filler drops the signal-to-token ratio without measurable benefit on Claude 4.x.

**Self-verification at Sprint Finish.** When Step 2 starts the dev server, the main agent auto-curls the preview URL and reports HTTP status before handing control to the user. Non-2xx/3xx or connection failure is surfaced with the last 20 lines of server log — catches the "server binds but app 500s" class of regression without any per-task overhead.

**Action Safety Gate survives auto mode.** Auto mode may skip routine user gates, but it never bypasses destructive or external side-effect boundaries. Force pushes, remote deletes, production database changes, credential movement, public uploads of repository data, deployments, destructive MCP/app actions, and disabled verification gates require explicit user confirmation and are logged in `events.jsonl`.

**Rendered UI verification for frontend work.** Frontend criteria must include at least one rendered-page check when the task changes user-visible UI: browser/devtools smoke, screenshot or DOM assertion, responsive overflow check, or project-native Playwright/Cypress route test. A Node 5 curl proves only that the server responds; it does not prove the visual state.

**OpenAI Codex boundary.** The Methodology Core remains compatible with OpenAI
Codex's Agent Skills discovery model. A Codex adapter should implement the Host
Adapter Contract with Codex-native skills, subagents, workspaces, browser/app
verification, and PR mechanics instead of copying Claude Code-specific Agent
calls.

**Single-file project memory.** `.stackpilot/ARCHITECTURE.md` is the sole per-project memory surface. Fixed sections: What This Project Is / Stack / Key Directories / Data Flow / Key Design Decisions / Conventions & Gotchas / Review Patterns. Only the main agent writes it, and only at Sprint Finish (Step 4a). Sub-agents are read-only: `sp-architect` reads `§ Key Design Decisions` and surfaces new HIGH-risk decisions via a `## Decision Candidates` block in its report; `sp-qa` reads `§ Review Patterns` & `§ Conventions & Gotchas` and surfaces new patterns via a `## Pattern Candidates` block. Specs may carry temporary `## Domain Language` entries from design interrogation; durable terms merge into `ARCHITECTURE.md` at Step 4a instead of creating `CONTEXT.md` or ADR files. The main agent merges these candidates at Sprint Finish. This keeps writes serial on the feature branch and avoids worktree-level write contention.

**TDD enforcement.** sp-dev enforces RED-GREEN-REFACTOR. Tests written before implementation.

**Root cause investigation.** 4-phase investigation (observe → reproduce → trace → hypothesize) before any fix.

---

## Evolution Notes

| Date | Change |
|------|--------|
| 2026-07-02 | **v3.0.0: Repository cleanup and product-surface trim.** Removed unused `/stackpilot-compete`, its empty `.stackpilot/compete-insights.tsv` seed, the project-local `.claude/skills/release` skill, stale skill-tighten plan/spec artifacts, legacy `.stackpilot/sprint-metrics.md`, and deprecated `visual-companion` / `optimize-sprint` references. Added structural regression checks so these unused surfaces do not regrow. |
| 2026-06-26 | **v2.4.1**: Browser design options for interface prompts. Node 2 now force-treats explicit page/screen/UI/UX/frontend layout, visual design, interaction, information architecture, dashboard, and multi-version interface design requests as browser-view eligible, so StackPilot generates `design-options.html`, starts or reuses the sprint server, and prints the local URL unless the user explicitly asks for terminal/text-only output. |
| 2026-06-16 | **External-method refresh: handoff, evals, feedback inbox.** Rechecked autoresearch and LLM Wiki style repositories, then adapted only the durable data-layer pieces: `handoff.json` for phase resume, `sprint-evals.md` for plateau/retry/gate retrospectives, and `.stackpilot/feedback/open|resolved` for external audit feedback. Deliberately did not restore `/stackpilot-bench` or add a runtime runner. |
| 2026-06-10 | **Single StackPilot entry model.** Reframed the portable `stackpilot-*` skills as default internal gates and adapter primitives rather than a user-facing skill catalog. Users should start from `/stackpilot` or natural-language StackPilot routing; bootstrap/hooks/host adapters decide when to trigger planning, workspace, execution, parallel, review-response, completion, TDD, QA, architecture, and debugging gates. Superpowers comparison remains a workflow coverage audit, not a skill-count parity target. |
| 2026-06-10 | **Methodology Core + Host Adapters repositioning.** Added portable `stackpilot-methodology` as the host-neutral core and reframed `/stackpilot` as the Claude Code adapter. StackPilot's product boundary is now the method and gates, not a single host implementation. Future Codex/Gemini/Cursor adapters must implement the Host Adapter Contract rather than forking the workflow. |
| 2026-06-07 | **v2.2.0**: Official-frontier refresh. Removed stale Claude/Opus point-release anchors from live prompts, aligned SKILL.md and run-sprint architecture review triggers (`standard` tasks, not HIGH risk), replaced the zsh-unsafe `.claude/plans/*.md` glob with `find`, added Action Safety Gate text to SKILL / Run Sprint / Finish, added sprint-level `events.jsonl` for durable dispatch / verification / decision evidence, required rendered UI verification for frontend tasks, and clarified that portable skills work in OpenAI Codex while the full autonomous sprint adapter remains Claude Code-specific. |
| 2026-05-25 | **v2.1.0**: Skill Tighten — sister-file sync via sub-agent contract. Node 1 加 Scope Lock（多文件 refactor 前列 will-touch / will-NOT-touch）；Node 3 § 3.1 默认最小有效版本引导；Node 4 plan task schema 加可选 `sister_files` / `shared_field_grep`，§ 4.2 加对应 grep verify；Node 5 pre-merge 显式三件套（typecheck/lint/test）+ 残留脚本扫描（`scripts/(migrate\|audit\|debug\|oneshot)-*` 命中提示是否合并前删除）。Sub-agent 接力：sp-architect Implementation Blueprint 加 `Will NOT touch`；sp-dev Required behaviors 加 Sister-file ack + Completion Output 加 `## Sister-File Sync` 段；sp-qa Consistency Audit 加第 4 条 sister-file sync audit + Adversarial Angles 加 `sister-file sync`。Why: insights 报告（2026-05-25 / 283 sessions / 4520 messages）跨项目 5 大稳定 friction 中 wrong_approach（34 次）和 sister-file 漏改占主要比重，需要从 SKILL.md 一次性检查升级为 plan→dev→qa 接力 enforce。 |
| 2026-05-22 | **qa-12-dimensions hardening (skill v1.0.1 → v1.1.0; shipped as part of v2.0.0).** After 43 days untouched the portable skill had drifted behind both upstream (Anthropic feature-dev v2 code-reviewer) and the stackpilot internal sp-qa. Three targeted backports: (1) 5-tier confidence rubric (0/25/50/75/100) replaces the single ">=80%" line, matching feature-dev v2; (2) Stage 1 renamed "Spec & Project Guidelines Compliance" and reads `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` / `.cursorrules` as a first-class review angle; (3) "Adversarial Angles Tried" required field sourced from sp-qa — "no findings" only credible when angle list is non-trivial. Sub-agent-only sp-qa features (output schema, Consistency Audit grep triplet, WTF ratio, hard caps) deliberately NOT backported. |
| 2026-05-20 | **Removed `/stackpilot-bench` skill and `codex-config/` Codex support.** Bench harness (3 workloads, history.csv, scoring/verdict scripts, run-codex-bench.sh, references/headless-mode.md) deleted; `codex-config/agents/` Codex-native sp-* prompts deleted; `claude-config/skills/stackpilot/references/codex-dispatch.md` deleted; `docs/bench-implementation.md` deleted; `qa.disable_criteria_gate` and `qa.disable_state_json` config flags (which only existed for the `stackpilot-serial` bench leg) removed from SKILL.md + run-sprint.md. Reason: bench v2 schema/runner/workload were inconsistent and unrunnable, and Codex orchestration was no longer maintained. |
| 2026-05-18 | **v1.11.0**: Run Sprint executes tasks in parallel waves (qa.max_parallel default 3) via dependency topological sort over `depends_on`; per-task `state.json` under `.stackpilot/runs/<sprint>/TASK-NNN/` replaces in-memory-only TaskCreate state and enables Sprint Interrupted recovery without git-log heuristic; Phase 3.6 derives mechanically verifiable `acceptance-criteria.md`, sp-qa updates Status during Run Sprint, sprint-finish Step 0.5 enforces 3 gates (criteria all green / CHANGELOG covers sprint scopes / Pattern Candidates surfaced) blocking merge; Light Feature path adds mandatory mini-brainstorm + Standard adds Phase 3.7 User Reviews Spec Gate (superpowers:brainstorming 5.1.0 re-sync, docs/sync.md updated); SKILL.md Run Sprint section downsized ~100→28 lines (detail in `references/run-sprint.md`). |
| 2026-05-07 | **Step 4.5 simplify between dev and QA.** Standard tasks now invoke the `simplify` skill on the task diff after sp-dev finishes and before sp-qa starts. Scoped to the task's `relevant_files`, must preserve test pass status, commits separately so QA sees both diffs. Catches over-engineering (premature abstractions, dead error handling, single-use helpers) while sp-dev's tests are still green — cheaper than sp-qa fix loops on style issues. Skipped for light tasks and `type: docs` (low ROI on small/mechanical diffs). |
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
