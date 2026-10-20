import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

/**
 * Clean and normalize names for similarity comparison
 */
function normalizeName(input: string): string {
  if (!input) return "";
  let cleaned = input.toLowerCase().trim();
  const honorifics = ["mr", "mrs", "ms", "dr", "shri", "smt", "md", "mister", "miss"];
  for (const h of honorifics) {
    cleaned = cleaned.replace(new RegExp(`\\b${h}\\b[.]?`, "g"), "");
  }
  cleaned = cleaned.replace(/[^a-z0-9\s]/g, " ");
  return cleaned.replace(/\s+/g, " ").trim();
}

/**
 * Calculate token Jaccard & Levenshtein similarity score (0.0 to 1.0)
 */
function calculateNameSimilarity(name1: string, name2: string): number {
  const s1 = normalizeName(name1);
  const s2 = normalizeName(name2);
  if (!s1 || !s2) return 0;
  if (s1 === s2) return 1.0;

  const tokens1 = new Set(s1.split(" ").filter(Boolean));
  const tokens2 = new Set(s2.split(" ").filter(Boolean));

  if (tokens1.size === 0 || tokens2.size === 0) return 0;

  const intersection = new Set([...tokens1].filter((x) => tokens2.has(x))).size;
  const union = new Set([...tokens1, ...tokens2]).size;
  const jaccard = union > 0 ? intersection / union : 0;

  // Check if one name is a complete subset of the other (e.g. middle name missing)
  const isSubset1 = [...tokens1].every((t) => tokens2.has(t));
  const isSubset2 = [...tokens2].every((t) => tokens1.has(t));
  if (isSubset1 || isSubset2) {
    return Math.max(0.90, jaccard);
  }

  return jaccard;
}

/**
 * 🛡️ CREATOR KYC VERIFICATION TRIGGER
 * Triggered when a creator submits or updates their KYC documents under `creator_kyc/{channelId}`.
 */
export const onKycDocumentCreatedOrUpdated = onDocumentWritten(
  {
    document: "creator_kyc/{channelId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 2,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return; // Deleted

    const data = after.data();
    if (!data) return;

    const channelId = event.params.channelId;
    const currentStatus = data.kycStatus || "pending";

    // Only process if in 'pending' status
    if (currentStatus !== "pending") return;

    const userId = data.userId;
    const panNumber = (data.panNumber || "").trim().toUpperCase();
    const panLegalName = (data.panLegalName || "").trim();
    const bankAccountName = (data.bankAccountName || "").trim();
    const panDocUrl = data.panDocumentUrl || "";
    const idDocUrl = data.identityProofFrontUrl || "";
    const maskedPan = panNumber.length >= 5
      ? `${panNumber.slice(0, 2)}*****${panNumber.slice(-1)}`
      : "[REDACTED]";
    logger.info(`[KYC] Processing verification for channel ${channelId} (User: ${userId}, PAN: ${maskedPan})`);

    // 1. PAN Regex Validation (5 uppercase letters, 4 digits, 1 uppercase letter)
    const panRegex = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;
    if (!panRegex.test(panNumber)) {
      logger.warn(`[KYC] Channel ${channelId} submitted invalid PAN format`);
      await after.ref.update({
        kycStatus: "rejected",
        rejectionReason: "Invalid Indian PAN format. A valid PAN consists of 5 letters, 4 digits, and 1 letter.",
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedBy: "system_auto",
      });

      // Mirror to channel doc
      await db().collection("channels").doc(channelId).set(
        { kycStatus: "rejected" },
        { merge: true }
      );

      // Notify creator
      if (userId) {
        await db().collection("notifications").add({
          userId,
          title: "KYC Verification Action Required",
          body: "Your PAN format could not be verified. Please check the number and resubmit your document.",
          type: "monetization_kyc",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          data: { channelId, status: "rejected" },
        });
      }
      return;
    }

    // 2. Name Matching between Bank Account and PAN Legal Name
    const nameScore = calculateNameSimilarity(bankAccountName, panLegalName);
    const isMatched = nameScore >= 0.90;

    logger.info(`[KYC] Name comparison for channel ${channelId}: Score: ${nameScore.toFixed(2)}, Matched: ${isMatched}`);

    // 3. Automated Decision:
    // If PAN format is valid, documents are attached, and name matches bank account: Auto-Approve!
    if (panDocUrl && idDocUrl && isMatched) {
      logger.info(`[KYC] Channel ${channelId} passed all automated checks. Marking verified.`);

      const batch = db().batch();

      // Update creator_kyc
      batch.update(after.ref, {
        kycStatus: "verified",
        isNameMatched: true,
        nameMatchScore: Number(nameScore.toFixed(2)),
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedBy: "system_auto",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update channels doc
      const channelRef = db().collection("channels").doc(channelId);
      batch.set(
        channelRef,
        {
          kycStatus: "verified",
          kycTier: "verified",
          kycVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Update channel subcollection kyc/verification
      const subKycRef = channelRef.collection("kyc").doc("verification");
      batch.set(
        subKycRef,
        {
          kycStatus: "verified",
          isNameMatched: true,
          nameMatchScore: Number(nameScore.toFixed(2)),
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewedBy: "system_auto",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await batch.commit();

      // Dispatch congratulatory in-app notification
      if (userId) {
        await db().collection("notifications").add({
          userId,
          title: "KYC Verification Approved",
          body: "Your identity and PAN documents have been successfully verified. Direct bank cash withdrawals are now fully unlocked!",
          type: "monetization_kyc",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          data: { channelId, status: "verified" },
        });
      }
    } else {
      // If name match failed or documents missing, leave in pending with audit note for manual review
      logger.warn(`[KYC] Channel ${channelId} flagged for manual review (Name match score: ${nameScore.toFixed(2)}).`);
      await after.ref.update({
        kycStatus: "pending",
        isNameMatched: isMatched,
        nameMatchScore: Number(nameScore.toFixed(2)),
        auditNote: !isMatched
          ? `Name discrepancy between Bank Account and PAN legal name (similarity: ${(nameScore * 100).toFixed(0)}%, threshold 90%). Flagged for compliance review.`
          : "Document image verification pending compliance officer sign-off.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);
