import { NextResponse } from 'next/server';
import { getServerAuthSession } from '@/lib/auth';
import { prisma } from '@/lib/db';

export async function GET() {
  const session = await getServerAuthSession();
  if (!session?.user) {
    return NextResponse.json(
      { error: 'Not signed in.', code: 'unauthenticated' },
      { status: 401 },
    );
  }

  const user = await prisma.user.findUnique({
    where: { id: (session.user as { id: string }).id },
    select: {
      id: true,
      email: true,
      name: true,
      image: true,
      createdAt: true,
    },
  });

  if (!user) {
    return NextResponse.json(
      { error: 'User not found.', code: 'user_not_found' },
      { status: 404 },
    );
  }

  return NextResponse.json(user);
}
