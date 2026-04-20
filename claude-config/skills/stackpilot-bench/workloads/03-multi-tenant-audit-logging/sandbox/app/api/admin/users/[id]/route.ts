import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { getCurrentTenant } from "@/lib/tenant";
import { requireRole } from "@/lib/permissions";
import { getServerAuthSession } from "@/lib/auth";
import { handleKnownError, jsonError } from "@/lib/http";
import { logger } from "@/lib/logger";

const PatchBody = z.object({
  displayName: z.string().min(1).max(120).optional(),
  email: z.string().email().optional(),
});

/**
 * PATCH /api/admin/users/[id] — update a user's profile fields.
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
) {
  try {
    const tenant = await getCurrentTenant(req);
    const session = await getServerAuthSession(req);
    await requireRole(session, tenant, "ADMIN");

    const body = PatchBody.parse(await req.json());
    const existing = await prisma.user.findFirst({
      where: { id: params.id, tenantId: tenant.id },
    });
    if (!existing) return jsonError("User not found", "not_found", 404);

    const updated = await prisma.user.update({
      where: { id: existing.id },
      data: body,
      select: {
        id: true,
        email: true,
        displayName: true,
        bannedAt: true,
      },
    });

    return NextResponse.json(updated);
  } catch (e) {
    const known = handleKnownError(e);
    if (known) return known;
    logger.error("admin_user_patch_failed", { err: String(e) });
    return jsonError("Update failed", "server_error", 500);
  }
}

/**
 * DELETE /api/admin/users/[id] — hard delete a user row.
 */
export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } },
) {
  try {
    const tenant = await getCurrentTenant(req);
    const session = await getServerAuthSession(req);
    await requireRole(session, tenant, "OWNER");

    const existing = await prisma.user.findFirst({
      where: { id: params.id, tenantId: tenant.id },
    });
    if (!existing) return jsonError("User not found", "not_found", 404);

    await prisma.user.delete({ where: { id: existing.id } });

    return NextResponse.json({ ok: true });
  } catch (e) {
    const known = handleKnownError(e);
    if (known) return known;
    logger.error("admin_user_delete_failed", { err: String(e) });
    return jsonError("Delete failed", "server_error", 500);
  }
}
