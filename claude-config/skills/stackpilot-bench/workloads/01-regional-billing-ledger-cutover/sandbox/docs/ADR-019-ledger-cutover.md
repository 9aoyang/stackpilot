# ADR-019: Billing ledger cutover

Accepted.

The ledger migration has three phases:

1. `legacy`: all reads and writes stay on legacy invoice/subscription/refund tables.
2. `dual`: legacy tables remain source of truth; ledger receives shadow writes for parity checks.
3. `ledger`: ledger becomes the write source after reconciliation passes for seven consecutive days.

Cutover is controlled by environment variables, not deployment branches:

- `BILLING_LEDGER_WRITE_MODE=legacy|dual|ledger`
- `BILLING_LEDGER_READ_MODE=legacy|ledger`

Default in production is `legacy`. Initial rollout uses `dual` writes and `legacy` reads.

Do not call the old `legacyLedger` helper. It predates regional sharding and omits idempotency keys.
