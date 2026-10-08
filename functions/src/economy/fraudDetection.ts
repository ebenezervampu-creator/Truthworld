import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";

// Velocity thresholds (industry calibrated)
const HOURLY_SPIKE_THRESHOLD_INR = 500;   // ₹500/hr is suspicious for any channel
const ROLLING_SPIKE_MULTIPLIER = 10;       // 10× 7-day average hourly is suspicious
const NEW_CHANNEL_HOLD_DAYS = 30;         // First payout held 30 days (YouTube standard)

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT 1: detectRevenueAnomalies — Scheduled hourly fraud scanner
// Scans all channels for sudden revenue spikes vs their historical baseline.
// Flags suspicious channels with fraudReviewFlag=true and queues for admin review.
// ─────────────────────────────────────────────────────────────────────────────
export const detectRevenueAnomalies = onSchedule(
  { schedule: "every 60 minutes", region: REGION, memory: "512MiB", timeoutSeconds: 540 },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const oneHourAgo = now - 60 * 60 * 1000;
    const hourKey = new Date(now).toISOString().slice(0, 13); // "2026-09-23T14"

    logger.info("[FraudDetection] Starting hourly revenue anomaly scan...");

    try {
      // Read all channels updated in the last hour (recently received ad revenue)
      const channelsSnap = await db.collection("channels")
        .where("updatedAt", ">=", admin.firestore.Timestamp.fromMillis(oneHourAgo))
        .select("adsRevenueTotal", "premiumSubsRevenueTotal", "createdAt", "ownerId", "fraudReviewFlag", "revenueHoldReason")
        .get();

      if (channelsSnap.empty) {
        logger.info("[FraudDetection] No recently updated channels. Scan complete.");
        return;
      }

      logger.info(`[FraudDetection] Scanning ${channelsSnap.docs.length} channels for anomalies.`);

      const batch = db.batch();
      let flaggedCount = 0;

      for (const channelDoc of channelsSnap.docs) {
        const channelId = channelDoc.id;
        const data = channelDoc.data();

        // Skip already-flagged channels (admin reviews those manually)
        if (data.fraudReviewFlag === true) continue;

        const currentAdsRevenue = Number(data.adsRevenueTotal || 0);
        const channelCreatedAt = data.createdAt?.toMillis?.() ?? now;
        const channelAgeMs = now - channelCreatedAt;
        const channelAgeDays = channelAgeMs / (1000 * 60 * 60 * 24);

        // Read the previous hourly snapshot for this channel
        const snapshotRef = db.collection("revenue_hour_snapshots").doc(`${channelId}_${hourKey}`);
        const prevHourKey = new Date(oneHourAgo).toISOString().slice(0, 13);
        const prevSnapshotRef = db.collection("revenue_hour_snapshots").doc(`${channelId}_${prevHourKey}`);
        const prevSnap = await prevSnapshotRef.get();

        const prevAdsRevenue = prevSnap.exists ? Number(prevSnap.data()?.adsRevenueTotal || 0) : 0;
        const hourlyGain = Math.max(0, currentAdsRevenue - prevAdsRevenue);

        // Write current snapshot for next hour's comparison
        batch.set(snapshotRef, {
          channelId,
          adsRevenueTotal: currentAdsRevenue,
          snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
          hourKey,
        });

        // --- RULE 1: Absolute hourly spike ---
        const isAbsoluteSpike = hourlyGain > HOURLY_SPIKE_THRESHOLD_INR;

        // --- RULE 2: Relative spike vs 7-day rolling average ---
        // Read last 7 days of hourly snapshots to compute average hourly gain
        let avgHourlyGain = 0;
        try {
          const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(now - 7 * 24 * 60 * 60 * 1000);
          const recentSnaps = await db.collection("revenue_hour_snapshots")
            .where("channelId", "==", channelId)
            .where("snapshotAt", ">=", sevenDaysAgo)
            .orderBy("snapshotAt", "asc")
            .get();

          if (recentSnaps.docs.length > 1) {
            const oldest = Number(recentSnaps.docs[0].data().adsRevenueTotal || 0);
            const newest = Number(recentSnaps.docs[recentSnaps.docs.length - 1].data().adsRevenueTotal || 0);
            const totalGain = Math.max(0, newest - oldest);
            avgHourlyGain = totalGain / recentSnaps.docs.length;
          }
        } catch (snapshotErr) {
          logger.warn(`[FraudDetection] Could not read snapshots for ${channelId}:`, snapshotErr);
        }

        const isRelativeSpike = avgHourlyGain > 0 &&
          hourlyGain > ROLLING_SPIKE_MULTIPLIER * avgHourlyGain;

        // --- RULE 3: New channel getting any significant revenue ---
        const isNewChannelRevenue = channelAgeDays < NEW_CHANNEL_HOLD_DAYS && hourlyGain > 50;

        if (!isAbsoluteSpike && !isRelativeSpike && !isNewChannelRevenue) continue;

        // Determine reason
        const reasons: string[] = [];
        if (isAbsoluteSpike) reasons.push(`hourly_gain_₹${hourlyGain.toFixed(2)}_exceeds_₹${HOURLY_SPIKE_THRESHOLD_INR}_threshold`);
        if (isRelativeSpike) reasons.push(`${ROLLING_SPIKE_MULTIPLIER}x_velocity_spike_vs_₹${avgHourlyGain.toFixed(2)}_avg`);
        if (isNewChannelRevenue) reasons.push(`new_channel_age_${Math.round(channelAgeDays)}_days_earning_₹${hourlyGain.toFixed(2)}/hr`);

        const revenueHoldReason = reasons.join(" | ");
        logger.warn(`[FraudDetection] FLAGGING channel ${channelId}: ${revenueHoldReason}`);

        // Flag the channel
        batch.set(
          db.collection("channels").doc(channelId),
          {
            fraudReviewFlag: true,
            revenueHoldReason,
            fraudFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Create fraud review queue entry for admin
        batch.set(
          db.collection("fraud_review_queue").doc(channelId),
          {
            channelId,
            ownerId: data.ownerId || "",
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            reasons,
            hourlyGainINR: Math.round(hourlyGain * 100) / 100,
            avgHourlyGainINR: Math.round(avgHourlyGain * 100) / 100,
            channelAgeDays: Math.round(channelAgeDays),
            currentAdsRevenueTotal: currentAdsRevenue,
            status: "pending_review",
            reviewedBy: null,
            reviewedAt: null,
            resolution: null,
          },
          { merge: true }
        );

        flaggedCount++;
      }

      await batch.commit();
      logger.info(`[FraudDetection] Scan complete. Flagged ${flaggedCount} channels for review.`);
    } catch (err) {
      logger.error("[FraudDetection] Anomaly scan failed:", err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT 2: reviewFraudFlag — Admin callable: clear or confirm a fraud flag
// Allows admins to either release held revenue (false positive) or
// confiscate fraudulent revenue and permanently ban channel payouts.
// ─────────────────────────────────────────────────────────────────────────────
export const reviewFraudFlag = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    // Verify admin role via server-minted custom claim only
    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin) throw new HttpsError("permission-denied", "Admin access required.");
    const db = admin.firestore();

    const { channelId, resolution } = (request.data ?? {}) as {
      channelId?: string;
      resolution?: "clear" | "confiscate";
    };

    if (!channelId || !resolution) {
      throw new HttpsError("invalid-argument", "channelId and resolution ('clear' | 'confiscate') are required.");
    }
    if (resolution !== "clear" && resolution !== "confiscate") {
      throw new HttpsError("invalid-argument", "resolution must be 'clear' or 'confiscate'.");
    }

    try {
      if (resolution === "clear") {
        // False positive — remove flag, release funds
        await db.collection("channels").doc(channelId).set(
          {
            fraudReviewFlag: false,
            revenueHoldReason: null,
            fraudFlaggedAt: null,
            fraudClearedAt: admin.firestore.FieldValue.serverTimestamp(),
            fraudClearedBy: userId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      } else {
        // Confirmed fraud — confiscate revenue, permanently flag
        await db.collection("channels").doc(channelId).set(
          {
            fraudReviewFlag: true,
            fraudConfirmed: true,
            adsRevenueTotal: 0,        // Zero out fraudulent revenue
            premiumSubsRevenueTotal: 0,
            payoutsBlocked: true,
            payoutsBlockedReason: "Confirmed fraudulent activity. Account under investigation.",
            fraudConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
            fraudConfirmedBy: userId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      // Update fraud_review_queue
      await db.collection("fraud_review_queue").doc(channelId).set(
        {
          status: resolution === "clear" ? "cleared" : "confirmed_fraud",
          reviewedBy: userId,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolution,
        },
        { merge: true }
      );

      logger.info(`[FraudDetection] Admin ${userId} resolved channel ${channelId}: ${resolution}`);
      return { success: true, channelId, resolution };
    } catch (err) {
      logger.error("[FraudDetection] reviewFraudFlag failed:", err);
      throw new HttpsError("internal", "Failed to update fraud review.");
    }
  }
);
