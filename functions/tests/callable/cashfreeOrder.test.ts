import { callOnCall, authCallableContext, anonCallableContext } from '../helpers/callableHelper';
import { createCashfreeOrder } from '../../src/economy/cashfreeFunctions';
import { CashfreeService } from '../../src/services/cashfreeService';
import { TEST_USERS } from '../helpers/authHelper';
import { HttpsError } from 'firebase-functions/v2/https';

jest.mock('../../src/services/cashfreeService', () => {
  return {
    CashfreeService: {
      isConfigured: jest.fn().mockReturnValue(true),
      sanitizeOrderTags: jest.fn().mockImplementation((tags) => tags),
      createSubscriptionPlan: jest.fn().mockResolvedValue({}),
      createSubscription: jest.fn().mockResolvedValue({
        auth_link: 'https://test.auth.link',
        payment_session_id: 'sub_sess_123',
        sub_reference_id: 'sub_ref_123',
        subscription_status: 'INITIALIZED'
      }),
      createOrder: jest.fn().mockResolvedValue({
        cf_order_id: 'cf_12345',
        payment_session_id: 'sess_12345'
      }),
      PublicEnvironment: 'TEST'
    }
  };
});

describe('Callable: createCashfreeOrder', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should throw unauthenticated if not logged in', async () => {
    const context = anonCallableContext({
      amount: 100,
      purpose: 'superchat'
    });
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toThrow(HttpsError);
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toMatchObject({
      code: 'unauthenticated'
    });
  });

  it('should throw invalid-argument for amount less than 1', async () => {
    const context = authCallableContext(TEST_USERS.regular, {
      amount: 0.5,
      purpose: 'superchat'
    });
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toThrow(HttpsError);
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toMatchObject({
      code: 'invalid-argument'
    });
  });

  it('should throw invalid-argument for amount greater than 500000', async () => {
    const context = authCallableContext(TEST_USERS.regular, {
      amount: 600000,
      purpose: 'superchat'
    });
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toThrow(HttpsError);
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toMatchObject({
      code: 'invalid-argument'
    });
  });

  it('should throw invalid-argument when purpose is missing', async () => {
    const context = authCallableContext(TEST_USERS.regular, {
      amount: 100
    });
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toThrow(HttpsError);
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toMatchObject({
      code: 'invalid-argument'
    });
  });

  it('should throw invalid-argument for unsupported purpose', async () => {
    const context = authCallableContext(TEST_USERS.regular, {
      amount: 100,
      purpose: 'invalid_purpose'
    });
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toThrow(HttpsError);
    await expect(callOnCall(createCashfreeOrder, context)).rejects.toMatchObject({
      code: 'invalid-argument'
    });
  });

  it('should successfully create order for a valid purpose using standard PG', async () => {
    const context = authCallableContext(TEST_USERS.regular, {
      amount: 50,
      purpose: 'superchat'
    });
    const result = await callOnCall(createCashfreeOrder, context);
    expect(result.success).toBe(true);
    expect(result.orderId).toBeDefined();
    expect(result.paymentSessionId).toBe('sess_12345');
    expect(CashfreeService.createOrder).toHaveBeenCalled();
  });

  it('should successfully create order using subscription AutoPay mandate', async () => {
    const context = authCallableContext(TEST_USERS.regular, {
      amount: 200,
      purpose: 'premium_subscription',
      metadata: { autoPay: true, planId: 'individual_monthly' }
    });
    const result = await callOnCall(createCashfreeOrder, context);
    expect(result.success).toBe(true);
    expect(result.isSubscription).toBe(true);
    expect(result.subscriptionId).toBeDefined();
    expect(CashfreeService.createSubscription).toHaveBeenCalled();
  });
});
