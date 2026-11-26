/**
 * 🧠 LAYER 06 — CREDIBILITY ENGINE (INDEPENDENT SYSTEM)
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
  ClaimNature,
  ClaimLedgerSummary,
} from "../types";
import { FactExtractionService }   from "../services/factExtraction";
import { ClaimVerificationService } from "../services/claimVerification";
import { DistributionLayer }       from "./04-distribution";
import { EdgeLayer }               from "./01-edge";
import { aggregationLayer }        from "./09-aggregation";
import { PerformanceLayer }        from "./10-performance";
import { logger }                  from "../utils/logger";
import { alerting }                from "../utils/alerting";
import { isDeepResearchEnabled, PIPELINE_CONFIG }   from "../config";
import { getVertexAI }              from "../utils/ai-client";
import { contentIntentDetector }    from "../services/contentIntentDetector";
import { computeSpeakerBreakdown }  from "../services/speakerBreakdown";
import { SpeakerRegistryService }    from "../services/speakerRegistry";
import { sourceTrustService } from "../services/sourceTrustService";
import { tier0KnowledgeService } from "../services/tier0Knowledge";
import { getAnalysisRepository, AnalysisRepository } from "../services/analysisRepository";
import {
  enforceClosedWorldCitationFirewall,
  isVerifiedRichSource,
  sanitizeReportPayloadForClosedWorld,
} from "../services/urlVerificationService";
import { costEngine } from "../services/cost-engine";
import { isVideoId, safeMergeExistingVideo } from "../../utils/videosCollectionGuard";
import { JobTokenTracker, normalizeToGcsUri, extractCandidateText } from "../utils/ai-utils";
import { SourceAvatarService } from "../services/sourceAvatarService";
import { StreamingClaimProcessor } from "../services/streamingClaimProcessor";
import { VerificationCascadeService } from "../services/verificationCascadeService";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import {
  FactcheckStage,
  FactcheckDiagnosticTracker,
  FactcheckPipelineError,
} from "./credibilityDiagnostics";
import { auditCredibilityReport, ReportQualityAudit } from "../services/reportQualityAudit";
import { applyVerdictGateToReport } from "../services/verdictGate";
import {
  DiarizedUtterance,
  ExtractedClaim as ModernExtractedClaim,
  extractEmpiricalClaims,
} from "../services/factExtraction";
import {
  AdjudicatedClaim,
  EvidenceProvider,
  VerifiedSource,
  verifyClaimsHybrid,
} from "../services/claimVerification";
import { pubmedAdapter } from "../providers/pubmedAdapter";
import { crossrefAdapter } from "../providers/crossrefAdapter";
import { wikipediaAdapter } from "../providers/wikipediaAdapter";
import { worldBankAdapter } from "../providers/worldBankAdapter";
import { fredAdapter } from "../providers/fredAdapter";
import { wikidataAdapter } from "../providers/wikidataAdapter";

const MAX_SNIPPET_CHARS = 650;

interface RawProviderHit {
  title: string;
  uri: string;
  passage: string;
  provider: EvidenceProvider;
  claimId: string;
}

function truncateSnippet(text: string, maxChars = MAX_SNIPPET_CHARS): string {
  const cleaned = text.replace(/\s+/g, " ").trim();
  if (cleaned.length <= maxChars) return cleaned;
  return `${cleaned.slice(0, maxChars - 3)}...`;
}

function getClaimSearchText(c: any): string {
  return (c?.normalizedClaim || c?.claim || c?.text || c?.displayLabel || "").trim();
}

/**
 * Resolves concise English search queries for multilingual / regional claims (e.g. Telugu, Hindi)
 * in a single, fast, ultra-low-cost Gemini Flash-Lite batch call before querying English-indexed
 * encyclopedia and academic databases (Wikipedia, PubMed, Crossref).
 */
async function batchResolveMultilingualSearchQueries(
  claims: Array<ModernExtractedClaim | FilteredClaim>
): Promise<Map<string, string>> {
  const queryMap = new Map<string, string>();
  const nonAsciiClaims = claims.filter((c) => {
    const text = getClaimSearchText(c);
    return /[^\x00-\x7F]/.test(text);
  });

  if (nonAsciiClaims.length === 0) return queryMap;

  // In test environment without Vertex AI, extract bracketed English tokens if present
  if (process.env.NODE_ENV === "test") {
    for (const c of nonAsciiClaims) {
      const text = getClaimSearchText(c);
      const englishMatch = text.match(/\/\s*([A-Za-z0-9\s]+)\]/);
      queryMap.set(c.claimId, englishMatch ? englishMatch[1].trim() : text);
    }
    return queryMap;
  }

  try {
    const ai = getVertexAI();
    const modelId = PIPELINE_CONFIG?.GEMINI_MODELS?.queryDecomposition || "gemini-3.5-flash-lite";
    const model = ai.getGenerativeModel({
      model: modelId,
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.1,
        maxOutputTokens: 1024,
      },
    });

    const prompt = `Convert the following non-English factual claims into concise 3-8 word English search queries suitable for Wikipedia/PubMed search.
Claims to convert:
${nonAsciiClaims.map((c) => `[ID: ${c.claimId}] "${getClaimSearchText(c)}"`).join("\n")}

Respond ONLY with valid JSON:
{
  "queries": [
    { "claimId": "string", "englishQuery": "concise English search keywords" }
  ]
}`;

    const res = await model.generateContent(prompt);
    const text = extractCandidateText(res?.candidates?.[0] || res?.response?.candidates?.[0]) || (typeof res?.text === "string" ? res.text : "");
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      if (Array.isArray(parsed.queries)) {
        for (const q of parsed.queries) {
          if (q.claimId && typeof q.englishQuery === "string" && q.englishQuery.trim()) {
            queryMap.set(q.claimId, q.englishQuery.trim());
          }
        }
      }
    }
  } catch (err: any) {
    logger.warn("[Credibility] Multilingual query decomposition fallback", { err: err?.message });
  }

  return queryMap;
}

/**
 * Layer 06C: Queries PubMed, Crossref, and Wikipedia in parallel for uncached claims,
 * deduplicates URIs, and builds a closed-world VerifiedSource[] catalog with passage snippets.
 */
export async function gatherLayer06CEvidence(
  claims: Array<ModernExtractedClaim | FilteredClaim>
): Promise<VerifiedSource[]> {
  const verifiable = claims.filter((c) => (c as any).requiresVerification !== false);
  if (verifiable.length === 0) return [];

  const multilingualQueries = await batchResolveMultilingualSearchQueries(verifiable);

  const retrievalTasks = verifiable.flatMap((claim) => {
    const claimText = getClaimSearchText(claim);
    const claimDomain = (claim as any).domain || "";
    const englishQuery = multilingualQueries.get(claim.claimId) || claimText;

    const tasks: Promise<RawProviderHit[]>[] = [
      wikipediaAdapter.searchPassages(englishQuery, { limit: 2 }).then((hits) =>
        hits.map((h) => ({
          title: h.title,
          uri: h.url,
          passage: h.extract,
          provider: "WIKIPEDIA" as EvidenceProvider,
          claimId: claim.claimId,
        }))
      ),
    ];

    // If query was non-English and we have an English query, also attempt regional language search if relevant
    if (englishQuery !== claimText && /[^\x00-\x7F]/.test(claimText)) {
      tasks.push(
        wikipediaAdapter.searchPassages(claimText, { limit: 1 }).then((hits) =>
          hits.map((h) => ({
            title: h.title,
            uri: h.url,
            passage: h.extract,
            provider: "WIKIPEDIA" as EvidenceProvider,
            claimId: claim.claimId,
          }))
        )
      );
    }

    // Route biomedical and quantitative claims to PubMed & Crossref
    if (
      claimDomain === "HEALTH_MEDICAL" ||
      /\d+%|\bstudy\b|\btrial\b|\bclinical\b|\bvaccine\b|\bdrug\b|\bdisease\b/i.test(claimText) ||
      /\d+%|\bstudy\b|\btrial\b|\bclinical\b|\bvaccine\b|\bdrug\b|\bdisease\b/i.test(englishQuery)
    ) {
      tasks.push(
        pubmedAdapter.searchAbstracts(englishQuery, { limit: 2 }).then((hits) =>
          hits.map((h) => ({
            title: h.title,
            uri: `https://pubmed.ncbi.nlm.nih.gov/${h.pmid}/`,
            passage: h.abstractText,
            provider: "PUBMED" as EvidenceProvider,
            claimId: claim.claimId,
          }))
        ),
        crossrefAdapter.searchWorks(englishQuery, { limit: 2 }).then((hits) =>
          hits.map((h) => ({
            title: h.title,
            uri: h.doiUrl,
            passage: h.abstract || h.subtitle || h.title,
            provider: "CROSSREF" as EvidenceProvider,
            claimId: claim.claimId,
          }))
        )
      );
    }

    // Route macroeconomic and quantitative financial claims to World Bank and FRED
    if (
      claimDomain === "MACROECONOMICS_FINANCE" ||
      /\b(inflation|cpi|gdp|unemployment|interest rate|fed funds|treasury|recession)\b/i.test(claimText) ||
      /\b(inflation|cpi|gdp|unemployment|interest rate|fed funds|treasury|recession)\b/i.test(englishQuery)
    ) {
      tasks.push(
        worldBankAdapter.searchIndicators(englishQuery).then((hits) =>
          hits.map((h) => ({
            title: h.title,
            uri: h.url,
            passage: h.passage,
            provider: "WORLDBANK" as EvidenceProvider,
            claimId: claim.claimId,
          }))
        ),
        fredAdapter.searchObservations(englishQuery).then((hits) =>
          hits.map((h) => ({
            title: h.title,
            uri: h.url,
            passage: h.passage,
            provider: "FRED" as EvidenceProvider,
            claimId: claim.claimId,
          }))
        )
      );
    }

    // Route settled general knowledge / biographical / geographic claims to Wikidata
    if (
      claimDomain === "GENERAL_FACT" ||
      claimDomain === "ELECTIONS_GOVERNANCE" ||
      (claim as any).requiresLiveWeb === false
    ) {
      tasks.push(
        wikidataAdapter.searchEntities(englishQuery).then((hits) =>
          hits.map((h) => ({
            title: h.title,
            uri: h.url,
            passage: h.passage,
            provider: "WIKIDATA" as EvidenceProvider,
            claimId: claim.claimId,
          }))
        )
      );
    }

    return tasks;
  });

  const settled = await Promise.allSettled(retrievalTasks);
  const byUri = new Map<string, VerifiedSource>();

  for (const outcome of settled) {
    if (outcome.status !== "fulfilled") continue;
    for (const hit of outcome.value) {
      if (!hit.uri || !hit.passage) continue;

      const existing = byUri.get(hit.uri);
      if (existing) {
        if (existing.claimIds && !existing.claimIds.includes(hit.claimId)) {
          existing.claimIds.push(hit.claimId);
        }
        continue;
      }

      byUri.set(hit.uri, {
        evidenceId: `E${byUri.size + 1}`,
        title: hit.title,
        uri: hit.uri,
        snippet: truncateSnippet(hit.passage),
        sourceProvider: hit.provider,
        claimIds: [hit.claimId],
      });
    }
  }

  return Array.from(byUri.values());
}

export async function runLayer06CredibilityPipeline(params: {
  videoId: string;
  utterances: DiarizedUtterance[];
  requireUsResidency?: boolean;
}): Promise<AdjudicatedClaim[]> {
  const { videoId, utterances, requireUsResidency = false } = params;

  // 06A: Tier 1 Extraction (Gemini 3.5 Flash-Lite, thinkingLevel: MINIMAL, AssemblyAI-bound)
  const extractedClaims = await extractEmpiricalClaims(
    videoId,
    utterances,
    requireUsResidency
  );

  // 06B: Tier-0 Deterministic Cache Pre-Filter ($0.00 LLM & $0.00 Grounding cost)
  const { cachedAdjudications, uncachedClaims } =
    await tier0KnowledgeService.partitionClaims(extractedClaims);

  if (uncachedClaims.length === 0) {
    return cachedAdjudications;
  }

  // 06C: Multi-Source Evidence Retrieval (PubMed, Crossref, Wikipedia)
  const preRetrievedEvidence = await gatherLayer06CEvidence(uncachedClaims);

  // 06D–F: Hybrid Verification (omits paid Vertex googleSearch when preRetrievedEvidence covers batch)
  const freshAdjudications = await verifyClaimsHybrid(videoId, uncachedClaims, {
    preRetrievedEvidence,
    requireUsResidency,
  });

  // Persist verified outcomes back to Tier-0 cache for future 30-day reuse
  await tier0KnowledgeService.upsertVerifiedClaims(uncachedClaims, freshAdjudications);

  return [...cachedAdjudications, ...freshAdjudications];
}

const db = () => admin.firestore();

/**
 * Adds `transcriptExcerpt` (the words actually spoken between a claim's start and end,
 * ±2 s) to each claim. Utterance and claim timestamps share the same unit (ms).
 */
function attachTranscriptExcerpts<T extends { start?: number; end?: number }>(claims: T[], utterances: Array<{ text?: string; start?: number; end?: number }>): T[] {
  if (!Array.isArray(utterances) || utterances.length === 0) return claims;
  const PAD = 2000;
  return claims.map((c) => {
    if (typeof c.start !== "number") return c;
    const from = c.start - PAD;
    const to = (typeof c.end === "number" && c.end > c.start ? c.end : c.start + 10000) + PAD;
    const words = utterances
      .filter((u) => typeof u.start === "number" && typeof u.end === "number" && (u.end as number) >= from && (u.start as number) <= to)
      .map((u) => String(u.text || "").trim())
      .filter(Boolean)
      .join(" ");
    return words ? ({ ...c, transcriptExcerpt: words.slice(0, 2000) } as T) : c;
  });
}

/**
 * Grades a finished report and records the outcome. Never throws and never blocks
 * publishing: a quality problem must be visible to the team, not hide the report.
 *  - Structured log line `TRUTHWORLD_CREDIBILITY_QUALITY` → create a log-based metric
 *    on jsonPayload.grade / jsonPayload.checkIds and alert when FAIL rate rises.
 *  - Firestore `credibility_quality_audits/{jobId}` → review queue for FAIL/WARN reports.
 */
async function recordReportQualityAudit(
  jobId: string,
  videoId: string | undefined,
  report: any
): Promise<ReportQualityAudit | undefined> {
  try {
    const audit = auditCredibilityReport(report);
    const logPayload = {
      event: "TRUTHWORLD_CREDIBILITY_QUALITY",
      jobId,
      videoId,
      grade: audit.grade,
      checkIds: audit.checks.map((c) => `${c.id}:${c.severity}`),
      ...audit.metrics,
    };
    if (audit.grade === "FAIL") {
      logger.warn("[CredibilityQuality] Report failed output quality audit", logPayload);
    } else {
      logger.info("[CredibilityQuality] Report output quality audit", logPayload);
    }
    await db().collection("credibility_quality_audits").doc(jobId).set({
      ...audit,
      jobId,
      videoId: videoId || null,
      reviewStatus: audit.grade === "PASS" ? "not_required" : "pending",
      updatedAt: Date.now(),
      // A freshly published report has freshly checked evidence; the daily
      // evidenceFreshnessSweep re-checks the oldest ones first.
      lastEvidenceCheckAt: Date.now(),
    }, { merge: true }).catch((err) => {
      logger.warn("[CredibilityQuality] Could not persist quality audit (non-fatal)", { jobId, err: String(err) });
    });
    return audit;
  } catch (err) {
    logger.warn("[CredibilityQuality] Quality audit skipped (non-fatal)", { jobId, err: String(err) });
    return undefined;
  }
}

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

export async function isBreakerTrippedAsync(): Promise<boolean> {
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

export function isBreakerTripped(): boolean {
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
  private readonly distribution:        DistributionLayer;
  private readonly performanceLayer:    PerformanceLayer;
  private readonly speakerRegistry:     SpeakerRegistryService;   // v7
  private readonly analysisRepository:  AnalysisRepository;

  constructor(geminiApiKey: string, analysisRepository?: AnalysisRepository) {
    this.extractionService   = new FactExtractionService(geminiApiKey);
    this.verificationService = new ClaimVerificationService(geminiApiKey, 0.6);
    this.distribution        = new DistributionLayer();
    this.performanceLayer    = new PerformanceLayer();
    this.speakerRegistry     = new SpeakerRegistryService();
    this.analysisRepository  = analysisRepository || getAnalysisRepository();
  }

  /**
   * Syncs pipeline execution progress across EdgeLayer, credibility_jobs, and videos documents.
   */
  private async syncCredibilityProgress(
    jobId: string,
    targetVideoId: string | undefined,
    prog: number,
    stageStatus: "running" | "completed" | "failed" = "running",
    extra: Record<string, any> = {}
  ): Promise<void> {
    await EdgeLayer.updateStage(jobId, "credibility", {
      progress: prog,
      status: stageStatus,
      ...extra,
    });
    await EdgeLayer.upsertCredibilityJob(jobId, {
      progress: prog,
      status: stageStatus,
      ...extra,
    });
    if (targetVideoId) {
      const videoUpdatePayload: Record<string, any> = {
        factCheckProgress: prog,
        factCheckStatus: stageStatus,
        stages: {
          credibility: {
            progress: prog,
            status: stageStatus,
            updatedAt: Date.now(),
            ...extra,
          },
        },
        updatedAt: Date.now(),
      };
      if (stageStatus === "completed") {
        videoUpdatePayload.factCheckCompletedAt = admin.firestore.FieldValue.serverTimestamp();
      }
      db()
        .collection("videos")
        .doc(targetVideoId)
        .set(videoUpdatePayload, { merge: true })
        .catch((err) => {
          logger.warn("[Credibility] Failed to mirror progress to video doc", {
            targetVideoId,
            err: String(err),
          });
        });
    }
  }

  /**
   * Stage 1: Pre-flight checks & Idempotency Gate
   */
  private async executeStage01Preflight(
    jobId: string,
    userId: string,
    executionPlan: ExecutionPlan,
    eventId: string,
    traceId?: string
  ): Promise<{ shouldExitEarly: boolean; existingResult?: CredibilityResult }> {
    const status = await this.distribution.checkAndMarkEventId(eventId, jobId);
    if (status === "COMPLETED") {
      logger.info("[Credibility] Duplicate — loading existing", { jobId });
      const existing = await this.loadExistingResult(jobId);
      return { shouldExitEarly: true, existingResult: existing || ({} as CredibilityResult) };
    }
    if (status === "PROCESSING") {
      logger.info("[Credibility] Already processing — exiting gracefully", { jobId });
      return { shouldExitEarly: true, existingResult: {} as any };
    }

    if (await isBreakerTrippedAsync()) {
      logger.warn("[Credibility] Circuit breaker tripped; upstream AI providers degraded", { jobId, traceId });
      throw new Error("CIRCUIT_BREAKER_ACTIVE: Credibility engine paused due to upstream provider outages");
    }

    const t0 = Date.now();
    logger.info("[Credibility] Starting independent Credibility pipeline", { jobId, traceId });
    await EdgeLayer.upsertCredibilityJob(jobId, {
      userId,
      ...(executionPlan.videoId ? { videoId: executionPlan.videoId } : {}),
      executionPlan,
      status: "running",
      progress: 5,
      startedAt: t0,
    });

    return { shouldExitEarly: false };
  }

  /**
   * Stage 2: Resilient Input & Media Context Resolution
   */
  private async executeStage02InputResolution(
    jobId: string,
    executionPlan: ExecutionPlan,
    providedVideoUrl?: string
  ): Promise<{
    targetVideoId: string;
    jobData: Record<string, any>;
    videoContext: { title: string; description: string; channelTitle: string };
    channelId: string;
    transcript: any;
    hasTranscript: boolean;
  }> {
    let jobDoc = await db().collection("video_jobs").doc(jobId).get();
    let jobData = jobDoc.exists ? jobDoc.data() : {};
    const targetVideoId = (executionPlan as any).videoId || jobData?.videoId || (jobData?.linkedVideoIds?.[0]) || jobId;

    let videoTitle = jobData?.title || "";
    let videoDescription = jobData?.description || "";
    let channelTitle = jobData?.channelTitle || jobData?.channelName || "";
    let channelId = jobData?.channelId || "";

    try {
      const videoSnap = await db().collection("videos").doc(targetVideoId).get();
      if (videoSnap.exists) {
        const vData = videoSnap.data() || {};
        if (!jobDoc.exists && vData.jobId) {
          const originalJobDoc = await db().collection("video_jobs").doc(vData.jobId).get();
          if (originalJobDoc.exists) {
            jobDoc = originalJobDoc;
            jobData = originalJobDoc.data() || {};
          }
        }
        if (!videoTitle) videoTitle = vData.title || "";
        if (!videoDescription) videoDescription = vData.description || "";
        if (!channelTitle) channelTitle = vData.channelTitle || vData.channelName || "";
        if (!channelId) channelId = vData.channelId || "";
      }
    } catch (_) {}

    const videoContext = {
      title: videoTitle,
      description: videoDescription,
      channelTitle: channelTitle,
    };

    let transcript: any = null;
    let hasTranscript = false;
    try {
      transcript = await this.loadTranscript(jobId, targetVideoId);
      if (transcript && Array.isArray(transcript.utterances) && transcript.utterances.length > 0) {
        hasTranscript = true;
      }
    } catch {
      logger.info("[Credibility] Transcript document not present — using Google Cloud multimodal media extraction", { jobId });
    }

    return {
      targetVideoId,
      jobData: jobData || {},
      videoContext,
      channelId,
      transcript,
      hasTranscript,
    };
  }

  /**
   * Stage 3: Rate Limiting & Safety Quota Enforcement
   */
  private async executeStage03QuotaAndSafety(
    userId: string,
    channelId: string,
    jobData: Record<string, any>,
    executionPlan: ExecutionPlan
  ): Promise<{ isChannelVerified: boolean; effectiveMaxClaims: number }> {
    const isChannelVerified = (jobData?.isChannelTrusted === true) ||
      (executionPlan.channelType === "custom") ||
      ((executionPlan as any).channelTier === "partner") ||
      ((executionPlan as any).channelTier === "enterprise");

    if (!isChannelVerified && userId) {
      try {
        const todayKey = new Date().toISOString().split("T")[0];
        const rateLimitRef = db().collection("rate_limits").doc(`credibility_${userId}_${todayKey}`);
        const rateLimitSnap = await rateLimitRef.get();
        const currentRuns = rateLimitSnap.exists ? Number(rateLimitSnap.data()?.runs || 0) : 0;
        if (currentRuns >= 3) {
          logger.warn("[Credibility] Unverified channel exceeded daily free fact-checking quota (max 3/day). Enforcing standard triage tier.", { userId, channelId, currentRuns });
          executionPlan.factCheckTier = "standard";
        } else {
          await rateLimitRef.set({
            userId,
            channelId: channelId || "unknown",
            runs: admin.firestore.FieldValue.increment(1),
            lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      } catch (rlErr: any) {
        logger.warn("[Credibility] Rate limit check non-fatal warning", { err: rlErr?.message });
      }
    }

    const defaultMax = isChannelVerified ? 200 : 30;
    const configuredMax = typeof executionPlan.maxClaims === 'number' && executionPlan.maxClaims > 0
      ? (isChannelVerified ? executionPlan.maxClaims : Math.min(executionPlan.maxClaims, 30))
      : defaultMax;
    const effectiveMaxClaims = configuredMax;

    return { isChannelVerified, effectiveMaxClaims };
  }

  /**
   * Stage 4: Claim Extraction, Domain Detection & Content Intent Analysis
   */
  private async executeStage04ClaimExtraction(
    jobId: string,
    targetVideoId: string,
    channelId: string,
    jobData: Record<string, any>,
    videoContext: { title: string; description: string; channelTitle: string },
    executionPlan: ExecutionPlan,
    hasTranscript: boolean,
    transcriptInput: any,
    providedVideoUrl?: string
  ): Promise<{
    rawClaims: ExtractedClaim[];
    domainInfo: any;
    contentIntent: any;
    speakerIdentities: any;
    videoDurationSec: number;
    extractionPartial: boolean;
    transcript: any;
  }> {
    const deepResearchActive = isDeepResearchEnabled(executionPlan.synthesisTier || 'standard') || executionPlan.factCheckTier === 'full_ground' || (executionPlan.factCheckTier as string) === 'deep';
    let rawClaims: ExtractedClaim[] = [];
    let domainInfo: any = null;
    let speakerIdentities: any = {};
    let videoDurationSec = 120;
    let extractionPartial = false;
    let transcript = transcriptInput;

    if (hasTranscript) {
      const rawDuration = transcript.duration;
      const fallbackDurationSec = (transcript.utterances?.length > 0)
        ? Math.max(...transcript.utterances.map((u: any) => u.end || 0)) / 1000
        : 120;
      videoDurationSec = rawDuration > 0 ? rawDuration : fallbackDurationSec;

      const extractionConcurrency = 5;
      const extractionBudgetMs = deepResearchActive ? 280_000
        : videoDurationSec >= 1200 ? 300_000
        : videoDurationSec >= 600 ? 240_000
        : videoDurationSec >= 180 ? 160_000
        : 120_000;

      const [detectedDomain, rawClaimsResult, resolvedSpeakers] = await Promise.all([
        this.extractionService.detectDomainAndStance(transcript.utterances ?? [], videoContext.title).catch((err: any) => {
          logger.error("[Credibility] Domain detection failed, using safe defaults", { jobId, error: err?.message });
          return { domain: "General", stance: "Mixed", cautionLevel: "medium" as const, isLaunchNews: false, primaryIntent: "educational", isSensitive: false };
        }),
        Promise.race([
          this.extractionService.extractClaims(jobId, transcript, 45_000, extractionConcurrency, videoContext)
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
        this.resolveSpeakerIdentities(jobId, channelId || jobData?.channelId || "unknown", transcript, {}).catch(() => ({}))
      ]);

      domainInfo = detectedDomain;
      rawClaims = rawClaimsResult.claims;
      extractionPartial = rawClaimsResult.partial;
      speakerIdentities = resolvedSpeakers;

      if (rawClaims.length === 0 && transcript.utterances && transcript.utterances.length > 0) {
        logger.warn("[Credibility] Chunked extraction returned 0 claims — attempting emergency fallback extraction pass", { jobId });
        try {
          const emergencyClaims = await this.extractionService.extractClaimsFromChunk(
            jobId,
            transcript.utterances.slice(0, 100),
            0,
            videoContext
          );
          if (emergencyClaims && emergencyClaims.length > 0) {
            logger.info(`[Credibility] Emergency fallback extraction recovered ${emergencyClaims.length} claims`, { jobId });
            rawClaims = emergencyClaims;
            extractionPartial = false;
          }
        } catch (fallbackErr) {
          logger.error("[Credibility] Emergency fallback extraction failed", { jobId, error: (fallbackErr as any)?.message });
        }
      }
    } else {
      logger.info("[Credibility] Stage 2: Direct multimodal claim extraction from media via Google Cloud Vertex AI", { jobId });
      let mediaUrl = providedVideoUrl || jobData?.videoUrl || jobData?.originalUrl || jobData?.filePath || "";
      if (!mediaUrl) {
        const videoSnap = await db().collection("videos").doc(targetVideoId).get();
        if (videoSnap.exists) {
          const vData = videoSnap.data() || {};
          mediaUrl = vData.originalUrl || vData.media?.originalVideoUrl || vData.videoUrl || "";
        }
      }

      const gcsUri = normalizeToGcsUri(mediaUrl);
      if (!gcsUri) {
        logger.warn("[Credibility] No valid GCS media URI or transcript available for job", { jobId, mediaUrl });
        throw new Error(`Cannot run credibility pipeline for ${jobId}: no valid video media URL or transcript found`);
      }

      const mimeType = mediaUrl.endsWith(".webm") ? "video/webm" : "video/mp4";
      const mediaExtraction = await this.extractionService.extractClaimsFromMedia(jobId, gcsUri, mimeType, videoContext.title);
      rawClaims = mediaExtraction.claims;
      domainInfo = mediaExtraction.domainInfo;
      videoDurationSec = jobData?.duration || 120;

      transcript = {
        duration: videoDurationSec,
        language: domainInfo.detectedLanguage || "en",
        utterances: rawClaims.map((c, idx) => ({
          speaker: c.speaker || "Speaker",
          text: c.text,
          start: typeof c.start === "number" ? c.start : idx * 5000,
          end: typeof c.end === "number" ? c.end : (idx + 1) * 5000,
        })),
        speakers: ["Speaker"],
        speakerCount: 1,
      };

      speakerIdentities = await this.resolveSpeakerIdentities(jobId, jobData?.channelId || "unknown", transcript, {}).catch(() => ({}));
    }

    // Attach the verbatim transcript words spoken at each claim's timestamp. The verdict
    // gate uses them to prove an "Opinion & Belief" label with a real quote from the video.
    rawClaims = attachTranscriptExcerpts(rawClaims, transcript.utterances ?? []);

    const contentIntent = contentIntentDetector.detectIntent(
      transcript.utterances ?? [],
      domainInfo
    );

    return {
      rawClaims,
      domainInfo,
      contentIntent,
      speakerIdentities,
      videoDurationSec,
      extractionPartial,
      transcript,
    };
  }

  /**
   * Stage 5: Claim Classification, Ranking & Real-time Stream Registration
   */
  private async executeStage05RankingAndStreaming(
    targetVideoId: string,
    rawClaims: ExtractedClaim[],
    effectiveMaxClaims: number,
    extractionPartial: boolean,
    jobId: string,
    videoDurationSec: number
  ): Promise<{
    topClaims: FilteredClaim[];
    filteredCount: number;
    filteringReasons: string[];
  }> {
    const filteringReasons: string[] = [];
    const ranked = this.classifyAndRank(rawClaims);
    const topClaims: FilteredClaim[] = ranked.slice(0, effectiveMaxClaims).map((c, idx) => ({
      ...c,
      claimId: (c as any).claimId || StreamingClaimProcessor.generateClaimOccurrenceId(c.text, typeof c.start === "number" ? c.start : idx * 3000),
    }));
    const filteredCount = ranked.length - topClaims.length;

    if (filteredCount > 0) {
      filteringReasons.push(`${filteredCount} claims exceeded system safety ceiling (Max: ${effectiveMaxClaims})`);
    }

    logger.info("[Credibility] Claims processed for complete verification", {
      jobId, total: ranked.length, kept: topClaims.length, filtered: filteredCount, maxClaims: effectiveMaxClaims, videoDurationSec
    });

    await StreamingClaimProcessor.registerExtractedClaims(targetVideoId, topClaims).catch((err) => {
      logger.warn("[Credibility] Non-fatal error registering initial claims stream", { err: err?.message });
    });

    if (topClaims.length === 0) {
      if (extractionPartial) {
        logger.error("[Credibility] Claim extraction timed out or failed without recovering claims — failing stage for retry", { jobId });
        throw new ExtractionError(
          "CLAIM_EXTRACTION_FAILED",
          `Claim extraction timed out or encountered unrecoverable errors for job ${jobId}`
        );
      }
      logger.info("[Credibility] Video evaluated with zero extracted claims — marking as non-empirical content", { jobId });
    }

    return {
      topClaims,
      filteredCount,
      filteringReasons,
    };
  }

  /**
   * Stage 6: Harvest & Validate Contextual Sources
   */
  private async executeStage06HarvestSources(
    targetVideoId: string,
    jobId: string,
    jobData: Record<string, any>,
    videoContext: { title: string; description: string; channelTitle: string },
    domainInfo: any
  ): Promise<Record<string, any>> {
    await sourceTrustService.loadRegistry().catch(() => {});

    const rawProvidedSources: string[] = Array.isArray(jobData?.providedSources)
      ? jobData.providedSources
      : (Array.isArray(jobData?.features?.providedSources) ? jobData.features.providedSources : []);
    let disputeSources: string[] = [];

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
            const rawUrl = data.url.trim();
            if (rawUrl.length > 2048) return;
            if (/[\x00-\x1f\x7f]/.test(rawUrl)) return;
            try {
              const parsed = new URL(rawUrl);
              if (parsed.protocol !== 'https:') return;
              communitySources.push(parsed.href);
            } catch {
              return;
            }
          }
        });
      }
    } catch (e) {
      logger.warn("[Credibility] Could not fetch community claim_sources", { jobId, targetVideoId, error: (e as any)?.message });
    }

    // Reviewer-approved community/creator evidence lives in the top-level `claim_sources`
    // review queue (see communityEvidenceService). Only approved links are used; pending
    // or rejected submissions never reach the fact-check.
    try {
      const approvedSnap = await db().collection("claim_sources").where("videoId", "==", targetVideoId).get();
      approvedSnap.docs.forEach((doc) => {
        const data = doc.data() || {};
        if (data.status !== "approved_pending_rerun" && data.status !== "applied") return;
        const urls: string[] = Array.isArray(data.urls) ? data.urls : data.url ? [data.url] : [];
        for (const raw of urls) {
          try {
            const parsed = new URL(String(raw).trim());
            if (parsed.protocol === "https:" && !communitySources.includes(parsed.href)) communitySources.push(parsed.href);
          } catch {
            continue;
          }
        }
      });
    } catch (e) {
      logger.warn("[Credibility] Could not fetch approved community evidence", { jobId, targetVideoId, error: (e as any)?.message });
    }

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

    return {
      videoTitle: videoContext.title,
      videoDescription: videoContext.description,
      channelTitle: videoContext.channelTitle,
      topicContext: domainInfo?.domain || "General",
      providedSources: creatorProvidedSources,
    };
  }

  /**
   * Stage 7: Execute Four-Tier Cascade Verification with Fallback Recovery
   */
  private async executeStage07CascadeVerification(
    targetVideoId: string,
    jobId: string,
    topClaims: FilteredClaim[],
    domainInfo: any,
    cascadeOptions: Record<string, any>,
    videoContext: { title: string; description: string; channelTitle: string }
  ): Promise<{ allVerified: VerifiedClaim[]; hitRate: number; tVerificationEnd: number }> {
    let allVerified: VerifiedClaim[] = [];
    if (topClaims.length > 0) {
      try {
        allVerified = await VerificationCascadeService.executeCascade(
          targetVideoId,
          topClaims,
          domainInfo?.domain || "General",
          cascadeOptions
        );
      } catch (cascadeErr: any) {
        logger.error("[Credibility] VerificationCascadeService threw error — initiating fast knowledge recovery fallback", {
          jobId,
          error: cascadeErr?.message,
        });
        allVerified = await this.verificationService.verifyBatchWithFastKnowledge(topClaims as any, jobId, {
          videoTitle: videoContext.title,
          videoDescription: videoContext.description,
          channelTitle: videoContext.channelTitle,
        });
      }

      if (allVerified.length === 0) {
        logger.warn("[Credibility] Cascade returned 0 claims — running fast knowledge recovery", { jobId });
        allVerified = await this.verificationService.verifyBatchWithFastKnowledge(topClaims as any, jobId, {
          videoTitle: videoContext.title,
          videoDescription: videoContext.description,
          channelTitle: videoContext.channelTitle,
        });
      }
    }

    const tVerificationEnd = Date.now();

    const stillTimedOut = allVerified.filter(c =>
      c.status === 'verification_timeout' || (c as any).failureReason === 'timeout'
    );
    if (stillTimedOut.length > 0) {
      logger.warn(`[Credibility] Final Recovery Sweep: ${stillTimedOut.length} claims still timed out`, { jobId });
      try {
        const recovered = await this.verificationService.verifyBatchWithFastKnowledge(stillTimedOut as any, jobId, {
          videoTitle: videoContext.title,
          videoDescription: videoContext.description,
          channelTitle: videoContext.channelTitle,
        });
        for (const r of recovered) {
          const idx = allVerified.findIndex(c => c.claimId === r.claimId);
          if (idx !== -1) allVerified[idx] = r;
        }
        logger.info(`[Credibility] Final Recovery Sweep succeeded: ${recovered.length} claims recovered`, { jobId });
      } catch (sweepErr) {
        logger.error(`[Credibility] Final Recovery Sweep failed`, { jobId, error: (sweepErr as any)?.message });
      }
    }

    await StreamingClaimProcessor.publishResolvedClaims(targetVideoId, allVerified).catch(() => {});

    const cacheHitsCount = allVerified.filter(c => c.verificationMethod === 'cache_hit').length;
    const hitRate = topClaims.length > 0 ? cacheHitsCount / topClaims.length : 0;
    await this.trackAndAlertHitRate(jobId, cacheHitsCount, topClaims.length);

    return { allVerified, hitRate, tVerificationEnd };
  }

  /**
   * Stage 8: Evaluation Health Tracking & Verifiable Claim Ledger Assembly
   */
  private async executeStage08CompileLedgerAndExplainability(
    jobId: string,
    rawClaims: ExtractedClaim[],
    topClaims: FilteredClaim[],
    allVerified: VerifiedClaim[],
    filteredCount: number,
    filteringReasons: string[],
    hitRate: number
  ): Promise<{
    evaluationHealth: any;
    factCheckStats: any;
    claimLedger: ClaimLedgerSummary;
    explainableResults: ExplainabilityResult[];
    confirmedCount: number;
    disputedCount: number;
    falseCount: number;
    unprovenCount: number;
    contextualCount: number;
    highestSeverityVerdict: ClaimLedgerSummary['highestSeverityVerdict'];
  }> {
    const factualRoutedCount = allVerified.filter(c => 
      c.status !== 'opinion_claim' && c.status !== 'religious_belief' && c.status !== 'satire_claim' && (c.status as string) !== 'rhetorical_exaggeration'
    ).length;
    const evaluatedClaimsCount = allVerified.filter(c => 
      c.status !== 'opinion_claim' && c.status !== 'religious_belief' && c.status !== 'satire_claim' && (c.status as string) !== 'rhetorical_exaggeration' && !c.timedOutAt && (c as any).failureReason !== 'timeout' && c.status !== 'unproven'
    ).length;
    const attemptedClaimsCount = factualRoutedCount;
    const claimReachRatio = topClaims.length > 0 ? factualRoutedCount / topClaims.length : 0;
    const evaluationRatio = factualRoutedCount > 0 ? evaluatedClaimsCount / factualRoutedCount : 0;
    const healthStatus = topClaims.length === 0 ? 'healthy' as const
      : claimReachRatio >= 0.6 && evaluationRatio >= 0.5 ? 'healthy' as const
      : claimReachRatio >= 0.3 || evaluationRatio >= 0.3 ? 'degraded' as const
      : 'critical' as const;

    if (healthStatus === 'critical' && topClaims.length >= 3) {
      logger.error(`[Credibility] CRITICAL: Low claim reach — ${factualRoutedCount}/${topClaims.length} reached verification, ${evaluatedClaimsCount} evaluated`, {
        jobId, claimReachRatio, evaluationRatio, totalExtracted: rawClaims.length,
        afterFilter: topClaims.length, factual: factualRoutedCount, opinions: topClaims.length - factualRoutedCount,
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

    const confirmedCount = allVerified.filter(c => c.status === 'verified_true' || c.status === 'mostly_true' || c.status === 'correct' || c.status === 'mostly_correct').length;
    const disputedCount = allVerified.filter(c => c.status === 'disputed' || c.status === 'inconclusive' || c.status === 'limited_support' || c.status === 'contested_interpretation' || c.status === 'misleading' || c.status === 'needs_context' || c.status === 'rhetorical_exaggeration' || c.status === 'partially_true' || c.status === 'outdated').length;
    const falseCount = allVerified.filter(c => c.status === 'false_claim' || c.status === 'incorrect' || c.status === 'verified_false' || c.status === 'historical_consensus_denial' || c.status === 'incorrect_citation').length;
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

    const explainableResults = this.buildExplainability(allVerified);

    return {
      evaluationHealth,
      factCheckStats,
      claimLedger,
      explainableResults,
      confirmedCount,
      disputedCount,
      falseCount,
      unprovenCount,
      contextualCount,
      highestSeverityVerdict,
    };
  }

  /**
   * Stage 9: Persist Verified Claims Draft & Trigger Async Synthesis
   */
  private async executeStage09PersistDraftAndTriggerSynthesis(
    jobId: string,
    userId: string,
    targetVideoId: string,
    executionPlan: ExecutionPlan,
    transcript: any,
    allVerified: VerifiedClaim[],
    rawClaims: ExtractedClaim[],
    filteredCount: number,
    domainInfo: any,
    contentIntent: any,
    evaluationHealth: any,
    speakerIdentities: any,
    t0: number
  ): Promise<{
    synthesis: SynthesisResult;
    speakerBreakdowns: any[];
    synthesisTier: "standard" | "deep" | "podcast";
  }> {
    const expectedCount = executionPlan.expectedSpeakerCount;
    const speakerCount = transcript.speakerCount || (transcript.speakers?.length) || 1;
    let pipelineMode: "solo" | "multi" | "debate" = "solo";
    if (expectedCount === "4+" || executionPlan.contentFormat === "debate" || speakerCount >= 4) {
      pipelineMode = "debate";
    } else if (["2-3"].includes(expectedCount || "") || ["interview", "podcast"].includes(executionPlan.contentFormat || "") || speakerCount >= 2) {
      pipelineMode = "multi";
    }

    const durationSeconds = transcript.duration ?? 0;
    let synthesisTier: "standard" | "deep" | "podcast" = "standard";
    if (executionPlan.factCheckTier === "full_ground" || executionPlan.synthesisTier === "deep" || durationSeconds > 1800 || pipelineMode === "debate" || executionPlan.contentFormat === "debate") {
      synthesisTier = "deep";
    } else if (pipelineMode === "multi" || executionPlan.contentFormat === "podcast") {
      synthesisTier = "podcast";
    }

    logger.info("[Credibility] Creator-Informed Adaptive Orchestration", { 
      jobId, speakerCount, expectedCount, pipelineMode, synthesisTier 
    });

    const draftPayload: Record<string, any> = {
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
      videoId: targetVideoId,
      pipelineStartMs: t0,
      savedAt: Date.now(),
    };

    const serializedClaims = JSON.stringify(allVerified);
    if (serializedClaims.length > 500_000) {
      const bucket = admin.storage().bucket();
      const draftPath = `factChecks/${jobId}/draft_claims.json`;
      await bucket.file(draftPath).save(serializedClaims, { contentType: "application/json" });
      const draftGcsUri = `gs://${bucket.name}/${draftPath}`;
      await db().collection("credibility_drafts").doc(jobId).set({
        ...draftPayload,
        draftGcsUri,
      });
      logger.info("[Credibility] Large verified claims draft offloaded to GCS", { jobId, draftGcsUri, size: serializedClaims.length });
    } else {
      await db().collection("credibility_drafts").doc(jobId).set({
        ...draftPayload,
        verifiedClaims: allVerified,
      });
      logger.info("[Credibility] Verified claims draft persisted", { jobId });
    }

    const hasVerifiedClaims = allVerified.length > 0;
    const initialSources: any[] = [];
    const seenInitSourceKeys = new Set<string>();
    for (const c of allVerified) {
      // claim.sources is a list of title STRINGS after the citation firewall; the URL-bearing
      // objects live in richSources. Reading `sources` first meant every key was "" and the
      // video-level source list started empty.
      const rich = Array.isArray((c as any).richSources) ? (c as any).richSources : [];
      const sList = rich.length > 0
        ? rich
        : ((c as any).effectiveSources || (c as any).sources || []).filter((s: any) => s && typeof s === "object");
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

    const speakerBreakdowns = computeSpeakerBreakdown(allVerified, synthesis.speakerRoles);
    logger.info("[Credibility] Speaker metrics computed", { jobId, speakerCount: speakerBreakdowns.length });

    return { synthesis, speakerBreakdowns, synthesisTier };
  }

  /**
   * Stage 10: Assemble Final Result, Multi-Path Storage Persistence & Event Dispatch
   */
  private async executeStage10AssembleAndStoreResult(params: {
    jobId: string;
    userId: string;
    targetVideoId: string;
    executionPlan: ExecutionPlan;
    eventId: string;
    allVerified: VerifiedClaim[];
    explainableResults: ExplainabilityResult[];
    synthesis: SynthesisResult;
    speakerBreakdowns: any[];
    speakerIdentities: any;
    claimLedger: ClaimLedgerSummary;
    factCheckStats: any;
    evaluationHealth: any;
    domainInfo: any;
    contentIntent: any;
    synthesisTier: "standard" | "deep" | "podcast";
    deepResearchActive: boolean;
    hasTranscript: boolean;
    transcript: any;
    rawClaims: ExtractedClaim[];
    hitRate: number;
    t0: number;
    t1: number;
    tVerificationEnd: number;
    falseCount: number;
    highestSeverityVerdict: string;
  }): Promise<CredibilityResult> {
    const {
      jobId, userId, targetVideoId, executionPlan, eventId, allVerified,
      explainableResults, synthesis, speakerBreakdowns, speakerIdentities,
      claimLedger, factCheckStats, evaluationHealth, domainInfo, contentIntent,
      synthesisTier, deepResearchActive, hasTranscript, transcript, rawClaims,
      hitRate, t0, t1, tVerificationEnd, falseCount, highestSeverityVerdict
    } = params;

    const durationSeconds = transcript.duration ?? 0;
    const tFinal = Date.now();

    const distinctSourcesMap = new Map<string, any>();
    for (const c of explainableResults) {
      for (const s of (c.sources || [])) {
        const key = (s.url || s.title || "").toLowerCase();
        if (key && !distinctSourcesMap.has(key)) {
          distinctSourcesMap.set(key, s);
        }
      }
    }
    for (const s of (synthesis.conclusion?.sources || [])) {
      const key = (typeof s === "string" ? s : s?.url || s?.title || "").toLowerCase();
      if (key && !distinctSourcesMap.has(key)) {
        distinctSourcesMap.set(key, typeof s === "string" ? { title: s, url: s, directUrl: s } : s);
      }
    }
    const aggregatedSources = Array.from(distinctSourcesMap.values());
    if (synthesis.conclusion && (!synthesis.conclusion.sources || synthesis.conclusion.sources.length === 0)) {
      synthesis.conclusion.sources = aggregatedSources.slice(0, 5);
    }

    const result: CredibilityResult = {
      analysisState:    'VERIFIED' as any,
      analysisFailureReason: undefined,
      viewerNote:       synthesis.viewerNote,
      uiReport:         undefined,
      confidence:       0,
      confidenceTier:   'low' as any,
      
      chapters:         synthesis.chapters || [],
      speakers:         speakerBreakdowns,
      speakerIdentities,
      claims:           explainableResults,
      claimLedger,
      sources:          aggregatedSources,
      richSources:      aggregatedSources as any,
      
      
      videoCategory:          executionPlan.videoCategory,
      contextualFlags:        undefined,
      
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
      reviewTriggered:  falseCount > 0 && highestSeverityVerdict === 'false_claim',
      reviewReason:     falseCount > 0 && highestSeverityVerdict === 'false_claim'
        ? `Flagged for human review: ${falseCount} high-severity claim(s) contradicted by documented evidence.`
        : undefined,
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
        model: "Gemini 3.5 Multi-Model",
        scoring: "v12.0-no-scoring",
        registry: "v3-blended"
      },

      llmProvider: "Gemini 3.5 (Flash-Lite+Pro)",
      sttProvider: hasTranscript ? "AssemblyAI Universal-3.7-Pro" : "Google Cloud Multimodal (Zero-Copy)",
      language: normalizeLanguageCode(transcript?.language || "en"),

      latencyMs: {
        extraction:   t1 - t0,
        verification: tVerificationEnd - t1,
        consistency:  0,
        synthesis:    tFinal - tVerificationEnd,
        total:        tFinal - t0,
      },
      processingMetadata: {
        verificationPipeline: {
          verifiedBy: deepResearchActive ? "Gemini 4 Hydrogen" : "Gemini 3.5 Flash Lite",
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

    const storedResult = await this.storeResult(jobId, userId, result, targetVideoId);

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
    }).catch((synthErr) => logger.warn("[Credibility] Could not publish credibility-synthesis event", { jobId, err: String(synthErr) }));
    logger.info("[Credibility] Async synthesis event published after result storage", { jobId });

    // Counts come from the stored (gated) report, not the raw pre-gate statuses.
    const gatedStats = storedResult.factCheckStats ?? result.factCheckStats;
    const eventData: FactCompleteData = {
      claimsEvaluated:  gatedStats.evaluatedClaims,
      correct:          gatedStats.correct,
      incorrect:        gatedStats.incorrect,
      unverifiable:     gatedStats.unverifiable,
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

    await this.syncCredibilityProgress(jobId, targetVideoId, 100, "completed", { completedAt: Date.now() });
    await aggregationLayer.onStageComplete(jobId, "credibility", userId, executionPlan);

    logger.info("[Credibility] Completed", {
      jobId,
      ms:     result.processingTime,
      hitRate,
    });
    await this.distribution.markEventCompleted(eventId);

    return result;
  }

  /**
   * Stage 11: Record Vertex AI Token Usage, Grounding Queries & Compute Attribution
   */
  private async executeStage11RecordCostAttribution(
    jobId: string,
    userId: string,
    rawClaims: ExtractedClaim[],
    allVerified: VerifiedClaim[],
    evaluatedCount: number,
    deepResearchActive: boolean,
    t0: number
  ): Promise<void> {
    const elapsedSec = (Date.now() - t0) / 1000;
    const claimCount = rawClaims.length;
    const verifiedCount = evaluatedCount;
    const modelTier: "flash" | "pro" = deepResearchActive ? "pro" : "flash";

    const actualTokens = JobTokenTracker.getAndClear(jobId);

    if (actualTokens && (actualTokens.extractionInputTokens > 0 || actualTokens.verificationInputTokens > 0)) {
      logger.info(`[Credibility] Recording actual Vertex AI token costs for ${jobId}`, { actualTokens });
      if (actualTokens.extractionInputTokens > 0 || actualTokens.extractionOutputTokens > 0) {
        costEngine.recordGeminiCost(jobId, userId, "extraction", "flash", actualTokens.extractionInputTokens, actualTokens.extractionOutputTokens).catch((err) => logger.warn(`[Credibility] Extraction cost record error for ${jobId}:`, err));
      }
      if (actualTokens.verificationInputTokens > 0 || actualTokens.verificationOutputTokens > 0) {
        costEngine.recordGeminiCost(jobId, userId, "verification", modelTier, actualTokens.verificationInputTokens, actualTokens.verificationOutputTokens).catch((err) => logger.warn(`[Credibility] Verification cost record error for ${jobId}:`, err));
      }
      if (actualTokens.synthesisInputTokens > 0 || actualTokens.synthesisOutputTokens > 0) {
        costEngine.recordGeminiCost(jobId, userId, "synthesis", "flash", actualTokens.synthesisInputTokens, actualTokens.synthesisOutputTokens).catch((err) => logger.warn(`[Credibility] Synthesis cost record error for ${jobId}:`, err));
      }
    } else {
      const extractionChunks = Math.max(1, Math.ceil(claimCount / 5));
      const extractInputTokens = extractionChunks * 2000;
      const extractOutputTokens = extractionChunks * 500;
      costEngine.recordGeminiCost(jobId, userId, "extraction", "flash", extractInputTokens, extractOutputTokens).catch((err) => logger.warn(`[Credibility] Fallback extraction cost record error for ${jobId}:`, err));

      const verificationBatches = Math.max(1, Math.ceil(verifiedCount / 6));
      const verifyInputTokens = verificationBatches * 3000;
      const verifyOutputTokens = verificationBatches * 1000;
      costEngine.recordGeminiCost(jobId, userId, "verification", modelTier, verifyInputTokens, verifyOutputTokens).catch((err) => logger.warn(`[Credibility] Fallback verification cost record error for ${jobId}:`, err));

      costEngine.recordGeminiCost(jobId, userId, "synthesis", "flash", 15000, 5000).catch((err) => logger.warn(`[Credibility] Fallback synthesis cost record error for ${jobId}:`, err));
    }

    const groundedClaims = allVerified.filter(c =>
      c.richSources?.some((s: any) => s.retrievalMethod === "google_grounding" || s.retrievalProvider === "Google Grounding (Fused)")
    ).length;
    if (groundedClaims > 0) {
      const queryCount = Math.ceil(groundedClaims / 5);
      costEngine.recordGroundingCost(jobId, userId, queryCount).catch((err) => logger.warn(`[Credibility] Grounding cost record error for ${jobId}:`, err));
    }

    costEngine.recordComputeCost(jobId, userId, elapsedSec).catch((err) => logger.warn(`[Credibility] Compute cost record error for ${jobId}:`, err));
  }

  /**
   * Run the full credibility pipeline.
   * Clean, modular orchestrator with explicit stages and instant root-cause bug localization.
   */
  async runCredibilityPipeline(
    jobId:         string,
    userId:        string,
    executionPlan: ExecutionPlan,
    eventId:       string,
    traceId?:      string,
    providedVideoUrl?: string
  ): Promise<CredibilityResult> {
    const t0 = Date.now();
    const tracker = new FactcheckDiagnosticTracker(jobId, executionPlan.videoId, userId);
    let targetVideoId: string = executionPlan.videoId || jobId;
    let transcript: any = null;

    try {
      // ── Stage 1: Pre-flight Checks & Idempotency ───────────────────────────
      const preflight = await tracker.executeStage(
        FactcheckStage.STAGE_01_PREFLIGHT,
        "DistributionLayer & CircuitBreaker",
        () => this.executeStage01Preflight(jobId, userId, executionPlan, eventId, traceId),
        { jobId, eventId, traceId },
        "Check Redis/Firestore distribution locks or upstream provider circuit breaker health"
      );
      if (preflight.shouldExitEarly) {
        return preflight.existingResult || ({} as CredibilityResult);
      }

      await this.syncCredibilityProgress(jobId, targetVideoId, 5, "running", { startedAt: t0 });

      // ── Stage 2: Resilient Input & Media Context Resolution ────────────────
      const input = await tracker.executeStage(
        FactcheckStage.STAGE_02_INPUT_RESOLUTION,
        "InputResolutionService",
        () => this.executeStage02InputResolution(jobId, executionPlan, providedVideoUrl),
        { jobId, providedVideoUrl },
        "Verify transcript exists in Firestore/Storage or ensure valid GCS media URI is accessible"
      );
      targetVideoId = input.targetVideoId;
      transcript = input.transcript;
      const { jobData, videoContext, channelId, hasTranscript } = input;
      tracker.recordMetric("hasTranscript", hasTranscript);
      tracker.recordMetric("targetVideoId", targetVideoId);

      await this.syncCredibilityProgress(jobId, targetVideoId, 10);

      // ── Stage 3: Rate Limiting & Safety Quota Enforcement ──────────────────
      const { isChannelVerified, effectiveMaxClaims } = await tracker.executeStage(
        FactcheckStage.STAGE_03_QUOTA_AND_SAFETY_GATES,
        "QuotaAndSafetyGates",
        () => this.executeStage03QuotaAndSafety(userId, channelId, jobData, executionPlan),
        { userId, channelId },
        "Check user rate limit document in Firestore collection 'rate_limits'"
      );
      tracker.recordMetric("isChannelVerified", isChannelVerified);
      tracker.recordMetric("effectiveMaxClaims", effectiveMaxClaims);

      const deepResearchActive = isDeepResearchEnabled(executionPlan.synthesisTier || 'standard') ||
        executionPlan.factCheckTier === 'full_ground' ||
        (executionPlan.factCheckTier as string) === 'deep';

      // ── Stage 4: Claim Extraction & Content Intent Analysis ────────────────
      const extraction = await tracker.executeStage(
        FactcheckStage.STAGE_04_CLAIM_EXTRACTION,
        "FactExtractionService & ContentIntentDetector",
        () => this.executeStage04ClaimExtraction(
          jobId, targetVideoId, channelId, jobData, videoContext,
          executionPlan, hasTranscript, transcript, providedVideoUrl
        ),
        { hasTranscript, videoTitle: videoContext.title },
        "Check Gemini Flash-Lite quota or verify video audio track has intelligible speech"
      );
      transcript = extraction.transcript;
      const { rawClaims, domainInfo, contentIntent, speakerIdentities, videoDurationSec, extractionPartial } = extraction;
      const t1 = Date.now();
      tracker.recordMetric("rawClaimsCount", rawClaims.length);
      tracker.recordMetric("domain", domainInfo?.domain);

      await this.syncCredibilityProgress(jobId, targetVideoId, 30);

      // ── Stage 5: Claim Classification, Ranking & Streaming ─────────────────
      const { topClaims, filteredCount, filteringReasons } = await tracker.executeStage(
        FactcheckStage.STAGE_05_RANKING_AND_STREAMING,
        "StreamingClaimProcessor & Classification",
        () => this.executeStage05RankingAndStreaming(
          targetVideoId, rawClaims, effectiveMaxClaims, extractionPartial, jobId, videoDurationSec
        ),
        { rawClaimsCount: rawClaims.length, effectiveMaxClaims },
        "Verify Firestore subcollection write permissions for 'videos/{id}/claims'"
      );
      tracker.recordMetric("topClaimsCount", topClaims.length);
      tracker.recordMetric("filteredCount", filteredCount);

      await this.syncCredibilityProgress(jobId, targetVideoId, 40);

      // ── Stage 6: Harvest Contextual Sources ────────────────────────────────
      const cascadeOptions = await tracker.executeStage(
        FactcheckStage.STAGE_06_SOURCE_HARVESTING,
        "SourceTrustService & CommunitySources",
        () => this.executeStage06HarvestSources(targetVideoId, jobId, jobData, videoContext, domainInfo),
        { targetVideoId },
        "Check Firestore claim_sources collection or provided URL syntax"
      );

      await this.syncCredibilityProgress(jobId, targetVideoId, 50);

      // ── Stage 7: Four-Tier Cascade Verification ────────────────────────────
      const { allVerified, hitRate, tVerificationEnd } = await tracker.executeStage(
        FactcheckStage.STAGE_07_CASCADE_VERIFICATION,
        "VerificationCascadeService",
        () => this.executeStage07CascadeVerification(
          targetVideoId, jobId, topClaims, domainInfo, cascadeOptions, videoContext
        ),
        { topClaimsCount: topClaims.length },
        "Check Vertex AI Google Grounding quota or Wikipedia/PubMed external adapter latency"
      );
      tracker.recordMetric("verifiedClaimsCount", allVerified.length);
      tracker.recordMetric("cacheHitRate", hitRate);

      await this.syncCredibilityProgress(jobId, targetVideoId, 65);

      // ── Stage 8: Verifiable Claim Ledger & Explainability ──────────────────
      const ledgerResult = await tracker.executeStage(
        FactcheckStage.STAGE_08_LEDGER_AND_EXPLAINABILITY,
        "LedgerCompilationEngine",
        () => this.executeStage08CompileLedgerAndExplainability(
          jobId, rawClaims, topClaims, allVerified, filteredCount, filteringReasons, hitRate
        ),
        { allVerifiedCount: allVerified.length },
        "Verify claim ledger arithmetic and explainability translation mappings"
      );
      const {
        evaluationHealth, factCheckStats, claimLedger, explainableResults,
        falseCount, highestSeverityVerdict
      } = ledgerResult;

      await this.syncCredibilityProgress(jobId, targetVideoId, 70);

      // ── Stage 9: Persist Draft & Trigger Async Synthesis ───────────────────
      const { synthesis, speakerBreakdowns, synthesisTier } = await tracker.executeStage(
        FactcheckStage.STAGE_09_PERSISTENCE_AND_DISPATCH,
        "DraftPersistenceService",
        () => this.executeStage09PersistDraftAndTriggerSynthesis(
          jobId, userId, targetVideoId, executionPlan, transcript, allVerified,
          rawClaims, filteredCount, domainInfo, contentIntent, evaluationHealth,
          speakerIdentities, t0
        ),
        { allVerifiedCount: allVerified.length },
        "Check Firestore collection 'credibility_drafts' write permissions or GCS bucket access"
      );

      // ── Stage 10: Assemble & Store Final Result ────────────────────────────
      const finalResult = await tracker.executeStage(
        FactcheckStage.STAGE_09_PERSISTENCE_AND_DISPATCH,
        "AnalysisRepository & EventPublisher",
        () => this.executeStage10AssembleAndStoreResult({
          jobId, userId, targetVideoId, executionPlan, eventId, allVerified,
          explainableResults, synthesis, speakerBreakdowns, speakerIdentities,
          claimLedger, factCheckStats, evaluationHealth, domainInfo, contentIntent,
          synthesisTier, deepResearchActive, hasTranscript, transcript, rawClaims,
          hitRate, t0, t1, tVerificationEnd, falseCount, highestSeverityVerdict
        }),
        { jobId, targetVideoId },
        "Verify Cloud Storage bucket 'factChecks/{id}/full.json' write access or PubSub permissions"
      );

      // ── Stage 11: Record Cost Attribution ──────────────────────────────────
      await tracker.executeStage(
        FactcheckStage.STAGE_10_COST_ATTRIBUTION,
        "CostEngine",
        () => this.executeStage11RecordCostAttribution(
          jobId, userId, rawClaims, allVerified, factCheckStats.evaluatedClaims,
          deepResearchActive, t0
        ),
        { jobId, userId },
        "Check Firestore collection 'costs' or token ledger tracking"
      ).catch((costErr) => {
        logger.warn("[Credibility] Cost attribution warning (non-fatal):", costErr);
      });

      return finalResult;

    } catch (error: any) {
      const pipelineError = error instanceof FactcheckPipelineError
        ? error
        : tracker.captureError({
            stage: FactcheckStage.STAGE_07_CASCADE_VERIFICATION,
            component: "CredibilityEngine",
            originalError: error,
            suggestedRemedy: "Review stage logs and component stack trace",
          });

      const failedStage = pipelineError.stage;
      const failedComponent = pipelineError.component;
      const remedy = pipelineError.suggestedRemedy;
      const errMsg = pipelineError.message;
      const diagTelemetry = tracker.getDiagnosticTelemetry();

      logger.error("================================================================================");
      logger.error("🚨 TRUTHWORLD FACTCHECK PIPELINE ERROR DETECTED");
      logger.error("================================================================================");
      logger.error(`• Job ID:           ${jobId}`);
      logger.error(`• Target Video ID:  ${targetVideoId}`);
      logger.error(`• Failed Stage:     ${failedStage}`);
      logger.error(`• Failed Component: ${failedComponent}`);
      logger.error(`• Root Cause:       ${errMsg}`);
      logger.error(`• Troubleshooting:  ${remedy}`);
      logger.error("================================================================================");

      let errorCode: CredibilityErrorCode = "GEMINI_FAILURE";
      if (error instanceof ExtractionError) {
        errorCode = error.code;
      }
      if (errMsg.includes("Transcript not found") || errMsg.includes("Empty transcript")) {
        errorCode = "TRANSCRIPT_EMPTY";
      } else if (errMsg.includes("JSON")) {
        errorCode = "JSON_PARSE_FAILED";
      }

      // v8.4: Robust Capacity Handling
      const isCapacity = errorCode === 'AI_CAPACITY_EXCEEDED' || 
                         errMsg.toLowerCase().includes("capacity") || 
                         errMsg.includes("429") || 
                         errMsg.includes("503");

      if (isCapacity) {
        logger.warn("[Credibility] Critical Capacity Limit hit at orchestration level", { jobId });
        
        const credSnap = await db().collection("credibility_jobs").doc(jobId).get().catch(() => null);
        const jobSnap = await db().collection("video_jobs").doc(jobId).get();
        const retryCount = credSnap?.exists && typeof credSnap.data()?.retryCount === "number"
          ? credSnap.data()!.retryCount
          : (jobSnap.data()?.credibilityRetryCount || 0);
        
        if (retryCount < 1) {
           await Promise.all([
             db().collection("video_jobs").doc(jobId).update({ credibilityRetryCount: retryCount + 1 }).catch(() => {}),
             EdgeLayer.upsertCredibilityJob(jobId, { retryCount: retryCount + 1 }),
           ]);
           logger.info("[Credibility] Scheduling a 60s cool-down retry...", { jobId });
           
           await new Promise(resolve => setTimeout(resolve, 60000));
           return this.runCredibilityPipeline(jobId, userId, executionPlan, eventId, traceId, providedVideoUrl);
        }
        
        const fallbackResult = this.generateCapacityFallbackResult(jobId, userId, errMsg, transcript);
        await this.storeResult(jobId, userId, fallbackResult, targetVideoId);
        await this.syncCredibilityProgress(jobId, targetVideoId, 100, "completed", { completedAt: Date.now() });

        await aggregationLayer.onStageComplete(jobId, "credibility", userId, executionPlan);
        
        await this.distribution.publish("fact-complete", {
          eventId:   eventId,
          eventType: "fact-complete",
          jobId, userId,
          timestamp:  Date.now(),
          data:       {
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

      await EdgeLayer.failStage(jobId, "credibility", errMsg);
      await this.syncCredibilityProgress(jobId, targetVideoId, 0, "failed", {
        error: errMsg,
        failedStage,
        failedComponent,
        suggestedRemedy: remedy,
        diagnostics: diagTelemetry,
        completedAt: Date.now(),
      });
      await aggregationLayer.onStageComplete(jobId, "credibility", userId, executionPlan).catch(() => {});
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
      confidence: 0,
      confidenceTier: 'low' as any,
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
      versions: { model: "Gemini 3.5", scoring: "v12.0-no-scoring", registry: "v3-blended" },
      filteringReasons: [],
    } as any;
  }

  public async cacheCheck(
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

  public async cacheWithTTL(claims: VerifiedClaim[]): Promise<void> {
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
        // Language-Agnostic Classification: Leverage structured metadata and extraction confidence
        let strength: ClaimStrength = "moderate";

        const framing = (claim as any).framing;
        const hasQuantitativeMetric = /\d+%|\d+\s*(?:crore|lakh|million|billion|trillion|percent|\$|₹|€|£)/i.test(claim.text);

        if (framing === "ABSOLUTE" || (claim as any).claimStrength === "absolute") {
          strength = "absolute";
        } else if (framing === "ASSERTIVE" || hasQuantitativeMetric || (claim as any).claimStrength === "strong") {
          strength = "strong";
        } else if (framing === "HEDGED" || (claim as any).claimStrength === "hedged") {
          strength = "hedged";
        }

        let importance = 0.5;
        if (claim.nature === ClaimNature.VERIFIABLE_FACT) importance += 0.35;
        else if (claim.nature === ClaimNature.ESTIMATION)  importance += 0.25;
        else if (claim.nature === "BELIEF" as any)         importance += 0.10;
        else if (claim.nature === ClaimNature.OPINION)     importance -= 0.10;

        if (strength === "strong")   importance += 0.20;
        if (strength === "absolute") importance += 0.15;
        if (strength === "hedged")   importance -= 0.25;

        const conf = typeof claim.confidence === "number" ? claim.confidence : 0.8;
        if (conf >= 0.85) importance += 0.15;
        else if (conf < 0.6) importance -= 0.10;

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
    return verified.map((rawClaim, idx) => {
      const claim = enforceClosedWorldCitationFirewall(rawClaim);
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
        unverifiable:               { label: "Unverifiable", icon: "❔" },
        rhetorical_exaggeration:    { label: "Rhetorical Exaggeration", icon: "🎭" }
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
        severity:       claim.severity || (['false_claim', 'incorrect', 'verified_false', 'historical_consensus_denial'].includes(claim.status) ? 'high' : ['misleading', 'disputed'].includes(claim.status) ? 'medium' : (['unproven', 'unsupported', 'verification_timeout'].includes(claim.status) ? undefined : 'low')),
        severityLabel:  (() => {
          const sev = claim.severity || (['false_claim', 'incorrect', 'verified_false', 'historical_consensus_denial'].includes(claim.status) ? 'high' : ['misleading', 'disputed'].includes(claim.status) ? 'medium' : (['unproven', 'unsupported', 'verification_timeout'].includes(claim.status) ? undefined : 'low'));
          return sev ? severityLabels[sev] : undefined;
        })(),
        reasoning:      claim.reasoning || claim.verificationSummary || "",
        response:       claim.reasoning || claim.verificationSummary || "",
        explanation:    claim.reasoning || claim.verificationSummary || "",
        whyWrong:       ['false_claim', 'incorrect', 'verified_false', 'historical_consensus_denial', 'misleading', 'disputed'].includes(claim.status) ? (claim.reasoning || undefined) : undefined,
        correction:     ['incorrect', 'historical_consensus_denial', 'incorrect_citation'].includes(claim.status)
          ? `Correction: ${claim.reasoning}`
          : (['false_claim', 'verified_false'].includes(claim.status) ? (claim.reasoning || undefined) : undefined),
        sources:        (claim.richSources && claim.richSources.length > 0)
          ? claim.richSources
              .filter((rs) => isVerifiedRichSource(rs))
              .map(rs => {
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
                  provenance:     rs.snippet,    // v5.0: Source snippet used as provenance
                  urlVerification: rs.urlVerification,
                };
              })
          : [],
        richSources:    claim.richSources,
        sourceStatus:   claim.sourceStatus || ((claim.richSources || []).some((rs) => isVerifiedRichSource(rs)) ? "partial" : "missing"),
        verifiedAcademicMetadata: claim.verifiedAcademicMetadata,
        start:          claim.start ?? 0,
        startMs:        claim.start ?? 0,
        end:            claim.end   ?? 0,
        endMs:          claim.end   ?? 0,
        timestampStart: claim.start ?? 0,
        timestampEnd:   claim.end   ?? 0,
        confidence:     claim.verificationConfidence ?? claim.confidence ?? 0.5,
        multiModelConsensus: claim.multiModelConsensus,
        // Inputs the verdict gate needs to prove Opinion & Belief / Caution labels.
        ...((claim as any).transcriptExcerpt ? { transcriptExcerpt: (claim as any).transcriptExcerpt } : {}),
        ...((claim as any).opinionEvidence ? { opinionEvidence: (claim as any).opinionEvidence } : {}),
        ...((claim as any).cautionType ? { cautionType: (claim as any).cautionType } : {}),
      };
    });
  }

  private async storeResult(
    jobId:  string,
    userId: string,
    result: CredibilityResult,
    targetVideoId?: string
  ): Promise<CredibilityResult> {
    // Verdict gate: the last code-level check — no verdict without its required evidence.
    const sanitizedResult = applyVerdictGateToReport(sanitizeReportPayloadForClosedWorld(result));
    // Output quality gate: grade the finished report (shared sources, unverified links,
    // verdict/explanation contradictions, …) so regressions are caught before users do.
    (sanitizedResult as any).qualityAudit = await recordReportQualityAudit(jobId, targetVideoId, sanitizedResult);
    const { path: latestPath } = await this.analysisRepository.saveAnalysis(jobId, "factChecks", sanitizedResult);
    const bucket = admin.storage().bucket();
    const factCheckUrl = `gs://${bucket.name}/${latestPath}`;

    // Industry Standard Resilient Multi-Path Storage:
    // Persist full.json and latest.json directly so all readers resolve consistently
    try {
      await Promise.all([
        bucket.file(`factChecks/${jobId}/full.json`).save(JSON.stringify(sanitizedResult), {
          metadata: { contentType: "application/json" }
        }),
        bucket.file(`factChecks/${jobId}/latest.json`).save(JSON.stringify(sanitizedResult), {
          metadata: { contentType: "application/json" }
        }),
      ]);
    } catch (saveErr) {
      logger.warn("[Credibility] Non-fatal direct full.json storage backup warning", { jobId, err: String(saveErr) });
    }

    // Update video_jobs and independent credibility_jobs with the factCheckUrl
    await Promise.all([
      db().collection("video_jobs").doc(jobId).set({
        outputs: { factCheckUrl },
        updatedAt: Date.now(),
      }, { merge: true }).catch(() => {}),
      EdgeLayer.upsertCredibilityJob(jobId, {
        factCheckUrl,
        progress: 95,
      }),
      ...(isVideoId(targetVideoId) ? [
        safeMergeExistingVideo(
          targetVideoId,
          {
            factCheckUrl,
            factCheckProgress: 95,
            factCheckStatus: "running",
            updatedAt: Date.now(),
          },
          "[Credibility:FactCheckProgress]"
        ).catch(() => false)
      ] : []),
    ]);

    // The live claim list (videos/{id}/claims) now shows exactly the stored report's verdicts.
    await this.syncLiveClaimsWithReport(targetVideoId, sanitizedResult, jobId);

    // Skip Firestore factChecks write to comply with storage-only verification results policy
    logger.info("[Credibility] Skipped Firestore factChecks write, result saved to Storage only", { jobId });

    // Note: Propagation to video collection is now handled centrally by AggregationLayer.onStageComplete
    // which is called immediately after this method returns in runCredibilityPipeline.

    return sanitizedResult;
  }

  /**
   * Overwrites each streamed claim in `videos/{videoId}/claims` with the verdict from the stored,
   * gated report, so viewers never see a live verdict that disagrees with the report.
   */
  private async syncLiveClaimsWithReport(targetVideoId: string | undefined, report: any, jobId: string): Promise<void> {
    const claims: VerifiedClaim[] = Array.isArray(report?.claims) ? report.claims.filter((c: any) => c?.claimId) : [];
    if (!isVideoId(targetVideoId) || claims.length === 0) return;
    await StreamingClaimProcessor.publishResolvedClaims(targetVideoId, claims).catch((err: any) => {
      logger.warn("[Credibility] Could not sync live claims with the stored report", { jobId, err: err?.message });
    });
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

    const tracker = new FactcheckDiagnosticTracker(jobId, draft.videoId, userId);
    tracker.addBreadcrumb("Async synthesis pass triggered", {
      eventId,
      synthesisTier: draft.synthesisTier,
    });

    try {
      await tracker.executeStage(
        FactcheckStage.STAGE_11_ASYNC_SYNTHESIS,
        "SynthesisService",
        async () => {
          let {
            verifiedClaims,
            draftGcsUri,
            synthesisTier = "standard",
            speakerIdentities = {},
            evaluationHealth = {},
            executionPlanRef,
          } = draft;
          void executionPlanRef;

          if (!verifiedClaims && draftGcsUri) {
            try {
              const bucket = admin.storage().bucket();
              const path = draftGcsUri.replace(`gs://${bucket.name}/`, "");
              const [content] = await bucket.file(path).download();
              verifiedClaims = JSON.parse(content.toString());
              logger.info("[CredibilityEngine.runSynthesisPass] Loaded verified claims from GCS draft", { jobId, count: verifiedClaims?.length });
            } catch (gcsErr) {
              throw new FactcheckPipelineError({
                jobId,
                stage: FactcheckStage.STAGE_11_ASYNC_SYNTHESIS,
                component: "GCSStorageAdapter",
                message: `Failed to load draft claims from GCS URI ${draftGcsUri}: ${String(gcsErr)}`,
                suggestedRemedy: "Ensure storage permissions allow reading credibility draft blobs and verify the GCS path exists.",
                context: { jobId, draftGcsUri },
                originalError: gcsErr,
              });
            }
          }

          const transcript = await this.loadTranscript(jobId, draft.videoId);
          if (!transcript) {
            throw new FactcheckPipelineError({
              jobId,
              stage: FactcheckStage.STAGE_11_ASYNC_SYNTHESIS,
              component: "TranscriptLoader",
              message: `Transcript not found for video ${draft.videoId} and job ${jobId}`,
              suggestedRemedy: "Verify that transcription stage (Layer 03) completed successfully and transcript artifact was persisted.",
              context: { jobId, videoId: draft.videoId },
            });
          }

        let existingResult = await this.loadExistingResult(jobId);
        if (!existingResult) {
          for (let attempt = 1; attempt <= 3; attempt++) {
            await new Promise(r => setTimeout(r, 1000 * attempt));
            existingResult = await this.loadExistingResult(jobId);
            if (existingResult) break;
          }
        }

        if (!existingResult) {
          logger.warn("[CredibilityEngine.runSynthesisPass] Existing CredibilityResult not found in storage, synthesizing from draft claims directly", { jobId });
          existingResult = {
            analysisState: 'VERIFIED' as any,
            analysisFailureReason: undefined,
            confidence: 0,
            confidenceTier: 'low' as any,
            chapters: [],
            speakers: [],
            speakerIdentities,
            claims: this.buildExplainability(verifiedClaims),
            factCheckStats: draft.factCheckStats,
            filteringReasons: [],
            contentIntent: draft.contentIntent,
            scoringMethod: 'balanced',
            diagnostics: [],
            confidenceNotes: [],
            synthesisTier,
            factCheckTier: 'standard',
            isLongform: false,
            isFinal: true,
            summary: "",
            conclusion: { label: "Review Complete", text: "", confidence: 0.8, sources: [] },
            domain: draft.domainInfo?.domain || "General",
            isLaunchNews: !!draft.domainInfo?.isLaunchNews,
            evaluationHealth,
            verifiedAt: Date.now(),
            processingTime: 0,
            versions: { model: "Gemini 3.5 Multi-Model", scoring: "v12.0-no-scoring", registry: "v3-blended" },
            llmProvider: "Gemini 3.5 (Flash-Lite+Pro)",
            sttProvider: "AssemblyAI",
            language: "en",
            latencyMs: { extraction: 0, verification: 0, consistency: 0, synthesis: 0, total: 0 },
          } as any;
        }

        const speakerCount = Object.keys(speakerIdentities).length;
        const pipelineMode = speakerCount > 1 ? "multi" : "standard";

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
              evaluationHealth,
            }
          );
        } catch (err: any) {
          logger.error("[CredibilityEngine.runSynthesisPass] Synthesis generation failed in background", { jobId, error: err?.message });
          const isZeroClaims = verifiedClaims.length === 0;
          const fallbackSources: any[] = [];
          const seenFallbackKeys = new Set<string>();
          for (const c of verifiedClaims) {
            const sList = (c as any).richSources || [];
            for (const s of sList) {
              if (!isVerifiedRichSource(s)) continue;
              const k = (s.url || "").toLowerCase();
              if (k && !seenFallbackKeys.has(k)) {
                seenFallbackKeys.add(k);
                fallbackSources.push({
                  title: s.title || s.domain || "Authoritative Source",
                  url: s.url || "",
                  domain: s.domain || "",
                  trustLevel: s.tier === 'A' || s.tier === 'B' ? 'High' : 'Medium',
                  type: s.type || 'Supporting',
                  snippet: s.snippet || "",
                  urlVerification: s.urlVerification,
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
        const targetResult = existingResult!;
        targetResult.summary = synthesis.summary;
        targetResult.conclusion = synthesis.conclusion;
        targetResult.viewerNote = synthesis.viewerNote;
        targetResult.chapters = synthesis.chapters || targetResult.chapters || [];
        targetResult.keyThemes = synthesis.keyThemes || targetResult.keyThemes || [];
        targetResult.manipulationScore = synthesis.manipulationScore;

        // Aggregate all verified sources across claims and synthesis if empty
        if (!targetResult.sources || targetResult.sources.length === 0) {
          const distinctSourcesMap = new Map<string, any>();
          for (const c of (targetResult.claims || [])) {
            for (const s of (c.sources || [])) {
              const key = (s.url || s.title || "").toLowerCase();
              if (key && !distinctSourcesMap.has(key)) {
                distinctSourcesMap.set(key, s);
              }
            }
          }
          for (const s of (synthesis.conclusion?.sources || [])) {
            const key = (typeof s === "string" ? s : s?.url || s?.title || "").toLowerCase();
            if (key && !distinctSourcesMap.has(key)) {
              distinctSourcesMap.set(key, typeof s === "string" ? { title: s, url: s, directUrl: s } : s);
            }
          }
          const aggregated = Array.from(distinctSourcesMap.values());
          targetResult.sources = aggregated;
          targetResult.richSources = aggregated as any;
          if (synthesis.conclusion && (!synthesis.conclusion.sources || synthesis.conclusion.sources.length === 0)) {
            synthesis.conclusion.sources = aggregated.slice(0, 5);
          }
        }

        // Enforce Closed-World persistence invariant before saving GCS / Firestore artifacts
        const sanitizedExistingResult = applyVerdictGateToReport(sanitizeReportPayloadForClosedWorld(targetResult));
        (sanitizedExistingResult as any).qualityAudit = await recordReportQualityAudit(
          jobId,
          (draft as any)?.videoId,
          sanitizedExistingResult
        );

        // Save updated result to GCS analysis repository and full.json
        await this.analysisRepository.saveAnalysis(jobId, "factChecks", sanitizedExistingResult);
        const bucket = admin.storage().bucket();
        await bucket.file(`factChecks/${jobId}/full.json`).save(JSON.stringify(sanitizedExistingResult), {
          metadata: { contentType: "application/json" }
        });

        // Update existing videos document in Firestore (never create a new doc from jobId)
        const targetVideoDocId = isVideoId(draft.videoId) ? draft.videoId : "";
        await this.syncLiveClaimsWithReport(targetVideoDocId || undefined, sanitizedExistingResult, jobId);
        if (targetVideoDocId) {
          try {
            await safeMergeExistingVideo(
              targetVideoDocId,
              {
                summary: synthesis.summary,
                viewerNote: synthesis.viewerNote,
                conclusion: synthesis.conclusion,
                "aiFeatures.factCheckSummary": synthesis.summary,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              "[Credibility:SynthesisPass]"
            );
          } catch (videoUpdateErr: any) {
            logger.warn("[CredibilityEngine.runSynthesisPass] Could not patch videos document directly", { jobId, error: videoUpdateErr?.message });
          }
        }

        // Clean up draft
        if (draft.draftGcsUri) {
          try {
            const bucket = admin.storage().bucket();
            const path = draft.draftGcsUri.replace(`gs://${bucket.name}/`, "");
            bucket.file(path).delete().catch(() => {});
          } catch (_) {}
        }
        await db().collection("credibility_drafts").doc(jobId).delete();
        logger.info("[CredibilityEngine.runSynthesisPass] Successfully completed async synthesis pass and deleted draft", { jobId });
      });
    } catch (err: any) {
      const diagErr = err instanceof FactcheckPipelineError
        ? err
        : tracker.captureError({
            stage: FactcheckStage.STAGE_11_ASYNC_SYNTHESIS,
            component: "SynthesisService / GeminiLLM",
            originalError: err,
            suggestedRemedy: "Verify GEMINI_API_KEY quota, check draft claims validity in credibility_drafts, or review synthesis timeout limits.",
            context: { jobId, userId, eventId },
          });

      logger.error("🚨 [CredibilityEngine.runSynthesisPass] Async synthesis failed", {
        jobId,
        stage: diagErr.stage,
        component: diagErr.component,
        message: diagErr.message,
        remedy: diagErr.suggestedRemedy,
      });
      throw diagErr;
    }
  }

  private async loadExistingResult(jobId: string): Promise<CredibilityResult | null> {
    try {
      const repoResult = await this.analysisRepository.loadAnalysis(jobId, "factChecks");
      if (repoResult) return repoResult as CredibilityResult;
    } catch (e) {
      logger.warn("[Credibility] loadAnalysis failed, checking direct GCS paths", { jobId, err: String(e) });
    }

    const bucket = admin.storage().bucket();
    const candidatePaths = [
      `factChecks/${jobId}/full.json`,
      `factChecks/${jobId}/latest.json`,
    ];

    for (const p of candidatePaths) {
      try {
        const file = bucket.file(p);
        const [exists] = await file.exists();
        if (exists) {
          const [data] = await file.download();
          return JSON.parse(data.toString()) as CredibilityResult;
        }
      } catch (_) {}
    }

    return null;
  }

  private async loadTranscript(jobId: string, videoId?: string): Promise<any | null> {
    // 1. Direct Firestore transcripts collection lookup
    try {
      let doc = await db().collection("transcripts").doc(jobId).get();
      if ((!doc.exists || !Array.isArray(doc.data()?.utterances) || doc.data()?.utterances.length === 0) && videoId) {
        doc = await db().collection("transcripts").doc(videoId).get();
      }
      if ((!doc.exists || !Array.isArray(doc.data()?.utterances) || doc.data()?.utterances.length === 0) && videoId) {
        const vSnap = await db().collection("videos").doc(videoId).get();
        const origJobId = vSnap.data()?.jobId;
        if (origJobId && origJobId !== jobId) {
          const origDoc = await db().collection("transcripts").doc(origJobId).get();
          if (origDoc.exists && Array.isArray(origDoc.data()?.utterances) && origDoc.data()!.utterances.length > 0) {
            doc = origDoc;
          }
        }
      }
      if (doc.exists) {
        const data = doc.data();
        if (Array.isArray(data?.utterances) && data.utterances.length > 0) {
          return data;
        }
      }
    } catch (fsErr) {
      logger.warn("[Credibility] Firestore transcripts lookup warning", { jobId, err: String(fsErr) });
    }

    // 2. Storage lookup via video_jobs artifacts or canonical paths
    const bucket = admin.storage().bucket();
    const candidatePaths: string[] = [
      `transcripts/${jobId}/full.json`,
      ...(videoId ? [`transcripts/${videoId}/full.json`] : []),
    ];

    try {
      const jobDoc = await db().collection("video_jobs").doc(jobId).get();
      const jobData = jobDoc.exists ? jobDoc.data() : null;
      const gcsArtifact = jobData?.artifacts?.transcription?.jsonUrl;
      if (gcsArtifact && typeof gcsArtifact === "string") {
        const parsedPath = gcsArtifact.replace(`gs://${bucket.name}/`, "");
        if (!candidatePaths.includes(parsedPath)) {
          candidatePaths.unshift(parsedPath);
        }
      }
      if (videoId && (!jobData || !gcsArtifact)) {
        const vJobDoc = await db().collection("video_jobs").doc(videoId).get();
        const vJobData = vJobDoc.exists ? vJobDoc.data() : null;
        const vGcsArtifact = vJobData?.artifacts?.transcription?.jsonUrl;
        if (vGcsArtifact && typeof vGcsArtifact === "string") {
          const parsedPath = vGcsArtifact.replace(`gs://${bucket.name}/`, "");
          if (!candidatePaths.includes(parsedPath)) {
            candidatePaths.unshift(parsedPath);
          }
        }
      }
    } catch (_) {}

    for (const storagePath of candidatePaths) {
      try {
        const file = bucket.file(storagePath);
        const [exists] = await file.exists();
        if (exists) {
          const [content] = await file.download();
          const parsed = JSON.parse(content.toString());
          if (parsed) {
            const rawUtterances = parsed.utterances || parsed.segments?.map((s: any) => ({
              start: s.start,
              end: s.end,
              text: s.text,
              speaker: s.speaker || "Speaker",
            })) || [];
            if (rawUtterances.length > 0) {
              logger.info("[Credibility] Loaded full transcript from Cloud Storage", { storagePath, utterances: rawUtterances.length });
              return {
                ...parsed,
                utterances: rawUtterances,
                duration: parsed.duration || (rawUtterances[rawUtterances.length - 1].end / 1000),
                language: parsed.detectedLanguage || parsed.language || "en",
              };
            }
          }
        }
      } catch (dlErr) {
        logger.warn("[Credibility] Failed to load transcript from storage path", { storagePath, err: String(dlErr) });
      }
    }

    // 3. Fallback: Check videos collection document for inline transcript string
    if (videoId) {
      try {
        const videoDoc = await db().collection("videos").doc(videoId).get();
        if (videoDoc.exists) {
          const vData = videoDoc.data() || {};
          const transcriptText = (typeof vData.transcript === "string" ? vData.transcript : "").trim();
          if (transcriptText.length > 20) {
            logger.info("[Credibility] Synthesizing transcript from videos doc inline text", { videoId, length: transcriptText.length });
            const durationSec = vData.durationSeconds || vData.duration || 120;
            return {
              duration: durationSec,
              language: vData.language || "en",
              text: transcriptText,
              utterances: [{
                start: 0,
                end: durationSec * 1000,
                text: transcriptText,
                speaker: "Speaker 1",
              }],
              speakers: ["Speaker 1"],
              speakerCount: 1,
            };
          }
        }
      } catch (_) {}
    }

    return null;
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

  public async enqueueBackgroundRefresh(
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
export {
  FactcheckStage,
  FactcheckDiagnosticTracker,
  FactcheckPipelineError,
  type FactcheckDiagnosticTelemetry,
} from "./credibilityDiagnostics";

