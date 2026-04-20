import type { Invoice, Refund, Subscription } from "./types.ts";

const subscriptions = new Map<string, Subscription>();
const invoices = new Map<string, Invoice>();
const refunds = new Map<string, Refund>();

export const db = {
  subscriptions,
  invoices,
  refunds,
  async transaction<T>(fn: () => Promise<T>): Promise<T> {
    return fn();
  },
};
