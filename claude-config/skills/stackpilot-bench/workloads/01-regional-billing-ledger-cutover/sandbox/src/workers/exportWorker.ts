import { getInvoiceExportApi } from "../api/invoiceExport.ts";

export async function runNightlyInvoiceExport() {
  return getInvoiceExportApi();
}
