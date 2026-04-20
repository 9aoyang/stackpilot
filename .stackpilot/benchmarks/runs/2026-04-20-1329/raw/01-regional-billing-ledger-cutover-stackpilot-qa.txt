# QA Report

## Verdict

PASS. Final diff supports regional ledger writes while preserving existing subscription, webhook, refund, invoice export, and reconciliation behavior during migration.

## Final Diff Inspection

- Reviewed modified files under `bench-sandbox/src/billing`, `bench-sandbox/src/db`, `bench-sandbox/src/jobs`, `bench-sandbox/tests/contract`, and new `bench-sandbox/src/ledger/events.ts`.
- Confirmed invoice and refund write paths use `getLedgerWriteMode()` and preserve `db.invoices.set` / `db.refunds.set` compatibility writes.
- Confirmed invoice export and reconciliation continue using `listInvoicesForExport()`, with default legacy reads and optional ledger projection under `BILLING_LEDGER_READ_MODE=ledger`.
- Confirmed subscription API files were not changed and contract test still rejects ledger coupling.
- Confirmed no new call sites use deprecated `writeLegacyLedger`.
- Confirmed ledger writer uses v2 schema, region, idempotency key, currency, amount, and whitelisted `safePayload` fields.

## Findings

- [FIXED] `src/jobs/backfillLedger.ts`: initial implementation used `Math.max(-1, 0)` when `afterId` had no later invoice, causing the backfill to restart from the beginning. Fixed by treating `findIndex === -1` as the end of the ordered invoice list.
- [LOW] `npm run typecheck` cannot run because the sandbox does not have `tsc` installed. Runtime contract tests are passing.

## Exact Commands Run

- `npm test`
- `npm run typecheck`
- `git diff -- bench-sandbox`
- `git diff --stat -- bench-sandbox && git diff -- bench-sandbox/src/ledger/events.ts bench-sandbox/src/jobs/backfillLedger.ts`
- `git status --porcelain -- bench-sandbox`
- `rg -n "writeLegacyLedger|legacyLedger" bench-sandbox/src bench-sandbox/tests`
- `rg -n "customerEmail|paymentMethod|cardLast4|rawPayload|stripePayload" bench-sandbox/src/ledger/events.ts bench-sandbox/src/billing bench-sandbox/src/api`

## Fixes Required

One scoped fix loop was required for the backfill cursor issue. No critical issues remain after the fix.
