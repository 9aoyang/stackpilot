# Development Report

## Files Changed

- `src/db/types.ts`: added v2 `LedgerEvent` schema with region, schema version, idempotency key, amount, currency, and sanitized payload.
- `src/db/client.ts`: added in-memory `ledgerEvents` store for regional ledger events.
- `src/ledger/events.ts`: added regional ledger event writer for invoice-paid and refund-created events plus sorted event listing.
- `src/billing/invoiceService.ts`: added write-mode gated ledger writes and read-mode gated ledger projection for invoice export/reconciliation callers.
- `src/billing/refundService.ts`: added write-mode gated refund ledger writes while preserving refund and invoice compatibility updates.
- `src/jobs/backfillLedger.ts`: replaced placeholder with cursor/batch backfill into the regional ledger writer.
- `tests/contract/cutover-contract.test.mjs`: added contract coverage for billing write cutover and ledger read projection.
- `.stackpilot-bench/architect.md`: recorded architecture decision and boundaries.

## Behavior Implemented

- `BILLING_LEDGER_WRITE_MODE=legacy` keeps existing invoice/refund table writes only.
- `BILLING_LEDGER_WRITE_MODE=dual` keeps legacy compatibility writes and shadow-writes regional v2 ledger events.
- `BILLING_LEDGER_WRITE_MODE=ledger` writes regional v2 ledger events and still updates current in-memory invoice/refund compatibility projections so existing APIs, exports, refunds, and reconciliation keep working during migration.
- `BILLING_LEDGER_READ_MODE=legacy` keeps export/reconciliation reading existing invoice records.
- `BILLING_LEDGER_READ_MODE=ledger` lets export/reconciliation read invoice-paid events from the regional ledger projection.
- Subscription API remains unchanged and does not read ledger events.
- Backfill now processes invoices in sorted cursor batches instead of full-table request-path scans.

## Assumptions

- This sandbox uses in-memory maps as the persistence layer, so regional ledger storage is represented by `db.ledgerEvents`.
- During migration, legacy invoice/refund maps are compatibility projections even in `ledger` write mode.
- Refund ledger events may use `accountId: "unknown"` if the related invoice is missing, preserving refund behavior rather than rejecting the request.
- The existing process-local idempotency helper is sufficient for the benchmark sandbox.

## Verification Commands Attempted

- `npm test`: passed after the backfill scoped fix.
- `npm run typecheck`: not completed because `tsc` is not installed in this sandbox (`sh: tsc: command not found`).
- `rg -n "writeLegacyLedger|legacyLedger" bench-sandbox/src bench-sandbox/tests`: no new call sites found; only the deprecated helper definition remains.
- `rg -n "customerEmail|paymentMethod|cardLast4|rawPayload|stripePayload" bench-sandbox/src/ledger/events.ts bench-sandbox/src/billing bench-sandbox/src/api`: sensitive fields remain only on the webhook input type, not in the ledger writer.

## Fix Loop Result

QA diff review found a cursor bug in `backfillLedger`: when `afterId` was greater than all invoice IDs, the job would restart from the first invoice. The scoped fix sets the start index to `orderedInvoices.length` when no later invoice exists. `npm test` passed after the fix.
