/**
 * 🧠 LAYER 06 — CREDIBILITY ENGINE (PATH 1)
 *
 * Fact-checking pipeline with explainability and cost-optimised caching.
 */

import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";
import {
  ExecutionPlan,
  CredibilityResult,
  ExplainabilityResult,
  ClaimStrength,
  FactCompleteData,
  ExtractedClaim,
  VerifiedClaim,
  FilteredClaim,
  CredibilityErrorCode,
  ExtractionError,
  SynthesisResult,
  ClaimStatus,
  ClaimNature,
  ClaimLedgerSummary,
} from "../types";
import { FactExtractionService }   from "../services/factExtraction";
import { ClaimVerificationService } from "../services/claimVerification";
import { ScoringEngine }           from "../services/scoringEngine";
import { DistributionLayer }       from "./04-distribution";
import { EdgeLayer }               from "./01-edge";
import { aggregationLayer }        from "./09-aggregation";
import { PerformanceLayer }        from "./10-performance";
import { logger }                  from "../utils/logger";
import { alerting }                from "../utils/alerting";
import { PIPELINE_CONFIG, DEEP_RESEARCH_CONFIG, isDeepResearchEnabled } from "../config";
// import { reputationService }       from "../services/reputationService";
import { contentIntentDetector }    from "../services/contentIntentDetector";
import { speakerTrustEngine }       from "../services/speakerTrustEngine";
import { SpeakerRegistryService }    from "../services/speakerRegistry";
import { SpeakerReputationService }  from "../services/speakerReputationService";
import { registryService } from "../registry/RegistryService";
import { sourceTrustService } from "../services/sourceTrustService";
import { tier0KnowledgeService } from "../services/tier0Knowledge";
import { getAnalysisRepository, AnalysisRepository } from "../services/analysisRepository";
import { costEngine } from "../services/cost-engine";
import { JobTokenTracker } from "../utils/ai-utils";
import { formatOpinionReasoning } from "../utils/opinion-formatting";
import { SourceAvatarService } from "../services/sourceAvatarService";

const db = () => admin.firestore();

// Distributed Circuit Breaker state (backed by Firestore with local 5s TTL read cache)
const recentFailureTimestamps: number[] = [];
const BREAKER_WINDOW_MS = 60 * 1000; // 1-minute rolling window
const BREAKER_THRESHOLD = 5; // 5 consecutive failures in 1 minute before trip
const BREAKER_COOLDOWN_MS = 30 * 1000; // 30s half-open recovery cooldown
let localBreakerTrippedUntil = 0;
let localBreakerLastSynced = 0;
const BREAKER_SYNC_TTL_MS = 5000;
const BREAKER_DOC_REF = () => admin.firestore().collection("system_health").doc("credibility_circuit_breaker");

async function recordDistributedFailure(reason: string = "vertexai_failure") {
  const now = Date.now();
  recentFailureTimestamps.push(now);
  while (recentFailureTimestamps.length > 0 && recentFailureTimestamps[0] < now - BREAKER_WINDOW_MS) {
    recentFailureTimestamps.shift();
  }
  if (recentFailureTimestamps.length >= BREAKER_THRESHOLD) {
    const trippedUntil = now + BREAKER_COOLDOWN_MS;
    localBreakerTrippedUntil = trippedUntil;
    localBreakerLastSynced = now;
    logger.warn(`[CIRCUIT BREAKER] Tripped until ${new Date(trippedUntil).toISOString()} due to ${recentFailureTimestamps.length} failures in last ${BREAKER_WINDOW_MS / 1000}s`);
    await BREAKER_DOC_REF().set({
      trippedUntil,
      lastTrippedAt: now,
      reason,
      failureCount: recentFailureTimestamps.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch((err) => {
      logger.warn("[CIRCUIT BREAKER] Failed to sync breaker trip to Firestore", { err: String(err) });
    });
  }
}

async function recordDistributedSuccess() {
  recentFailureTimestamps.length = 0;
  if (localBreakerTrippedUntil > 0) {
    localBreakerTrippedUntil = 0;
    localBreakerLastSynced = Date.now();
    await BREAKER_DOC_REF().set({
      trippedUntil: 0,
      lastResetAt: Date.now(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => {});
  }
}

function recordFailure() {
  recordDistributedFailure().catch(() => {});
}

function recordSuccess() {
  recordDistributedSuccess().catch(() => {});
}

async function isBreakerTrippedAsync(): Promise<boolean> {
  const now = Date.now();
  if (localBreakerTrippedUntil > now) {
    return true;
  }
  if (now - localBreakerLastSynced > BREAKER_SYNC_TTL_MS) {
    localBreakerLastSynced = now;
    try {
      const snap = await BREAKER_DOC_REF().get();
      if (snap.exists) {
        const data = snap.data();
        const distTrippedUntil = Number(data?.trippedUntil || 0);
        if (distTrippedUntil > now) {
          localBreakerTrippedUntil = distTrippedUntil;
          return true;
        } else {
          localBreakerTrippedUntil = 0;
        }
      }
    } catch {
      // Non-fatal: rely on local state
    }
  }
  return localBreakerTrippedUntil > now;
}

function isBreakerTripped(): boolean {
  const now = Date.now();
  return localBreakerTrippedUntil > now;
}

/** v11.0: Content-aware cache TTL in seconds per claim category */
const CLAIM_TTL: Record<string, number> = {
  breaking_news: 4 * 3600,        // 4 hours — breaking news evolves rapidly
  news:          86400,            // 1 day   — general news claims
  political:     86400 * 7,       // 7 days  — political claims shift with cycles
  financial:     86400,            // 1 day   — market/economic claims
  statistics:    86400 * 14,      // 14 days — stats get updated periodically
  scientific:    86400 * 90,      // 90 days — peer-reviewed science is stable
  historical:    86400 * 180,     // 180 days — historical claims rarely change
  education:     86400 * 60,      // 60 days — educational content is stable
  default:       86400 * 30,      // 30 days — general fallback
};

/** Alert threshold: alert if cache hit rate drops below this */
const MIN_HIT_RATE = 0.30;

export class CredibilityEngine {
  private readonly extractionService:   FactExtractionService;
  private readonly verificationService: ClaimVerificationService;
  private readonly scoringEngine:       ScoringEngine;
  private readonly distribution:        DistributionLayer;
  private readonly performanceLayer:    PerformanceLayer;
  private readonly speakerRegistry:     SpeakerRegistryService;   // v7
  private readonly speakerReputation:   SpeakerReputationService; // v7
  private readonly analysisRepository:  AnalysisRepository;

  constructor(geminiApiKey: string, analysisRepository?: AnalysisRepository) {
    this.extractionService   = new FactExtractionService(geminiApiKey);
    this.verificationService = new ClaimVerificationService(geminiApiKey, 0.6);
    this.scoringEngine       = new ScoringEngine();
    this.distribution        = new DistributionLayer();
    this.performanceLayer    = new PerformanceLayer();
    this.speakerRegistry     = new SpeakerRegistryService();
    this.speakerReputation   = new SpeakerReputationService();
    this.analysisRepository  = analysisRepository || getAnalysisRepository();
  }

  /**
   * Run the full credibility pipeline.
   */
  async runCredibilityPipeline(
    jobId:         string,
    userId:        string,
    executionPlan: ExecutionPlan,
    eventId:       string,
    traceId?:      string
  ): Promise<CredibilityResult> {
    // ── Idempotency gate ──────────────────────────────────────────────────────
    const status = await this.distribution.checkAndMarkEventId(eventId, jobId);
    if (status === "COMPLETED") {
      logger.info("[Credibility] Duplicate — loading existing", { jobId });
      return this.loadExistingResult(jobId);
    }
    if (status === "PROCESSING") {
      logger.info("[Credibility] Already processing — exiting gracefully", { jobId });
      return {} as any; // Early ACK
    }

    const t0 = Date.now();
    logger.info("[TruthEngine] Starting Path 1", { jobId, traceId });
    let transcript: any = null;

    // ── Transcription Gate (Hardened) ─────────────────────────────────────────
    const jobDoc = await db().collection("video_jobs").doc(jobId).get();
    const stages = jobDoc.exists ? jobDoc.data()?.stages : {};
    
    if (stages?.transcription?.status !== "completed") {
        logger.info("[Credibility] Gate: Transcription status not 'completed'. Checking for transcript document fallback.", { jobId });
        
        // Fallback: Check if the transcript document actually exists
        const transcriptDoc = await db().collection("transcripts").doc(jobId).get();
        if (!transcriptDoc.exists) {
            logger.warn("[Credibility] Gate: Transcription not completed and no transcript doc found — aborting", { jobId, traceId });
            throw new Error("Transcription must be completed before starting Credibility Engine");
        }
        
        logger.info("[Credibility] Gate: Transcript doc found! Proceeding despite metadata drift.", { jobId });
    }

    await EdgeLayer.updateStageSync(jobId, "credibility", {
      status: "running", progress: 5, startedAt: Date.now(),
    });

    try {
      // 1. Load transcript
      logger.info("[Credibility] Stage 1: Loading transcript", { jobId, traceId });
      transcript = await this.loadTranscript(jobId);
      if (!transcript) throw new Error(`Transcript not found for job ${jobId}`);

      await EdgeLayer.updateStage(jobId, "credibility", { progress: 10 });

      // 1.5 NEW: Domain & Stance Detection + Claim Extraction + Speaker Identities (v11.1 PARALLEL)
      logger.info("[Credibility] Stage 2: Parallelized Analysis & Extraction", { jobId, traceId });
      // All claims fact-checked with complete full ground truth verification
      const deepResearchActive = isDeepResearchEnabled(executionPlan.synthesisTier || 'standard') || executionPlan.factCheckTier === 'full_ground' || Boolean(executionPlan.factCheckEnabled) || (executionPlan.factCheckTier as string) !== 'none';

      // v20.0: Derive video duration accurately from transcript or utterances first
      const rawDuration = transcript.duration;
      const fallbackDurationSec = (transcript.utterances?.length > 0)
        ? Math.max(...transcript.utterances.map((u: any) => u.end || 0)) / 1000
        : 120;
      const videoDurationSec = rawDuration > 0 ? rawDuration : fallbackDurationSec;

      // TruthWorld Core Epistemic Policy: "No Claim Left Unchecked"
      // In TruthWorld, no empirical claim is left unverified or filtered out.
      // Every verifiable claim extracted from the video is verified.
      // configuredMax (default 200) acts as a high system ceiling against memory exhaustion.
      const configuredMax = typeof executionPlan.maxClaims === 'number' && executionPlan.maxClaims > 0
        ? executionPlan.maxClaims
        : 200;
      const effectiveMaxClaims = Math.max(configuredMax, 200);

      // Extraction concurrency (safe parallel Gemini calls for transcript chunks)
      const extractionConcurrency = 5;

      // v19.0 & v20.0: Scale extraction timeout with video duration.
      // Cloud Function has 540s — give extraction generous time so claims are NEVER lost.
      const extractionBudgetMs = deepResearchActive ? 280_000       // Deep research
        : videoDurationSec >= 1200 ? 300_000  // 20+ minutes: 5 min
        : videoDurationSec >= 600 ? 240_000   // 10-20 minutes: 4 min
        : videoDurationSec >= 180 ? 160_000   // 3-10 minutes: 2.6 min
        : 120_000;                            // < 3 minutes: 2 min

      let extractionPartial = false;
      const [domainInfo, rawClaimsResult, speakerIdentities] = await Promise.all([
        // v13.2: Graceful degradation — domain detection must NEVER crash the pipeline
        this.extractionService.detectDomainAndStance(transcript.utterances ?? []).catch((err: any) => {
          logger.error("[Credibility] Domain detection failed, using safe defaults", { jobId, error: err?.message });
          return { domain: "General", stance: "Mixed", cautionLevel: "medium" as const, isLaunchNews: false, primaryIntent: "educational", isSensitive: false };
        }),
        // v20.0: Extraction with duration-scaled budget and 45s chunks
        Promise.race([
          this.extractionService.extractClaims(jobId, transcript, 45_000, extractionConcurrency)
            .then(claims => ({ claims, partial: false }))
            .catch((err: any) => {
              logger.error("[Credibility] Primary extraction failed", { jobId, error: err?.message });
              return { claims: [] as any[], partial: true };
            }),
          new Promise<{ claims: any[], partial: boolean }>(resolve => {
            setTimeout(() => {
              logger.warn(`[Credibility] Extraction reached ${extractionBudgetMs / 1000}s budget — returning partial results`, { jobId, budgetMs: extractionBudgetMs });
              resolve({ claims: [], partial: true });
            }, extractionBudgetMs);
          })
        ]),
        this.resolveSpeakerIdentities(jobId, jobDoc.data()?.channelId || "unknown", transcript, {}).catch(() => ({}))
      ]);

      const rawClaims = rawClaimsResult.claims;
      extractionPartial = rawClaimsResult.partial;
      void extractionPartial; // v12.0: No longer passed to scoring engine

      logger.info("[Credibility] Context recognized", { jobId, traceId, ...domainInfo });

      // 1.6 NEW: Content Intent Detection (v4.3)
      const contentIntent = contentIntentDetector.detectIntent(
        transcript.utterances ?? [],
        domainInfo
      );
      logger.info("[Credibility] Content intent classified", {
        jobId,
        intent: contentIntent.primaryIntent,
        confidence: contentIntent.confidence,
        subjectiveRatio: contentIntent.subjectiveRatio,
        promoSignals: contentIntent.promotionalSignals.length,
        floor: contentIntent.ratingFloor,
        ceiling: contentIntent.ratingCeiling,
      });

      // 2. Extract claims
      logger.info("[Credibility] Stage 3: Claim extraction", { jobId, traceId });
      const t1 = Date.now(); // Kept for latency telemetry
      await EdgeLayer.updateStage(jobId, "credibility", { progress: 30 });

      // 3. Classify + rank by importance
      const filteringReasons: string[] = [];
      const ranked = this.classifyAndRank(rawClaims);

      // 4. Complete Fact-Checking: 100% of claims verified (Zero claims left unchecked)
      const maxClaims = effectiveMaxClaims;

      const topClaims     = ranked.slice(0, maxClaims);
      const filteredCount = ranked.length - topClaims.length;

      if (filteredCount > 0) {
        filteringReasons.push(`${filteredCount} claims exceeded system safety ceiling (Max: ${maxClaims})`);
      }

      logger.info("[Credibility] Claims processed for complete verification", {
        jobId, total: ranked.length, kept: topClaims.length, filtered: filteredCount, maxClaims, videoDurationSec
      });

      await EdgeLayer.updateStage(jobId, "credibility", { progress: 40 });

      // 4.5 NEW: Early Exit if no claims extracted (v5.0)
      if (topClaims.length === 0) {
        logger.warn("[Credibility] No claims extracted from transcript", { jobId });
        // Proceed to synthesis/scoring with empty claims
      }
      
      // Load source trust registry from Firestore (with dynamic fallback)
      await sourceTrustService.loadRegistry().catch(() => {});

      // 5. Cache lookup
      logger.info("[Credibility] Stage 4: Cache lookup", { jobId, traceId });
      const { cached, stale, uncached } = await this.cacheCheck(topClaims, jobId, domainInfo.domain);
      cached.forEach(c => c.verificationMethod = 'cache_hit'); // v11.5
      stale.forEach(c => c.verificationMethod = 'cache_hit');
      const hitRate = topClaims.length > 0 ? (cached.length + stale.length) / topClaims.length : 0;

      await this.trackAndAlertHitRate(jobId, cached.length + stale.length, topClaims.length);

      await EdgeLayer.updateStage(jobId, "credibility", { progress: 50 });

      // 5.5 NEW: Registry Fast-Path (v11.4)
      // Check each uncached claim against the registry BEFORE routing to AI
      const registryHits: VerifiedClaim[] = [];
      const stillUncached: ExtractedClaim[] = [];

      // v13.0: Map Registry status → ClaimStatus (the Registry uses 'correct'/'mostly_correct'
      // but the Scoring Engine expects 'verified_true'/'mostly_true')
      const mapRegistryStatus = (status: string): ClaimStatus => {
        switch (status) {
          case 'correct': return 'verified_true';
          case 'mostly_correct': return 'mostly_true';
          case 'incorrect': return 'false_claim';
          case 'disputed': return 'disputed';
          default: return 'verified_true';
        }
      };

      for (const claim of uncached) {
        const registryCheck = registryService.resolveTruthCheck(claim.text);
        if (registryCheck) {
          const regDomain = sourceTrustService.resolvePublisherDomain(registryCheck.source);
          const regUrl = regDomain
            ? `https://${regDomain}`
            : (registryCheck.source && registryCheck.source.trim().length > 0
                ? `https://www.google.com/search?q=${encodeURIComponent(registryCheck.source.trim())}`
                : "https://www.google.com/search?q=TruthWorld+Fact+Registry");
          registryHits.push({
            ...claim,
            claimId: `claim_reg_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`,
            status: mapRegistryStatus(registryCheck.status),
            verificationConfidence: 1.0,
            evidenceConfidence: 1.0,
            reasoning: registryCheck.reasoning,
            sources: [registryCheck.source],
            richSources: [{
              title: registryCheck.source,
              url: regUrl,
              directUrl: regUrl,
              domain: regDomain,
              tier: "A",
              snippet: registryCheck.reasoning
            }],
            isGrounded: true,
            verificationMethod: 'deterministic' // v11.5
          });
        } else {
          // v22.0: Tier-0 Pre-Indexed Knowledge Base Lookup (instant vector/lexical match)
          const t0Match = tier0KnowledgeService.lookupPreIndexedFact(claim.text);
          if (t0Match) {
            registryHits.push({
              ...claim,
              claimId: `claim_t0_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`,
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
                retrievalMethod: 'tier0_local_store',
              }],
              isGrounded: true,
              verificationMethod: 'deterministic',
            });
          } else {
            stillUncached.push(claim);
          }
        }
      }

      // v14.0: Only force ALL claims as sensitive when Deep Research is active.
      // For standard tier, let per-claim pattern matching in isSensitiveClaim() handle routing.
      // Previously: deepResearchActive || domainInfo.isSensitive (caused ALL geopolitical claims → Pro)
      const isDiscoverySensitive = deepResearchActive;

      const { toVerify: factual, opinions: opinionClaims, filteringReasons: routerReasons } = 
        this.verificationService.classifyClaims(stillUncached, domainInfo.isLaunchNews, isDiscoverySensitive);
      filteringReasons.push(...routerReasons);
      
      const nonFactualCount = uncached.length - factual.length;
      if (nonFactualCount > 0) {
        filteringReasons.push(`${nonFactualCount} claims routed as non-factual (opinion, satire, or unclear)`);
      }
      
      // Convert opinion claims to VerifiedClaim format (labeled but not verified)
      const labeledOpinions: VerifiedClaim[] = opinionClaims.map(claim => ({
        ...claim,
        status: (claim.nature === ClaimNature.BELIEF ? 'religious_belief' : 
                 claim.nature === ClaimNature.ESTIMATION ? 'opinion_claim' : 'opinion_claim') as any,
        nature: claim.nature,
        verificationConfidence: 1.0,
        reasoning: formatOpinionReasoning(claim.text),
        sources: [],
        richSources: [],
        isGrounded: false,
        importance: claim.importance || 0.3,
      }));

      let verified: VerifiedClaim[] = [];
      let batchStats = { completed: 0, timedOut: 0 };
      const verificationPromise = (async () => {
        if (factual.length > 0) {
          // Dynamic Batching based on Grounding Mode
          let effectiveGroundingMode = PIPELINE_CONFIG.GROUNDING_MODE;
          const isSensitiveTopic = executionPlan.sensitiveTopics?.some(t => ["health", "politics", "finance"].includes(t));

          if (domainInfo.isLaunchNews || executionPlan.priorityMode === "accuracy" || isSensitiveTopic) {
            effectiveGroundingMode = "always";
          }

           // v20.0: Cost-Optimized Dynamic Batching — groups more claims per Gemini call to halve grounding fees
           const batchSize = (() => {
             if (executionPlan.priorityMode === 'accuracy') return 3;
             if (deepResearchActive) return 4;  // Pro + grounding: 4 claims per batch
             if (effectiveGroundingMode === 'always' || domainInfo.domain === 'News' || domainInfo.domain === 'Technology') return 6;
             if (effectiveGroundingMode === 'auto') return PIPELINE_CONFIG.BATCH_SIZE_GROUNDING || 6;
             return 6;  // standard Flash
           })();

          const jobData = jobDoc.data() || {};
          const rawProvidedSources: string[] = Array.isArray(jobData.providedSources)
            ? jobData.providedSources
            : (Array.isArray(jobData.features?.providedSources) ? jobData.features.providedSources : []);
          let disputeSources: string[] = [];
          
          const targetVideoId = (executionPlan as any).videoId || jobData.videoId || (jobData.linkedVideoIds?.[0]) || jobId;
          
          try {
            const videoSnap = await db().collection("videos").doc(targetVideoId).get();
            if (videoSnap.exists) {
              const vData = videoSnap.data() || {};
              if (Array.isArray(vData.providedSources)) {
                rawProvidedSources.push(...vData.providedSources);
              }
              if (vData.factCheckDispute && Array.isArray(vData.factCheckDispute.additionalSources)) {
                disputeSources = vData.factCheckDispute.additionalSources;
              }
            }
          } catch (e) {
            logger.warn("[Credibility] Could not fetch extra video providedSources", { jobId, targetVideoId, error: (e as any)?.message });
          }

          let communitySources: string[] = [];
          try {
            const claimSourcesSnap = await db().collection("videos").doc(targetVideoId).collection("claim_sources").get();
            if (!claimSourcesSnap.empty) {
              claimSourcesSnap.docs.forEach(doc => {
                const data = doc.data();
                if (data?.url && typeof data.url === 'string') {
                  // v12.1 SECURITY FIX: Validate and sanitize community-submitted URLs
                  const rawUrl = data.url.trim();

                  // 1. Reject excessively long URLs (potential payload)
                  if (rawUrl.length > 2048) return;

                  // 2. Reject URLs with control characters or newlines (prompt injection vector)
                  if (/[\x00-\x1f\x7f]/.test(rawUrl)) return;

                  // 3. Validate URL format and enforce HTTPS only
                  try {
                    const parsed = new URL(rawUrl);
                    if (parsed.protocol !== 'https:') return;
                    // 4. Only keep the clean URL (strip any appended target labels that could inject instructions)
                    communitySources.push(parsed.href);
                  } catch {
                    // Invalid URL — silently skip
                    return;
                  }
                }
              });
            }
          } catch (e) {
            logger.warn("[Credibility] Could not fetch community claim_sources", { jobId, targetVideoId, error: (e as any)?.message });
          }

          // v12.1 + v21.0 SECURITY FIX: Separate creator-provided sources from untrusted community sources.
          // Strictly validate and sanitize creator sources against prompt injection or control characters.
          const rawCreatorSources = Array.from(new Set([...rawProvidedSources, ...disputeSources])).filter(s => typeof s === 'string' && s.trim().length > 0);
          const creatorProvidedSources: string[] = [];
          for (const s of rawCreatorSources) {
            const rawUrl = s.trim();
            if (rawUrl.length > 512 || /[\x00-\x1f\x7f]/.test(rawUrl)) continue;
            try {
              const parsed = new URL(rawUrl);
              if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
                creatorProvidedSources.push(parsed.href);
              }
            } catch {
              continue;
            }
          }
          const sanitizedCommunitySources = Array.from(new Set(communitySources)).filter(s => !creatorProvidedSources.includes(s));

          const deepResearchOptions = {
            jobId: jobId,
            groundingMode: deepResearchActive ? DEEP_RESEARCH_CONFIG.GROUNDING_MODE : (effectiveGroundingMode as any),
            forcePro: deepResearchActive && DEEP_RESEARCH_CONFIG.FORCE_PRO_MODEL,
            minSourcesRequired: DEEP_RESEARCH_CONFIG.MIN_SOURCES_PER_CLAIM,
            sourceDiversityRequired: DEEP_RESEARCH_CONFIG.SOURCE_DIVERSITY_REQUIRED,
            isDiscoverySensitive: isDiscoverySensitive || isSensitiveTopic,
            providedSources: creatorProvidedSources,
            communitySources: sanitizedCommunitySources, // v12.1: Separated & sandboxed
          };

          // v10.5 Audit #8: Pre-verification cost logging
          const costEstimate = this.scoringEngine.estimateDeepResearchCost(factual.length, 3, batchSize);
          logger.info(`[Credibility] Deep Research Cost Estimate: $${costEstimate.estimatedCostUsd} for ${factual.length} claims`, { jobId });
          if (costEstimate.warning) logger.warn(`[Credibility] ${costEstimate.warning}`);

          // Parallelize Grounded Claim Verification with a concurrency pool of 3 (p-limit(3))
          // Reduces 440s verification to ≈ 150s, comfortably below the 540s timeout.
          const maxConcurrent = 3;

          // Check distributed circuit breaker before invoking Vertex AI
          const isBreakerActive = await isBreakerTrippedAsync();
          if (isBreakerActive) {
            logger.warn(`[Credibility] Distributed Circuit Breaker is active. Routing ${factual.length} claims to safe fast-knowledge recovery to prevent downstream cascade.`, { jobId });
            verified = await this.verificationService.verifyBatchWithFastKnowledge(factual, jobId);
            batchStats = { completed: verified.length, timedOut: 0 };
            return verified;
          }

          // v14.0: Verification block is now crash-proof. If the entire verification pipeline
          // throws (e.g. all retries exhausted), we fall back to Fast Knowledge Recovery
          // instead of silently dropping all claims.
          try {
            const verificationResult = await this.verificationService.verifyClaims(
              factual, 
              batchSize, 
              maxConcurrent, 
              domainInfo.domain, 
              deepResearchOptions
            );
            verified = verificationResult.claims;
            batchStats = verificationResult.batchStats;
            await this.cacheWithTTL(verified);
            recordSuccess();
          } catch (verErr) {
            recordFailure();
            logger.error(`[Credibility] Verification pipeline threw — initiating Full Recovery Pass`, { jobId, error: (verErr as any)?.message });
            try {
              verified = await this.verificationService.verifyBatchWithFastKnowledge(factual, jobId);
              batchStats = { completed: verified.length, timedOut: 0 };
              logger.info(`[Credibility] Full Recovery Pass succeeded: ${verified.length} claims recovered`, { jobId });
              recordSuccess();
            } catch (recoveryErr) {
              logger.error(`[Credibility] Full Recovery Pass also failed — graceful degradation`, { jobId, error: (recoveryErr as any)?.message });
              verified = [];
            }
          }
        }
        return verified;
      })();
      void batchStats; // v12.0: Scoring engine removed; batchStats preserved for structure

      // 9. Merge cached + stale + newly verified + labeled opinions (v5.0)
      const newlyVerified = await verificationPromise;
      const tVerificationEnd = Date.now();
      let allVerified = [...cached, ...stale, ...registryHits, ...newlyVerified, ...labeledOpinions];

      // Trigger SWR background refresh for stale claims if breaker is healthy
      if (stale.length > 0) {
        if (isBreakerTripped()) {
          logger.warn("[SWR] Circuit breaker is tripped. Serving stale cache and skipping background refresh.", { jobId, count: stale.length });
        } else {
          await this.enqueueBackgroundRefresh(jobId, stale, domainInfo.domain);
        }
      }

      // v14.0: Final Recovery Sweep — catch ANY remaining verification_timeout claims
      const stillTimedOut = allVerified.filter(c =>
        c.status === 'verification_timeout' || (c as any).failureReason === 'timeout'
      );
      if (stillTimedOut.length > 0) {
        logger.warn(`[Credibility] Final Recovery Sweep: ${stillTimedOut.length} claims still timed out`, { jobId });
        try {
          const recovered = await this.verificationService.verifyBatchWithFastKnowledge(stillTimedOut as any, jobId);
          for (const r of recovered) {
            const idx = allVerified.findIndex(c => c.claimId === r.claimId);
            if (idx !== -1) allVerified[idx] = r;
          }
          logger.info(`[Credibility] Final Recovery Sweep succeeded: ${recovered.length} claims recovered`, { jobId });
        } catch (sweepErr) {
          logger.error(`[Credibility] Final Recovery Sweep failed`, { jobId, error: (sweepErr as any)?.message });
          // Continue with what we have — claims remain as verification_timeout
        }
      }

      // v11.0: Evaluation Health Tracking — detect 0-evaluated-claims failure mode
      // v11.4: Include registry hits in routed count
      const factualRoutedCount = factual.length + registryHits.length;
      const evaluatedClaimsCount = allVerified.filter(c => 
        c.status !== 'opinion_claim' && c.status !== 'religious_belief' && !c.timedOutAt && (c as any).failureReason !== 'timeout'
      ).length;
      const attemptedClaimsCount = allVerified.filter(c => 
        c.status !== 'opinion_claim' && c.status !== 'religious_belief'
      ).length;
      const claimReachRatio = topClaims.length > 0 ? factualRoutedCount / topClaims.length : 0;
      const evaluationRatio = factualRoutedCount > 0 ? evaluatedClaimsCount / factualRoutedCount : 0;
      const healthStatus = claimReachRatio >= 0.6 && evaluationRatio >= 0.5 ? 'healthy' as const
        : claimReachRatio >= 0.3 || evaluationRatio >= 0.3 ? 'degraded' as const
        : 'critical' as const;

      if (healthStatus === 'critical' && topClaims.length >= 3) {
        logger.error(`[Credibility] CRITICAL: Low claim reach — ${factualRoutedCount}/${topClaims.length} reached verification, ${evaluatedClaimsCount} evaluated`, {
          jobId, claimReachRatio, evaluationRatio, totalExtracted: rawClaims.length,
          afterFilter: topClaims.length, factual: factualRoutedCount, opinions: opinionClaims.length,
          filteringReasons,
        });
        await alerting.notify('low-claim-reach', { jobId, claimReachRatio, evaluationRatio, healthStatus });
      } else if (healthStatus === 'degraded') {
        logger.warn(`[Credibility] Degraded evaluation health: reach=${claimReachRatio.toFixed(2)}, eval=${evaluationRatio.toFixed(2)}`, { jobId });
      }

      const evaluationHealth = {
        extractedClaims: rawClaims.length,
        factualRouted: factualRoutedCount,
        attemptedClaims: attemptedClaimsCount,
        evaluatedClaims: evaluatedClaimsCount,
        claimReachRatio,
        evaluationRatio,
        healthStatus,
      };

      await EdgeLayer.updateStage(jobId, "credibility", { progress: 65 });

      // 9.4 v7: Speaker Identity Resolution moved up to parallel block (v11.1)

      // 9.5 NEW: Determine Pipeline Mode & Synthesis Tier (v5.3 Adaptive Routing + v7 Creator Input)
      const expectedCount = executionPlan.expectedSpeakerCount;
      const speakerCount = transcript.speakerCount || (transcript.speakers?.length) || 1;
      
      let pipelineMode: "solo" | "multi" | "debate" = "solo";
      
      // 1. Prioritize '4+' or 'debate' format
      if (expectedCount === "4+" || executionPlan.contentFormat === "debate" || speakerCount >= 4) {
        pipelineMode = "debate";
      } 
      // 2. Prioritize '2-3', 'interview', 'podcast' format
      else if (["2-3"].includes(expectedCount || "") || ["interview", "podcast"].includes(executionPlan.contentFormat || "") || speakerCount >= 2) {
        pipelineMode = "multi";
      }

      const durationSeconds = transcript.duration ?? 0;
      let synthesisTier: "standard" | "deep" | "podcast" = "standard";

      if (executionPlan.factCheckTier === "full_ground" || executionPlan.synthesisTier === "deep" || durationSeconds > 1800 || pipelineMode === "debate" || executionPlan.contentFormat === "debate") {
        synthesisTier = "deep"; // Full Ground fact-check, > 30m, or Debate
      } else if (pipelineMode === "multi" || executionPlan.contentFormat === "podcast") {
        synthesisTier = "podcast"; // Interviews/Podcasts
      }

      logger.info("[Credibility] Creator-Informed Adaptive Orchestration", { 
        jobId, speakerCount, expectedCount, pipelineMode, synthesisTier 
      });

      // 9.6 NEW: Non-blocking synthesis architecture
      // After verification completes, save intermediate draft and delegate synthesis to background Cloud Function
      await EdgeLayer.updateStage(jobId, "credibility", { progress: 70 });
      logger.info("[Credibility] Stage 6: Persisting verified claims draft and triggering async synthesis", { jobId, traceId });

      // Build explainability
      const explainableResults = this.buildExplainability(allVerified);

      // Save draft to credibility_drafts/{jobId}
      await db().collection("credibility_drafts").doc(jobId).set({
        verifiedClaims: allVerified,
        synthesisPending: true,
        synthesisTier,
        domainInfo,
        contentIntent,
        evaluationHealth,
        factCheckStats: {
          totalClaims: rawClaims.length,
          extractedClaims: rawClaims.length,
          filtered: filteredCount,
          checkedClaimsRatio: rawClaims.length > 0 ? allVerified.length / rawClaims.length : 0,
        },
        speakerBreakdowns: [],
        speakerIdentities,
        executionPlanRef: executionPlan,
        userId,
        pipelineStartMs: t0,
        savedAt: Date.now(),
      });

      // Publish credibility-synthesis event for async background completion
      await this.distribution.publish("credibility-synthesis", {
        eventId: uuidv4(),
        eventType: "credibility-synthesis",
        jobId,
        userId,
        timestamp: Date.now(),
        data: {
          jobId,
          userId,
          eventId,
        },
        retryCount: 0,
        source: "credibility-engine",
      });
      logger.info("[Credibility] Async synthesis event published", { jobId });

      // Safe fallback synthesis so claims and verifications show immediately
      const hasVerifiedClaims = allVerified.length > 0;
      const initialSources: any[] = [];
      const seenInitSourceKeys = new Set<string>();
      for (const c of allVerified) {
        const sList = (c as any).sources || (c as any).richSources || (c as any).effectiveSources || [];
        for (const s of sList) {
          const k = (s.url || s.domain || s.title || "").toLowerCase();
          if (k && !seenInitSourceKeys.has(k)) {
            seenInitSourceKeys.add(k);
            initialSources.push({
              title: s.title || s.domain || "Authoritative Source",
              url: s.url || "",
              domain: s.domain || "",
              trustLevel: s.tier === 'A' || s.tier === 'B' ? 'High' : 'Medium',
              type: s.type || 'Supporting',
              snippet: s.snippet || "",
            });
          }
        }
      }
      const synthesis: SynthesisResult = {
        summary: "",
        conclusion: {
          label: hasVerifiedClaims ? "Checking Facts" : "No Claims Detected",
          text: hasVerifiedClaims
            ? "We're checking the facts in this video right now! Individual claim verdicts are already ready for you below."
            : "We checked this video and didn't find any specific facts that need checking — it's mostly personal opinions, music, or casual conversation!",
          confidence: hasVerifiedClaims ? 0.8 : 1.0,
          sources: initialSources,
        },
        viewerNote: hasVerifiedClaims
          ? "Claim verdicts are verified and ready. Overview synthesis is finalizing in the background."
          : "",
        chapters: [],
        keyThemes: [],
        manipulationScore: undefined as any,
        hallucinationIsolation: { verifiedFacts: [], modelInterpretations: [], uncertainInferences: [] },
        traceabilityMap: {},
        knowledgeDensity: hasVerifiedClaims ? 0.5 : 0.0,
        manipulationSignals: [],
        speakerRoles: {},
      };

      // 11.6 v5.0: Compute Speaker Trust Metrics
      const speakerBreakdowns = speakerTrustEngine.computeSpeakerMetrics(allVerified, synthesis.speakerRoles);
      logger.info("[Credibility] Speaker metrics computed", { jobId, speakerCount: speakerBreakdowns.length });

      const tConsistencyStart = Date.now();
      const tConsistencyEnd = Date.now();
      const tFinal = Date.now();

      // v12.0: Scoring engine removed — no Trust Index calculation
      // The fact-checking pipeline (extraction, verification, synthesis) remains intact.
      // Videos no longer receive numerical scores, factors, or deductions.
      const factCheckStats = {
        totalClaims: rawClaims.length,
        extractedClaims: rawClaims.length,
        evaluatedClaims: allVerified.filter(c => 
          c.status !== 'opinion_claim' && c.status !== 'religious_belief' && c.status !== 'satire_claim'
        ).length,
        correct: allVerified.filter(c => c.status === 'verified_true').length,
        mostly_correct: allVerified.filter(c => c.status === 'mostly_true').length,
        incorrect: allVerified.filter(c => c.status === 'false_claim').length,
        unsupported: allVerified.filter(c => c.status === 'unproven').length,
        unverifiable: 0,
        filtered: filteredCount,
        religious_belief: allVerified.filter(c => c.status === 'religious_belief').length,
        opinion_claim: allVerified.filter(c => c.status === 'opinion_claim').length,
        satire_claim: allVerified.filter(c => c.status === 'satire_claim').length,
        verification_timeout: allVerified.filter(c => c.status === 'verification_timeout').length,
        cacheHitRate: hitRate,
        checkedClaimsRatio: rawClaims.length > 0 ? allVerified.length / rawClaims.length : 0,
        verificationCoverageRatio: 1.0,
      };

      // v22.0: Verifiable Claim Ledger (Replaces ambiguous scalar scoring with transparent ledger)
      const confirmedCount = allVerified.filter(c => c.status === 'verified_true' || c.status === 'mostly_true' || c.status === 'correct' || c.status === 'mostly_correct').length;
      const disputedCount = allVerified.filter(c => c.status === 'disputed' || c.status === 'inconclusive' || c.status === 'limited_support' || c.status === 'contested_interpretation').length;
      const falseCount = allVerified.filter(c => c.status === 'false_claim' || c.status === 'incorrect' || c.status === 'verified_false' || c.status === 'historical_consensus_denial' || c.status === 'misleading').length;
      const unprovenCount = allVerified.filter(c => c.status === 'unproven' || c.status === 'unsupported' || c.status === 'verification_timeout').length;
      const contextualCount = allVerified.filter(c => c.status === 'opinion_claim' || c.status === 'religious_belief' || c.status === 'satire_claim' || c.status === 'faith_based_claim' || c.status === 'not_historically_verifiable').length;
      const totalClaimsChecked = allVerified.length;

      let highestSeverityVerdict: ClaimLedgerSummary['highestSeverityVerdict'] = 'none';
      if (falseCount > 0) highestSeverityVerdict = 'false_claim';
      else if (disputedCount > 0) highestSeverityVerdict = 'disputed';
      else if (unprovenCount > 0) highestSeverityVerdict = 'unproven';
      else if (confirmedCount > 0) highestSeverityVerdict = 'verified_true';

      const verdictHeadline = `${confirmedCount} Confirmed • ${disputedCount} Disputed • ${falseCount} False`;
      const priorityNotice = falseCount > 0
        ? `Notice: ${falseCount} claim(s) contradicted by documented evidence.`
        : disputedCount > 0
          ? `Notice: ${disputedCount} claim(s) have conflicting or inconclusive evidence.`
          : undefined;

      const claimLedger: ClaimLedgerSummary = {
        totalClaimsChecked,
        confirmedCount,
        disputedCount,
        unprovenCount,
        falseCount,
        contextualCount,
        highestSeverityVerdict,
        verdictHeadline,
        priorityNotice,
        verifiableRatio: totalClaimsChecked > 0 ? Number((confirmedCount / totalClaimsChecked).toFixed(3)) : 0,
      };

      const result: CredibilityResult = {
        analysisState:    'VERIFIED' as any, // v12.0: Analysis completes but no scoring
        scoreAvailable:   false, // v12.0: No score generated
        analysisFailureReason: undefined,
        viewerNote:       synthesis.viewerNote,
        uiReport:         undefined, // v12.0: No scoring-based UI report

        trustScore:       null, // v12.0: Scoring removed
        trustLabel:       'Not Scored' as any,
        confidence:       0,
        confidenceTier:   'low' as any,
        
        factors:          null, // v12.0: Scoring factors removed
        chapters:         synthesis.chapters || [],
        speakers:         speakerBreakdowns,
        speakerIdentities,
        claims:           explainableResults,
        claimLedger,
        
        deductions:       [], // v12.0: Deductions removed
        
        // v12.0: Category & epistemic scoring removed
        videoCategory:          executionPlan.videoCategory,
        categoryWeightProfile:  undefined,
        honestyBreakdown:       undefined,
        contextualFlags:        undefined,
        harmCapApplied:         false,
        harmCapReason:          undefined,
        rawScoreBeforeCap:      undefined,
        penaltyApplied:         undefined,
        
        factCheckStats,
        filteringReasons: [],
        contentIntent: {
          primaryIntent: contentIntent.primaryIntent,
          intentScores: contentIntent.intentScores,
          confidence: contentIntent.confidence,
          subjectiveRatio: contentIntent.subjectiveRatio,
          promotionalSignals: contentIntent.promotionalSignals,
          ratingFloor: contentIntent.ratingFloor,
          ratingCeiling: contentIntent.ratingCeiling,
        },
        
        scoringMethod:  'balanced',
        diagnostics:      [],
        confidenceNotes:  [],
        vertical:         undefined,
        verticalScores:   undefined,
        reviewTriggered:  false,
        reviewReason:     undefined,
        synthesisTier,
        factCheckTier: executionPlan.factCheckTier || 'standard',
        isLongform:       durationSeconds > 600,
        isFinal:        true, 
        
        summary:        synthesis.summary,
        conclusion:     synthesis.conclusion,
        keyThemes:      synthesis.keyThemes,
        domain:         domainInfo.domain,
        isLaunchNews:   !!domainInfo.isLaunchNews,
        extractionError: (domainInfo as any).extractionError || "",
        manipulationScore: synthesis.manipulationScore,
        isAppealed:     false,
        appealStatus:   'none',
        sourceLedger:   undefined,
        verifiedAsOf:   new Date().toISOString().split('T')[0],
        evaluationHealth,
        repairSuggestions: undefined,
        consistencyIssues: undefined,
        verifiedAt:     Date.now(),
        processingTime: Date.now() - t0,

        telemetry: {
          transcriptLoaded: true,
          utteranceCount: (transcript.utterances ?? []).length,
          claimsExtracted: rawClaims.length,
          verificationAttempted: evaluationHealth.attemptedClaims,
          verificationSucceeded: evaluationHealth.evaluatedClaims,
          verificationTimedOut: factCheckStats.verification_timeout,
          verificationCompleted: factCheckStats.verification_timeout === 0 && evaluationHealth.attemptedClaims > 0,
          claimsVerified: (allVerified.filter(c => ['verified_true', 'mostly_true', 'false_claim', 'misleading', 'disputed'].includes(c.status)).length > 0),
          verificationPipelineCompleted: true,
          summaryGenerated: synthesis.conclusion.label !== "Error",
          consistencyCheckCompleted: true,
          checkedClaimsRatio: factCheckStats.checkedClaimsRatio,
          verificationCoverage: factCheckStats.verificationCoverageRatio || 0,
        },

        versions: {
          model: "Gemini 2.5 Multi-Model",
          scoring: "v12.0-no-scoring",
          registry: "v3-blended"
        },

        llmProvider: "Gemini 2.5 (Flash+Pro)",
        sttProvider: "AssemblyAI Universal-3-Pro",
        language: transcript.language,

        latencyMs: {
          extraction:   t1 - t0,
          verification: tVerificationEnd - t1,
          consistency:  tConsistencyEnd - tConsistencyStart,
          synthesis:    tFinal - tConsistencyEnd,
          total:        tFinal - t0,
        },
        processingMetadata: {
          verificationPipeline: {
            verifiedBy: deepResearchActive ? "Gemini 2.5 Pro" : "Gemini 2.5 Flash",
            grounded: deepResearchActive || executionPlan.priorityMode === "accuracy",
            groundingProvider: "Google Search",
            embeddingModel: "text-embedding-005",
            cacheVersion: {
              embedding: 2,
              verification: 5,
              citation: 1
            },
            verifiedAt: new Date().toISOString(),
            cacheGeneratedAt: new Date().toISOString()
          }
        }
      };

      // v12.0: No scoring — conclusion label stays as synthesis-generated

      // 14. Store result
      await this.storeResult(jobId, userId, result);

      // 15. Cost Attribution — Track Gemini AI, Grounding, and Compute costs
      //     (Previously untracked: the largest variable cost components)
      const elapsedSec = (Date.now() - t0) / 1000;
      const claimCount = rawClaims.length;
      const verifiedCount = result.factCheckStats?.evaluatedClaims ?? 0;
      const modelTier: "flash" | "pro" = deepResearchActive ? "pro" : "flash";

      // Refined Cost Tracking: Read actual Vertex AI token usage captured during execution
      const actualTokens = JobTokenTracker.getAndClear(jobId);

      if (actualTokens && (actualTokens.extractionInputTokens > 0 || actualTokens.verificationInputTokens > 0)) {
        logger.info(`[Credibility] Recording actual Vertex AI token costs for ${jobId}`, { actualTokens });
        if (actualTokens.extractionInputTokens > 0 || actualTokens.extractionOutputTokens > 0) {
          costEngine.recordGeminiCost(jobId, userId, "extraction", "flash", actualTokens.extractionInputTokens, actualTokens.extractionOutputTokens).catch(() => {});
        }
        if (actualTokens.verificationInputTokens > 0 || actualTokens.verificationOutputTokens > 0) {
          costEngine.recordGeminiCost(jobId, userId, "verification", modelTier, actualTokens.verificationInputTokens, actualTokens.verificationOutputTokens).catch(() => {});
        }
        if (actualTokens.synthesisInputTokens > 0 || actualTokens.synthesisOutputTokens > 0) {
          costEngine.recordGeminiCost(jobId, userId, "synthesis", "flash", actualTokens.synthesisInputTokens, actualTokens.synthesisOutputTokens).catch(() => {});
        }
      } else {
        // Fallback: chunk-based estimates if usageMetadata was not surfaced
        const extractionChunks = Math.max(1, Math.ceil(claimCount / 5));
        const extractInputTokens = extractionChunks * 2000;
        const extractOutputTokens = extractionChunks * 500;
        costEngine.recordGeminiCost(jobId, userId, "extraction", "flash", extractInputTokens, extractOutputTokens).catch(() => {});

        const verificationBatches = Math.max(1, Math.ceil(verifiedCount / 6));
        const verifyInputTokens = verificationBatches * 3000;
        const verifyOutputTokens = verificationBatches * 1000;
        costEngine.recordGeminiCost(jobId, userId, "verification", modelTier, verifyInputTokens, verifyOutputTokens).catch(() => {});

        costEngine.recordGeminiCost(jobId, userId, "synthesis", "flash", 15000, 5000).catch(() => {});
      }

      // Search Grounding: 1 query per verified claim that used grounding
      const groundedClaims = allVerified.filter(c =>
        c.richSources?.some((s: any) => s.retrievalMethod === "google_grounding")
      ).length;
      if (groundedClaims > 0) {
        costEngine.recordGroundingCost(jobId, userId, groundedClaims).catch(() => {});
      }

      // Cloud Functions compute: credibility pipeline elapsed seconds × 1 vCPU
      costEngine.recordComputeCost(jobId, userId, elapsedSec).catch(() => {});

      // 16. Emit fact-complete
      const eventData: FactCompleteData = {
        honestRating:     null, // v12.0: Scoring removed
        claimsEvaluated:  result.factCheckStats.evaluatedClaims,
        correct:          result.factCheckStats.correct,
        incorrect:        result.factCheckStats.incorrect,
        unverifiable:     result.factCheckStats.unverifiable,
        resultPath:       `factChecks/${jobId}`,
      };

      await this.distribution.publish("fact-complete", {
        eventId:   uuidv4(),
        eventType: "fact-complete",
        jobId, userId,
        timestamp:  Date.now(),
        data:       eventData,
        retryCount: 0,
        source:     "credibility-engine",
      });

      await aggregationLayer.onStageComplete(jobId, "credibility", userId, executionPlan);

      logger.info("[TruthEngine] Completed", {
        jobId,
        rating: result.trustScore,
        ms:     result.processingTime,
        hitRate,
      });
      await this.distribution.markEventCompleted(eventId);

      return result;

    } catch (error: any) {
      logger.error("[Credibility] Execution failed", { jobId, error: String(error) });

      let errorCode: CredibilityErrorCode = "GEMINI_FAILURE";
      if (error instanceof ExtractionError) {
        errorCode = error.code;
      }
      
      const errMsg = error instanceof Error ? error.message : String(error);

      if (errMsg.includes("Transcript not found") || errMsg.includes("Empty transcript")) {
        errorCode = "TRANSCRIPT_EMPTY";
      } else if (errMsg.includes("JSON")) {
        errorCode = "JSON_PARSE_FAILED";
      }

      // v8.4: Robust Capacity Handling
      // If we hit capacity error here, it means even withAiRetry within services failed.
      // We'll attempt a "cool-down" wait if this is the first time we hit it at this level.
      const isCapacity = errorCode === 'AI_CAPACITY_EXCEEDED' || 
                         errMsg.toLowerCase().includes("capacity") || 
                         errMsg.includes("429") || 
                         errMsg.includes("503");

      if (isCapacity) {
        logger.warn("[Credibility] Critical Capacity Limit hit at orchestration level", { jobId });
        
        // Check if we already tried a cool-down
        const jobSnap = await db().collection("video_jobs").doc(jobId).get();
        const retryCount = (jobSnap.data()?.credibilityRetryCount || 0);
        
        if (retryCount < 1) {
           await db().collection("video_jobs").doc(jobId).update({ credibilityRetryCount: retryCount + 1 });
           logger.info("[Credibility] Scheduling a 60s cool-down retry...", { jobId });
           
           // We throw a specific error that the outer orchestrator can catch to retry the task
           // or we just wait here if it's a simple function call. 
           // Given the current architecture, let's wait and retry once.
           await new Promise(resolve => setTimeout(resolve, 60000));
           return this.runCredibilityPipeline(jobId, userId, executionPlan, eventId, traceId);
        }
        
        // If second attempt also fails, fallback to PARTIAL/UNVERIFIED instead of hard failure
        const fallbackResult = this.generateCapacityFallbackResult(jobId, userId, errMsg, transcript);
        await this.storeResult(jobId, userId, fallbackResult);

        // 🚨 VITAL FIX: Notify orchestration that the stage is complete (even if degraded)
        // Without this, the UI and Aggregation Layer will hang forever waiting for 'credibility'.
        await aggregationLayer.onStageComplete(jobId, "credibility", userId, executionPlan);
        
        await this.distribution.publish("fact-complete", {
          eventId:   eventId,
          eventType: "fact-complete",
          jobId, userId,
          timestamp:  Date.now(),
          data:       {
            honestRating: null, // v12.0: Scoring removed
            claimsEvaluated: 0,
            correct: 0,
            incorrect: 0,
            unverifiable: 0,
            resultPath: `factChecks/${jobId}`,
            isDegraded: true
          },
          retryCount: 0,
          source:     "credibility-engine",
        });

        return fallbackResult;
      }

      await EdgeLayer.failJob(jobId, "credibility", errMsg);
      throw error;
    }
  }

  /**
   * Generates a neutral, low-confidence result when AI capacity is exceeded.
   */
  private generateCapacityFallbackResult(jobId: string, userId: string, error: string, transcript: any): CredibilityResult {
    // v12.0: No scoring engine invocation — return minimal result with null scores
    return {
      analysisState: 'ANALYSIS_INCOMPLETE' as any,
      scoreAvailable: false,
      trustScore: null,
      trustLabel: 'Not Scored' as any,
      confidence: 0,
      confidenceTier: 'low' as any,
      factors: null,
      deductions: [],
      totalClaims: 0,
      evaluatedClaims: 0,
      claims: [],
      chapters: [],
      speakers: [],
      summary: "",
      conclusion: { label: "Unverified", text: "We couldn't check the facts for this video right now. Please check your connection and try again soon!", confidence: 0.1 },
      viewerNote: "",
      latencyMs: { extraction: 0, verification: 0, consistency: 0, synthesis: 0, total: 0 },
      telemetry: { transcriptLoaded: true, claimsExtracted: 0, verificationCompleted: false, summaryGenerated: false },
      factCheckStats: { totalClaims: 0, extractedClaims: 0, evaluatedClaims: 0, correct: 0, mostly_correct: 0, incorrect: 0, unsupported: 0, unverifiable: 0, filtered: 0, religious_belief: 0, opinion_claim: 0, satire_claim: 0, verification_timeout: 0 },
      scoringMethod: 'balanced',
      synthesisTier: 'standard',
      isLongform: false,
      isFinal: false,
      verifiedAt: Date.now(),
      processingTime: 0,
      versions: { model: "Gemini 2.5", scoring: "v12.0-no-scoring", registry: "v3-blended" },
      filteringReasons: [],
    } as any;
  }

  private async cacheCheck(
    claims: ExtractedClaim[],
    jobId:  string,
    domainContext?: string
  ): Promise<{ cached: VerifiedClaim[]; stale: VerifiedClaim[]; uncached: ExtractedClaim[] }> {
    try {
      return await this.performanceLayer.checkClaimCache(claims, domainContext);
    } catch (err) {
      logger.error("[Credibility] Cache lookup failed", { jobId, err });
      await alerting.notify("redis-read-failure", { jobId, context: "checkClaimCache" });
      return { cached: [], stale: [], uncached: claims };
    }
  }

  private async cacheWithTTL(claims: VerifiedClaim[]): Promise<void> {
    for (const claim of claims) {
      const category = this.categoriseClaim(claim.text);
      const ttl      = CLAIM_TTL[category] ?? CLAIM_TTL.default;
      try {
        await this.performanceLayer.cacheVerifiedClaimsWithTTL([claim], ttl);
      } catch (err) {
        logger.warn("[Credibility] Claim cache write failed", { err });
      }
    }
  }

  private async trackAndAlertHitRate(
    jobId:     string,
    hits:      number,
    total:     number
  ): Promise<void> {
    const hitRate = total > 0 ? hits / total : 0;
    await this.performanceLayer.trackCost(jobId, {
      geminiCallsAvoided: hits,
      cacheHitRate:       hitRate,
    } as any);

    if (total >= 3 && hitRate < MIN_HIT_RATE) {
      await alerting.notify("low-cache-hit-rate", { jobId, hitRate, hits, total });
    }
  }

  private classifyAndRank(claims: ExtractedClaim[]): Array<ExtractedClaim & { claimStrength: ClaimStrength; importance: number }> {
    return claims
      .map((claim) => {
        const text  = claim.text.toLowerCase();
        let strength: ClaimStrength = "moderate";

        if (text.includes("study") || text.includes("research") || text.includes("data") || text.includes("%")) {
          strength = "strong";
        } else if (text.includes("proven") || text.includes("confirmed") || text.includes("showed")) {
          strength = "absolute";
        } else if (text.includes("think") || text.includes("believe") || text.includes("feel") || text.includes("i think")) {
          strength = "hedged";
        }

        let importance = 0.5;
        if (claim.nature === ClaimNature.VERIFIABLE_FACT || claim.nature === ClaimNature.ESTIMATION) importance += 0.3;
        if (claim.nature === "BELIEF") importance += 0.1;
        if (strength === "strong")     importance += 0.2;
        if (strength === "absolute")          importance += 0.15;
        if (claim.confidence > 0.8)         importance += 0.1;
        if (strength === "hedged")         importance -= 0.3;

        return { ...claim, claimStrength: strength, importance: Math.min(1, Math.max(0, importance)) };
      })
      .sort((a, b) => b.importance - a.importance);
  }

  /**
   * v11.0: Enhanced claim categorization for content-aware cache TTL.
   * Maps claim text to domain-specific categories with appropriate staleness windows.
   */
  private categoriseClaim(text: string): string {
    const t = text.toLowerCase();
    // Breaking news — highest priority, shortest TTL
    if (/\b(breaking|just (announced|reported)|hours ago|minutes ago|live)\b/.test(t)) return 'breaking_news';
    // Political claims
    if (/\b(election|vote|candidate|campaign|poll|government|policy|legislation|congress|parliament)\b/.test(t)) return 'political';
    // Financial claims
    if (/\b(stock|market|economy|gdp|inflation|revenue|profit|earnings|crypto|bitcoin)\b/.test(t)) return 'financial';
    // General news
    if (/\b(today|yesterday|this week|this month|recently|reported|announced)\b/.test(t)) return 'news';
    // Scientific claims
    if (/\b(study|research|published|journal|peer.?review|experiment|hypothesis|clinical|trial)\b/.test(t)) return 'scientific';
    // Educational
    if (/\b(teaches|education|curriculum|lesson|learning|textbook|theory of)\b/.test(t)) return 'education';
    // Statistics
    if (/\b(%|million|billion|trillion|rate|ratio|percent|statistics|data shows)\b/.test(t)) return 'statistics';
    // Historical
    if (/\b(ancient|century|history|historical|era|dynasty|founded in|established in|\d{3,4}\s?(AD|BC|CE|BCE))\b/.test(t)) return 'historical';
    return 'default';
  }

  private buildExplainability(verified: VerifiedClaim[]): ExplainabilityResult[] {
    return verified.map((claim, idx) => {
      const severityLabels: Record<string, string> = {
        low: "Minor error / Inaccuracy",
        medium: "Misleading context",
        high: "Factually false",
        extreme: "Dangerous fabrication"
      };

      // 🕊 Modern Clinical Icon & Label Mapping
      const clinicalLabels: Record<string, { label: string; icon: string }> = {
        correct:                    { label: "Correct", icon: "✅" },
        verified_true:              { label: "Verified True", icon: "✅" },
        mostly_correct:             { label: "Mostly Correct", icon: "🟢" },
        mostly_true:                { label: "Mostly True", icon: "🟢" },
        partially_true:             { label: "Partially True", icon: "🟢" },
        incorrect:                  { label: "Incorrect", icon: "❌" },
        false_claim:                { label: "False", icon: "❌" },
        verified_false:             { label: "False", icon: "❌" },
        misleading:                 { label: "Misleading", icon: "⚠️" },
        disputed:                   { label: "Disputed", icon: "⚖️" },
        outdated:                   { label: "Outdated", icon: "⏳" },
        unsupported:                { label: "Unsupported", icon: "🔍" },
        unproven:                   { label: "Unproven", icon: "🔍" },
        inconclusive:               { label: "Inconclusive", icon: "🔍" },
        limited_support:            { label: "Limited Support", icon: "🔍" },
        needs_context:              { label: "Needs Context", icon: "📎" },
        opinion:                    { label: "Opinion", icon: "💭" },
        opinion_claim:              { label: "Opinion", icon: "💭" },
        satire:                     { label: "Satire", icon: "🎭" },
        satire_claim:               { label: "Satire", icon: "🎭" },
        religious_belief:           { label: "Faith / Belief", icon: "🕊" },
        faith_based_claim:          { label: "Faith-Based Claim", icon: "🕊" },
        not_historically_verifiable:{ label: "Not Historically Verifiable", icon: "🏛" },
        anecdotal_experience:       { label: "Personal Experience", icon: "👤" },
        value_judgment:             { label: "Value Judgment", icon: "⚖️" },
        preference_statement:        { label: "Preference", icon: "❤️" },
        unverifiable_personal_claim: { label: "Personal Account", icon: "🗣️" },
        doctrinal_unverifiable:     { label: "Doctrinal Statement", icon: "🕊" },
        historical_tradition:       { label: "Scriptural Tradition", icon: "🏛" },
        historical_consensus_denial: { label: "Historical Reality Failure", icon: "❌" },
        incorrect_citation:         { label: "Incorrect Source Citation", icon: "📜" },
        contested_interpretation:    { label: "Contested Interpretation", icon: "⚖️" },
        unverifiable:               { label: "Unverifiable", icon: "❔" }
      };

      const mapped = clinicalLabels[claim.status] || { label: claim.status, icon: "❔" };

      return {
        claimId:        claim.claimId ?? `claim_${idx}`,
        claim:          claim.text,
        displayLabel:   `${mapped.icon} ${claim.text}`,
        status:         claim.status,
        nature:         claim.nature,
        framing:        claim.framing,
        evidenceLevel:  claim.evidenceLevel,
        ontology:       claim.nature as any, // Legacy field
        severity:       claim.severity,
        severityLabel:  claim.severity ? severityLabels[claim.severity] : undefined,
        reasoning:      claim.reasoning || claim.verificationSummary || "",
        response:       claim.reasoning || claim.verificationSummary || "",
        explanation:    claim.reasoning || claim.verificationSummary || "",
        whyWrong:       claim.reasoning || undefined,
        correction:     ['incorrect', 'historical_consensus_denial', 'incorrect_citation'].includes(claim.status)
          ? `Correction: ${claim.reasoning}`
          : (claim.reasoning || undefined),
        sources:        claim.richSources && claim.richSources.length > 0
          ? claim.richSources.map(rs => {
              const dom = rs.domain || SourceAvatarService.cleanDomain(rs.url);
              const avatar = SourceAvatarService.resolveAvatar(dom, rs.publisher || rs.author);
              return {
                title:          rs.title,
                url:            rs.url,
                domain:         dom,
                publisher:      rs.publisher || rs.author,
                publishedAt:    rs.publishedAt || rs.lastPublished || (rs.yearPublished ? `${rs.yearPublished}` : undefined),
                avatarUrl:      avatar,
                snippet:        rs.snippet || "",
                relevanceScore: 0.9,
                tier:           rs.tier,       // v5.0
                provenance:     rs.snippet     // v5.0: Source snippet used as provenance
              };
            })
          : (claim.sources ?? []).map((s: string) => {
              const dom = sourceTrustService.resolvePublisherDomain(s) || SourceAvatarService.cleanDomain(s);
              const url = s.startsWith("http")
                ? s
                : (dom
                    ? `https://${dom}`
                    : (s.trim().length > 0 ? `https://www.google.com/search?q=${encodeURIComponent(s.trim())}` : undefined));
              const avatar = SourceAvatarService.resolveAvatar(dom, s);
              return {
                title:          s,
                url:            url,
                domain:         dom,
                avatarUrl:      avatar,
                snippet:        "",
                relevanceScore: 0.8,
              };
            }),
        timestampStart: claim.start ?? 0,
        timestampEnd:   claim.end   ?? 0,
        confidence:     claim.verificationConfidence ?? claim.confidence ?? 0.5,
        multiModelConsensus: claim.multiModelConsensus,
      };
    });
  }

  private async storeResult(
    jobId:  string,
    userId: string,
    result: CredibilityResult
  ): Promise<void> {
    const { path: latestPath } = await this.analysisRepository.saveAnalysis(jobId, "factChecks", result);
    const bucket = admin.storage().bucket();
    const factCheckUrl = `gs://${bucket.name}/${latestPath}`;

    // v12.1 FIX: Distinguish between "unscored" (null) and "scored 0" (genuine low-trust).
    // When scoring is disabled (v12.0 decoupled mode), trustScore is null — do NOT coerce to 0.
    const isScored = result.scoreAvailable !== false && result.trustScore !== null && !isNaN(result.trustScore as any);
    const finalTrustScore = isScored ? (result.trustScore as number) : null;
    // Update video_jobs with the factCheckUrl
    await db().collection("video_jobs").doc(jobId).update({
      "outputs.factCheckUrl": factCheckUrl,
      "outputs.trustScore": finalTrustScore,
      "outputs.scoreAvailable": isScored,
      updatedAt: Date.now(),
    });

    // Skip Firestore factChecks write to comply with storage-only verification results policy
    logger.info("[Credibility] Skipped Firestore factChecks write, result saved to Storage only", { jobId });

    // v12.1 FIX: Only update channel reputation when a real score was computed.
    // Writing unscored sentinel values into EWMA would poison channel ratings.
    if (isScored && finalTrustScore !== null) {
      try {
        const { updateChannelReputationAndVideos } = await import("../../channels/reputation_triggers.js");
        await updateChannelReputationAndVideos(jobId, finalTrustScore);
      } catch (err) {
        logger.error("[Credibility] Failed to propagate reputation updates", { jobId, err });
      }
    } else {
      logger.info("[Credibility] Skipped reputation update — scoring not available (v12.0 decoupled mode)", { jobId });
    }

    // Note: Propagation to video collection is now handled centrally by AggregationLayer.onStageComplete
    // which is called immediately after this method returns in runCredibilityPipeline.

    // Initialize/Update Creator Trust Score (Exponential Moving Average later)
    await db().collection("users").doc(userId).set({
       creatorTrustVersion: 30,
       latestTrustScore: result.trustScore,
       factors: result.factors,
       updatedAt: Date.now()
    }, { merge: true });
  }

  public async runSynthesisPass(jobId: string, userId: string, eventId: string): Promise<void> {
    logger.info("[CredibilityEngine.runSynthesisPass] Starting async synthesis pass", { jobId, userId, eventId });

    const draftDoc = await db().collection("credibility_drafts").doc(jobId).get();
    if (!draftDoc.exists) {
      logger.warn("[CredibilityEngine.runSynthesisPass] Draft document does not exist, aborting", { jobId });
      return;
    }

    const draft = draftDoc.data();
    if (!draft || draft.synthesisPending !== true) {
      logger.info("[CredibilityEngine.runSynthesisPass] Draft is not marked pending, skipping", { jobId });
      return;
    }

    const {
      verifiedClaims,
      synthesisTier = "standard",
      speakerIdentities = {},
      evaluationHealth = {},
      executionPlanRef,
    } = draft;
    void executionPlanRef;

    const transcript = await this.loadTranscript(jobId);
    if (!transcript) {
      logger.error("[CredibilityEngine.runSynthesisPass] Transcript not found", { jobId });
      return;
    }

    const existingResult = await this.loadExistingResult(jobId);
    if (!existingResult) {
      logger.error("[CredibilityEngine.runSynthesisPass] Existing CredibilityResult not found", { jobId });
      return;
    }

    const speakerCount = Object.keys(speakerIdentities).length;
    const pipelineMode = speakerCount > 1 ? "multi" : "standard";
    const speakerPriors = await this.fetchSpeakerPriors(Object.values(speakerIdentities).map((id: any) => id.id)).catch(() => ({}));

    let synthesis: SynthesisResult;
    try {
      synthesis = await this.extractionService.generateTieredIntelligence(
        transcript.utterances ?? [],
        verifiedClaims,
        synthesisTier,
        [],
        {
          pipelineMode,
          speakerCount,
          speakerIdentities,
          speakerPriors,
          evaluationHealth,
        }
      );
    } catch (err: any) {
      logger.error("[CredibilityEngine.runSynthesisPass] Synthesis generation failed in background", { jobId, error: err?.message });
      const isZeroClaims = verifiedClaims.length === 0;
      const fallbackSources: any[] = [];
      const seenFallbackKeys = new Set<string>();
      for (const c of verifiedClaims) {
        const sList = (c as any).sources || (c as any).richSources || (c as any).effectiveSources || [];
        for (const s of sList) {
          const k = (s.url || s.domain || s.title || "").toLowerCase();
          if (k && !seenFallbackKeys.has(k)) {
            seenFallbackKeys.add(k);
            fallbackSources.push({
              title: s.title || s.domain || "Authoritative Source",
              url: s.url || "",
              domain: s.domain || "",
              trustLevel: s.tier === 'A' || s.tier === 'B' ? 'High' : 'Medium',
              type: s.type || 'Supporting',
              snippet: s.snippet || "",
            });
          }
        }
      }
      synthesis = {
        summary: isZeroClaims
          ? ""
          : `Analysis of ${verifiedClaims.length} claim(s) completed. Individual claim verdicts and sources are available.`,
        conclusion: {
          label: isZeroClaims ? "No Claims Found" : "Review Complete",
          text: isZeroClaims
            ? "We checked this video and didn't find any specific facts that need checking — it's mostly personal opinions, music, or casual conversation!"
            : `${verifiedClaims.filter((c: any) => c.status === 'verified_true' || c.status === 'mostly_true').length} of ${verifiedClaims.length} claims were backed up by reliable proof. You can check the details for each claim below!`,
          confidence: isZeroClaims ? 1.0 : 0.8,
          sources: fallbackSources,
        },
        hallucinationIsolation: { verifiedFacts: [], modelInterpretations: [], uncertainInferences: [] },
        traceabilityMap: {},
        knowledgeDensity: isZeroClaims ? 0.0 : 0.5,
        keyThemes: [],
        viewerNote: "",
        manipulationScore: 0.15,
        manipulationSignals: [],
        chapters: [],
        speakers: [],
        speakerRoles: {},
      } as unknown as SynthesisResult;
    }

    // Patch existingResult with synthesized fields
    existingResult.summary = synthesis.summary;
    existingResult.conclusion = synthesis.conclusion;
    existingResult.viewerNote = synthesis.viewerNote;
    existingResult.chapters = synthesis.chapters || existingResult.chapters || [];
    existingResult.keyThemes = synthesis.keyThemes || existingResult.keyThemes || [];
    existingResult.manipulationScore = synthesis.manipulationScore;

    // Save updated result to GCS analysis repository and full.json
    await this.analysisRepository.saveAnalysis(jobId, "factChecks", existingResult);
    const bucket = admin.storage().bucket();
    await bucket.file(`factChecks/${jobId}/full.json`).save(JSON.stringify(existingResult), {
      metadata: { contentType: "application/json" }
    });

    // Update videos/{jobId} document in Firestore
    try {
      await db().collection("videos").doc(jobId).set({
        summary: synthesis.summary,
        viewerNote: synthesis.viewerNote,
        conclusion: synthesis.conclusion,
        "aiFeatures.factCheckSummary": synthesis.summary,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (videoUpdateErr: any) {
      logger.warn("[CredibilityEngine.runSynthesisPass] Could not patch videos document directly", { jobId, error: videoUpdateErr?.message });
    }

    // Clean up draft
    await db().collection("credibility_drafts").doc(jobId).delete();
    logger.info("[CredibilityEngine.runSynthesisPass] Successfully completed async synthesis pass and deleted draft", { jobId });
  }

  private async loadExistingResult(jobId: string): Promise<CredibilityResult> {
    const bucket = admin.storage().bucket();
    const [data] = await bucket.file(`factChecks/${jobId}/full.json`).download();
    return JSON.parse(data.toString()) as CredibilityResult;
  }

  private async loadTranscript(jobId: string): Promise<any | null> {
    const doc = await db().collection("transcripts").doc(jobId).get();
    return doc.exists ? doc.data() : null;
  }

  /**
   * 🏷 v7: Identity Resolution Bridge (Hardened against 10k-char truncation amnesia)
   */
  private async resolveSpeakerIdentities(
    jobId: string,
    channelId: string,
    transcript: any,
    roles: Record<string, string>
  ): Promise<Record<string, { id: string; name: string; role: string; confidence: number }>> {
    const rawText = transcript?.text || "";
    let sampleForNameExtraction = rawText;

    // Multi-segment representative sampling across the entire video duration
    if (rawText.length > 16000) {
      const introSlice = rawText.slice(0, 7000);
      const midPoint = Math.floor(rawText.length / 2);
      const midSlice = rawText.slice(Math.max(0, midPoint - 2500), midPoint + 2500);
      const outroSlice = rawText.slice(-3000);

      // Collect late-appearing speaker dialogue samples from utterances
      const lateSpeakerSamples: string[] = [];
      if (Array.isArray(transcript?.utterances)) {
        const seenSpeakers = new Set<string>();
        for (const u of transcript.utterances) {
          if (!u?.speaker) continue;
          if ((u.end || 0) < 300000) { // first 5 minutes
            seenSpeakers.add(u.speaker);
          } else if (!seenSpeakers.has(u.speaker)) {
            // First time seeing this late-entering speaker
            seenSpeakers.add(u.speaker);
            if (u.text && lateSpeakerSamples.length < 5) {
              lateSpeakerSamples.push(`[${u.speaker} Dialogue Sample]: ${u.text.slice(0, 300)}`);
            }
          }
        }
      }

      sampleForNameExtraction = [
        "--- [BEGINNING / INTRODUCTIONS] ---",
        introSlice,
        "--- [MIDPOINT DISCUSSION] ---",
        midSlice,
        "--- [CLOSING REMARKS & CREDITS] ---",
        outroSlice,
        lateSpeakerSamples.length > 0 ? "--- [LATE-ENTERING SPEAKERS] ---\n" + lateSpeakerSamples.join("\n") : ""
      ].filter(Boolean).join("\n\n");
    }

    const speakerNames = await this.extractionService
      .extractSpeakerNames(sampleForNameExtraction)
      .catch(() => ({} as Record<string, string>));

    // Gather all unique speaker labels from transcript metadata, utterances, and AI extraction
    const allSpeakerLabels = new Set<string>();
    if (Array.isArray(transcript?.speakers)) {
      for (const s of transcript.speakers) {
        if (typeof s === "string") allSpeakerLabels.add(s);
        else if (s?.speaker) allSpeakerLabels.add(s.speaker);
        else if (s?.id) allSpeakerLabels.add(s.id);
      }
    }
    if (Array.isArray(transcript?.utterances)) {
      for (const u of transcript.utterances) {
        if (u?.speaker) allSpeakerLabels.add(u.speaker);
      }
    }
    for (const label of Object.keys(speakerNames)) {
      allSpeakerLabels.add(label);
    }

    if (allSpeakerLabels.size === 0) {
      allSpeakerLabels.add("Speaker A");
    }

    const identities: Record<string, { id: string; name: string; role: string; confidence: number }> = {};

    for (const label of allSpeakerLabels) {
      const extractedName = speakerNames[label]?.trim();
      const isKnown = extractedName && extractedName !== "Unknown" && !extractedName.toLowerCase().startsWith("speaker");
      
      const role = roles[label] || (label === "Speaker A" || label === "Host" ? "Host" : "Guest");
      const displayName = isKnown 
        ? extractedName 
        : (role === "Host" ? `Channel Host (${label})` : `Guest (${label})`);

      const resolved = await this.speakerRegistry.resolveIdentity(channelId, displayName, role as any);
      identities[label] = {
        id: resolved.id,
        name: displayName,
        role,
        confidence: resolved.confidence,
      };
    }

    return identities;
  }

  /**
   * 🏆 v7: Fetch Speaker Priors
   */
  private async fetchSpeakerPriors(speakerIds: string[]) {
    const priors: Record<string, any> = {};
    for (const id of speakerIds) {
      priors[id] = await this.speakerReputation.getReputation(id);
    }
    return priors;
  }

  private async enqueueBackgroundRefresh(
    jobId: string,
    staleClaims: VerifiedClaim[],
    domain: string
  ): Promise<void> {
    const claimIdsToRefresh: string[] = [];
    const cacheKeysToRefresh: string[] = [];

    // Bypassed lock acquisition: SWR locks disabled as Firestore fact-checking caching is removed.
    for (const claim of staleClaims) {
      const claimHash = this.performanceLayer["hashClaim"](claim.text);
      claimIdsToRefresh.push(claim.claimId || claimHash);
      cacheKeysToRefresh.push(claimHash);
    }

    if (claimIdsToRefresh.length === 0) {
      logger.info("[SWR] All stale claims already locked for refresh. Skipping enqueue.", { jobId });
      return;
    }

    const queueName = this.getQueueNameForDomain(domain);
    const payload = {
      jobId,
      claimIds: claimIdsToRefresh,
      cacheKeys: cacheKeysToRefresh,
      domainContext: domain
    };

    try {
      const { getFunctions } = await import("firebase-admin/functions");
      const queue = getFunctions().taskQueue(queueName);
      await queue.enqueue(payload);
      logger.info(`[SWR] Enqueued background refresh to queue ${queueName}`, { jobId, payload });
      logger.info(`[TELEMETRY] SWR Enqueued: queue=${queueName}, claimCount=${claimIdsToRefresh.length}`);
    } catch (err) {
      logger.error("[SWR] Failed to enqueue background refresh task", { jobId, queueName, err });
    }
  }

  private getQueueNameForDomain(domain: string): string {
    const dom = domain.toLowerCase();
    if (dom.includes("breaking") || dom.includes("election") || dom.includes("disaster") || dom.includes("politics")) {
      return "refreshHighQueue";
    }
    if (dom.includes("finance") || dom.includes("medical") || dom.includes("health") || dom.includes("economic")) {
      return "refreshMediumQueue";
    }
    if (dom.includes("science") || dom.includes("history") || dom.includes("educational")) {
      return "refreshLowQueue";
    }
    return "refreshBackgroundQueue";
  }

  /**
   * Background task handler to refresh stale claim and citation caches.
   */
  async refreshCacheForClaims(payload: {
    jobId: string;
    claimIds: string[];
    cacheKeys: string[];
    domainContext: string;
  }): Promise<void> {
    const { jobId, claimIds, cacheKeys, domainContext } = payload;
    logger.info("[SWR Worker] Starting background cache refresh", { jobId, claimIds, cacheKeys, domainContext });
    logger.info(`[TELEMETRY] SWR Refresh Started: count=${claimIds.length}`);

    // Load full claims from video_jobs/transcripts since we only enqueued IDs
    const claimsToVerify: FilteredClaim[] = [];
    try {
      const transcriptDoc = await db().collection("transcripts").doc(jobId).get();
      if (transcriptDoc.exists) {
        const claimsList = transcriptDoc.data()?.claims || [];
        for (const claim of claimsList) {
          const claimHash = this.performanceLayer["hashClaim"](claim.text);
          if (cacheKeys.includes(claimHash)) {
            claimsToVerify.push({
              ...claim,
              claimId: claim.claimId || claimHash
            });
          }
        }
      }
      
      if (claimsToVerify.length < cacheKeys.length) {
        const jobDoc = await db().collection("video_jobs").doc(jobId).get();
        if (jobDoc.exists) {
          const claimsList = jobDoc.data()?.claims || [];
          for (const claim of claimsList) {
            const claimHash = this.performanceLayer["hashClaim"](claim.text);
            const alreadyAdded = claimsToVerify.some(c => this.performanceLayer["hashClaim"](c.text) === claimHash);
            if (cacheKeys.includes(claimHash) && !alreadyAdded) {
              claimsToVerify.push({
                ...claim,
                claimId: claim.claimId || claimHash
              });
            }
          }
        }
      }
    } catch (err) {
      logger.error("[SWR Worker] Failed to load claims from Firestore", { jobId, err });
      return;
    }

    if (claimsToVerify.length === 0) {
      logger.warn("[SWR Worker] No matching claims found in job/transcript for refresh", { jobId, cacheKeys });
      return;
    }

    logger.info(`[SWR Worker] Resolved ${claimsToVerify.length} claims to re-verify`, { jobId });

    try {
      const isSensitiveTopic = ["health", "politics", "finance"].some(t => domainContext.toLowerCase().includes(t));
      const deepResearchOptions = {
        jobId: jobId,
        groundingMode: isSensitiveTopic ? "always" as const : "sensitive_only" as const,
        forcePro: false,
        minSourcesRequired: 2,
        sourceDiversityRequired: true,
        isDiscoverySensitive: isSensitiveTopic
      };

      const verificationResult = await this.verificationService.verifyClaims(
        claimsToVerify,
        claimsToVerify.length,
        1,
        domainContext,
        deepResearchOptions
      );

      for (const claim of verificationResult.claims) {
        const category = this.categoriseClaim(claim.text);
        const ttl = CLAIM_TTL[category] ?? CLAIM_TTL.default;
        await this.performanceLayer.cacheVerifiedClaim(claim, ttl);
        
        const claimHash = this.performanceLayer["hashClaim"](claim.text);
        await db().collection("refresh_locks").doc(claimHash).delete().catch(() => {});
      }

      logger.info("[SWR Worker] Successfully completed background cache refresh", { jobId, count: verificationResult.claims.length });
      logger.info(`[TELEMETRY] SWR Refresh Completed: count=${verificationResult.claims.length}`);
      recordSuccess();
    } catch (err) {
      logger.error("[SWR Worker] Verification failed during cache refresh", { jobId, err });
      recordFailure();
    }
  }
}

export { formatOpinionReasoning } from "../utils/opinion-formatting";

