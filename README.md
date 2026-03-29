# Stackpilot

Autonomous AI development team framework for Claude Code. Give it an idea; it delivers production-ready code.

## How it works

Stackpilot runs a five-layer pipeline inside Claude Code:

1. **Idea** — you write a feature spec in `docs/specs/` and commit it.
2. **PM Agent** — triggered by the `post-commit` hook, reads the spec and decomposes it into atomic tasks written to `tasks/backlog.yml`.
3. **Coordinator** — triggered by the `post-checkout` hook when you switch to a feature branch; reads the backlog, dispatches specialist agents in sequence, and tracks in-progress work.
4. **Specialist Agents** — Dev, QA, Architect, and Docs agents each implement one task at a time, following strict conventions and escalating to `tasks/NEEDS_REVIEW.md` when blocked.
5. **Delivery** — completed task summaries land in `tasks/done/`, docs are updated, and you receive a macOS notification when the sprint finishes.

## Prerequisites

- Claude Code CLI (`claude`)
- gstack skill:
  ```bash
  git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack
  ```

## Quick start (new project)

1. Install agents and skills (one-time):
   ```bash
   bash scripts/restore.sh
   ```

2. Initialize Stackpilot in your project:
   ```bash
   cd /your/project
   bash /path/to/stackpilot/scripts/init.sh
   ```

3. Create a design spec, then commit it:
   ```bash
   mkdir -p docs/specs
   # Write your spec to docs/specs/YYYY-MM-DD-feature-name.md
   git add docs/specs/
   git commit -m "feat: add feature spec"
   # → PM Agent auto-decomposes into tasks/backlog.yml
   ```

4. Switch to a feature branch — Coordinator auto-starts:
   ```bash
   git checkout -b feat/my-feature
   # → Coordinator reads backlog, dispatches agents
   ```

## Restore on a new machine

```bash
# 1. Clone and restore Stackpilot agents + skills
git clone git@github.com:9aoyang/stackpilot.git ~/Documents/github/stackpilot
cd ~/Documents/github/stackpilot
bash scripts/restore.sh

# 2. Restore personal Claude config (CLAUDE.md, settings.json)
git clone git@github.com:9aoyang/dotfiles.git ~/Documents/github/dotfiles
cd ~/Documents/github/dotfiles
bash install.sh

# 3. Install gstack
git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack
```

## Keeping gstack up to date

Add to crontab (`crontab -e`):
```
0 3 * * 1  bash /path/to/stackpilot/scripts/update-gstack.sh
```

Or run manually inside Claude Code: `/update-gstack`

## Agent team

| Agent | Role | Tools |
|-------|------|-------|
| PM Agent | Decomposes specs into tasks/backlog.yml | Read, Write, Glob |
| Architect Agent | Reviews tech decisions, flags risks (read-only) | Read, Glob, Grep, WebSearch |
| Dev Agent | Implements features | Read, Edit, Write, Bash, Glob, Grep |
| QA Agent | Writes & runs tests | Read, Write, Bash, Glob, Grep |
| Docs Agent | Updates README and API docs | Read, Edit, Write, Glob |
| Coordinator | Orchestrates the sprint (headless claude -p) | Read, Write, Bash, Glob |

## Human escalation

Agents write to `tasks/NEEDS_REVIEW.md` when blocked. You'll get a macOS notification. Reply by appending:
```
REPLY: Option B
```
Then switch branches to re-trigger the Coordinator.

## Project config

`stackpilot.config.yml` in your project root:
```yaml
qa:
  coverage_threshold: 80
  test_command: npm test
coordinator:
  worktree_limit: 3
  timeout_hours: 2
```

## Repository structure

```
agents/          # Claude Code agent definitions (*.md) — copy to ~/.claude/agents/
skills/
  stackpilot/    # Slash-command skills for Claude Code — copy to ~/.claude/skills/stackpilot/
scripts/
  init.sh        # Initialize Stackpilot in a target project (installs git hooks)
  update-gstack.sh  # Pull latest gstack skill from GitHub
  hooks/
    post-commit.sh   # Triggers PM Agent when a spec is committed
    post-checkout.sh # Triggers Coordinator when switching to a feature branch
templates/
  backlog.yml         # Starter task backlog structure
  stackpilot.config.yml  # Default project config
  NEEDS_REVIEW.md     # Escalation file template
tests/
  test-init.sh    # Validates that init.sh wires up hooks correctly
  test-hooks.sh   # Validates hook trigger logic
  test-e2e.sh     # End-to-end structural check for the whole framework
docs/
  specs/          # Example and real feature specs
  superpowers/    # Implementation plans and planning documents
```
