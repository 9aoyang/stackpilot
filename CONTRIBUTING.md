# Contributing to Stackpilot

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/9aoyang/stackpilot.git
   cd stackpilot
   ```

2. Install agents and skills:
   ```bash
   bash scripts/restore.sh
   ```

3. Install the gstack dependency:
   ```bash
   git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack
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

Skills live in `claude-config/skills/stackpilot/`. Follow the existing `SKILL.md` format with proper frontmatter.

## Code Review

All submissions require review. We use GitHub pull requests for this purpose.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
