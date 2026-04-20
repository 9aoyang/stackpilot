import { listInvoicesForExport } from "../billing/invoiceService";

export async function getInvoiceExportApi() {
  const invoices = await listInvoicesForExport();
  return {
    rows: invoices.map((invoice) => ({
      invoiceId: invoice.id,
      amountCents: invoice.amountCents,
      currency: invoice.currency,
      status: invoice.status,
      createdAt: invoice.createdAt,
    })),
  };
}
