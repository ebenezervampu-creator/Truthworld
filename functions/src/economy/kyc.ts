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

    // 3. Automated Compliance Pre-Screening:
    // 🛡️ Security Invariant: Client-submitted name strings MUST NEVER auto-approve KYC (TW-ECON-02).
    // All documents are queued with computed pre-screening scores for authorized compliance officer review.
    const hasDocuments = Boolean(panDocUrl && idDocUrl);
    const auditNote = !hasDocuments
      ? "Document image verification pending. PAN and Government ID document uploads required."
      : !isMatched
      ? `Name discrepancy between Bank Account and PAN legal name (similarity: ${(nameScore * 100).toFixed(0)}%, threshold 90%). Queued for compliance officer review.`
      : "Automated format and similarity pre-checks passed. Queued for compliance officer sign-off.";

    logger.info(`[KYC] Channel ${channelId} pre-screened. Documents: ${hasDocuments}, NameMatch: ${isMatched}. Queued for compliance officer approval.`);

    const batch = db().batch();

    // Update creator_kyc document with audit scores
    batch.update(after.ref, {
      kycStatus: "pending",
      isNameMatched: isMatched,
      nameMatchScore: Number(nameScore.toFixed(2)),
      auditNote,
      reviewedAt: null,
      reviewedBy: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Ensure channel status reflects pending verification
    const channelRef = db().collection("channels").doc(channelId);
    batch.set(
      channelRef,
      {
        kycStatus: "pending",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Update channel subcollection kyc/verification
    const subKycRef = channelRef.collection("kyc").doc("verification");
    batch.set(
      subKycRef,
      {
        kycStatus: "pending",
        isNameMatched: isMatched,
        nameMatchScore: Number(nameScore.toFixed(2)),
        auditNote,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await batch.commit();

    if (userId) {
      await db().collection("notifications").add({
        userId,
        title: "KYC Documents Under Review",
        body: "Your identity and PAN verification documents have been received and queued for compliance officer review.",
        type: "monetization_kyc",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: { channelId, status: "pending" },
      });
    }
  }
);
