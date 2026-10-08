import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: parseInt(__ENV.VUS || '20', 10),
  duration: __ENV.DURATION || '15s',
  thresholds: {
    http_req_duration: ['p(95)<150', 'p(99)<300'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:5001/truthworld-1/asia-south1';

export default function () {
  const categories = ['All', 'Science', 'Technology', 'Economy'];
  const cat = categories[Math.floor(Math.random() * categories.length)];

  const res = http.get(`${BASE_URL}/publicFeedServer?category=${cat}&limit=20`);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'feed payload valid': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.feed);
      } catch {
        return false;
      }
    },
  });

  sleep(0.05);
}
