import { PrismaClient } from '@prisma/client';

// Prisma client singleton. In Next.js dev mode the module graph is re-evaluated
// on HMR, which would leak PrismaClient instances; the globalThis cache avoids
// that. Always import `prisma` from here — do NOT call `new PrismaClient()`
// directly in route handlers.
const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}
