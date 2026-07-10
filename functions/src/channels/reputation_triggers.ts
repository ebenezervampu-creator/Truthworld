import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

const db = admin.firestore();

/**
 * 📊 TRIGGER: ON FACT CHECK COMPLETED
 * Updates the channel's rolling reputation and manages Recovery Mode streaks.
 */
export const onFactCheckCompleted = onDocumentCreated(
  {
    document: "factChecks/{jobId}",
    region: "asia-south1",
    maxInstances: 2,
  },
  async (event) => {
  const data = event.data?.data();
  if (!data || data.status === "failed") return;

  const jobId = event.params.jobId;
  const videoRating = data.videoRating ?? data.trustIndex ?? 0;
  const trustIndex = videoRating; // legacy compatibility mapping

  try {
    // 1. Find the channel(s) associated with this video/job
    // A job might be linked to multiple videos if it's a deduplicated upload
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
      const newAvg = (oldRating * (1 - alpha)) + (videoRating * alpha);

      // B. Update Recovery Streak
      // Recovery condition: TI >= 9.0
      let recoveryStreak = reputation.recoveryStreak || 0;
      if (trustIndex >= 9.0) {
        recoveryStreak += 1;
      } else {
        recoveryStreak = 0; // Streak broken!
      }

      // C. Update Trend (30d delta)
      const trend30d = newAvg - oldRating;

      tx.update(channelRef, {
        "reputation.channelRating": parseFloat(newAvg.toFixed(2)), // v4.2 Public score
        "reputation.avgTrustIndex": parseFloat(newAvg.toFixed(2)), // Legacy
        "reputation.totalVideos": totalVideos,
        "reputation.factCheckedVideos": (reputation.factCheckedVideos || 0) + 1,
        "reputation.videosThisMonth": (reputation.videosThisMonth || 0) + 1,
        "reputation.recoveryStreak": recoveryStreak,
        "reputation.trend30d": parseFloat(trend30d.toFixed(2)),
        "reputation.lastUpdatedAt": Date.now(),
        "stats.channelRating": parseFloat(newAvg.toFixed(2)),      // v4.2 Public score
        "stats.avgTrustIndex": parseFloat(newAvg.toFixed(2)),      // Legacy
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });

      // D. Propagate to all linked videos
      const linkedVideoIds = jobData?.linkedVideoIds || [];
      if (jobData?.videoId && !linkedVideoIds.includes(jobData.videoId)) {
        linkedVideoIds.push(jobData.videoId);
      }

      for (const vid of linkedVideoIds) {
        tx.update(db.collection("videos").doc(vid), {
          videoRating: videoRating,
          trustIndex: videoRating,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      logger.info(`[Reputation] Updated channel ${channelId}: TI=${newAvg.toFixed(2)}, Streak=${recoveryStreak}`);
    });

  } catch (err) {
    logger.error(`[Reputation] Error updating channel for job ${jobId}:`, err);
  }
});
