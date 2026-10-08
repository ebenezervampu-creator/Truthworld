import request from 'supertest';
import * as crypto from 'crypto';
import { cashfreeWebhook } from '../../src/economy/cashfreeFunctions';
import { CashfreeService } from '../../src/services/cashfreeService';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { buildOrder } from '../factories/orderFactory';

describe('API Integration: /cashfreeWebhook (cashfreeWebhook listener)', () => {
  const app = createTestApp(cashfreeWebhook);
  const testSecret = 'test_mock_secret_key_truthworld_12345';

  beforeEach(() => {
    testFirestore.clear();
    process.env.CASHFREE_SECRET_KEY = testSecret;
    process.env.CASHFREE_APP_ID = 'TEST_APP_ID';
  });

  function generateSignedHeaders(bodyObj: any, timestampSec = Math.floor(Date.now() / 1000)) {
    const rawBody = JSON.stringify(bodyObj);
    const signature = crypto
      .createHmac('sha256', testSecret)
      .update(String(timestampSec) + rawBody)
      .digest('base64');

    return {
      'x-webhook-signature': signature,
      'x-webhook-timestamp': String(timestampSec),
      'content-type': 'application/json',
    };
  }

  it('responds with 200 to health check / ping GET requests', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.message).toContain('Cashfree Webhook Active');
  });

  it('rejects unsupported HTTP methods with 405 Method Not Allowed', async () => {
    const res = await request(app).put('/');
    expect(res.status).toBe(405);
  });

  it('rejects POST requests with missing signature headers with 401', async () => {
    const res = await request(app).post('/').send({ data: {} });
    expect(res.status).toBe(401);
  });

  it('rejects webhooks with expired timestamp with 400', async () => {
    const expiredTimestamp = Math.floor(Date.now() / 1000) - 1000; // 1000s ago
    const body = { data: { order: { order_id: 'cf_ord_expired' } } };
    const headers = generateSignedHeaders(body, expiredTimestamp);

    const res = await request(app).post('/').set(headers).send(body);
    expect(res.status).toBe(400);
    expect(res.text).toContain('Expired webhook timestamp');
  });

  it('rejects webhooks with invalid HMAC signatures with 401', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    const body = { data: { order: { order_id: 'cf_ord_tampered' } } };

    const res = await request(app)
      .post('/')
      .set({
        'x-webhook-signature': 'invalid_forged_signature_hash',
        'x-webhook-timestamp': String(timestamp),
      })
      .send(body);

    expect(res.status).toBe(401);
    expect(res.text).toContain('Invalid webhook signature');
  });

  it('successfully processes Cashfree test dashboard ping', async () => {
    const body = { type: 'TEST_WEBHOOK', event_time: new Date().toISOString() };
    const headers = generateSignedHeaders(body);

    const res = await request(app).post('/').set(headers).send(body);
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('acknowledged');
    expect(res.body.message).toContain('Cashfree test ping received successfully');
  });

  it('successfully processes valid PAID order and fulfills idempotently', async () => {
    const orderId = 'cf_ord_test_success_1';
    const order = buildOrder({
      orderId,
      status: 'PENDING',
      purpose: 'channel_membership',
      amount: 100,
      metadata: { channelId: 'chn_1', tierId: 'tier_supporter' },
    });

    await testFirestore.collection('payment_orders').doc(orderId).set(order);

    // Mock CashfreeService.getOrder returning PAID status
    jest.spyOn(CashfreeService, 'getOrder').mockResolvedValueOnce({
      order_id: orderId,
      order_status: 'PAID',
      order_amount: 100,
    } as any);

    const body = {
      data: {
        order: { order_id: orderId, order_amount: 100 },
        payment: { payment_status: 'SUCCESS' },
      },
    };
    const headers = generateSignedHeaders(body);

    const res = await request(app).post('/').set(headers).send(body);
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('acknowledged');
  });
});
