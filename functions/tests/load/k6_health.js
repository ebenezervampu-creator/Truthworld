import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: parseInt(__ENV.VUS || '10', 10),
  duration: __ENV.DURATION || '10s',
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<400'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:5001/truthworld-1/asia-south1';

export default function () {
  const res = http.get(`${BASE_URL}/cashfreeWebhook`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'health response ok': (r) => {
      try {
        return JSON.parse(r.body).status === 'ok';
      } catch {
        return false;
      }
    },
  });
  sleep(0.1);
}
