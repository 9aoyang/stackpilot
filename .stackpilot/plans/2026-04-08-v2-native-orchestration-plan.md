# Implementation Plan: Stackpilot v2 Native Orchestration

## File Structure Map

### Files to delete
- `scripts/dispatch.sh` — bash agent dispatcher (replaced by Agent tool)
- `scripts/hooks/pre-commit.sh` — spec/plan validation hook (moved inline)
- `scripts/hooks/post-commit.sh` — sp-pm trigger hook (PM removed)
- `scripts/hooks/post-checkout.sh` — sp-coordinator trigger hook (coordinator inlined)
- `claude-config/agents/sp-pm.md` — PM agent (decomposition inlined in skill)
- `claude-config/agents/sp-coordinator.md` — coordinator agent (inlined in skill)
- `templates/backlog.yml` — YAML task template (replaced by TaskCreate)
- `templates/in-progress.yml` — in-progress tracking template (replaced by TaskCreate)

### Files to rewrite
- `claude-config/skills/stackpilot/SKILL.md` — main skill, rewrite Run Coordinator → Run Sprint
- `claude-config/agents/sp-dev.md` — remove file I/O, pure methodology
- `claude-config/agents/sp-qa.md` — remove file I/O, pure methodology
- `claude-config/agents/sp-architect.md` — remove file I/O, pure methodology

### Files to simplify
- `scripts/init.sh` — remove hooks installation, provider detection, model routing
- `scripts/lib/config.sh` — keep config_get, remove locking functions
- `templates/stackpilot.config.yml` — reduce to qa section only
- `templates/stackpilot-inner-gitignore` — simplify (fewer runtime dirs)

### Files to create
- `claude-config/skills/stackpilot-resume/SKILL.md` — sprint resume skill

### Files to update
- `claude-config/skills/stackpilot-auto/SKILL.md` — adjust overrides for new architecture
- `docs/sync.md` — update tracking table

---

## Tasks

### TASK-001: Rewrite sp-architect.md — pure methodology prompt
- **title**: Rewrite sp-architect as pure methodology agent
- **type**: dev
- **complexity**: light
- **depends_on**: []
- **relevant_files**: `claude-config/agents/sp-architect.md`
- **description**:
  Remove all file I/O from sp-architect. Currently reads task from backlog.yml and writes to arch-review/TASK-ID.md. In v2, it receives task context directly in prompt and returns architecture decision as text output. Keep: existing patterns analysis, decisive architecture choice, multi-persona review for HIGH risk, implementation blueprint. Remove: backlog.yml reading, arch-review/ file writing, escalation to NEEDS_REVIEW.md (return as text instead). Add frontmatter field `model: opus` for Claude Code native routing.

### TASK-002: Rewrite sp-dev.md — pure methodology prompt
- **title**: Rewrite sp-dev as pure methodology agent
- **type**: dev
- **complexity**: light
- **depends_on**: []
- **relevant_files**: `claude-config/agents/sp-dev.md`
- **description**:
  Remove all file I/O from sp-dev. Currently reads backlog.yml, reads arch-review/, updates backlog.yml status, writes done/TASK-ID.md. In v2, it receives task description + architecture review in prompt. Keeps: TDD cycle (RED-GREEN-REFACTOR), verify/fix loop (4 checks, max 3 rounds), root cause investigation phases, "fundamentally different approach" examples, git history review. Remove: backlog.yml reads/writes, arch-review/ reads, done/ file writes, NEEDS_REVIEW.md file writes. Agent returns completion report as structured text output. Escalation returned as structured text with `[ESCALATION]` prefix. Add: read `stackpilot.config.yml` for test_command (this stays as the one config file agents read).

### TASK-003: Rewrite sp-qa.md — pure methodology prompt
- **title**: Rewrite sp-qa as pure methodology agent
- **type**: dev
- **complexity**: light
- **depends_on**: []
- **relevant_files**: `claude-config/agents/sp-qa.md`
- **description**:
  Remove file I/O from sp-qa. Currently reads stackpilot.config.yml, reads done/TASK-ID.md, reads backlog.yml, writes to NEEDS_REVIEW.md, updates backlog.yml. In v2, receives task description + dev completion report in prompt. Keeps: two-stage code review (spec compliance + code quality), 12-dimension scenario coverage, reporting rules (confidence >= 80), verify/fix loop. Remove: backlog.yml reads/writes, done/ reads, NEEDS_REVIEW.md file writes. Critical issues returned as `[CRITICAL]` prefixed text. Important fixes (<5 lines) applied directly. Still reads `stackpilot.config.yml` for test_command and coverage_threshold.

### TASK-004: Rewrite SKILL.md — Run Sprint section
- **title**: Rewrite SKILL.md Run Coordinator as Run Sprint using native Agent tool
- **type**: dev
- **complexity**: standard
- **depends_on**: [TASK-001, TASK-002, TASK-003]
- **relevant_files**: `claude-config/skills/stackpilot/SKILL.md`
- **description**:
  This is the core change. Replace the entire "Run Coordinator" section and all references to backlog.yml/in-progress.yml/done/ with a new "Run Sprint" section that uses Claude Code native tools.

  **Changes to "Run Coordinator" section** (rename to "Run Sprint"):
  Replace the Entry Checklist (NEEDS_REVIEW processing, timeout checks, soft-blocked retry, circular dep detection, dispatch rules) with a simple linear loop:
  ```
  For each task parsed from the plan file:
    1. TaskCreate or TaskUpdate(in_progress)
    2. If standard: arch_result = Agent(sp-architect + task)
    3. dev_result = Agent(sp-dev + task + arch_result, isolation="worktree")
    4. If dev returned [ESCALATION]: present to user, wait, retry
    5. qa_result = Agent(sp-qa + task + dev_result)
    6. If qa returned [CRITICAL]: present to user, wait
    7. TaskUpdate(completed)
    8. Print progress line
  ```

  **Changes to state references throughout SKILL.md**:
  - Remove all `backlog.yml` references → TaskCreate/TaskUpdate
  - Remove all `in-progress.yml` references → TaskCreate status
  - Remove all `done/TASK-ID.md` references → agent returns output directly
  - Remove all `arch-review/TASK-ID.md` references → agent returns output directly
  - Remove `coordinator.worktree_limit` and `coordinator.timeout_hours` references

  **Changes to "Sprint In-Progress" section**:
  - Option A: Continue → Run Sprint (checks TaskList for pending)
  - Remove option C (view task details from done/ files)

  **Changes to "Sprint Finish" section**:
  - Remove backlog.yml cleanup (no more backlog)
  - Remove done/ and arch-review/ cleanup
  - Keep: test run, dev server detection, merge/PR/keep/discard options

  **Changes to Light Feature and Standard Feature paths**:
  - Plan writing stays the same
  - Instead of "create feature branch → commit plan → run Coordinator", change to "create feature branch → commit plan → Run Sprint"

  **Keep unchanged**: Step 1 (show state), Visual Companion, Design phases, Spec writing, Plan writing, Optimize Sprint, Sprint Finish options

### TASK-005: Simplify init.sh
- **title**: Simplify init.sh — remove hooks, provider detection, model routing
- **type**: dev
- **complexity**: light
- **depends_on**: []
- **relevant_files**: `scripts/init.sh`, `templates/stackpilot.config.yml`, `templates/stackpilot-inner-gitignore`
- **description**:
  Reduce init.sh from ~300 lines to ~100 lines.

  **Remove**:
  - `detect_provider()` function and all provider references
  - `install_hook()` function and all 3 hook installations
  - Model routing config generation (the `models:` section in config template)
  - `install_skill()` function and dependency checks (autoresearch, superpowers)
  - `coordinator:` section from config template
  - `.stackpilot/path` and `.stackpilot/version` file creation

  **Keep**:
  - Git repo check
  - `.stackpilot/` directory creation (specs/, plans/ only — remove tasks/ subdirs)
  - `.stackpilot/.gitignore` creation
  - `NEEDS_REVIEW.md` creation
  - `detect_test_command()` function (auto-detect test runner)
  - `stackpilot.config.yml` generation (qa section only)
  - `.gitignore` updates

  **Simplify config template to**:
  ```yaml
  qa:
    test_command: <detected>
    coverage_threshold: 80
  ```

  **Update stackpilot-inner-gitignore** to only ignore NEEDS_REVIEW.md (specs/ and plans/ are tracked).

### TASK-006: Delete deprecated files
- **title**: Remove deprecated infrastructure files
- **type**: dev
- **complexity**: light
- **depends_on**: [TASK-004, TASK-005]
- **relevant_files**: `scripts/dispatch.sh`, `scripts/hooks/`, `claude-config/agents/sp-pm.md`, `claude-config/agents/sp-coordinator.md`, `templates/backlog.yml`, `templates/in-progress.yml`, `scripts/lib/config.sh`
- **description**:
  Delete the following files:
  - `scripts/dispatch.sh`
  - `scripts/hooks/pre-commit.sh`
  - `scripts/hooks/post-commit.sh`
  - `scripts/hooks/post-checkout.sh`
  - `claude-config/agents/sp-pm.md`
  - `claude-config/agents/sp-coordinator.md`
  - `templates/backlog.yml`
  - `templates/in-progress.yml`

  Simplify `scripts/lib/config.sh`:
  - Keep: `config_get`, `config_get_or`, `strip_frontmatter`, `get_frontmatter_field`
  - Remove: `locked_write` function and all flock/mkdir lock logic

  Keep `scripts/hooks/README.md` with a note that hooks were removed in v2.

### TASK-007: Create /stackpilot:resume skill
- **title**: Create stackpilot:resume skill for interrupted sprint recovery
- **type**: dev
- **complexity**: light
- **depends_on**: [TASK-004]
- **relevant_files**: `claude-config/skills/stackpilot-resume/SKILL.md`
- **description**:
  Create new skill at `claude-config/skills/stackpilot-resume/SKILL.md` with frontmatter:
  ```yaml
  name: stackpilot:resume
  description: Resume an interrupted stackpilot sprint. Reads the plan file and git history to determine which tasks are done vs pending, then continues the sprint.
  ```

  Skill body:
  1. Find latest plan file: `ls -t .stackpilot/plans/*.md | head -1`
  2. Read plan file, parse TASK sections (### TASK-NNN headers)
  3. Read git log: `git log --oneline --all` — match commit messages containing TASK IDs
  4. For each TASK: if commit found → mark done, else → mark pending
  5. Read NEEDS_REVIEW.md — if has unresolved content, present to user first
  6. TaskCreate for each pending task
  7. Print status summary showing done/pending
  8. Ask: "Continue sprint from TASK-XXX?" → Run Sprint from that point

### TASK-008: Update stackpilot-auto and docs
- **title**: Update auto mode and documentation for v2 architecture
- **type**: dev
- **complexity**: light
- **depends_on**: [TASK-004]
- **relevant_files**: `claude-config/skills/stackpilot-auto/SKILL.md`, `docs/sync.md`, `docs/architecture.md`
- **description**:
  **stackpilot-auto/SKILL.md**: Update override descriptions. Replace "Run Coordinator step 4" reference with "Run Sprint pre-coding confirmation". Remove references to backlog.yml cleanup in sprint finish.

  **docs/sync.md**: No changes needed (tracking table references skill names, not internals).

  **docs/architecture.md**: If exists, update to reflect v2 architecture. Key changes: no more dispatch.sh, no more git hooks, agents receive context via prompt, TaskCreate for tracking.

  **scripts/hooks/README.md**: Update to explain hooks were removed in v2, with brief explanation of why.
