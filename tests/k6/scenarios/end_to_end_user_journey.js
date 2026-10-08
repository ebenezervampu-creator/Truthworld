import http from 'k6/http';
import { group, check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, STANDARD_THRESHOLDS } from '../k6_config.js';

const journeyDuration = new Trend('journey_full_duration_ms');
const journeySuccess = new Counter('journey_completed_count');

export const options = {
  stages: [
    { duration: '20s', target: 20 },
    { duration: '40s', target: 50 },
    { duration: '20s', target: 0 },
  ],
  thresholds: {
    ...STANDARD_THRESHOLDS,
    'journey_full_duration_ms': ['p(95)<1500', 'p(99)<3000'],
  },
};

export default function () {
  const startMs = Date.now();
  const userId = `viewer_${__VU}`;
  const videoId = `vid_${Math.floor(Math.random() * 50)}`;

  // Step 1: Browse Public Feed
  group('1. Browse Home Feed', () => {
    const res = http.get(`${BASE_URL}/publicFeedServer?category=All&limit=10`, { headers: DEFAULT_HEADERS });
    check(res, {
      'feed loaded': (r) => r.status === 200 || r.status === 304,
    });
    sleep(1);
  });

  // Step 2: Search TruthWorld
  group('2. Search TruthWorld', () => {
    const res = http.post(
      `${BASE_URL}/searchTruthWorld`,
      JSON.stringify({ data: { query: 'AI Fact Check', limit: 10 } }),
      { headers: DEFAULT_HEADERS }
    );
    check(res, {
      'search completed': (r) => r.status === 200,
    });
    sleep(1.5);
  });

  // Step 3: Stream Video & Emit Watchtime Heartbeat
  group('3. Watch Video Pulse', () => {
    const res = http.post(
      `${BASE_URL}/trackWatchEvent`,
      JSON.stringify({
        data: {
          videoId: videoId,
          viewerId: userId,
          pulseDurationSeconds: 15,
          currentPositionSeconds: 15,
          timestamp: Date.now(),
        },
      }),
      { headers: DEFAULT_HEADERS }
    );
    check(res, {
      'watch pulse recorded': (r) => r.status === 200,
    });
    sleep(2);
  });

  // Step 4: Community Interaction
  group('4. Add Comment', () => {
    const res = http.post(
      `${BASE_URL}/addCommentNested`,
      JSON.stringify({
        data: {
          videoId: videoId,
          userId: userId,
          content: 'Excellent verification breakdown! @truthworld',
        },
      }),
      { headers: DEFAULT_HEADERS }
    );
    check(res, {
      'comment response valid': (r) => r.status === 200 || r.status === 429,
    });
  });

  journeyDuration.add(Date.now() - startMs);
  journeySuccess.add(1);

  sleep(2);
}
