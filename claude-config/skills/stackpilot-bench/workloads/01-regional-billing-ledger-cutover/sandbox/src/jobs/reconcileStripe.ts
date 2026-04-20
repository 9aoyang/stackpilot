import { listInvoicesForExport } from "../billing/invoiceService.ts";

export async function reconcileStripe() {
  const invoices = await listInvoicesForExport();
  return {
    invoiceCount: invoices.length,
    totalCents: invoices.reduce((sum, invoice) => sum + invoice.amountCents, 0),
  };
}
