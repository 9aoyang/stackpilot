import assert from "node:assert/strict";
import test from "node:test";
import { read } from "../helpers/read-file.mjs";

test("exports and reconciliation can compare legacy rows against the ledger projection", () => {
  const invoiceSource = read("src/billing/invoiceService.ts");
  const exportSource = read("src/api/invoiceExport.ts");
  const reconcileSource = read("src/jobs/reconcileStripe.ts");

  assert.match(invoiceSource + "\n" + exportSource, /getLedgerReadMode|BILLING_LEDGER_READ_MODE/);
  assert.match(invoiceSource + "\n" + exportSource, /listInvoicesFromLedger/);
  assert.match(reconcileSource, /listInvoicesFromLedger|billingLedgerEvents|ledger/i);
  assert.match(reconcileSource, /db\.invoices|listInvoicesForExport|legacy/i);
  assert.match(reconcileSource, /parity|compare|matches|legacyTotal/i);
});
