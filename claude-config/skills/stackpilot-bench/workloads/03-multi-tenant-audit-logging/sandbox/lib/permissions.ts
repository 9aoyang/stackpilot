import { prisma } from "@/lib/db";
import type { TenantContext } from "@/lib/tenant";

export type Role = "OWNER" | "ADMIN" | "SUPPORT" | "MEMBER";

export type SessionLike = {
  user: { id: string; email: string };
};

const HIERARCHY: Role[] = ["MEMBER", "SUPPORT", "ADMIN", "OWNER"];

function rank(role: Role): number {
  return HIERARCHY.indexOf(role);
}

export class PermissionError extends Error {
  statusCode = 403;
  constructor(public required: Role) {
    super(`permission_denied:${required}`);
  }
}

export class UnauthenticatedError extends Error {
  statusCode = 401;
}

export async function getActorRole(
  session: SessionLike | null,
  tenant: TenantContext,
): Promise<Role | null> {
  if (!session) return null;
  const row = await prisma.adminRole.findUnique({
    where: {
      tenantId_userId: { tenantId: tenant.id, userId: session.user.id },
    },
    select: { role: true },
  });
  return (row?.role as Role | undefined) ?? null;
}

/**
 * Throws if session is null (401) or role is below `min` (403).
 * Returns the actor's role on success.
 */
export async function requireRole(
  session: SessionLike | null,
  tenant: TenantContext,
  min: Role,
): Promise<Role> {
  if (!session) throw new UnauthenticatedError("unauthenticated");
  const role = await getActorRole(session, tenant);
  if (!role || rank(role) < rank(min)) throw new PermissionError(min);
  return role;
}
