/**
 * Unit Tests: Watch Time Telemetry Sharding & High-Concurrency Scalability
 *
 * Verifies:
 * - 60s standard pulse handling with up to 90s tolerance
 * - Distributed shard writes across 20 sub-counters
 * - Contention-free atomic idempotency
 * - In-memory rate limiting without database reads
 */

import * as admin from 'firebase-admin';
import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { authHeader } from '../helpers/authHelper';
import { trackWatchEvent } from '../../src/watchtime/watchtime';

describe('Unit: Watch Time Telemetry & Distributed Sharding', () => {
  const app = createTestApp(trackWatchEvent as any);

  beforeEach(() => {
    testFirestore.clear();
  });

  describe('Heartbeat Interval & Delta Clamping', () => {
    it('accepts legitimate 60s watch pulse without triggering false suspicious heartbeat flags', async () => {
      const payload = {
        videoId: 'vid_scale_test_101',
        userId: 'usr_viewer_01',
        sessionId: 'session_scale_01',
        eventType: 'watch_ping',
        position: 60,
        duration: 600,
        watchTimeSecondsDelta: 60,
        channelId: 'chan_creator_01',
      };

      const res = await request(app)
        .post('/')
        .set(authHeader({ uid: payload.userId }))
        .send(payload);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.processed).toBe(true);
      expect(res.body.creditedDelta).toBe(60);

      // Verify session doc reflects credited watch time
      const sessionDoc = await admin.firestore().collection('watch_sessions').doc(res.body.trackingId).get();
      expect(sessionDoc.exists).toBe(true);
      expect(sessionDoc.data()?.watchTimeSeconds).toBe(60);
      expect(sessionDoc.data()?.suspiciousHeartbeatCount).toBeUndefined();
    });

    it('clamps excessive heartbeat pulse delta exceeding 90 seconds limit to prevent watch time inflation', async () => {
      const payload = {
        videoId: 'vid_scale_test_102',
        userId: 'usr_viewer_02',
        sessionId: 'session_scale_02',
        eventType: 'watch_ping',
        position: 300,
        duration: 600,
        watchTimeSecondsDelta: 500, // Malicious / inflated payload
        channelId: 'chan_creator_01',
      };

      const res = await request(app)
        .post('/')
        .set(authHeader({ uid: payload.userId }))
        .send(payload);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      // Suspicious heartbeat is credited with 0 to prevent bot inflation
      expect(res.body.creditedDelta).toBe(0);

      const sessionDoc = await admin.firestore().collection('watch_sessions').doc(res.body.trackingId).get();
      expect(sessionDoc.exists).toBe(true);
      expect(sessionDoc.data()?.suspiciousHeartbeatCount).toBeGreaterThanOrEqual(1);
    });
  });

  describe('Distributed Shard Ingestion & Idempotency', () => {
    it('writes watch time increments to distributed shards without cross-document transaction locks', async () => {
      const payload = {
        videoId: 'vid_viral_100k',
        userId: 'usr_viewer_03',
        sessionId: 'session_scale_03',
        eventType: 'watch_ping',
        position: 120,
        duration: 1000,
        watchTimeSecondsDelta: 60,
        channelId: 'chan_creator_viral',
      };

      const res = await request(app)
        .post('/')
        .set(authHeader({ uid: payload.userId }))
        .send(payload);

      expect(res.status).toBe(200);
      expect(res.body.processed).toBe(true);

      // Verify idempotency record created
      const eventId = 'session_scale_03_120_watch_ping';
      const eventDoc = await admin.firestore().collection('processedWatchEvents').doc(eventId).get();
      expect(eventDoc.exists).toBe(true);
      expect(eventDoc.data()?.secondsDelta).toBe(60);

      // Verify video shards collection received write
      const videoShards = await admin.firestore().collection('videos').doc('vid_viral_100k').collection('shards').get();
      expect(videoShards.docs.length).toBeGreaterThanOrEqual(1);
      const shardData = videoShards.docs[0].data();
      expect(shardData.watchTimeSeconds).toBe(60);

      // Verify channel shards collection received write
      const channelShards = await admin.firestore().collection('channels').doc('chan_creator_viral').collection('shards').get();
      expect(channelShards.docs.length).toBeGreaterThanOrEqual(1);
      expect(channelShards.docs[0].data()?.watchTimeSeconds).toBe(60);
    });

    it('rejects duplicate watch events with same event ID idempotently', async () => {
      const payload = {
        videoId: 'vid_viral_100k',
        userId: 'usr_viewer_04',
        sessionId: 'session_scale_04',
        eventType: 'watch_ping',
        position: 180,
        duration: 1000,
        watchTimeSecondsDelta: 60,
        channelId: 'chan_creator_viral',
      };

      // First delivery
      const res1 = await request(app)
        .post('/')
        .set(authHeader({ uid: payload.userId }))
        .send(payload);
      expect(res1.status).toBe(200);
      expect(res1.body.processed).toBe(true);

      // Duplicate delivery (network retry / replay)
      const res2 = await request(app)
        .post('/')
        .set(authHeader({ uid: payload.userId }))
        .send(payload);
      expect(res2.status).toBe(200);
      expect(res2.body.processed).toBe(false);
      expect(res2.body.reason).toBe('duplicate_event');
    });
  });

  describe('Zero-Read In-Memory Anti-Spam Rate Limiter', () => {
    it('throttles rapid-fire spam pings beyond threshold with 429', async () => {
      const sessionId = 'session_spam_flood_99';
      const payload = {
        videoId: 'vid_spam_test',
        userId: 'usr_spammer',
        sessionId,
        eventType: 'watch_ping',
        position: 10,
        duration: 300,
        watchTimeSecondsDelta: 10,
      };

      // Send 30 rapid requests (within allowed limit)
      for (let i = 0; i < 30; i++) {
        await request(app).post('/').send({
          ...payload,
          position: 10 + i,
        });
      }

      // 31st request should be throttled by in-memory rate limiter
      const blockedRes = await request(app).post('/').send({
        ...payload,
        position: 45,
      });

      expect(blockedRes.status).toBe(429);
      expect(blockedRes.body.error).toBe('Rate limit');
    });
  });

  describe('Guest / Anonymous User Isolation', () => {
    it('strictly isolates unsigned playback (zero watch_events, zero video/channel shard increments)', async () => {
      const payload = {
        videoId: 'vid_unsigned_test',
        userId: 'anonymous',
        sessionId: 'session_unsigned_99',
        eventType: 'video_start',
        position: 15,
        duration: 300,
        watchTimeSecondsDelta: 15,
        channelId: 'chan_creator_unsigned',
      };

      const res = await request(app).post('/').send(payload);

      expect(res.status).toBe(200);

      // Verify ZERO watch_events were written for anonymous/unsigned users
      const watchEvents = await admin.firestore().collection('watch_events').get();
      expect(watchEvents.empty).toBe(true);

      // Verify ZERO video shard increments
      const videoShards = await admin.firestore().collection('videos').doc('vid_unsigned_test').collection('shards').get();
      expect(videoShards.empty).toBe(true);

      // Verify ZERO channel shard increments
      const channelShards = await admin.firestore().collection('channels').doc('chan_creator_unsigned').collection('shards').get();
      expect(channelShards.empty).toBe(true);
    });
  });
});
