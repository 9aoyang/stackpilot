import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Lightweight middleware: every /admin/* or /api/admin/* request must carry
 * a resolvable tenant slug (subdomain in prod, X-Tenant-Slug in dev).
 * Real auth enforcement lives in the route handlers via `requireRole`.
 */
export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const isAdminPath =
    pathname.startsWith("/admin") || pathname.startsWith("/api/admin");
  if (!isAdminPath) return NextResponse.next();

  const host = req.headers.get("host") ?? "";
  const override = req.headers.get("x-tenant-slug");
  const slug = override ?? host.split(".")[0];
  if (!slug) {
    return NextResponse.json(
      { error: "Tenant not resolved", code: "tenant_unresolved" },
      { status: 400 },
    );
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*", "/api/admin/:path*"],
};
