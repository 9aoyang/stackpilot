import { pool } from '../lib/db';
import { Document, rowToDocument } from './Document';

export interface SearchParams {
  q: string;
  limit: number;
  offset: number;
}

export interface SearchResult {
  results: Document[];
  total: number;
}

/**
 * DocumentRepo wraps all SQL for the documents table. The search path
 * here is the current ILIKE implementation backing /api/search.
 *
 * Any new backend (Meilisearch, Typesense, ES, etc.) should live behind
 * a sibling repo / adapter — do NOT mutate this one in place, because
 * it's the rollback target.
 */
export const DocumentRepo = {
  async search(params: SearchParams): Promise<SearchResult> {
    const { q, limit, offset } = params;
    const pattern = `%${q}%`;

    const rowsQuery = pool.query(
      `SELECT id, title, body, tags, created_at
         FROM documents
        WHERE title ILIKE $1 OR body ILIKE $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3`,
      [pattern, limit, offset]
    );

    const totalQuery = pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count
         FROM documents
        WHERE title ILIKE $1 OR body ILIKE $1`,
      [pattern]
    );

    const [rowsRes, totalRes] = await Promise.all([rowsQuery, totalQuery]);

    return {
      results: rowsRes.rows.map(rowToDocument),
      total: Number(totalRes.rows[0]?.count ?? '0'),
    };
  },

  async getById(id: string): Promise<Document | null> {
    const res = await pool.query(
      `SELECT id, title, body, tags, created_at
         FROM documents
        WHERE id = $1`,
      [id]
    );
    const row = res.rows[0];
    return row ? rowToDocument(row) : null;
  },

  async *iterateAll(
    batchSize = 500
  ): AsyncGenerator<Document[], void, void> {
    // Cursor-style iteration for a future backfill / reindex job.
    let lastCreatedAt: string | null = null;
    for (;;) {
      const res = lastCreatedAt
        ? await pool.query(
            `SELECT id, title, body, tags, created_at
               FROM documents
              WHERE created_at < $1
              ORDER BY created_at DESC
              LIMIT $2`,
            [lastCreatedAt, batchSize]
          )
        : await pool.query(
            `SELECT id, title, body, tags, created_at
               FROM documents
              ORDER BY created_at DESC
              LIMIT $1`,
            [batchSize]
          );
      if (res.rows.length === 0) return;
      const docs = res.rows.map(rowToDocument);
      yield docs;
      lastCreatedAt = docs[docs.length - 1].createdAt;
      if (res.rows.length < batchSize) return;
    }
  },
};
