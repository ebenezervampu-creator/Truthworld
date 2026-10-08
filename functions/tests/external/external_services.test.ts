import axios from 'axios';
import { CashfreeService } from '../../src/services/cashfreeService';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('External Services & Third-Party Integration Tests', () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    process.env.CASHFREE_APP_ID = 'TEST_CLIENT_ID_101';
    process.env.CASHFREE_SECRET_KEY = 'TEST_SECRET_KEY_101';
    process.env.CASHFREE_ENV = 'SANDBOX';
    jest.clearAllMocks();
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('Payment Gateway External API (Cashfree)', () => {
    const sampleOrderParams = {
      orderId: 'cf_ord_ext_test_1',
      orderAmount: 50,
      customerDetails: {
        customer_id: 'cust_ext_1',
        customer_email: 'payer@truthworld.test',
        customer_phone: '9876543210',
      },
    };

    it('handles successful payment gateway order creation response', async () => {
      mockedAxios.post.mockResolvedValueOnce({
        status: 200,
        data: {
          cf_order_id: '12345678',
          order_id: sampleOrderParams.orderId,
          order_amount: 50,
          order_currency: 'INR',
          order_status: 'ACTIVE',
          payment_session_id: 'session_mock_xyz123',
        },
      });

      const response = await CashfreeService.createOrder(sampleOrderParams);

      expect(response).toBeDefined();
      expect(response.order_status).toBe('ACTIVE');
      expect(response.payment_session_id).toBe('session_mock_xyz123');
      expect(mockedAxios.post).toHaveBeenCalledTimes(1);
    });

    it('handles rejected / invalid requests from payment provider with clean error', async () => {
      const providerError: any = new Error('Request failed with status code 400');
      providerError.response = {
        status: 400,
        data: {
          message: 'Order amount is below minimum permissible value',
          code: 'order_amount_invalid',
        },
      };

      mockedAxios.post.mockRejectedValueOnce(providerError);

      await expect(CashfreeService.createOrder(sampleOrderParams)).rejects.toThrow();
    });

    it('handles network timeouts from payment gateway', async () => {
      const timeoutError: any = new Error('timeout of 10000ms exceeded');
      timeoutError.code = 'ECONNABORTED';

      mockedAxios.post.mockRejectedValueOnce(timeoutError);

      await expect(CashfreeService.createOrder(sampleOrderParams)).rejects.toThrow();
    });

    it('handles malformed provider responses gracefully', async () => {
      // Gateway returns non-JSON or corrupted response
      mockedAxios.post.mockResolvedValueOnce({
        status: 200,
        data: null,
      });

      const res = await CashfreeService.createOrder(sampleOrderParams);
      expect(res).toBeNull();
    });
  });
});
