import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/db";

export default async function AdminUserDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const slug = headers().get("x-tenant-slug") ?? "";
  const tenant = await prisma.tenant.findUnique({ where: { slug } });
  if (!tenant) return notFound();

  const user = await prisma.user.findFirst({
    where: { id: params.id, tenantId: tenant.id },
    select: {
      id: true,
      email: true,
      displayName: true,
      bannedAt: true,
      createdAt: true,
    },
  });
  if (!user) return notFound();

  return (
    <div className="space-y-6 max-w-lg">
      <h1 className="text-2xl font-semibold">{user.email}</h1>
      <dl className="grid grid-cols-2 gap-2 text-sm">
        <dt className="text-neutral-500">Display name</dt>
        <dd>{user.displayName ?? "—"}</dd>
        <dt className="text-neutral-500">Status</dt>
        <dd>{user.bannedAt ? `banned ${user.bannedAt.toISOString()}` : "active"}</dd>
        <dt className="text-neutral-500">Created</dt>
        <dd>{user.createdAt.toISOString()}</dd>
      </dl>
      <div className="flex gap-2">
        <form action={`/api/admin/users/${user.id}/ban`} method="post">
          <button className="px-3 py-1.5 rounded bg-red-600 text-white text-sm">
            {user.bannedAt ? "Unban" : "Ban"}
          </button>
        </form>
      </div>
    </div>
  );
}
