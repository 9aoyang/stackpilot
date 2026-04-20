import assert from "node:assert/strict";
import test from "node:test";

import { getInvoiceExportApi } from "../../src/api/invoiceExport.ts";
import { postRefundApi } from "../../src/api/refunds.ts";
import { handleStripeWebhook } from "../../src/api/webhooks/stripe.ts";
import { db } from "../../src/db/client.ts";
import { reconcileStripe } from "../../src/jobs/reconcileStripe.ts";
import { read } from "../helpers/read-file.mjs";

test("exports and reconciliation can compare legacy rows against the ledger projection", () => {
  const reconcileSource = read("src/jobs/reconcileStripe.ts");

  assert.match(reconcileSource, /ledger|BILLING_LEDGER_READ_MODE|getLedgerReadMode/i);
  assert.match(reconcileSource, /db\.invoices|listInvoicesForExport|legacy/i);
  assert.match(reconcileSource, /parity|compare|matches|legacyTotal|ledgerTotal/i);
});

test("ledger read mode serves invoice export and reconciliation after invoice/refund writes", async () => {
  resetState();
  process.env.BILLING_LEDGER_WRITE_MODE = "ledger";
  process.env.BILLING_LEDGER_READ_MODE = "ledger";

  const invoiceId = "in_hidden_ledger_refund";
  await handleStripeWebhook({
    id: "evt_hidden_ledger",
    type: "invoice.paid",
    accountId: "acct_apac_hidden",
    invoiceId,
    subscriptionId: "sub_hidden_ledger",
    amountPaid: 5100,
    currency: "JPY",
    customerEmail: "hidden-ledger@example.com",
    paymentMethod: "pm_hidden_ledger",
    createdAt: "2026-04-20T11:00:00.000Z",
  });

  await postRefundApi({
    id: "rf_hidden_ledger",
    invoiceId,
    amountCents: 1200,
    currency: "JPY",
    region: "apac",
    createdAt: "2026-04-20T12:00:00.000Z",
  });

  assert.equal(db.invoices.has(invoiceId), false, "ledger write mode should not require legacy invoice writes");
  assert.equal(db.refunds.has("rf_hidden_ledger"), false, "ledger write mode should not require legacy refund writes");

  const rows = (await getInvoiceExportApi()).rows;
  const row = rows.find((candidate) => candidate.invoiceId === invoiceId);
  assert.ok(row, "ledger read mode must expose the invoice through the export API");
  assert.equal(row.status, "refunded");
  assert.equal(row.amountCents, 5100);
  assert.equal(row.currency, "JPY");

  const reconciliation = await reconcileStripe();
  assert.ok(reconciliation.invoiceCount >= 1);
  assert.ok(reconciliation.totalCents >= 5100);
});

function resetState() {
  for (const value of Object.values(db)) {
    if (value && typeof value.clear === "function") value.clear();
  }
  delete process.env.BILLING_LEDGER_WRITE_MODE;
  delete process.env.BILLING_LEDGER_READ_MODE;
}
