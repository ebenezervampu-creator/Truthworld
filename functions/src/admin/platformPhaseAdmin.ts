/**
 * 👑 PLATFORM PHASE MANAGEMENT (ADMIN API)
 *
 * Provides dedicated endpoints for TruthWorld Director (hello@truthworld.in)
 * and authorized Platform Administrators to:
 * 1. Inspect live capacity and rollout phases
 * 2. Instantly switch the platform to any phase (Phase 1, Phase 2, Phase 3, Custom)
 * 3. Batch-admit waitlisted users when capacity opens up
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { isSessionRecent } from "../utils/securityHeaders";
import {
  PHASE_CONFIGS,
  PhaseConfig,
  getDynamicPlatformLimits,
  clearLimitsCache,
} from "../config/platformLimits";

const db = () => admin.firestore();

/**
 * Helper to verify that the caller is an authenticated Director
 * or holds administrative privileges with a verified email.
 */
async function assertAdminCaller(authContext: any): Promise<{ uid: string; email: string }> {
  if (!authContext || !authContext.uid) {
    throw new HttpsError("unauthenticated", "Authentication required to manage platform phases.");
  }

  const token = authContext.token || {};
  const isEmailVerified = token.email_verified === true;
  if (!isEmailVerified) {
    throw new HttpsError("permission-denied", "Verified email address required for administrative operations.");
  }

  const email = (token.email || "").toLowerCase();
  const isAdmin =
    token.admin === true ||
    token.role === "admin" ||
    token.isDirector === true ||
    token.isSuperAdmin === true;

  if (!isAdmin) {
    // Check admin_members collection as fallback
    try {
      const memberDoc = await db().collection("admin_members").doc(email).get();
      if (!memberDoc.exists || memberDoc.data()?.status === "suspended") {
        throw new HttpsError("permission-denied", "Director or Super Admin access required.");
      }
    } catch {
      throw new HttpsError("permission-denied", "Director or Super Admin access required.");
    }
  }

  return { uid: authContext.uid, email: email || "admin" };
}

/**
 * 🚀 SET PLATFORM PHASE (Director / Admin Only)
 * Instantly transitions TruthWorld to Phase 1, Phase 2, Phase 3, or a custom phase.
 */
export const setPlatformPhase = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const caller = await assertAdminCaller(request.auth);
    const authTime = request.auth?.token?.auth_time as number | undefined;
    if (!isSessionRecent(authTime, 3600)) {
      throw new HttpsError("permission-denied", "Recent authentication required to update platform phase.");
    }

    const data = request.data || {};
    const targetPhaseNumber = Number(data.phase);

    if (!targetPhaseNumber || isNaN(targetPhaseNumber) || targetPhaseNumber < 1) {
      throw new HttpsError("invalid-argument", "Valid phase number (e.g. 1, 2, 3) is required.");
    }

    const previousLimits = await getDynamicPlatformLimits();
    const preset: PhaseConfig = PHASE_CONFIGS[targetPhaseNumber] || {
      phase: targetPhaseNumber,
      name: `Phase ${targetPhaseNumber}: Custom Expansion`,
      maxStandardUsers: 500000,
      maxStandardChannels: 5000,
      isCustomChannelUnlimited: true,
      description: `Phase ${targetPhaseNumber} custom capacity limits.`,
    };

    const newConfig = {
      currentPhase: targetPhaseNumber,
      phaseName: data.name || preset.name,
      maxStandardUsers: Number(data.maxStandardUsers) || preset.maxStandardUsers,
      maxStandardChannels: Number(data.maxStandardChannels) || preset.maxStandardChannels,
      isCustomChannelUnlimited: data.isCustomChannelUnlimited !== false,
      description: data.description || preset.description,
      updatedBy: caller.email,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // 1. Persist live limits to Firestore
    await db().collection("system_settings").doc("platform_limits").set(newConfig, { merge: true });

    // 2. Invalidate in-memory cache so subsequent calls reflect change instantly
    clearLimitsCache();

    // 3. Write immutable audit log
    await db().collection("audit_logs").add({
      action: "UPDATE_PLATFORM_PHASE",
      category: "PLATFORM_GOVERNANCE",
      targetPhase: targetPhaseNumber,
      previousPhase: previousLimits.CURRENT_PHASE,
      newLimits: {
        maxUsers: newConfig.maxStandardUsers,
        maxChannels: newConfig.maxStandardChannels,
      },
      actorEmail: caller.email,
      actorUid: caller.uid,
      details: `TruthWorld Director / Admin changed platform phase from Phase ${previousLimits.CURRENT_PHASE} to Phase ${targetPhaseNumber} (${newConfig.phaseName}).`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `[setPlatformPhase] Platform phase successfully updated to Phase ${targetPhaseNumber} by ${caller.email}`
    );

    return {
      success: true,
      phase: targetPhaseNumber,
      phaseName: newConfig.phaseName,
      maxStandardUsers: newConfig.maxStandardUsers,
      maxStandardChannels: newConfig.maxStandardChannels,
      isCustomChannelUnlimited: newConfig.isCustomChannelUnlimited,
      updatedBy: caller.email,
    };
  }
);

/**
 * 📊 GET PLATFORM PHASE CONFIGURATION & BLUEPRINTS
 * Returns current phase, live headroom, and all available rollout phase presets.
 */
export const getPlatformPhaseConfig = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    await assertAdminCaller(request.auth);

    const [currentLimits, usersSnap, allChannelsSnap, customChannelsSnap] = await Promise.all([
      getDynamicPlatformLimits(),
      db().collection("users").count().get(),
      db().collection("channels").where("status", "!=", "deleted").count().get(),
      db().collection("channels").where("channelType", "==", "custom").where("status", "!=", "deleted").count().get(),
    ]);

    const totalUsers = usersSnap.data().count;
    const totalActiveChannels = allChannelsSnap.data().count;
    const customChannels = customChannelsSnap.data().count;
    const standardChannels = Math.max(0, totalActiveChannels - customChannels);

    return {
      currentLimits,
      currentStats: {
        totalUsers,
        standardChannels,
        customChannels,
        remainingUserSlots: Math.max(0, currentLimits.MAX_STANDARD_USERS - totalUsers),
        remainingChannelSlots: Math.max(0, currentLimits.MAX_STANDARD_CHANNELS - standardChannels),
      },
      availablePhasePresets: PHASE_CONFIGS,
    };
  }
);

/**
 * 👥 ADMIT WAITLISTED USERS
 * Promotes waitlisted users to ACTIVE when moving to a higher phase.
 */
export const admitWaitlistedUsers = onCall(
  {
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 300,
    maxInstances: 5,
  },
  async (request) => {
    const caller = await assertAdminCaller(request.auth);
    const limit = Math.min(Number(request.data?.limit) || 200, 500);

    const waitlistedSnap = await db()
      .collection("users")
      .where("accountStatus", "==", "waitlisted")
      .limit(limit)
      .get();

    if (waitlistedSnap.empty) {
      return { success: true, admittedCount: 0, message: "No waitlisted users found." };
    }

    const batch = db().batch();
    waitlistedSnap.docs.forEach((d) => {
      batch.update(d.ref, {
        accountStatus: "ACTIVE",
        isWaitlisted: false,
        admittedBy: caller.email,
        admittedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    await db().collection("audit_logs").add({
      action: "ADMIT_WAITLISTED_USERS",
      category: "USER_MANAGEMENT",
      count: waitlistedSnap.size,
      actorEmail: caller.email,
      actorUid: caller.uid,
      details: `Batch admitted ${waitlistedSnap.size} waitlisted users to ACTIVE.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`[admitWaitlistedUsers] Admitted ${waitlistedSnap.size} users by ${caller.email}`);

    return {
      success: true,
      admittedCount: waitlistedSnap.size,
      message: `Successfully admitted ${waitlistedSnap.size} waitlisted users.`,
    };
  }
);
