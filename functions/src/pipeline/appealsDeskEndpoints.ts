import { CREDIBILITY_REGION } from "../config/regions";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { appealsDeskService } from "./services/appealsDeskService";
import { communityEvidenceService } from "./services/communityEvidenceService";

/**
 * Accredited reviewer check shared by appeal resolution and evidence review:
 * verified email AND (reviewer/admin claim on the token OR an active admin_members role).
 */
async function isAccreditedReviewer(auth: { uid: string; token: any }): Promise<boolean> {
  const token = auth.token;
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
        const uidDoc = await admin.firestore().collection("admin_members").doc(auth.uid).get();
        if (uidDoc.exists && isOmbudsmanRole(uidDoc.data())) {
          isAuthorized = true;
        }
      }
    } catch {
      // Fallback to token check
    }
  }
  return isAuthorized;
}

const APPEALS_ENDPOINT_OPTIONS = {
  region: CREDIBILITY_REGION,
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
  const { videoId, reason, additionalSources, claimId, claimIndex, claimText } = request.data || {};
  try {
    const result = await appealsDeskService.submitFactualDispute({
      videoId,
      userId: request.auth.uid,
      userEmail: request.auth.token.email,
      reason,
      additionalSources,
      claimId: typeof claimId === "string" ? claimId : undefined,
      claimIndex,
      claimText: typeof claimText === "string" ? claimText : undefined,
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
  const isAuthorized = await isAccreditedReviewer(request.auth);
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

/**
 * Reviewer decision on a community / creator evidence submission (claim_sources).
 * Approve → live link check → single-claim re-check with the new evidence.
 */
export const reviewCommunityEvidence = onCall(
  { ...APPEALS_ENDPOINT_OPTIONS, memory: "512MiB" as const, timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to review evidence.");
    }
    if (!(await isAccreditedReviewer(request.auth))) {
      throw new HttpsError("permission-denied", "Only accredited fact-check reviewers may review evidence.");
    }
    const { evidenceId, decision, reviewerNotes } = request.data || {};
    if (typeof evidenceId !== "string" || !evidenceId || (decision !== "approve" && decision !== "reject")) {
      throw new HttpsError("invalid-argument", "Provide an evidenceId and a decision of approve or reject.");
    }
    try {
      return await communityEvidenceService.review({
        evidenceId,
        reviewerId: request.auth.uid,
        decision,
        reviewerNotes: typeof reviewerNotes === "string" ? reviewerNotes : "",
      });
    } catch (err: any) {
      throw new HttpsError("failed-precondition", err?.message || "Unable to review this evidence right now.");
    }
  }
);

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

/**
 * 🛡️ Appeals SLA Watchdog: Auto-escalates pending appeals stuck in "submitted" for > 72 hours.
 * Runs every 6 hours (asia-south1).
 */
export const sweepPendingAppealsSla = onSchedule(
  {
    schedule: "every 6 hours",
    region: CREDIBILITY_REGION,
    timeoutSeconds: 120,
    memory: "256MiB",
    retryCount: 1,
  },
  async () => {
    try {
      const result = await appealsDeskService.sweepPendingAppealsSla();
      console.log("[sweepPendingAppealsSla] SLA sweep completed:", result);
    } catch (err: any) {
      console.error("[sweepPendingAppealsSla] SLA sweep failed:", err);
    }
  }
);
