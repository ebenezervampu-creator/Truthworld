import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: parseInt(__ENV.VUS || '10', 10),
  duration: __ENV.DURATION || '10s',
  thresholds: {
    http_req_duration: ['p(95)<250', 'p(99)<500'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:5001/truthworld-1/asia-south1';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'mock_bearer_token_for_load_testing';

export default function () {
  const payload = JSON.stringify({
    query: 'science',
    limit: 10,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${AUTH_TOKEN}`,
    },
  };

  const res = http.post(`${BASE_URL}/searchUsers`, payload, params);

  check(res, {
    'auth handled': (r) => r.status === 200,
  });

  sleep(0.1);
}
