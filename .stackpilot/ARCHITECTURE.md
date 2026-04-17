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
| `claude-config/skills/stackpilot-bench/` | `/stackpilot-bench` benchmark skill — separate from `/stackpilot` |
| `docs/bench-implementation.md` | Bench v1 implementation walkthrough + known limitations + v2 backlog |
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
- **Benchmark is a sibling skill, not a mode of `/stackpilot`**: `/stackpilot-bench` lives at `claude-config/skills/stackpilot-bench/` parallel to `/stackpilot` (2026-04-17). Reason: benchmarking has a different lifecycle from sprinting (run repeatedly on the same workload set, no merge-ready output), and embedding it inside `/stackpilot` would bloat the already-long SKILL.md. Runs produce `.stackpilot/benchmarks/history.csv` (21 columns, `status` column added for INCOMPLETE legs) + `runs/<ts>/report.md`.
- **Workload fixtures are synthetic, not repo-referenced**: each benchmark workload's `sandbox/` holds hand-crafted self-contained files. The workload does not reference real repo files — this isolates the benchmark from ongoing repo evolution and gives reproducibility across versions (2026-04-17).
- **/stackpilot is explicit-invocation only — never auto-route by inferred complexity**: the user opts in by typing `/stackpilot`. By that act, they have already decided this task warrants the heavy machinery. The skill must NOT add internal routing like "this looks light → skip sp-architect" — that breaks the user's mental contract (they invoked the heavy tool deliberately). Internal `complexity: light|standard` flags inside a plan ARE allowed (they're authored by the user/main-agent, not auto-inferred), but the `/stackpilot` entry point itself never branches on heuristic complexity guesses. **Why**: this is the explicit positioning that distinguishes stackpilot from superpowers (which auto-triggers on prompt keywords). **How to apply**: when proposing optimizations, never suggest "auto-detect simple tasks and skip phases". If a phase is wasteful for a class of tasks, the right fix is letting the user not invoke /stackpilot for that class — not auto-stripping the pipeline. (2026-04-17)
- **/stackpilot-bench workloads must match real /stackpilot usage scope**: trivial workloads (rename a string, add a one-line flag, edit one doc) produce misleading "stackpilot is wasteful" verdicts because users would never invoke /stackpilot for tasks that small. The first-cut workloads (trap-heavy-bash / doc-consistency / cross-file-refactor) were all too small and were deleted on 2026-04-17. **Why**: the first run showed stackpilot 5-7x slower than zero, which only "proves" stackpilot loses on tasks no one would use it for. **How to apply**: future workloads must mimic the size of an actual sprint a user would invoke /stackpilot for — multi-file features, cross-system refactors, risky bug fixes with subtle failure modes. Each new workload should pass the test "would I actually type /stackpilot for this?" before it's added. (2026-04-17)
- **Read ARCHITECTURE.md before proposing changes that touch project conventions**: when designing a new feature/refactor, scan this file's Key Design Decisions and Conventions & Gotchas sections first. If you're about to assert a convention not listed here, ask the user "is this a hard rule?" before coding it. If it IS a hard rule, add it here as part of the change. **Why**: 2026-04-17 stackpilot-bench design wasted two iterations because the "explicit invocation" and "workload scope" rules existed in the user's head but not in this file. **How to apply**: before any non-trivial design proposal, grep this file for keywords related to your design space, and surface any tension to the user explicitly. (2026-04-17)

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

- [trap-schema] workload `traps.yml` uses `check_mode: diff | final_file` to distinguish "regex matches diff" vs "regex matches final file content"; `final_file` mode is essential for stale-reference detection where the agent may have not touched the file at all ×1 (stackpilot-bench sprint)
- [atomicity] CSV append / any multi-row write uses `write-to-.tmp && mv` pattern so a mid-write crash leaves the original intact ×1 (stackpilot-bench sprint)
- [size-control] SKILL.md defers deep algorithm details to `references/<name>.md` rather than inlining; keeps main skill readable and under ~500 lines ×1 (stackpilot-bench sprint)

## External Skill Dependencies

See `docs/sync.md` for all tracked external skills.
