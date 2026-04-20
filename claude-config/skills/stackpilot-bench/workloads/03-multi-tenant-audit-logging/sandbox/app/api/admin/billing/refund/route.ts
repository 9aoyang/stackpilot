import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { getCurrentTenant } from "@/lib/tenant";
import { requireRole } from "@/lib/permissions";
import { getServerAuthSession } from "@/lib/auth";
import { handleKnownError, jsonError } from "@/lib/http";
import { logger } from "@/lib/logger";

const RefundBody = z.object({
  invoiceId: z.string().min(1),
  reason: z.string().max(500).optional(),
});

/**
 * POST /api/admin/billing/refund — mark an invoice as refunded.
 *
 * In production this also calls Stripe; here we just toggle the local row.
 */
export async function POST(req: NextRequest) {
  try {
    const tenant = await getCurrentTenant(req);
    const session = await getServerAuthSession(req);
    await requireRole(session, tenant, "ADMIN");

    const body = RefundBody.parse(await req.json());
    const invoice = await prisma.invoice.findFirst({
      where: { id: body.invoiceId, tenantId: tenant.id },
    });
    if (!invoice) return jsonError("Invoice not found", "not_found", 404);
    if (invoice.refundedAt) {
      return jsonError("Already refunded", "already_refunded", 409);
    }

    const updated = await prisma.invoice.update({
      where: { id: invoice.id },
      data: { refundedAt: new Date(), status: "refunded" },
      select: {
        id: true,
        amountCents: true,
        currency: true,
        status: true,
        refundedAt: true,
      },
    });

    return NextResponse.json(updated);
  } catch (e) {
    const known = handleKnownError(e);
    if (known) return known;
    logger.error("admin_refund_failed", { err: String(e) });
    return jsonError("Refund failed", "server_error", 500);
  }
}
