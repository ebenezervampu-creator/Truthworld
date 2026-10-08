import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, SEARCH_THRESHOLDS } from '../k6_config.js';

const searchDurationTrend = new Trend('search_response_duration_ms');
const totalResultsCounter = new Counter('search_results_returned');

export const options = {
  stages: [
    { duration: '15s', target: 20 },
    { duration: '30s', target: 80 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    ...SEARCH_THRESHOLDS,
    'search_response_duration_ms': ['p(95)<350', 'p(99)<700'],
  },
};

const SEARCH_QUERIES = [
  'truthworld fact check',
  'ai speech synthesis',
  '@truthworld',
  'deepfake audio verification',
  'geopolitics analysis',
  'multilingual dubbing',
  'creator revenue monetization',
];

export default function () {
  const query = SEARCH_QUERIES[Math.floor(Math.random() * SEARCH_QUERIES.length)];
  const url = `${BASE_URL}/searchTruthWorld`;

  const payload = JSON.stringify({
    data: {
      query: query,
      limit: 15,
      filter: 'all',
    },
  });

  const res = http.post(url, payload, { headers: DEFAULT_HEADERS });

  searchDurationTrend.add(res.timings.duration);

  check(res, {
    'search status 200': (r) => r.status === 200,
    'search duration within P95 SLA': (r) => r.timings.duration < 350,
    'result contains data payload': (r) => {
      try {
        const body = JSON.parse(r.body);
        if (body.result && Array.isArray(body.result.items)) {
          totalResultsCounter.add(body.result.items.length);
          return true;
        }
        return body.result !== undefined;
      } catch (_) {
        return false;
      }
    },
  });

  sleep(Math.random() * 2 + 1);
}
