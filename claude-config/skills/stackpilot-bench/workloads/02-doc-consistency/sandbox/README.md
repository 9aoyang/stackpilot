# Stackpilot

Stackpilot is a Claude Code skill that turns a one-line user request into a
fully reviewed, committed change via a five-agent pipeline.

## How It Works

1. Run `/stackpilot` in any initialized project.
2. Describe the change you want.
3. The pipeline (Spec → Plan → Architect → Dev → QA) executes autonomously.

## Isolation Model

Stackpilot uses worktree isolation — each dev task runs in its own git worktree.
Tasks never touch each other's working tree, so concurrent sprints stay safe.

## Quick Start

```bash
bash scripts/install.sh
cd your-project
/stackpilot
```

## Requirements

- Claude Code with at least one `sp-*` agent registered.
- A git repository.
- `stackpilot.config.yml` in the project root (created by install).

## Further Reading

- `docs/architecture.md` — full design documentation
- `claude-config/skills/stackpilot/SKILL.md` — runtime instructions
- `agents/sp-qa.md` — quality audit methodology
