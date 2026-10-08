import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { cashfreeWebhook } from '../../src/economy/cashfreeFunctions';
import { publicFeedServer } from '../../src/feed/publicFeedServer';
import { testFirestore } from '../helpers/mockFirestore';
import { verifyAuth } from '../../src/utils/auth';
import { TEST_USERS, createMockToken } from '../helpers/authHelper';
import { buildVideo } from '../factories/videoFactory';

describe('Post-Deployment Smoke Test Suite', () => {
  describe('1. Application Health Check', () => {
    it('verifies webhook / health ping endpoint responds with 200 OK', async () => {
      const app = createTestApp(cashfreeWebhook);
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
    });
  });

  describe('2. Database Connectivity Through Application', () => {
    it('verifies application can read and write to Firestore database', async () => {
      const pingDocId = 'smoke_ping_' + Date.now();
      await testFirestore.collection('_smoke_health').doc(pingDocId).set({
        status: 'UP',
        timestamp: new Date().toISOString(),
      });

      const snap = await testFirestore.collection('_smoke_health').doc(pingDocId).get();
      expect(snap.exists).toBe(true);
      expect(snap.data()?.status).toBe('UP');

      // Cleanup ping doc
      await testFirestore.collection('_smoke_health').doc(pingDocId).delete();
    });
  });

  describe('3. Public Read Endpoint', () => {
    it('verifies public feed server responds with valid feed array', async () => {
      // Seed a public video
      const v = buildVideo({ id: 'v_smoke_test' });
      await testFirestore.collection('videos').doc(v.id).set(v);

      const app = createTestApp(publicFeedServer);
      const res = await request(app).get('/api/feed?limit=5');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('feed');
      expect(Array.isArray(res.body.feed)).toBe(true);
    });
  });

  describe('4. Authentication Flow Verification', () => {
    it('verifies auth verification helper decodes valid credentials correctly', async () => {
      const token = createMockToken(TEST_USERS.regular);
      const req: any = { headers: { authorization: `Bearer ${token}` } };
      const user = await verifyAuth(req);
      expect(user).not.toBeNull();
      expect(user?.uid).toBe(TEST_USERS.regular.uid);
    });
  });
});
