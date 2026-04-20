# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- **`/stackpilot-bench` headline output is now a scorecard, not a verdict.**
  Scorecard answers "is stackpilot worth using over native Claude Code?"
  with 0-100 per-dimension scores (correctness / over-engineering
  resistance / bug catch rate / token efficiency / wall-clock speed),
  plus a per-workload decision guide. The POSITIVE / MARGINAL / NEGATIVE
  verdict is still rendered as a secondary regression-tracking view. See
  `claude-config/skills/stackpilot-bench/references/scoring.md`.
- **Verdict quality gate now counts sp-qa catches.** Pairwise quality
  condition is `stackpilot.traps_avoided_in_diff + 0.5 * traps_caught_in_qa
  >= baseline.traps_avoided_in_diff`. Without this, any sp-qa improvement
  was invisible to the bench.
- **sp-dev agent prompt reshaped.** Six explicit "Don't add X"
  boundaries at the top (primacy position) mirror Anthropic's official
  "Avoid over-engineering" template for Claude Opus 4.5/4.6/4.7. Filler
  posture lines removed; U-shape reminder at the bottom. Claude Opus's
  acknowledged scope-creep tendency now has an explicit guardrail.
- **sp-architect agent prompt reshaped.** Prescriptive Process 1-5 steps
  replaced by general instructions ("What to ground the review in") per
  Anthropic's "prefer general instructions over prescriptive steps"
  guidance for Claude 4.x. Non-negotiable boundaries at the top
  (read-only, one decision not a list, justified risk).
- **sp-qa agent prompt reshaped.** Opens with an adversarial KPI ("your
  job is finding reasons this PR should not ship"), requires every
  finding to cite `file:line` + concrete failure scenario + ≥80%
  confidence, and mandates an "Adversarial Angles Tried" completion
  field so "no finding" has to be earned. The deterministic Consistency
  Audit (stackpilot's unique value) is preserved verbatim.

### Added
- **Three representative workloads installed** under
  `claude-config/skills/stackpilot-bench/workloads/`:
  `01-stripe-invoice-api` (simple, 11 traps),
  `02-rate-limit-middleware` (medium, 13 traps),
  `03-moment-to-datefns-refactor` (complex, 15 traps). Every trap has a
  `category: over-engineering | correctness` field for future scorecard
  splits. Replaces workloads deleted in 27f1838.
- **Headless execution scaffolded**
  (`scripts/run-leg-headless.sh` + `references/headless-mode.md`). Each
  leg runs as an isolated `claude --print` subprocess, eliminating
  parent-session prompt-cache leak that biased v1 token counts. Not
  wired as SKILL.md default yet — requires live CLI contract verify +
  permissions guard + re-baseline. See `headless-mode.md § Flipping the
  default`.

### Fixed
- **sp-* agents now actually dispatch** — forensics on 171 real user stackpilot sessions showed `sp-architect` / `sp-dev` / `sp-qa` / `sp-docs` had NEVER been invoked. Three compounding bugs:
  1. Frontmatter used non-standard `allowed-tools:` YAML list; Claude Code spec requires `tools:` comma-separated string. Silent non-registration.
  2. Users installing via skill-only symlink never ran `install.sh`, so agents never landed in `~/.claude/agents/`.
  3. `SKILL.md` `Agent()` calls never passed `subagent_type`, routing every dispatch to `general-purpose`.

  All three fixed: frontmatter corrected, `install.sh` now prints a RESTART reminder, all dispatch sites include `subagent_type="sp-*"`. Activation requires Claude Code restart after install.

### Added
- **`/stackpilot-bench` skill** — continuous quantitative benchmark for stackpilot. Runs naive_zero / naive_savvy / stackpilot legs across a set of fixed workloads, writes CSV time series + verdict report. Use after editing `sp-*` prompts or `/stackpilot` orchestration to confirm the change is a positive optimization. See `claude-config/skills/stackpilot-bench/SKILL.md` for the full protocol and `docs/architecture.md` for high-level description. **Note (2026-04-17)**: first-cut workloads (rename / flag-add / doc-edit) deleted as too small to be representative — see ARCHITECTURE.md "workloads must match real /stackpilot usage scope". New workloads pending design.
- **Task-type routing for sp-docs** — `type: docs` tasks now route to `sp-docs` (haiku model). Previously all types went to `sp-dev` (sonnet), making the haiku cost optimization dead code.
- **`tests/test-e2e.sh` +8 structural assertions** — guards against the registration regression returning: frontmatter `tools:` format on all 4 agents, `subagent_type="sp-*"` on all SKILL.md dispatches, sp-docs routing.

### Verified (benchmark evidence, 2026-04-17)
- sp-docs live dispatch confirmed: identity "Stackpilot Docs Agent", model `haiku`, tools `Read, Edit, Write, Glob` (no Bash/Grep per frontmatter restriction).
- sp-architect live dispatch confirmed: model `opus`, tools `Read, Glob, Grep, WebSearch` (read-only — cannot write code by construction).
- sp-qa vs inline-methodology-on-general-purpose micro-benchmark on the same read-only task: **10.7k tokens / 13.6s vs 21.5k tokens / 31.1s** (2x cheaper, 2.3x faster). Root cause: registered agent methodology caches as Claude Code system prompt; inline methodology counts as input tokens every dispatch.
- sp-dev benchmark (read-only analysis of `detect_test_command`): **9.8k tokens / 13.0s vs 21.4k tokens / 18.2s** (2.2x cheaper, 1.4x faster). Quality roughly equivalent.
- sp-architect benchmark (LOW-risk architecture review): **19.7k tokens / 47.6s vs 32.5k tokens / 50.7s** (1.6x cheaper, similar duration). Quality regression flagged: general-purpose + opus + inline architect methodology caught a critical failure mode (dev hand-editing generated files silently skipped) and bumped risk LOW→MEDIUM; sp-architect missed it. Hypothesis: methodology-as-system-prompt dilutes "think deeply" directive vs. fresh in-prompt. n=1, but worth watching. Recommendation: promote extended thinking in sp-architect from HIGH-only to always-on, and require explicit risk-level justification in the review output.

## [1.10.0] - 2026-04-17

### Added
- **Per-phase effort advisory** — `stackpilot.config.yml` gains an `effort:` block (architect: xhigh, dev: high, qa: medium, docs: low). All 4 agent prompts include a one-line effort posture that reflects this allocation. Users set matching Claude Code effort for best cost/quality.
- **Cross-sprint memory files** — `.stackpilot/sprint-metrics.md` (appended by `sprint-finish` Step 0.5) and `.stackpilot/decisions.md` (appended by `sp-architect` on HIGH-risk reviews). Sprint Clean now reads sprint-metrics.md and surfaces a SOFT-BLOCKED trend advisory when the rate climbs across 3 sprints. Append failures are non-blocking (supplementary memory, not critical path).
- **`references/12-qa-matrix.md`** — consolidated 12-dimension scenario coverage tables for both Spec and Plan reviews.

### Changed
- **Verify/fix loops reduced 3 → 2 rounds** — SKILL.md Phase 3/4 auto-verify, sp-dev Fix Loop Rules, sp-qa Verify/Fix Loop. Rationale: Opus 4.7 self-catches most issues earlier; the third round was rarely productive.
- **SKILL.md token trim** — 12-QA tables extracted to `references/12-qa-matrix.md`. SKILL.md net -26 lines, saves ~1.5k tokens per `/stackpilot` invocation.
- **`sp-architect`** — now reads `.stackpilot/decisions.md` (if present) before producing reviews and cites relevant prior decisions in "Existing Patterns".

## [1.9.1] - 2026-04-16

### Removed
- **codex-plugin-cc cross-model review integration** — sp-qa no longer invokes `/codex:adversarial-review`. Removed tracking from `docs/sync.md`. Removed `CODEX_CI` environment detection from preview server.

### Changed
- **sp-qa deep review** — optional `/ultrareview` (Claude Code Opus 4.7+) replaces codex cross-model review for HIGH-risk tasks. Still non-blocking, still supplementary.

## [1.9.0] - 2026-04-16

### Added
- **sp-qa WTF self-monitoring** — tracks revert/fix ratio and total fix count during QA runs. Hard stops at 15 fixes or when instability ratio exceeds 20%, preventing cascading damage from runaway fixes.
- **Phase 1 anti-sycophancy** — Standard Feature exploration now enforces position-taking, specificity forcing questions, status-quo challenge, and a two-push rule for vague requirements.
- **Sprint-finish pre-merge gate** — new Step 0 runs typecheck + lint + test suite before presenting merge/PR options. Failures are surfaced explicitly, not silently skipped.
- **3-strike escalation in debugging** — systematic-debugging now hard-stops after 3 disproven hypotheses and escalates to user with evidence, preventing guess spirals.
- **`--quick` flag for sync-skills** — skips full skill directory sync on startup, used by `/stackpilot` Step 0 for faster invocation.

## [1.8.0] - 2026-04-13

### Added
- **Skill auto-sync** — `scripts/sync-skills.sh` with `--auto-update` mode. Automatically checks for upstream updates (throttled to once per 24h), pulls new versions, and syncs missing skills. Works for both developers (symlink mode) and external users (copy mode).
- **Post-commit hook** — `scripts/hooks/post-commit` auto-creates symlinks for newly added skill directories after commit. Installed by `restore.sh`.
- **Version self-check in `/stackpilot`** — Step 0 runs version check on skill invocation, notifying users of available updates.
- **Fixed `install.sh` skill copy** — uses `cp -r` to preserve `references/` subdirectories in skills.

## [1.7.0] - 2026-04-13

### Added
- **`/stackpilot-research` skill** — Cross-longitudinal analysis (横纵分析法) for deep research reports (10k-30k words). 3-wave research strategy, narrative-driven output, structured quality self-check. Explicit invocation only.

## [1.6.1] - 2026-04-12

### Changed
- Sharpened agent prompts (sp-dev, sp-architect, sp-qa, sp-docs) and SKILL.md planning gates with Karpathy coding principles: positive traceability over negative constraints, assumption surfacing, simplicity self-checks, anti-scope-creep in plans.

## [1.6.0] - 2026-04-11

### Added
- **`pre-merge-commit` git hook** — blocks non-squash merges on main/master. `git merge --squash` is unaffected (no merge commit = hook doesn't fire). Installed by `init.sh`. Bypass: `STACKPILOT_ALLOW_MERGE=1`.

## [1.5.3] - 2026-04-11

### Fixed
- **12-QA phases skipped** — Phase 3 and Phase 4 auto-verify exits used ambiguous `auto-proceed` which LLMs interpreted as "jump to next numbered phase", skipping Spec 12-QA (Phase 3.5) and Plan 12-QA (Phase 4.5). Replaced with explicit phase references and "do NOT skip" instruction.

## [1.5.2] - 2026-04-11

### Fixed
- **`/release` skill** — include `docs/architecture.md` and `docs/architecture.zh.md` in release commit to satisfy pre-commit hook that requires docs updates when skill files change

## [1.5.1] - 2026-04-11

### Changed
- Remove unused `NEEDS_REVIEW.md` mechanism entirely (template, init, skill references, docs, tests)

### Fixed
- Fix zsh `no matches found` errors in sprint cleanup — replace glob patterns (`ls *.md`, `rm -f *.md`) with `find -name '*.md'` for cross-shell safety

## [1.5.0] - 2026-04-11

### Added
- **Spec/Plan 12-QA gates** — after spec and plan auto-verify, a 12-dimension scenario coverage review is run (happy path, error, edge case, abuse, scale, concurrent, temporal, data variation, permission, integration, recovery, state transition); dimensions 1-4 are hard gates that block progress if missing

### Fixed
- **`/release` skill** — use Edit tool instead of sed for version bumping

## [1.4.0] - 2026-04-11

### Added
- **`/release` skill** — project-local skill that auto-generates CHANGELOG from git log, detects bump type (patch/minor/major), bumps all three version files, validates, tags, and pushes
- **`.stackpilot/ARCHITECTURE.md`** — quick-reference architecture summary for sprint routing

### Fixed
- **pre-commit hook** — expanded doc check to include README.md and CONTRIBUTING.md
- **`/release` skill** — support `patch`/`minor`/`major` bump types with auto-calculation; auto-detect bump type from commits when no args provided

## [1.3.0] - 2026-04-11

### Changed
- **Sprint Finish: squash merge as standard** — merging to base branch now uses `git merge --squash`, producing exactly one commit on main
- **Pre-merge housekeeping on feature branch** — architecture update and sprint artifact cleanup are committed on the feature branch before squash, so they get folded into the single merge commit
- **Feature branch auto-deleted after merge** — `git branch -d` runs automatically on choice A

## [1.2.0] - 2026-04-10

### Added
- **sp-qa Stage 3: Adversarial Review** — attacker-mindset review checking 6 attack surfaces (auth, data integrity, rollback, race conditions, null/timeout, version skew). Full review for HIGH risk tasks, top 3 for others.
- **Review Patterns (cross-sprint memory)** — `.stackpilot/review-patterns.md` accumulates recurring QA findings across sprints. Frequency-based retention (max 20, lowest-count pruned first). sp-qa reads patterns on startup and actively watches for known issues.
- **Risk-aware QA dispatch** — architecture review risk level passed to sp-qa, controlling adversarial review depth.

## [1.1.0] - 2026-04-10

### Changed
- **Consolidated orchestration commands** (6→3): merged `stackpilot-auto`, `stackpilot-resume`, `stackpilot-tidy` into main `/stackpilot` as state-routed flows
- **Removed archive mechanism**: plans/specs are deleted directly after sprint (git history is sufficient)
- **Auto/interactive mode**: user chooses after describing feature, replacing standalone `/stackpilot-auto`

### Added
- **Workspace tidy flow**: cleans `.claude/plans/`, `.superpowers/`, orphaned worktrees, merged branches, stale remote tracking branches
- **Sprint resume flow**: detects interrupted sprints from plan + git log, offers continue/fresh/discard

### Removed
- `stackpilot-auto` skill (merged into `/stackpilot`)
- `stackpilot-resume` skill (merged into `/stackpilot`)
- `stackpilot-tidy` skill (merged into `/stackpilot`)
- `.stackpilot/archive/` directory and all archive logic

## [1.0.1] - 2026-04-08

### Added
- New portable skill: `systematic-debugging` — 4-phase root cause investigation
- TDD rationalization blockers in `tdd-development` (7 common excuses countered)

### Changed
- Updated all docs for v1.0 completeness (README, architecture, sync, CONTRIBUTING)

## [1.0.0] - 2026-04-08

### Changed — Architecture Rewrite
- **Agent dispatch**: replaced `dispatch.sh` (272 lines bash) with Claude Code native Agent tool — Fork pattern cache sharing, automatic worktree isolation
- **Task tracking**: replaced `backlog.yml` + `in-progress.yml` with Claude Code native `TaskCreate`/`TaskUpdate`
- **Inter-agent communication**: replaced file exchange (`arch-review/`, `done/`) with prompt-level passing
- **Coordinator**: inlined into SKILL.md "Run Sprint" section (was separate `sp-coordinator` agent)
- **Task decomposition**: inlined into skill Phase 4 (was separate `sp-pm` agent)
- **Config**: simplified from 40-line multi-provider to 5-line qa-only (`stackpilot.config.yml`)
- **SKILL.md**: restructured with progressive disclosure — 482→186 lines, heavy content moved to `references/`
- **All skill names**: migrated from colon syntax (`stackpilot:auto`) to hyphen syntax (`stackpilot-auto`) for Agent Skills spec compliance

### Added
- **Portable methodology skills** (Agent Skills standard, work in Cursor/Copilot/Gemini CLI/Codex/25+ products):
  - `tdd-development` — TDD cycle + verify/fix loop + 4-phase root cause investigation
  - `qa-12-dimensions` — two-stage code review + 12-dimension scenario test coverage
  - `architecture-review` — codebase pattern analysis → decisive choice → implementation blueprint
- **`/stackpilot-resume`** skill — recover interrupted sprints from plan + git log
- **Claude Plugin manifest** (`.claude-plugin/plugin.json`) — installable via marketplace
- **Progressive disclosure references**: `references/visual-companion.md`, `references/optimize-sprint.md`, `references/sprint-finish.md`

### Removed
- `scripts/dispatch.sh` — replaced by Claude Code native Agent tool
- `scripts/hooks/pre-commit.sh`, `post-commit.sh`, `post-checkout.sh` — validation and triggers inlined into skill
- `claude-config/agents/sp-pm.md` — task decomposition inlined into skill
- `claude-config/agents/sp-coordinator.md` — orchestration inlined into skill
- `templates/backlog.yml`, `templates/in-progress.yml` — replaced by TaskCreate
- Cross-provider support (Gemini/custom) — now Claude Code-only
- Provider detection, model routing matrix, worktree management, file locking from init.sh

## [0.3.0] - 2026-04-07

### Added
- Automated GitHub Release workflow triggered by `v*` tags
- Release helper script for validating tag and `VERSION` consistency

### Changed
- CI now runs release automation tests

## [0.2.0] - 2026-04-05

### Changed
- Renamed all agent files to `sp-*` prefix (`sp-pm`, `sp-architect`, `sp-dev`, `sp-qa`, `sp-docs`, `sp-coordinator`) — **breaking change** for existing installations
- Moved task runtime directory from `tasks/` to `.stackpilot/tasks/` — **breaking change** for existing installations
- Renamed config pointer from `.stackpilot-path` to `.stackpilot/path`
- Git hooks now watch `.stackpilot/specs/` and `.stackpilot/plans/` instead of `docs/specs/`
- Updated GitHub org/username references in README and install URL
- Significant rewrite of `/stackpilot` skill (`SKILL.md`) for improved agent dispatch logic
- Replaced dependency table in README with link to architecture docs

### Added
- Architecture documentation: `docs/architecture.md` and `docs/architecture.zh.md`
- `docs/skill-refs.md` skill reference index

### Removed
- Old design specs and implementation plan docs (`docs/specs/`, `docs/superpowers/`)
- Workflow diagram (`docs/workflow.png`, `docs/workflow.html`)

## [0.1.0] - 2026-03-29

### Added
- Core agent definitions: PM, Architect, Dev, QA, Docs, Coordinator
- Project templates: `backlog.yml`, `in-progress.yml`, `stackpilot.config.yml`, `NEEDS_REVIEW.md`
- `init.sh` script to initialize Stackpilot in any project
- `restore.sh` script to install agents and skills to `~/.claude/`
- Git hooks: `post-commit` (triggers PM Agent), `post-checkout` (triggers Coordinator)
- `/stackpilot` skill as primary workflow entry point
- `/update-gstack` skill and cron-based auto-updater
- Test suite: `test-init.sh`, `test-hooks.sh`, `test-e2e.sh`
- Workflow diagram (`docs/workflow.png`)
- Design specs and implementation plan documentation

### Fixed
- Auto-install gstack if not found during init
- Correct `--allowedTools` syntax in coordinator dispatch table
- Use append semantics for `NEEDS_REVIEW.md` in all agents
- Skill file renamed to `SKILL.md` for Claude Code discovery
