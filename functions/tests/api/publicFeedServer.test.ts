import request from 'supertest';
import { publicFeedServer, parseETags, isWeakETagMatch } from '../../src/feed/publicFeedServer';
import { clearCache, invalidateFeedGeneration, sharedLruCache } from '../../src/shared/memory-cache';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { buildVideo } from '../factories/videoFactory';

describe('API Integration: /api/feed (publicFeedServer)', () => {
  const app = createTestApp(publicFeedServer);

  beforeEach(() => {
    testFirestore.clear();
    clearCache();
  });

  describe('RFC 9110 ETag Parsing & Comparison', () => {
    it('parses complex entity tags including commas inside quotes', () => {
      const header = 'W/"abc,123", "normal", W/"tag with \"escaped\" quote", *';
      const tags = parseETags(header);
      expect(tags).toContain('W/"abc,123"');
      expect(tags).toContain('"normal"');
      expect(tags).toContain('*');
    });

    it('matches weak and strong ETags correctly under RFC 9110 weak comparison', () => {
      expect(isWeakETagMatch('"abc"', 'W/"abc"')).toBe(true);
      expect(isWeakETagMatch('W/"abc"', '"abc"')).toBe(true);
      expect(isWeakETagMatch('W/"abc"', 'W/"abc"')).toBe(true);
      expect(isWeakETagMatch('*', 'W/"any"')).toBe(true);
      expect(isWeakETagMatch('W/"other", W/"abc"', 'W/"abc"')).toBe(true);
      expect(isWeakETagMatch('W/"xyz"', 'W/"abc"')).toBe(false);
    });

    it('handles commas enclosed inside quoted ETags without breaking comparison', () => {
      const header = 'W/"first,with,comma", W/"target_tag"';
      expect(isWeakETagMatch(header, 'W/"target_tag"')).toBe(true);
      expect(isWeakETagMatch(header, 'W/"first,with,comma"')).toBe(true);
      expect(isWeakETagMatch(header, 'W/"not_present"')).toBe(false);
    });
  });

  describe('Feed Retrieval & Conditional HTTP Requests', () => {
    it('responds with 200 and returns published public videos in default feed', async () => {
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
      expect(res.headers).toHaveProperty('etag');
      expect(res.headers['cache-control']).toContain('s-maxage=300');
      expect(res.headers['cache-control']).toContain('stale-while-revalidate=600');

      const ids = res.body.feed.map((v: any) => v.id);
      expect(ids).toContain('vid_pub_1');
      expect(ids).toContain('vid_pub_2');
      expect(ids).not.toContain('vid_draft');
    });

    it('returns 304 Not Modified when matching If-None-Match ETag is sent', async () => {
      const vid1 = buildVideo({ id: 'vid_etag_test', title: 'ETag Test Video' });
      await testFirestore.collection('videos').doc(vid1.id).set(vid1);

      // First request: obtain ETag
      const res1 = await request(app).get('/api/feed');
      expect(res1.status).toBe(200);
      const etag = res1.headers['etag'];
      expect(etag).toBeDefined();

      // Second request: send If-None-Match
      const res2 = await request(app)
        .get('/api/feed')
        .set('If-None-Match', etag);

      expect(res2.status).toBe(304);
      expect(res2.text).toBe('');
    });

    it('serves repeated requests from in-process L1 cache when ETag does not match', async () => {
      const vid1 = buildVideo({ id: 'vid_l1_test', title: 'L1 Test Video' });
      await testFirestore.collection('videos').doc(vid1.id).set(vid1);

      const res1 = await request(app).get('/api/feed');
      expect(res1.status).toBe(200);

      const res2 = await request(app).get('/api/feed');
      expect(res2.status).toBe(200);
      expect(res2.headers['x-cache-l1']).toBe('HIT');
    });

    it('invalidates L1 cache when feed generation is bumped', async () => {
      const vid1 = buildVideo({ id: 'vid_gen_test', title: 'Gen Test Video' });
      await testFirestore.collection('videos').doc(vid1.id).set(vid1);

      const res1 = await request(app).get('/api/feed');
      expect(res1.status).toBe(200);

      // Invalidate feed generation (e.g. video published or deleted)
      invalidateFeedGeneration();

      const res2 = await request(app).get('/api/feed');
      expect(res2.status).toBe(200);
      expect(res2.headers['x-cache-l1']).toBe('MISS');
    });
  });

  describe('HMAC-Signed Cursor Pagination (Option A)', () => {
    it('returns nextCursor when more items exist beyond the requested limit', async () => {
      // Seed 5 videos
      for (let i = 1; i <= 5; i++) {
        const v = buildVideo({ id: `vid_p_${i}`, title: `Video ${i}`, createdAt: new Date(1700000000000 + i * 1000) });
        await testFirestore.collection('videos').doc(v.id).set(v);
      }

      // Request limit=2
      const res = await request(app).get('/api/feed?limit=2');
      expect(res.status).toBe(200);
      expect(res.body.count).toBe(2);
      expect(res.body.hasMore).toBe(true);
      expect(typeof res.body.nextCursor).toBe('string');
      expect(res.body.nextCursor.length).toBeGreaterThan(10);
    });

    it('rejects tampered or forged pagination cursor with 400 Bad Request', async () => {
      const tamperedCursor = 'eyJhbGciOiJIUzI1NiJ9.forged_signature';
      const res = await request(app).get(`/api/feed?cursor=${tamperedCursor}`);
      expect(res.status).toBe(400);
      expect(res.body.error).toContain('Invalid, expired, or mismatched pagination cursor');
    });

    it('rejects cursor cross-injected across different categories', async () => {
      // Seed videos in Technology
      for (let i = 1; i <= 3; i++) {
        const v = buildVideo({ id: `v_tech_${i}`, category: 'technology' });
        await testFirestore.collection('videos').doc(v.id).set(v);
      }

      const resTech = await request(app).get('/api/feed?category=technology&limit=1');
      const cursor = resTech.body.nextCursor;
      expect(cursor).toBeDefined();

      // Attempt to reuse Technology cursor for Science feed
      const resScience = await request(app).get(`/api/feed?category=science&cursor=${cursor}`);
      expect(resScience.status).toBe(400);
      expect(resScience.body.error).toContain('mismatched');
    });

    it('rejects cursor reused with mismatched limit parameter', async () => {
      const v1 = buildVideo({ id: 'v_limit_1', category: 'technology' });
      const v2 = buildVideo({ id: 'v_limit_2', category: 'technology' });
      await testFirestore.collection('videos').doc(v1.id).set(v1);
      await testFirestore.collection('videos').doc(v2.id).set(v2);

      const res = await request(app).get('/api/feed?category=technology&limit=1');
      const cursor = res.body.nextCursor;
      expect(cursor).toBeDefined();

      // Attempt to reuse limit=1 cursor for limit=10 request
      const resMismatchedLimit = await request(app).get(`/api/feed?category=technology&limit=10&cursor=${cursor}`);
      expect(resMismatchedLimit.status).toBe(400);
      expect(resMismatchedLimit.body.error).toContain('mismatched');
    });

    it('allows successful pagination using valid signed cursor', async () => {
      const v1 = buildVideo({ id: 'v_page_1', title: 'Page 1', createdAt: new Date(1700000002000) });
      const v2 = buildVideo({ id: 'v_page_2', title: 'Page 2', createdAt: new Date(1700000001000) });
      await testFirestore.collection('videos').doc(v1.id).set(v1);
      await testFirestore.collection('videos').doc(v2.id).set(v2);

      const resPage1 = await request(app).get('/api/feed?limit=1');
      expect(resPage1.status).toBe(200);
      expect(resPage1.body.feed.length).toBe(1);
      const cursor = resPage1.body.nextCursor;
      expect(cursor).toBeDefined();

      const resPage2 = await request(app).get(`/api/feed?limit=1&cursor=${cursor}`);
      expect(resPage2.status).toBe(200);
      expect(resPage2.body.feed.length).toBe(1);
    });
  });

  describe('Dual-Bounded LRU Cache Hardening', () => {
    it('enforces maximum payload byte constraints and evicts LRU entries', () => {
      expect(sharedLruCache.getStats().maxEntries).toBe(150);
      expect(sharedLruCache.getStats().maxTotalBytes).toBe(16 * 1024 * 1024);

      // Reject entries exceeding 256 KiB
      const largePayload = 'A'.repeat(300 * 1024); // 300 KiB
      const stored = sharedLruCache.set('large_test', largePayload);
      expect(stored).toBe(false);
      expect(sharedLruCache.get('large_test')).toBeUndefined();
    });
  });

  describe('CORS and Method Guards', () => {
    it('responds with 204 No Content for OPTIONS CORS preflight', async () => {
      const res = await request(app).options('/api/feed');
      expect(res.status).toBe(204);
      expect(res.headers['access-control-allow-origin']).toBe('*');
    });

    it('responds with 405 Method Not Allowed for POST requests', async () => {
      const res = await request(app).post('/api/feed').send({ data: 123 });
      expect(res.status).toBe(405);
      expect(res.body.error).toBe('Method Not Allowed');
    });
  });
});
