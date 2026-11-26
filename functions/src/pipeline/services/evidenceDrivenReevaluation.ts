/**
 * Evidence-Driven Re-evaluation
 *
 * A published verdict is a function of its evidence, not a fixed label. Whenever the set
 * of live sources behind a claim changes — a source dies or is retracted, source healing
 * finds new sources, a reviewer approves community evidence, a cached verdict's links
 * stop resolving — the claim is re-evaluated here:
 *
 *   - sources ADDED   → the claim is re-judged by the model on the full new evidence set,
 *                       then passed through the evidence rule (reconcileVerdictWithEvidence).
 *   - sources REMOVED → no new evidence to read, so the existing verdict is re-checked
 *                       against the evidence rule only (e.g. no sources left → "unproven").
 *   - nothing changed → the claim is returned untouched.
 *
 * Every verdict change is appended to `verdictHistory` so viewers and auditors can see
 * what changed, when, and why.
 */

import { ClaimStatus, RichSource, VerifiedClaim } from "../types";
import { reconcileVerdictWithEvidence } from "./verdictReconciliation";
import { classifySourceStances } from "./stanceClassifier";

export type StanceClassifierFn = (claimText: string, sources: RichSource[]) => Promise<RichSource[]>;

export type EvidenceChangeTrigger =
  | "source_health"
  | "community_evidence"
  | "cache_revalidation"
  | "evidence_freshness_sweep";

/** Minimal surface of ClaimVerificationService needed to re-judge a claim. */
export interface ClaimReAdjudicator {
  reAdjudicateClaimWithRecoveredEvidence(
    claim: VerifiedClaim,
    context: any,
    domainContext?: string
  ): Promise<{ status: ClaimStatus; verdictConfidence: number; reasoning: string; publicNote?: string }>;
}

export interface ReevaluationResult {
  claim: any;
  evidenceChanged: boolean;
  verdictChanged: boolean;
  usedModel: boolean;
  /** The evidence change required a model re-reading but no model was available (budget). */
  modelSkipped?: boolean;
  previousStatus: ClaimStatus;
  newStatus: ClaimStatus;
}

const urlKey = (s: Partial<RichSource> | undefined) =>
  String(s?.url || s?.directUrl || "").trim().toLowerCase().split("#")[0].replace(/\/+$/, "");

export function toDisplaySources(sources: RichSource[]): any[] {
  return sources.map((s) => ({
    title: s.title,
    url: s.url,
    directUrl: s.directUrl || s.url,
    domain: s.domain,
    publisher: s.publisher,
    snippet: s.snippet || "",
    tier: s.tier,
    urlVerification: s.urlVerification,
    ...(s.claimStance ? { claimStance: s.claimStance } : {}),
    ...(s.sourceKind ? { sourceKind: s.sourceKind } : {}),
    ...((s.retrievalMethod as string) === "community_submitted" ? { communitySubmitted: true } : {}),
  }));
}

export async function reevaluateClaimOnEvidenceChange(params: {
  claim: any;
  newSources: RichSource[];
  trigger: EvidenceChangeTrigger;
  reAdjudicator?: ClaimReAdjudicator;
  /** Stance step (default: classifySourceStances). Injected in tests. */
  classifyStances?: StanceClassifierFn;
  domainContext?: string;
  triggerRef?: string;
  reviewedBy?: string;
  now?: Date;
}): Promise<ReevaluationResult> {
  const { claim, trigger } = params;
  const claimTextForStance = String(params.claim?.claim || params.claim?.text || "");

  // Stance step for any source that has not been judged against THIS claim yet (new
  // evidence, or sources stored before the stance step existed). Off-topic and unreadable
  // sources are not evidence and are dropped from the evidence set.
  let newSources: RichSource[] = params.newSources;
  const isOpinionStatus = ["opinion_claim", "opinion", "religious_belief", "faith_based_claim", "satire_claim"].includes(String(claim?.status || ""));
  const stanceNewlyAssigned = !isOpinionStatus && newSources.some((s) => !s.claimStance);
  if (stanceNewlyAssigned) {
    const classify = params.classifyStances ?? classifySourceStances;
    newSources = (await classify(claimTextForStance, newSources)).filter(
      (s) => s.claimStance !== "OFF_TOPIC" && s.claimStance !== "UNREADABLE"
    );
  }
  const previousSources: RichSource[] = Array.isArray(claim?.richSources) ? claim.richSources : [];
  const previousStatus = String(claim?.status || "unproven") as ClaimStatus;

  const prevKeys = new Set(previousSources.map(urlKey).filter(Boolean));
  const nextKeys = new Set(newSources.map(urlKey).filter(Boolean));
  const added = [...nextKeys].filter((k) => !prevKeys.has(k));
  const removed = [...prevKeys].filter((k) => !nextKeys.has(k));
  // Newly judged stances are an evidence change too: the verdict must be re-checked against
  // what the sources actually say (e.g. reports created before the stance step existed).
  const evidenceChanged = added.length > 0 || removed.length > 0 || stanceNewlyAssigned;

  // A claim left un-reread by an earlier budget-capped run is re-read as soon as a model is available.
  const forcedRecheck = Boolean(claim?.pendingEvidenceRecheck) && Boolean(params.reAdjudicator);

  if (!evidenceChanged && !forcedRecheck) {
    return { claim, evidenceChanged: false, verdictChanged: false, usedModel: false, previousStatus, newStatus: previousStatus };
  }

  const claimText = String(claim?.claim || claim?.text || "");
  let proposedStatus = previousStatus;
  let proposedReasoning = String(claim?.reasoning || claim?.explanation || "");
  let modelConfidence = Number(claim?.verificationConfidence ?? claim?.confidence ?? 0.5);
  let publicNote: string | undefined = claim?.publicNote;
  let usedModel = false;

  // When does the evidence need to be READ again (model call) rather than just counted?
  //  - new sources were added, or
  //  - a source that was on a different side from the rest was removed: a mixed verdict
  //    (disputed / misleading / needs context / half-true) or a claim that had any
  //    contradicting source can become one-sided, and only re-reading the remaining
  //    evidence can say which way it now points.
  const MIXED_VERDICTS = new Set(["disputed", "misleading", "needs_context", "partially_true", "outdated"]);
  const removedSources = previousSources.filter((s) => removed.includes(urlKey(s)));
  const removedOpposingSide =
    removed.length > 0 &&
    newSources.length > 0 &&
    (MIXED_VERDICTS.has(previousStatus) ||
      removedSources.some((s: any) => s?.isContradictory || s?.stance === "CONTRADICTS") ||
      previousSources.some((s: any) => s?.isContradictory || s?.stance === "CONTRADICTS"));
  const needsModel = newSources.length > 0 && (added.length > 0 || removedOpposingSide || forcedRecheck);
  const modelSkipped = needsModel && !params.reAdjudicator;

  if (needsModel && params.reAdjudicator) {
    const reAdj = await params.reAdjudicator.reAdjudicateClaimWithRecoveredEvidence(
      { ...claim, text: claimText, status: previousStatus } as VerifiedClaim,
      {
        claimId: claim?.claimId,
        originalClaim: claimText,
        provisionalStatus: previousStatus,
        recoveredSources: newSources,
        previousReasoning: proposedReasoning,
        previousConfidence: modelConfidence,
        retrievalStage: trigger === "community_evidence" ? "community_evidence" : "citation_retry",
      },
      params.domainContext || claim?.claimDomain || "General"
    );
    proposedStatus = reAdj.status;
    proposedReasoning = reAdj.reasoning;
    modelConfidence = reAdj.verdictConfidence;
    publicNote = reAdj.publicNote ?? publicNote;
    usedModel = true;
  }

  const reconciled = reconcileVerdictWithEvidence({
    proposedStatus,
    reasoning: proposedReasoning,
    publicNote,
    sources: newSources,
  });

  const verdictChanged = reconciled.status !== previousStatus;
  const confidence = Math.min(modelConfidence, reconciled.confidenceCap);
  const at = (params.now || new Date()).toISOString();

  const updated: any = {
    ...claim,
    status: reconciled.status,
    richSources: newSources,
    sources: toDisplaySources(newSources),
    sourceStatus: newSources.length >= 2 ? "complete" : newSources.length === 1 ? "partial" : "missing",
    confidence,
    verificationConfidence: confidence,
    lastEvidenceChangeAt: at,
  };
  if (verdictChanged || usedModel) {
    updated.reasoning = reconciled.reasoning;
    updated.response = reconciled.reasoning;
    updated.explanation = reconciled.reasoning;
    if (reconciled.publicNote !== undefined) updated.publicNote = reconciled.publicNote;
  }
  if (verdictChanged) {
    updated.verdictHistory = [
      ...(Array.isArray(claim?.verdictHistory) ? claim.verdictHistory : []),
      {
        at,
        previousStatus,
        newStatus: reconciled.status,
        trigger,
        ...(params.triggerRef ? { ref: params.triggerRef } : {}),
        ...(params.reviewedBy ? { reviewedBy: params.reviewedBy } : {}),
        sourcesAdded: added.length,
        sourcesRemoved: removed.length,
      },
    ];
  }

  if (modelSkipped) {
    // Flag for the next run: the verdict was only rule-checked and still needs re-reading.
    updated.pendingEvidenceRecheck = true;
  } else if (usedModel) {
    delete updated.pendingEvidenceRecheck;
  }
  return { claim: updated, evidenceChanged: evidenceChanged || forcedRecheck, verdictChanged, usedModel, modelSkipped, previousStatus, newStatus: reconciled.status };
}
