import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, EDGE_THRESHOLDS } from '../k6_config.js';

const seoDurationTrend = new Trend('seo_response_duration_ms');
const botRequestCounter = new Counter('seo_bot_requests_total');

export const options = {
  stages: [
    { duration: '10s', target: 30 },  // Crawler ramp
    { duration: '30s', target: 120 }, // High-concurrency spider burst
    { duration: '10s', target: 0 },   // Cool-down
  ],
  thresholds: {
    ...EDGE_THRESHOLDS,
    'seo_response_duration_ms': ['p(95)<120', 'p(99)<250'],
  },
};

const BOT_USER_AGENTS = [
  'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
  'Mozilla/5.0 (compatible; Bingbot/2.0; +http://www.bing.com/bingbot.htm)',
  'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
  'Twitterbot/1.0',
];

const SAMPLE_PATHS = [
  '/v/video_demo_1080p',
  '/shorts/short_fact_check_01',
  '/@TruthWorld',
  '/T/geopolitics',
  '/embed/video_demo_1080p',
];

export default function () {
  const path = SAMPLE_PATHS[Math.floor(Math.random() * SAMPLE_PATHS.length)];
  const botUa = BOT_USER_AGENTS[Math.floor(Math.random() * BOT_USER_AGENTS.length)];
  const url = `${BASE_URL}/seoServer${path}`;

  botRequestCounter.add(1);

  const res = http.get(url, {
    headers: {
      'User-Agent': botUa,
      'Accept': 'text/html,application/xhtml+xml',
    },
  });

  seoDurationTrend.add(res.timings.duration);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'contains OpenGraph or meta tags': (r) => r.body.includes('<meta') || r.body.includes('og:'),
    'meets P95 latency SLA (<120ms)': (r) => r.timings.duration < 120,
  });

  sleep(Math.random() * 0.5 + 0.2); // Faster crawler pace
}
