import { headers } from "next/headers";
import { prisma } from "@/lib/db";

export default async function AdminDashboard() {
  const slug = headers().get("x-tenant-slug") ?? "";
  const tenant = await prisma.tenant.findUnique({ where: { slug } });
  if (!tenant) return <div>Tenant not found.</div>;

  const [userCount, invoiceCount] = await Promise.all([
    prisma.user.count({ where: { tenantId: tenant.id } }),
    prisma.invoice.count({ where: { tenantId: tenant.id } }),
  ]);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Admin dashboard</h1>
      <div className="grid grid-cols-3 gap-4">
        <Stat label="Users" value={userCount} />
        <Stat label="Invoices" value={invoiceCount} />
        <Stat label="Plan" value={"—"} />
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded border p-4">
      <div className="text-xs uppercase text-neutral-500">{label}</div>
      <div className="text-2xl font-semibold">{value}</div>
    </div>
  );
}
