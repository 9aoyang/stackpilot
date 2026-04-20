# Architecture Decision

Move billing write-side ledger entries to a regional v2 ledger event writer while preserving existing legacy tables as the compatibility surface during migration.

## Decision

Introduce `src/ledger/events.ts` as the only new ledger write API. Billing write paths call this writer according to `BILLING_LEDGER_WRITE_MODE`:

- `legacy`: keep current invoice/refund table writes only.
- `dual`: keep legacy writes as source of truth and shadow-write regional ledger events.
- `ledger`: write regional ledger events as the ledger source while still updating existing in-memory invoice/refund tables as compatibility projections for subscription, webhook, refund, invoice export, and reconciliation behavior in this sandbox.

Use `BILLING_LEDGER_READ_MODE` only for read-side selection in invoice export and reconciliation. Default remains `legacy`, matching ADR-019 rollback behavior.

## Rejected Alternatives

- Reuse `legacyLedger.writeLegacyLedger`: rejected because ADR-019 explicitly forbids it and the helper has no region, schema version, or idempotency key.
- Replace invoice/refund tables immediately: rejected because existing API/export/reconciliation behavior must keep working during migration.
- Route subscription responses through ledger events: rejected because subscription API contract tests require no ledger/journal coupling.

## Risks

- Ledger-mode compatibility projections can mask missing downstream consumers; acceptable here because the request explicitly requires existing behavior during migration.
- Event payloads may grow to include unsafe provider fields; writer should whitelist sanitized payload fields only.
- In-memory idempotency is process-local in the sandbox and not a production dedupe store.

## Implementation Boundary

Allowed changes are limited to `bench-sandbox/`. The implementation may touch billing services, ledger modules, database types/client, API/job readers, and contract tests. It must not rewrite unrelated subscription behavior or introduce external dependencies.
