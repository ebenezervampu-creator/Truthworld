import request from 'supertest';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { verifyAuth, setCorsHeaders } from '../../src/utils/auth';
import { sendAdminCredentials, verifyAdminUsername } from '../../src/admin/adminMemberEndpoints';
import {
  createCashfreeOrder,
  cashfreeWebhook,
  cashfreeHostedCheckout,
} from '../../src/economy/cashfreeFunctions';
import { moderateUser, consolidateUserAccounts } from '../../src/admin/userManagement';
import { getClientIp } from '../../src/watchtime/guestWatchLimit';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { TEST_USERS, authHeader, createMockToken } from '../helpers/authHelper';
import { mockClaimsStore } from '../setup';
import { CashfreeService } from '../../src/services/cashfreeService';

describe('Backend Security Vulnerability Remediations Verification Suite', () => {
  beforeEach(() => {
    testFirestore.clear();
    mockClaimsStore.clear();
  });

  // =========================================================================
  // 1. TW-BACKEND-01, TW-BACKEND-09, TW-BACKEND-12 in auth.ts
  // =========================================================================
  describe('1. TW-BACKEND-01, TW-BACKEND-09, TW-BACKEND-12 (auth.ts)', () => {
    it('preserves assigned role from admin_members and does NOT escalate to Super Admin', async () => {
      const moderatorEmail = 'moderator@truthworld.test';
      const moderatorUid = 'usr_mod_42';

      // Seed moderator document in admin_members with role "Content Moderator"
      await testFirestore.collection('admin_members').doc(moderatorEmail).set({
        email: moderatorEmail,
        name: 'Jane Moderator',
        role: 'Content Moderator',
        roles: ['Content Moderator'],
        status: 'active',
      });

      const req: any = {
        headers: {
          authorization: `Bearer ${createMockToken({
            uid: moderatorUid,
            email: moderatorEmail,
            email_verified: true,
            admin: false,
          })}`,
        },
      };

      const user = await verifyAuth(req);
      expect(user).not.toBeNull();
      expect(user?.isAdmin).toBe(true);

      // Verify custom claims store: must preserve assigned role "Content Moderator" and NOT grant isSuperAdmin
      const claims = mockClaimsStore.get(moderatorUid) || {};
      expect(claims.admin).toBe(true);
      expect(claims.role).toBe('Content Moderator');
      expect(claims.isSuperAdmin).toBeUndefined();

      // Verify admin_members document: must NOT have been overwritten with Super Admin
      const updatedDoc = await testFirestore.collection('admin_members').doc(moderatorEmail).get();
      expect(updatedDoc.data()?.role).toBe('Content Moderator');
      expect(updatedDoc.data()?.roles).toEqual(['Content Moderator']);
    });

    it('restricts localhost CORS regex to emulator or non-production environment', () => {
      const origNodeEnv = process.env.NODE_ENV;
      const origEmulator = process.env.FUNCTIONS_EMULATOR;

      try {
        // In Production: localhost must NOT be matched
        process.env.NODE_ENV = 'production';
        process.env.FUNCTIONS_EMULATOR = 'false';

        const reqProd: any = { headers: { origin: 'http://localhost:5173' } };
        const resHeadersProd: Record<string, string> = {};
        const resProd: any = {
          setHeader: (k: string, v: string) => { resHeadersProd[k.toLowerCase()] = v; },
          set: (k: string, v: string) => { resHeadersProd[k.toLowerCase()] = v; },
        };

        setCorsHeaders(reqProd, resProd);
        expect(resHeadersProd['access-control-allow-origin']).toBeUndefined();

        // In Development/Emulator: localhost is matched
        process.env.NODE_ENV = 'development';
        const reqDev: any = { headers: { origin: 'http://localhost:5173' } };
        const resHeadersDev: Record<string, string> = {};
        const resDev: any = {
          setHeader: (k: string, v: string) => { resHeadersDev[k.toLowerCase()] = v; },
          set: (k: string, v: string) => { resHeadersDev[k.toLowerCase()] = v; },
        };

        setCorsHeaders(reqDev, resDev);
        expect(resHeadersDev['access-control-allow-origin']).toBe('http://localhost:5173');
      } finally {
        process.env.NODE_ENV = origNodeEnv;
        process.env.FUNCTIONS_EMULATOR = origEmulator;
      }
    });
  });

  // =========================================================================
  // 2. TW-BACKEND-03 & TW-BACKEND-04 in adminMemberEndpoints.ts
  // =========================================================================
  describe('2. TW-BACKEND-03 & TW-BACKEND-04 (adminMemberEndpoints.ts)', () => {
    it('verifyAdminUsername does not call bootstrap or reset passwords', async () => {
      const res = await (verifyAdminUsername as any).run({
        data: { username: 'hello1' },
      });

      expect(res.valid).toBe(true);
      expect(res.email).toBe('hello@truthworld.in');
      expect(res.role).toBe('Owner / Super Admin');

      // Ensure no default password was written to Firestore
      const doc = await testFirestore.collection('admin_members').doc('hello@truthworld.in').get();
      expect(doc.data()?.password).toBeUndefined();
    });

    it('sendAdminCredentials requires caller to be Super Admin or Owner', async () => {
      // Non-super admin caller (regular admin / moderator)
      const callPromise = (sendAdminCredentials as any).run({
        auth: {
          uid: 'usr_mod_99',
          token: { email: 'mod@truthworld.test', admin: true, role: 'Content Moderator' },
        },
        data: {
          email: 'newhire@truthworld.test',
          password: 'SecurePassword123!',
          role: 'Reviewer',
        },
      });

      await expect(callPromise).rejects.toThrow(/Super Admin or Owner privileges required/);
    });

    it('sendAdminCredentials never writes plaintext password to Firestore and does not overwrite existing user password', async () => {
      const existingEmail = 'existing.admin@truthworld.test';
      const existingUid = 'usr_exist_auth_12';

      // Pre-create user in Auth
      jest.spyOn(admin.auth(), 'getUserByEmail').mockResolvedValueOnce({
        uid: existingUid,
        email: existingEmail,
        displayName: 'Existing Admin',
      } as any);

      const updateUserSpy = jest.spyOn(admin.auth(), 'updateUser').mockResolvedValueOnce({} as any);

      // Invoke as Super Admin / Owner
      await (sendAdminCredentials as any).run({
        auth: {
          uid: 'owner_uid',
          token: { email: 'hello@truthworld.in', isDirector: true, admin: true },
        },
        data: {
          email: existingEmail,
          password: 'NewPlaintextPassword999!',
          name: 'Existing Admin Updated',
          role: 'Fact Checker',
        },
      });

      // Assert password was NOT passed to updateUser for existing user
      expect(updateUserSpy).toHaveBeenCalledWith(
        existingUid,
        expect.not.objectContaining({ password: expect.anything() })
      );

      // Assert password is NOT stored in admin_members Firestore document
      const memberDoc = await testFirestore.collection('admin_members').doc(existingEmail).get();
      expect(memberDoc.exists).toBe(true);
      expect(memberDoc.data()?.password).toBeUndefined();
    });
  });

  // =========================================================================
  // 3. TW-BACKEND-02, TW-BACKEND-05, TW-BACKEND-06 in cashfreeFunctions.ts
  // =========================================================================
  describe('3. TW-BACKEND-02, TW-BACKEND-05, TW-BACKEND-06 (cashfreeFunctions.ts)', () => {
    it('createCashfreeOrder strips client-supplied financial and quota overrides from metadata', async () => {
      jest.spyOn(CashfreeService, 'isConfigured').mockReturnValue(true);
      jest.spyOn(CashfreeService, 'createOrder').mockResolvedValueOnce({
        cf_order_id: 'cf_12345',
        payment_session_id: 'sess_12345',
        order_status: 'ACTIVE',
      } as any);

      const callerUid = 'usr_adv_101';
      await testFirestore.collection('users').doc(callerUid).set({
        displayName: 'Advertiser User',
        email: 'advertiser@truthworld.test',
      });

      const res = await (createCashfreeOrder as any).run({
        auth: { uid: callerUid, token: { email: 'advertiser@truthworld.test' } },
        data: {
          amount: 1180,
          currency: 'INR',
          purpose: 'advertiser_wallet',
          metadata: {
            netAmount: 999999, // Attempted tamper
            taxAmount: 0,      // Attempted tamper
            amountUSD: 50000,  // Attempted tamper
            gigabytes: 10000,  // Attempted tamper
            customBalance: 50000, // Attempted tamper
            channelId: 'chn_legit_1',
          },
        },
      });

      expect(res.success).toBe(true);

      // Verify stored order metadata in Firestore
      const orderDoc = await testFirestore.collection('payment_orders').doc(res.orderId).get();
      const storedMeta = orderDoc.data()?.metadata || {};
      expect(storedMeta.netAmount).toBeUndefined();
      expect(storedMeta.taxAmount).toBeUndefined();
      expect(storedMeta.amountUSD).toBeUndefined();
      expect(storedMeta.gigabytes).toBeUndefined();
      expect(storedMeta.customBalance).toBeUndefined();
      expect(storedMeta.channelId).toBe('chn_legit_1');
    });

    it('cashfreeWebhook rejects requests missing signature or timestamp headers unconditionally', async () => {
      const app = createTestApp(cashfreeWebhook);

      // Missing all signature headers
      const res1 = await request(app).post('/').send({ type: 'ORDER_PAID' });
      expect(res1.status).toBe(401);
      expect(res1.text).toContain('Missing webhook signature headers');

      // Missing timestamp header
      const res2 = await request(app)
        .post('/')
        .set('x-webhook-signature', 'some_sig')
        .send({ type: 'ORDER_PAID' });
      expect(res2.status).toBe(401);
      expect(res2.text).toContain('Missing webhook signature headers');
    });

    it('cashfreeHostedCheckout result view does NOT execute fulfillOrder', async () => {
      const app = createTestApp(cashfreeHostedCheckout);
      const orderId = 'cf_ord_view_only_123';
      const userId = 'usr_adv_202';

      // Seed order in payment_orders
      await testFirestore.collection('payment_orders').doc(orderId).set({
        orderId,
        userId,
        amount: 1180,
        currency: 'INR',
        purpose: 'advertiser_wallet',
        status: 'ACTIVE',
      });

      jest.spyOn(CashfreeService, 'isConfigured').mockReturnValue(true);
      jest.spyOn(CashfreeService, 'getOrder').mockResolvedValueOnce({
        order_id: orderId,
        order_status: 'PAID',
        order_amount: 1180,
        order_currency: 'INR',
      } as any);

      // Access hosted checkout return view
      const res = await request(app).get(`/?action=result&order_id=${orderId}`);
      expect(res.status).toBe(200);
      expect(res.text).toContain('Payment Successful');

      // Verify that fulfillOrder was NOT called by this unauthenticated view:
      // Status in payment_orders remains ACTIVE (not FULFILLED) and no balance credited
      const orderDoc = await testFirestore.collection('payment_orders').doc(orderId).get();
      expect(orderDoc.data()?.status).toBe('ACTIVE');

      const advDoc = await testFirestore.collection('advertiser_profiles').doc(userId).get();
      expect(advDoc.exists).toBe(false);
    });
  });

  // =========================================================================
  // 4. TW-BACKEND-07 in userManagement.ts
  // =========================================================================
  describe('4. TW-BACKEND-07 (userManagement.ts)', () => {
    it('moderateUser blocks moderation or deletion when target user is an administrator', async () => {
      const app = createTestApp(moderateUser);
      const targetAdminUid = 'admin_target_456';
      const targetAdminEmail = 'target.admin@truthworld.test';

      // Target is in admin_members
      await testFirestore.collection('admin_members').doc(targetAdminEmail).set({
        email: targetAdminEmail,
        uid: targetAdminUid,
        role: 'Content Moderator',
        status: 'active',
      });
      await testFirestore.collection('users').doc(targetAdminUid).set({
        email: targetAdminEmail,
        role: 'admin',
      });

      const res = await request(app)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({
          userId: targetAdminUid,
          action: 'ban',
          reason: 'Test ban attempt',
        });

      expect(res.status).toBe(403);
      expect(res.body.error).toContain('Cannot moderate or delete an administrator account');
    });

    it('consolidateUserAccounts requires verified email on both accounts before transferring channel ownership', async () => {
      const app = createTestApp(consolidateUserAccounts);
      const primaryUid = 'usr_primary_1';
      const legacyUid = 'usr_legacy_2';
      const channelId = 'chn_valuable_creator';
      const sharedEmail = 'duplicate@truthworld.test';

      // Primary user with unverified email
      await testFirestore.collection('users').doc(primaryUid).set({
        email: sharedEmail,
        displayName: 'Primary User',
      });

      // Legacy user who owns the channel with the same duplicate email
      await testFirestore.collection('users').doc(legacyUid).set({
        email: sharedEmail,
        displayName: 'Legacy User',
        channelId,
      });

      // Channel owned by legacy user
      await testFirestore.collection('channels').doc(channelId).set({
        ownerId: legacyUid,
        userId: legacyUid,
        name: 'Official Channel',
      });

      // Mock auth lookup: primary is unverified (emailVerified = false)
      jest.spyOn(admin.auth(), 'getUser').mockImplementation(async (uid: string) => {
        if (uid === primaryUid) {
          return { uid, email: sharedEmail, emailVerified: false } as any;
        }
        return { uid, email: sharedEmail, emailVerified: true } as any;
      });

      const res = await request(app)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({
          email: sharedEmail,
          primaryUid,
        });

      expect(res.status).toBe(403);
      expect(res.body.error).toContain('Both primary and secondary accounts must have verified email addresses');

      // Verify channel ownership was NOT transferred
      const channelDoc = await testFirestore.collection('channels').doc(channelId).get();
      expect(channelDoc.data()?.ownerId).toBe(legacyUid);
    });
  });

  // =========================================================================
  // 5. TW-BACKEND-08 in guestWatchLimit.ts
  // =========================================================================
  describe('5. TW-BACKEND-08 (guestWatchLimit.ts)', () => {
    it('getClientIp does not trust untrusted cf-connecting-ip or fastly-client-ip headers', () => {
      const spoofedReq = {
        headers: {
          'cf-connecting-ip': '198.51.100.77',      // Client spoof attempt
          'fastly-client-ip': '198.51.100.88',      // Client spoof attempt
          'x-forwarded-for': '203.0.113.195, 35.191.0.1', // True verified client IP before GCP proxy
        },
      };

      const resolved = getClientIp(spoofedReq);
      // Must resolve to 203.0.113.195 from verified proxy chain, NOT the spoofed headers
      expect(resolved).toBe('203.0.113.195');
      expect(resolved).not.toBe('198.51.100.77');
      expect(resolved).not.toBe('198.51.100.88');
    });
  });
});
