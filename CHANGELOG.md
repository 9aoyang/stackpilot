# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.2.1] - 2026-06-09

### Fixed

- **Hardened Node 2 design options** — `design-options.html` now uses an
  Apple-like minimal interface with real selectable cards, validates
  `OPTIONS_JSON` before rendering, and refuses to show placeholder/demo choices
  such as `Approach A`, `pro 1`, or `con 1`.

## [2.2.0] - 2026-06-07

### Changed — Official-frontier protocol refresh

- **Removed stale point-release model anchors from live prompts** — `sp-dev`,
  `sp-qa`, `templates/stackpilot.config.yml`, README, and architecture docs now
  describe capability tiers and Stackpilot-specific contracts instead of
  hard-coding claims like "Claude 4.7 self-catches..." or "haiku 4.5".
- **Aligned architecture-review routing** — `SKILL.md` now matches
  `references/run-sprint.md`: architecture review runs for `standard`
  complexity tasks. HIGH risk is an output of that review, not a valid trigger
  before the review exists.
- **Fixed zsh startup debris scan** — Step 0 now uses `find .claude/plans ...`
  instead of an unmatched `.claude/plans/*.md` glob, preventing `no matches
  found` noise when no plan files exist.
- **Added Action Safety Gate** — auto mode cannot silently run force push,
  remote delete, production database mutation, credential/secret movement,
  deployment, public repo-data upload, destructive MCP/app actions, or disabled
  verification gates. Decisions are recorded in the sprint event log.
- **Added sprint-level `events.jsonl`** — Run Sprint now defines a durable event
  log for `task-dispatched`, `phase-change`, `verification`, `decision`,
  `action-safety-gate`, and completion events. Sprint Finish consumes it for
  final report evidence.
- **Raised frontend acceptance bar** — frontend/UI criteria now require rendered
  UI evidence such as browser/devtools smoke, screenshot/DOM assertion,
  responsive overflow check, or native Playwright/Cypress route test; a server
  curl alone is not enough.
- **Made HTML view handoff explicit** — every HTML decision/report node must
  start or reuse the sprint server and print the `localhost` browser URL as the
  primary output; `.stackpilot/views/...` file paths are secondary context only.
- **Clarified OpenAI Codex boundary** — portable methodology skills remain
  compatible with OpenAI Codex Agent Skills, but `/stackpilot` sprint
  orchestration remains Claude Code-specific until a maintained Codex plugin or
  `.agents/skills` orchestration package is shipped.

### Evidence

- OpenAI Codex official docs/blog now emphasize Agent Skills, subagents,
  sandboxed worktrees, Sites/browser-style app verification, SDK/app-server
  event streams, and Claude-like long-running agent workflows.
- Anthropic Claude Code official engineering/news posts now emphasize auto-mode
  safety gates, long-running harnesses with durable session logs, dynamic
  workflows, and large parallel subagent teams.
- Added `tests/test-v2-2-upgrade.sh` to mechanically guard every v2.2.0
  upgrade claim, then ran it RED before implementation and GREEN after changes.
  Full test suite verification is recorded in the release handoff.

## [2.1.0] - 2026-05-25

### Added — Skill Tighten (sister-file sync via sub-agent contract)

- **Node 1 Scope Lock** — `SKILL.md` Exploration rigor rules 末尾加多文件改动前的 will-touch / will-NOT-touch 文件清单要求；歧义组件名先问再改。
- **Node 3 默认最小有效版本** — § 3.1 引导句：spec 先出最小可执行版本，comparison framework / decision matrix / 多 audience 切片仅在用户明确要求时加。
- **Node 4 plan task `sister_files` / `shared_field_grep` 字段** — 任务触动 shared identifier / shared field 时必填，sp-dev 启动前跑 grep 验证范围，sp-qa Stage 4 做 sync audit。§ 4.2 加对应 grep verify 行。
- **Node 5 pre-merge gate** — 显式三件套（`tsc --noEmit` / lint / test）+ 一次性脚本残留扫描（`scripts/(migrate|audit|debug|oneshot)-*` 命中即提示用户合并前是否删除）。
- **sp-architect Implementation Blueprint** — 加 `Will NOT touch` 字段；shared identifier 任务必含 grep false-positive 命中点。
- **sp-dev Required behaviors** — 加 Sister-file ack（启动前 grep + sister_files 验证）；`## Completion Output` 加 `## Sister-File Sync` 段。
- **sp-qa Consistency Audit** — 加第 4 条 Sister-file sync audit；Adversarial Angles Tried 默认列表加 `sister-file sync`。

### Why

回应 insights 报告（2026-05-25 / 283 sessions / 4520 messages）跨项目 5 大稳定 friction：wrong_approach 34 次（改错组件 / kept-wrong-pages / blocking overlay 当 fire-and-forget）、sister-file 漏改、文档过度工程、一次性脚本残留、完成前没 verify。前两项占主要比重，本次升级 SKILL.md + 3 个 sub-agent 契约把"sister-file sync"从一次性检查变成 plan→dev→qa 接力 enforce。

### Fixed

- **`scripts/restore.sh`**：agents 从 `cp` 改 `ln -sf`（与 skills 一致）。`cp` 每次仓库改 agent 文件都得手动 re-run；symlink 后改完即生效。
- **`VERSION` 文件**：v2.0.0 release 漏 bump（仍停在 1.11.0）→ 已校正到 2.0.0（本 release 再 bump 至 2.1.0）。
- **`.githooks/pre-commit`**：版本一致性检查只看 SKILL.md vs plugin.json，VERSION 单飞它放过；现把 `VERSION` 纳入三方检查。
- **`docs/architecture.zh.md`**：补 2026-05-25 evolution row（之前 sprint 只加英文版，违反中英双语同步原则）。

## [2.0.0] - 2026-05-22

### Added — HTML-first rebuild (dual-track architecture)

- **Dual-track principle** introduced in `SKILL.md`: data layer (markdown / YAML
  / JSON) feeds sub-agents and git diff; view layer (self-contained HTML)
  feeds human decision-makers at specific nodes. View layer is never source of
  truth; user actions on HTML write `*-action.json` files that the main agent
  reads back into the data layer.
- **5 HTML view templates** under `claude-config/skills/stackpilot/references/views/`:
  - `design-options.html` — 3-column responsive grid for Node 2 design picks
  - `dashboard.html` — live DAG (mermaid) + 5-col Kanban + criteria during Run Sprint
  - `spec-review.html` — left nav + markdown spec + 12-QA grid + editable criteria for Node 3
  - `finish-report.html` — chart.js task timeline + criteria pie + commits + A/B/C/D footer
  - `architecture.html` — on-demand full-page mermaid module graph
  All include CSP meta (self + jsdelivr only); CDN libs pinned (mermaid@10,
  markdown-it@14, chart.js@4).
- **Sprint server (extends `scripts/preview/server.cjs`)** — new routes
  additive to brainstorm back-compat: `GET /sprints/<slug>/<artifact>.html`,
  `POST /api/action/<slug>/<name>` (64KB body cap → 413), `GET /api/state/<slug>`
  aggregating `runs/<slug>/TASK-*/state.json` + `<slug>-criteria.md`. fs.watch
  on `.stackpilot/runs/` + `.stackpilot/specs/` broadcasts `state-update`
  WebSocket events for live dashboard refresh.
- **Sprint-slug lifecycle** — `start-server.sh --sprint-slug <name>` writes
  `.stackpilot/views/<slug>/.server-info.json`; `stop-server.sh --slug <name>`
  resolves and terminates that exact server. `--help` flag added.
- **`window.sp.{action,state}` helper API** in `scripts/preview/helper.js` for
  HTML templates to fetch state and POST actions. Existing brainstorm
  `data-choice` WS event protocol unchanged for back-compat. New `sp:state-update`
  CustomEvent dispatched on incoming WS state events.
- **`tests/test-html-rebuild-e2e.sh`** — 10-check E2E smoke: server start →
  sprint routing → action POST (200) → action JSON write → oversize body
  (413) → state JSON → slug-based stop → marker cleanup.

### Changed

- **SKILL.md restructured to 5 named nodes** (Exploration / Design / Spec &
  Criteria / Plan & Run Sprint / Finish) replacing the 10+ Phase X.Y
  numbering. Inline grep verifications and 12-QA matrix become sub-steps,
  not separate phases. File: 431 → 427 lines.
- **`references/run-sprint.md`** — Pre-Sprint step 4 starts sprint server +
  copies dashboard.html to `.stackpilot/views/<slug>/`, prints URL once.
  Sprint Interrupted resume re-prints URL. state.json schema gains
  `depends_on` (consumed by dashboard DAG renderer).
- **`references/sprint-finish.md`** — Step 3 generates `finish-report.html`,
  waits for `finish-action.json` OR terminal A/B/C/D (first wins; 30s
  fallback to terminal). Step 6 stops sprint server via `--slug`.
- **`docs/architecture.{md,zh.md}`** synced: new `references/views/`
  directory, `.stackpilot/views/` layout, server module names.
- **`.gitignore` + `templates/stackpilot-inner-gitignore` + `scripts/init.sh`**
  — `.stackpilot/views/` ignored at all levels; init idempotently appends
  `views/` to existing `.stackpilot/.gitignore` on re-run.
- **`qa-12-dimensions` portable skill hardened (1.0.1 → 1.1.0)** — 43 days of
  drift behind upstream Anthropic `feature-dev/code-reviewer` and stackpilot's
  internal sp-qa, closed in three targeted backports:
  (a) **5-tier confidence rubric** (0/25/50/75/100, only ≥80 reported) replaces
  the single "≥80%" line — matches feature-dev v2 standard for Claude 4.5+
  reviewer agents.
  (b) **Stage 1 renamed "Spec & Project Guidelines Compliance"** — reads
  `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` / `.cursorrules` as a first-class
  review angle; guideline violations are first-class findings.
  (c) **"Adversarial Angles Tried" required field** — sourced from sp-qa;
  "no findings" only credible when the angle list is non-trivial. Prevents
  the "review didn't happen → silently approved" failure mode.
  Sub-agent-only sp-qa features (output schema, Consistency Audit grep
  triplet, WTF-ratio self-monitoring, 15-fix hard cap, max-2-rounds verify)
  deliberately NOT backported — different audience.

### Deprecated (kept one release for back-compat; removal in v2.1)

- **`references/visual-companion.md`** — folded into sprint server. Node 2
  Design no longer routes to it.
- **`references/optimize-sprint.md`** — under review; same outcome achievable
  via standard 5-node sprint with a metric-targeting acceptance criterion.

### Breaking changes

- Any external tooling that references "Phase X.Y" by name (e.g. "Phase 3.7
  spec gate") must update — the Phase numbering is gone. Equivalent nodes:
  Phase 0.5/1 → Node 1; Phase 1.5/2 → Node 2; Phase 3/3.5/3.6/3.7 → Node 3;
  Phase 4/4.5 + Run Sprint → Node 4; Sprint Finish → Node 5.
- Sub-agent files (`sp-architect`, `sp-dev`, `sp-qa`, `sp-docs`) and their
  markdown completion-report schemas are unchanged — no breaking change at
  the agent contract layer.

### Removed (2026-05-20 — full cleanup of stackpilot-bench skill and Codex support; included in 2.0.0)

- **`/stackpilot-bench` skill deleted** — `claude-config/skills/stackpilot-bench/`
  (SKILL.md, all 3 workloads, scripts, references, run-codex-bench.sh,
  headless-mode.md) removed; `.stackpilot/benchmarks/` data (history.csv +
  per-run scorecards) removed; `tests/test-bench.sh` removed;
  `docs/bench-implementation.md` removed. The 2026-05-19 v2 rewrite was
  inconsistent across three layers (SKILL.md docs vs runner script vs workload
  files all disagreed on schema and prompt format), so it never actually ran.
- **`codex-config/` deleted** — Codex-native sp-* agent prompts no longer
  shipped. `claude-config/skills/stackpilot/references/codex-dispatch.md` also
  deleted along with the SKILL.md / docs / tests references that pointed at it.
- **`qa.disable_criteria_gate` and `qa.disable_state_json` config flags removed**
  from SKILL.md and `references/run-sprint.md`. These only existed to make the
  bench `stackpilot-serial` leg behave like v1.10.0; with bench gone they have
  no consumer. Default behavior of the gates is unchanged.
- **`.stackpilot/ARCHITECTURE.md`** trimmed of all bench-related Decision /
  Pattern entries.

### Fixed (2026-05-20 — post-cleanup test + docs alignment)

- **`tests/test-e2e.sh`** — added `check_absent` helper symmetric to `check`;
  added 4 negative assertions guarding against codex-config / bench skill /
  bench docs regrowth; redirected 5 stale `subagent_type` + light-skip grep
  targets from `SKILL.md` to `references/run-sprint.md` (where the dispatch
  protocol actually lives since v1.11.0's SKILL.md downsize). 5 pre-existing
  FAILs → 5 PASSes; full suite now 102/102.
- **`claude-config/agents/sp-architect.md`** — removed parenthetical
  reference `(bench 2026-04-17)` pointing at the deleted bench micro-benchmark;
  retained the underlying rule (extended thinking on every review).
- **`README.md`** — removed 4 stale references to Codex `update_plan` /
  `explorer` / `worker` dispatch fallback and "Codex-only `/stackpilot` skill"
  installation note (both English and 中文 sections). Codex orchestration was
  removed with the rest of `codex-config/`; these prose lines were missed.
- **`docs/architecture.md` + `docs/architecture.zh.md`** — bumped `Last updated`
  / `最后更新` from `2026-04-20` to `2026-05-20`.
- **`CHANGELOG.md`** — disambiguated two adjacent `### Changed` headers inside
  `[1.11.0]` that abutted after the cleanup deleted the block between them.

## [1.11.0] - 2026-05-18

### Changed (2026-05-18 — parallel Run Sprint + criteria-gated Sprint Finish + brainstorm re-sync)

- **Run Sprint now executes in parallel waves** instead of strict serial.
  Pre-Sprint computes dependency waves via topological sort over `depends_on`;
  wave-internal tasks dispatch in parallel (cap by `qa.max_parallel`, default
  3). Each task already has worktree isolation, so concurrent dev is safe.
  Expected to be the largest wall-time improvement to the sprint pipeline.
  Detailed protocol in `claude-config/skills/stackpilot/references/run-sprint.md`.
- **Per-task `state.json` persistence** under
  `.stackpilot/runs/<sprint-slug>/TASK-NNN/` (gitignored, atomic `.tmp` +
  `mv` writes). Replaces in-memory-only TaskCreate state. Sprint Interrupted
  recovery now reads `state.json` first; falls back to git log heuristic only
  when missing.
- **Acceptance-criteria-driven Sprint Finish gate**
  (`references/sprint-finish.md` Step 0.5). Phase 3.6 derives mechanically
  verifiable criteria (`.stackpilot/specs/<feature>-criteria.md`); sp-qa
  updates Status during Run Sprint; Sprint Finish enforces 3 gates (criteria
  all green / CHANGELOG covers sprint scopes / Pattern Candidates surfaced)
  before allowing merge. Replaces the "agent self-declares done" pattern
  (Anthropic premature-completion antipattern).
- **Run Sprint section in `SKILL.md` downsized** (~100 lines → ~28 lines).
  Detailed bash + agent dispatch templates + state transitions moved to
  `references/run-sprint.md`.
- **Light Feature path now runs mandatory mini-brainstorm** (≤2 minutes:
  scout + ≤1 clarifying question + 1 approach + user confirm). Recovers the
  "Too Simple to Need a Design" anti-pattern diluted by the 2026-04-17
  "Light skips Phase 1/2" decision.
- **Standard Feature path adds Phase 3.7 User Reviews Spec Gate.** Spec is
  presented to the user for review after Phase 3.5 12-QA but before plan
  writing. Sourced from superpowers:brainstorming step 8 re-sync.
- **`docs/sync.md` brainstorming row updated** (Last Checked 2026-04-08 →
  2026-05-18) — "Too Simple" anti-pattern and User Reviews Spec gate added
  to Core Contribution.
- **`.stackpilot/ARCHITECTURE.md`** Key Design Decisions section adds 3 new
  rules covering the above (parallel waves, artifact-driven termination,
  Light mini-brainstorm + Phase 3.7).

### Changed (2026-04-20 — agent prompt reshape)
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

### Fixed
- **sp-* agents now actually dispatch** — forensics on 171 real user stackpilot sessions showed `sp-architect` / `sp-dev` / `sp-qa` / `sp-docs` had NEVER been invoked. Three compounding bugs:
  1. Frontmatter used non-standard `allowed-tools:` YAML list; Claude Code spec requires `tools:` comma-separated string. Silent non-registration.
  2. Users installing via skill-only symlink never ran `install.sh`, so agents never landed in `~/.claude/agents/`.
  3. `SKILL.md` `Agent()` calls never passed `subagent_type`, routing every dispatch to `general-purpose`.

  All three fixed: frontmatter corrected, `install.sh` now prints a RESTART reminder, all dispatch sites include `subagent_type="sp-*"`. Activation requires Claude Code restart after install.

### Added
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
