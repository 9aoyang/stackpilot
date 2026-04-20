import { recordRefund } from "../billing/refundService.ts";
import type { Refund } from "../db/types.ts";

export async function postRefundApi(refund: Refund) {
  const result = await recordRefund(refund);
  return { ok: true, refundId: result.id };
}
