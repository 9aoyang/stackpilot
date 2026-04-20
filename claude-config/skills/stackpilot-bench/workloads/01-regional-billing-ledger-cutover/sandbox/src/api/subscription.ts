import { getSubscriptionResponse } from "../billing/subscriptionService";

export async function getSubscriptionApi(accountId: string) {
  return getSubscriptionResponse(accountId);
}
