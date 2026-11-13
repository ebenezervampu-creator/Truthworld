import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom SLA & Edge Performance Metrics
export const edgeHitRate = new Rate('edge_hit_rate');
export const l1HitRate = new Rate('l1_hit_rate');
export const conditional304Rate = new Rate('conditional_304_rate');
export const edgeLatencyTrend = new Trend('edge_latency_ms');

export const options = {
  stages: [
    { duration: '15s', target: 20 },  // Stage 1: 20 VUs baseline / warm-up
    { duration: '30s', target: 100 }, // Stage 2: 100 VUs peak concurrency stress
    { duration: '10s', target: 10 },  // Stage 3: Cooldown ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<100', 'p(99)<250'], // Global edge latency budget
    http_req_failed: ['rate<0.01'],                 // < 1% error rate
    edge_hit_rate: ['rate>0.70'],                   // >= 70% CDN hit rate after warm-up
  },
};

const BASE_URL = __ENV.BASE_URL || __ENV.TARGET_HOST || 'https://www.truthworld.in';

// In-memory VU state to simulate client-side ETag caching across requests
let lastETag = null;

export default function () {
  const categories = ['all', 'science', 'technology', 'economy', 'news'];
  const cat = categories[Math.floor(Math.random() * categories.length)];
  const languages = ['all', 'te', 'hi', 'en'];
  const lang = languages[Math.floor(Math.random() * languages.length)];

  // Feed endpoint under test (Firebase Hosting rewrite path)
  const url = `${BASE_URL}/api/feed?category=${cat}&lang=${lang}&limit=24`;

  const headers = {
    'Accept': 'application/json',
  };

  // Send conditional If-None-Match header if we have an ETag from previous request
  if (lastETag && Math.random() < 0.6) {
    headers['If-None-Match'] = lastETag;
  }

  const res = http.get(url, { headers });

  // Evaluate caching headers
  const isCdnHit = res.headers['X-Cache'] === 'HIT' ||
    res.headers['x-cache'] === 'HIT' ||
    Number(res.headers['X-Cache-Hits'] || res.headers['x-cache-hits'] || 0) > 0;
  edgeHitRate.add(isCdnHit);

  const isL1Hit = (res.headers['X-Cache-L1'] || res.headers['x-cache-l1']) === 'HIT';
  l1HitRate.add(isL1Hit);

  const is304 = res.status === 304;
  conditional304Rate.add(is304);
  edgeLatencyTrend.add(res.timings.duration);

  // Capture ETag for subsequent conditional requests
  const returnedETag = res.headers['ETag'] || res.headers['etag'];
  if (returnedETag) {
    lastETag = returnedETag;
  }

  check(res, {
    'status is 200 or 304': (r) => r.status === 200 || r.status === 304,
    'feed payload valid when 200': (r) => {
      if (r.status === 304) return true;
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.feed);
      } catch {
        return false;
      }
    },
    'cache-control header present': (r) => {
      const cc = r.headers['Cache-Control'] || r.headers['cache-control'] || '';
      return cc.includes('public') && cc.includes('s-maxage');
    },
  });

  sleep(0.05);
}
