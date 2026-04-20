import { redirect } from 'next/navigation';
import { getServerAuthSession } from '@/lib/auth';
import { prisma } from '@/lib/db';

export default async function DashboardPage() {
  const session = await getServerAuthSession();
  if (!session?.user) {
    redirect('/signin');
  }

  const user = await prisma.user.findUnique({
    where: { id: (session.user as { id: string }).id },
    select: { id: true, email: true, name: true, createdAt: true },
  });

  if (!user) redirect('/signin');

  return (
    <main className="dashboard">
      <header>
        <h1>Welcome back{user.name ? `, ${user.name}` : ''}.</h1>
        <p className="muted">Signed in as {user.email}</p>
      </header>

      <section className="plan-card">
        <h2>Your plan</h2>
        <p>You are on the Free plan.</p>
        <p className="muted">
          Paid plans are launching soon. We'll email you when they're live.
        </p>
      </section>

      <section className="notes-placeholder">
        <p className="muted">Your notes will appear here.</p>
      </section>
    </main>
  );
}
