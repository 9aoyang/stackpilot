---
name: stackpilot-bootstrap
description: Use when starting any conversation. Establishes StackPilot automatic routing before work: feature work goes through the portable methodology core, bugs through systematic-debugging, implementation through TDD, and completion through fresh verification.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# Stackpilot Bootstrap

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a Stackpilot skill might apply to what
you are doing, you MUST invoke the relevant skill before acting.

Invoke relevant skills BEFORE any response or action, including clarifying
questions, file reads, shell commands, edits, commits, or completion claims.

For natural feature work, the first action must be activating
`stackpilot-methodology` (or the host's namespaced equivalent such as
`stackpilot:stackpilot-methodology`). Reading files, creating tasks, or saying
"I'll keep this lean" is not a substitute for activating the methodology.
</EXTREMELY-IMPORTANT>

## User-Facing Contract

StackPilot is the user entry. Do not make the user choose from a catalog of
internal process skills unless they explicitly ask for that level of control.
Use the routes below as default/on-demand gates behind StackPilot.

In Claude Code, `/stackpilot` is the primary visible entry and host adapter.
`stackpilot-methodology`, `stackpilot-planning`, `stackpilot-workspace`,
`stackpilot-plan-execution`, `stackpilot-parallel-agents`,
`stackpilot-review-response`, and `stackpilot-completion-verification` are
internal gates that may still need real Skill activation for the host to enforce
the workflow. Activating an internal gate is routing, not a separate product
experience.

## Instruction Priority

User instructions have highest priority. If an explicit user, AGENTS.md,
CLAUDE.md, or project instruction says to skip a workflow, avoid launching a
service, or let the user verify manually, follow that instruction.

General preferences for speed, quick iteration, concise responses, or avoiding
over-engineering are NOT opt-outs. They change how lightweight the methodology
should be; they do not permit skipping the route. Only explicit instructions
such as "skip planning", "do not use StackPilot", "just answer", or "I'll verify
myself" override the corresponding gate.

Priority order:

1. User instructions and project instructions — highest priority
2. Stackpilot bootstrap routing
3. Default assistant behavior

## Routing Rules

Use these routes unless the user explicitly opts out. Route internally; do not
ask the user to pick one.

- Feature work, building, modifying behavior, multi-file changes, or ambiguous
  product requests → route through StackPilot's methodology gate
  (`/stackpilot-methodology`) before implementation.
- Existing spec/plan execution, "continue plan", "run the plan", or
  task-by-task implementation → route through `/stackpilot-plan-execution`.
- Existing spec/design/clear requirements that need an implementation plan
  before code → route through `/stackpilot-planning`.
- Two or more independent tasks, failures, review domains, or research targets
  that can run concurrently → route through `/stackpilot-parallel-agents`.
- Starting implementation in a branch/worktree, or executing a non-trivial plan
  → route through `/stackpilot-workspace` unless the host adapter already provides
  managed isolation or the user explicitly chose in-place work.
- In Claude Code, `/stackpilot` is the primary visible entry. If the user has
  not explicitly started it, activate `stackpilot:stackpilot-methodology` as the
  internal methodology gate through the Skill tool. In hosts without a Skill
  tool, use the host-native skill activation mechanism. Do not replace this with
  TaskCreate, TodoWrite, file reads, or shell commands.
- When the Claude Code adapter is available and the work benefits from an
  autonomous sprint, `/stackpilot` may run the host adapter for the execution
  phase. Treat `/stackpilot` as a host adapter, not the whole methodology.
- Bug, test failure, build failure, unexpected behavior, or broken integration
  → invoke `/systematic-debugging` before proposing fixes.
- Any production code change → invoke `/tdd-development` before writing code.
- Code review, QA, or test coverage work → invoke `/qa-12-dimensions`.
- Receiving human/external code review feedback → invoke
  `/stackpilot-review-response` before accepting or implementing suggestions.
- Adding, updating, or reviewing StackPilot skills → invoke
  `/stackpilot-skill-authoring`.
- Architecture decisions, shared data structures, or multi-file feature design
  → invoke `/architecture-review`.
- Before saying work is complete, fixed, passing, ready to merge, or ready for
  PR → invoke `/stackpilot-completion-verification`, run fresh verification, and
  cite the command evidence.

## Red Flags

Stop and route through the proper skill if you catch yourself thinking:

| Thought | Correct action |
|---------|----------------|
| "This is simple; I can just edit it." | Use `/stackpilot-methodology` or `/tdd-development` first. |
| "The user likes quick iteration." | Run the lightweight path; do not skip skill activation. |
| "I need to inspect files before deciding." | Skill routing happens before inspection. |
| "The user did not type `/stackpilot`." | Automatic StackPilot methodology routing exists for non-trivial feature work. |
| "I can create tasks first." | TaskCreate/TodoWrite happens after methodology activation. |
| "The reviewer is probably right." | Use `/stackpilot-review-response`; verify technically first. |
| "These failures are independent; I'll handle them one by one." | Use `/stackpilot-parallel-agents` if they can safely run concurrently. |
| "The agent/subagent said it passed." | Verify independently before advancing state. |
| "I can claim done now." | Use `/stackpilot-completion-verification` and run the proving command first. |

## If Unsure

When in doubt, invoke the smallest process skill that fits. If it turns out not
to apply, say that briefly and proceed with the right route. Do not silently
skip the check.
