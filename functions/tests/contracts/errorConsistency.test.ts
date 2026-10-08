import { z } from 'zod';
import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { TEST_USERS, authHeader } from '../helpers/authHelper';

import { moderateUser, searchUsers } from '../../src/admin/userManagement';

const ErrorResponseSchema = z.object({
  error: z.string(),
}).passthrough();

describe('Error Response Consistency', () => {
  const modApp = createTestApp(moderateUser);
  const searchApp = createTestApp(searchUsers);

  it('401 errors have consistent shape across endpoints', async () => {
    const resMod = await request(modApp).post('/moderateUser').send({ userId: 'u1', action: 'warn' });
    const resSearch = await request(searchApp).post('/searchUsers').send({});

    expect(resMod.status).toBe(401);
    expect(resSearch.status).toBe(401);

    expect(ErrorResponseSchema.safeParse(resMod.body).success).toBe(true);
    expect(ErrorResponseSchema.safeParse(resSearch.body).success).toBe(true);
  });

  it('403 errors have consistent shape across endpoints', async () => {
    const resMod = await request(modApp)
      .post('/moderateUser')
      .set(authHeader(TEST_USERS.regular))
      .send({ userId: 'u1', action: 'warn' });
      
    const resSearch = await request(searchApp)
      .post('/searchUsers')
      .set(authHeader(TEST_USERS.regular))
      .send({});

    expect(resMod.status).toBe(403);
    expect(resSearch.status).toBe(403);

    expect(ErrorResponseSchema.safeParse(resMod.body).success).toBe(true);
    expect(ErrorResponseSchema.safeParse(resSearch.body).success).toBe(true);
  });

  it('400 errors have consistent shape across endpoints', async () => {
    const resMod = await request(modApp)
      .post('/moderateUser')
      .set(authHeader(TEST_USERS.admin))
      .send({ }); // missing required fields

    expect(resMod.status).toBe(400);
    expect(ErrorResponseSchema.safeParse(resMod.body).success).toBe(true);
  });

  it('errors never contain stack traces', async () => {
    const resMod = await request(modApp).post('/moderateUser').send({ userId: 'u1', action: 'warn' });
    
    expect(resMod.body).not.toHaveProperty('stack');
    expect(resMod.body).not.toHaveProperty('stackTrace');
    expect(resMod.body).not.toHaveProperty('exception');
  });
});
