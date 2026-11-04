import * as admin from "firebase-admin";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { Request, Response } from "express";
import { logger } from "../pipeline/utils/logger";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { isCallableRecentAdmin } from "../utils/auth";

const db = () => admin.firestore();

/**
 * 📡 GET ALGORITHM REMOTE CONFIG (Public HTTPS)
 *
 * Edge-cached dynamic algorithm weight provider.
 * Used by Truthworld client apps to fetch live surface weights and active version.
 */
export const getAlgorithmRemoteConfig = onRequest(
  {
    region: "asia-south1",
    cors: true,
    memory: "256MiB",
    maxInstances: 5,
  },
  async (req: Request, res: Response) => {
    applySecurityHeaders(res);
    res.set("Cache-Control", "public, max-age=300, s-maxage=1800");

    try {
      const docSnap = await db()
        .collection("remote_config")
        .doc("algorithm_weights")
        .get();

      if (docSnap.exists) {
        res.status(200).json({
          success: true,
          data: docSnap.data(),
        });
        return;
      }

      // Default baseline weights if remote doc not yet initialized
      res.status(200).json({
        success: true,
        data: {
          version: "v1",
          weights: {
            homeFeedAll: {
              topicAffinity: 0.18,
              channelAffinity: 0.10,
              engagement: 0.05,
              freshness: 0.12,
              trending: 0.08,
              watchCompletion: 0.05,
              sessionBoost: 0.13,
              penalty: 0.07,
              knowledgeQuality: 0.10,
              twoTowerAffinity: 0.12,
            },
          },
        },
      });
    } catch (err) {
      logger.error("[getAlgorithmRemoteConfig] Error:", err);
      res.status(500).json({
        success: false,
        error: "Unable to retrieve algorithm configuration",
      });
    }
  }
);

/**
 * 🛠️ UPDATE ALGORITHM REMOTE CONFIG (Admin onCall)
 *
 * Allows verified administrators to tune recommendation weights on the fly
 * without client code updates or app store redeployments.
 */
export const updateAlgorithmRemoteConfig = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required to update algorithm config."
      );
    }

    // Verify admin privileges and recent session (strictly requires verified email)
    if (!isCallableRecentAdmin(request.auth, 3600)) {
      throw new HttpsError(
        "permission-denied",
        "Administrative privileges with verified email and recent authentication required."
      );
    }

    const { version, weights } = request.data || {};
    if (!version || typeof version !== "string" || !weights || typeof weights !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Invalid payload. Required: version (string), weights (object)."
      );
    }

    try {
      await db().collection("remote_config").doc("algorithm_weights").set(
        {
          version,
          weights,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: request.auth.uid,
        },
        { merge: true }
      );

      logger.info(
        `[updateAlgorithmRemoteConfig] Successfully updated algorithm weights to version ${version} by ${request.auth.uid}`
      );

      return {
        success: true,
        version,
        message: "Algorithm weights updated successfully.",
      };
    } catch (err) {
      logger.error("[updateAlgorithmRemoteConfig] Error saving config:", err);
      throw new HttpsError("internal", "Failed to update algorithm weights.");
    }
  }
);
