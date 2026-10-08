import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, HEARTBEAT_THRESHOLDS } from '../k6_config.js';

const heartbeatDurationTrend = new Trend('heartbeat_response_duration_ms');
const pulsesSentCounter = new Counter('watch_pulses_total');

export const options = {
  stages: [
    { duration: '15s', target: 50 },  // Ramp concurrent viewers
    { duration: '45s', target: 200 }, // High volume of 15s heartbeats
    { duration: '15s', target: 0 },   // Cool down
  ],
  thresholds: {
    ...HEARTBEAT_THRESHOLDS,
    'heartbeat_response_duration_ms': ['p(95)<100', 'p(99)<250'],
  },
};

export default function () {
  const viewerId = `vu_viewer_${__VU}`;
  const videoId = `video_${Math.floor(Math.random() * 50)}`;
  const url = `${BASE_URL}/trackWatchEvent`;

  const payload = JSON.stringify({
    data: {
      videoId: videoId,
      viewerId: viewerId,
      pulseDurationSeconds: 15,
      currentPositionSeconds: Math.floor(Math.random() * 300),
      timestamp: Date.now(),
    },
  });

  const res = http.post(url, payload, { headers: DEFAULT_HEADERS });

  heartbeatDurationTrend.add(res.timings.duration);
  pulsesSentCounter.add(1);

  check(res, {
    'heartbeat status 200': (r) => r.status === 200,
    'duration within P95 SLA (<100ms)': (r) => r.timings.duration < 100,
  });

  // Next heartbeat in 15 seconds (simulated video playback cadence)
  // For stress testing load, we sleep 2-4 seconds per VU to simulate 10x traffic density
  sleep(Math.random() * 2 + 2);
}
