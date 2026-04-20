import assert from "node:assert/strict";
import test from "node:test";
import { exists, read } from "../helpers/read-file.mjs";

test("billing writes route through regional ledger modes without deleting legacy compatibility writes", () => {
  assert.equal(exists("src/ledger/events.ts"), true, "regional ledger writer must exist");
  const source = [
    read("src/billing/invoiceService.ts"),
    read("src/billing/refundService.ts"),
    read("src/ledger/events.ts"),
  ].join("\n");

  assert.match(source, /getLedgerWriteMode|BILLING_LEDGER_WRITE_MODE/);
  assert.match(source, /db\.invoices\.set/);
  assert.match(source, /db\.refunds\.set/);
  assert.match(source, /invoice\.paid|writeInvoice|writeLedger/);
  assert.match(source, /refund\.created|writeRefund|writeLedger/);
  assert.match(source, /idempotencyKey|dedupeKey/);
});
