/**
 * 📦 TEST PAYLOAD FIXTURES
 * Static reusable sample payloads for unit, integration, and security tests.
 */

import * as crypto from 'crypto';

export function createValidWebhookPayload(
  orderId: string = 'cf_ord_sample_123',
  amount: number = 50,
  secretKey: string = 'test_mock_secret_key_truthworld_12345',
  timestampSec: number = Math.floor(Date.now() / 1000)
) {
  const body = {
    data: {
      order: {
        order_id: orderId,
        order_amount: amount,
        order_currency: 'INR',
      },
      payment: {
        payment_status: 'SUCCESS',
        cf_payment_id: 'cf_pay_999888',
        payment_time: new Date().toISOString(),
      },
    },
    event_time: new Date().toISOString(),
    type: 'PAYMENT_SUCCESS_WEBHOOK',
  };

  const rawBody = JSON.stringify(body);
  const signaturePayload = `${timestampSec}${rawBody}`;
  const signature = crypto
    .createHmac('sha256', secretKey)
    .update(signaturePayload)
    .digest('base64');

  return {
    body,
    rawBody,
    timestamp: String(timestampSec),
    signature,
  };
}

export const SAMPLE_USER_MODERATION = {
  validBan: {
    userId: 'usr_bad_actor_909',
    action: 'ban',
    reason: 'Repeated deceptive manipulation violation',
    durationDays: 30,
  },
  validUnban: {
    userId: 'usr_reformed_909',
    action: 'unban',
    reason: 'Successful epistemic appeal',
  },
  validDelete: {
    userId: 'usr_to_delete_909',
    action: 'delete',
    reason: 'GDPR right to be forgotten',
  },
  missingAction: {
    userId: 'usr_target_909',
  },
  missingUserId: {
    action: 'ban',
  },
};
