import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";

export type TenantContext = {
  id: string;
  slug: string;
  region: string;
};

/**
 * Resolve the active tenant for the current request.
 *
 * In production we pull the subdomain from the Host header; in dev & tests
 * we allow an `X-Tenant-Slug` override so Playwright can hop between tenants.
 *
 * Throws if no tenant can be resolved. Route handlers should let this bubble
 * (middleware will turn it into a 404).
 */
export async function getCurrentTenant(
  req: NextRequest | Request,
): Promise<TenantContext> {
  const headers = req.headers;
  const override = headers.get("x-tenant-slug");
  const host = headers.get("host") ?? "";
  const slug = override ?? host.split(".")[0] ?? "";

  if (!slug) throw new Error("tenant_unresolved");

  const tenant = await prisma.tenant.findUnique({
    where: { slug },
    select: { id: true, slug: true, region: true },
  });
  if (!tenant) throw new Error("tenant_not_found");
  return tenant;
}

/**
 * Pull the client IP. Honors the first entry in X-Forwarded-For when the
 * request came through our edge proxy; falls back to request.ip.
 */
export function getClientIp(req: NextRequest | Request): string | null {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0]!.trim();
  // @ts-expect-error ip exists on NextRequest at runtime
  return (req as NextRequest).ip ?? null;
}
