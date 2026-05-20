# Stackpilot — Sprint Architecture Summary

> This is the quick-reference for sprint routing. Full architecture: `docs/architecture.md`

## What This Project Is

Stackpilot is a sprint orchestration layer for Claude Code. `/stackpilot` skill drives the full dev loop: spec → plan → agent dispatch → QA → ship.

## Stack

- **Runtime**: Claude Code native (Agent tool, TaskCreate, worktrees — no custom infra)
- **Language**: Markdown-driven skills + Bash scripts
- **Distribution**: install.sh → symlinks into `~/.claude/`

## Key Directories

| Path | Purpose |
|------|---------|
| `claude-config/agents/sp-*.md` | Agent methodology prompts (architect/dev/qa/docs) |
| `claude-config/skills/stackpilot/SKILL.md` | Main `/stackpilot` entry point |
| `claude-config/skills/stackpilot/references/` | Sub-protocols (sprint-finish, optimize-sprint, visual-companion) |
| `docs/architecture.md` | Full architecture reference |
| `docs/sync.md` | External skill dependency tracking |
| `.stackpilot/` | Per-project: specs, plans |
| `scripts/` | init.sh, hooks, preview server |
| `templates/` | stackpilot.config.yml |

## Agent Pipeline

```
sp-architect (HIGH complexity only) → sp-dev (TDD, worktree) → sp-qa (12-dim + Stage 4 consistency audit) → [opt-in Deep Review] → sp-docs
```

## Key Design Decisions

- **Fork-pattern caching**: agents share parent context → ~66% token savings
- **Worktree isolation**: each dev task runs in its own git worktree
- **Zero custom infra**: everything uses Claude Code native tools
- **Deep review (2-layer, local)**: Layer 1 — sp-qa Stage 4 Consistency Audit (grep-based, HIGH-risk mandatory, <1s). Layer 2 — main agent spawns a fresh-context reviewer after sp-qa on HIGH-risk tasks (default on, `qa.deep_review: false` disables; ~30-60s, no remote)
- **Don't re-teach Claude what it already knows**: agent methodology files specify stackpilot's orchestration contract (input format, completion output format, escalation signals, cross-sprint memory hooks) — NOT generic engineering advice (how to do TDD, how to review code, how to debug). Claude 4.7 does those natively. sp-dev and sp-qa were trimmed ~47% on 2026-04-17 to enforce this separation.
- **Light tasks skip sp-qa dispatch**: for `complexity: light`, sp-dev's TDD verify/fix is sufficient. Main agent still runs Stage 4 consistency audit inline (cheap deterministic greps). sp-qa dispatch only fires on standard complexity.
- **sp-docs uses haiku**: docs updates are mechanical; haiku 4.5 handles them at ~3-5x lower cost than sonnet.
- **Auto-verify 1 round, not 2**: 4.7 self-catches first-pass issues ~95% of the time. Second round is rare hit with high cost; escalate on failure instead.
- **Plan review = traceability check, not 12-QA re-run**: spec 12-QA already scored all 12 dimensions. Plan review only verifies spec→task forward trace and task→spec reverse trace. No re-derivation.
- **Registered agents >> inline methodology**: 2026-04-17 micro-benchmark on identical read-only QA task: sp-qa dispatch = 10.7k tokens / 13.6s; general-purpose with inlined sp-qa methodology = 21.5k tokens / 31.1s. 2x cheaper and 2.3x faster. Root cause: registered agent methodology caches as Claude Code system prompt; inline counts as input tokens every dispatch. This is WHY sp-* registration correctness matters — without it, every optimization (haiku for docs, opus for arch, tool restrictions) is dead code.
- **/stackpilot is explicit-invocation only — never auto-route by inferred complexity**: the user opts in by typing `/stackpilot`. By that act, they have already decided this task warrants the heavy machinery. The skill must NOT add internal routing like "this looks light → skip sp-architect" — that breaks the user's mental contract (they invoked the heavy tool deliberately). Internal `complexity: light|standard` flags inside a plan ARE allowed (they're authored by the user/main-agent, not auto-inferred), but the `/stackpilot` entry point itself never branches on heuristic complexity guesses. **Why**: this is the explicit positioning that distinguishes stackpilot from superpowers (which auto-triggers on prompt keywords). **How to apply**: when proposing optimizations, never suggest "auto-detect simple tasks and skip phases". If a phase is wasteful for a class of tasks, the right fix is letting the user not invoke /stackpilot for that class — not auto-stripping the pipeline. (2026-04-17)
- **Read ARCHITECTURE.md before proposing changes that touch project conventions**: when designing a new feature/refactor, scan this file's Key Design Decisions and Conventions & Gotchas sections first. If you're about to assert a convention not listed here, ask the user "is this a hard rule?" before coding it. If it IS a hard rule, add it here as part of the change. **Why**: undocumented rules existing only in the user's head force re-discovery and waste iterations; encoding them here lets future design proposals surface tensions early. **How to apply**: before any non-trivial design proposal, grep this file for keywords related to your design space, and surface any tension to the user explicitly. (2026-04-17)

- **Plan / spec self-review grep verification can false-positive on documents that mention placeholder vocabulary** (2026-05-19, surfaced sprint Phase 4 verify): the `grep -inE "TBD|TODO|FIXME|\bplaceholder\b"` verify check in stackpilot SKILL.md Phase 3/4 false-positives when a self-review section contains literal words like "no placeholders" or "no TBDs". **Why**: grep cannot distinguish self-referential mentions from actual placeholders. **How to apply**: when authoring spec / plan self-review sections, use alternate phrasing ("All task descriptions are fully resolved") instead of "no placeholders / no TBDs". Don't add `# noqa`-style escape mechanisms — keep the verify cheap and dumb. Related files: `claude-config/skills/stackpilot/SKILL.md` Phase 3/4 verify blocks.

- **Run Sprint executes tasks in parallel waves, not strict serial order** (2026-05-18): Pre-Sprint phase computes dependency waves via topological sort over `depends_on`; tasks within a wave dispatch in parallel (`TaskCreate` + simultaneous `Agent(...)` calls), capped by `qa.max_parallel` (default 3). Each task already has worktree isolation so concurrent dev is safe. Wave completes when ALL its tasks finish (success or failure). **Why**: single-task serial Run Sprint was the largest wall-time bottleneck; Anthropic multi-agent benchmarks show ~+90% throughput at ~15x token cost, and stackpilot's main constraint is wall time not token. **How to apply**: when authoring plans, set realistic `depends_on` — over-declaring deps forces serial execution and erases the speedup. For projects that need strict serial (e.g., shared global state), set `qa.max_parallel: 1` in `stackpilot.config.yml`. Failed wave-task does NOT abort siblings. Detailed protocol in `claude-config/skills/stackpilot/references/run-sprint.md`.

- **Sprint termination is artifact-driven, not agent-self-assessed** (2026-05-18): three new artifacts gate completion. (a) `.stackpilot/specs/<feature>-criteria.md` — mechanically verifiable acceptance criteria derived in Phase 3.6, updated by sp-qa during Run Sprint (Status: untested/pass/fail/n-a-this-task). (b) `.stackpilot/runs/<sprint-slug>/TASK-NNN/state.json` — per-task state (phase, retry_count, last_result), atomically written (`.tmp` + `mv`), gitignored. (c) `references/sprint-finish.md` Step 0.5 Sprint Closure Gate — 3 mechanical checks (criteria all green / CHANGELOG covers sprint scopes / Pattern Candidates surfaced) blocking merge. **Why**: prevents the "premature completion" antipattern (Anthropic [effective-harnesses-for-long-running-agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)) where the agent self-declares done without an external check; also enables Sprint Interrupted recovery to read `state.json` instead of grep'ing git log heuristically. **How to apply**: every acceptance criterion must be a `grep`/`test`/`curl`/benchmark command output (same standard as spec 12-QA dim 1) — no "looks correct"; sp-qa MUST update criteria Status during its review; Step 0.5 gates always run unless auto mode B + no criteria file (legacy sprints pre-2026-05-18). Don't bypass Step 0.5 silently — explicit user override required and logged.

- **Light Feature path runs mandatory mini-brainstorm; spec writes pause for user review** (2026-05-18): even ≤2-sentence Light tasks must run a 30-second design check (scout once + ≤1 clarifying question + 1 approach proposal + user confirm) before plan. Standard tasks add an explicit Phase 3.7 User Reviews Spec Gate after Phase 3.5 12-QA. **Why**: re-syncs the `superpowers:brainstorming` "Too Simple to Need a Design" anti-pattern that was diluted by the 2026-04-17 "Light skips Phase 1/2" decision; recovers the explicit spec-review gate the inlined brainstorming docs/sync.md lost. **How to apply**: skip mini-brainstorm only in auto mode B; skip Phase 3.7 spec review gate only in auto mode B. Sourced from superpowers:brainstorming 5.1.0 — see `docs/sync.md`.

- **Phase 1 anti-hallucination: scout-before-ask + canonical-refs** (2026-04-18): before any clarifying question, Phase 1 must grep + read 2-5 relevant files first; any doc path the user cites mid-conversation → Read immediately + record in spec's `## Canonical Refs`. Ported from GSD `discuss-phase` (gsd-build/get-shit-done) after evaluating 8 candidate mechanisms and rejecting 6. **Why**: two failure modes Claude 4.7 does NOT self-correct — (a) asking the user about things grep would reveal, (b) losing user-cited doc paths before sub-agents see them, so downstream design violates the binding constraint. **How to apply**: these are the ONLY two new Phase-1 rules. Do NOT add more "anti-hallucination" rules without a concrete failure surfacing in real sprints — rejected as redundant: gray-area specificity (covered by "Push for specificity"), user/builder role separation (covered by "Challenge status-quo"), recommended-option gates (covered by "Take a position"), scope-creep Deferred docs (covered by Phase 1 "flag and decompose"), single-pass cap (covered by auto-verify 1 round), empty-answer retry (4.7 self-handles). Also rejected: CONTEXT.md + DISCUSSION-LOG.md + CHECKPOINT.json + 4 persistent project docs (violates single-ARCHITECTURE.md rule) and ADVISOR_MODE / NON_TECHNICAL_OWNER auto-routing (violates explicit-invocation rule).

## Conventions & Gotchas

<!-- project-specific conventions, decisions, gotchas; add entries as they surface -->

- **Squash merge only on main** — enforced by `scripts/hooks/pre-merge-commit` (installed by `init.sh` into each clone's `.git/hooks/`); feature branches fold into one commit on merge
- **Markdown + Bash only** — no runtime tests; verification is grep-based on references across `claude-config/`, `scripts/`, `docs/`
- **Single-file project memory** — `.stackpilot/ARCHITECTURE.md` is the sole per-project memory surface; `sp-qa` never writes it, only reads and surfaces Pattern Candidates in its report (2026-04-17)
- **stackpilot.config.yml `qa.test_command` may be `N/A`** for meta-projects (like this repo) — Step 0 pre-merge gate handles absent test commands by reporting `N/A`, not failing
- **`.githooks/pre-commit` rejects skill changes without co-doc changes**: during sprints, intermediate per-task commits that touch only `claude-config/skills/` or `claude-config/agents/` fail the hook. Workaround: accumulate all sprint changes locally and batch-commit skill files + CHANGELOG + docs in one commit at sprint end. Matches the squash-merge pattern anyway (2026-04-17).
- **sp-docs agents can "describe" files without actually writing them**: observed hallucination mode where the subagent reports "File created at: ..." in its summary but the file does not exist. Always verify file existence after any docs dispatch, especially for Write-only tasks (2026-04-17).
- **`restore.sh` auto-picks up new skills via wildcard loop**: adding a new directory under `claude-config/skills/` requires no changes to `restore.sh` — the existing `for skill_dir in "$CONFIG_DIR/skills/"*/` loop symlinks them automatically. Resist the temptation to add per-skill install logic.

## Review Patterns

<!-- maintained via Sprint Finish; sp-qa surfaces candidates, main agent merges; max 20 entries -->

- [atomicity] multi-row file writes use `write-to-.tmp && mv` pattern so a mid-write crash leaves the original intact ×1
- [size-control] SKILL.md defers deep algorithm details to `references/<name>.md` rather than inlining; keeps main skill readable and under ~500 lines ×1

## External Skill Dependencies

See `docs/sync.md` for all tracked external skills.
