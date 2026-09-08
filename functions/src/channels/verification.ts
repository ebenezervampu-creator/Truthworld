import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { VerificationRequest } from "./types";
import { isCallableAdmin } from "../utils/auth";

const db = admin.firestore();

/**
 * 🛡️ REQUEST INSTITUTIONAL VERIFICATION (Callable)
 * Allows creators to apply for Org/Newsroom/Edu status.
 */
export const requestInstitutionalVerification = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId, type, legalName, website, documents } = request.data;
    if (!channelId || !type || !legalName) {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    try {
      // 1. Verify ownership
      const channelSnap = await db.collection("channels").doc(channelId).get();
      if (!channelSnap.exists) throw new HttpsError("not-found", "Channel not found.");
      if (channelSnap.data()?.ownerId !== userId) throw new HttpsError("permission-denied", "Not owner.");

      // 2. Check for existing pending request
      const existingSnap = await db.collection("verification_requests")
        .where("channelId", "==", channelId)
        .where("status", "==", "pending")
        .get();
      
      if (!existingSnap.empty) {
        throw new HttpsError("already-exists", "A request is already pending for this channel.");
      }

      // 3. Create request
      const requestId = db.collection("verification_requests").doc().id;
      const verificationRequest: VerificationRequest = {
        id: requestId,
        channelId,
        userId,
        type,
        legalName,
        website: website || "",
        documents: documents || [],
        status: "pending",
        createdAt: Date.now()
      };

      await db.collection("verification_requests").doc(requestId).set(verificationRequest);
      
      logger.info(`[Verification] New request created for ${channelId} (${type})`);
      
      return { success: true, requestId };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[requestInstitutionalVerification] Error:", err);
      throw new HttpsError("internal", "Failed to submit request.");
    }
  }
);

/**
 * ✅ APPROVE VERIFICATION (Internal/Admin)
 * Updates channel verification state and status.
 */
export const approveVerification = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    if (!isCallableAdmin(request.auth)) {
      throw new HttpsError("permission-denied", "Admin privileges required to approve verification.");
    }

    const { requestId, status, notes } = request.data;
    if (!requestId || !status) throw new HttpsError("invalid-argument", "Missing data.");

    try {
      await db.runTransaction(async (tx) => {
        const reqRef = db.collection("verification_requests").doc(requestId);
        const reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");

        const reqData = reqSnap.data() as VerificationRequest;
        const channelRef = db.collection("channels").doc(reqData.channelId);

        tx.update(reqRef, {
          status,
          notes: notes || "",
          reviewedAt: Date.now()
        });

        if (status === "approved") {
          // Map request type to verification state
          const newState = reqData.type === "newsroom" ? "newsroom" : "institutional";
          tx.update(channelRef, {
            verification: newState,
            updatedAt: Date.now()
          });
        }
      });

      return { success: true };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[approveVerification] Error:", err);
      throw new HttpsError("internal", "Approval failed.");
    }
  }
);
