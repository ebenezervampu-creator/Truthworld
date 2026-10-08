import request from 'supertest';
import { moderateUser } from '../../src/admin/userManagement';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { TEST_USERS, authHeader, createMockToken } from '../helpers/authHelper';
import { buildUser } from '../factories/userFactory';

describe('API Integration: /moderateUser (Admin User Management)', () => {
  const app = createTestApp(moderateUser);

  beforeEach(() => {
    testFirestore.clear();
  });

  it('rejects unauthenticated requests with 401 Unauthorized', async () => {
    const res = await request(app)
      .post('/moderateUser')
      .send({ userId: 'usr_target', action: 'ban' });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('rejects non-admin users with 403 Forbidden', async () => {
    const res = await request(app)
      .post('/moderateUser')
      .set(authHeader(TEST_USERS.regular))
      .send({ userId: 'usr_target', action: 'ban' });

    expect(res.status).toBe(403);
    expect(res.body.error).toContain('Forbidden');
  });

  it('rejects missing required parameters with 400 Bad Request', async () => {
    const res = await request(app)
      .post('/moderateUser')
      .set(authHeader(TEST_USERS.admin))
      .send({ action: 'ban' }); // missing userId

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Missing required fields');
  });

  it('requires step-up re-authentication for high-impact destructive action (ban) on stale session', async () => {
    const staleAuthTime = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago (threshold is 1800s)
    const staleAdminToken = createMockToken({ ...TEST_USERS.admin, auth_time: staleAuthTime });

    const res = await request(app)
      .post('/moderateUser')
      .set({ authorization: `Bearer ${staleAdminToken}` })
      .send({ userId: 'usr_bad_actor', action: 'ban', reason: 'Deceptive manipulation' });

    expect(res.status).toBe(403);
    expect(res.body.code).toBe('AUTH_STEP_UP_REQUIRED');
  });

  it('successfully bans a user when recent admin credentials are provided', async () => {
    const target = buildUser({ id: 'usr_to_ban', role: 'user', accountStatus: 'ACTIVE' });
    await testFirestore.collection('users').doc(target.id).set(target);

    const recentAuthTime = Math.floor(Date.now() / 1000) - 60; // 1 minute ago
    const recentAdminToken = createMockToken({ ...TEST_USERS.admin, auth_time: recentAuthTime });

    const res = await request(app)
      .post('/moderateUser')
      .set({ authorization: `Bearer ${recentAdminToken}` })
      .send({
        userId: target.id,
        action: 'ban',
        reason: 'Violated TruthWorld verification policies',
        durationDays: 30,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.action).toBe('ban');

    // Verify Firestore updates
    const updatedDoc = await testFirestore.collection('users').doc(target.id).get();
    expect(updatedDoc.data()?.isBanned).toBe(true);
    expect(updatedDoc.data()?.accountStatus).toBe('BANNED');

    // Verify audit log entry
    const auditLogs = await testFirestore.collection('admin_actions_log').get();
    expect(auditLogs.size).toBe(1);
    expect(auditLogs.docs[0].data()?.action).toBe('ban');
    expect(auditLogs.docs[0].data()?.userId).toBe(target.id);
  });
});
