import { headers } from "next/headers";
import { prisma } from "@/lib/db";

export default async function AdminBillingPage() {
  const slug = headers().get("x-tenant-slug") ?? "";
  const tenant = await prisma.tenant.findUnique({ where: { slug } });
  if (!tenant) return <div>Tenant not found.</div>;

  const invoices = await prisma.invoice.findMany({
    where: { tenantId: tenant.id },
    orderBy: { createdAt: "desc" },
    take: 50,
  });

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Billing</h1>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left border-b">
            <th className="py-2">Invoice</th>
            <th>Amount</th>
            <th>Status</th>
            <th>Created</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {invoices.map((inv) => (
            <tr key={inv.id} className="border-b last:border-0">
              <td className="py-2 font-mono text-xs">{inv.id}</td>
              <td>
                {(inv.amountCents / 100).toFixed(2)} {inv.currency.toUpperCase()}
              </td>
              <td>{inv.refundedAt ? "refunded" : inv.status}</td>
              <td>{inv.createdAt.toISOString().slice(0, 10)}</td>
              <td>
                {!inv.refundedAt && (
                  <form action={`/api/admin/billing/refund`} method="post">
                    <input type="hidden" name="invoiceId" value={inv.id} />
                    <button className="text-xs text-red-600 hover:underline">
                      Refund
                    </button>
                  </form>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
