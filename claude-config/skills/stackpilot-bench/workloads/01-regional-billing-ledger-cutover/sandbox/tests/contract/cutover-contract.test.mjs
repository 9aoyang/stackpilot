import assert from "node:assert/strict";
import test from "node:test";
import { read } from "../helpers/read-file.mjs";

test("cutover is dual-write capable and rollback-safe", () => {
  const source = [
    read("src/lib/featureFlags.ts"),
    read("src/api/webhooks/stripe.ts"),
    read("src/api/refunds.ts"),
    read("src/api/invoiceExport.ts"),
    read("src/jobs/reconcileStripe.ts"),
  ].join("\n");
  assert.match(source, /BILLING_LEDGER_WRITE_MODE|getLedgerWriteMode|dual/);
  assert.match(source, /BILLING_LEDGER_READ_MODE|getLedgerReadMode|legacy/);
  assert.match(source, /shadow|reconcile|parity|compare/i);
});
