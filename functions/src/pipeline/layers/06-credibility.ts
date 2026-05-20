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
  CredibilityErrorCode,
  ExtractionError,
  SynthesisResult,
  ClaimStatus,
  ClaimNature,
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
import { PIPELINE_CONFIG, DEEP_RESEARCH_CONFIG, isDeepResearchEnabled }         from "../config";
import { reputationService }       from "../services/reputationService";
import { contentIntentDetector }    from "../services/contentIntentDetector";
import { speakerTrustEngine }       from "../services/speakerTrustEngine";
import { SpeakerRegistryService }    from "../services/speakerRegistry";
import { SpeakerReputationService }  from "../services/speakerReputationService";
import { registryService } from "../registry/RegistryService";

const db = () => admin.firestore();

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

  constructor(geminiApiKey: string) {
    this.extractionService   = new FactExtractionService(geminiApiKey);
    this.verificationService = new ClaimVerificationService(geminiApiKey, 0.6);
    this.scoringEngine       = new ScoringEngine();
    this.distribution        = new DistributionLayer();
    this.performanceLayer    = new PerformanceLayer();
    this.speakerRegistry     = new SpeakerRegistryService();
    this.speakerReputation   = new SpeakerReputationService();
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
      
      const deepResearchActive = isDeepResearchEnabled(executionPlan.synthesisTier || 'standard');
      const maxExtractionTarget = deepResearchActive 
        ? DEEP_RESEARCH_CONFIG.MAX_CLAIMS_INSTITUTIONAL 
        : DEEP_RESEARCH_CONFIG.MAX_CLAIMS_STANDARD;

      let extractionPartial = false;
      const [domainInfo, rawClaimsResult, speakerIdentities] = await Promise.all([
        // v13.2: Graceful degradation — domain detection must NEVER crash the pipeline
        this.extractionService.detectDomainAndStance(transcript.utterances ?? []).catch((err: any) => {
          logger.error("[Credibility] Domain detection failed, using safe defaults", { jobId, error: err?.message });
          return { domain: "General", stance: "Mixed", cautionLevel: "medium" as const, isLaunchNews: false, primaryIntent: "educational", isSensitive: false };
        }),
        // v13.2: Extraction with crash-proof fallback
        Promise.race([
          this.extractionService.extractClaims(jobId, transcript, 60_000, maxExtractionTarget)
            .then(claims => ({ claims, partial: false }))
            .catch((err: any) => {
              logger.error("[Credibility] Primary extraction failed", { jobId, error: err?.message });
              return { claims: [] as any[], partial: true };
            }),
          new Promise<{ claims: any[], partial: boolean }>(resolve => {
            setTimeout(() => {
              logger.warn("[Credibility] Extraction reached 30s budget — returning partial results", { jobId });
              resolve({ claims: [], partial: true });
            }, 30_000);
          })
        ]),
        this.resolveSpeakerIdentities(jobId, jobDoc.data()?.channelId || "unknown", transcript, {}).catch(() => ({}))
      ]);

      const rawClaims = rawClaimsResult.claims;
      extractionPartial = rawClaimsResult.partial;

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

      await EdgeLayer.updateStage(jobId, "credibility", { progress: 30 });

      // 3. Classify + rank by importance
      const filteringReasons: string[] = [];
      const ranked = this.classifyAndRank(rawClaims);

      // 4. Hard claim cap (v10.5: Scale based on Deep Research status)
      const maxClaims = deepResearchActive 
        ? DEEP_RESEARCH_CONFIG.MAX_CLAIMS_INSTITUTIONAL 
        : DEEP_RESEARCH_CONFIG.MAX_CLAIMS_STANDARD;

      const topClaims     = ranked.slice(0, maxClaims);
      const filteredCount = ranked.length - topClaims.length;

      if (filteredCount > 0) {
        filteringReasons.push(`${filteredCount} claims filtered due to institutional importance ranking (Max: ${maxClaims})`);
      }

      logger.info("[Credibility] Claims filtered", {
        jobId, total: ranked.length, kept: topClaims.length, filtered: filteredCount,
      });

      await EdgeLayer.updateStage(jobId, "credibility", { progress: 40 });

      // 4.5 NEW: Early Exit if no claims extracted (v5.0)
      if (topClaims.length === 0) {
        logger.warn("[Credibility] No claims extracted from transcript", { jobId });
        // Proceed to synthesis/scoring with empty claims
      }

      // 5. Cache lookup
      logger.info("[Credibility] Stage 4: Cache lookup", { jobId, traceId });
      const { cached, uncached } = await this.cacheCheck(topClaims, jobId);
      cached.forEach(c => c.verificationMethod = 'cache_hit'); // v11.5
      const hitRate = topClaims.length > 0 ? cached.length / topClaims.length : 0;

      await this.trackAndAlertHitRate(jobId, cached.length, topClaims.length);

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
          registryHits.push({
            ...claim,
            claimId: `claim_reg_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`,
            status: mapRegistryStatus(registryCheck.status),
            verificationConfidence: 1.0,
            evidenceConfidence: 1.0,
            reasoning: registryCheck.reasoning,
            sources: [registryCheck.source],
            richSources: [{ title: registryCheck.source, url: "#", tier: "A", snippet: registryCheck.reasoning }],
            isGrounded: true,
            verificationMethod: 'deterministic' // v11.5
          });
        } else {
          stillUncached.push(claim);
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
        reasoning: "Classified as subjective content — not subject to factual verification.",
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

           // v10.6: Dynamic Batching — accounts for model, grounding, and deep research
           const batchSize = (() => {
             if (executionPlan.priorityMode === 'accuracy') return 2;
             if (deepResearchActive) return 3;  // Pro + grounding: 3 claims per batch
             if (effectiveGroundingMode === 'always' || domainInfo.domain === 'News' || domainInfo.domain === 'Technology') return 3;
             if (effectiveGroundingMode === 'auto') return PIPELINE_CONFIG.BATCH_SIZE_GROUNDING;
             return 5;  // standard Flash
           })();

          const deepResearchOptions = {
            jobId: jobId,
            groundingMode: deepResearchActive ? DEEP_RESEARCH_CONFIG.GROUNDING_MODE : (effectiveGroundingMode as any),
            // v14.0: CRITICAL FIX — was `||` which forced Pro on EVERY video.
            // Only force Pro when Deep Research is explicitly active.
            forcePro: deepResearchActive && DEEP_RESEARCH_CONFIG.FORCE_PRO_MODEL,
            minSourcesRequired: DEEP_RESEARCH_CONFIG.MIN_SOURCES_PER_CLAIM,
            sourceDiversityRequired: DEEP_RESEARCH_CONFIG.SOURCE_DIVERSITY_REQUIRED,
            isDiscoverySensitive: isDiscoverySensitive || isSensitiveTopic
          };

          // v10.5 Audit #8: Pre-verification cost logging
          const costEstimate = this.scoringEngine.estimateDeepResearchCost(factual.length, 3, batchSize);
          logger.info(`[Credibility] Deep Research Cost Estimate: $${costEstimate.estimatedCostUsd} for ${factual.length} claims`, { jobId });
          if (costEstimate.warning) logger.warn(`[Credibility] ${costEstimate.warning}`);

          // v10.6: Reduce maxConcurrent to prevent API stampedes
          // Deep research: 3 parallel batches max; Standard: 5
          const maxConcurrent = deepResearchActive ? 3 : 5;

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
          } catch (verErr) {
            logger.error(`[Credibility] Verification pipeline threw — initiating Full Recovery Pass`, { jobId, error: (verErr as any)?.message });
            try {
              verified = await this.verificationService.verifyBatchWithFastKnowledge(factual, jobId);
              batchStats = { completed: verified.length, timedOut: 0 };
              logger.info(`[Credibility] Full Recovery Pass succeeded: ${verified.length} claims recovered`, { jobId });
            } catch (recoveryErr) {
              logger.error(`[Credibility] Full Recovery Pass also failed — graceful degradation`, { jobId, error: (recoveryErr as any)?.message });
              verified = [];
            }
          }
        }
        return verified;
      })();

      // 9. Merge cached + newly verified + labeled opinions (v5.0)
      const newlyVerified = await verificationPromise;
      const tVerificationEnd = Date.now();
      let allVerified = [...cached, ...registryHits, ...newlyVerified, ...labeledOpinions];

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

      if (durationSeconds > 1800 || pipelineMode === "debate" || executionPlan.contentFormat === "debate") {
        synthesisTier = "deep"; // > 30m or Debate
      } else if (pipelineMode === "multi" || executionPlan.contentFormat === "podcast") {
        synthesisTier = "podcast"; // Interviews/Podcasts
      }

      logger.info("[Credibility] Creator-Informed Adaptive Orchestration", { 
        jobId, speakerCount, expectedCount, pipelineMode, synthesisTier 
      });

      // 9.6 NEW: Orchestrate Synthesis, Consistency, and Reputation in Parallel (v8.5 Performance Boost)
      await EdgeLayer.updateStage(jobId, "credibility", { progress: 70 });
      logger.info("[Credibility] Stage 6: Parallelizing consistency check and adaptive synthesis", { jobId, traceId });
      
      const tConsistencyStart = Date.now();
      // v14.0: Consistency check + synthesis are now crash-proof.
      // If either LLM call fails, we return safe defaults instead of crashing the pipeline.
      const [consistencyResult, synthesis] = await Promise.all([
        this.extractionService.detectInternalContradictions(allVerified).catch((err: any) => {
          logger.error("[Credibility] Consistency check failed, using empty result", { jobId, error: err?.message });
          return { contradictions: [], overallConsistency: "unknown" };
        }),
        this.extractionService.generateTieredIntelligence(
          transcript.utterances ?? [],
          allVerified,
          synthesisTier,
          [], 
          { pipelineMode, speakerCount, speakerIdentities, speakerPriors: {}, evaluationHealth }
        ).catch((err: any) => {
          logger.error("[Credibility] Synthesis generation failed, using fallback", { jobId, error: err?.message });
          return {
            summary: `Analysis of ${allVerified.length} claims completed. Synthesis unavailable due to infrastructure timeout.`,
            conclusion: { label: "Analysis Complete", text: `${allVerified.filter(c => c.status === 'verified_true').length} of ${allVerified.length} claims verified.`, confidence: 0.5 },
            hallucinationIsolation: { verifiedFacts: [], modelInterpretations: [], uncertainInferences: [] },
            traceabilityMap: {},
            knowledgeDensity: 0,
            keyThemes: [],
            viewerNote: "Synthesis was unavailable due to infrastructure timeout. Claim verdicts are still valid.",
            manipulationScore: 0.15,
            manipulationSignals: [],
            chapters: [],
            speakers: [],
            speakerRoles: {},
          } as unknown as SynthesisResult;
        })
      ]) as [any, SynthesisResult];
      const tConsistencyEnd = Date.now();

      // Resolve priors and re-run synthesis with context if needed (or just use the parallel result)
      const speakerPriors = await this.fetchSpeakerPriors(Object.values(speakerIdentities).map((id: any) => id.id)).catch(() => ({}));
      
      // Update synthesis with consistency and speaker context if they were critical
      if (consistencyResult.hasContradiction) {
          synthesis.summary += `\n\n### Consistency Warning:\n${consistencyResult.details}`;
      }
      
      // Integrate speaker priors into synthesis telemetry (v7.2)
      (synthesis as any).speakerPriors = speakerPriors;

      // 10. Build explainability
      const explainableResults = this.buildExplainability(allVerified);

      // 11.5 NEW: Fetch user reputation for Expertise Score (Factor 5)
      const userRep = await reputationService.getReputation(userId);
      const userHistory = {
         reputation: userRep ? userRep.accuracyRate : 0.8, // Fallback to 80% if new
         misinfoStrikes: 0 // Placeholder until strikes are implemented in ReputationService
      };

      // 11.6 v5.0: Compute Speaker Trust Metrics
      const speakerBreakdowns = speakerTrustEngine.computeSpeakerMetrics(allVerified, synthesis.speakerRoles);
      logger.info("[Credibility] Speaker metrics computed", { jobId, speakerCount: speakerBreakdowns.length });

      const tFinal = Date.now();

      // 12. Score (Institutional Trust Score v5.0)
      // v5.0: Determine if launch claims were grounded (have real sources)
      const launchGrounded = domainInfo.isLaunchNews && newlyVerified.some(c => 
        c.isGrounded === true || (c.richSources && c.richSources.length > 0)
      );

      const trustScoreResult = this.scoringEngine.calculateInstitutionalTrustScore(
        jobId, userId,
        transcript, 
        allVerified,
        rawClaims.length,
        executionPlan.channelType === "custom" ? "strict" : "balanced",

        domainInfo.cautionLevel,
        domainInfo.domain,
        {
          consistencyFactor: synthesis.chapters?.[0]?.videoRating ? synthesis.chapters[0].videoRating / 10 : undefined,
          manipulationScore: synthesis.manipulationScore, // Graded L11 score
          chapters: synthesis.chapters, // NEW: Pass for deterministic normalization
          filteringReasons, // NEW: Pass for reporting
          contentIntent,    // v4.3: Content Intent Detection
          isLaunchNews: domainInfo.isLaunchNews,  // v5.0: Launch freshness boost
          launchGrounded,                          // v5.0: Grounding confirmation
          speakerCount,                            // v7.2: Calculate Metadata Reliability Score
          viewerNote: synthesis.viewerNote,        // v8.3: Narrative generation
          hallucinationIsolation: synthesis.hallucinationIsolation, // v10.0
          traceabilityMap: synthesis.traceabilityMap, // v10.0
          extractionPartial, // v11.1: Partial extraction telemetry
        },
        userHistory,
        executionPlan.videoCategory, // v8.0: Category-aware epistemic scoring
        undefined,                   // primaryVertical
        {},                          // verticalScores
        executionPlan.synthesisTier || 'standard',
        batchStats
      );

      // v11.5: Institutional-grade coverage metric
      const totalVerifiable = trustScoreResult.factCheckStats.totalClaims - 
                             (trustScoreResult.factCheckStats.opinion_claim + 
                              trustScoreResult.factCheckStats.religious_belief + 
                              trustScoreResult.factCheckStats.satire_claim);
      
      const totalTimedOut = trustScoreResult.factCheckStats.verification_timeout;
      const totalReachedTerminal = totalVerifiable - totalTimedOut;
      
      const coverageRatio = totalVerifiable > 0 ? Math.max(0, totalReachedTerminal / totalVerifiable) : 1.0;
      trustScoreResult.factCheckStats.verificationCoverageRatio = Number(coverageRatio.toFixed(2));

      const result: CredibilityResult = {
        analysisState:    trustScoreResult.analysisState,
        scoreAvailable:   trustScoreResult.scoreAvailable,
        analysisFailureReason: trustScoreResult.analysisFailureReason,
        viewerNote:       trustScoreResult.viewerNote,
        uiReport:         trustScoreResult.uiReport,

        trustScore:       trustScoreResult.trustScore,
        trustLabel:       trustScoreResult.trustLabel,
        confidence:       trustScoreResult.confidence,
        confidenceTier:   trustScoreResult.confidenceTier,
        videoRating:      trustScoreResult.videoRating ?? (trustScoreResult.trustScore !== null ? Number((trustScoreResult.trustScore / 10).toFixed(1)) : 0),
        
        factors:          trustScoreResult.factors,
        chapters:         synthesis.chapters || [],
        speakers:         speakerBreakdowns, // v5.0: Populated speaker metrics
        claims:           explainableResults,
        
        deductions:       trustScoreResult.deductions, // v5.1: Transparency
        
        // v8.0: Category-Aware Epistemic Scoring
        videoCategory:          trustScoreResult.videoCategory,
        categoryWeightProfile:  trustScoreResult.categoryWeightProfile,
        honestyBreakdown:       trustScoreResult.honestyBreakdown,
        contextualFlags:        trustScoreResult.contextualFlags,
        harmCapApplied:         trustScoreResult.harmCapApplied,
        harmCapReason:          trustScoreResult.harmCapReason,
        rawScoreBeforeCap:      trustScoreResult.rawScoreBeforeCap,
        penaltyApplied:         trustScoreResult.penaltyApplied,
        
        factCheckStats: {
          totalClaims:      rawClaims.length,
          extractedClaims:  rawClaims.length,
          evaluatedClaims:  trustScoreResult.factCheckStats.evaluatedClaims,
          correct:      trustScoreResult.factCheckStats.correct,
          mostly_correct: trustScoreResult.factCheckStats.mostly_correct,
          incorrect:    trustScoreResult.factCheckStats.incorrect,
          unsupported:  trustScoreResult.factCheckStats.unsupported,
          unverifiable: trustScoreResult.factCheckStats.unverifiable,
          filtered:     filteredCount,
          religious_belief: trustScoreResult.factCheckStats.religious_belief,
          opinion_claim:    trustScoreResult.factCheckStats.opinion_claim,
          satire_claim:     trustScoreResult.factCheckStats.satire_claim,
          verification_timeout: trustScoreResult.factCheckStats.verification_timeout,
          cacheHitRate: hitRate,
          verificationCoverageRatio: trustScoreResult.factCheckStats.verificationCoverageRatio,
        },
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
        
        scoringMethod:  trustScoreResult.scoringMethod,
        diagnostics:      trustScoreResult.diagnostics || [],
        confidenceNotes:  trustScoreResult.confidenceNotes || [],
        vertical:         trustScoreResult.vertical,
        verticalScores:   trustScoreResult.verticalScores,
        reviewTriggered:  trustScoreResult.reviewTriggered,
        reviewReason:     trustScoreResult.reviewReason,
        synthesisTier,
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
        sourceLedger:   trustScoreResult.sourceLedger,
        verifiedAsOf:   trustScoreResult.verifiedAsOf,
        evaluationHealth,                                  // v11.0: Claim reach + evaluation health
        repairSuggestions: trustScoreResult.repairSuggestions, // v11.0: Creator repair path
        consistencyIssues: trustScoreResult.consistencyIssues, // v11.0: Traceable consistency
        verifiedAt:     Date.now(),
        processingTime: Date.now() - t0,

        telemetry: {
          transcriptLoaded: true,
          utteranceCount: (transcript.utterances ?? []).length,
          claimsExtracted: rawClaims.length,
          verificationAttempted: evaluationHealth.attemptedClaims,
          verificationSucceeded: evaluationHealth.evaluatedClaims,
          verificationTimedOut: trustScoreResult.factCheckStats.verification_timeout,
          verificationCompleted: trustScoreResult.factCheckStats.verification_timeout === 0 && evaluationHealth.attemptedClaims > 0,
          claimsVerified: (allVerified.filter(c => ['verified_true', 'mostly_true', 'false_claim', 'misleading', 'disputed'].includes(c.status)).length > 0),
          verificationPipelineCompleted: true,
          summaryGenerated: synthesis.conclusion.label !== "Error",
          consistencyCheckCompleted: true,
          checkedClaimsRatio: trustScoreResult.factCheckStats.checkedClaimsRatio,
          verificationCoverage: trustScoreResult.factCheckStats.verificationCoverageRatio || 0,
        },

        versions: {
          model: "Gemini 2.5 Multi-Model",
          scoring: "v8.5", // v8.5: Path 1 multi-dimensional scoring
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
      };

      // v5.0: Sync conclusion label with honest verdict when no evaluation occurred
      if (result.factCheckStats.evaluatedClaims === 0 && result.conclusion) {
        result.conclusion.label = result.trustLabel;
      }

      // 14. Store result
      await this.storeResult(jobId, userId, result);

      // 15. Emit fact-complete
      const eventData: FactCompleteData = {
        honestRating:     result.trustScore,
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
            honestRating: fallbackResult.trustScore,
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
    const rawResult = this.scoringEngine.calculateInstitutionalTrustScore(
      jobId, userId, transcript, [], 0, "balanced", "medium", "General",
      { extractionError: 'AI_CAPACITY_EXCEEDED' }
    );
    
    return {
      ...rawResult,
      totalClaims: 0,
      evaluatedClaims: 0,
      claims: [],
      chapters: [],
      speakers: [],
      summary: "Strategic analysis unavailable due to AI provider capacity spikes.",
      conclusion: { label: "Unverified – Insufficient Data", text: "Processing error due to AI capacity limit. Please try again later.", confidence: 0.1 },
      viewerNote: "The AI provider is currently at capacity. Analysis is incomplete.",
      latencyMs: { extraction: 0, verification: 0, consistency: 0, synthesis: 0, total: 0 },
      telemetry: { transcriptLoaded: true, claimsExtracted: 0, verificationCompleted: false, summaryGenerated: false },
      stats: { correct: 0, mostly_correct: 0, incorrect: 0, unsupported: 0, unverifiable: 0, filtered: 0, cacheHitRate: 0 }
    } as any;
  }

  private async cacheCheck(
    claims: ExtractedClaim[],
    jobId:  string
  ): Promise<{ cached: VerifiedClaim[]; uncached: ExtractedClaim[] }> {
    try {
      return await this.performanceLayer.checkClaimCache(claims);
    } catch (err) {
      logger.error("[Credibility] Cache lookup failed", { jobId, err });
      await alerting.notify("redis-read-failure", { jobId, context: "checkClaimCache" });
      return { cached: [], uncached: claims };
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
        mostly_correct:             { label: "Mostly Correct", icon: "🟢" },
        incorrect:                  { label: "Incorrect", icon: "❌" },
        outdated:                   { label: "Outdated", icon: "⏳" },
        unsupported:                { label: "Unsupported", icon: "🔍" },
        needs_context:              { label: "Needs Context", icon: "📎" },
        opinion:                    { label: "Opinion", icon: "💭" },
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
        claim:          `${mapped.icon} ${claim.text}`,
        status:         claim.status,
        nature:         claim.nature,
        framing:        claim.framing,
        evidenceLevel:  claim.evidenceLevel,
        ontology:       claim.nature as any, // Legacy field
        severity:       claim.severity,
        severityLabel:  claim.severity ? severityLabels[claim.severity] : undefined,
        whyWrong:       ['incorrect', 'historical_consensus_denial', 'incorrect_citation'].includes(claim.status) ? claim.reasoning : undefined,
        correction:     ['incorrect', 'historical_consensus_denial', 'incorrect_citation'].includes(claim.status)
          ? `Correction: ${claim.reasoning}`
          : undefined,
        sources:        claim.richSources && claim.richSources.length > 0
          ? claim.richSources.map(rs => ({
              title:          rs.title,
              url:            rs.url,
              snippet:        rs.snippet || "",
              relevanceScore: 0.9,
              tier:           rs.tier,       // v5.0
              provenance:     rs.snippet     // v5.0: Source snippet used as provenance
            }))
          : (claim.sources ?? []).map((s: string) => ({
              title:          s,
              url:            s.startsWith("http") ? s : undefined,
              snippet:        "",
              relevanceScore: 0.8,
            })),
        timestampStart: claim.start ?? 0,
        timestampEnd:   claim.end   ?? 0,
        confidence:     claim.verificationConfidence ?? claim.confidence ?? 0.5,
      };
    });
  }

  private async storeResult(
    jobId:  string,
    userId: string,
    result: CredibilityResult
  ): Promise<void> {
    const resultPath = `factChecks/${jobId}/full.json`;
    const bucket = admin.storage().bucket();
    await bucket.file(resultPath).save(
      JSON.stringify(result),
      { metadata: { contentType: "application/json" } }
    );

    const factCheckUrl = `gs://${bucket.name}/${resultPath}`;

    const finalTrustScore = (result.trustScore === null || isNaN(result.trustScore as any)) ? 0 : result.trustScore as number;
    const finalVideoRating = result.videoRating ?? (isNaN(finalTrustScore) ? 0 : Number((finalTrustScore / 10).toFixed(1)));

    // Update video_jobs with the factCheckUrl
    await db().collection("video_jobs").doc(jobId).update({
      "outputs.factCheckUrl": factCheckUrl,
      "outputs.trustScore": finalTrustScore,
      "outputs.videoRating": isNaN(finalVideoRating) ? 0 : finalVideoRating,
      updatedAt: Date.now(),
    });

    // Write lightweight summary document to factChecks collection to trigger channel reputation sync and support governance
    await db().collection("factChecks").doc(jobId).set({
      jobId,
      userId,
      trustScore: finalTrustScore,
      videoRating: isNaN(finalVideoRating) ? 0 : finalVideoRating,
      trustLabel: result.trustLabel || "Low Reliability",
      claimSummary: result.claims?.map(c => ({ claim: c.claim, status: c.status, severity: c.severity })) || [],
      fullResultPath: resultPath,
      factCheckUrl: factCheckUrl,
      isAppealed: false,
      appealStatus: 'none',
      status: 'completed',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

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
   * 🏷 v7: Identity Resolution Bridge
   */
  private async resolveSpeakerIdentities(jobId: string, channelId: string, transcript: any, roles: Record<string, string>) {
    const speakerNames = await this.extractionService.extractSpeakerNames(transcript.text.slice(0, 10000));
    const identities: Record<string, any> = {};

    for (const [label, name] of Object.entries(speakerNames)) {
      const role = roles[label] || "Guest";
      identities[label] = await this.speakerRegistry.resolveIdentity(channelId, name, role as any);
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
}
