# Workload 02: doc-consistency

## Scenario

Update a Key Design Decision in `docs/architecture.md` from:

> **Worktree isolation**: each dev task runs in its own git worktree.

to:

> **Workspace pools**: dev tasks draw from a shared pool of prepared workspaces.

Keep all downstream references consistent with the new decision.

## Purpose

Tests sp-qa's Stage 4 cross-file consistency audit. A design-decision
change in the canonical architecture doc must propagate to every file
that describes or references that decision. Failing to catch stale
references is a frequent regression when editing stackpilot's own docs.

## Fixture Layout

```
fixtures/
├── docs/architecture.md        # canonical source — contains the decision (CHANGE THIS)
├── README.md                   # mentions the decision in passing (must be updated)
├── agents/sp-qa.md             # inline example references the old decision (must be updated)
├── CHANGELOG.md                # historical entry that is now misleading (judgment call)
└── references/12-qa-matrix.md  # checklist item uses old phrasing (must be updated)
```

## Seeded Traps

| ID | Severity | Short Description |
|----|----------|-------------------|
| trap-01-readme-stale | high | `README.md` still describes "worktree isolation" after the decision changed. |
| trap-02-agent-file-contradiction | high | `agents/sp-qa.md` inline example still references the old decision phrasing, contradicting the new architecture. |
| trap-03-reference-duplicate | medium | `references/12-qa-matrix.md` checklist item uses the old decision wording. |
| trap-04-changelog-misleading | medium | `CHANGELOG.md` 1.0 entry positions worktree isolation as the current model, not as a superseded historical decision. |

## How the Benchmark Uses This Workload

1. The runner copies `fixtures/` into the worktree before each leg.
2. The leg's prompt (from `prompts.yml`) instructs the agent to change the design decision.
3. The final diff is evaluated against:
   - `functional_assertions` — did `docs/architecture.md` actually change?
   - `traps.yml` `diff_bad_regex` — did the agent leave stale references behind?
   - `traps.yml` `qa_good_regex` (stackpilot leg only) — did sp-qa flag the inconsistencies?

## Notes on trap-04-changelog-misleading

The CHANGELOG entry is *historically accurate* — worktree isolation was indeed
introduced in 1.0. The trap tests whether the agent (or sp-qa) handles this
nuance correctly:

- **Correct behavior**: add a note that the 1.0 decision has since been superseded,
  or leave the historical entry as-is with a clear framing that it is historical.
- **Bad behavior**: delete the CHANGELOG entry (destroys history) or leave it
  with no indication it is no longer current, causing readers to infer the old
  decision is still active.

The `diff_bad_regex` for this trap targets the deletion-of-history case.
The `qa_good_regex` targets sp-qa recognising the misleading framing.
