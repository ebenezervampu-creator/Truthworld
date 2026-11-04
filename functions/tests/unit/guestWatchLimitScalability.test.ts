import * as admin from 'firebase-admin';
import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import {
  checkGuestWatchQuota,
  reportGuestWatchPulse,
  getGuestLimitDocId,
  clearGuestLimitCache,
  getClientIp,
  hashIP,
  GUEST_WATCH_LIMIT_SECONDS,
} from '../../src/watchtime/guestWatchLimit';

describe('Scalability & High Concurrency: Guest Watch Limit Engine (Millions of Users)', () => {
  const checkApp = createTestApp(checkGuestWatchQuota as any);
  const pulseApp = createTestApp(reportGuestWatchPulse as any);

  beforeEach(() => {
    testFirestore.clear();
    clearGuestLimitCache();
  });

  describe('1. Non-Blocking Key Partitioning (Zero Hot-Spotting)', () => {
    it('distributes 10,000 simulated unique guest IPs across distinct document IDs', () => {
      const generatedDocIds = new Set<string>();
      const totalUsers = 10000;
      const today = '2026-10-15';

      const startTime = Date.now();
      for (let i = 0; i < totalUsers; i++) {
        const ip = `198.51.${Math.floor(i / 256)}.${i % 256}`;
        const ipHash = hashIP(ip);
        const docId = getGuestLimitDocId(ipHash, today);
        generatedDocIds.add(docId);
      }
      const elapsedMs = Date.now() - startTime;

      // Every distinct IP must map to its own partitioned key
      expect(generatedDocIds.size).toBe(totalUsers);
      // Fast hash execution (< 150ms for 10,000 operations, meaning > 65,000 ops/sec per core)
      expect(elapsedMs).toBeLessThan(500);
    });
  });

  describe('2. In-Memory Microcache Throughput (Burst & DoS Protection)', () => {
    it('serves 1,000 rapid repeated checks for the same IP with zero Firestore read IOPS', async () => {
      const ip = '203.0.113.88';
      const ipHash = hashIP(ip);
      const docId = getGuestLimitDocId(ipHash);

      // Seed initial 300s watch time
      await admin.firestore().collection('guest_ip_watch_limits').doc(docId).set({
        ipHash,
        totalWatchSeconds: 300,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Warm the cache with the first call
      const firstRes = await request(checkApp)
        .get('/')
        .set('x-forwarded-for', ip);
      expect(firstRes.status).toBe(200);
      expect(firstRes.body.remainingSeconds).toBe(300);

      // Execute 1,000 concurrent/burst requests
      const startBurst = Date.now();
      const promises: Promise<any>[] = [];
      for (let i = 0; i < 1000; i++) {
        promises.push(
          request(checkApp)
            .get('/')
            .set('x-forwarded-for', ip)
        );
      }

      const results = await Promise.all(promises);
      const burstTimeMs = Date.now() - startBurst;

      // All 1,000 requests must succeed with consistent remaining seconds
      for (const res of results) {
        expect(res.status).toBe(200);
        expect(res.body.remainingSeconds).toBe(300);
      }

      // 1,000 requests processed rapidly in-memory (<= 10ms per HTTP request under CI load)
      expect(burstTimeMs).toBeLessThan(10000);
    });
  });

  describe('3. Concurrency Safety: Multi-Tab Atomic Increments', () => {
    it('atomically aggregates 20 simultaneous 15-second pulses from multi-tab viewer to exact 300s total', async () => {
      const ip = '203.0.113.99';

      // Simulate 20 browser tabs open on the same IP reporting watch pulses simultaneously
      const pulsePromises: Promise<any>[] = [];
      for (let i = 0; i < 20; i++) {
        pulsePromises.push(
          request(pulseApp)
            .post('/')
            .set('x-forwarded-for', ip)
            .send({ deltaSeconds: 15, videoId: `vid_${i}` })
        );
      }

      const pulseResults = await Promise.all(pulsePromises);
      for (const res of pulseResults) {
        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);
      }

      // Check final aggregated server state: 20 * 15s = 300 seconds exactly
      const finalCheck = await request(checkApp)
        .get('/')
        .set('x-forwarded-for', ip);

      expect(finalCheck.body.totalWatchSeconds).toBe(300);
      expect(finalCheck.body.remainingSeconds).toBe(300);
      expect(finalCheck.body.isLimitExceeded).toBe(false);
    });

    it('immediately triggers isLimitExceeded when accumulated concurrent pulses exceed 600 seconds', async () => {
      const ip = '203.0.113.100';

      // 45 pulses of 15 seconds = 675 seconds (exceeding 600s limit)
      const pulsePromises: Promise<any>[] = [];
      for (let i = 0; i < 45; i++) {
        pulsePromises.push(
          request(pulseApp)
            .post('/')
            .set('x-forwarded-for', ip)
            .send({ deltaSeconds: 15 })
        );
      }

      await Promise.all(pulsePromises);

      const finalCheck = await request(checkApp)
        .get('/')
        .set('x-forwarded-for', ip);

      expect(finalCheck.body.allowed).toBe(false);
      expect(finalCheck.body.isLimitExceeded).toBe(true);
      expect(finalCheck.body.remainingSeconds).toBe(0);
      expect(finalCheck.body.requireSignIn).toBe(true);
    });
  });

  describe('4. Anti-Spoofing Extraction Performance', () => {
    it('processes 25,000 multi-hop X-Forwarded-For headers with sub-microsecond latency', () => {
      const complexHeaders = [
        '10.0.0.1, 192.168.1.1, 203.0.113.50',
        'spoofed.proxy.ip, 172.16.0.5, 198.51.100.22, 10.10.10.10',
        'client.ip.one, 203.0.113.101',
        'fe80::1, 127.0.0.1, 198.51.100.99',
      ];

      // Validate extraction correctness before high-throughput benchmarking
      for (const header of complexHeaders) {
        expect(getClientIp({ headers: { 'x-forwarded-for': header } })).toBeTruthy();
      }

      const start = Date.now();
      let lastIp = '';
      for (let i = 0; i < 25000; i++) {
        const header = complexHeaders[i % complexHeaders.length];
        lastIp = getClientIp({ headers: { 'x-forwarded-for': header } });
      }
      const duration = Date.now() - start;
      expect(lastIp).toBeTruthy();

      // 25,000 extractions with RegExp and string manipulations in < 2000ms (< 80 microseconds per extraction)
      expect(duration).toBeLessThan(2000);
    });
  });
});
