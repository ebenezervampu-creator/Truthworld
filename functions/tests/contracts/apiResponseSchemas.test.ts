import { z } from 'zod';
import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { TEST_USERS, authHeader, createMockToken } from '../helpers/authHelper';
import { buildVideo } from '../factories/videoFactory';
import { buildUser } from '../factories/userFactory';

// Import handlers
import { publicFeedServer } from '../../src/feed/publicFeedServer';
import { cashfreeWebhook } from '../../src/economy/cashfreeFunctions';
import { moderateUser, searchUsers } from '../../src/admin/userManagement';

// 1. Schemas
const FeedVideoSchema = z.object({
  id: z.string(),
}).passthrough();

const FeedResponseSchema = z.object({
  feed: z.array(FeedVideoSchema),
  count: z.number(),
  category: z.string(),
  cachedAt: z.string(),
  edgeServed: z.boolean(),
}).passthrough();

const WebhookHealthSchema = z.object({
  status: z.literal('ok'),
  message: z.string(),
});

const UserSearchSchema = z.object({
  users: z.array(z.object({
    id: z.string(),
    email: z.string(),
    displayName: z.string().optional(),
    role: z.string().optional(),
    accountStatus: z.string().optional(),
    hasChannel: z.boolean().optional(),
    createdAt: z.any().optional(),
  }).passthrough()),
  nextCursor: z.string().nullable().optional()
}).passthrough();

const ModerationResponseSchema = z.object({
  success: z.boolean(),
  action: z.string(),
  userId: z.string(),
}).passthrough();

const ErrorResponseSchema = z.object({
  error: z.string(),
}).passthrough();

describe('API Response Schema Contracts', () => {
  beforeEach(async () => {
    // Clear handled by setup.ts
  });

  describe('GET /api/feed', () => {
    const app = createTestApp(publicFeedServer);

    it('matches FeedResponseSchema', async () => {
      await testFirestore.collection('videos').doc('v1').set(buildVideo({ status: 'published', visibility: 'public', title: 'Video 1' }));

      const res = await request(app).get('/api/feed');
      expect(res.status).toBe(200);
      
      const parseResult = FeedResponseSchema.safeParse(res.body);
      expect(parseResult.success).toBe(true);
    });
  });

  describe('GET /', () => {
    const app = createTestApp(cashfreeWebhook);

    it('matches WebhookHealthSchema', async () => {
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      
      const parseResult = WebhookHealthSchema.safeParse(res.body);
      expect(parseResult.success).toBe(true);
    });
  });

  describe('POST /searchUsers', () => {
    const app = createTestApp(searchUsers);

    it('matches UserSearchSchema without sensitive fields', async () => {
      await testFirestore.collection('users').doc('u1').set({
        ...buildUser({ email: 'test@example.com', displayName: 'Test' }),
        passwordHash: 'secret',
      });

      const res = await request(app)
        .post('/searchUsers')
        .set(authHeader(TEST_USERS.admin))
        .send({ query: 'test', limit: 10 });
      
      expect(res.status).toBe(200);
      
      const parseResult = UserSearchSchema.safeParse(res.body);
      expect(parseResult.success).toBe(true);
      
      if (res.body.users && res.body.users.length > 0) {
        expect(res.body.users[0]).not.toHaveProperty('passwordHash');
        expect(res.body.users[0]).not.toHaveProperty('apiSecretKey');
        expect(res.body.users[0]).not.toHaveProperty('refreshToken');
        expect(res.body.users[0]).not.toHaveProperty('salt');
      }
    });
  });

  describe('POST /moderateUser', () => {
    const app = createTestApp(moderateUser);

    it('matches ModerationResponseSchema', async () => {
      await testFirestore.collection('users').doc('u2').set(buildUser({ id: 'u2' }));

      const recentAdminToken = createMockToken({
        ...TEST_USERS.admin,
        auth_time: Math.floor(Date.now() / 1000) - 30,
      });

      const res = await request(app)
        .post('/moderateUser')
        .set({ authorization: `Bearer ${recentAdminToken}` })
        .send({ userId: 'u2', action: 'warn' });
      
      expect(res.status).toBe(200);
      
      const parseResult = ModerationResponseSchema.safeParse(res.body);
      expect(parseResult.success).toBe(true);
    });
    
    it('matches ErrorResponseSchema for unauthorized request', async () => {
      const res = await request(app)
        .post('/moderateUser')
        .send({ userId: 'u2', action: 'warn' });
      
      expect(res.status).toBe(401);
      
      const parseResult = ErrorResponseSchema.safeParse(res.body);
      expect(parseResult.success).toBe(true);
      expect(res.body).not.toHaveProperty('stack');
    });
    
    it('matches ErrorResponseSchema for forbidden request', async () => {
      const res = await request(app)
        .post('/moderateUser')
        .set(authHeader(TEST_USERS.regular))
        .send({ userId: 'u2', action: 'warn' });
      
      expect(res.status).toBe(403);
      
      const parseResult = ErrorResponseSchema.safeParse(res.body);
      expect(parseResult.success).toBe(true);
      expect(res.body).not.toHaveProperty('stack');
    });
  });
});
