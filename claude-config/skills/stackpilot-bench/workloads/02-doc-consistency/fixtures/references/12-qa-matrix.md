# QA Matrix — Reference Checklist

Use this checklist during Stage 4 Consistency Audit to verify that a
structural change has been propagated correctly across the repository.

## General Cross-File Checks

- [ ] All files that mention the changed entity were identified via grep.
- [ ] Each identified file was either updated or explicitly reviewed and
      deemed correct as-is.
- [ ] No stale copy-paste blocks remain from the prior state.

## Design Decision Checks

- [ ] Review: does the dev agent respect worktree isolation?
      Each task must operate in `.worktrees/<task-id>/`, not in main.
- [ ] Confirm: `docs/architecture.md` Key Design Decisions section
      matches the current runtime behavior.
- [ ] Confirm: `README.md` isolation model description is consistent
      with `docs/architecture.md`.

## Agent File Checks

- [ ] `agents/sp-qa.md` Stage 4 example still refers to a valid,
      current design decision (not a superseded one).
- [ ] Any inline examples in agent files use current terminology.

## Release Checks

- [ ] CHANGELOG entry drafted for any design-decision change.
- [ ] VERSION file bumped if the change is user-visible.
