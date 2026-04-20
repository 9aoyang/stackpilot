import { db } from "../db/client";
import type { Invoice } from "../db/types";
import { assertCents } from "../lib/money";

export async function recordInvoicePaid(invoice: Invoice) {
  assertCents(invoice.amountCents);
  db.invoices.set(invoice.id, { ...invoice, status: "paid" });
  return db.invoices.get(invoice.id)!;
}

export async function listInvoicesForExport() {
  return [...db.invoices.values()].sort((a, b) => a.createdAt.localeCompare(b.createdAt));
}
