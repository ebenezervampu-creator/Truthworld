import * as admin from 'firebase-admin';
import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { checkGuestWatchQuota, reportGuestWatchPulse, GUEST_WATCH_LIMIT_SECONDS, getGuestLimitDocId, clearGuestLimitCache } from '../../src/watchtime/guestWatchLimit';
import { trackWatchEvent } from '../../src/watchtime/watchtime';

describe('Unit: Guest Watch Limit & Incognito IP Enforcement', () => {
  const checkApp = createTestApp(checkGuestWatchQuota as any);
  const pulseApp = createTestApp(reportGuestWatchPulse as any);
  const trackApp = createTestApp(trackWatchEvent as any);

  beforeEach(() => {
    testFirestore.clear();
    clearGuestLimitCache();
  });

  describe('checkGuestWatchQuota', () => {
    it('returns full 600 seconds quota for new guest IP', async () => {
      const res = await request(checkApp)
        .get('/')
        .set('x-forwarded-for', '203.0.113.195');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.allowed).toBe(true);
      expect(res.body.isLimitExceeded).toBe(false);
      expect(res.body.remainingSeconds).toBe(GUEST_WATCH_LIMIT_SECONDS);
      expect(res.body.requireSignIn).toBe(false);
    });

    it('returns isLimitExceeded=true when IP has accumulated >= 600 seconds', async () => {
      const ip = '203.0.113.196';
      // Seed initial pulse for this IP
      await request(pulseApp)
        .post('/')
        .set('x-forwarded-for', ip)
        .send({ deltaSeconds: 30 });

      // Directly update the daily doc to 600 seconds to simulate 10 minutes reached
      const ipHash = resToHash(ip);
      const docId = getGuestLimitDocId(ipHash);
      await admin.firestore().collection('guest_ip_watch_limits').doc(docId).set({
        ipHash,
        totalWatchSeconds: 600,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const res = await request(checkApp)
        .get('/')
        .set('x-forwarded-for', ip);

      expect(res.status).toBe(200);
      expect(res.body.allowed).toBe(false);
      expect(res.body.isLimitExceeded).toBe(true);
      expect(res.body.remainingSeconds).toBe(0);
      expect(res.body.requireSignIn).toBe(true);
    });
  });

  describe('reportGuestWatchPulse', () => {
    it('accumulates delta seconds against the client IP', async () => {
      const ip = '203.0.113.197';
      const res = await request(pulseApp)
        .post('/')
        .set('x-forwarded-for', ip)
        .send({ deltaSeconds: 15, videoId: 'vid_test_101' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.totalWatchSeconds).toBe(15);
      expect(res.body.remainingSeconds).toBe(585);
      expect(res.body.isLimitExceeded).toBe(false);
    });

    it('clamps excessive delta pulse to max 30 seconds per pulse', async () => {
      const ip = '203.0.113.198';
      const res = await request(pulseApp)
        .post('/')
        .set('x-forwarded-for', ip)
        .send({ deltaSeconds: 500 }); // Attempted spoof

      expect(res.status).toBe(200);
      expect(res.body.totalWatchSeconds).toBe(30); // Clamped to 30s
    });

    it('handles NaN, non-finite, and negative delta payloads safely without crashing', async () => {
      const ip = '203.0.113.201';
      // 1. Send invalid string
      const res1 = await request(pulseApp)
        .post('/')
        .set('x-forwarded-for', ip)
        .send({ deltaSeconds: 'malicious_nan_string' });

      expect(res1.status).toBe(200);
      expect(res1.body.success).toBe(true);
      expect(res1.body.totalWatchSeconds).toBe(0);

      // 2. Send negative delta
      const res2 = await request(pulseApp)
        .post('/')
        .set('x-forwarded-for', ip)
        .send({ deltaSeconds: -50 });

      expect(res2.status).toBe(200);
      expect(res2.body.totalWatchSeconds).toBe(0);
    });
  });

  describe('Security & Anti-Spoofing: IP Extraction & Date Partitioning', () => {
    it('ignores client-spoofed prefix in X-Forwarded-For header and picks the verified client IP', async () => {
      const { getClientIp } = require('../../src/watchtime/guestWatchLimit');

      const mockReq = {
        headers: {
          'x-forwarded-for': '1.1.1.1, 203.0.113.210',
        },
      };

      const resolvedIp = getClientIp(mockReq);
      expect(resolvedIp).toBe('203.0.113.210');
    });

    it('ignores internal/private proxy hops on the right of X-Forwarded-For', async () => {
      const { getClientIp } = require('../../src/watchtime/guestWatchLimit');

      const mockReq = {
        headers: {
          'x-forwarded-for': '1.1.1.1, 203.0.113.211, 10.0.0.1',
        },
      };

      const resolvedIp = getClientIp(mockReq);
      expect(resolvedIp).toBe('203.0.113.211');
    });

    it('generates date-partitioned document IDs for daily quota resets', () => {
      const { getGuestLimitDocId } = require('../../src/watchtime/guestWatchLimit');
      const docId = getGuestLimitDocId('abc12345', '2026-10-15');
      expect(docId).toBe('abc12345_2026-10-15');
    });
  });

  describe('trackWatchEvent integration', () => {
    it('restricts unsigned playback once IP limit has been reached', async () => {
      const ip = '203.0.113.199';
      const ipHash = resToHash(ip);

      // Pre-seed 600s
      await admin.firestore().collection('guest_ip_watch_limits').doc(ipHash).set({
        ipHash,
        totalWatchSeconds: 600,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const res = await request(trackApp)
        .post('/')
        .set('x-forwarded-for', ip)
        .send({
          videoId: 'vid_guest_blocked',
          userId: 'anonymous',
          sessionId: 'session_guest_01',
          eventType: 'video_start',
          position: 0,
          duration: 300,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(false);
      expect(res.body.limitExceeded).toBe(true);
      expect(res.body.requireSignIn).toBe(true);
    });
  });
});

function resToHash(ip: string): string {
  const { createHash } = require('crypto');
  return createHash('sha256').update(ip).digest('hex').substring(0, 16);
}
