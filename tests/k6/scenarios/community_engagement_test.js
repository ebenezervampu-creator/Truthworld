import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, DEFAULT_HEADERS, STANDARD_THRESHOLDS } from '../k6_config.js';

const commentDurationTrend = new Trend('comment_action_duration_ms');
const actionsCounter = new Counter('engagement_actions_total');

export const options = {
  stages: [
    { duration: '15s', target: 25 },
    { duration: '30s', target: 75 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    ...STANDARD_THRESHOLDS,
    'comment_action_duration_ms': ['p(95)<200', 'p(99)<400'],
  },
};

export default function () {
  const userId = `user_vu_${__VU}`;
  const videoId = `video_${Math.floor(Math.random() * 20)}`;
  const actionType = Math.random() > 0.4 ? 'comment' : 'reaction';

  if (actionType === 'comment') {
    const url = `${BASE_URL}/addCommentNested`;
    const payload = JSON.stringify({
      data: {
        videoId: videoId,
        userId: userId,
        content: `Insightful fact check on this claim! VU #${__VU} @truthworld`,
      },
    });

    const res = http.post(url, payload, { headers: DEFAULT_HEADERS });
    commentDurationTrend.add(res.timings.duration);
    actionsCounter.add(1);

    check(res, {
      'comment creation 200 or 429': (r) => r.status === 200 || r.status === 429, // 429 indicates rate limiter working properly
      'latency within P95 SLA': (r) => r.timings.duration < 200,
    });
  } else {
    const url = `${BASE_URL}/toggleCommentInteraction`;
    const payload = JSON.stringify({
      data: {
        commentId: `comment_${Math.floor(Math.random() * 100)}`,
        userId: userId,
        type: 'like',
      },
    });

    const res = http.post(url, payload, { headers: DEFAULT_HEADERS });
    commentDurationTrend.add(res.timings.duration);
    actionsCounter.add(1);

    check(res, {
      'reaction toggle 200': (r) => r.status === 200,
      'latency within P95 SLA': (r) => r.timings.duration < 200,
    });
  }

  sleep(Math.random() * 3 + 1);
}
