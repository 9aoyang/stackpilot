import { getInvoiceExportApi } from "../api/invoiceExport";

export async function runNightlyInvoiceExport() {
  return getInvoiceExportApi();
}
