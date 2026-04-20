# Ledger migration runbook

Preflight:

- Enable `BILLING_LEDGER_WRITE_MODE=dual` for one region at a time.
- Keep `BILLING_LEDGER_READ_MODE=legacy` until parity checks are green.
- Run backfill in batches of 500 invoices using a stable cursor.
- Compare legacy invoice totals to ledger totals by `{region, currency, day}`.

Rollback:

- Set `BILLING_LEDGER_WRITE_MODE=legacy`.
- Keep `BILLING_LEDGER_READ_MODE=legacy`.
- Do not delete ledger rows; they are diagnostic artifacts.

Failure modes:

- Missing idempotency key causes duplicate Stripe events to inflate revenue.
- Raw Stripe payloads contain billing email and payment method details.
- Table-wide invoice scans block checkout during month end.
