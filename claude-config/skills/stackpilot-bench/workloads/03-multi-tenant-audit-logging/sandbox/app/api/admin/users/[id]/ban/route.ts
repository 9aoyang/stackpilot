import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getCurrentTenant } from "@/lib/tenant";
import { requireRole } from "@/lib/permissions";
import { getServerAuthSession } from "@/lib/auth";
import { handleKnownError, jsonError } from "@/lib/http";
import { logger } from "@/lib/logger";

/**
 * POST /api/admin/users/[id]/ban — toggle ban on a user.
 */
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
) {
  try {
    const tenant = await getCurrentTenant(req);
    const session = await getServerAuthSession(req);
    await requireRole(session, tenant, "ADMIN");

    const existing = await prisma.user.findFirst({
      where: { id: params.id, tenantId: tenant.id },
      select: { id: true, bannedAt: true, email: true },
    });
    if (!existing) return jsonError("User not found", "not_found", 404);

    const bannedAt = existing.bannedAt ? null : new Date();
    const updated = await prisma.user.update({
      where: { id: existing.id },
      data: { bannedAt },
      select: { id: true, email: true, bannedAt: true },
    });

    return NextResponse.json(updated);
  } catch (e) {
    const known = handleKnownError(e);
    if (known) return known;
    logger.error("admin_user_ban_failed", { err: String(e) });
    return jsonError("Ban failed", "server_error", 500);
  }
}
