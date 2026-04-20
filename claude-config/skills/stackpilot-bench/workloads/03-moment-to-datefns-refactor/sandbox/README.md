# sandbox

Small internal service that does event rollups, weekly reports, and a
scheduled cron ping. Currently uses `moment` for all date handling.

## Task

Migrating date handling from `moment` to `date-fns` for bundle size reasons.
Keep behaviour identical. Another task will remove `moment` from
`package.json` once every consumer has been migrated, so leave that entry
alone for now.

## Layout

- `src/utils/formatDate.ts` — shared date helpers
- `src/api/events.ts` — event listing / cutoff filter
- `src/reports/weeklyReport.ts` — weekly rollup report
- `src/scheduler/cron.ts` — cron tick computation
- `src/index.ts` — entry point
- `src/utils/formatDate.test.ts` — jest tests for the helpers
