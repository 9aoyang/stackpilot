import { headers } from "next/headers";
import { prisma } from "@/lib/db";

export default async function AdminSettingsPage() {
  const slug = headers().get("x-tenant-slug") ?? "";
  const tenant = await prisma.tenant.findUnique({
    where: { slug },
    include: { settings: true },
  });
  if (!tenant) return <div>Tenant not found.</div>;

  const s = tenant.settings;

  return (
    <div className="space-y-6 max-w-lg">
      <h1 className="text-2xl font-semibold">Settings</h1>
      <form
        action="/api/admin/settings"
        method="post"
        className="space-y-3 text-sm"
      >
        <input type="hidden" name="_method" value="PATCH" />
        <label className="flex flex-col gap-1">
          <span className="text-neutral-500">Plan</span>
          <input
            name="plan"
            defaultValue={s?.plan ?? "starter"}
            className="border rounded px-2 py-1"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-neutral-500">Brand color</span>
          <input
            name="brandColor"
            defaultValue={s?.brandColor ?? "#6366f1"}
            className="border rounded px-2 py-1 font-mono"
          />
        </label>
        <button className="px-3 py-1.5 rounded bg-indigo-600 text-white">
          Save
        </button>
      </form>
    </div>
  );
}
