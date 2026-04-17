# Workload 03: cross-file-refactor

## Scenario

Rename `Stage 4 Consistency Audit` to `Stage 4 Cross-File Audit` everywhere in the synthetic codebase.

The primary definition lives in `fixtures/agents/sp-qa.md`. Four sibling files each contain at least one reference to the old stage name.

## Purpose

Tests sp-qa's ability to detect dead references after a rename — the most common regression class when editing stackpilot itself. A naive agent typically renames the primary file and forgets one or more sibling references, leaving the codebase inconsistent. The stackpilot pipeline's Stage 4 Consistency Audit (or its successor) must flag every stale reference.

## Fixture

Five synthetic files, all self-contained and not copies of real stackpilot agent/skill files:

| Path | Role |
|------|------|
| `fixtures/agents/sp-qa.md` | Primary definition — stage name appears in the methodology section |
| `fixtures/skills/stackpilot/SKILL.md` | Pipeline overview — mentions stage name in step description |
| `fixtures/references/12-qa-matrix.md` | QA coverage matrix — two table cells and a note reference the stage name |
| `fixtures/scripts/hooks/pre-merge-commit` | Shell hook — comment and grep check reference the stage name |
| `fixtures/docs/architecture.md` | ASCII diagram — stage name appears in the pipeline tree |

## Seeded Dead-Reference Traps

| ID | File | Nature |
|----|------|--------|
| trap-01-skill-md-stale | `skills/stackpilot/SKILL.md` | Stage name in pipeline description not updated |
| trap-02-12-qa-matrix-stale | `references/12-qa-matrix.md` | Table rows and trailing note still carry old name |
| trap-03-hook-comment-stale | `scripts/hooks/pre-merge-commit` | Comment block and grep pattern still reference old name |
| trap-04-arch-diagram-stale | `docs/architecture.md` | ASCII diagram leaf node still shows old stage name |

## How the Benchmark Uses This Workload

1. The runner resets all five fixture files into the worktree before each leg.
2. The leg's prompt (from `prompts.yml`) is dispatched to the agent under test.
3. The final diff is evaluated against:
   - `functional_assertions` — does the primary file actually rename the stage?
   - `traps.yml` `diff_bad_regex` — does the diff leave any sibling file with the old name?
   - `traps.yml` `qa_good_regex` (stackpilot leg only) — did sp-qa's report mention the stale reference?
