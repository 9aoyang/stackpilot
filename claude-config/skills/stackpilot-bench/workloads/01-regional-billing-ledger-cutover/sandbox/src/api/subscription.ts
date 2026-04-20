import { getSubscriptionResponse } from "../billing/subscriptionService.ts";

export async function getSubscriptionApi(accountId: string) {
  return getSubscriptionResponse(accountId);
}
