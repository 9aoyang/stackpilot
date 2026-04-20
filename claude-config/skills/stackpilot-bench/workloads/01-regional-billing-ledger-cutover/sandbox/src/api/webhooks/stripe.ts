import { recordInvoicePaid } from "../../billing/invoiceService.ts";
import type { Invoice } from "../../db/types.ts";
import { markProcessedOnce } from "../../lib/idempotency.ts";
import { regionFromAccount } from "../../lib/region.ts";

export type StripeInvoicePaidEvent = {
  id: string;
  type: "invoice.paid";
  accountId: string;
  invoiceId: string;
  subscriptionId: string;
  amountPaid: number;
  currency: "USD" | "EUR" | "JPY";
  customerEmail?: string;
  paymentMethod?: string;
  createdAt: string;
};

export async function handleStripeWebhook(event: StripeInvoicePaidEvent) {
  const firstSeen = await markProcessedOnce(`stripe:${event.id}`);
  if (!firstSeen) return { ok: true, duplicate: true };

  const invoice: Invoice = {
    id: event.invoiceId,
    accountId: event.accountId,
    subscriptionId: event.subscriptionId,
    amountCents: event.amountPaid,
    currency: event.currency,
    region: regionFromAccount(event.accountId),
    status: "paid",
    createdAt: event.createdAt,
  };

  await recordInvoicePaid(invoice);
  return { ok: true };
}
