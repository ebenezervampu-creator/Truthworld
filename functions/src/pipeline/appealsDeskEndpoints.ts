import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { appealsDeskService } from "./services/appealsDeskService";

const APPEALS_ENDPOINT_OPTIONS = {
  region: "asia-south1",
  memory: "256MiB" as const,
  timeoutSeconds: 30,
};

export const submitClaimAppeal = onCall(APPEALS_ENDPOINT_OPTIONS, async (request) => {
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

export const submitFactualDispute = onCall(APPEALS_ENDPOINT_OPTIONS, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to submit a factual dispute.");
  }
  const { videoId, reason, additionalSources, claimId, claimIndex } = request.data || {};
  try {
    const result = await appealsDeskService.submitFactualDispute({
      videoId,
      userId: request.auth.uid,
      userEmail: request.auth.token.email,
      reason,
      additionalSources,
      claimId,
      claimIndex,
    });
    return result;
  } catch (err: any) {
    throw new HttpsError("invalid-argument", err?.message || "Failed to submit factual dispute.");
  }
});

export const resolveClaimAppeal = onCall(APPEALS_ENDPOINT_OPTIONS, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to resolve an appeal.");
  }
    const token = request.auth.token;
  const isEmailVerified = token.email_verified === true;
  let isAuthorized = (token.role === "admin" || token.role === "ombudsman" || token.isReviewer === true || token.admin === true) && isEmailVerified;
  
  if (!isAuthorized && token.email && isEmailVerified) {
    const email = (token.email || "").toLowerCase().trim();
    const isOmbudsmanRole = (docData: any) => {
      if (!docData || docData.status === "suspended") return false;
      const authorizedRoles = ["Super Admin", "Owner", "admin", "ombudsman", "Fact-Check Reviewer"];
      const roles: string[] = Array.isArray(docData.roles) ? docData.roles : (docData.role ? [docData.role] : []);
      return roles.some((r: string) => authorizedRoles.includes(r)) || docData.isReviewer === true || docData.isAdmin === true;
    };
    try {
      const memberDoc = await admin.firestore().collection("admin_members").doc(email).get();
      if (memberDoc.exists && isOmbudsmanRole(memberDoc.data())) {
        isAuthorized = true;
      } else {
        const uidDoc = await admin.firestore().collection("admin_members").doc(request.auth.uid).get();
        if (uidDoc.exists && isOmbudsmanRole(uidDoc.data())) {
          isAuthorized = true;
        }
      }
    } catch {
      // Fallback to token check
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

export const verifyGovernanceAuditChain = onCall(APPEALS_ENDPOINT_OPTIONS, async (request) => {
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
    throw new HttpsError("internal", "Unable to verify governance audit log chain. Please try again later.");
  }
});
