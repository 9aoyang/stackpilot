/**
 * Placeholder for the search indexer / backfill job.
 *
 * Today nothing indexes anywhere — the ILIKE path in DocumentRepo reads
 * straight from Postgres. When we migrate to a dedicated search engine,
 * this module will own:
 *
 *   - one-shot backfill of all existing documents into the new engine
 *   - incremental reindex when document rows change
 *   - a dry-run / verify mode used by ops before we flip traffic
 *
 * Deliberately empty for now so the shape of the future job is obvious.
 */

export async function runBackfill(): Promise<void> {
  throw new Error('not implemented');
}

export async function reindexOne(_id: string): Promise<void> {
  throw new Error('not implemented');
}
