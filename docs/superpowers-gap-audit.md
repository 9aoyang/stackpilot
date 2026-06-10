# StackPilot vs Superpowers Workflow Gap Audit

> Last updated: 2026-06-10

This is a coverage audit, not a cloning target. It maps Superpowers' public
workflow skills to the StackPilot gate or adapter that covers the same
product-level behavior. StackPilot intentionally keeps one normal user entry:
users start with StackPilot, while bootstrap, hooks, and host adapters trigger
the internal gates automatically or on demand.

Do not infer "one Superpowers skill means one StackPilot public skill." Add a
new public entry only when it creates a distinct StackPilot user experience;
otherwise keep the behavior inside the StackPilot route.

| Superpowers workflow skill | StackPilot owner | StackPilot exposure | Status |
|----------------------------|------------------|---------------------|--------|
| `using-superpowers` | `stackpilot-bootstrap`, `hooks/session-start`, `hooks/pre-tool-use` | Bootstrap/default routing | Covered with prompt routing plus mechanical PreToolUse enforcement |
| `brainstorming` | `stackpilot-methodology`, `/stackpilot` Nodes 1-3 | Default internal gate | Covered by explore/design/spec/criteria gates |
| `writing-plans` | `stackpilot-planning`, `/stackpilot` Node 4 plan generation | Default internal gate | Covered by exact task plans, traceability, fully resolved task descriptions |
| `using-git-worktrees` | `stackpilot-workspace`, `/stackpilot` Claude Code worktree adapter | Default internal gate / adapter mechanic | Covered by isolation/setup/baseline workflow |
| `executing-plans` | `stackpilot-plan-execution`, `/stackpilot` Run Sprint | Default internal gate | Covered by task execution gates |
| `subagent-driven-development` | `stackpilot-plan-execution`, `stackpilot-parallel-agents`, `/stackpilot` Run Sprint | Default internal gates / adapter mechanic | Covered by scoped workers, spec review before quality review, controller verification |
| `dispatching-parallel-agents` | `stackpilot-parallel-agents`, `/stackpilot` dependency waves | Default internal gate | Covered by independent-domain dispatch and integration verification |
| `test-driven-development` | `tdd-development`, `sp-dev` | Default internal gate / agent contract | Covered by RED/GREEN/REFACTOR and rationalization blockers |
| `systematic-debugging` | `systematic-debugging` | Default internal gate | Covered by 4-phase root cause investigation |
| `requesting-code-review` | `qa-12-dimensions`, `sp-qa`, `/stackpilot` QA stage | Default internal gate / agent contract | Covered by spec compliance, quality review, confidence threshold, deterministic audits |
| `receiving-code-review` | `stackpilot-review-response` | Default internal gate | Covered by feedback parsing, technical verification, scoped fixes |
| `verification-before-completion` | `stackpilot-completion-verification`, `/stackpilot` Sprint Finish | Default internal gate | Covered by fresh evidence before claims |
| `finishing-a-development-branch` | `stackpilot-completion-verification`, `references/sprint-finish.md` | Default internal gate / adapter finish protocol | Covered by verification before merge/PR/keep/discard choices |
| `writing-skills` | `stackpilot-skill-authoring`, `stackpilot-sync` | Maintainer-only gate | Covered by trigger/routing/docs/tests gates for skill changes |

## Remaining Boundary

The full autonomous sprint adapter is still Claude Code-specific. Other hosts
receive the portable StackPilot gates and package metadata, but each host still
needs its own full adapter if it should match Claude Code's native
agent/worktree/task/event-log mechanics. The target experience remains one
StackPilot entry with default/on-demand routing behind it.
