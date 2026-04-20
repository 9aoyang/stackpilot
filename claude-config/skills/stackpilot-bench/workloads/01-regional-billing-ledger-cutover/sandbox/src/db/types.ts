import type { Currency } from "../lib/money";
import type { Region } from "../lib/region";

export type SubscriptionStatus = "trialing" | "active" | "past_due" | "canceled";

export type Subscription = {
  id: string;
  accountId: string;
  plan: "free" | "team" | "enterprise";
  status: SubscriptionStatus;
  currentPeriodEnd: string;
  cancelAtPeriodEnd: boolean;
  region: Region;
};

export type Invoice = {
  id: string;
  accountId: string;
  subscriptionId: string;
  amountCents: number;
  currency: Currency;
  region: Region;
  status: "open" | "paid" | "void" | "refunded";
  createdAt: string;
};

export type Refund = {
  id: string;
  invoiceId: string;
  amountCents: number;
  currency: Currency;
  region: Region;
  createdAt: string;
};
