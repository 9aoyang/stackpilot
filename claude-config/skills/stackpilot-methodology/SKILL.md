---
name: stackpilot-methodology
description: Internal/default StackPilot gate for feature work in any agent host. Trigger behind the StackPilot entry before implementation to drive exploration, design, spec, criteria, plan, execution, verification, and finish through host-native tools or adapters.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Methodology Core

StackPilot is a host-neutral method for turning a request into verified
software. The method is portable; each host provides its own adapter for tools
such as subagents, worktrees, browser checks, tasks, or pull requests.

## Adapter Rule

Use the best available host adapter:

- Claude Code with the StackPilot adapter available → `/stackpilot` may run the
  full autonomous sprint implementation after this methodology has routed the
  work.
- Other Agent Skills hosts → follow this methodology using host-native tools
  for planning, edits, tests, review, and finish.
- No adapter support → run the same gates manually in the current session.

Do not weaken the methodology because an adapter is missing. Degrade the
mechanics, not the gates.

## Core Pipeline

1. **Explore** — inspect project context before asking questions. Read project
   instructions, search relevant code, and identify canonical refs. Ask one
   question at a time, each with a recommended answer; answer from code instead
   of asking when evidence is available.
2. **Design** — present one recommended approach, plus rejected alternatives
   when the trade-off is real. Use 2-3 selectable options only when comparison,
   visual design, interaction, or topology materially reduces ambiguity. Get
   approval before implementation.
3. **Spec & Criteria** — write a concise spec and 3-7 mechanically verifiable
   acceptance criteria. Criteria must use commands or observable evidence.
4. **Plan** — use `stackpilot-planning` to break the work into task-sized steps
   with exact files, dependencies, verification commands, and scope boundaries.
5. **Execute** — use `stackpilot-workspace` for isolation/setup/baseline when
   needed, then `stackpilot-plan-execution` or the host adapter to execute tasks
   with TDD and review gates. Use `stackpilot-parallel-agents` for independent
   domains that can safely run concurrently.
6. **Review** — verify spec compliance first, then implementation quality. Do
   not trust implementer self-reports; inspect evidence. Use
   `stackpilot-review-response` for incoming human or external review feedback.
7. **Finish** — use `stackpilot-completion-verification`, check acceptance
   criteria, surface open feedback, write a sprint eval summary when artifacts
   exist, present merge / PR / keep / discard choices, and record any reusable
   lessons.

## Hard Gates

- No implementation before design approval unless the user explicitly opts out.
- No production code before a failing test, except pure config/docs changes with
  a stated reason.
- No acceptance criterion based on "looks right" or "feels fast"; make it
  command-runnable or observable.
- No phase advancement from agent success reports alone. Require diff, command,
  criteria, or browser evidence.
- No completion claim without fresh verification in the current turn.
- No destructive/external side effect without explicit user confirmation.
- No plan execution in a dirty/shared workspace until isolation or an explicit
  in-place decision is recorded.

## Output Contract

When you use this skill without a richer adapter, keep a compact data layer:

```markdown
# Spec — <feature>
## Goal
## Scope
## Design
## Acceptance Criteria
## Canonical Refs
## Domain Language

# Plan — <feature>
## Tasks
### TASK-001 — <title>
- files:
- depends_on:
- verify:
- scope:
```

When an adapter provides stronger artifacts, such as `.stackpilot/specs`,
`.stackpilot/plans`, `handoff.json`, `state.json`, `events.jsonl`,
`sprint-evals.md`, `.stackpilot/feedback/open|resolved`, dashboards, or browser
evidence, use those artifacts as the source of truth.

For host-neutral runs without the full adapter, preserve the same data-layer
concepts in compact form: a handoff note for the next action, a feedback inbox
for unresolved external audit items, and a short eval summary before claiming
the sprint is finished.

## Red Flags

Stop and restore the methodology if you notice:

- You are editing code before writing a spec or plan.
- A plan task lacks exact files or a verification command.
- A reviewer says "looks good" without file/line evidence.
- A task is marked complete but criteria remain `untested`.
- A host limitation is being used as a reason to skip the gate instead of
  running a manual equivalent.
