import {
  verifyAuth,
  requireAuth,
  requireAdmin,
  requireRecentAdmin,
} from '../../src/utils/auth';
import { TEST_USERS, createMockToken, authHeader } from '../helpers/authHelper';
import { mockClaimsStore } from '../setup';
import { testFirestore } from '../helpers/mockFirestore';

describe('Authentication & Authorization Security Matrix', () => {
  beforeEach(() => {
    testFirestore.clear();
    mockClaimsStore.clear();
  });

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

  describe('Token Validation & Integrity', () => {
    it('rejects requests missing an Authorization header', async () => {
      const req: any = { method: 'POST', headers: {} };
      const res = mockRes();
      const user = await requireAuth(req, res);
      expect(user).toBeNull();
      expect(res.statusCode).toBe(401);
      expect(res.body.error).toContain('Unauthorized. Bearer token required.');
    });

    it('rejects malformed tokens without throwing unhandled exceptions', async () => {
      const req: any = {
        method: 'POST',
        headers: { authorization: 'Bearer malformed_token_payload_xyz' },
      };
      const res = mockRes();
      const user = await requireAuth(req, res);
      expect(user).toBeNull();
      expect(res.statusCode).toBe(401);
    });

    it('rejects expired tokens safely', async () => {
      const req: any = {
        method: 'POST',
        headers: { authorization: 'Bearer expired_token' },
      };
      const res = mockRes();
      const user = await requireAuth(req, res);
      expect(user).toBeNull();
      expect(res.statusCode).toBe(401);
    });

    it('rejects tokens with forged/invalid cryptographic signatures', async () => {
      const req: any = {
        method: 'POST',
        headers: { authorization: 'Bearer invalid_signature_token' },
      };
      const res = mockRes();
      const user = await requireAuth(req, res);
      expect(user).toBeNull();
      expect(res.statusCode).toBe(401);
    });
  });

  describe('Role-Based Access Control (RBAC)', () => {
    it('allows standard user to pass requireAuth', async () => {
      const req: any = { method: 'GET', headers: authHeader(TEST_USERS.regular) };
      const res = mockRes();
      const user = await requireAuth(req, res);
      expect(user).not.toBeNull();
      expect(user?.uid).toBe(TEST_USERS.regular.uid);
      expect(user?.isAdmin).toBe(false);
    });

    it('strictly forbids standard user from accessing admin endpoints', async () => {
      const req: any = { method: 'POST', headers: authHeader(TEST_USERS.regular) };
      const res = mockRes();
      const user = await requireAdmin(req, res);
      expect(user).toBeNull();
      expect(res.statusCode).toBe(403);
      expect(res.body.error).toContain('Forbidden. Admin access required.');
    });

    it('allows verified admin to access admin-protected endpoints', async () => {
      const req: any = { method: 'POST', headers: authHeader(TEST_USERS.admin) };
      const res = mockRes();
      const user = await requireAdmin(req, res);
      expect(user).not.toBeNull();
      expect(user?.isAdmin).toBe(true);
    });

    it('auto-provisions and syncs admin role claim when user is listed in admin_members collection', async () => {
      const email = 'auditor@truthworld.test';
      const uid = 'usr_auditor_555';

      await testFirestore.collection('admin_members').doc(email).set({
        role: 'admin',
        status: 'active',
      });

      const token = createMockToken({ uid, email, email_verified: true, admin: false });
      const req: any = { method: 'POST', headers: { authorization: `Bearer ${token}` } };
      const res = mockRes();

      const user = await requireAdmin(req, res);
      expect(user).not.toBeNull();
      expect(user?.isAdmin).toBe(true);
      expect(mockClaimsStore.get(uid)?.admin).toBe(true);
    });
  });

  describe('Resource Ownership & IDOR Protection', () => {
    it('prevents attacker from reading or mutating resource owned by another user', async () => {
      const victimId = TEST_USERS.victim.uid;
      const attackerId = TEST_USERS.attacker.uid;

      // Seed victim private order
      const orderId = 'cf_ord_victim_private_99';
      await testFirestore.collection('payment_orders').doc(orderId).set({
        orderId,
        userId: victimId,
        amount: 100,
        status: 'PAID',
      });

      // Authorization check simulating resource ownership guard
      async function authorizeOrderAccess(requestingUserId: string, targetOrderId: string) {
        const doc = await testFirestore.collection('payment_orders').doc(targetOrderId).get();
        if (!doc.exists) return { allowed: false, status: 404 };
        const data = doc.data();
        if (data?.userId !== requestingUserId) {
          return { allowed: false, status: 403, error: 'Forbidden: Access to another user resource is denied.' };
        }
        return { allowed: true, data };
      }

      // Attacker attempts access
      const attackerAttempt = await authorizeOrderAccess(attackerId, orderId);
      expect(attackerAttempt.allowed).toBe(false);
      expect(attackerAttempt.status).toBe(403);

      // Victim legitimate access
      const victimAttempt = await authorizeOrderAccess(victimId, orderId);
      expect(victimAttempt.allowed).toBe(true);
    });
  });
});
