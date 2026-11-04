import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import * as crypto from 'crypto';
import { isCallableAdmin } from '../utils/auth';
import {
  FraudSignalType,
  FraudSeverity,
  ViewFraudSignal,
  IP_CLUSTER_SAME_VIDEO_THRESHOLD,
  IP_GLOBAL_BLOCK_THRESHOLD,
  BEHAVIORAL_UNIFORMITY_MIN_SESSIONS,
  BEHAVIORAL_UNIFORMITY_CV_THRESHOLD,
  VIEW_VELOCITY_NEW_VIDEO_THRESHOLD,
  VIEW_VELOCITY_BURST_THRESHOLD,
  DEVICE_FINGERPRINT_DOMINANCE_THRESHOLD,
  ANONYMOUS_IP_BLOCK_DURATION_MS,
} from './viewFraudTypes';

const REGION = 'asia-south1';

export function hashIP(ip: string): string {
  return crypto.createHash('sha256').update(ip).digest('hex');
}


async function isIPBlocked(db: admin.firestore.Firestore, ipHash: string): Promise<boolean> {
  const doc = await db.collection('blocked_ips').doc(ipHash).get();
  if (!doc.exists) return false;
  const data = doc.data();
  if (data && data.expiresAt && data.expiresAt.toDate() > new Date()) {
    return true;
  }
  return false;
}

function computeCoefficientOfVariation(values: number[]): number {
  if (values.length === 0) return 0;
  const sum = values.reduce((a, b) => a + b, 0);
  const mean = sum / values.length;
  if (mean === 0) return 0;
  
  const variance = values.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / values.length;
  const stddev = Math.sqrt(variance);
  
  return stddev / mean;
}

export const detectViewFraud = onSchedule({
  schedule: 'every 30 minutes',
  region: REGION,
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const thirtyMinsAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 30 * 60 * 1000);
  
  try {
    logger.info('Starting detectViewFraud');
    const batch = db.batch();
    let batchCount = 0;
    
    const commitBatch = async () => {
      if (batchCount > 0) {
        await batch.commit();
        batchCount = 0;
      }
    };

    // 1. IP Clustering Detection (simplified for illustration - in production would require aggregated views)
    const ipTrackersSnap = await db.collection('view_ip_tracker')
      .where('lastSeenAt', '>=', thirtyMinsAgo)
      .get();
      
    const ipGlobalCounts: Record<string, number> = {};
    const ipVideoCounts: Record<string, Record<string, number>> = {};
    
    ipTrackersSnap.docs.forEach(doc => {
      const data = doc.data();
      const ip = data.ipHash;
      const videoId = data.videoId;
      const count = data.count || 1;
      
      ipGlobalCounts[ip] = (ipGlobalCounts[ip] || 0) + count;
      if (!ipVideoCounts[ip]) ipVideoCounts[ip] = {};
      ipVideoCounts[ip][videoId] = (ipVideoCounts[ip][videoId] || 0) + count;
    });

    const flaggedIPs = new Set<string>();

    for (const [ip, globalCount] of Object.entries(ipGlobalCounts)) {
      if (globalCount > IP_GLOBAL_BLOCK_THRESHOLD) {
        flaggedIPs.add(ip);
        const signalRef = db.collection('view_fraud_signals').doc();
        const signal: ViewFraudSignal = {
          signalType: FraudSignalType.IP_CLUSTER,
          severity: FraudSeverity.CRITICAL,
          videoId: 'global',
          description: `IP globally exceeded threshold with ${globalCount} sessions`,
          evidence: { ipHash: ip, count: globalCount },
          detectedAt: admin.firestore.FieldValue.serverTimestamp(),
          affectedSessionCount: globalCount,
          affectedIPs: [ip],
          status: 'pending_review'
        };
        batch.set(signalRef, signal);
        batchCount++;
      } else {
        for (const [videoId, count] of Object.entries(ipVideoCounts[ip])) {
          if (count > IP_CLUSTER_SAME_VIDEO_THRESHOLD) {
            flaggedIPs.add(ip);
            const signalRef = db.collection('view_fraud_signals').doc();
            const signal: ViewFraudSignal = {
              signalType: FraudSignalType.IP_CLUSTER,
              severity: FraudSeverity.HIGH,
              videoId,
              description: `IP exceeded threshold for video with ${count} sessions`,
              evidence: { ipHash: ip, count, videoId },
              detectedAt: admin.firestore.FieldValue.serverTimestamp(),
              affectedSessionCount: count,
              affectedIPs: [ip],
              status: 'pending_review'
            };
            batch.set(signalRef, signal);
            batchCount++;
          }
        }
      }
    }

    for (const ipHash of flaggedIPs) {
      const blockRef = db.collection('blocked_ips').doc(ipHash);
      batch.set(blockRef, {
        ipHash,
        reason: 'ip_cluster_fraud_detected',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + ANONYMOUS_IP_BLOCK_DURATION_MS)
      }, { merge: true });
      batchCount++;
      
      if (batchCount >= 490) {
        await commitBatch();
      }
    }
    
    // ── 2. Behavioral Uniformity Analysis ──────────────────────────────────────
    // Bot farms produce sessions with unnaturally uniform watch durations,
    // identical device fingerprints, and no seek/pause behavior.
    const recentSessions = await db.collection('watch_sessions')
      .where('lastUpdated', '>=', thirtyMinsAgo)
      .limit(5000)
      .get();

    // Group sessions by videoId
    const videoSessionGroups = new Map<string, Array<{ watchTimeSeconds: number; deviceModel: string; platform: string; playbackRate: number; channelId: string }>>();
    for (const doc of recentSessions.docs) {
      const data = doc.data();
      const vid = data.videoId;
      if (!vid) continue;
      if (!videoSessionGroups.has(vid)) videoSessionGroups.set(vid, []);
      videoSessionGroups.get(vid)!.push({
        watchTimeSeconds: Number(data.watchTimeSeconds || 0),
        deviceModel: data.deviceModel || 'unknown',
        platform: data.platform || 'unknown',
        playbackRate: Number(data.playbackRate || 1),
        channelId: data.channelId || '',
      });
    }

    for (const [videoId, sessions] of videoSessionGroups) {
      if (sessions.length < BEHAVIORAL_UNIFORMITY_MIN_SESSIONS) continue;

      // (a) Watch time coefficient of variation
      const watchTimes = sessions.map(s => s.watchTimeSeconds).filter(t => t > 0);
      const watchTimeCV = computeCoefficientOfVariation(watchTimes);

      // (b) Device fingerprint dominance
      const fingerprintCounts = new Map<string, number>();
      for (const s of sessions) {
        const fp = `${s.deviceModel}|${s.platform}`;
        fingerprintCounts.set(fp, (fingerprintCounts.get(fp) || 0) + 1);
      }
      const maxFPCount = Math.max(...fingerprintCounts.values());
      const fpDominance = maxFPCount / sessions.length;

      // (c) Playback rate uniformity (>90% identical and all 1x = suspicious with other signals)
      const rateOneCounts = sessions.filter(s => s.playbackRate === 1).length;
      const rateUniformity = rateOneCounts / sessions.length;

      const isBehaviorallyUniform = watchTimeCV < BEHAVIORAL_UNIFORMITY_CV_THRESHOLD;
      const isDeviceCluster = fpDominance > DEVICE_FINGERPRINT_DOMINANCE_THRESHOLD;

      if (isBehaviorallyUniform || isDeviceCluster) {
        const severity = (isBehaviorallyUniform && isDeviceCluster) ? FraudSeverity.CRITICAL : FraudSeverity.HIGH;
        const reasons: string[] = [];
        if (isBehaviorallyUniform) reasons.push(`watch_time_CV=${watchTimeCV.toFixed(3)}_below_${BEHAVIORAL_UNIFORMITY_CV_THRESHOLD}`);
        if (isDeviceCluster) reasons.push(`device_fingerprint_dominance=${(fpDominance * 100).toFixed(1)}%_above_${DEVICE_FINGERPRINT_DOMINANCE_THRESHOLD * 100}%`);

        const signalRef = db.collection('view_fraud_signals').doc();
        const signal: ViewFraudSignal = {
          signalType: isDeviceCluster ? FraudSignalType.DEVICE_FINGERPRINT_CLUSTER : FraudSignalType.BEHAVIORAL_UNIFORMITY,
          severity,
          videoId,
          channelId: sessions[0]?.channelId,
          description: `Bot-like behavioral pattern: ${reasons.join(' | ')}`,
          evidence: {
            sessionCount: sessions.length,
            watchTimeCV,
            fpDominance,
            rateUniformity,
            topFingerprint: [...fingerprintCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0],
          },
          detectedAt: admin.firestore.FieldValue.serverTimestamp(),
          affectedSessionCount: sessions.length,
          status: 'pending_review',
        };
        batch.set(signalRef, signal);
        batchCount++;

        // Auto-quarantine for critical severity
        if (severity === FraudSeverity.CRITICAL && sessions[0]?.channelId) {
          const channelId = sessions[0].channelId;
          batch.set(db.collection('channels').doc(channelId), {
            viewFraudReviewFlag: true,
            fraudReviewFlag: true,
            revenueHoldReason: `Bot farm pattern detected: ${reasons.join(' | ')}`,
            fraudFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          batchCount++;

          batch.set(db.collection('fraud_review_queue').doc(channelId), {
            channelId,
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            reasons,
            status: 'pending_review',
            source: 'view_fraud_detection',
            videoId,
            sessionCount: sessions.length,
            evidence: { watchTimeCV, fpDominance, rateUniformity },
          }, { merge: true });
          batchCount++;
        }

        if (batchCount >= 490) await commitBatch();
      }
    }

    // ── 3. View Velocity Detection ───────────────────────────────────────────
    // Flag videos getting views far faster than their organic reach allows.
    for (const [videoId, sessions] of videoSessionGroups) {
      if (sessions.length < 100) continue; // Only check videos with significant activity

      const channelId = sessions[0]?.channelId;
      if (!channelId) continue;

      try {
        // Check channel subscriber count and video age
        const channelSnap = await db.collection('channels').doc(channelId).get();
        const channelData = channelSnap.data();
        const subscriberCount = Number(channelData?.subscriberCount || 0);

        const videoSnap = await db.collection('videos').doc(videoId).get();
        const videoData = videoSnap.data();
        const videoCreatedAt = videoData?.createdAt?.toMillis?.() ?? Date.now();
        const videoAgeHours = (Date.now() - videoCreatedAt) / (1000 * 60 * 60);

        // RULE: New video (<24h) + <100 subs + >1000 sessions in 30min → FLAG
        if (videoAgeHours < 24 && subscriberCount < 100 && sessions.length > VIEW_VELOCITY_NEW_VIDEO_THRESHOLD) {
          const signalRef = db.collection('view_fraud_signals').doc();
          batch.set(signalRef, {
            signalType: FraudSignalType.VIEW_VELOCITY,
            severity: FraudSeverity.CRITICAL,
            videoId,
            channelId,
            description: `New video velocity anomaly: ${sessions.length} sessions in 30min, channel has ${subscriberCount} subscribers, video is ${videoAgeHours.toFixed(1)}h old`,
            evidence: { sessionCount: sessions.length, subscriberCount, videoAgeHours },
            detectedAt: admin.firestore.FieldValue.serverTimestamp(),
            affectedSessionCount: sessions.length,
            status: 'pending_review',
          } as ViewFraudSignal);
          batchCount++;

          // Auto-quarantine
          batch.set(db.collection('channels').doc(channelId), {
            viewFraudReviewFlag: true,
            fraudReviewFlag: true,
            revenueHoldReason: `Velocity anomaly: ${sessions.length} views in 30min on new video with ${subscriberCount} subs`,
            fraudFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          batchCount++;
        }

        // RULE: >5000 sessions from same state in 30min → FLAG (geo-concentrated burst)
        // Note: state-level breakdown requires joining watch_events; for now flag on total volume

        if (sessions.length > VIEW_VELOCITY_BURST_THRESHOLD) {
          const signalRef = db.collection('view_fraud_signals').doc();
          batch.set(signalRef, {
            signalType: FraudSignalType.VIEW_VELOCITY,
            severity: FraudSeverity.HIGH,
            videoId,
            channelId,
            description: `Burst velocity: ${sessions.length} sessions in 30min exceeds ${VIEW_VELOCITY_BURST_THRESHOLD} threshold`,
            evidence: { sessionCount: sessions.length, subscriberCount },
            detectedAt: admin.firestore.FieldValue.serverTimestamp(),
            affectedSessionCount: sessions.length,
            status: 'pending_review',
          } as ViewFraudSignal);
          batchCount++;
        }

        if (batchCount >= 490) await commitBatch();
      } catch (velocityErr) {
        logger.warn(`[ViewFraud] Velocity check failed for ${videoId}:`, velocityErr);
      }
    }

    await commitBatch();
    logger.info(`[ViewFraud] Scan complete. Processed ${recentSessions.size} sessions across ${videoSessionGroups.size} videos.`);
  } catch (error) {
    logger.error('[ViewFraud] detectViewFraud failed:', error);
  }
});

export const cleanupExpiredFraudBlocks = onSchedule({
  schedule: 'every 6 hours',
  region: REGION,
  maxInstances: 1,
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  try {
    const expiredQuery = await db.collection('blocked_ips')
      .where('expiresAt', '<', now)
      .limit(490)
      .get();
      
    if (expiredQuery.empty) return;
    
    const batch = db.batch();
    expiredQuery.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    logger.info(`Deleted ${expiredQuery.size} expired blocked IPs`);
  } catch (error) {
    logger.error('Error in cleanupExpiredFraudBlocks:', error);
  }
});

export const rollbackFraudulentViews = onCall({
  region: REGION,
  memory: '512MiB',
  timeoutSeconds: 300,
}, async (request) => {
  if (!isCallableAdmin(request.auth)) {
    throw new HttpsError('permission-denied', 'Verified admin access required.');
  }
  
  const { videoId, fromTimestamp, toTimestamp, action } = request.data || {};
  if (!videoId || typeof videoId !== 'string' || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId) || !fromTimestamp || !toTimestamp || !action) {
    throw new HttpsError('invalid-argument', 'Missing or invalid required arguments: videoId, fromTimestamp, toTimestamp, action');
  }
  if (action !== 'rollback' && action !== 'preview') {
    throw new HttpsError('invalid-argument', 'action must be "rollback" or "preview"');
  }
  
  try {
    const db = admin.firestore();
    const fromDate = admin.firestore.Timestamp.fromDate(new Date(fromTimestamp));
    const toDate = admin.firestore.Timestamp.fromDate(new Date(toTimestamp));
    
    // Query flagged or blocked-IP sessions in the time window
    const sessionsSnapshot = await db.collection('watch_sessions')
      .where('videoId', '==', videoId)
      .where('lastUpdated', '>=', fromDate)
      .where('lastUpdated', '<=', toDate)
      .limit(2000)
      .get();
      
    let totalAffectedSessions = 0;
    let totalWatchTimeToRollback = 0;
    let totalViewsToRollback = 0;
    let channelId: string | null = null;
    
    // Identify tainted sessions (flagged or from blocked IPs)
    const taintedDocs: Array<{ ref: admin.firestore.DocumentReference; watchTime: number }> = [];
    
    for (const doc of sessionsSnapshot.docs) {
      const data = doc.data();
      
      // Check if session is flagged or from a blocked IP
      const isFlagged = data.flagged === true || data.fraudFlagged === true;
      const sessionIPHash = data.ipHash;
      let isFromBlockedIP = false;
      
      if (sessionIPHash) {
        isFromBlockedIP = await isIPBlocked(db, sessionIPHash);
      }
      
      if (isFlagged || isFromBlockedIP) {
        totalAffectedSessions++;
        const sessionWatchTime = Number(data.watchTimeSeconds || 0);
        totalWatchTimeToRollback += sessionWatchTime;
        if (data.hasCompleted || (data.watchPercentage && data.watchPercentage >= 0.3)) {
          totalViewsToRollback++;
        }
        if (!channelId && data.channelId) channelId = data.channelId;
        taintedDocs.push({ ref: doc.ref, watchTime: sessionWatchTime });
      }
    }
    
    if (action === 'preview') {
      return {
        success: true,
        action: 'preview',
        videoId,
        totalAffectedSessions,
        totalWatchTimeToRollback,
        totalViewsToRollback,
        channelId,
        message: `Preview: ${totalAffectedSessions} tainted sessions found. ${totalWatchTimeToRollback}s watch time and ${totalViewsToRollback} views would be rolled back.`,
      };
    }
    
    // === ROLLBACK MODE ===
    if (totalAffectedSessions === 0) {
      return {
        success: true,
        action: 'rollback',
        totalAffectedSessions: 0,
        message: 'No tainted sessions found in the specified window.',
      };
    }

    // Batch 1: Mark tainted sessions
    let batch = db.batch();
    let ops = 0;
    for (const { ref } of taintedDocs) {
      batch.update(ref, {
        fraudFlagged: true,
        status: 'rolled_back',
        rolledBackAt: admin.firestore.FieldValue.serverTimestamp(),
        rolledBackBy: request.auth!.uid,
      });
      ops++;
      if (ops >= 490) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();

    // Batch 2: Decrement video and channel counters
    const videoRef = db.collection('videos').doc(videoId);
    await videoRef.set({
      totalWatchTimeSeconds: admin.firestore.FieldValue.increment(-totalWatchTimeToRollback),
      viewCount: admin.firestore.FieldValue.increment(-totalViewsToRollback),
      qualifiedViewCount: admin.firestore.FieldValue.increment(-totalViewsToRollback),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    if (channelId) {
      const channelRef = db.collection('channels').doc(channelId);
      await channelRef.set({
        totalWatchTimeSeconds: admin.firestore.FieldValue.increment(-totalWatchTimeToRollback),
        'metrics.totalWatchTimeMinutes': admin.firestore.FieldValue.increment(-totalWatchTimeToRollback / 60),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    // Audit log
    await db.collection('fraud_audit_log').add({
      action: 'rollback',
      videoId,
      channelId,
      totalAffectedSessions,
      totalWatchTimeRolledBack: totalWatchTimeToRollback,
      totalViewsRolledBack: totalViewsToRollback,
      timeWindow: { from: fromTimestamp, to: toTimestamp },
      rolledBackAt: admin.firestore.FieldValue.serverTimestamp(),
      rolledBackBy: request.auth!.uid,
    });

    logger.info(`[ViewFraud] Rollback complete for ${videoId}: ${totalAffectedSessions} sessions, ${totalWatchTimeToRollback}s watch time, ${totalViewsToRollback} views`);

    return {
      success: true,
      action: 'rollback',
      videoId,
      channelId,
      totalAffectedSessions,
      totalWatchTimeRolledBack: totalWatchTimeToRollback,
      totalViewsRolledBack: totalViewsToRollback,
      message: `Rolled back ${totalAffectedSessions} tainted sessions. Removed ${totalWatchTimeToRollback}s watch time and ${totalViewsToRollback} views.`,
    };
  } catch (error) {
    logger.error('[ViewFraud] rollbackFraudulentViews failed:', error);
    throw new HttpsError('internal', 'Failed to process rollback request.');
  }
});
