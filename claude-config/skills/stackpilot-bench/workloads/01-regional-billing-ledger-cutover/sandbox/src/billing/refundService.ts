import { db } from "../db/client.ts";
import type { Refund } from "../db/types.ts";
import { assertCents } from "../lib/money.ts";

export async function recordRefund(refund: Refund) {
  assertCents(refund.amountCents);
  db.refunds.set(refund.id, refund);
  const invoice = db.invoices.get(refund.invoiceId);
  if (invoice) db.invoices.set(invoice.id, { ...invoice, status: "refunded" });
  return refund;
}
