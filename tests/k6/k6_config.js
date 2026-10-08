/**
 * ⚡ K6 LOAD TESTING SUITE CONFIGURATION FOR TRUTHWORLD
 *
 * Defines shared configurations, environments, headers, and SLA thresholds.
 * Compatible with standard k6 CLI (`k6 run`) and Node.js test runners.
 */

export const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:5001/truthworld-1/asia-south1';

export const DEFAULT_HEADERS = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'User-Agent': 'TruthWorld-k6-PerformanceTest/1.0',
};

// Standard TruthWorld P95/P99 SLA Thresholds
export const STANDARD_THRESHOLDS = {
  http_req_failed: ['rate<0.01'], // Global error rate must be < 1%
  http_req_duration: ['p(95)<200', 'p(99)<500'], // P95 < 200ms, P99 < 500ms
};

// High-Throughput Edge / CDN Thresholds
export const EDGE_THRESHOLDS = {
  http_req_failed: ['rate<0.005'], // Error rate < 0.5%
  http_req_duration: ['p(95)<150', 'p(99)<300'], // P95 < 150ms, P99 < 300ms
};

// Search / Vector Intensive Thresholds
export const SEARCH_THRESHOLDS = {
  http_req_failed: ['rate<0.02'], // Error rate < 2%
  http_req_duration: ['p(95)<350', 'p(99)<700'], // P95 < 350ms, P99 < 700ms
};

// Heartbeat / Pulse High-Volume Ingestion Thresholds
export const HEARTBEAT_THRESHOLDS = {
  http_req_failed: ['rate<0.005'],
  http_req_duration: ['p(95)<100', 'p(99)<250'], // P95 < 100ms, P99 < 250ms
};

// Realistic traffic stages
export const LOAD_STAGES = {
  smoke: [
    { duration: '10s', target: 5 },
    { duration: '20s', target: 5 },
    { duration: '10s', target: 0 },
  ],
  load: [
    { duration: '30s', target: 50 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 100 },
    { duration: '1m', target: 100 },
    { duration: '30s', target: 0 },
  ],
  stress: [
    { duration: '30s', target: 100 },
    { duration: '1m', target: 250 },
    { duration: '1m', target: 500 },
    { duration: '30s', target: 0 },
  ],
  spike: [
    { duration: '10s', target: 20 },
    { duration: '10s', target: 500 },
    { duration: '30s', target: 500 },
    { duration: '10s', target: 20 },
    { duration: '10s', target: 0 },
  ],
};
