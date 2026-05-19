// TASK-001 will add roundUnitCost integration.
// TASK-003 will wrap each mutation with auditLog.append(...).

import { nextInvoiceNumber } from './invoiceNumbering.ts';

export interface Invoice {
  id: string;
  cents: number;
  status: 'draft' | 'sent' | 'paid';
}

export function createInvoice(cents: number): Invoice {
  // TASK-001 will route this through roundUnitCost.
  // TASK-003 will auditLog.append('invoice.create', ...).
  return { id: nextInvoiceNumber('INV'), cents, status: 'draft' };
}

export function markPaid(invoice: Invoice): Invoice {
  // TASK-003 will auditLog.append('invoice.paid', ...).
  return { ...invoice, status: 'paid' };
}
