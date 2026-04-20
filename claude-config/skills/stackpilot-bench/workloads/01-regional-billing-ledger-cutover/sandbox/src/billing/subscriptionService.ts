import { db } from "../db/client.ts";

export async function getSubscriptionResponse(accountId: string) {
  const subscription = db.subscriptions.get(accountId);
  if (!subscription) {
    return {
      plan: "free",
      status: "active",
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
    };
  }
  return {
    plan: subscription.plan,
    status: subscription.status,
    currentPeriodEnd: subscription.currentPeriodEnd,
    cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
  };
}
