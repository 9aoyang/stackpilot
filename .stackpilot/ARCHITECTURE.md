# Stackpilot — Sprint Architecture Summary

> This is the quick-reference for sprint routing. Full architecture: `docs/architecture.md`

## What This Project Is

StackPilot is a general methodology for coding agents with one normal user
entry. The portable `stackpilot-methodology` core defines the flow; smaller
portable skills are internal gates; host adapters such as the Claude Code
`/stackpilot` skill execute the method with native tools.

## Stack

- **Runtime**: StackPilot entry routes through host-neutral Agent Skills gates; Claude Code adapter uses Agent tool, TaskCreate, worktrees, preview server, state, and events
- **Language**: Markdown-driven skills + Bash scripts
- **Distribution**: Claude Code installer/symlinks plus host plugin manifests for Claude, Cursor, Codex, and Gemini StackPilot entry/routing surfaces

## Key Directories

| Path | Purpose |
|------|---------|
| `claude-config/agents/sp-*.md` | Agent methodology prompts (architect/dev/qa/docs) |
| `claude-config/skills/stackpilot-methodology/SKILL.md` | Internal portable StackPilot Methodology Core |
| `claude-config/skills/stackpilot-planning/SKILL.md` | Internal spec/design to executable task plan gate |
| `claude-config/skills/stackpilot-workspace/SKILL.md` | Internal workspace isolation/setup/baseline gate |
| `claude-config/skills/stackpilot-plan-execution/SKILL.md` | Internal task-by-task plan execution gate |
| `claude-config/skills/stackpilot-parallel-agents/SKILL.md` | Internal independent parallel dispatch gate |
| `claude-config/skills/stackpilot-review-response/SKILL.md` | Internal review feedback verification/response gate |
| `claude-config/skills/stackpilot-completion-verification/SKILL.md` | Internal evidence-before-claims finish gate |
| `claude-config/skills/stackpilot-skill-authoring/SKILL.md` | Maintainer-only StackPilot skill creation/update gate |
| `claude-config/skills/stackpilot/SKILL.md` | Main `/stackpilot` entry point |
| `claude-config/skills/stackpilot/references/` | Sub-protocols (run-sprint, sprint-finish, 12-qa-matrix) + `views/` HTML templates (v2.0) |
| `scripts/preview/{server.cjs,helper.js}` | Sprint server: HTML view host + WebSocket state stream (v2.0) |
| `.stackpilot/views/<sprint>/` | Generated HTML view layer (gitignored — never source of truth) |
| `docs/architecture.md` | Full architecture reference |
| `docs/sync.md` | External skill dependency tracking |
| `.stackpilot/` | Per-project: specs, plans, run state, event logs |
| `scripts/` | init.sh, hooks, preview server |
| `templates/` | stackpilot.config.yml |
| `.claude-plugin/` | Claude Code full adapter package metadata |
| `.cursor-plugin/` | Cursor StackPilot routing + portable gate package metadata |
| `.codex-plugin/` | Codex StackPilot package metadata |
| `gemini-extension.json`, `GEMINI.md` | Gemini StackPilot routing context |
| `hooks/pre-tool-use` | Mechanical routing gate before feature/bug/code tool use |

## Agent Pipeline

```
sp-architect (standard complexity only) → sp-dev (TDD, worktree) → sp-qa (12-dim + Stage 4 consistency audit) → [opt-in Deep Review] → sp-docs
```

## Key Design Decisions

- **Dual-track architecture (v2.0.0, 2026-05-22)**: every artifact lives in exactly one of two layers. Data layer (markdown / YAML / JSON) feeds sub-agents and git diff; view layer (self-contained HTML, CDN libs) feeds human decision-makers at specific nodes. View HTML is regenerated from data, never source of truth; user actions on HTML (button clicks, criteria edits) `POST /api/action/<slug>/<name>` → server writes `*-action.json` → main agent reads back into data layer. **Why**: text-wall outputs at decision points (design options, sprint progress, finish report) lose spatial information (diff visualization, dependency DAG, criteria status) that humans need; markdown spec/plan stay LLM-consumable for sub-agents. Inspired by [The unreasonable effectiveness of HTML](https://thariqs.github.io/html-effectiveness/). **How to apply**: when adding a new decision point, ask "does the user need to compare / visualize / track over time?" → if yes, generate an HTML view from existing data files. Never make HTML the SoT. New HTML must include CSP meta restricting script-src to `self + jsdelivr` (the only CDN). Sub-agent contracts (sp-*) unchanged — they only see markdown.

- **5-node skill pipeline (v2.0.0, supersedes 10+ Phase X.Y numbering)**: SKILL.md is now organized as 5 named nodes (Exploration / Design / Spec & Criteria / Plan & Run Sprint / Finish). Inline grep verifications + 12-QA matrix + traceability checks are sub-steps inside their node, not separate numbered phases. **Why**: Phase 3.5/3.6/3.7 numbering was noise — humans don't remember which is which, and the gates are still enforced inline. Fewer top-level steps = clearer mental model. **How to apply**: when adding new gates or verifications, embed them inside the relevant node as a sub-step (e.g. "3.3 12-QA matrix"); don't introduce new Node numbers. Breaking change: external tooling referencing "Phase X.Y" by name must be updated. Migration: Phase 0.5/1 → Node 1; Phase 1.5/2 → Node 2; Phase 3/3.5/3.6/3.7 → Node 3; Phase 4/4.5 + Run Sprint → Node 4; Sprint Finish → Node 5.

- **Sprint server extends preview server, single binary, slug-scoped lifecycle (v2.0.0)**: `scripts/preview/server.cjs` (354 lines pre-v2) extended additively with `/sprints/<slug>/<artifact>.html`, `POST /api/action/<slug>/<name>` (64KB cap → 413), `GET /api/state/<slug>` (aggregates `runs/<slug>/TASK-*/state.json` + `<slug>-criteria.md`), fs.watch on runs + criteria broadcasts `state-update` WS events. `start-server.sh --sprint-slug` writes `.stackpilot/views/<slug>/.server-info.json` marker so `stop-server.sh --slug` can resolve which server to kill. Brainstorm root `/` path preserved for back-compat one release. **Why**: visual-companion was a separate server that started/stopped per design question; consolidating to one long-lived sprint server avoids start/stop churn and enables live dashboard. **How to apply**: never spawn ad-hoc servers from new view nodes — generate HTML into `views/<slug>/` and rely on the existing sprint server. Existing helper.js `data-choice` WS protocol unchanged; new templates use `window.sp.{action,state}` fetch API instead.

- **Fork-pattern caching**: agents share parent context → ~66% token savings
- **Worktree isolation**: each dev task runs in its own git worktree
- **Claude adapter infrastructure boundary**: the full sprint adapter uses Claude Code native tools; portable hosts must implement the Host Adapter Contract with their own native tools instead of copying Claude-specific `Agent` calls.
- **Deep review (2-layer, local)**: Layer 1 — sp-qa Stage 4 Consistency Audit (grep-based, HIGH-risk mandatory, <1s). Layer 2 — main agent spawns a fresh-context reviewer after sp-qa on HIGH-risk tasks (default on, `qa.deep_review: false` disables; ~30-60s, no remote)
- **Don't re-teach frontier coding models what they already handle**: agent methodology files specify stackpilot's orchestration contract (input format, completion output format, escalation signals, safety gates, event logging, cross-sprint memory hooks) — NOT generic engineering advice (how to do TDD, how to review code, how to debug). sp-dev and sp-qa were trimmed ~47% on 2026-04-17 to enforce this separation.
- **Light tasks skip sp-qa dispatch**: for `complexity: light`, sp-dev's TDD verify/fix is sufficient. Main agent still runs Stage 4 consistency audit inline (cheap deterministic greps). sp-qa dispatch only fires on standard complexity.
- **sp-docs uses haiku tier**: docs updates are mechanical; haiku-tier routing keeps them cheaper than sonnet-tier implementation work.
- **Auto-verify 1 round, not 2**: current frontier coding models usually self-catch first-pass document issues. A second blind round is rarely worth the cost; escalate specific failures instead.
- **Plan review = traceability check, not 12-QA re-run**: spec 12-QA already scored all 12 dimensions. Plan review only verifies spec→task forward trace and task→spec reverse trace. No re-derivation.
- **Registered agents >> inline methodology**: 2026-04-17 micro-benchmark on identical read-only QA task: sp-qa dispatch = 10.7k tokens / 13.6s; general-purpose with inlined sp-qa methodology = 21.5k tokens / 31.1s. 2x cheaper and 2.3x faster. Root cause: registered agent methodology caches as Claude Code system prompt; inline counts as input tokens every dispatch. This is WHY sp-* registration correctness matters — without it, every optimization (haiku for docs, opus for arch, tool restrictions) is dead code.
- **Single StackPilot entry, internal gates**: StackPilot's product shape is one user entry, not a public catalog of process skills. `/stackpilot` is the primary Claude Code entry; natural-language requests route into StackPilot through bootstrap; `stackpilot-methodology`, `stackpilot-planning`, `stackpilot-workspace`, `stackpilot-plan-execution`, `stackpilot-parallel-agents`, `stackpilot-review-response`, `stackpilot-completion-verification`, and `stackpilot-skill-authoring` are internal/default/maintainer gates. **Why**: the user works across many models and wants Superpowers-like strictness without memorizing a skill taxonomy or making StackPilot look like a Superpowers clone. **How to apply**: docs should present StackPilot first, then explain gates as automatic/on-demand internals; new host packages should expose one StackPilot route and use discrete skills only for host compatibility. (2026-06-10)

- **Methodology Core + Host Adapters**: StackPilot is not a Claude Code-only sprint tool. `stackpilot-methodology` is the portable core behind the StackPilot route; `/stackpilot` is the Claude Code adapter. **Why**: user works across many models/hosts, so the product must define durable gates independent of Claude Code while preserving the existing full adapter. **How to apply**: new host support implements the Host Adapter Contract (design before code, mechanical criteria, traceable plan, TDD/exception, spec-compliance review before quality review, independent verification, finish/safety gates) instead of forking a new workflow. (2026-06-10)

- **Cross-host package surfaces**: StackPilot ships package metadata for Claude Code (`.claude-plugin/`), Cursor (`.cursor-plugin/`), Codex (`.codex-plugin/`), and Gemini (`gemini-extension.json` + `GEMINI.md`). **Why**: a methodology users can apply across many models needs actual discovery/activation surfaces, not just prose claims. **How to apply**: keep portable gates host-neutral; keep `/stackpilot` clearly labeled as the Claude Code adapter; when adding a new host, add the smallest StackPilot routing/tool-mapping layer first, then a full adapter only if the host can enforce the Host Adapter Contract. (2026-06-10)

- **Superpowers workflow coverage without skill-count cloning**: StackPilot maintains coverage for the workflow classes Superpowers exposes (planning, workspace, plan execution, parallel dispatch, review response, completion verification, skill authoring), but those capabilities are internal/default/maintainer gates under the StackPilot entry. **Why**: the competitive gap is strict process enforcement, not matching Superpowers one public skill at a time. **How to apply**: use `docs/superpowers-gap-audit.md` to find workflow gaps; do not add a new public skill just because Superpowers has one. (2026-06-10)

- **Session bootstrap auto-route — Superpowers-like entry experience**: StackPilot installs a SessionStart hook that injects `stackpilot-bootstrap` at conversation start. Natural feature work, behavior changes, and multi-file requests route to the internal `stackpilot-methodology` gate before inspection or implementation; Claude Code can then hand execution to `/stackpilot` as the host adapter. **Why**: observed user experience showed explicit-only routing made the strict process easy to skip, while Superpowers gets reliability from session bootstrap + automatic skill triggering. **How to apply**: keep user/project instructions highest priority; explicit "skip planning", "just answer", or "I'll verify myself" requests override the route. Do not auto-strip internal gates based on inferred simplicity — adapter mini-mode/auto-mode rules decide the lighter path. (2026-06-10)

- **PreToolUse routing gate**: StackPilot backs up prompt-level bootstrap with `hooks/pre-tool-use`. For natural feature/bug/code work, the hook blocks implementation or inspection tools until a StackPilot process skill is activated. **Why**: real triggering tests showed some models read the bootstrap and still rationalized skipping it for "small" tasks; a methodology needs mechanical gates where the host offers them. **How to apply**: keep the hook conservative and fail-open when transcript inspection is unavailable; user explicit opt-outs still win; do not block subagents. (2026-06-10)
- **Read ARCHITECTURE.md before proposing changes that touch project conventions**: when designing a new feature/refactor, scan this file's Key Design Decisions and Conventions & Gotchas sections first. If you're about to assert a convention not listed here, ask the user "is this a hard rule?" before coding it. If it IS a hard rule, add it here as part of the change. **Why**: undocumented rules existing only in the user's head force re-discovery and waste iterations; encoding them here lets future design proposals surface tensions early. **How to apply**: before any non-trivial design proposal, grep this file for keywords related to your design space, and surface any tension to the user explicitly. (2026-04-17)

- **Plan / spec self-review grep verification can false-positive on documents that mention placeholder vocabulary** (2026-05-19, surfaced sprint Phase 4 verify): the `grep -inE "TBD|TODO|FIXME|\bplaceholder\b"` verify check in stackpilot SKILL.md Phase 3/4 false-positives when a self-review section contains literal words like "no placeholders" or "no TBDs". **Why**: grep cannot distinguish self-referential mentions from actual placeholders. **How to apply**: when authoring spec / plan self-review sections, use alternate phrasing ("All task descriptions are fully resolved") instead of "no placeholders / no TBDs". Don't add `# noqa`-style escape mechanisms — keep the verify cheap and dumb. Related files: `claude-config/skills/stackpilot/SKILL.md` Phase 3/4 verify blocks.

- **Run Sprint executes tasks in parallel waves, not strict serial order** (2026-05-18): Pre-Sprint phase computes dependency waves via topological sort over `depends_on`; tasks within a wave dispatch in parallel (`TaskCreate` + simultaneous `Agent(...)` calls), capped by `qa.max_parallel` (default 3). Each task already has worktree isolation so concurrent dev is safe. Wave completes when ALL its tasks finish (success or failure). **Why**: single-task serial Run Sprint was the largest wall-time bottleneck; Anthropic multi-agent benchmarks show ~+90% throughput at ~15x token cost, and stackpilot's main constraint is wall time not token. **How to apply**: when authoring plans, set realistic `depends_on` — over-declaring deps forces serial execution and erases the speedup. For projects that need strict serial (e.g., shared global state), set `qa.max_parallel: 1` in `stackpilot.config.yml`. Failed wave-task does NOT abort siblings. Detailed protocol in `claude-config/skills/stackpilot/references/run-sprint.md`.

- **Sprint termination is artifact-driven, not agent-self-assessed** (2026-05-18; v2.2 event-log refresh 2026-06-07): four artifacts gate completion. (a) `.stackpilot/specs/<feature>-criteria.md` — mechanically verifiable acceptance criteria derived in Node 3, updated by sp-qa during Run Sprint. (b) `.stackpilot/runs/<sprint-slug>/TASK-NNN/state.json` — per-task state, atomically written. (c) `.stackpilot/runs/<sprint-slug>/events.jsonl` — durable dispatch / verification / decision / safety event log. (d) `references/sprint-finish.md` Sprint Closure Gate — criteria green / CHANGELOG / Pattern Candidates. **Why**: prevents premature completion and lets long-running sprints resume from artifacts rather than conversation memory. **How to apply**: every acceptance criterion must be a `grep`/`test`/`curl`/browser/screenshot/benchmark command output — no "looks correct"; sp-qa MUST update criteria Status; Action Safety Gate decisions and verification outcomes must be logged.

- **Light Feature path runs mandatory mini-brainstorm; spec writes pause for user review** (2026-05-18): even ≤2-sentence Light tasks must run a 30-second design check (scout once + ≤1 clarifying question + 1 approach proposal + user confirm) before plan. Standard tasks add an explicit Phase 3.7 User Reviews Spec Gate after Phase 3.5 12-QA. **Why**: re-syncs the `superpowers:brainstorming` "Too Simple to Need a Design" anti-pattern that was diluted by the 2026-04-17 "Light skips Phase 1/2" decision; recovers the explicit spec-review gate the inlined brainstorming docs/sync.md lost. **How to apply**: skip mini-brainstorm only in auto mode B; skip Phase 3.7 spec review gate only in auto mode B. Sourced from superpowers:brainstorming 5.1.0 — see `docs/sync.md`.

- **Phase 1 anti-hallucination: scout-before-ask + canonical-refs** (2026-04-18): before any clarifying question, Phase 1 must grep + read 2-5 relevant files first; any doc path the user cites mid-conversation → Read immediately + record in spec's `## Canonical Refs`. Ported from GSD `discuss-phase` (gsd-build/get-shit-done) after evaluating 8 candidate mechanisms and rejecting 6. **Why**: two stable failure modes still matter on frontier coding models — (a) asking the user about things grep would reveal, (b) losing user-cited doc paths before sub-agents see them, so downstream design violates the binding constraint. **How to apply**: these are the ONLY two new Phase-1 rules. Do NOT add more "anti-hallucination" rules without a concrete failure surfacing in real sprints — rejected as redundant: gray-area specificity (covered by "Push for specificity"), user/builder role separation (covered by "Challenge status-quo"), recommended-option gates (covered by "Take a position"), scope-creep Deferred docs (covered by Phase 1 "flag and decompose"), single-pass cap (covered by auto-verify 1 round), empty-answer retry (model-handled). Also rejected: CONTEXT.md + DISCUSSION-LOG.md + CHECKPOINT.json + 4 persistent project docs (violates single-ARCHITECTURE.md rule) and ADVISOR_MODE / NON_TECHNICAL_OWNER auto-routing (violates explicit-invocation rule).

- **Skill Tighten — sister-file sync via sub-agent contract** (2026-05-25): Node 1 加 Scope Lock（多文件 refactor 前列 will-touch / will-NOT-touch）；Node 3 § 3.1 加"默认最小有效版本"引导；Node 4 plan task schema 加可选 `sister_files` / `shared_field_grep` 字段；Node 5 pre-merge gate 显式三件套（typecheck/lint/test）+ 残留脚本扫描。Sub-agent 接力：sp-architect Implementation Blueprint 加 `Will NOT touch`；sp-dev Required behaviors 加 Sister-file ack（启动前跑 shared_field_grep / 验证 sister_files），Completion Output 加 `## Sister-File Sync` 段；sp-qa Consistency Audit 加第 4 条 sister-file sync audit。**Why**: insights 报告（2026-05-25 / 283 sessions / 4520 messages）揭示跨项目 5 大稳定 friction 中 wrong_approach（34 次）和 sister-file 漏改（多次：OnboardingView 第二个表单、KP↔article 没同步、ConfigPanel vs product form 误改）占主要比重，需要从 SKILL.md 一次性检查升级为 plan→dev→qa 接力 enforce。**How to apply**: plan 写 task 时，触动 shared identifier / shared field 必须填两字段之一；sp-dev 启动前必须 ack 命中并填 Completion Output；sp-qa Stage 4 audit 命中不在范围内即 [CRITICAL]。本次符合 "Don't re-teach Claude" 原则——加的是 stackpilot orchestration 契约（字段 + 接力点），不是教 Claude 怎么 refactor。Related files: `claude-config/skills/stackpilot/SKILL.md`, `claude-config/agents/sp-{architect,dev,qa}.md`.

- **Official-frontier refresh (v2.2.0, 2026-06-07)**: live prompts avoid stale point-release model claims; SKILL.md and run-sprint agree that architecture review runs for standard tasks; Step 0 uses zsh-safe `find` for `.claude/plans`; Action Safety Gate cannot be bypassed by auto mode; sprint-level `events.jsonl` records task-dispatched / verification / decision / safety evidence; frontend tasks require rendered UI verification; OpenAI Codex compatibility is limited to portable methodology skills until a maintained Codex orchestration plugin ships.

## Conventions & Gotchas

<!-- project-specific conventions, decisions, gotchas; add entries as they surface -->

- **Squash merge only on main** — enforced by `scripts/hooks/pre-merge-commit` (installed by `init.sh` into each clone's `.git/hooks/`); feature branches fold into one commit on merge
- **Markdown + Bash only** — no runtime tests; verification is grep-based on references across `claude-config/`, `scripts/`, `docs/`
- **Single-file project memory** — `.stackpilot/ARCHITECTURE.md` is the sole per-project memory surface; `sp-qa` never writes it, only reads and surfaces Pattern Candidates in its report (2026-04-17)
- **stackpilot.config.yml `qa.test_command` may be `N/A`** for meta-projects (like this repo) — Step 0 pre-merge gate handles absent test commands by reporting `N/A`, not failing
- **`.githooks/pre-commit` rejects skill changes without co-doc changes**: during sprints, intermediate per-task commits that touch only `claude-config/skills/` or `claude-config/agents/` fail the hook. Workaround: accumulate all sprint changes locally and batch-commit skill files + CHANGELOG + docs in one commit at sprint end. Matches the squash-merge pattern anyway (2026-04-17).
- **sp-docs agents can "describe" files without actually writing them**: observed hallucination mode where the subagent reports "File created at: ..." in its summary but the file does not exist. Always verify file existence after any docs dispatch, especially for Write-only tasks (2026-04-17).
- **`restore.sh` auto-picks up new skills via wildcard loop**: adding a new directory under `claude-config/skills/` requires no changes to `restore.sh` — the existing `for skill_dir in "$CONFIG_DIR/skills/"*/` loop symlinks them automatically. Resist the temptation to add per-skill install logic.

- **acceptance-criteria `Verify Command` cells must escape grep patterns that match the file structure** (2026-05-22): C6 in the HTML-first rebuild used `grep "sprints/.*\.html"` but server.cjs contains JS regex literals with `sprints\/` (escaped slash), so the grep returned 0 — criterion looked failed but the route was actually present. Fix: when verifying file content with grep, prefer matching the route constant name (`SPRINT_HTML_RE`) or handler function name (`handleSprintHtml`) rather than the regex pattern itself — those are not subject to language-specific escaping. Same principle applies to anything where the verifier's regex shares syntax with the verified file.

- **Squash merge into main loses commit SHA equivalence; `git branch -d` fails on feature branches** (2026-05-22): `git merge --squash` creates a new commit on main with different SHA from the source branch tip, so `git branch -d <feature>` refuses ("not fully merged"). Use `git branch -D` to force-delete after confirming the squash commit contains the work. Don't switch to non-squash merges to avoid this — `pre-merge-commit` hook blocks non-squash on main/master anyway.

## Review Patterns

<!-- maintained via Sprint Finish; sp-qa surfaces candidates, main agent merges; max 20 entries -->

- [atomicity] multi-row file writes use `write-to-.tmp && mv` pattern so a mid-write crash leaves the original intact ×2 (TASK-001 HTML rebuild reused this for action JSON writes)
- [size-control] SKILL.md defers deep algorithm details to `references/<name>.md` rather than inlining; keeps main skill readable and under ~500 lines ×1
- [verification-fragility] grep-based acceptance criteria can fail-by-format when the verifier's regex shares syntax with the verified content (escaped slashes, regex literals, template tokens) — prefer constant/handler names over content patterns ×1 (TASK-016 HTML rebuild C6)

## External Skill Dependencies

See `docs/sync.md` for all tracked external skills.
