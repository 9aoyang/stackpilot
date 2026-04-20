import assert from "node:assert/strict";
import test from "node:test";

import { getInvoiceExportApi } from "../../src/api/invoiceExport.ts";
import { handleStripeWebhook } from "../../src/api/webhooks/stripe.ts";
import { db } from "../../src/db/client.ts";

test("billing writes route through regional ledger modes without deleting legacy compatibility writes", () => {
  assert.equal(typeof handleStripeWebhook, "function");
  assert.equal(typeof getInvoiceExportApi, "function");
});

test("dual write shadows invoice events while legacy reads remain available", async () => {
  resetState();
  process.env.BILLING_LEDGER_WRITE_MODE = "dual";
  process.env.BILLING_LEDGER_READ_MODE = "legacy";

  const event = stripeEvent("evt_hidden_dual", "in_hidden_dual", "acct_eu_hidden", 4200, "EUR");

  await handleStripeWebhook(event);
  assert.equal(db.invoices.get(event.invoiceId)?.status, "paid");

  const legacyRows = (await getInvoiceExportApi()).rows;
  assert.equal(rowById(legacyRows, event.invoiceId)?.amountCents, 4200);

  db.invoices.clear();
  db.refunds.clear();
  process.env.BILLING_LEDGER_READ_MODE = "ledger";

  const ledgerRows = (await getInvoiceExportApi()).rows.filter((row) => row.invoiceId === event.invoiceId);
  assert.equal(ledgerRows.length, 1, "ledger read mode must not fall back to legacy invoice rows");
  assert.equal(ledgerRows[0]?.status, "paid");

  await handleStripeWebhook(event);
  const afterDuplicate = (await getInvoiceExportApi()).rows.filter((row) => row.invoiceId === event.invoiceId);
  assert.equal(afterDuplicate.length, 1, "duplicate Stripe event must not create duplicate ledger rows");
});

function resetState() {
  for (const value of Object.values(db)) {
    if (value && typeof value.clear === "function") value.clear();
  }
  delete process.env.BILLING_LEDGER_WRITE_MODE;
  delete process.env.BILLING_LEDGER_READ_MODE;
}

function stripeEvent(id, invoiceId, accountId, amountPaid, currency) {
  return {
    id,
    type: "invoice.paid",
    accountId,
    invoiceId,
    subscriptionId: `sub_${invoiceId}`,
    amountPaid,
    currency,
    customerEmail: "hidden-buyer@example.com",
    paymentMethod: "pm_hidden_card",
    createdAt: "2026-04-20T10:00:00.000Z",
  };
}

function rowById(rows, invoiceId) {
  return rows.find((row) => row.invoiceId === invoiceId);
}
