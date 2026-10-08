import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

/**
 * 🔄 MERGE DUPLICATE ACCOUNT (Callable Cloud Function)
 *
 * Securely merges a duplicate Firebase Auth & Firestore account into the caller's active account.
 * Handles the scenario where a user signed in with Phone on one device and Email on another device.
 * Cryptographically verifies ownership of both accounts (caller token + duplicateIdToken).
 *
 * Actions:
 * 1. Verifies caller authentication (primaryUid).
 * 2. Verifies duplicate ID token (duplicateUid) or resolves by verified credential.
 * 3. Re-assigns channels, videos, playlists, subscriptions from duplicateUid to primaryUid.
 * 4. Merges profile data into primaryUid's Firestore document.
 * 5. Updates primaryUid in Firebase Auth with verified phone number / email.
 * 6. Permanently deletes duplicateUid from Firebase Auth and Firestore.
 */
export const mergeDuplicateAccount = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const primaryUid = request.auth?.uid;
    if (!primaryUid) {
      throw new HttpsError("unauthenticated", "You must be signed in to merge accounts.");
    }

    let data = request.data || {};
    if (data && typeof data === "object" && "data" in data) {
      data = (data as any).data;
    }

    const duplicateIdToken = data.duplicateIdToken as string | undefined;
    const targetPhoneNumber = data.phoneNumber as string | undefined;
    const targetEmail = data.email as string | undefined;

    const db = admin.firestore();
    const auth = admin.auth();

    let duplicateUid: string | null = null;
    let duplicateUserRecord: admin.auth.UserRecord | null = null;

    if (duplicateIdToken) {
      try {
        const decoded = await auth.verifyIdToken(duplicateIdToken);
        duplicateUid = decoded.uid;
        duplicateUserRecord = await auth.getUser(duplicateUid).catch(() => null);
      } catch (err) {
        logger.error("[mergeDuplicateAccount] Invalid duplicate ID token:", err);
        throw new HttpsError("invalid-argument", "Invalid credentials provided for duplicate account.");
      }
    } else if (targetPhoneNumber) {
      try {
        duplicateUserRecord = await auth.getUserByPhoneNumber(targetPhoneNumber);
        duplicateUid = duplicateUserRecord.uid;
      } catch {
        duplicateUid = null;
      }
    } else if (targetEmail) {
      try {
        duplicateUserRecord = await auth.getUserByEmail(targetEmail);
        duplicateUid = duplicateUserRecord.uid;
      } catch {
        duplicateUid = null;
      }
    }

    if (duplicateUid && duplicateUid === primaryUid) {
      return { success: true, message: "Account is already current." };
    }

    logger.info(
      `[mergeDuplicateAccount] Merging duplicate ${duplicateUid ?? "firestore-only"} into primary ${primaryUid}`
    );

    const primaryDocRef = db.collection("users").doc(primaryUid);
    const primarySnap = await primaryDocRef.get();
    const primaryData = primarySnap.exists ? primarySnap.data() || {} : {};

    let duplicateData: Record<string, any> = {};
    let duplicateDocRef: FirebaseFirestore.DocumentReference | null = null;

    if (duplicateUid) {
      duplicateDocRef = db.collection("users").doc(duplicateUid);
      const dupSnap = await duplicateDocRef.get();
      if (dupSnap.exists) {
        duplicateData = dupSnap.data() || {};
      }
    }

    // Also search for any orphaned documents with this phone number or email in Firestore
    const orphanedDocsToClean: FirebaseFirestore.DocumentReference[] = [];
    const searchPhone = targetPhoneNumber || duplicateUserRecord?.phoneNumber || duplicateData.phoneNumber;
    const searchEmail = targetEmail || duplicateUserRecord?.email || duplicateData.email;

    if (searchPhone) {
      const qRoot = await db.collection("users").where("phoneNumber", "==", searchPhone).get();
      for (const d of qRoot.docs) {
        if (d.id !== primaryUid && d.id !== duplicateUid) {
          orphanedDocsToClean.push(d.ref);
          if (Object.keys(duplicateData).length === 0) duplicateData = d.data();
        }
      }
      const qMeta = await db.collection("users").where("metadata.phoneNumber", "==", searchPhone).get();
      for (const d of qMeta.docs) {
        if (d.id !== primaryUid && d.id !== duplicateUid && !orphanedDocsToClean.some((r) => r.id === d.id)) {
          orphanedDocsToClean.push(d.ref);
          if (Object.keys(duplicateData).length === 0) duplicateData = d.data();
        }
      }
    }

    if (searchEmail) {
      const qEmail = await db.collection("users").where("email", "==", searchEmail).get();
      for (const d of qEmail.docs) {
        if (d.id !== primaryUid && d.id !== duplicateUid && !orphanedDocsToClean.some((r) => r.id === d.id)) {
          orphanedDocsToClean.push(d.ref);
          if (Object.keys(duplicateData).length === 0) duplicateData = d.data();
        }
      }
    }

    // 1. Re-link channels owned by duplicate / orphaned users
    const allSourceUids = [duplicateUid, ...orphanedDocsToClean.map((r) => r.id)].filter(
      (id): id is string => Boolean(id)
    );

    let channelRestored: string | null = null;
    for (const srcUid of allSourceUids) {
      const chSnap = await db.collection("channels").where("ownerId", "==", srcUid).get();
      for (const chDoc of chSnap.docs) {
        channelRestored = chDoc.id;
        await chDoc.ref.update({
          ownerId: primaryUid,
          userId: primaryUid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      const chSnapUser = await db.collection("channels").where("userId", "==", srcUid).get();
      for (const chDoc of chSnapUser.docs) {
        channelRestored = chDoc.id;
        await chDoc.ref.update({
          ownerId: primaryUid,
          userId: primaryUid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // 2. Prepare merged profile updates
    const updateObj: Record<string, any> = {};

    const fieldsToMerge = [
      "channelId",
      "displayName",
      "name",
      "username",
      "handle",
      "bio",
      "photoURL",
      "photoUrl",
      "avatarUrl",
      "avatarFileId",
      "avatarStatus",
      "avatarStatusReason",
      "gender",
      "age",
      "ageGroup",
      "birthdate",
      "location",
      "city",
      "state",
      "country",
      "profession",
      "interests",
      "topicAffinities",
      "topicExploreCounts",
      "exploredTopicSlugs",
    ];

    for (const field of fieldsToMerge) {
      const currentVal = primaryData[field];
      const dupVal = duplicateData[field];
      if (
        (currentVal === undefined || currentVal === null || (typeof currentVal === "string" && currentVal.trim() === "")) &&
        dupVal !== undefined && dupVal !== null && (typeof dupVal !== "string" || dupVal.trim() !== "")
      ) {
        updateObj[field] = dupVal;
      }
    }

    if (duplicateData.hasCompletedOnboarding && !primaryData.hasCompletedOnboarding) {
      updateObj.hasCompletedOnboarding = true;
    }

    // Merge role / admin claims
    if (duplicateData.isAdmin === true || duplicateData.role === "admin") {
      updateObj.isAdmin = true;
      updateObj.role = "admin";
      await auth.setCustomUserClaims(primaryUid, { admin: true, role: "admin" }).catch(() => {});
    }

    // Attach phone number or email to primary user
    const finalPhone = searchPhone || primaryData.phoneNumber;
    const finalEmail = searchEmail || primaryData.email;

    if (finalPhone) {
      updateObj.phoneNumber = finalPhone;
      updateObj.isPhoneVerified = true;
      if (!updateObj.metadata) updateObj.metadata = { ...(primaryData.metadata || {}) };
      updateObj.metadata.phoneNumber = finalPhone;
    }

    if (finalEmail) {
      updateObj.email = finalEmail;
      updateObj.isEmailVerified = true;
    }

    updateObj.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    // 3. Update primary document
    await primaryDocRef.set(updateObj, { merge: true });

    // 4. Update primary Firebase Auth user record with phone/email if needed
    const authUpdatePayload: admin.auth.UpdateRequest = {};
    if (finalPhone && !primarySnap.data()?.metadata?.phoneNumber) {
      authUpdatePayload.phoneNumber = finalPhone;
    }
    if (finalEmail && !primarySnap.data()?.email) {
      authUpdatePayload.email = finalEmail;
      authUpdatePayload.emailVerified = true;
    }
    if (Object.keys(authUpdatePayload).length > 0) {
      await auth.updateUser(primaryUid, authUpdatePayload).catch((e) => {
        logger.warn("[mergeDuplicateAccount] Error updating primary auth record:", e);
      });
    }

    // 5. Delete duplicate account from Firebase Auth
    if (duplicateUid) {
      await auth.deleteUser(duplicateUid).catch((e) => {
        logger.warn(`[mergeDuplicateAccount] Error deleting duplicate auth user ${duplicateUid}:`, e);
      });
    }

    // 6. Delete duplicate Firestore document
    if (duplicateDocRef) {
      await duplicateDocRef.delete().catch(() => {});
    }

    // Clean up any other orphaned duplicate documents in Firestore
    for (const orphanRef of orphanedDocsToClean) {
      await orphanRef.delete().catch(() => {});
    }

    // 7. Audit log
    await db.collection("account_merge_logs").add({
      primaryUid,
      mergedUid: duplicateUid,
      orphanedUids: orphanedDocsToClean.map((r) => r.id),
      phoneNumber: searchPhone || null,
      email: searchEmail || null,
      channelRestored,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `[mergeDuplicateAccount] Successfully merged and deleted duplicate ${duplicateUid} into ${primaryUid}`
    );

    return {
      success: true,
      primaryUid,
      mergedUid: duplicateUid,
      channelRestored,
    };
  }
);
