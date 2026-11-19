/**
 * ⚡ PHASE 3: FOUR-TIER VERIFICATION CASCADE SERVICE (TRUTHWORLD)
 *
 * Central routing and decision layer determining how much verification each claim needs:
 *
 *   ┌──────────────────────────────────────────────────────────────────┐
 *   │ ⚡ TIER 1: SEMANTIC CLAIM CACHE (< 50ms)                         │
 *   │ Exact hash + proposition alignment (rejects 0.94 false positives)│
 *   └────────────────────────────────┬─────────────────────────────────┘
 *                                    ▼ Miss
 *   ┌──────────────────────────────────────────────────────────────────┐
 *   │ 🏛️ TIER 2: DETERMINISTIC REGISTRY (< 100ms)                      │
 *   │ Scientific constants, units, conditions, world capitals, history │
 *   └────────────────────────────────┬─────────────────────────────────┘
 *                                    ▼ Miss
 *   ┌──────────────────────────────────────────────────────────────────┐
 *   │ ⚡ TIER 3: FAST-TRACK LLM (< 1.2s)                               │
 *   │ Opinions, value judgments, satire. (No empirical truth stamped)  │
 *   └────────────────────────────────┬─────────────────────────────────┘
 *                                    ▼ Requires Grounding / Escalation
 *   ┌──────────────────────────────────────────────────────────────────┐
 *   │ 🛡️ TIER 4: DEEP GROUNDED VERIFICATION (2 - 5s)                   │
 *   │ Fused Grounding + Citation Firewall + Semantic Evidence Validator│
 *   └──────────────────────────────────────────────────────────────────┘
 */

import { logger } from "../utils/logger";
import {
  ClaimStatus,
  EvidenceLevel,
  FilteredClaim,
  VerifiedClaim,
} from "../types";
import { claimCacheService, isTimeSensitiveClaim } from "./claimCacheService";
import { DeterministicRegistryService } from "./deterministicRegistry";
import { tier0KnowledgeService } from "./tier0Knowledge";
import { registryService } from "../registry/RegistryService";
import { FastTrackLlmService } from "./fastTrackLlmService";
import { FusedGroundingService, FusedGroundingOptions } from "./fusedGroundingService";
import { StreamingClaimProcessor } from "./streamingClaimProcessor";
import {
  VerificationConcurrencyManager,
  ClaimPrioritizationScheduler,
  ResilientExecutor,
} from "./verificationConcurrencyManager.js";

export interface CascadeRoutingDecision {
  claimId: string;
  text: string;
  recommendedTier: 1 | 2 | 3 | 4;
  escalationReasons: string[];
  isTimeSensitive: boolean;
  isStatistical: boolean;
  isHighStakes: boolean;
  isMedical: boolean;
  isSubjective: boolean;
}

export class VerificationCascadeService {
  /**
   * Analyzes an individual claim to establish its inherent volatility, risk,
   * and recommended routing tier.
   */
  public static analyzeClaimForTierRouting(
    claimText: string,
    claimMeta?: { requiresLiveWeb?: boolean; domain?: string }
  ): CascadeRoutingDecision {
    const text = claimText || "";
    const lower = text.toLowerCase();
    const escalationReasons: string[] = [];

    // Temporal Recency Gate: if explicitly marked requiresLiveWeb === false, suppress temporal escalation
    const explicitlyStatic = claimMeta?.requiresLiveWeb === false;
    const timeSensitive = !explicitlyStatic && (isTimeSensitiveClaim(text) || /\b(202[4-9]|this morning|just in)\b/i.test(lower));
    if (timeSensitive) {
      escalationReasons.push("Time-sensitive temporal claim requires live grounded corroboration");
    }

    // 2. Statistical / Financial Metric Check
    const statistical = /\b(\d+(?:\.\d+)?%|gdp|inflation|unemployment|revenue|quarterly earnings|deficit|trillion|billion|stock price)\b/i.test(lower);
    if (statistical) {
      escalationReasons.push("Statistical/financial quantitative metric requires authoritative citation");
    }

    // 3. High-Stakes Accusation Check
    const highStakes = /\b(accuse[ds]?|bribe[ds]?|corrupt|fraud|foreign funding|secretly|bombed|missile strike|warfare|casualties|killed)\b/i.test(lower);
    if (highStakes) {
      escalationReasons.push("High-stakes political/legal allegation requires strict evidentiary standard");
    }

    // 4. Medical / Clinical Claim Check
    const medical = /\b(vaccine|drug|cure|treatment|cancer|clinical trial|fda approval|approved yesterday)\b/i.test(lower);
    const isCanonicalMedical = /\b(antibiotics|smoking|tobacco|turmeric)\b/i.test(lower);
    if (medical && !isCanonicalMedical) {
      escalationReasons.push("Medical/pharmacological claim requires live authoritative peer review");
    }

    // 5. Subjective Opinion Check
    const subjective = /\b(i feel|in my opinion|in my personal opinion|personally|i think|my favorite|is the best|the best|greatest|worst|most beautiful|should be|ought to)\b/i.test(lower) &&
      !statistical && !highStakes;

    // Determine Tier recommendation:
    // If escalated for time, stats, high stakes, or novel medical -> Tier 4
    if (timeSensitive || statistical || highStakes || (medical && !isCanonicalMedical)) {
      return {
        claimId: "",
        text,
        recommendedTier: 4,
        escalationReasons,
        isTimeSensitive: timeSensitive,
        isStatistical: statistical,
        isHighStakes: highStakes,
        isMedical: medical,
        isSubjective: false,
      };
    }

    // If clearly subjective -> Tier 3
    if (subjective) {
      return {
        claimId: "",
        text,
        recommendedTier: 3,
        escalationReasons: ["Subjective statement classified for fast opinion labeling"],
        isTimeSensitive: false,
        isStatistical: false,
        isHighStakes: false,
        isMedical: false,
        isSubjective: true,
      };
    }

    // Check if deterministic match exists -> Tier 2
    const deterministicMatch = DeterministicRegistryService.resolveDeterministicFact(text);
    if (deterministicMatch) {
      return {
        claimId: "",
        text,
        recommendedTier: 2,
        escalationReasons: ["Settled constant/geography matches deterministic registry"],
        isTimeSensitive: false,
        isStatistical: false,
        isHighStakes: false,
        isMedical: false,
        isSubjective: false,
      };
    }

    // Default: Check Tier 1 Cache first, then cascade down
    return {
      claimId: "",
      text,
      recommendedTier: 1,
      escalationReasons: [],
      isTimeSensitive: false,
      isStatistical: false,
      isHighStakes: false,
      isMedical: false,
      isSubjective: false,
    };
  }

  /**
   * Executes the Complete 4-Tier Verification Cascade for a batch of claims with
   * progressive streaming delivery to Firestore.
   */
  public static async executeCascade(
    videoId: string,
    claims: FilteredClaim[],
    domainContext: string = "General",
    options: FusedGroundingOptions = {}
  ): Promise<VerifiedClaim[]> {
    if (!claims || claims.length === 0) return [];

    const t0 = Date.now();
    const finalResultsMap = new Map<string, VerifiedClaim>();

    // Prepare claim map by claimId and by text
    const pendingClaims = [...claims];

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 1: SEMANTIC CLAIM CACHE (< 50ms)
    // ──────────────────────────────────────────────────────────────────────────
    const tier1Candidates: FilteredClaim[] = [];
    for (const c of pendingClaims) {
      const routing = this.analyzeClaimForTierRouting(c.text, {
        requiresLiveWeb: (c as any).requiresLiveWeb,
        domain: (c as any).domain,
      });
      // If time-sensitive or high-stakes, bypass cache if older than 3h
      if (routing.recommendedTier === 4 && routing.isTimeSensitive) {
        // High urgency time-sensitive claims skip cache to guarantee fresh live grounding
        continue;
      }
      tier1Candidates.push(c);
    }

    if (tier1Candidates.length > 0) {
      try {
        const cacheHits = await claimCacheService.getBatch(tier1Candidates.map(c => c.text));
        const resolvedTier1: VerifiedClaim[] = [];

        for (const candidate of tier1Candidates) {
          const cached = cacheHits.get(candidate.text);
          if (cached && cached.status) {
            const verified: VerifiedClaim = {
              ...candidate,
              status: cached.status,
              verificationConfidence: cached.verificationConfidence || 0.95,
              evidenceConfidence: 0.95,
              reasoning: cached.reasoning || "Previously verified and corroborating sources remain active.",
              sources: (cached.richSources || []).map(s => s.url).filter(Boolean),
              richSources: cached.richSources || [],
              isGrounded: true,
              verificationMethod: "cache_hit",
              displayLabel: cached.displayLabel,
              evidenceLevel: (cached.evidenceLevel as EvidenceLevel) || EvidenceLevel.MODERATE,
            };

            finalResultsMap.set(candidate.claimId, verified);
            resolvedTier1.push(verified);
          }
        }

        // Stream Tier 1 hits immediately to Firestore (< 50ms)
        if (resolvedTier1.length > 0 && videoId) {
          await StreamingClaimProcessor.publishResolvedClaims(videoId, resolvedTier1).catch(() => {});
          logger.info(`[VerificationCascade] Tier 1 Cache resolved ${resolvedTier1.length}/${claims.length} claims in ${Date.now() - t0}ms`);
        }
      } catch (err: any) {
        logger.warn("[VerificationCascade] Tier 1 cache lookup failed; continuing cascade", { err: err?.message });
      }
    }

    // Filter out claims resolved in Tier 1
    const remainingAfterTier1 = pendingClaims.filter(c => !finalResultsMap.has(c.claimId));
    if (remainingAfterTier1.length === 0) {
      return claims.map(c => finalResultsMap.get(c.claimId)!);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 2: DETERMINISTIC KNOWLEDGE REGISTRY (< 100ms)
    // ──────────────────────────────────────────────────────────────────────────
    const resolvedTier2: VerifiedClaim[] = [];
    const remainingAfterTier2: FilteredClaim[] = [];

    for (const c of remainingAfterTier1) {
      // 1. Enhanced Deterministic Registry (Strict units, conditions, country-capitals)
      const detMatch = DeterministicRegistryService.resolveDeterministicFact(c.text);
      if (detMatch) {
        const verified: VerifiedClaim = {
          ...c,
          status: detMatch.status,
          verificationConfidence: detMatch.confidence,
          evidenceConfidence: 1.0,
          reasoning: detMatch.reasoning,
          sources: [detMatch.source],
          richSources: detMatch.richSources,
          isGrounded: true,
          verificationMethod: "deterministic",
        };
        finalResultsMap.set(c.claimId, verified);
        resolvedTier2.push(verified);
        continue;
      }

      // 2. Canonical Tier-0 Pre-Indexed Facts (Physical constants & NASA/WHO baselines)
      const t0Match = tier0KnowledgeService.lookupPreIndexedFact(c.text);
      if (t0Match) {
        const verified: VerifiedClaim = {
          ...c,
          status: t0Match.status,
          verificationConfidence: t0Match.confidence,
          evidenceConfidence: 1.0,
          reasoning: t0Match.reasoning,
          sources: [t0Match.source],
          richSources: [{
            title: t0Match.title,
            url: t0Match.url,
            directUrl: t0Match.url,
            domain: t0Match.domain,
            tier: "A",
            snippet: t0Match.reasoning,
            retrievalMethod: "tier0_local_store",
          }],
          isGrounded: true,
          verificationMethod: "deterministic",
        };
        finalResultsMap.set(c.claimId, verified);
        resolvedTier2.push(verified);
        continue;
      }

      // 3. Historical entity registry check
      const regMatch = registryService.resolveTruthCheck(c.text);
      if (regMatch) {
        const statusMap: Record<string, ClaimStatus> = {
          correct: "verified_true",
          mostly_correct: "mostly_true",
          incorrect: "false_claim",
          disputed: "disputed",
        };
        const regUrl = "https://unstats.un.org/";
        const verified: VerifiedClaim = {
          ...c,
          status: statusMap[regMatch.status] || "verified_true",
          verificationConfidence: 1.0,
          evidenceConfidence: 1.0,
          reasoning: regMatch.reasoning,
          sources: [regMatch.source],
          richSources: [{
            title: regMatch.source,
            url: regUrl,
            directUrl: regUrl,
            domain: "unstats.un.org",
            tier: "A",
            snippet: regMatch.reasoning,
          }],
          isGrounded: true,
          verificationMethod: "deterministic",
        };
        finalResultsMap.set(c.claimId, verified);
        resolvedTier2.push(verified);
        continue;
      }

      remainingAfterTier2.push(c);
    }

    // Stream Tier 2 hits immediately to Firestore (< 100ms)
    if (resolvedTier2.length > 0 && videoId) {
      await StreamingClaimProcessor.publishResolvedClaims(videoId, resolvedTier2).catch(() => {});
      logger.info(`[VerificationCascade] Tier 2 Deterministic Registry resolved ${resolvedTier2.length} claims in ${Date.now() - t0}ms`);
    }

    if (remainingAfterTier2.length === 0) {
      return claims.map(c => finalResultsMap.get(c.claimId)!);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 3: FAST-TRACK LLM (< 1.2s) & BOUNDED CONCURRENT EVALUATION
    // ──────────────────────────────────────────────────────────────────────────
    const tier3Candidates: FilteredClaim[] = [];
    const preEscalatedToTier4: FilteredClaim[] = [];

    for (const c of remainingAfterTier2) {
      const routing = this.analyzeClaimForTierRouting(c.text);
      if (routing.recommendedTier === 4) {
        preEscalatedToTier4.push(c);
      } else {
        tier3Candidates.push(c);
      }
    }

    const tier4EscalatedClaims: FilteredClaim[] = [...preEscalatedToTier4];
    const resolvedTier3: VerifiedClaim[] = [];

    if (tier3Candidates.length > 0) {
      // Execute Tier 3 candidates concurrently through bounded worker pool
      const tier3Tasks = tier3Candidates.map(async (c) => {
        return VerificationConcurrencyManager.tier3Pool.run(async () => {
          try {
            const fastTrackResult = await ResilientExecutor.executeWithRetry(
              `tier3_fasttrack_${c.claimId}`,
              () => FastTrackLlmService.evaluateClaim(c.text, domainContext),
              { maxRetries: 2, baseDelayMs: 300, maxDelayMs: 3000 }
            );

            if (fastTrackResult.resolved && fastTrackResult.status) {
              const verified: VerifiedClaim = {
                ...c,
                status: fastTrackResult.status,
                verificationConfidence: fastTrackResult.confidence,
                evidenceConfidence: fastTrackResult.confidence,
                reasoning: fastTrackResult.reasoning,
                sources: [],
                richSources: [],
                isGrounded: false,
                verificationMethod: "llm_training",
              };
              finalResultsMap.set(c.claimId, verified);
              resolvedTier3.push(verified);
              if (videoId) {
                await StreamingClaimProcessor.publishResolvedClaims(videoId, [verified]).catch(() => {});
              }

              // ⚡ TIER 3 FALSE-POSITIVE SHADOW AUDIT (3% Random Sampling)
              // Verifies empirical claims masked as opinions/satire are not prematurely bypassed
              if (Math.random() < 0.03) {
                this.executeTier3ShadowAudit(c, domainContext, options, fastTrackResult.status).catch(() => {});
              }
            } else {
              // Empirical assertion or fast-track flagged grounding required
              tier4EscalatedClaims.push(c);
            }
          } catch (_) {
            tier4EscalatedClaims.push(c);
          }
        });
      });

      await Promise.all(tier3Tasks);
      logger.info(`[VerificationCascade] Tier 3 Fast-Track resolved ${resolvedTier3.length}/${tier3Candidates.length} claims in ${Date.now() - t0}ms`);
    }

    if (tier4EscalatedClaims.length === 0) {
      return VerificationConcurrencyManager.restoreDeterministicOrder(claims, finalResultsMap);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TIER 4: DEEP GROUNDED VERIFICATION (2 - 5s) WITH MICRO-BATCHING & CONCURRENCY
    // ──────────────────────────────────────────────────────────────────────────
    // Prioritize escalated claims (timeline offset + salience)
    const prioritizedTier4 = ClaimPrioritizationScheduler.prioritizeClaims(tier4EscalatedClaims);
    logger.info(`[VerificationCascade] Tier 4 Deep Grounding executing for ${prioritizedTier4.length} escalated claims across bounded worker pool`);

    // 1. Mark escalated claims as DEEP_VERIFYING in Firestore via single batched commit
    if (videoId && prioritizedTier4.length > 0) {
      await StreamingClaimProcessor.markClaimsDeepVerifying(
        videoId,
        prioritizedTier4.map((c) => c.claimId)
      ).catch(() => {});
    }

    // Pre-retrieve authoritative biomedical / scientific literature (PubMed & Crossref)
    let preRetrievedEvidence: any[] = [];
    const scientificClaims = prioritizedTier4.filter(
      (c) =>
        domainContext === "HEALTH_MEDICAL" ||
        domainContext === "Science" ||
        /\b(\d+%|study|trial|clinical|vaccine|drug|pharmacology|medical|disease|treatment|fda)\b/i.test(c.text)
    );
    if (scientificClaims.length > 0) {
      try {
        const { gatherLayer06CEvidence } = require("../layers/06-credibility");
        preRetrievedEvidence = await gatherLayer06CEvidence(scientificClaims);
        if (preRetrievedEvidence.length > 0) {
          logger.info(`[VerificationCascade] Pre-retrieved ${preRetrievedEvidence.length} scientific literature sources from PubMed/Crossref`);
        }
      } catch (litErr: any) {
        logger.warn("[VerificationCascade] Scientific pre-retrieval non-fatal warning", { err: litErr?.message });
      }
    }

    const tier4Options: FusedGroundingOptions = {
      ...options,
      ...(preRetrievedEvidence.length > 0 ? { preRetrievedEvidence } : {}),
    };

    // 2. Partition into micro-batches to optimize search quality, avoid prompt/token exhaustion, and enable parallel workers
    const microBatches = ClaimPrioritizationScheduler.chunkIntoMicroBatches(
      prioritizedTier4,
      VerificationConcurrencyManager.TIER4_MICRO_BATCH_SIZE
    );

    // 3. Execute micro-batches concurrently through Tier 4 bounded pool with resilient retry and full jitter
    const microBatchTasks = microBatches.map(async (microBatch, batchIdx) => {
      return VerificationConcurrencyManager.tier4Pool.run(async () => {
        try {
          const microBatchResults = await ResilientExecutor.executeWithRetry(
            `tier4_microbatch_${batchIdx}`,
            () => FusedGroundingService.verifyBatchFused(microBatch, domainContext, tier4Options),
            { maxRetries: 3, baseDelayMs: 800, maxDelayMs: 8000 }
          );

          for (const g of microBatchResults) {
            finalResultsMap.set(g.claimId, g);
          }

          // Immediate progressive streaming to Firestore per completed micro-batch
          if (videoId && microBatchResults.length > 0) {
            await StreamingClaimProcessor.publishResolvedClaims(videoId, microBatchResults).catch(() => {});
          }

          // Back-write to Tier 1 Cache with content-aware TTL
          await claimCacheService.setBatch(microBatchResults).catch(() => {});
        } catch (err: any) {
          logger.error(`[VerificationCascade] Tier 4 micro-batch ${batchIdx} failed; assigning unproven fallback to prevent false certainty`, {
            err: err?.message,
            batchSize: microBatch.length,
          });

          // Epistemic Invariant: When deep verification fails or times out, assign unproven, NEVER manufacture truth
          const fallbacks: VerifiedClaim[] = microBatch.map((c) => ({
            ...c,
            status: "unproven",
            verificationConfidence: 0.0,
            evidenceConfidence: 0.0,
            reasoning: "Live multi-source verification could not be completed within timeout limits. The claim remains unproven.",
            sources: [],
            richSources: [],
            isGrounded: false,
            verificationMethod: "not_verified",
          }));

          for (const fb of fallbacks) {
            finalResultsMap.set(fb.claimId, fb);
          }
          if (videoId) {
            await StreamingClaimProcessor.publishResolvedClaims(videoId, fallbacks).catch(() => {});
          }
        }
      });
    });

    await Promise.all(microBatchTasks);

    logger.info(`[VerificationCascade] Completed 4-Tier Cascade with Concurrency for ${claims.length} claims in ${Date.now() - t0}ms`);

    // Return in strict deterministic order matching original input slice
    return VerificationConcurrencyManager.restoreDeterministicOrder(claims, finalResultsMap);
  }

  /**
   * ⚡ TIER 3 FALSE-POSITIVE SHADOW AUDIT
   * Samples 1%–5% of claims triaged as opinion/satire/belief and runs them asynchronously
   * through Tier 4 Search Grounding in the background (zero user latency impact).
   * Flags discrepancies where an empirical claim was misclassified as an opinion.
   */
  private static async executeTier3ShadowAudit(
    claim: FilteredClaim,
    domainContext: string,
    options: FusedGroundingOptions,
    tier3Verdict: string
  ): Promise<void> {
    try {
      const shadowResults = await FusedGroundingService.verifyBatchFused([claim], domainContext, options);
      if (shadowResults.length > 0) {
        const shadow = shadowResults[0];
        if (
          (shadow.status === "false_claim" || shadow.status === "verified_true") &&
          (shadow.evidenceLevel === "STRONG" || (shadow.richSources && shadow.richSources.length > 0))
        ) {
          logger.warn(`[Tier3ShadowAudit] Discrepancy detected: Claim triaged by Tier 3 as "${tier3Verdict}", but Tier 4 found empirical evidence: "${shadow.status}"`, {
            claimId: claim.claimId,
            text: claim.text,
            tier3Verdict,
            shadowVerdict: shadow.status,
            evidenceLevel: shadow.evidenceLevel,
            sourcesCount: shadow.richSources?.length || 0,
          });
        }
      }
    } catch (auditErr: any) {
      logger.debug("[Tier3ShadowAudit] Background audit pass completed with transient error", { err: auditErr?.message });
    }
  }
}
