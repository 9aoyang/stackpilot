import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { getCurrentTenant } from "@/lib/tenant";
import { requireRole } from "@/lib/permissions";
import { getServerAuthSession } from "@/lib/auth";
import { handleKnownError, jsonError } from "@/lib/http";
import { logger } from "@/lib/logger";

const PatchBody = z.object({
  plan: z.string().min(1).max(64).optional(),
  brandColor: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/)
    .optional(),
  featureFlags: z.record(z.boolean()).optional(),
});

/**
 * PATCH /api/admin/settings — update tenant-level preferences.
 */
export async function PATCH(req: NextRequest) {
  try {
    const tenant = await getCurrentTenant(req);
    const session = await getServerAuthSession(req);
    await requireRole(session, tenant, "ADMIN");

    const body = PatchBody.parse(await req.json());

    const updated = await prisma.tenantSettings.upsert({
      where: { tenantId: tenant.id },
      update: body,
      create: {
        tenantId: tenant.id,
        plan: body.plan ?? "starter",
        brandColor: body.brandColor ?? "#6366f1",
        featureFlags: body.featureFlags ?? {},
      },
      select: {
        tenantId: true,
        plan: true,
        brandColor: true,
        featureFlags: true,
      },
    });

    return NextResponse.json(updated);
  } catch (e) {
    const known = handleKnownError(e);
    if (known) return known;
    logger.error("admin_settings_patch_failed", { err: String(e) });
    return jsonError("Settings update failed", "server_error", 500);
  }
}
