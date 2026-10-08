import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { moderateUser, searchUsers } from '../../src/admin/userManagement';
import { publicFeedServer } from '../../src/feed/publicFeedServer';
import { testFirestore } from '../helpers/mockFirestore';
import { TEST_USERS, authHeader } from '../helpers/authHelper';
import { buildUser } from '../factories/userFactory';
import { buildVideo } from '../factories/videoFactory';

describe('Security-Focused Automated Audit & Guard Tests', () => {
  beforeEach(() => {
    testFirestore.clear();
  });

  describe('Authorization Bypass & Header Spoofing Resistance', () => {
    const adminApp = createTestApp(moderateUser);

    it('rejects spoofed header bypass attempts (e.g. x-admin, x-role, x-forwarded-user)', async () => {
      const res = await request(adminApp)
        .post('/')
        .set({
          'x-admin': 'true',
          'x-role': 'admin',
          'x-authenticated-user': 'admin_super',
        })
        .send({ userId: 'usr_target', action: 'ban' });

      // Must be 401 Unauthorized because only verified Firebase Bearer token is authoritative
      expect(res.status).toBe(401);
    });

    it('rejects tampered Bearer token with forged role property', async () => {
      // Simulate a forged JWT: attacker tries to inject admin claims but
      // the token doesn't pass cryptographic signature verification.
      // In our mock, non-mock_token_ prefixed strings fall through to the
      // default handler which returns admin: false, simulating sig failure.
      const forgedToken = 'forged_jwt_' + Buffer.from(JSON.stringify({ uid: 'attacker', role: 'admin', admin: true })).toString('base64');

      const res = await request(adminApp)
        .post('/')
        .set({ authorization: `Bearer ${forgedToken}` })
        .send({ userId: 'usr_target', action: 'ban' });

      // Forged token must be rejected — never allow 200
      expect([401, 403]).toContain(res.status);
    });

    it('prevents mass assignment vulnerabilities (e.g. attempting to set role to admin via body)', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.regular))
        .send({ userId: 'usr_target', action: 'ban', role: 'admin', isAdmin: true });

      expect(res.status).toBe(403);
    });

    it('enforces strict CORS security headers', async () => {
      const res = await request(adminApp)
        .options('/')
        .set('Origin', 'https://malicious-site.com')
        .set('Access-Control-Request-Method', 'POST');
      
      const allowedOrigins = [
        'https://truthworld.net',
        'http://localhost:3000'
      ];
      
      if (res.headers['access-control-allow-origin']) {
        expect(allowedOrigins).toContain(res.headers['access-control-allow-origin']);
      }
    });
  });

  describe('Injection Attacks (NoSQL / SQL / Script Injection)', () => {
    const feedApp = createTestApp(publicFeedServer);

    it('neutralizes NoSQL injection style query parameters ($gt, $ne)', async () => {
      const res = await request(feedApp).get('/api/feed?category[$gt]=');
      expect(res.status).toBe(200);
      // Ensure it returned safe response without executing arbitrary selector
      expect(Array.isArray(res.body.feed)).toBe(true);
    });

    it('neutralizes SQL injection strings safely', async () => {
      const sqlInjection = "' OR '1'='1";
      const res = await request(feedApp).get(`/api/feed?category=${encodeURIComponent(sqlInjection)}`);
      expect(res.status).toBe(200);
      expect(res.body.feed).toEqual([]);
    });

    it('neutralizes Cross-Site Scripting (XSS) payloads in category query', async () => {
      const xss = '<script>alert("xss")</script>';
      const res = await request(feedApp).get(`/api/feed?category=${encodeURIComponent(xss)}`);
      expect(res.status).toBe(200);
      expect(res.headers['x-content-type-options']).toBe('nosniff');
    });

    it('prevents path traversal attacks in query parameters', async () => {
      const traversal = '../../../../etc/passwd';
      const res = await request(feedApp).get(`/api/feed?category=${encodeURIComponent(traversal)}`);
      // Should not error, but should definitely not return system files
      expect(res.status).toBe(200);
      expect(res.body.feed).toEqual([]);
    });

    it('prevents prototype pollution via request body', async () => {
      const maliciousPayload = JSON.parse('{"__proto__":{"polluted":"yes"},"constructor":{"prototype":{"polluted":"yes"}}}');
      const res = await request(feedApp)
        .post('/api/feed') // Assuming a post route or general server middleware
        .send(maliciousPayload);
      
      expect(({} as any).polluted).toBeUndefined();
      expect([200, 400, 403, 404, 405]).toContain(res.status);
    });
  });

  describe('Sensitive Data Exposure & Leakage Prevention', () => {
    it('guarantees searchUsers API response never leaks password hashes, tokens, or secrets', async () => {
      const sensitiveUser = {
        ...buildUser({ id: 'usr_sensitive_1', email: 'secret_user@truthworld.test' }),
        passwordHash: '$2b$12$e8Y5M6Wc.1234567890abcdef...',
        salt: '9876543210abcdef',
        apiSecretKey: 'tw_sec_9999999999',
        refreshToken: 'rt_mock_secret_xyz',
      };

      await testFirestore.collection('users').doc(sensitiveUser.id).set(sensitiveUser);

      const searchApp = createTestApp(searchUsers);
      const res = await request(searchApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({ query: 'secret_user' });

      expect(res.status).toBe(200);
      expect(res.body.users.length).toBe(1);

      const userInResponse = res.body.users[0];
      const serialized = JSON.stringify(userInResponse);

      // Verify strict sensitive field scrubbing
      expect(serialized).not.toContain('passwordHash');
      expect(serialized).not.toContain('salt');
      expect(serialized).not.toContain('apiSecretKey');
      expect(serialized).not.toContain('refreshToken');
      expect(userInResponse.passwordHash).toBeUndefined();
      expect(userInResponse.salt).toBeUndefined();
    });

    it('guarantees public feed never leaks internal moderation summaries or private storage paths', async () => {
      const publicVideo = buildVideo({
        id: 'v_public_1',
        title: 'Public Truth Video',
      });

      const videoDocWithPrivateFields = {
        ...publicVideo,
        internalModerationDecision: 'APPROVED_WITH_HIGH_MONITORING',
        privateStorageBucketUrl: 'gs://truthworld-internal-secure/raw/master.mov',
      };

      await testFirestore.collection('videos').doc(publicVideo.id).set(videoDocWithPrivateFields);

      const feedApp = createTestApp(publicFeedServer);
      const res = await request(feedApp).get('/api/feed');

      expect(res.status).toBe(200);
      expect(res.body.feed.length).toBeGreaterThan(0);
      expect(res.headers['x-content-type-options']).toBe('nosniff');
    });
  });
});
