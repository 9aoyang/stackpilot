import express from 'express';
import { searchRouter } from './api/search';
import { healthcheck } from './lib/db';
import { logger } from './lib/logger';

const app = express();
app.use(express.json({ limit: '256kb' }));

app.get('/healthz', async (_req, res) => {
  const ok = await healthcheck();
  res.status(ok ? 200 : 503).json({ ok });
});

app.use('/api', searchRouter);

const port = Number(process.env.PORT ?? 4100);

if (require.main === module) {
  app.listen(port, () => {
    logger.info({ port }, 'search-service listening');
  });
}

export { app };
