import { NextResponse } from "next/server";
import { PermissionError, UnauthenticatedError } from "@/lib/permissions";

export function jsonError(
  error: string,
  code: string,
  status = 400,
): NextResponse {
  return NextResponse.json({ error, code }, { status });
}

export function handleKnownError(e: unknown): NextResponse | null {
  if (e instanceof UnauthenticatedError) {
    return jsonError("Not signed in", "unauthenticated", 401);
  }
  if (e instanceof PermissionError) {
    return jsonError("Insufficient permission", "forbidden", 403);
  }
  if (e instanceof Error && e.message === "tenant_not_found") {
    return jsonError("Tenant not found", "tenant_not_found", 404);
  }
  if (e instanceof Error && e.message === "tenant_unresolved") {
    return jsonError("Tenant not resolved", "tenant_unresolved", 400);
  }
  return null;
}
