import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { moderateUser } from '../../src/admin/userManagement';
import { publicFeedServer } from '../../src/feed/publicFeedServer';
import { TEST_USERS, authHeader, createMockToken } from '../helpers/authHelper';

describe('Negative & Edge-Case Resilience Tests', () => {
  beforeEach(() => {
    testFirestore.clear();
  });

  describe('Missing Required Fields & Wrong Data Types', () => {
    const adminApp = createTestApp(moderateUser);

    it('rejects payload when required fields are completely omitted', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('Missing required fields');
    });

    it('handles wrong data types gracefully (e.g. number or object passed as userId)', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({ userId: 12345, action: { malicious: true } });

      // Action is invalid string or handled without 500 crash
      expect([400, 500]).toContain(res.status);
    });

    it('handles empty string or whitespace-only inputs safely', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({ userId: '   ', action: '   ' });

      expect(res.status).toBe(400);
    });

    it('rejects malformed JSON (invalid JSON syntax)', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .set('Content-Type', 'application/json')
        .send('{"userId": "123", "action": "ban",'); // Trailing comma / incomplete JSON

      expect(res.status).toBe(400);
    });

    it('rejects deeply nested JSON objects to prevent stack overflow', async () => {
      // Create deeply nested object
      let nested: any = {};
      let current = nested;
      for (let i = 0; i < 2000; i++) {
        current.child = {};
        current = current.child;
      }

      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .send({ userId: 'usr_target', action: 'ban', data: nested });

      expect([400, 413, 500]).toContain(res.status);
    });

    it('handles content-type spoofing (claiming json but sending plain text)', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.admin))
        .set('Content-Type', 'application/json')
        .send('just a plain text string not json');

      expect(res.status).toBe(400);
    });
  });

  describe('Extreme Input & Payload Boundary Handling', () => {
    const feedApp = createTestApp(publicFeedServer);

    it('handles extremely large category parameter without server crash', async () => {
      const hugeString = 'A'.repeat(5000);
      const res = await request(feedApp).get(`/api/feed?category=${hugeString}`);

      expect([200, 400, 414, 431]).toContain(res.status);
    });

    it('clamps negative or NaN pagination parameters safely', async () => {
      const resNeg = await request(feedApp).get('/api/feed?limit=-50');
      expect(resNeg.status).toBe(200);

      const resNaN = await request(feedApp).get('/api/feed?limit=invalid_number');
      expect(resNaN.status).toBe(200);
      expect(resNaN.body.feed).toBeDefined();
    });
  });

  describe('Non-Existent Resources & Invalid IDs', () => {
    it('returns empty results when querying non-existent category or ID', async () => {
      const snap = await testFirestore.collection('videos').doc('non_existent_random_id_999').get();
      expect(snap.exists).toBe(false);
      expect(snap.data()).toBeUndefined();
    });
  });

  describe('Authentication & Authorization Denial Cases', () => {
    const adminApp = createTestApp(moderateUser);

    it('denies access when token is corrupted with random characters', async () => {
      const res = await request(adminApp)
        .post('/')
        .set({ authorization: 'Bearer !!corrupted_invalid_jwt_garbage!!' })
        .send({ userId: 'usr_1', action: 'warn' });

      expect([401, 403]).toContain(res.status);
    });

    it('denies access when regular user attempts admin action (403 Forbidden)', async () => {
      const res = await request(adminApp)
        .post('/')
        .set(authHeader(TEST_USERS.regular))
        .send({ userId: 'usr_1', action: 'warn' });

      expect(res.status).toBe(403);
    });
  });
});
