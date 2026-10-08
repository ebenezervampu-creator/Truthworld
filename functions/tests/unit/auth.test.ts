import * as admin from 'firebase-admin';
import {
  verifyAuth,
  requireAuth,
  requireAdmin,
  requireRecentAdmin,
  isCallableAdmin,
  isCallableRecentAdmin,
} from '../../src/utils/auth';
import { TEST_USERS, createMockToken, authHeader } from '../helpers/authHelper';
import { mockClaimsStore } from '../setup';
import { testFirestore } from '../helpers/mockFirestore';

describe('Unit: Authentication Utilities', () => {
  const mockRes = () => {
    const res: any = {
      statusCode: 200,
      headers: {},
      body: null,
      setHeader: jest.fn((k: string, v: string) => {
        res.headers[k] = v;
      }),
      set: jest.fn((k: string, v: string) => {
        res.headers[k] = v;
      }),
      status: jest.fn((code: number) => {
        res.statusCode = code;
        return res;
      }),
      json: jest.fn((data: any) => {
        res.body = data;
        return res;
      }),
      send: jest.fn((data: any) => {
        res.body = data;
        return res;
      }),
    };
    return res;
  };

  describe('verifyAuth()', () => {
    it('returns null when Authorization header is missing', async () => {
      const req: any = { headers: {} };
      const user = await verifyAuth(req);
      expect(user).toBeNull();
    });

    it('returns null when Authorization header does not start with Bearer', async () => {
      const req: any = { headers: { authorization: 'Basic 123456' } };
      const user = await verifyAuth(req);
      expect(user).toBeNull();
    });

    it('returns decoded user when valid Bearer token is provided', async () => {
      const token = createMockToken(TEST_USERS.regular);
      const req: any = { headers: { authorization: `Bearer ${token}` } };
      const user = await verifyAuth(req);
      expect(user).not.toBeNull();
      expect(user?.uid).toBe(TEST_USERS.regular.uid);
      expect(user?.isAdmin).toBe(false);
    });

    it('returns user with isAdmin=true when custom claim contains admin', async () => {
      const token = createMockToken(TEST_USERS.admin);
      const req: any = { headers: { authorization: `Bearer ${token}` } };
      const user = await verifyAuth(req);
      expect(user).not.toBeNull();
      expect(user?.isAdmin).toBe(true);
    });

    it('auto-provisions admin claim when email exists in admin_members collection', async () => {
      const email = 'newly_appointed_admin@truthworld.test';
      const uid = 'usr_new_admin_404';

      // Insert member into admin_members collection in Firestore
      await testFirestore.collection('admin_members').doc(email).set({
        role: 'superadmin',
        status: 'active',
      });

      const token = createMockToken({ uid, email, email_verified: true, admin: false });
      const req: any = { headers: { authorization: `Bearer ${token}` } };

      const user = await verifyAuth(req);
      expect(user).not.toBeNull();
      expect(user?.isAdmin).toBe(true);
      expect(mockClaimsStore.get(uid)?.admin).toBe(true);
    });

    it('returns null on expired token', async () => {
      const req: any = { headers: { authorization: 'Bearer expired_token' } };
      const user = await verifyAuth(req);
      expect(user).toBeNull();
    });

    it('returns null on malformed token', async () => {
      const req: any = { headers: { authorization: 'Bearer malformed_token' } };
      const user = await verifyAuth(req);
      expect(user).toBeNull();
    });
  });

  describe('requireAuth()', () => {
    it('returns 204 on OPTIONS request', async () => {
      const req: any = { method: 'OPTIONS', headers: {} };
      const res = mockRes();
      const result = await requireAuth(req, res);
      expect(result).toBeNull();
      expect(res.statusCode).toBe(204);
    });

    it('returns 401 when unauthenticated', async () => {
      const req: any = { method: 'GET', headers: {} };
      const res = mockRes();
      const result = await requireAuth(req, res);
      expect(result).toBeNull();
      expect(res.statusCode).toBe(401);
      expect(res.body.error).toContain('Unauthorized');
    });

    it('returns user when authenticated', async () => {
      const req: any = {
        method: 'GET',
        headers: authHeader(TEST_USERS.regular),
      };
      const res = mockRes();
      const result = await requireAuth(req, res);
      expect(result).not.toBeNull();
      expect(result?.uid).toBe(TEST_USERS.regular.uid);
    });
  });

  describe('requireAdmin()', () => {
    it('returns 403 when user is authenticated but not an admin', async () => {
      const req: any = {
        method: 'POST',
        headers: authHeader(TEST_USERS.regular),
      };
      const res = mockRes();
      const result = await requireAdmin(req, res);
      expect(result).toBeNull();
      expect(res.statusCode).toBe(403);
      expect(res.body.error).toContain('Forbidden');
    });

    it('allows access when user is verified admin', async () => {
      const req: any = {
        method: 'POST',
        headers: authHeader(TEST_USERS.admin),
      };
      const res = mockRes();
      const result = await requireAdmin(req, res);
      expect(result).not.toBeNull();
      expect(result?.isAdmin).toBe(true);
    });
  });

  describe('requireRecentAdmin()', () => {
    it('allows recent admin session', async () => {
      const nowSec = Math.floor(Date.now() / 1000);
      const token = createMockToken({ ...TEST_USERS.admin, auth_time: nowSec - 60 });
      const req: any = {
        method: 'POST',
        headers: { authorization: `Bearer ${token}` },
      };
      const res = mockRes();
      const result = await requireRecentAdmin(req, res, 1800);
      expect(result).not.toBeNull();
    });

    it('rejects stale admin session requiring step-up auth', async () => {
      const nowSec = Math.floor(Date.now() / 1000);
      // Session older than 1800s (30m)
      const token = createMockToken({ ...TEST_USERS.admin, auth_time: nowSec - 3600 });
      const req: any = {
        method: 'POST',
        headers: { authorization: `Bearer ${token}` },
      };
      const res = mockRes();
      const result = await requireRecentAdmin(req, res, 1800);
      expect(result).toBeNull();
      expect(res.statusCode).toBe(403);
      expect(res.body.code).toBe('AUTH_STEP_UP_REQUIRED');
    });
  });

  describe('Callable Admin Helpers', () => {
    it('isCallableAdmin correctly identifies admin in token context', () => {
      expect(isCallableAdmin({ token: { admin: true } })).toBe(true);
      expect(isCallableAdmin({ token: { role: 'admin' } })).toBe(true);
      expect(isCallableAdmin({ token: { role: 'user' } })).toBe(false);
      expect(isCallableAdmin(null)).toBe(false);
    });

    it('isCallableRecentAdmin checks admin and freshness', () => {
      const nowSec = Math.floor(Date.now() / 1000);
      expect(isCallableRecentAdmin({ token: { admin: true, auth_time: nowSec - 30 } }, 600)).toBe(true);
      expect(isCallableRecentAdmin({ token: { admin: true, auth_time: nowSec - 1200 } }, 600)).toBe(false);
      expect(isCallableRecentAdmin({ token: { admin: false, auth_time: nowSec } }, 600)).toBe(false);
    });
  });
});
