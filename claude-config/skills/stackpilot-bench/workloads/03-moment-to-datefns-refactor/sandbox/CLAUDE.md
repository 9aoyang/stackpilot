# Conventions

- Date handling: use `date-fns` going forward. The project is migrating off
  `moment` for bundle size reasons.
- Weeks are Monday-based (ISO week).
- Tests: jest, co-located `*.test.ts` next to the source.
- Quote style is single quotes in most files but not enforced in every file yet.
- Don't fix unrelated lint warnings in a refactor PR. Keep the diff scoped to
  the stated task.
- `package.json` entries for `moment` stay until the coordinated removal PR.
