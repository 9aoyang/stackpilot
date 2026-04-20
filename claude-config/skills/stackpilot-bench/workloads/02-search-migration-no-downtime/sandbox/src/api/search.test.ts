import express from 'express';
import request from 'supertest';
import { searchRouter } from './search';
import { DocumentRepo } from '../models/DocumentRepo';

jest.mock('../models/DocumentRepo', () => ({
  DocumentRepo: {
    search: jest.fn(),
  },
}));

const mockedRepo = DocumentRepo as unknown as {
  search: jest.Mock;
};

function buildApp() {
  const app = express();
  app.use('/api', searchRouter);
  return app;
}

describe('GET /api/search', () => {
  beforeEach(() => {
    mockedRepo.search.mockReset();
  });

  it('returns { results, total } for a valid query', async () => {
    mockedRepo.search.mockResolvedValue({
      results: [
        {
          id: '11111111-1111-1111-1111-111111111111',
          title: 'Invoice template',
          body: 'body',
          tags: ['billing'],
          createdAt: '2026-01-01T00:00:00.000Z',
        },
      ],
      total: 1,
    });

    const res = await request(buildApp())
      .get('/api/search')
      .query({ q: 'invoice' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      results: [
        {
          id: '11111111-1111-1111-1111-111111111111',
          title: 'Invoice template',
          body: 'body',
          tags: ['billing'],
          createdAt: '2026-01-01T00:00:00.000Z',
        },
      ],
      total: 1,
    });
    expect(mockedRepo.search).toHaveBeenCalledWith({
      q: 'invoice',
      limit: 20,
      offset: 0,
    });
  });

  it('rejects missing q', async () => {
    const res = await request(buildApp()).get('/api/search');
    expect(res.status).toBe(400);
    expect(mockedRepo.search).not.toHaveBeenCalled();
  });

  it('clamps limit and offset', async () => {
    mockedRepo.search.mockResolvedValue({ results: [], total: 0 });
    await request(buildApp())
      .get('/api/search')
      .query({ q: 'x', limit: '9999', offset: '-5' });
    expect(mockedRepo.search).toHaveBeenCalledWith({
      q: 'x',
      limit: 100,
      offset: 0,
    });
  });
});
