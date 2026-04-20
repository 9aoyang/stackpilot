import type { SessionLike } from "@/lib/permissions";

/**
 * Stub session resolver. In production this wraps next-auth's
 * `getServerSession(authOptions)`. Kept simple here so tests can swap it.
 */
export async function getServerAuthSession(
  req: Request,
): Promise<SessionLike | null> {
  const uid = req.headers.get("x-user-id");
  const email = req.headers.get("x-user-email");
  if (!uid || !email) return null;
  return { user: { id: uid, email } };
}
