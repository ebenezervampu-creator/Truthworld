import http from 'k6/http';
import { check, sleep } from 'k6';
import crypto from 'k6/crypto';

export const options = {
  vus: parseInt(__ENV.VUS || '10', 10),
  duration: __ENV.DURATION || '10s',
  thresholds: {
    http_req_duration: ['p(95)<300', 'p(99)<600'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:5001/truthworld-1/asia-south1';

export default function () {
  const payload = JSON.stringify({
    type: 'TEST_WEBHOOK',
    event_time: new Date().toISOString(),
  });

  const timestamp = String(Math.floor(Date.now() / 1000));
  
  // Calculate valid HMAC signature for webhook
  const dataToSign = timestamp + payload;
  const signature = crypto.hmac('sha256', 'test_secret', dataToSign, 'base64');

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'x-webhook-timestamp': timestamp,
      'x-webhook-signature': signature,
    },
  };

  const res = http.post(`${BASE_URL}/cashfreeWebhook`, payload, params);

  check(res, {
    'receives HTTP response': (r) => r.status >= 200 && r.status < 500,
  });

  sleep(0.1);
}
