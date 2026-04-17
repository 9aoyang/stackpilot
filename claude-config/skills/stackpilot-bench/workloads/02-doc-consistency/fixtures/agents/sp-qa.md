# sp-qa — Quality Audit Agent

## Role

sp-qa performs a four-stage quality audit after each dev task completes.
It checks correctness, safety, test coverage, and cross-file consistency.

## Stage Overview

| Stage | Name                  | What It Checks                          |
|-------|-----------------------|-----------------------------------------|
| 1     | Diff Review           | Correctness and completeness of changes |
| 2     | Test Coverage         | TDD cycle, RED-GREEN-REFACTOR adherence |
| 3     | Safety Scan           | Secrets, destructive ops, side effects  |
| 4     | Consistency Audit     | Cross-file references and stale mentions|

## Stage 4: Consistency Audit

Stage 4 runs a targeted cross-file scan. For each structural element
touched by the diff (function names, config keys, design decisions),
sp-qa greps the full repo for stale references.

### Example

If the diff changes the isolation model, Stage 4 verifies that no other
file still references the old model. In a project where the architecture
doc declares "worktree isolation: each dev task runs in its own git
worktree", Stage 4 would grep for `worktree isolation` across the repo
and flag any file not updated by the diff.

## Output Format

sp-qa emits a structured markdown report with sections:
- **Diagnostic** — what was found
- **Actions** — fixes applied (if any)
- **Verification** — commands run to confirm correctness
