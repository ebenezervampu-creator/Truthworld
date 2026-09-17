import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

/**
 * 🏦 PROCESS CREATOR PAYOUT REQUEST
 * Triggered automatically when a creator submits a withdrawal request to their direct bank account or UPI.
 */
export const onPayoutRequestCreated = onDocumentCreated(
  {
    document: "payout_requests/{requestId}",
    region: "asia-south1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const requestId = event.params.requestId;
    const { userId, channelId, amount, paymentMethod, beneficiaryName, bankName, accountNumberMasked, ifscCode } = data;

    logger.info(`[Payouts] Received payout request ${requestId} for channel ${channelId} (User: ${userId}): ₹${amount} via ${paymentMethod}`);

    // 1. Validate minimum threshold (100 Rupees)
    if (!amount || Number(amount) < 100) {
      logger.warn(`[Payouts] Request ${requestId} failed minimum threshold validation (₹${amount} < ₹100). Marking as rejected.`);
      await snap.ref.update({
        status: "rejected",
        rejectReason: "Minimum withdrawal threshold of ₹100 (100 Rupees) not met.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    // 2. Validate Creator KYC Status (Must be 'verified')
    if (channelId) {
      const channelSnap = await db().collection("channels").doc(channelId).get();
      const channelData = channelSnap.data();
      if (!channelData || channelData.kycStatus !== "verified") {
        logger.warn(`[Payouts] Channel ${channelId} attempted payout without verified KYC (Status: ${channelData?.kycStatus}). Rejecting.`);
        await snap.ref.update({
          status: "rejected",
          rejectReason: "KYC document verification (PAN & ID) is required before withdrawing funds.",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }
    }

    try {
      // 3. Mark as processing with authoritative transfer reference
      const transferRef = `TW-PAYOUT-${requestId.slice(0, 8).toUpperCase()}`;
      await snap.ref.update({
        status: "processing",
        transferReference: transferRef,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Send notification to the creator
      if (userId) {
        await db().collection("notifications").add({
          userId,
          title: "Direct Bank Withdrawal Processing",
          body: `Your withdrawal of ₹${Number(amount).toFixed(2)} to ${bankName || "Bank Account"} (${accountNumberMasked || ""}) is verified and being credited via NEFT/IMPS.`,
          type: "monetization_payout",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          data: {
            requestId,
            channelId,
            amount: Number(amount),
            transferReference: transferRef,
            ifscCode: ifscCode || "",
          },
        });
      }

      logger.info(`[Payouts] Payout request ${requestId} successfully scheduled for ${beneficiaryName || "Creator"} (${transferRef})`);
    } catch (err: any) {
      logger.error(`[Payouts] Error processing payout request ${requestId}:`, err);
    }
  }
);
