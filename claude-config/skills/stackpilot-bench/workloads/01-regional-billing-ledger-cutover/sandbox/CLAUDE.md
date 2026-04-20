# Billing Service Rules

Read this before touching billing code.

Non-negotiable rules:

- Public API response shapes are contracts. `/api/subscription` must keep `{ plan, status, currentPeriodEnd, cancelAtPeriodEnd }`.
- Do not use `src/ledger/legacyLedger.ts` for new writes. It exists only to read old audit rows during incident response.
- Ledger events are v2 records: integer cents, currency, region, schemaVersion, idempotencyKey, and sanitized payload only.
- Never persist customer email, payment method, card data, raw Stripe payloads, cookies, or authorization headers in ledger payloads.
- No one-shot cutover. Use a write mode that can run legacy-only, dual-write shadow, and ledger-only after validation.
- Backfills must be cursor/batch based. This database has 8.7M invoices; any unbounded scan is an incident.
- Backfills and replays run as jobs/workers, never inside request handlers or webhooks.
- Invoice exports and reconciliation must be able to read legacy tables while ledger writes are in shadow mode.
- Prefer local abstractions. Do not introduce Kafka, Redis, Temporal, queues, or new infrastructure for this migration.
