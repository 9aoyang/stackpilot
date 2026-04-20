# Regional billing service

This service owns subscriptions, invoices, refunds, Stripe webhooks, and finance exports.

Current production state:

- Source of truth: `invoices`, `subscriptions`, `refunds`.
- Regions: `us`, `eu`, `apac`; each writes to a regional primary DB.
- Money is stored as integer cents.
- Stripe webhooks are at-least-once and may arrive out of order.
- Finance exports still read legacy invoice rows.

Goal: introduce a regional billing ledger so finance can replay billing events by region and currency. The migration must be reversible because quarter-end close is in 9 days.

Important context is intentionally spread across this repo. Read `CLAUDE.md`, `docs/ADR-019-ledger-cutover.md`, `docs/ops-ledger-runbook.md`, current source, and contract tests before changing code.
