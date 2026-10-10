import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { appealsDeskService } from "./services/appealsDeskService";

export const submitClaimAppeal = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to submit an appeal.");
  }
  const { videoId, claimId, claimText, originalVerdict, creatorRationale, evidenceUrls } = request.data || {};
  try {
    const result = await appealsDeskService.submitClaimAppeal({
      videoId,
      claimId,
      appellantId: request.auth.uid,
      claimText,
      originalVerdict,
      creatorRationale,
      evidenceUrls,
    });
    return result;
  } catch (err: any) {
    throw new HttpsError("invalid-argument", err?.message || "Failed to submit claim appeal.");
  }
});

export const resolveClaimAppeal = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to resolve an appeal.");
  }
  const token = request.auth.token;
  let isAuthorized = token.role === "admin" || token.role === "ombudsman" || token.isReviewer === true || token.admin === true;
  
  if (!isAuthorized && token.email) {
    const email = (token.email || "").toLowerCase();
    if (email === "hello@truthworld.in") {
      isAuthorized = true;
    } else {
      try {
        const memberDoc = await admin.firestore().collection("admin_members").doc(email).get();
        if (memberDoc.exists && memberDoc.data()?.status !== "suspended") {
          isAuthorized = true;
        }
      } catch {
        // Fallback to token check
      }
    }
  }

  if (!isAuthorized) {
    throw new HttpsError("permission-denied", "Only accredited fact-check ombudsman reviewers may resolve appeals.");
  }

  const { appealId, decision, newVerdict, reviewerNotes } = request.data || {};
  try {
    const result = await appealsDeskService.resolveClaimAppeal({
      appealId,
      reviewerId: request.auth.uid,
      decision,
      newVerdict,
      reviewerNotes,
    });
    return result;
  } catch (err: any) {
    throw new HttpsError("invalid-argument", err?.message || "Failed to resolve claim appeal.");
  }
});

export const verifyGovernanceAuditChain = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to verify governance audit logs.");
  }
  const { targetId } = request.data || {};
  if (!targetId) {
    throw new HttpsError("invalid-argument", "Missing required targetId parameter.");
  }
  try {
    const result = await appealsDeskService.verifyAuditLogChain(targetId);
    return result;
  } catch (err: any) {
    throw new HttpsError("internal", err?.message || "Failed to verify governance audit log chain.");
  }
});
