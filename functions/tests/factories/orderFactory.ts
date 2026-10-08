/**
 * 🏭 PAYMENT ORDER FACTORY
 * Creates standardized Cashfree payment orders for financial lifecycle tests.
 */

export interface TestOrder {
  orderId: string;
  userId: string;
  amount: number;
  currency: string;
  status: 'PENDING' | 'PAID' | 'FULFILLED' | 'FAILED' | 'CANCELLED';
  purpose: 'channel_membership' | 'premium_subscription' | 'superchat';
  metadata?: Record<string, any>;
  createdAt: any;
  fulfilledAt?: any;
}

export function buildOrder(overrides: Partial<TestOrder> = {}): TestOrder {
  const orderId = overrides.orderId || `cf_ord_${Math.random().toString(36).substring(2, 10)}`;
  return {
    orderId,
    userId: overrides.userId || 'usr_payer_777',
    // Rule compliant: honest round numbers, zero charm pricing
    amount: overrides.amount ?? 50,
    currency: overrides.currency || 'INR',
    status: overrides.status || 'PENDING',
    purpose: overrides.purpose || 'channel_membership',
    metadata: overrides.metadata || { channelId: 'chn_target_1', tierId: 'tier_supporter' },
    createdAt: overrides.createdAt || new Date().toISOString(),
    ...overrides,
  };
}
