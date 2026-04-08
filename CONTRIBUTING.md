# Contributing to Stackpilot

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/9aoyang/stackpilot.git
   cd stackpilot
   ```

2. Install agents, skills, and all dependencies:
   ```bash
   bash scripts/restore.sh
   ```

## Running Tests

```bash
bash tests/test-init.sh
bash tests/test-hooks.sh
bash tests/test-e2e.sh
```

All tests must pass before submitting a PR.

## How to Contribute

### Reporting Bugs

Open an issue using the **Bug Report** template. Include:
- Steps to reproduce
- Expected vs actual behavior
- Your Claude Code version (`claude --version`)

### Suggesting Features

Open an issue using the **Feature Request** template.

### Submitting Changes

1. Fork the repo and create a branch from `main`:
   ```bash
   git checkout -b feat/your-feature
   ```

2. Make your changes. Follow existing code style:
   - Shell scripts: use `set -euo pipefail`, quote variables
   - Agent/skill Markdown: keep the YAML frontmatter format
   - Commit messages: use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)

3. Run the test suite and make sure everything passes.

4. Open a Pull Request against `main`. Fill out the PR template.

### Modifying Agents

Agent definitions live in `claude-config/agents/`. Each agent has:
- A YAML frontmatter block (name, tools, model)
- Markdown instructions

When changing agent behavior, update the corresponding test in `tests/` and document the change in your PR.

### Adding New Skills

Skills live in `claude-config/skills/`. Each skill gets its own directory with a `SKILL.md` file.

Two types of skills:
- **Orchestration skills** (Claude Code-specific): prefix with `stackpilot-` (e.g., `stackpilot-auto/SKILL.md`)
- **Portable methodology skills** (Agent Skills standard): use descriptive names without prefix (e.g., `tdd-development/SKILL.md`)

All `name` fields in frontmatter must follow the [Agent Skills spec](https://agentskills.io/specification): lowercase letters, numbers, and hyphens only. Must match the directory name.

Portable skills should include `license: Apache-2.0` and `metadata` fields. Keep SKILL.md under 500 lines; use `references/` for detailed content.

## Code Review

All submissions require review. We use GitHub pull requests for this purpose.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
