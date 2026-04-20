import assert from "node:assert/strict";
import test from "node:test";
import { read } from "../helpers/read-file.mjs";

test("cutover keeps explicit write and read rollback controls", () => {
  const source = [
    read("src/lib/featureFlags.ts"),
    read("src/billing/invoiceService.ts"),
    read("src/billing/refundService.ts"),
    read("src/api/invoiceExport.ts"),
    read("src/jobs/reconcileStripe.ts"),
  ].join("\n");

  assert.match(source, /BILLING_LEDGER_WRITE_MODE|getLedgerWriteMode/);
  assert.match(source, /\bdual\b/);
  assert.match(source, /\bledger\b/);
  assert.match(source, /BILLING_LEDGER_READ_MODE|getLedgerReadMode/);
  assert.match(source, /\blegacy\b/);
});
