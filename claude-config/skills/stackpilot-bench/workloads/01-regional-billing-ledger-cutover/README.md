# Regional Billing Ledger Cutover

This is the single high-discrimination Codex workload for `/stackpilot-bench`.

The task intentionally resembles a real `/stackpilot` sprint:

- Cross-system billing change touching webhooks, refunds, exports, reconciliation, and subscription APIs.
- Hidden constraints distributed across `CLAUDE.md`, docs, existing tests, and source comments.
- Multiple tempting wrong paths: using the deprecated ledger shim, changing API response shape, one-shot cutover, logging PII, and writing a table-locking backfill.
- Scoring compares only `zero` and `stackpilot`; `savvy` is intentionally removed.

The target behavior is not "more files". It is "native zero can produce a plausible diff but is likely to miss at least one load-bearing invariant unless it reads deeply and self-reviews".
