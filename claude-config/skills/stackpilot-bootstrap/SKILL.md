---
name: stackpilot-bootstrap
description: Use when starting any conversation. Establishes automatic routing before work - requiring skill invocation before ANY response including clarifying questions.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "2.0.0"
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a Stackpilot skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill before acting.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first (in StackPilot: `stackpilot-methodology`).

## Routing Rules

Use these routes unless the user explicitly opts out. Route internally; do not ask the user to pick one.

- Feature work, building, modifying behavior, multi-file changes → `stackpilot-methodology`
- Existing spec/plan execution, "continue plan" → `stackpilot-plan-execution`
- Spec/design that needs an implementation plan → `stackpilot-planning`
- Two or more independent tasks running concurrently → `stackpilot-parallel-agents`
- Bug, test failure, unexpected behavior → `systematic-debugging`
- Any production code change → `tdd-development`
- Code review, QA, or test coverage work → `qa-12-dimensions`
- Before saying work is complete, ready to merge/PR → `stackpilot-completion-verification`

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Correct Action |
|---------|----------------|
| "This is just a simple question/edit" | Use `stackpilot-methodology` or `tdd-development` first. |
| "I need more context / let me check files first" | Skill check and routing comes BEFORE file reads or clarifying questions. |
| "I can check git/files quickly" | Route first. Skills tell you HOW to explore and gather context. |
| "The user did not type /stackpilot" | Automatic StackPilot methodology routing exists for non-trivial feature work. |
| "I remember this skill" | Skills evolve. Read current version. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "I can claim done now" | Use `stackpilot-completion-verification` and run proving commands first. |

## Platform Adaptation

When running under different platforms, translate abstract instructions into platform-native tools:
- Claude Code: use `Task` for subagent dispatch, track checklist tasks via native UI.
- Codex: use `spawn_agent`/`wait_agent` for subagents (requires `multi_agent = true` in config).
- Cursor / Gemini (Antigravity): use `invoke_subagent` for subagents, track task progress via a Markdown task artifact.

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, direct requests) take precedence over skills. Only skip skill workflows when your human partner has explicitly told you to.
