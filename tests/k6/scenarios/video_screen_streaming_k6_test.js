import http from 'k6/http';
import { group, check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, STANDARD_THRESHOLDS, HEARTBEAT_THRESHOLDS } from '../k6_config.js';

const videoMetadataDuration = new Trend('video_metadata_duration_ms');
const videoHeartbeatDuration = new Trend('video_heartbeat_duration_ms');
const videoRecommendationsDuration = new Trend('video_recommendations_duration_ms');
const videoCommentsDuration = new Trend('video_comments_duration_ms');
const videoStreamsStarted = new Counter('video_streams_active_total');

export const options = {
  stages: [
    { duration: '15s', target: 20 },  // Ramp viewers
    { duration: '30s', target: 80 },  // Concurrent video watchers
    { duration: '15s', target: 80 },  // Peak load
    { duration: '10s', target: 0 },   // Cool down
  ],
  thresholds: {
    ...STANDARD_THRESHOLDS,
    ...HEARTBEAT_THRESHOLDS,
    'video_metadata_duration_ms': ['p(95)<100', 'p(99)<200'],
    'video_heartbeat_duration_ms': ['p(95)<100', 'p(99)<200'],
    'video_recommendations_duration_ms': ['p(95)<150', 'p(99)<300'],
    'video_comments_duration_ms': ['p(95)<200', 'p(99)<400'],
  },
};

export default function () {
  const viewerId = `viewer_vu_${__VU}`;
  const videoId = `vid_perf_${Math.floor(Math.random() * 50)}`;

  // 1. Open VideoScreen & Hydrate Video Metadata
  group('1. VideoScreen Hydration & Metadata', () => {
    const res = http.get(`${BASE_URL}/publicFeedServer?videoId=${videoId}`, { headers: DEFAULT_HEADERS });
    videoMetadataDuration.add(res.timings.duration);
    videoStreamsStarted.add(1);

    check(res, {
      'video metadata loaded': (r) => r.status === 200 || r.status === 304,
      'metadata under P95 SLA (<100ms)': (r) => r.timings.duration < 100,
    });
    sleep(1);
  });

  // 2. Continuous 15s Playback Watchtime Heartbeat
  group('2. Watchtime Heartbeat Pulse', () => {
    const payload = JSON.stringify({
      data: {
        videoId: videoId,
        viewerId: viewerId,
        pulseDurationSeconds: 15,
        currentPositionSeconds: 15,
        timestamp: Date.now(),
      },
    });

    const res = http.post(`${BASE_URL}/trackWatchEvent`, payload, { headers: DEFAULT_HEADERS });
    videoHeartbeatDuration.add(res.timings.duration);

    check(res, {
      'watch heartbeat accepted': (r) => r.status === 200,
      'heartbeat under P95 SLA (<100ms)': (r) => r.timings.duration < 100,
    });
    sleep(1.5);
  });

  // 3. Load Related Recommendations in Sidebar
  group('3. Video Recommendations', () => {
    const res = http.get(`${BASE_URL}/publicFeedServer?category=Trending&limit=12`, { headers: DEFAULT_HEADERS });
    videoRecommendationsDuration.add(res.timings.duration);

    check(res, {
      'recommendations loaded': (r) => r.status === 200 || r.status === 304,
      'recommendations under P95 SLA (<150ms)': (r) => r.timings.duration < 150,
    });
    sleep(2);
  });

  // 4. Post Video Reaction / Comment
  group('4. Post Comment on VideoScreen', () => {
    const payload = JSON.stringify({
      data: {
        videoId: videoId,
        userId: viewerId,
        content: `Great investigative journalism and fact-checking report! VU #${__VU}`,
      },
    });

    const res = http.post(`${BASE_URL}/addCommentNested`, payload, { headers: DEFAULT_HEADERS });
    videoCommentsDuration.add(res.timings.duration);

    check(res, {
      'comment interaction response valid (200/429)': (r) => r.status === 200 || r.status === 429,
      'comment action under P95 SLA (<200ms)': (r) => r.timings.duration < 200,
    });
    sleep(2);
  });
}
