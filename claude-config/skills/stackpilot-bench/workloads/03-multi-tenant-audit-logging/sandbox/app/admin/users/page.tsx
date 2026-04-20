import { headers } from "next/headers";
import { prisma } from "@/lib/db";

export default async function AdminUsersPage() {
  const slug = headers().get("x-tenant-slug") ?? "";
  const tenant = await prisma.tenant.findUnique({ where: { slug } });
  if (!tenant) return <div>Tenant not found.</div>;

  const users = await prisma.user.findMany({
    where: { tenantId: tenant.id },
    orderBy: { createdAt: "desc" },
    take: 50,
    select: {
      id: true,
      email: true,
      displayName: true,
      bannedAt: true,
      createdAt: true,
    },
  });

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Users</h1>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left border-b">
            <th className="py-2">Email</th>
            <th>Name</th>
            <th>Status</th>
            <th>Created</th>
          </tr>
        </thead>
        <tbody>
          {users.map((u) => (
            <tr key={u.id} className="border-b last:border-0">
              <td className="py-2">
                <a
                  className="text-indigo-600 hover:underline"
                  href={`/admin/users/${u.id}`}
                >
                  {u.email}
                </a>
              </td>
              <td>{u.displayName ?? "—"}</td>
              <td>{u.bannedAt ? "banned" : "active"}</td>
              <td>{u.createdAt.toISOString().slice(0, 10)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
