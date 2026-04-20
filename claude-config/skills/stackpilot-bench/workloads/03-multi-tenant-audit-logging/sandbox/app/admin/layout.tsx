import { ReactNode } from "react";
import { headers } from "next/headers";
import { prisma } from "@/lib/db";
import { getActorRole } from "@/lib/permissions";

/**
 * Admin area shell. Verifies the caller has at least SUPPORT role in the
 * current tenant. Anything tenant-wide destructive is still re-checked in
 * the route handler — this guard only controls navigation.
 */
export default async function AdminLayout({ children }: { children: ReactNode }) {
  const h = headers();
  const slug = h.get("x-tenant-slug") ?? h.get("host")?.split(".")[0] ?? "";
  const uid = h.get("x-user-id");
  const email = h.get("x-user-email");

  if (!slug) {
    return <main className="p-8">Tenant not resolved.</main>;
  }

  const tenant = await prisma.tenant.findUnique({
    where: { slug },
    select: { id: true, slug: true, region: true, name: true },
  });
  if (!tenant) return <main className="p-8">Tenant not found.</main>;

  const session = uid && email ? { user: { id: uid, email } } : null;
  const role = await getActorRole(session, tenant);
  if (!role) return <main className="p-8">You are not an admin here.</main>;

  return (
    <div className="flex min-h-screen">
      <aside className="w-56 border-r p-4 space-y-2">
        <div className="font-semibold text-sm uppercase tracking-wide">
          {tenant.name}
        </div>
        <nav className="flex flex-col gap-1 text-sm">
          <a href="/admin">Dashboard</a>
          <a href="/admin/users">Users</a>
          <a href="/admin/billing">Billing</a>
          <a href="/admin/settings">Settings</a>
        </nav>
        <div className="text-xs text-neutral-500 pt-4">
          Signed in as {email} ({role})
        </div>
      </aside>
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}
