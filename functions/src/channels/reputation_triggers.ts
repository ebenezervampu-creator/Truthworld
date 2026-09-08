import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

const db = admin.firestore();

/**
 * 📊 Update channel rolling reputation and propagate ratings to linked videos
 */
export async function updateChannelReputationAndVideos(jobId: string, trustScore: number): Promise<void> {
  // v12.1 FIX: Guard against unscored videos poisoning channel reputation.
  // When scoring is disabled (v12.0 decoupled mode), trustScore arrives as 0 or null.
  // A genuine "all claims false" rating of 0.0 is extremely rare; the guard uses
  // null/undefined/NaN checks. The caller in 06-credibility.ts now also guards
  // against calling this function when scoring is unavailable.
  if (trustScore === null || trustScore === undefined || isNaN(trustScore)) {
    logger.warn(`[Reputation] Skipping reputation update for job ${jobId} — trustScore is null/undefined/NaN (unscored)`);
    return;
  }

  try {
    // 1. Find the channel(s) associated with this video/job
    const jobDoc = await db.collection("video_jobs").doc(jobId).get();
    const jobData = jobDoc.data();
    const channelId = jobData?.channelId;

    if (!channelId) {
      logger.warn(`[Reputation] No channelId found for job ${jobId}`);
      return;
    }

    const channelRef = db.collection("channels").doc(channelId);

    await db.runTransaction(async (tx) => {
      const channelSnap = await tx.get(channelRef);
      if (!channelSnap.exists) return;

      const channel = channelSnap.data() as any;
      const reputation = channel.reputation || {
        avgTrustIndex: 5.0,
        totalVideos: 0,
        factCheckedVideos: 0,
        videosThisMonth: 0,
        recoveryStreak: 0,
      };

      // A. Calculate New Rolling Average (Weighted towards recent)
      const totalVideos = (reputation.totalVideos || 0) + 1;
      const alpha = 0.2; // 20% weight to new video
      const oldRating = reputation.channelRating ?? reputation.avgTrustIndex ?? 5.0;
      const newAvg = (oldRating * (1 - alpha)) + (trustScore * alpha);

      // B. Update Recovery Streak
      let recoveryStreak = reputation.recoveryStreak || 0;
      if (trustScore >= 9.0) {
        recoveryStreak += 1;
      } else {
        recoveryStreak = 0; // Streak broken!
      }

      // C. Update Trend (30d delta)
      const trend30d = newAvg - oldRating;

      tx.update(channelRef, {
        "reputation.channelRating": parseFloat(newAvg.toFixed(2)),
        "reputation.avgTrustIndex": parseFloat(newAvg.toFixed(2)),
        "reputation.totalVideos": totalVideos,
        "reputation.factCheckedVideos": (reputation.factCheckedVideos || 0) + 1,
        "reputation.videosThisMonth": (reputation.videosThisMonth || 0) + 1,
        "reputation.recoveryStreak": recoveryStreak,
        "reputation.trend30d": parseFloat(trend30d.toFixed(2)),
        "reputation.lastUpdatedAt": Date.now(),
        "stats.channelRating": parseFloat(newAvg.toFixed(2)),
        "stats.avgTrustIndex": parseFloat(newAvg.toFixed(2)),
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });

      // D. Propagate to all linked videos
      const linkedVideoIds = jobData?.linkedVideoIds || [];
      if (jobData?.videoId && !linkedVideoIds.includes(jobData.videoId)) {
        linkedVideoIds.push(jobData.videoId);
      }

      for (const vid of linkedVideoIds) {
        tx.update(db.collection("videos").doc(vid), {
          trustIndex: trustScore,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      logger.info(`[Reputation] Updated channel ${channelId}: TI=${newAvg.toFixed(2)}, Streak=${recoveryStreak}`);
    });

  } catch (err) {
    logger.error(`[Reputation] Error updating channel for job ${jobId}:`, err);
  }
}

