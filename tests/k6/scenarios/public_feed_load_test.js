import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, EDGE_THRESHOLDS } from '../k6_config.js';

// Custom metrics
const feedDurationTrend = new Trend('feed_response_duration_ms');
const cacheHitRate = new Rate('feed_cache_hit_rate');
const feedItemsCounter = new Counter('feed_items_delivered');

export const options = {
  stages: [
    { duration: '15s', target: 20 },  // Warm-up ramp
    { duration: '30s', target: 100 }, // Full load
    { duration: '15s', target: 100 }, // Sustain peak
    { duration: '15s', target: 0 },   // Cool-down
  ],
  thresholds: {
    ...EDGE_THRESHOLDS,
    'feed_response_duration_ms': ['p(95)<150', 'p(99)<300'],
    'feed_cache_hit_rate': ['rate>0.70'], // Expect > 70% cache hits at edge
  },
};

const CATEGORIES = ['All', 'Trending', 'Popular', 'New', 'Music', 'Unexplored'];

export default function () {
  const category = CATEGORIES[Math.floor(Math.random() * CATEGORIES.length)];
  const pageSize = 20;
  const url = `${BASE_URL}/publicFeedServer?category=${encodeURIComponent(category)}&limit=${pageSize}`;

  const res = http.get(url, { headers: DEFAULT_HEADERS });

  feedDurationTrend.add(res.timings.duration);

  // Check cache headers (SWR Cache or Cloudflare/Fastly CDN cache)
  const isCacheHit = res.headers['X-Cache'] === 'HIT' || res.headers['Cache-Control']?.includes('max-age');
  cacheHitRate.add(isCacheHit ? 1 : 0);

  const isOk = check(res, {
    'status is 200 or 304': (r) => r.status === 200 || r.status === 304,
    'duration within P95 SLA': (r) => r.timings.duration < 150,
    'contains videos array': (r) => {
      try {
        const body = JSON.parse(r.body);
        if (Array.isArray(body.videos)) {
          feedItemsCounter.add(body.videos.length);
          return true;
        }
        return false;
      } catch (_) {
        return false;
      }
    },
  });

  // User browsing think time (1 - 3 seconds)
  sleep(Math.random() * 2 + 1);
}
