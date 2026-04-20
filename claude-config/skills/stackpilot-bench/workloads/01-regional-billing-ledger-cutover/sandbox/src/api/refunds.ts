import { recordRefund } from "../billing/refundService";
import type { Refund } from "../db/types";

export async function postRefundApi(refund: Refund) {
  const result = await recordRefund(refund);
  return { ok: true, refundId: result.id };
}
