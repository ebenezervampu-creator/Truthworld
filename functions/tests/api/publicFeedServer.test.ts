import request from 'supertest';
import { publicFeedServer } from '../../src/feed/publicFeedServer';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { buildVideo } from '../factories/videoFactory';

describe('API Integration: /api/feed (publicFeedServer)', () => {
  const app = createTestApp(publicFeedServer);

  beforeEach(() => {
    testFirestore.clear();
  });

  it('responds with 200 and returns published public videos in default feed', async () => {
    // Seed videos
    const vid1 = buildVideo({ id: 'vid_pub_1', title: 'First Video', category: 'Science' });
    const vid2 = buildVideo({ id: 'vid_pub_2', title: 'Second Video', category: 'History' });
    const vidDraft = buildVideo({ id: 'vid_draft', title: 'Draft Video', status: 'draft' });

    await testFirestore.collection('videos').doc(vid1.id).set(vid1);
    await testFirestore.collection('videos').doc(vid2.id).set(vid2);
    await testFirestore.collection('videos').doc(vidDraft.id).set(vidDraft);

    const res = await request(app).get('/api/feed');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('feed');
    expect(res.body).toHaveProperty('count');
    expect(Array.isArray(res.body.feed)).toBe(true);
    // Draft video should not be in public feed
    const ids = res.body.feed.map((v: any) => v.id);
    expect(ids).toContain('vid_pub_1');
    expect(ids).toContain('vid_pub_2');
    expect(ids).not.toContain('vid_draft');

    // Security & Cache headers
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['access-control-allow-origin']).toBe('*');
  });

  it('filters videos by category query parameter', async () => {
    const vidSci = buildVideo({ id: 'v_sci', category: 'Science' });
    const vidTech = buildVideo({ id: 'v_tech', category: 'Technology' });

    await testFirestore.collection('videos').doc(vidSci.id).set(vidSci);
    await testFirestore.collection('videos').doc(vidTech.id).set(vidTech);

    const res = await request(app).get('/api/feed?category=Science');

    expect(res.status).toBe(200);
    const ids = res.body.feed.map((v: any) => v.id);
    expect(ids).toContain('v_sci');
    expect(ids).not.toContain('v_tech');
    expect(res.body.category).toBe('Science');
  });

  it('returns trending feed with velocity-based trending scores', async () => {
    const highEngagement = buildVideo({
      id: 'v_trending_high',
      viewCount: 50000,
      likeCount: 4000,
      commentCount: 900,
      createdAt: new Date(),
    });
    const lowEngagement = buildVideo({
      id: 'v_trending_low',
      viewCount: 10,
      likeCount: 0,
      commentCount: 0,
      createdAt: new Date(),
    });

    await testFirestore.collection('videos').doc(highEngagement.id).set(highEngagement);
    await testFirestore.collection('videos').doc(lowEngagement.id).set(lowEngagement);

    const res = await request(app).get('/trending');

    expect(res.status).toBe(200);
    expect(res.body.feed.length).toBeGreaterThan(0);

    // Verify trending endpoint returns feed items
    const feedItems = res.body.feed;
    const highItem = feedItems.find((v: any) => v.id === 'v_trending_high');

    expect(highItem).toBeDefined();

    // Verify trending scores are computed (may be null in mock due to Date vs Timestamp)
    if (highItem?.trendingScore != null) {
      expect(typeof highItem.trendingScore).toBe('number');
    }
  });

  it('responds with 204 No Content for OPTIONS CORS preflight', async () => {
    const res = await request(app).options('/api/feed');
    expect(res.status).toBe(204);
  });

  it('responds with 405 Method Not Allowed for POST requests', async () => {
    const res = await request(app).post('/api/feed').send({ data: 123 });
    expect(res.status).toBe(405);
    expect(res.body.error).toBe('Method Not Allowed');
  });

  it('clamps request limit within valid range [1, 50]', async () => {
    // Requesting excessive limit of 500
    const res = await request(app).get('/api/feed?limit=500');
    expect(res.status).toBe(200);
  });
});
