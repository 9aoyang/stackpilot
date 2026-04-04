# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Stackpilot, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please email **silence1amb@gmail.com** with:

1. A description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested fix (if any)

You will receive an acknowledgment within 48 hours, and we will work with you to understand and address the issue before any public disclosure.

## Security Considerations

Stackpilot executes Claude Code agents that can run shell commands via the `Bash` tool. Users should be aware that:

- Agent definitions in `claude-config/agents/` control what tools each agent can access
- The Coordinator dispatches agents with explicit `--allowedTools` restrictions
- Design specs committed to `docs/specs/` trigger automated agent execution via git hooks
- Review `stackpilot.config.yml` to configure timeouts and resource limits

Always review agent output and escalations in `tasks/NEEDS_REVIEW.md` before accepting changes.
