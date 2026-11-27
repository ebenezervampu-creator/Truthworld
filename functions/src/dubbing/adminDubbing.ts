import { DUBBING_REGION } from "../config/regions";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { DubbingWallet, DubbingWalletTransaction } from "./types";

const db = () => admin.firestore();
const REGION = DUBBING_REGION;

/**
 * 🔒 Verifies that the caller is an authorized administrator or platform owner.
 */
async function assertAdminCaller(authContext: any): Promise<{ uid: string; email: string }> {
  if (!authContext || !authContext.uid) {
    throw new HttpsError("unauthenticated", "Please sign in to perform administrator operations.");
  }

  const token = authContext.token || {};
  const email = (token.email || "").toLowerCase();
  const isEmailVerified = token.email_verified === true || (process.env.NODE_ENV === "test" && token.email_verified !== false);

  const authorizedOwners = [
    "hello@truthworld.in",
    "ebenezervampu4@gmail.com",
    (process.env.ADMIN_OWNER_EMAIL || "hello@truthworld.in").toLowerCase(),
    (process.env.ADMIN_SECONDARY_EMAIL || "hello@truthworld.in").toLowerCase(),
  ];

  const isOwner = token.isDirector === true || (authorizedOwners.includes(email) && isEmailVerified);

  const isSuperAdminOrAdmin =
    isOwner ||
    token.admin === true ||
    token.isSuperAdmin === true ||
    token.role === "admin" ||
    token.role === "Super Admin" ||
    token.role === "Owner" ||
    (Array.isArray(token.roles) &&
      (token.roles.includes("admin") ||
        token.roles.includes("Super Admin") ||
        token.roles.includes("Owner")));

  if (isSuperAdminOrAdmin) {
    return { uid: authContext.uid, email };
  }

  // Check admin_members collection in Firestore
  if (email) {
    try {
      const memberDoc = await db().collection("admin_members").doc(email).get();
      if (memberDoc.exists) {
        const data = memberDoc.data();
        if (data && data.status !== "suspended") {
          return { uid: authContext.uid, email };
        }
      }
    } catch (e) {
      logger.warn("[AdminDubbing:assertAdminCaller] Failed to check admin_members", { email, error: String(e) });
    }
  }

  throw new HttpsError(
    "permission-denied",
    "Administrative privileges required to access Dubbing administration."
  );
}

/**
 * 🎁 Admin: Grant Free Dubbing Credits to a User Account
 */
export const adminGrantDubbingCredits = onCall(
  { region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    const adminUser = await assertAdminCaller(request.auth);
    const {
      targetUserId,
      amountCredits,
      amountUsd = 0.0,
      reason = "Admin Promotional Grant",
      mode = "add", // 'add' or 'set'
    } = request.data || {};

    if (!targetUserId || typeof targetUserId !== "string") {
      throw new HttpsError("invalid-argument", "Valid target user ID is required.");
    }

    const creditsNum = Math.floor(Number(amountCredits));
    if (!Number.isFinite(creditsNum) || (mode === "add" && creditsNum <= 0) || (mode === "set" && creditsNum < 0)) {
      throw new HttpsError("invalid-argument", "Credit amount must be a positive number.");
    }

    const usdNum = Math.max(0, Math.round(Number(amountUsd || 0) * 100) / 100);
    const firestore = db();
    const walletRef = firestore.collection("dubbing_wallets").doc(targetUserId);
    const now = Date.now();

    return await firestore.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef);
      const existingCredits = walletSnap.exists ? Number(walletSnap.data()?.balanceCredits || 0) : 0;
      const existingUsd = walletSnap.exists ? Number(walletSnap.data()?.balanceUsd || 0) : 0.0;
      const existingTxs = walletSnap.exists ? (walletSnap.data()?.transactions || []) : [];

      const newCredits = mode === "set" ? creditsNum : existingCredits + creditsNum;
      const newUsd = mode === "set" ? usdNum : Math.round((existingUsd + usdNum) * 100) / 100;

      const grantTx: DubbingWalletTransaction = {
        id: `tx_admin_${now}_${Math.random().toString(36).substring(2, 6)}`,
        type: "trial_credit",
        amountCredits: creditsNum,
        amountUsd: usdNum,
        description: `Admin Grant: ${reason} (+${creditsNum.toLocaleString()} chars)`,
        timestamp: now,
      };

      const updatedWallet: Partial<DubbingWallet> = {
        userId: targetUserId,
        balanceCredits: newCredits,
        balanceUsd: newUsd,
        updatedAt: now,
        transactions: [grantTx, ...existingTxs],
      };

      tx.set(walletRef, updatedWallet, { merge: true });

      // Record administrative audit trail
      const auditRef = firestore.collection("admin_actions_log").doc();
      tx.set(auditRef, {
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
        action: "DUBBING_GRANT_CREDITS",
        targetUserId,
        amountCredits: creditsNum,
        amountUsd: usdNum,
        mode,
        previousCredits: existingCredits,
        newCredits,
        reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("[AdminDubbing:GrantCredits] Successfully granted dubbing credits", {
        adminEmail: adminUser.email,
        targetUserId,
        creditsNum,
        newCredits,
      });

      return {
        success: true,
        targetUserId,
        balanceCredits: newCredits,
        balanceUsd: newUsd,
        message: `Successfully granted ${creditsNum.toLocaleString()} free credits to user.`,
      };
    });
  }
);

/**
 * 🏷️ Admin: Set Special Dubbing Discount or 100% Free Waiver for a User Account
 */
export const adminSetDubbingDiscount = onCall(
  { region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    const adminUser = await assertAdminCaller(request.auth);
    const {
      targetUserId,
      discountPercent = 0,
      discountType = "none", // 'none', 'percent', 'free'
      reason = "Admin VIP Discount",
      applyToChannels = true,
    } = request.data || {};

    if (!targetUserId || typeof targetUserId !== "string") {
      throw new HttpsError("invalid-argument", "Valid target user ID is required.");
    }

    let cleanType = String(discountType).toLowerCase();
    if (!["none", "percent", "free", "50%"].includes(cleanType)) {
      cleanType = "none";
    }

    let cleanPercent = Math.max(0, Math.min(100, Math.round(Number(discountPercent || 0))));
    if (cleanType === "free") {
      cleanPercent = 100;
    } else if (cleanType === "none") {
      cleanPercent = 0;
    }

    const firestore = db();
    const now = Date.now();
    const walletRef = firestore.collection("dubbing_wallets").doc(targetUserId);
    const userRef = firestore.collection("users").doc(targetUserId);

    const isFree = cleanType === "free" || cleanPercent >= 100;

    await firestore.runTransaction(async (tx) => {
      // 1. Update Dubbing Wallet
      tx.set(
        walletRef,
        {
          userId: targetUserId,
          specialDiscountPercent: cleanPercent,
          specialDiscountType: cleanType,
          isDubbingFree: isFree,
          discountAppliedBy: adminUser.email,
          discountReason: reason,
          discountUpdatedAt: now,
          updatedAt: now,
        },
        { merge: true }
      );

      // 2. Mirror to User Profile document
      tx.set(
        userRef,
        {
          dubbingDiscountPercent: cleanPercent,
          dubbingDiscountType: cleanType,
          isDubbingFree: isFree,
          dubbingDiscountReason: reason,
          dubbingDiscountUpdatedAt: now,
        },
        { merge: true }
      );

      // 3. Log to Admin Audit Trail
      const auditRef = firestore.collection("admin_actions_log").doc();
      tx.set(auditRef, {
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
        action: "DUBBING_SET_SPECIAL_DISCOUNT",
        targetUserId,
        discountPercent: cleanPercent,
        discountType: cleanType,
        isDubbingFree: isFree,
        reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // 4. Optionally propagate to user's creator channels
    if (applyToChannels) {
      try {
        const channelsSnap = await firestore
          .collection("channels")
          .where("ownerId", "==", targetUserId)
          .get();

        const batch = firestore.batch();
        channelsSnap.docs.forEach((doc) => {
          batch.set(
            doc.ref,
            {
              dubbingDiscountPercent: cleanPercent,
              dubbingDiscountType: cleanType,
              isDubbingFree: isFree,
              updatedAt: now,
            },
            { merge: true }
          );
        });

        if (!channelsSnap.empty) {
          await batch.commit();
          logger.info("[AdminDubbing:SetDiscount] Updated channel discounts", {
            targetUserId,
            channelCount: channelsSnap.size,
          });
        }
      } catch (e) {
        logger.warn("[AdminDubbing:SetDiscount] Channel sync notice", { error: String(e) });
      }
    }

    logger.info("[AdminDubbing:SetDiscount] Special discount applied", {
      adminEmail: adminUser.email,
      targetUserId,
      cleanPercent,
      cleanType,
    });

    return {
      success: true,
      targetUserId,
      discountPercent: cleanPercent,
      discountType: cleanType,
      isDubbingFree: isFree,
      message: isFree
        ? "100% Free Dubbing Waiver activated for this user account."
        : cleanPercent > 0
        ? `${cleanPercent}% Special Dubbing Discount activated.`
        : "Dubbing discount reset to standard rate.",
    };
  }
);

/**
 * 🔍 Admin: Get Full Dubbing User Details & Transaction History
 */
export const adminGetDubbingUserDetails = onCall(
  { region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    await assertAdminCaller(request.auth);
    const { targetUserId } = request.data || {};

    if (!targetUserId || typeof targetUserId !== "string") {
      throw new HttpsError("invalid-argument", "Valid target user ID is required.");
    }

    const firestore = db();
    const [userDoc, walletDoc, jobsSnap] = await Promise.all([
      firestore.collection("users").doc(targetUserId).get(),
      firestore.collection("dubbing_wallets").doc(targetUserId).get(),
      firestore
        .collection("dubbing_jobs")
        .where("userId", "==", targetUserId)
        .orderBy("createdAt", "desc")
        .limit(10)
        .get()
        .catch(() => null),
    ]);

    const userData = userDoc.exists ? userDoc.data() : null;
    const walletData = walletDoc.exists ? walletDoc.data() : null;
    const jobs = jobsSnap ? jobsSnap.docs.map((d) => ({ id: d.id, ...d.data() })) : [];

    return {
      success: true,
      user: userData
        ? {
            id: userDoc.id,
            displayName: userData.displayName || userData.name || "",
            email: userData.email || "",
            photoURL: userData.photoURL || "",
            createdAt: userData.createdAt || null,
            dubbingDiscountPercent: userData.dubbingDiscountPercent ?? 0,
            dubbingDiscountType: userData.dubbingDiscountType ?? "none",
            isDubbingFree: userData.isDubbingFree ?? false,
          }
        : null,
      wallet: walletData || {
        userId: targetUserId,
        balanceCredits: 0,
        balanceUsd: 0.0,
        totalCharactersUsed: 0,
        totalSpentUsd: 0.0,
        specialDiscountPercent: 0,
        specialDiscountType: "none",
        isDubbingFree: false,
        transactions: [],
      },
      recentJobs: jobs,
    };
  }
);

/**
 * 📋 Admin: List All Dubbing User & Channel Accounts
 * Correlates users, channels, and dubbing wallets via Admin SDK to bypass client security rule limitations.
 */
export const adminListDubbingAccounts = onCall(
  { region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    await assertAdminCaller(request.auth);
    const firestore = db();

    const [usersSnap, walletsSnap, channelsSnap] = await Promise.all([
      firestore.collection("users").orderBy("createdAt", "desc").limit(150).get().catch(() => null),
      firestore.collection("dubbing_wallets").limit(200).get().catch(() => null),
      firestore.collection("channels").limit(200).get().catch(() => null),
    ]);

    const walletMap = new Map<string, any>();
    if (walletsSnap) {
      walletsSnap.docs.forEach((d) => walletMap.set(d.id, d.data()));
    }

    const channelMap = new Map<string, any>();
    if (channelsSnap) {
      channelsSnap.docs.forEach((d) => {
        const cData = d.data();
        const cOwner = cData.ownerId || cData.userId;
        if (cOwner) {
          channelMap.set(cOwner, { id: d.id, ...cData });
        }
      });
    }

    const accountMap = new Map<string, any>();

    // 1. Process from Users
    if (usersSnap) {
      usersSnap.docs.forEach((doc) => {
        const uData = doc.data();
        const uid = doc.id;
        const wData = walletMap.get(uid);
        const cData = channelMap.get(uid);

        const displayName = (uData.displayName || uData.name || uData.username || "").trim();
        const email = (uData.email || "").trim();
        const fallbackName = displayName || (cData?.name || cData?.channelName) || (email.includes("@") ? email.split("@")[0] : `User ${uid.substring(0, 6)}`);

        const balanceCredits = Number(wData?.balanceCredits || 0);
        const balanceUsd = Number(wData?.balanceUsd || 0);
        const totalUsed = Number(wData?.totalCharactersUsed || 0);

        const discountPercent = Number(wData?.specialDiscountPercent ?? uData.dubbingDiscountPercent ?? cData?.dubbingDiscountPercent ?? 0);
        const discountType = String(wData?.specialDiscountType || uData.dubbingDiscountType || cData?.dubbingDiscountType || "none");
        const isFree = wData?.isDubbingFree === true || uData.isDubbingFree === true || cData?.isDubbingFree === true || discountType === "free" || discountPercent >= 100;

        accountMap.set(uid, {
          id: uid,
          uid,
          displayName: fallbackName,
          email,
          photoURL: uData.photoURL || uData.avatarUrl || cData?.avatarUrl || "",
          accountStatus: uData.accountStatus || "ACTIVE",
          balanceCredits,
          balanceUsd,
          totalCharactersUsed: totalUsed,
          specialDiscountPercent: discountPercent,
          specialDiscountType: discountType,
          isDubbingFree: isFree,
          discountReason: wData?.discountReason || uData.dubbingDiscountReason || "",
          channelId: cData?.id || null,
          channelName: cData?.name || cData?.channelName || null,
          channelHandle: cData?.handle || null,
          customDailyVideoDurationSeconds: cData?.customDailyVideoDurationSeconds || null,
          freeDubbingCredits: cData?.freeDubbingCredits || 0,
          createdAt: uData.createdAt || null,
        });
      });
    }

    // 2. Add Channels whose owners were not captured in users collection
    if (channelsSnap) {
      channelsSnap.docs.forEach((d) => {
        const cData = d.data();
        const uid = cData.ownerId || cData.userId || d.id;
        if (!accountMap.has(uid)) {
          const wData = walletMap.get(uid);
          const channelName = (cData.name || cData.channelName || "Creator Channel").trim();
          const balanceCredits = Number(wData?.balanceCredits || 0);
          const balanceUsd = Number(wData?.balanceUsd || 0);
          const totalUsed = Number(wData?.totalCharactersUsed || 0);

          const discountPercent = Number(wData?.specialDiscountPercent ?? cData.dubbingDiscountPercent ?? 0);
          const discountType = String(wData?.specialDiscountType || cData.dubbingDiscountType || "none");
          const isFree = wData?.isDubbingFree === true || cData.isDubbingFree === true || discountType === "free" || discountPercent >= 100;

          accountMap.set(uid, {
            id: uid,
            uid,
            displayName: channelName,
            email: cData.email || "",
            photoURL: cData.avatarUrl || "",
            accountStatus: cData.status || "ACTIVE",
            balanceCredits,
            balanceUsd,
            totalCharactersUsed: totalUsed,
            specialDiscountPercent: discountPercent,
            specialDiscountType: discountType,
            isDubbingFree: isFree,
            discountReason: wData?.discountReason || "",
            channelId: d.id,
            channelName,
            channelHandle: cData.handle || null,
            customDailyVideoDurationSeconds: cData.customDailyVideoDurationSeconds || null,
            freeDubbingCredits: cData.freeDubbingCredits || 0,
            createdAt: cData.createdAt || null,
          });
        }
      });
    }

    // 3. Add wallets whose users were not yet captured
    walletMap.forEach((wData, uid) => {
      if (!accountMap.has(uid)) {
        const balanceCredits = Number(wData.balanceCredits || 0);
        const balanceUsd = Number(wData.balanceUsd || 0);
        const discountPercent = Number(wData.specialDiscountPercent || 0);
        const discountType = String(wData.specialDiscountType || "none");
        const isFree = wData.isDubbingFree === true || discountType === "free" || discountPercent >= 100;

        accountMap.set(uid, {
          id: uid,
          uid,
          displayName: `User ${uid.substring(0, 6)}`,
          email: "",
          photoURL: "",
          accountStatus: "ACTIVE",
          balanceCredits,
          balanceUsd,
          totalCharactersUsed: Number(wData.totalCharactersUsed || 0),
          specialDiscountPercent: discountPercent,
          specialDiscountType: discountType,
          isDubbingFree: isFree,
          discountReason: wData.discountReason || "",
          channelId: null,
          channelName: null,
          createdAt: wData.createdAt || null,
        });
      }
    });

    const accounts = Array.from(accountMap.values());
    accounts.sort((a, b) => {
      if (a.isDubbingFree === true && b.isDubbingFree !== true) return -1;
      if (b.isDubbingFree === true && a.isDubbingFree !== true) return 1;
      if (a.specialDiscountPercent !== b.specialDiscountPercent) {
        return b.specialDiscountPercent - a.specialDiscountPercent;
      }
      return b.balanceCredits - a.balanceCredits;
    });

    return {
      success: true,
      accounts,
      count: accounts.length,
    };
  }
);

/**
 * 🎁 Admin: Grant Free Dubbing Studio Credits, Discounts & Upload Duration for a Specific Channel Directly
 */
export const adminGrantChannelDubbingCredits = onCall(
  { region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    const adminUser = await assertAdminCaller(request.auth);
    const {
      channelId,
      amountCredits = 0,
      amountUsd = 0.0,
      reason = "Super Admin Channel Privilege Grant",
      customDailyDurationMinutes,
      dubbingDiscountPercent,
      dubbingDiscountType,
      subtitlesDiscountPercent,
      subtitlesDiscountType,
    } = request.data || {};

    if (!channelId || typeof channelId !== "string") {
      throw new HttpsError("invalid-argument", "Valid target channel ID is required.");
    }

    const creditsNum = Math.floor(Number(amountCredits || 0));
    if (creditsNum < 0) {
      throw new HttpsError("invalid-argument", "Credit grant amount must be non-negative.");
    }

    const firestore = db();
    const now = Date.now();
    const channelRef = firestore.collection("channels").doc(channelId);

    const channelSnap = await channelRef.get();
    if (!channelSnap.exists) {
      throw new HttpsError("not-found", `Channel with ID "${channelId}" not found.`);
    }

    const channelData = channelSnap.data() || {};
    const ownerId = channelData.ownerId || channelData.userId || channelId;
    const channelName = channelData.name || channelData.channelName || "Channel";
    const channelHandle = channelData.handle || channelId;
    const walletRef = firestore.collection("dubbing_wallets").doc(ownerId);
    const userRef = firestore.collection("users").doc(ownerId);

    return await firestore.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef);
      const existingCredits = walletSnap.exists ? Number(walletSnap.data()?.balanceCredits || 0) : 0;
      const existingUsd = walletSnap.exists ? Number(walletSnap.data()?.balanceUsd || 0) : 0.0;
      const existingTxs = walletSnap.exists ? (walletSnap.data()?.transactions || []) : [];

      const newCredits = existingCredits + creditsNum;
      const newUsd = Math.round((existingUsd + Number(amountUsd || 0)) * 100) / 100;

      // 1. Record credit transaction in wallet if credits were granted
      let newTxs = existingTxs;
      if (creditsNum > 0) {
        const grantTx: DubbingWalletTransaction = {
          id: `tx_chan_admin_${now}_${Math.random().toString(36).substring(2, 6)}`,
          type: "trial_credit",
          amountCredits: creditsNum,
          amountUsd: Number(amountUsd || 0),
          description: `Super Admin Grant to Channel @${channelHandle}: ${reason} (+${creditsNum.toLocaleString()} chars)`,
          timestamp: now,
        };
        newTxs = [grantTx, ...existingTxs];
      }

      // 2. Prepare channel updates
      const channelUpdates: Record<string, any> = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (creditsNum > 0) {
        const existingGranted = Number(channelData.freeDubbingCredits || 0);
        channelUpdates.freeDubbingCredits = existingGranted + creditsNum;
        channelUpdates.dubbingCreditsGrantedTotal = Number(channelData.dubbingCreditsGrantedTotal || 0) + creditsNum;
        channelUpdates.lastDubbingCreditsGranted = creditsNum;
        channelUpdates.lastDubbingGrantReason = reason;
        channelUpdates.lastDubbingGrantAt = now;
        channelUpdates.lastDubbingGrantBy = adminUser.email;
      }

      // Update upload limit duration if specified
      if (customDailyDurationMinutes !== undefined && customDailyDurationMinutes !== null) {
        const minutes = Math.max(10, Math.min(1440, Math.round(Number(customDailyDurationMinutes))));
        const dailySeconds = minutes * 60;
        channelUpdates.customDailyVideoDurationSeconds = dailySeconds;
        channelUpdates.customDailyUploadLimitMinutes = minutes;
        channelUpdates.maxDailyVideoDurationSeconds = dailySeconds;
        channelUpdates.hasCustomQuota = minutes > 10;
        channelUpdates.quotaIncreasedBy = adminUser.email;
        channelUpdates.quotaIncreasedAt = admin.firestore.FieldValue.serverTimestamp();
        channelUpdates.quotaIncreaseReason = reason;
      }

      // Update dubbing discount if specified
      let cleanDubType = dubbingDiscountType !== undefined ? String(dubbingDiscountType).toLowerCase() : undefined;
      let cleanDubPercent = dubbingDiscountPercent !== undefined ? Math.max(0, Math.min(100, Math.round(Number(dubbingDiscountPercent)))) : undefined;
      if (cleanDubType === "free") cleanDubPercent = 100;
      if (cleanDubType === "none") cleanDubPercent = 0;
      const isDubFree = cleanDubType === "free" || (cleanDubPercent !== undefined && cleanDubPercent >= 100);

      if (cleanDubType !== undefined) {
        channelUpdates.dubbingDiscountType = cleanDubType;
        channelUpdates.dubbingDiscountPercent = cleanDubPercent;
        channelUpdates.isDubbingFree = isDubFree;
      }

      // Update subtitles discount if specified
      let cleanSubType = subtitlesDiscountType !== undefined ? String(subtitlesDiscountType).toLowerCase() : undefined;
      let cleanSubPercent = subtitlesDiscountPercent !== undefined ? Math.max(0, Math.min(100, Math.round(Number(subtitlesDiscountPercent)))) : undefined;
      if (cleanSubType === "free") cleanSubPercent = 100;
      if (cleanSubType === "none") cleanSubPercent = 0;
      const isSubFree = cleanSubType === "free" || (cleanSubPercent !== undefined && cleanSubPercent >= 100);

      if (cleanSubType !== undefined) {
        channelUpdates.subtitlesDiscountType = cleanSubType;
        channelUpdates.subtitlesDiscountPercent = cleanSubPercent;
        channelUpdates.isSubtitlesFree = isSubFree;
      }

      // 3. Update Dubbing Wallet
      const walletUpdates: Partial<DubbingWallet> = {
        userId: ownerId,
        balanceCredits: newCredits,
        balanceUsd: newUsd,
        updatedAt: now,
        transactions: newTxs,
      };

      if (cleanDubType !== undefined) {
        walletUpdates.specialDiscountPercent = cleanDubPercent;
        walletUpdates.specialDiscountType = cleanDubType;
        walletUpdates.isDubbingFree = isDubFree;
        walletUpdates.discountAppliedBy = adminUser.email;
        walletUpdates.discountReason = reason;
        walletUpdates.discountUpdatedAt = now;
      }

      tx.set(walletRef, walletUpdates, { merge: true });
      tx.set(channelRef, channelUpdates, { merge: true });

      // 4. Mirror to user profile if user exists
      const userUpdates: Record<string, any> = {
        updatedAt: now,
      };
      if (cleanDubType !== undefined) {
        userUpdates.dubbingDiscountPercent = cleanDubPercent;
        userUpdates.dubbingDiscountType = cleanDubType;
        userUpdates.isDubbingFree = isDubFree;
        userUpdates.dubbingDiscountReason = reason;
      }
      tx.set(userRef, userUpdates, { merge: true });

      // 5. Admin Actions Audit Log
      const auditRef = firestore.collection("admin_actions_log").doc();
      tx.set(auditRef, {
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
        action: "SUPER_ADMIN_CHANNEL_PRIVILEGES_GRANT",
        targetChannelId: channelId,
        targetChannelName: channelName,
        targetUserId: ownerId,
        amountCredits: creditsNum,
        newBalanceCredits: newCredits,
        customDailyDurationMinutes: customDailyDurationMinutes || null,
        dubbingDiscountPercent: cleanDubPercent ?? null,
        dubbingDiscountType: cleanDubType ?? null,
        subtitlesDiscountPercent: cleanSubPercent ?? null,
        subtitlesDiscountType: cleanSubType ?? null,
        reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("[AdminDubbing:GrantChannelPrivileges] Successfully updated channel privileges", {
        adminEmail: adminUser.email,
        channelId,
        ownerId,
        creditsNum,
        newCredits,
      });

      return {
        success: true,
        channelId,
        ownerId,
        channelName,
        grantedCredits: creditsNum,
        balanceCredits: newCredits,
        message: creditsNum > 0
          ? `Successfully granted ${creditsNum.toLocaleString()} free Dubbing Studio credits to ${channelName}.`
          : `Successfully updated privileges for ${channelName}.`,
      };
    });
  }
);
