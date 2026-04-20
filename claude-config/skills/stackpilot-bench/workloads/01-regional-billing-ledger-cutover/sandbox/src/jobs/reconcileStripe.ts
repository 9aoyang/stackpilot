import { listInvoicesForExport } from "../billing/invoiceService";

export async function reconcileStripe() {
  const invoices = await listInvoicesForExport();
  return {
    invoiceCount: invoices.length,
    totalCents: invoices.reduce((sum, invoice) => sum + invoice.amountCents, 0),
  };
}
