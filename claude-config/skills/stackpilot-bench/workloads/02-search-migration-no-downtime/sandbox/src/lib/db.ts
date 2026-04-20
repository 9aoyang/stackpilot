import { Pool, PoolConfig } from 'pg';
import { logger } from './logger';

/**
 * Shared pg Pool singleton. Every module that needs the database must
 * import `pool` from this file — do not construct a new Pool elsewhere.
 */
const config: PoolConfig = {
  connectionString: process.env.DATABASE_URL,
  max: Number(process.env.PG_POOL_MAX ?? 10),
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
  application_name: 'search-service',
};

if (!config.connectionString) {
  throw new Error('DATABASE_URL is required');
}

export const pool = new Pool(config);

pool.on('error', (err) => {
  logger.error({ err }, 'pg pool error');
});

export async function healthcheck(): Promise<boolean> {
  try {
    const res = await pool.query('SELECT 1 AS ok');
    return res.rows[0]?.ok === 1;
  } catch (err) {
    logger.error({ err }, 'db healthcheck failed');
    return false;
  }
}
