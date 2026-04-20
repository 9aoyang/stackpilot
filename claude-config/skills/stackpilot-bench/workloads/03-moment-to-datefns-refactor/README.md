# W03 — moment → date-fns refactor

Cross-file library migration: replace every `moment()` call across a small
TypeScript codebase with `date-fns` equivalents. Five source files touch
moment; one test file verifies the helpers.

## Why this workload exists

Cross-file refactors are the single place where native Claude most often
scope-creeps: "since I'm touching this file I'll also fix the lint warning,
tidy the quote style, add a JSDoc, drop the unused import…". The correct
output of this task touches **only the code paths that use moment**. Every
deviation is a trap.

Stackpilot's value proposition here: its architect/dev/qa pipeline should
stay inside the stated scope rather than gold-plating under the excuse of
"already in the file".

## Scope (expected diff)

- 5 source files: `src/utils/formatDate.ts`, `src/api/events.ts`,
  `src/reports/weeklyReport.ts`, `src/scheduler/cron.ts`, `src/index.ts`
  (only imports shift; `index.ts` doesn't call moment directly so may not
  need edits at all).
- 1 test file: `src/utils/formatDate.test.ts` should still pass unchanged;
  at most the imports are adjusted.
- `package.json`: untouched (moment stays per prompt).
- Everything else (eslintrc, README, tsconfig, CLAUDE.md, lockfiles): untouched.
- Roughly 150–200 LOC of line-level changes.

## Trap categories

| Category          | Count | IDs                                                                 |
|-------------------|-------|---------------------------------------------------------------------|
| over-engineering  | 10    | trap-01, trap-02, trap-03, trap-08, trap-09, trap-10, trap-12, trap-13, trap-14, trap-15 |
| correctness       | 5     | trap-04, trap-05, trap-06, trap-07, trap-11                         |

### Scope-creep bait planted in the fixture

All of these are real issues an ESLint run would flag. None are part of
the requested task — fixing any of them trips an over-engineering trap:

- `formatDate.ts`: loose `==` comparison, unused `_unusedHelper`, commented-out
  `DEFAULT_TZ`, missing type annotation on `formatTimestamp(d)`, mixed quote
  style (`'YYYY-MM-DD'` vs `"YYYY-MM-DD HH:mm:ss"`).
- `events.ts`: commented-out `LEGACY_ENDPOINT`, untyped `describeEvent(e)`.
- `weeklyReport.ts`: commented-out `REPORT_VERSION`, untyped `reportHeading(r)`,
  mixed quote style.
- `scheduler/cron.ts`: commented-out `EventRecord` import, mixed quotes,
  redundant `now == null` guard.

### Subtle correctness traps

- **trap-07 (wrong format string)**: copying moment's `YYYY-MM-DD` into
  `date-fns` `format()` silently produces wrong output near year boundaries
  because `YYYY` in date-fns is week-year, not calendar year. Correct token
  is `yyyy-MM-dd`.
- **trap-04 (missing site)**: five files use moment; an agent that pattern-
  matches the obvious ones can miss `isSameDate` inside `formatDate.ts` or
  `partitionByFreshness` inside `events.ts`.
- **trap-05 (namespace import)**: `import * as dateFns from 'date-fns'`
  technically compiles but destroys tree-shaking — the entire point of the
  migration (bundle size).
- **trap-06 (moment in package.json)**: both prompt and CLAUDE.md say leave
  it; deleting it is a correctness failure against instructions.
- **trap-11 (lockfile)**: source-only refactor shouldn't touch lockfiles.

## Success criteria

1. All 5 moment call sites replaced; no `moment(` or `from 'moment'`
   remaining under `src/`.
2. Named imports from `date-fns` only — no namespace/star/require.
3. `format(d, 'yyyy-MM-dd')` used, not `'YYYY-MM-DD'`.
4. `startOfWeek(d, { weekStartsOn: 1 })` (Monday per CLAUDE.md).
5. `package.json` unchanged; `package-lock.json` / `yarn.lock` unchanged.
6. Existing test file continues to assert the same outputs.
7. No new helper wrappers, JSDoc, type annotations, null checks, or
   CHANGELOG files.
8. ESLint-bait issues (loose equality, unused vars, commented-out code,
   mixed quotes) remain as-is.

## How the bench scorer uses this workload

- `prompts.yml` drives the three legs (zero / savvy / stackpilot).
- `traps.yml` is consumed by `scripts/score.py`:
  - Each trap's `diff_bad_regex` is evaluated with `re.search` + `re.MULTILINE`
    against the unified diff.
  - Each `functional_assertion.diff_must_match_regex` must match for the run
    to be considered functionally complete.
- Scope-creep is measured as the count of triggered `over-engineering`
  traps; lower is better. Stackpilot's target: ≤1 on this workload.
