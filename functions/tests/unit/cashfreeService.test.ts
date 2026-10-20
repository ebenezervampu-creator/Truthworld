import * as crypto from 'crypto';
import { CashfreeService } from '../../src/services/cashfreeService';

describe('Unit: Cashfree Payment Gateway Service', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  describe('Environment Resolution', () => {
    it('resolves to SANDBOX when CASHFREE_ENV=SANDBOX', () => {
      process.env.CASHFREE_ENV = 'SANDBOX';
      expect(CashfreeService.PublicEnvironment).toBe('SANDBOX');
    });

    it('resolves to PRODUCTION when CASHFREE_ENV=PRODUCTION', () => {
      process.env.CASHFREE_ENV = 'PRODUCTION';
      expect(CashfreeService.PublicEnvironment).toBe('PRODUCTION');
    });

    it('auto-detects SANDBOX when App ID starts with TEST', () => {
      delete process.env.CASHFREE_ENV;
      process.env.CASHFREE_APP_ID = 'TEST1023456789';
      expect(CashfreeService.PublicEnvironment).toBe('SANDBOX');
    });

    it('auto-detects PRODUCTION when App ID does not start with TEST', () => {
      delete process.env.CASHFREE_ENV;
      process.env.CASHFREE_APP_ID = 'PROD_MERCHANT_APP_ID';
      expect(CashfreeService.PublicEnvironment).toBe('PRODUCTION');
    });
  });

  describe('Cryptographic Webhook Signature Verification', () => {
    const testSecret = 'test_secret_key_truthworld_12345';

    beforeEach(() => {
      process.env.CASHFREE_SECRET_KEY = testSecret;
    });

    it('successfully verifies a valid HMAC-SHA256 signature', () => {
      const timestamp = String(Math.floor(Date.now() / 1000));
      const rawBody = JSON.stringify({
        data: {
          order: { order_id: 'cf_order_001', order_amount: 100 },
          payment: { payment_status: 'SUCCESS' },
        },
      });

      const signature = crypto
        .createHmac('sha256', testSecret)
        .update(timestamp + rawBody)
        .digest('base64');

      const isValid = CashfreeService.verifyWebhookSignature(signature, rawBody, timestamp);
      expect(isValid).toBe(true);
    });

    it('rejects a tampered body payload', () => {
      const timestamp = String(Math.floor(Date.now() / 1000));
      const rawBody = JSON.stringify({ order_id: 'legit_order', amount: 100 });
      const tamperedBody = JSON.stringify({ order_id: 'legit_order', amount: 10 }); // altered amount

      const signature = crypto
        .createHmac('sha256', testSecret)
        .update(timestamp + rawBody)
        .digest('base64');

      const isValid = CashfreeService.verifyWebhookSignature(signature, tamperedBody, timestamp);
      expect(isValid).toBe(false);
    });

    it('rejects malformed or empty signatures safely without throwing', () => {
      expect(CashfreeService.verifyWebhookSignature('', '{}', '12345')).toBe(false);
      expect(CashfreeService.verifyWebhookSignature('invalid_sig', '{}', '12345')).toBe(false);
    });
  });

  describe('Customer Data Sanitization', () => {
    it('sanitizes customer phone numbers to 10 digits or fallback', () => {
      const cleaned = CashfreeService.cleanPhoneNumber('+91 98765 43210');
      expect(cleaned).toBe('9876543210');

      const fallback = CashfreeService.cleanPhoneNumber('');
      expect(fallback).toBe('9999999999');
    });

    it('sanitizes customer email or falls back to system email', () => {
      const valid = CashfreeService.cleanEmail('  User.Test+sub@TruthWorld.in  ');
      expect(valid).toBe('user.test+sub@truthworld.in');

      const invalid = CashfreeService.cleanEmail('not-an-email');
      expect(invalid).toBe('user@truthworld.tv');
    });

    it('sanitizes customer ID to safe characters and enforces length limits', () => {
      const cleaned = CashfreeService.cleanCustomerId('user!@#$123');
      expect(cleaned).toBe('user123');

      const fallback = CashfreeService.cleanCustomerId('');
      expect(fallback).toBe('cust_user');
    });

    it('sanitizes customer names stripping emojis and invalid characters', () => {
      const emojiName = CashfreeService.cleanCustomerName('John Doe 🔥🚀 (Admin)');
      expect(emojiName).toBe('John Doe Admin');

      const emptyName = CashfreeService.cleanCustomerName('');
      expect(emptyName).toBe('TruthWorld User');
    });

    it('sanitizes order notes stripping emojis and keeping length within bounds', () => {
      const emojiNote = CashfreeService.cleanOrderNote('Superchat on Live Stream 🔴 with $10 USD!');
      expect(emojiNote).toBe('Superchat on Live Stream with 10 USD');

      const emptyNote = CashfreeService.cleanOrderNote('');
      expect(emptyNote).toBe('TruthWorld Payment');
    });
  });
});
