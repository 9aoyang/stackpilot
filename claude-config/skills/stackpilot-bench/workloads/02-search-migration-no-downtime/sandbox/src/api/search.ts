import { Request, Response, Router } from 'express';
import { DocumentRepo } from '../models/DocumentRepo';
import { logger } from '../lib/logger';

/**
 * GET /api/search?q=foo&limit=20&offset=0
 *
 * Response contract (do NOT change without a frontend change):
 *   { results: Document[], total: number }
 *
 * Currently served by Postgres ILIKE. See DocumentRepo.search.
 */
export const searchRouter = Router();

searchRouter.get('/search', async (req: Request, res: Response) => {
  const q = String(req.query.q ?? '').trim();
  const limit = clampInt(req.query.limit, 20, 1, 100);
  const offset = clampInt(req.query.offset, 0, 0, 10_000);

  if (!q) {
    res.status(400).json({ error: 'q is required' });
    return;
  }

  try {
    const { results, total } = await DocumentRepo.search({ q, limit, offset });
    res.json({ results, total });
  } catch (err) {
    logger.error({ err, q }, 'search failed');
    res.status(500).json({ error: 'search failed' });
  }
});

function clampInt(
  raw: unknown,
  fallback: number,
  min: number,
  max: number
): number {
  const n = Number(raw);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.floor(n)));
}
