import { requireAuth, __seedSession, __clearSessions, type AuthedRequest } from './auth';
import type { Response, NextFunction } from 'express';

function mockRes(): Response {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.setHeader = jest.fn().mockReturnValue(res);
  return res as Response;
}

function mockReq(headers: Record<string, string> = {}): AuthedRequest {
  return { headers } as unknown as AuthedRequest;
}

describe('requireAuth', () => {
  beforeEach(() => __clearSessions());

  it('rejects requests without a bearer token with 401', () => {
    const req = mockReq();
    const res = mockRes();
    const next = jest.fn() as NextFunction;

    requireAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects unknown session tokens with 401', () => {
    const req = mockReq({ authorization: 'Bearer nope' });
    const res = mockRes();
    const next = jest.fn() as NextFunction;

    requireAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('populates req.userId and calls next() on valid session', () => {
    __seedSession('tok-abc', 'user-1');
    const req = mockReq({ authorization: 'Bearer tok-abc' });
    const res = mockRes();
    const next = jest.fn() as NextFunction;

    requireAuth(req, res, next);

    expect(req.userId).toBe('user-1');
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('rejects expired sessions with 401', () => {
    __seedSession('tok-expired', 'user-2', -1);
    const req = mockReq({ authorization: 'Bearer tok-expired' });
    const res = mockRes();
    const next = jest.fn() as NextFunction;

    requireAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });
});
