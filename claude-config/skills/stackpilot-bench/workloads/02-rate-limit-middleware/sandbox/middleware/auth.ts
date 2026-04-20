import type { Request, Response, NextFunction } from 'express';

export interface AuthedRequest extends Request {
  userId?: string;
  sessionId?: string;
}

// In-memory session store. Production swaps this for redis; for now, tests seed it.
const SESSIONS = new Map<string, { userId: string; expiresAt: number }>();

export function __seedSession(token: string, userId: string, ttlMs = 3_600_000): void {
  SESSIONS.set(token, { userId, expiresAt: Date.now() + ttlMs });
}

export function __clearSessions(): void {
  SESSIONS.clear();
}

function extractBearer(req: Request): string | null {
  const header = req.headers['authorization'];
  if (typeof header !== 'string') return null;
  const [scheme, token] = header.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) return null;
  return token;
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction): void {
  const token = extractBearer(req);
  if (!token) {
    res.status(401).json({ error: 'missing bearer token' });
    return;
  }

  const session = SESSIONS.get(token);
  if (!session) {
    res.status(401).json({ error: 'invalid session' });
    return;
  }
  if (session.expiresAt < Date.now()) {
    SESSIONS.delete(token);
    res.status(401).json({ error: 'session expired' });
    return;
  }

  req.userId = session.userId;
  req.sessionId = token;
  next();
}
