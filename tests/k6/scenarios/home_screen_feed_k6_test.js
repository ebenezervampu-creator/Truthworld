import http from 'k6/http';
import { group, check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, EDGE_THRESHOLDS } from '../k6_config.js';

const homeFeedDuration = new Trend('home_feed_duration_ms');
const homeCategoryDuration = new Trend('home_category_switch_duration_ms');
const homePaginationDuration = new Trend('home_pagination_duration_ms');
const homeCacheHitRate = new Rate('home_edge_cache_hit_rate');
const homeVideosLoaded = new Counter('home_videos_loaded_total');

export const options = {
  stages: [
    { duration: '15s', target: 25 },  // Ramp to 25 VUs
    { duration: '30s', target: 100 }, // Full load 100 VUs
    { duration: '15s', target: 100 }, // Peak sustained
    { duration: '10s', target: 0 },   // Cool down
  ],
  thresholds: {
    ...EDGE_THRESHOLDS,
    'home_feed_duration_ms': ['p(95)<120', 'p(99)<250'],
    'home_category_switch_duration_ms': ['p(95)<100', 'p(99)<200'],
    'home_pagination_duration_ms': ['p(95)<150', 'p(99)<300'],
    'home_edge_cache_hit_rate': ['rate>0.75'], // 75%+ edge cache hit rate
  },
};

const CATEGORIES = ['All', 'Trending', 'Popular', 'New', 'Music', 'Unexplored'];

export default function () {
  // 1. Initial Home Screen Load
  group('1. Initial Home Feed Load', () => {
    const res = http.get(`${BASE_URL}/publicFeedServer?category=All&limit=24`, { headers: DEFAULT_HEADERS });
    homeFeedDuration.add(res.timings.duration);

    const isHit = res.headers['X-Cache'] === 'HIT' || res.headers['Cache-Control']?.includes('max-age');
    homeCacheHitRate.add(isHit ? 1 : 0);

    check(res, {
      'home feed loaded successfully (200/304)': (r) => r.status === 200 || r.status === 304,
      'home feed under P95 SLA': (r) => r.timings.duration < 120,
    });
    sleep(1);
  });

  // 2. Category Tab Switching (User clicks "Trending" or "Popular")
  group('2. Category Tab Switch', () => {
    const category = CATEGORIES[Math.floor(Math.random() * CATEGORIES.length)];
    const res = http.get(`${BASE_URL}/publicFeedServer?category=${encodeURIComponent(category)}&limit=24`, { headers: DEFAULT_HEADERS });
    homeCategoryDuration.add(res.timings.duration);

    const isHit = res.headers['X-Cache'] === 'HIT' || res.headers['Cache-Control']?.includes('max-age');
    homeCacheHitRate.add(isHit ? 1 : 0);

    check(res, {
      'category tab switched successfully': (r) => r.status === 200 || r.status === 304,
      'category switch under P95 SLA': (r) => r.timings.duration < 100,
    });
    sleep(1.5);
  });

  // 3. User Scrolls Down -> Pagination Page 2
  group('3. Feed Infinite Scroll Pagination', () => {
    const res = http.get(`${BASE_URL}/publicFeedServer?category=All&limit=24&page=2`, { headers: DEFAULT_HEADERS });
    homePaginationDuration.add(res.timings.duration);

    check(res, {
      'pagination batch loaded': (r) => r.status === 200 || r.status === 304,
      'pagination under P95 SLA': (r) => r.timings.duration < 150,
    });
    sleep(2);
  });
}
