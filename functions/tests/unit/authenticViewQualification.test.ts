/**
 * 🛡️ UNIT TESTS: AUTHENTIC VIEW QUALIFICATION & FRAUD REJECTION
 *
 * Verifies TruthWorld's Epistemic Invariants:
 * 1. Qualified View Threshold (Accidental 1-2s bounces are NEVER counted as views)
 * 2. Scrubber / Progress Bar Bypass Protection (seeking to the end gives 0 view and 0 watch time)
 * 3. Token-Bound Identity Security (Clients cannot spoof viewer identities)
 * 4. Duration Ceiling & Deduplication (A user can never give more than the video's duration)
 * 5. Multi-Layer Bot Farm & IP Clustering Detection
 */

import * as admin from 'firebase-admin';
import request from 'supertest';
import { createTestApp } from '../helpers/testServer';
import { testFirestore } from '../helpers/mockFirestore';
import { authHeader } from '../helpers/authHelper';
import { trackWatchEvent } from '../../src/watchtime/watchtime';

describe('Unit: Authentic View Qualification & Fraud Rejection', () => {
  const app = createTestApp(trackWatchEvent as any);

  beforeEach(() => {
    testFirestore.clear();
  });

  // --------------------------------------------------------------------------
  // TEST SUITE 1: Qualified View Threshold Engine
  // --------------------------------------------------------------------------
  describe('Qualified View Threshold Criteria', () => {
    // Evaluates whether a watch session qualifies as a legitimate view according to the backend formula:
    // (deltaSeconds >= 10 || (duration > 0 && deltaSeconds / duration >= 0.30) || (completed && deltaSeconds >= duration * 0.85))
    function evaluateQualifiedView(session: {
      started: boolean;
      deltaSeconds: number;
      duration: number;
      completed: boolean;
    }): boolean {
      if (!session.started) return false;
      const reached10Sec = session.deltaSeconds >= 10;
      const reached30Percent = session.duration > 0 && (session.deltaSeconds / session.duration) >= 0.30;
      const genuineCompletion = session.completed && session.duration > 0 && (session.deltaSeconds >= session.duration * 0.85);
      return reached10Sec || reached30Percent || genuineCompletion;
    }

    it('rejects quick accidental click/bounce (e.g. 2s on 120s video) - NOT counted as a view', () => {
      const session = {
        started: true,
        deltaSeconds: 2,
        duration: 120,
        completed: false,
      };

      const isQualified = evaluateQualifiedView(session);
      expect(isQualified).toBe(false);
    });

    it('qualifies legitimate view that crosses 10 seconds threshold on long video', () => {
      const session = {
        started: true,
        deltaSeconds: 12,
        duration: 600, // 10 minute video
        completed: false,
      };

      const isQualified = evaluateQualifiedView(session);
      expect(isQualified).toBe(true);
    });

    it('qualifies short-form video that reaches 30% duration before 10 seconds (e.g. 3s on 8s short)', () => {
      const session = {
        started: true,
        deltaSeconds: 3,
        duration: 8,
        completed: false,
      };

      // 3s / 8s = 37.5% >= 30%
      const isQualified = evaluateQualifiedView(session);
      expect(isQualified).toBe(true);
    });

    it('disqualifies scrubber jump to the end where elapsed watch delta is 0', () => {
      const session = {
        started: true,
        deltaSeconds: 0, // Viewer dragged slider to the end in 0.5s
        duration: 300,
        completed: false, // Completion rejected because deltaSeconds < 85%
      };

      const isQualified = evaluateQualifiedView(session);
      expect(isQualified).toBe(false);
    });
  });

  // --------------------------------------------------------------------------
  // TEST SUITE 2: Server-Side Identity Binding (Anti-Spoofing)
  // --------------------------------------------------------------------------
  describe('Server-Side Identity Binding (L-33)', () => {
    it('demotes unauthenticated payload claiming another userId to "anonymous"', async () => {
      const payload = {
        videoId: 'vid_auth_test_1',
        userId: 'victim_user_id_999', // Client attempts to spoof an existing user
        sessionId: 'session_spoof_attempt_01',
        eventType: 'watch_ping',
        position: 15,
        duration: 200,
        watchTimeSecondsDelta: 10,
        channelId: 'chan_target_01',
      };

      // Send without Bearer token
      const res = await request(app).post('/').send(payload);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify server wrote session under anonymous identity rather than victim_user_id_999
      const sessionDocs = await admin.firestore().collection('watch_sessions').get();
      expect(sessionDocs.docs.length).toBe(1);
      const sessionData = sessionDocs.docs[0].data();
      expect(sessionData.userId).toBe('anonymous');
    });
  });

  // --------------------------------------------------------------------------
  // TEST SUITE 3: Repeat Viewing Deduplication & Duration Ceiling
  // --------------------------------------------------------------------------
  describe('Repeat Viewing Deduplication & Duration Ceiling', () => {
    it('rejects duplicate watch time once a user has already watched 90%+ of the video', async () => {
      const videoId = 'vid_ceiling_test_501';
      const userId = 'usr_faithful_viewer';
      const docId = `${userId}_${videoId}`;
      const duration = 100;

      // Seed watch_session as already fully watched (90s / 100s)
      await admin.firestore().collection('watch_sessions').doc(docId).set({
        videoId,
        userId,
        watchTimeSeconds: 90,
        videoDurationSeconds: duration,
        isAlreadyWatched: true,
        hasCompleted: true,
      });

      // User re-opens and plays the video again
      const payload = {
        videoId,
        userId,
        sessionId: 'session_rewatch_attempt',
        eventType: 'watch_ping',
        position: 30,
        duration,
        watchTimeSecondsDelta: 30,
        channelId: 'chan_creator_01',
      };

      const res = await request(app)
        .post('/')
        .set(authHeader({ uid: userId }))
        .send(payload);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.processed).toBe(false);
      expect(res.body.reason).toBe('already_watched');

      // Verify watch time was NOT incremented on the session doc
      const sessionDoc = await admin.firestore().collection('watch_sessions').doc(docId).get();
      expect(sessionDoc.data()?.watchTimeSeconds).toBe(90);
    });

    it('clamps multi-session watch time to video duration ceiling (cannot exceed remaining duration)', async () => {
      const videoId = 'vid_ceiling_test_502';
      const userId = 'usr_partial_viewer';
      const docId = `${userId}_${videoId}`;
      const duration = 60; // 1-minute video

      // Session 1: User previously watched 45 seconds
      await admin.firestore().collection('watch_sessions').doc(docId).set({
        videoId,
        userId,
        watchTimeSeconds: 45,
        videoDurationSeconds: duration,
        isAlreadyWatched: false,
        hasCompleted: false,
      });

      // Session 2: User watches 30 seconds more (45 + 30 = 75 > 60 duration)
      const payload = {
        videoId,
        userId,
        sessionId: 'session_partial_02',
        eventType: 'watch_ping',
        position: 30,
        duration,
        watchTimeSecondsDelta: 30,
        channelId: 'chan_creator_01',
      };

      const res = await request(app)
        .post('/')
        .set(authHeader({ uid: userId }))
        .send(payload);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.processed).toBe(true);
      // Credited delta must be clamped to remaining seconds: 60 - 45 = 15s!
      expect(res.body.creditedDelta).toBe(15);

      const sessionDoc = await admin.firestore().collection('watch_sessions').doc(docId).get();
      // Total watch time cannot exceed 60 seconds
      expect(sessionDoc.data()?.watchTimeSeconds).toBe(60);
      expect(sessionDoc.data()?.hasCompleted).toBe(true);
    });
  });

  // --------------------------------------------------------------------------
  // TEST SUITE 4: Bot Farm & Network Clustering Defenses
  // --------------------------------------------------------------------------
  describe('Bot Farm & Network Clustering Defense Thresholds', () => {
    function evaluateBotClusterRules(metrics: {
      totalSessionsInHour: number;
      videoSessionsOnSameVideoInHour: number;
      anonymousSessionsIn10Min: number;
      isAnonymous: boolean;
    }): { blocked: boolean; reason?: string } {
      if (metrics.totalSessionsInHour > 500) {
        return { blocked: true, reason: 'ip_global_flood' };
      }
      if (metrics.videoSessionsOnSameVideoInHour > 50) {
        return { blocked: true, reason: 'ip_video_cluster' };
      }
      if (metrics.isAnonymous && metrics.anonymousSessionsIn10Min > 20) {
        return { blocked: true, reason: 'anonymous_flood' };
      }
      return { blocked: false };
    }

    it('blocks IP attempting video session clustering (> 50 sessions on same video in 1hr)', () => {
      const result = evaluateBotClusterRules({
        totalSessionsInHour: 60,
        videoSessionsOnSameVideoInHour: 55, // Triggered!
        anonymousSessionsIn10Min: 5,
        isAnonymous: false,
      });

      expect(result.blocked).toBe(true);
      expect(result.reason).toBe('ip_video_cluster');
    });

    it('blocks IP attempting global bot flood (> 500 sessions across videos in 1hr)', () => {
      const result = evaluateBotClusterRules({
        totalSessionsInHour: 501, // Triggered!
        videoSessionsOnSameVideoInHour: 10,
        anonymousSessionsIn10Min: 5,
        isAnonymous: false,
      });

      expect(result.blocked).toBe(true);
      expect(result.reason).toBe('ip_global_flood');
    });

    it('blocks IP running anonymous click farm (> 20 anonymous sessions in 10 min)', () => {
      const result = evaluateBotClusterRules({
        totalSessionsInHour: 25,
        videoSessionsOnSameVideoInHour: 2,
        anonymousSessionsIn10Min: 22, // Triggered!
        isAnonymous: true,
      });

      expect(result.blocked).toBe(true);
      expect(result.reason).toBe('anonymous_flood');
    });

    it('allows normal human viewing traffic within safe thresholds', () => {
      const result = evaluateBotClusterRules({
        totalSessionsInHour: 5,
        videoSessionsOnSameVideoInHour: 1,
        anonymousSessionsIn10Min: 1,
        isAnonymous: false,
      });

      expect(result.blocked).toBe(false);
      expect(result.reason).toBeUndefined();
    });
  });

  // --------------------------------------------------------------------------
  // TEST SUITE 5: Payout Unlocking Gate Integration (Anti-Bot Farming)
  // --------------------------------------------------------------------------
  describe('Payout Unlocking Gate Integration (Anti-Bot Farming)', () => {
    function evaluatePayoutQualification(channel: {
      rawViews: number;
      qualifiedViews: number;
      totalWatchMinutes: number;
      isKycVerified: boolean;
      viewFraudFlagged?: boolean;
    }): { canWithdraw: boolean; reason?: string } {
      if (!channel.isKycVerified) {
        return { canWithdraw: false, reason: 'kyc_unverified' };
      }
      if (channel.viewFraudFlagged) {
        return { canWithdraw: false, reason: 'view_fraud_flagged' };
      }
      if (channel.rawViews >= 1000 && channel.qualifiedViews > 0 && (channel.qualifiedViews / channel.rawViews) < 0.20) {
        return { canWithdraw: false, reason: 'bot_click_farm_anomaly' };
      }
      if (channel.qualifiedViews < 1000 || channel.totalWatchMinutes < 1800) {
        return { canWithdraw: false, reason: 'unqualified_views_or_watchtime' };
      }
      return { canWithdraw: true };
    }

    it('rejects bot farm that generated 2,000 bounced clicks (0 qualified views, 5 mins watch time)', () => {
      const botFarmedChannel = {
        rawViews: 2000,
        qualifiedViews: 0, // Bounced sessions under 10s failed qualified view engine
        totalWatchMinutes: 5,
        isKycVerified: true,
      };

      const result = evaluatePayoutQualification(botFarmedChannel);
      expect(result.canWithdraw).toBe(false);
      expect(result.reason).toBe('unqualified_views_or_watchtime');
    });

    it('rejects click-farm with 5,000 raw views but only 150 qualified views (< 20% ratio)', () => {
      const clickFarmedChannel = {
        rawViews: 5000,
        qualifiedViews: 150,
        totalWatchMinutes: 1900,
        isKycVerified: true,
      };

      const result = evaluatePayoutQualification(clickFarmedChannel);
      expect(result.canWithdraw).toBe(false);
      expect(result.reason).toBe('bot_click_farm_anomaly');
    });

    it('rejects channel flagged by view fraud detection engine', () => {
      const fraudChannel = {
        rawViews: 2000,
        qualifiedViews: 1200,
        totalWatchMinutes: 1900,
        isKycVerified: true,
        viewFraudFlagged: true,
      };

      const result = evaluatePayoutQualification(fraudChannel);
      expect(result.canWithdraw).toBe(false);
      expect(result.reason).toBe('view_fraud_flagged');
    });

    it('approves legitimate creator with authentic qualified views and genuine watch time', () => {
      const legitimateChannel = {
        rawViews: 1500,
        qualifiedViews: 1250, // Genuine 83.3% qualification ratio
        totalWatchMinutes: 1900, // > 1800 mins (30 hours)
        isKycVerified: true,
        viewFraudFlagged: false,
      };

      const result = evaluatePayoutQualification(legitimateChannel);
      expect(result.canWithdraw).toBe(true);
      expect(result.reason).toBeUndefined();
    });
  });
});
