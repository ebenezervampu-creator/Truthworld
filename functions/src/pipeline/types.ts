/**
 * Type definitions for video processing pipeline
 * ✅ CLEANED: No Redis references — Firestore + memory cache only
 */

export interface VideoJob {
  jobId: string;
  userId: string;
  videoUrl: string;
  fileName: string;
  duration: number;
  status: JobStatus;
  stage: ProcessingStage;
  progress: number;
  languages: string[];
  options: ProcessingOptions;
  outputs: OutputMetadata;
  timestamp: number;
  updatedAt: number;
  errors?: ErrorLog[];
}

export type JobStatus = "pending" | "processing" | "completed" | "failed" | "cancelled";
export type ProcessingStage = "queued" | "transcription" | "translation" | "subtitles" | "tts" | "dubbing" | "voice_cloning" | "media_processing" | "finalizing";

export interface JobData {
  jobId: string;
  userId: string;
  videoUrl: string;
  fileName: string;
  status: "accepted" | "processing" | "completed" | "failed";
  eventId: string;
  shard: string;
  executionPlan: ExecutionPlan;
  config: UserConfig;
  videoId?: string;           // Canonical video ID
  channelId?: string;         // Linked creator channel for reputation tracking
  linkedVideoIds?: string[];  // De-duplication links
  linkedVideoCount?: number;  // Performance counter
  estimatedCostUsd: number;
  stages: {
    transcription: StageStatus;
    credibility: StageStatus; // Legacy Path 1
    dubbing?: StageStatus;    // Legacy Path 2 (Optional in v5)
    truthEngine?: StageStatus; // New TruthEngine
    reachEngine?: StageStatus; // New ReachEngine
    aggregation?: StageStatus; // Optional in v5
    [key: string]: StageStatus | undefined; // Allow dynamic stages like 'translating_hi'
  };
  createdAt: number;
  updatedAt: number;
  completedAt?: number;       // Terminal Metric
  completionSource?: string;  // Terminal Metric (which stage triggered completion)
  version: number; // For canonical truth tracking
  finalOutput?: AggregatedOutput;
  
  // ETA & Predictability (v5)
  etaSeconds?: number;
  etaMin?: number;
  etaMax?: number;
  etaMode?: "cold" | "stable" | "high-variance";
  estimatedCompletionAt?: number;
  actualCompletedAt?: number;
  stageDurations?: Record<string, number>; // Stores duration in seconds per stage
  sourceLanguage?: string;   // Original video language
  outputs?: {
    subtitles?: Record<string, any>;
    dubbed?: Record<string, any>;
    [key: string]: any;
  };
}

export interface ProcessingOptions {
  genLangSubs: boolean;
  generateDubbing: boolean;
  enableVoiceCloning: boolean;
  chunkSize?: number;
  priority: "low" | "normal" | "high";
}

export interface OutputMetadata {
  subtitles: {
    [language: string]: {
      path: string;
      format: "srt" | "vtt";
      createdAt: number;
      followersCount: number;
      views: number;
    };
  };
  dubbed: {
    [language: string]: {
      path: string;
      audioUrl: string;
      createdAt: number;
    };
  };
  voiceCloning?: {
    cloneId: string;
    provider: string;
    createdAt: number;
  };
  transcript: {
    [language: string]: {
      text: string;
      path: string;
      createdAt: number;
    };
  };
}

export interface ErrorLog {
  stage: ProcessingStage;
  error: string;
  timestamp: number;
  retryCount: number;
  maxRetries: number;
}

export interface CloudTaskPayload {
  jobId: string;
  userId: string;
  operation: "orchestrate" | "transcode" | "merge";
  data: Record<string, any>;
  retryCount: number;
}

export interface TranscriptionResult {
  jobId: string;
  language: string;
  text: string;
  confidence: number;
  segments: Segment[];
}

export interface Segment {
  start: number;
  end: number;
  text: string;
}

export interface TranslationResult {
  jobId: string;
  sourceLanguage: string;
  targetLanguage: string;
  segments: TranslatedSegment[];
}

export interface TranslatedSegment {
  original: string;
  translated: string;
  start: number;
  end: number;
  confidence?: number;
  isHook?: boolean;
  variants?: {
    viral: string;
    safe: string;
    professional: string;
  };
}

export interface TTSRequest {
  jobId: string;
  language: string;
  text: string;
  voiceId?: string;
  speakerId?: string;
}

export interface TTSResult {
  jobId: string;
  language: string;
  audioUrl: string;
  duration: number;
  format: string;
}

export interface MediaMergeRequest {
  jobId: string;
  videoUrl: string;
  audioUrl: string;
  subtitleUrl?: string;
  language: string;
  format: "mp4" | "webm";
}

export interface ProcessLog {
  jobId: string;
  timestamp: number;
  stage: ProcessingStage;
  action: string;
  details?: Record<string, any>;
}

export interface Checkpoint {
  jobId: string;
  language: string;
  stage: ProcessingStage;
  data: Record<string, any>;
  timestamp: number;
}

// ============================================
// FACT-CHECKING TYPES
// ============================================

export enum VerificationState {
  VERIFIED             = 'VERIFIED',              // High factual density, comprehensive evidence
  PARTIALLY_VERIFIED   = 'PARTIALLY_VERIFIED',    // Some claims checked, others unverified
  STRUCTURAL_ONLY      = 'STRUCTURAL_ONLY',       // Zero factual claims — honesty/consistency only
  INSUFFICIENT_EVIDENCE = 'INSUFFICIENT_EVIDENCE' // Claims found but no reliable data available
}

/**
 * 🏛 v10.0: Analysis Error State
 */
export enum ErrorState {
  FAILED = 'FAILED'
}


export enum ClaimNature {
  FACTUAL = 'FACTUAL',
  OPINION = 'OPINION',
  PREDICTION = 'PREDICTION',
  THEORY = 'THEORY',
  BELIEF = 'BELIEF',
  SATIRE = 'SATIRE'
}

export enum FramingStyle {
  HEDGED = 'HEDGED',
  BALANCED = 'BALANCED',
  ASSERTIVE = 'ASSERTIVE',
  ABSOLUTE = 'ABSOLUTE',
  MANIPULATIVE = 'MANIPULATIVE'
}

export enum EvidenceLevel {
  STRONG = 'STRONG',
  MODERATE = 'MODERATE',
  WEAK = 'WEAK',
  NONE = 'NONE',
  CONTRADICTED = 'CONTRADICTED',
  INSUFFICIENT = 'INSUFFICIENT',  // v10.5: sources found but below quality threshold
}

export type AnalysisFailureReason = 
  | "AI_CAPACITY"
  | "TIMEOUT"
  | "NO_CLAIMS"
  | "LOW_INFORMATION"
  | "UNSUPPORTED_LANGUAGE"
  | "UNKNOWN_ERROR";

export interface TranscriptData {
  text: string;
  utterances: Utterance[];
  segments?: Segment[]; // AssemblyAI segments or fixed chunks
  language: string;
  confidence: number;
  duration: number; // Duration in seconds
}

export interface Utterance {
  start: number;
  end: number;
  speaker?: string;
  text: string;
}

export interface FactCheckJob {
  videoId: string;
  userId: string;
  transcript: TranscriptData;
  language: string;
  status: 'pending' | 'extracting' | 'verifying' | 'scoring' | 'completed' | 'failed';
  createdAt: number;
  updatedAt: number;
  progress: number;
  error?: string;
}

export interface ExtractedClaim {
  text: string;
  nature: ClaimNature;
  framing: FramingStyle;
  speaker?: string; // Diarization label: Speaker A, Speaker B, etc.
  confidence: number;
  importance: number; // 0-1 scale of impact on core message
  isVerifiableEvent?: boolean; // v5.2: LLM-flagged factuality (language-agnostic)
  assertiveness?: ClaimAssertiveness;
  claimStrength?: ClaimStrength;
  honestyWashingRisk?: boolean; // v8.1
  start?: number;
  end?: number;
  chunkIndex: number;
}

export interface FilteredClaim extends ExtractedClaim {
  claimId: string;
}

export type SourceTier = 'A' | 'B' | 'C' | 'D';

export interface RichSource {
  title: string;
  url: string;
  domain?: string;
  publishedAt?: string;
  tier: SourceTier;
  snippet?: string; // Stored in full.json only
}

export type ClaimType = 
  | 'empirical'      // Factual/Scientific
  | 'historical'     // Documented history
  | 'doctrinal_metaphysical' // Pure theology/philosophy (Faith)
  | 'scriptural_citation'    // References to books/verses
  | 'epical_traditional'     // Faith figures in history (Rama, Moses)
  | 'mythological'   // Legends
  | 'philosophical'  // Abstract logic
  | 'pseudo_scientific' // False empirical
  | 'satirical'      // Parody
  | 'opinion'        // Subjective judgment/preference
  | 'anecdotal_experience' // Personal experience/testimony
  | 'speculation'    // Futures
  | 'unclear';

export type ClaimSeverity = 'low' | 'medium' | 'high' | 'extreme';
export type ClaimAssertiveness = 'casual' | 'moderate' | 'confident' | 'authoritative' | 'absolute';
export type ClaimStrength = 'hedged' | 'moderate' | 'strong' | 'absolute';

export type ClaimStatus = 
  | "correct" 
  | "mostly_correct"               // NEW: Broadly true but approximate (numbers, dates, durations)
  | "incorrect" 
  | "outdated"                      // NEW: Was true but time-sensitive and stale
  | "unsupported"                   // NEW: No evidence found (NOT the same as false)
  | "unverified"                    // v5.0: No verification was attempted
  | "needs_context"                 // NEW: True only in specific context
  | "unverifiable" 
  | "faith_based"     // v4.1 Faith-based claim
  | "faith_context"   // spiritual context
  | "tradition_linked"              // sacred geography/history
  | "historical_tradition" 
  | "historical_consensus_denial" 
  | "incorrect_citation" 
  | "contested_interpretation" 
  | "opinion" 
  | "anecdotal_experience"           // Personal testimony/experience
  | "value_judgment"                // "This is terrible/great"
  | "preference_statement"           // "I like/don't like"
  | "unverifiable_personal_claim"    // "I got a headache from this"
  | "satire"
  | "speculation"
  | "developing_story";

export interface VerifiedClaim extends FilteredClaim {
  status: ClaimStatus; // Pipeline state
  evidenceLevel?: EvidenceLevel; // Epistemic classification
  speaker?: string; // Explicitly added to ensure visibility in v5
  verificationConfidence: number;
  reasoning: string;
  sources?: string[]; // Legacy / Concatenated
  richSources?: RichSource[]; // Production rich links
  isGrounded?: boolean;
  freshnessScore?: number;
  importance: number; // 0-1 scale of impact on core message
  severity?: ClaimSeverity; // Degrees of wrongness
  evidenceConfidence?: number; // 0-1 weight from SourceTier
  ontology?: ClaimType; // Legacy truth domain
  trueAsOf?: string; // YYYY-MM-DD anchor for factual validity

  // v5.2: Live Grounding Engine Fields
  claimType?: ClaimType;
  assertiveness?: ClaimAssertiveness;
  claimStrength?: ClaimStrength;
  rating?: number;
  freshness?: string;
  verificationSummary?: string;
  verifiedFacts?: string[];
  missingEvidence?: string[];
  sourceConsensus?: string;
  riskLevel?: string;
  publicNote?: string;
  recommendedAction?: string;
  timedOutAt?: number;   // v10.6: set when claim timed out, cleared after retry conversion
}

export interface UIDriver {
  text: string;
  impact: 'high' | 'medium';
}

export interface UISource {
  title: string;
  url?: string;
  domain?: string;
  trustLevel: 'High' | 'Medium' | 'Low';
  type: 'Primary' | 'Secondary' | 'Supporting';
}

export interface SynthesisOutput {
  verifiedFacts: {
    claimId: string;
    text: string;       // Direct finding from verification ledger
    evidenceLevel: EvidenceLevel;
  }[];
  modelInterpretations: {
    text: string;       // Analytical logic about speaker structure — not fact-checked
    basis: string;      // Which structural signal this is based on
  }[];
  uncertainInferences: {
    text: string;       // Speculative points where data is missing
    missingDataReason: string;
  }[];
  narrative: string;     // Grounded clinical narrative
}

export interface TraceabilityMap {
  [sentenceHash: string]: string[]; // Maps each narrative sentence to claimId[]
}

export interface UIReport {
  summary: {
    rating: number | null;
    truthScore?: number | null;      // v10.0
    honestyScore?: number | null;    // v10.0
    rationalityScore?: number | null; // v10.0
    label: string;
    confidence: 'high' | 'medium' | 'low';
    confidenceInterpretation: string; // v8.5
    rationalityContributedToComposite?: boolean; // v10.0
    analysisState: VerificationState | ErrorState; // v10.0: Migration from AnalysisState
    verificationState?: VerificationState; // v10.0
    evidenceCoverage: {
      checked: number;
      total: number;
      label: string;   // e.g. "3 of 10 claims verified"
    } | null;          // null for STRUCTURAL_ONLY state
  };
  quickVerdict: string;
  narrative: string;
  riskNote: string;
  positiveDrivers: UIDriver[];
  negativeDrivers: UIDriver[];
  sources: UISource[];
  conclusion: string;
  recommendation?: string; // v8.5
  disclaimer?: string;     // v8.5
  counterSignals?: string[]; // v8.5
  reviewRequestEnabled?: boolean; // v10.0
  claimResults: {
    claimId: string;
    text: string;
    status: ClaimStatus;
    evidenceLevel: EvidenceLevel;
    publicNote: string;
    sources: {
      title: string;
      url: string;
      domain: string;
      tier: SourceTier;
      snippet: string;
      publishedAt?: string;
    }[];
    sourceConsensus: string;
    recommendedAction: string;
  }[];
}

/**
 * 🧠 v10.0: Synthesis Result Layer
 * Explicit structure for evidence-bounded synthesis.
 */
export interface SynthesisResult {
  summary: string;
  conclusion: {
    label: string;
    text: string;
    confidence: number;
  };
  hallucinationIsolation: {
    verifiedFacts: string[];
    modelInterpretations: string[];
    uncertainInferences: string[];
  };
  traceabilityMap: Record<string, string[]>;
  knowledgeDensity: number;
  keyThemes: string[];
  viewerNote: string;
  manipulationScore: number;
  manipulationSignals: string[];
  chapters: TrustChapter[];
  speakerRoles: Record<string, string>;
  pipelineMode?: string;
  speakerCount?: number;
  speakerIdentities?: Record<string, any>;
  extractionError?: string;
  consistencyFactor?: number;
  consensusFactor?: number;
  filteringReasons?: string[];
  contentIntent?: any;
  speakerPriors?: Record<string, any>;
  isLaunchNews?: boolean;
  launchGrounded?: boolean;
}

export interface FactCheckResult {
  videoId: string;
  userId: string;
  scoringVersion: string;
  transcript: TranscriptData;
  analysisState: VerificationState | ErrorState;      // v10.0 Migration
  scoreAvailable: boolean;           // v8.2: UI guard
  analysisFailureReason?: AnalysisFailureReason; // v8.2: Structured failure
  viewerNote?: string;               // v8.2: Dynamic message
  uiReport?: UIReport;               // v8.3: Human-friendly UI format
  
  trustScore: number | null;         // 0-100 institutional score (null = not evaluated)
  videoRating?: number;              // v4.2 Public score mapping (0-10)
  truthScore?: number | null;        // v8.5 Public Truth score (0-100)
  honestyScore?: number | null;      // v8.5 Public Honesty score (0-100)
  rationalityScore?: number | null;  // v8.5 Public Rationality score (0-100)
  structuralReliabilityScore?: number | null; // v10.0: Structural-only composite
  compositeRating?: number | null;   // v8.5 Normalized public rating (0-10)
  
  verificationState?: VerificationState; // v10.0
  
  trustLabel: TrustLabel;            // Highly Reliable | Reliable | Mixed | Low | Misleading
  confidence: number;                // 0.0-1.0 confidence score
  confidenceTier: 'high' | 'medium' | 'low';
  confidenceNotes?: string[];
  diagnostics?: string[];
  vertical?: TrustVertical;
  verticalScores?: Record<TrustVertical, number>;
  reviewTriggered?: boolean;
  reviewReason?: string;
  sourceLedger?: Record<string, string>;
  contentIntent?: {
    primaryIntent: string;
    intentScores?: Record<string, number>;
    confidence: number;
    subjectiveRatio: number;
    promotionalSignals: string[];
    ratingFloor: number;
    ratingCeiling: number;
    genre?: string; // v5.0
  };
  
  factors: InstitutionalTrustFactors | null; // v8.2: Null if state != COMPLETE/PARTIAL
  chapters: TrustChapter[];
  speakers: SpeakerBreakdown[];
  speakerIdentities?: Record<string, { id: string, name: string, confidence: number }>; // v7
  claims: VerifiedClaim[];
  
  // v10.0: Hallucination Isolation Layer
  synthesisOutput?: SynthesisOutput;
  traceabilityMap?: TraceabilityMap;
  
  factCheckStats: {
    totalClaims: number;
    extractedClaims: number;
    evaluatedClaims: number;
    correct: number;
    mostly_correct: number;
    incorrect: number;
    unsupported: number;
    unverifiable: number;
    ignored: number;
    faith: number; // v4.1: Faith-based claims tracking
    checkedClaimsRatio?: number; // v5.0: transparency metric
  };
  
  scoringMethod: 'strict' | 'balanced';
  synthesisTier: 'standard' | 'deep' | 'podcast';
  deepResearchMetrics?: {
    claimsAttempted: number;
    claimsGrounded: number;
    totalSourcesFound: number;
    uniqueDomainsFound: number;
    tierASourceCount: number;
    tierBSourceCount: number;
    batchesCompleted: number;
    batchesTimedOut: number;
    estimatedCostUsd: number;
  };
  isLongform: boolean;
  isFinal: boolean;
  isLaunchNews?: boolean;   // v5.0
  launchGrounded?: boolean; // v5.0
  extractionError?: string; // v5.2
  speakerCount?: number;    // v5.3
  detectedLanguage?: string; // v7.2
  
  generatedAt: number;
  verifiedAsOf: string;
  language: string;
  riskDomain: string;
  domainRiskMultiplier: number;
  
  reputationModifier?: number; // expertise/history impact
  recalculateAt?: number;
  
  // v5.1: Transparency & Creator Feedback
  deductions: TrustDeduction[];
  
  // v8.0: Category-Aware Epistemic Scoring
  videoCategory?: string;                         // from upload metadata
  categoryWeightProfile?: Record<string, number>;  // which weights were used
  honestyBreakdown?: HonestyBreakdown;             // sub-components of honesty dimension
  contextualFlags?: ContextualFlag[];              // multi-perspective debated topics
  harmCapApplied?: boolean;                        // whether safety cap was enforced
  harmCapReason?: string;                          // explanation for the cap
  rawScoreBeforeCap?: number;                      // pre-cap score for transparency
  penaltyApplied?: number;                         // total points deducted from penalties
  
  // v8.1 Hardened Trust (Stable)
  hardeningMetadata?: HardeningMetadata;           // Structured logs for regulators
  intentToMisleadScore?: number;                   // Strategic manipulation (0-100)
  effectiveCategory?: string;                      // Risk-hierarchy resolved category
  
  // v10.6: Verification Quality Signals
  reanalysisAvailable?: boolean;                   // true when >30% of claims timed out — UI shows "Re-analyze"
  
  // v11.0: Production Hardening & Scale Readiness
  evaluationHealth?: {
    extractedClaims: number;
    factualRouted: number;
    evaluatedClaims: number;
    claimReachRatio: number;    // factualRouted / extractedClaims
    evaluationRatio: number;    // evaluatedClaims / factualRouted
    healthStatus: 'healthy' | 'degraded' | 'critical';
  };
  repairSuggestions?: RepairSuggestion[];
  consistencyIssues?: ConsistencyIssue[];

  versions: {
    model: string;
    scoring: string;
    registry: string;
  };
}

/**
 * v11.0: Actionable repair suggestions for creators.
 * Each suggestion targets a specific claim and explains how to improve the score.
 */
export interface RepairSuggestion {
  claimId: string;
  type: 'factual_error' | 'missing_source' | 'verification_timeout' | 'hedging_needed' | 'outdated_info';
  severity: 'low' | 'medium' | 'high' | 'info';
  currentText: string;
  suggestion: string;
  impactEstimate: string;
}

/**
 * v11.0: Traceable consistency issues between claims.
 * Makes the consistency score auditable instead of opaque.
 */
export interface ConsistencyIssue {
  claim1: string;
  claim2: string;
  type: 'contradiction' | 'mixed_accuracy' | 'temporal_inconsistency';
  severity: 'low' | 'medium' | 'high';
}

export interface TrustDeduction {
  factor: keyof InstitutionalTrustFactors | 'intent' | 'reputation' | 'harm_cap';
  points: number; // Amount lost on 10.0 scale (e.g., 1.5)
  reason: string;
}

export type TrustLabel = 
  | "High Credibility"
  | "Generally Credible"
  | "Mixed Credibility"
  | "Low Evidence Support"
  | "Significant Concerns"
  | "Safety Capped – Significant Concerns"
  | "Confidence Evolving"
  | "Analysis Unavailable"
  | "Limited Analysis"
  | "No Verifiable Claims"
  | "Not Applicable"
  | "Casual Educational Media"
  | "Reliable Promotion"
  | "Promotional – Verify Independently"
  | "Misleading Promotion"
  | "Well-Supported Opinion"
  | "Editorial – Mixed Support"
  | "Poorly Supported Opinion"
  | "Trusted Testimonial"
  | "Testimonial – Unverified"
  // v5.1 Political/Legal Commentary Labels
  | "In-Depth Legal/Political Inquiry"
  | "Commentary – Mixed Detail"
  | "Poorly Supported Commentary"
  // v5.0 Honesty Labels
  | "Unverified – Insufficient Data"
  | "No Factual Claims"
  // v8.2 Epistemic State Labels
  | "Analysis Unavailable"
  | "Limited Analysis"
  | "Not Applicable"
  | "Analysis in Progress"
  // v8.0 Category-Aware Labels
  | "Faithfully Presented"           // Religion with high honesty
  | "Misleading Framing"             // Low honesty (belief as fact)
  | "Safety Capped – Verify Claims"; // Harm cap applied

export interface HardeningMetadata {
  truthFloorApplied: boolean;
  truthFloorReason?: string;
  domainOverride: {
    triggered: boolean;
    from?: string;
    to?: string;
    penalty: number;
    riskDelta: number;
  };
  consensusGateTriggered: boolean;
  intentToMisleadScore: number; // 0-100
  penalties: { type: string; value: number }[];
  auditTimestamp: string;
}


export interface InstitutionalTrustFactors {
  accuracy: number | null;     // Factual correctness of verifiable claims
  evidence: number | null;     // Source quality and citation strength
  consensus: number;    // Alignment with expert/institutional consensus
  consistency: number;  // Internal logical consistency
  integrity: number;    // Absence of manipulation / deceptive framing
  expertise: number;    // Creator credentials for the domain
  freshness: number;    // Information recency
  safety: number;       // Harm potential (inverted — 100 = safe)
  honesty: number;      // v8.0: Framing transparency (belief as belief, opinion as opinion)
  rationality?: number;  // v8.5: Internal logic and manipulation resistance
  reputation?: number;   // v8.8: Historical reliability score
  intentToMislead?: number; // v8.1: Gaming/manipulation detection (0-100)
}

export type TrustVertical = 'general' | 'finance' | 'health' | 'religion' | 'history' | 'politics';

// ============================================
// v8.0: CATEGORY-AWARE EPISTEMIC SCORING TYPES
// ============================================

export type VideoCategory =
  | 'science'
  | 'science_trivia'
  | 'health'
  | 'news'
  | 'politics'
  | 'history'
  | 'religion'
  | 'culture'
  | 'education'
  | 'opinion'
  | 'podcast'
  | 'entertainment'
  | 'unknown';

export interface ContextualFlag {
  topic: string;
  claimText: string;
  perspectives: {
    label: string;
    explanation: string;
    sources?: string[];
  }[];
  aiNote: string;
  confidence?: number;
}

export interface HonestyBreakdown {
  score: number;                      // 0–100 (v8.8 synchronized)
  opinionLabeledOpinion: number;      // count of correctly framed opinions
  beliefLabeledBelief: number;        // count of correctly framed beliefs
  beliefPresentedAsFact: number;      // count of violations (belief → authoritative)
  opinionPresentedAsFact: number;     // count of violations
  speculationLabeledSpeculation: number;
  assertivenessMismatchPenalty: number; // total points lost from mismatches
}

export interface HarmCapResult {
  applied: boolean;
  reason?: string;
  originalScore?: number;
  cappedScore?: number;
}

export interface CategoryWeightProfile {
  category: VideoCategory;
  weights: InstitutionalTrustFactors;
  falsehood_penalty: number;           // per verified-false claim (negative)
  misleading_penalty: number;          // per misleading/needs_context claim (negative)
  harm_cap: number | null;             // null = no cap; number = max final score
  harm_cap_severity: ClaimSeverity[];  // which severities trigger the cap
}

export interface FactCheckDocument {
  videoId: string;
  userId: string;
  honestRating: number;
  factCheck: {
    totalClaims: number;
    evaluatedClaims: number;
    correct: number;
    incorrect: number;
    unverifiable: number;
    ignored: number;
  };
  claims: {
    text: string;
    status: 'correct' | 'incorrect' | 'unverifiable';
    confidence: number;
    start?: number;
    end?: number;
    reasoning?: string;
  }[];
  createdAt: number;
  updatedAt: number;
  language: string;
  scoringMethod: string;
}

import { z } from 'zod';

export const GeminiExtractionSchema = z.object({
  claims: z.array(z.object({
    text: z.string(),
    nature: z.string(), // FACTUAL | OPINION | PREDICTION | THEORY | BELIEF | SATIRE
    framing: z.string(), // HEDGED | BALANCED | ASSERTIVE | ABSOLUTE | MANIPULATIVE
    confidence: z.number(),
    importance: z.number().optional().default(0.5),
    isVerifiableEvent: z.boolean().optional().default(true),
    honestyWashingRisk: z.boolean().optional().default(false),
    assertiveness: z.string().optional().default('moderate'),
    claimStrength: z.string().optional().default('moderate')
  })),
  summary: z.string()
});

export const GeminiIntelligenceSchema = z.object({
  summary: z.string(),
  conclusion: z.object({
    label: z.string(),
    text: z.string(),
    confidence: z.number()
  }),
  knowledgeDensity: z.number().optional(),
  keyThemes: z.array(z.string()),
  viewerNote: z.string(),
  chapters: z.array(z.object({
    index: z.number(),
    title: z.string(),
    start: z.number(),
    end: z.number(),
    videoRating: z.number(), // Replaces trustIndex
    primaryTopics: z.array(z.string())
  })).optional()
});

export const GeminiVerificationSchema = z.object({
  verifications: z.array(z.object({
    claimId: z.string(),
    claim: z.string(),
    claimType: z.enum(['empirical', 'historical', 'doctrinal_metaphysical', 'scriptural_citation', 'epical_traditional', 'mythological', 'philosophical', 'pseudo_scientific', 'satirical', 'opinion', 'anecdotal_experience', 'speculation', 'unclear']),
    label: z.string(),
    evidenceLevel: z.string(), // STRONG | MODERATE | WEAK | NONE | CONTRADICTED
    rating: z.number(),
    confidence: z.number(),
    freshness: z.string(),
    summary: z.string(),
    verifiedFacts: z.array(z.string()),
    missingEvidence: z.array(z.string()),
    sourceConsensus: z.string(),
    riskLevel: z.string(),
    publicNote: z.string(),
    recommendedAction: z.string()
  }))
});

export interface FactCheckConfig {
  extractionChunkDuration: number;
  claimsPerBatch: number;
  confidenceThreshold: number;
  maxGeminiCalls: number;
  scoringMethod: 'strict' | 'balanced';
  enableDoubleCheck: boolean;
  enableWebSearch: boolean;
  claimBatchSize: number;
  verificationTier: 'standard' | 'deep' | 'pro';
  constraintBasedVerification: boolean; // v10.0: prohibit model training data in fact checks
}

// ============================================
// LAYER ARCHITECTURE TYPES
// ============================================

export interface EdgeResponse {
  jobId: string;
  status: 'accepted' | 'rejected';
  message: string;
  estimatedTime?: number;
  trackingUrl?: string;
}

export interface ProgressiveStatus {
  jobId: string;
  overall: number;
  stages: {
    transcription: StageStatus;
    credibility: StageStatus;
    dubbing?: StageStatus;
    aggregation?: StageStatus;
    [key: string]: StageStatus | undefined; // Allow dynamic stages
  };
  partialResults?: Partial<AggregatedOutput>;
  
  // ETA UI Support
  etaSeconds?: number;
  etaMin?: number;
  etaMax?: number;
  etaMode?: "cold" | "stable" | "high-variance";
  estimatedCompletionAt?: number;
}

export interface StageStatus {
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  progress: number;
  startedAt?: number;
  completedAt?: number;
  error?: string;
}


export interface UserConfig {
  userId: string;
  channelType: ChannelType;

  languages: string[];
  dubbingMode: 'none' | 'standard' | 'voice_clone';
  genLangSubs: boolean;
  generateDubbing: boolean;
  enableFactCheck: boolean;
  priority: 'low' | 'normal' | 'high';
  duration?: number; // duration in seconds
}

export interface ExecutionPlan {
  jobId: string;
  enablePath1: boolean;      // Legacy
  enablePath2: boolean;      // Legacy
  enableTruthEngine: boolean; // Strategic alias for Path 1
  enableReachEngine: boolean; // Strategic alias for Path 2
  enableAuxiliary: boolean;
  languages: string[];
  dubbingMode: 'none' | 'standard' | 'voice_clone';
  translationModel?: 'standard' | 'premium' | 'dynamic';
  toneMode?: 'casual' | 'formal';
  localeStyle?: 'neutral' | 'hinglish' | 'hinglish_urban' | 'hinglish_professional' | 'slang';
  targetPlatform?: 'youtube' | 'reels' | 'shorts' | 'linkedin' | 'tiktok';
  
  // v7: Creator Intelligence Input v2
  expectedSpeakerCount?: '1' | '2-3' | '4+' | 'not_sure';
  contentFormat?: 'solo' | 'interview' | 'podcast' | 'debate' | 'commentary' | 'general';
  primaryLanguage?: string; // v7.2: Skip auto-detection
  guestNames?: string[];    // v7.2: Persistent identity help
  sensitiveTopics?: ('health' | 'politics' | 'finance' | 'religion' | 'other')[]; // v7.2: Risk-aware scoring
  priorityMode?: 'speed' | 'balanced' | 'accuracy'; // v7.2: Pipeline depth control
  synthesisTier?: 'standard' | 'deep' | 'podcast';
  
  // v8.0: Category-Aware Scoring
  videoCategory?: string;      // Upload category mapped to scoring profile
  scoringProfile?: string;     // Override for custom scoring profiles
  
  creatorDNA?: CreatorDNA; // persistent style memory
  enableABHooks?: boolean; // generate 3 variants for first 10s
  generateDubbing: boolean;
  genLangSubs: boolean;
  channelType: ChannelType;
  autoChapters?: boolean;

  duration?: number;
  maxClaims: number;
  priority: 'low' | 'normal' | 'high';
  skipCache: boolean;
}

export interface CreatorDNA {
  vibe: 'energetic' | 'authoritative' | 'humorous' | 'educational' | 'controversial';
  slangTolerance: 'low' | 'medium' | 'high';
  vocabPreference: 'simple' | 'tech_heavy' | 'academic';
  customInstructions?: string;
}

export type ChannelType = 'standard' | 'custom';

export interface Channel {
  id: string;
  ownerId: string;
  handle: string; // @name
  displayName: string;
  about?: string;
  type: ChannelType;
  outstandingCosts: number;
  hasPaidSubscriptionBuyout: boolean;
  createdAt: number;
  updatedAt: number;
  profile: {
    photoUrl?: string;
    coverUrl?: string;
    category: string;
    about?: string;
    links?: Record<string, string>;
  };
  stats: {
    videoCount: number;
    avgTrustIndex: number;
    subscriberCount: number;
    viewCount: number;
  };
  settings: {
    adsEnabled: boolean;
    adsRevenueShare: number;
    memberRevenueShare: number;
    locale: string;
    defaultPlatform: string;
  };
  limits: {
    maxDurationSec: number;
    maxChannels: number;
  };
}




export type EventType =
  | 'video-uploaded'
  | 'transcription-complete'
  | 'fact-processing'
  | 'dubbing-processing'
  | 'fact-complete'
  | 'dubbing-complete'
  | 'aggregation-ready'
  | 'resolution-requested';

export interface PipelineEvent<T = Record<string, any>> {
  eventId: string;
  eventType: EventType;
  jobId: string;
  userId: string;
  timestamp: number;
  data: T;
  retryCount: number;
  source: string;
  traceId?: string; // For event correlation across stages
}

export interface TranscriptionCompleteData {
  transcriptPath: string;
  language: string;
  confidence: number;
  wordCount: number;
  duration: number;
  speakerCount: number;
  executionPlan: ExecutionPlan;
}

export interface FactCompleteData {
  honestRating: number | null;
  claimsEvaluated: number;
  correct: number;
  incorrect: number;
  unverifiable: number;
  resultPath: string;
}

export interface DubbingCompleteData {
  languages: string[];
  subtitlePaths: Record<string, string>;
  dubbedVideoPaths: Record<string, string>;
  audioPaths: Record<string, string>;
}

export interface EnhancedTranscriptionResult {
  jobId: string;
  language: string;
  detectedLanguage: string;
  text: string;
  confidence: number;
  speakerConfidence?: number;
  words: WordTimestamp[];
  segments: TimedSegment[];
  speakers: SpeakerInfo[];
  chapters?: Array<{
    startTimeMs: number;
    endTimeMs: number;
    title: string;
    summary: string;
  }>;
  duration: number;
}

export interface WordTimestamp {
  text: string;
  start: number;
  end: number;
  confidence: number;
  speaker?: string;
}

export interface TimedSegment {
  index: number;
  text: string;
  start: number;
  end: number;
  duration: number;
  speaker?: string;
  isHook?: boolean;
  words: WordTimestamp[];
}

export interface SpeakerInfo {
  speakerId: string;
  label: string;
  totalDuration: number;
  segments: number[];
}

// ClaimStrength removed here - using v8.1 definition above

export type CredibilityErrorCode = 
  | 'TRANSCRIPT_EMPTY'
  | 'CLAIM_EXTRACTION_FAILED'
  | 'VERIFICATION_FAILED'
  | 'JSON_PARSE_FAILED'
  | 'GEMINI_FAILURE'
  | 'INSUFFICIENT_DATA'
  | 'AI_CAPACITY_EXCEEDED'; // v5.2

export class ExtractionError extends Error {
  constructor(public code: CredibilityErrorCode, message: string) {
    super(message);
    this.name = 'ExtractionError';
  }
}

// End of types.ts

export interface EnhancedClaim extends ExtractedClaim {
  claimStrength: ClaimStrength;
  importance: number;
  speaker?: string;
  context?: string;
}

export interface ExplainabilityResult {
  claimId: string;
  claim: string;
  status: ClaimStatus;
  ontology?: ClaimType;
  whyWrong?: string;
  correction?: string;
  sources: SourceReference[];
  timestampStart: number;
  timestampEnd: number;
  confidence: number;
  severity?: ClaimSeverity;
  severityLabel?: string;
}

export interface SourceReference {
  title: string;
  url?: string;
  snippet: string;
  relevanceScore: number;
  tier?: SourceTier;       // v5.0: Evidence provenance
  provenance?: string;     // v5.0: Source description (e.g. "News Archive")
}

export interface TrustIndexFactors {
  accuracy: number;     
  evidence: number;     
  consensus: number;
  consistency: number;  
  integrity: number;    
  expertise: number;    
  freshness: number;    
  safety: number;       
}

export interface SpeakerBreakdown {
  speakerId: string;
  label: string;
  role?: string; // v5.3: Host, Guest, Expert, etc.
  trustIndex: number;
  wordCount: number;
  claimCount: number;
}

export interface TrustChapter {
  index: number;
  title: string;
  start: number;
  end: number;
  videoRating: number;
  primaryTopics: string[];
}

export interface CredibilityResult {
  analysisState: VerificationState | ErrorState;      // v8.2: Epistemic state layer
  scoreAvailable: boolean;           // v8.2: UI guard
  analysisFailureReason?: AnalysisFailureReason; // v8.2: Structured failure
  viewerNote?: string;               // v8.2: Dynamic message
  uiReport?: UIReport;               // v8.3: Human-friendly UI format

  trustScore: number | null;
  trustLabel: TrustLabel;
  confidence: number;
  confidenceTier: 'high' | 'medium' | 'low';
  
  factors: InstitutionalTrustFactors | null;
  chapters: TrustChapter[];
  speakers: SpeakerBreakdown[];
  claims: ExplainabilityResult[];
  
  speakerIdentities?: Record<string, { id: string, name: string, confidence: number }>; // v7
  
  factCheckStats: {
    totalClaims: number;
    extractedClaims: number;
    evaluatedClaims: number;
    correct: number;
    mostly_correct: number;
    incorrect: number;
    unsupported: number;
    unverifiable: number;
    filtered: number;
    cacheHitRate?: number;
    checkedClaimsRatio?: number; // v5.0: transparency metric
  };
  videoRating?: number; // v4.2 Public score
  contentIntent?: {
    primaryIntent: string;
    intentScores?: Record<string, number>;
    confidence: number;
    subjectiveRatio: number;
    promotionalSignals: string[];
    ratingFloor: number;
    ratingCeiling: number;
    genre?: string; // v5.0
  };
  filteringReasons: string[];
  
  // v5.1: Transparency & Creator Feedback
  deductions?: TrustDeduction[];
  
  // v8.0: Category-Aware Epistemic Scoring
  videoCategory?: string;
  categoryWeightProfile?: Record<string, number>;
  honestyBreakdown?: HonestyBreakdown;
  contextualFlags?: ContextualFlag[];
  harmCapApplied?: boolean;
  harmCapReason?: string;
  rawScoreBeforeCap?: number;
  penaltyApplied?: number;
  
  // v8.1 Hardened Trust (Stable)
  hardeningMetadata?: HardeningMetadata;           // Structured logs for regulators
  intentToMisleadScore?: number;                   // Strategic manipulation (0-100)
  effectiveCategory?: string;                      // Risk-hierarchy resolved category
  
  scoringMethod: 'strict' | 'balanced';
  synthesisTier: 'standard' | 'deep' | 'podcast';
  isLongform: boolean;
  isFinal: boolean;         // Preliminary vs Final
  
  summary?: string;
  conclusion?: {
    label: string;
    text: string;
    confidence: number;
  };
  
  keyThemes?: string[];
  domain?: string;
  isLaunchNews?: boolean;
  launchGrounded?: boolean; // v5.0
  extractionError?: string; // v5.2
  speakerCount?: number;    // v5.3
  detectedLanguage?: string; // v7.2
  manipulationScore?: number;
  trustIndexFormatted?: string; // For UI confidence bands
  isAppealed?: boolean;
  appealStatus?: 'none' | 'pending' | 'reviewed' | 'resolved';
  diagnostics?: string[]; // v4.0 - Actionable repair tips
  sourceLedger?: Record<string, string>; // Mapping of claim text to verification source
  verifiedAsOf?: string;
  verifiedAt: number;
  processingTime: number;
  vertical?: TrustVertical;
  verticalScores?: Record<TrustVertical, number>; // v4.1.1 Multi-label
  confidenceNotes?: string[]; // 3-bullet summary
  reviewTriggered?: boolean;
  reviewReason?: string;
  scoreDrivers?: string[];
  knowledgeDensity?: number;

  telemetry: {
    transcriptLoaded: boolean;
    utteranceCount: number;
    claimsExtracted: number;
    verificationCompleted: boolean;
    claimsVerified?: boolean; // v10.0
    verificationPipelineCompleted?: boolean; // v10.0
    summaryGenerated: boolean;
    consistencyCheckCompleted: boolean;
    checkedClaimsRatio?: number; // v5.0
  };

  versions: {
    model: string;
    scoring: string;
    registry: string;
  };

  llmProvider?: string;
  sttProvider?: string;
  errorCode?: CredibilityErrorCode;
  language?: string;

  latencyMs?: {
    extraction: number;
    verification: number;
    consistency: number;
    synthesis: number;
    total: number;
  };

  // v11.0: Production Hardening fields
  evaluationHealth?: {
    extractedClaims: number;
    factualRouted: number;
    evaluatedClaims: number;
    claimReachRatio: number;
    evaluationRatio: number;
    healthStatus: 'healthy' | 'degraded' | 'critical';
  };
  repairSuggestions?: RepairSuggestion[];
  consistencyIssues?: ConsistencyIssue[];
}

export interface DubbingSegment {
  index: number;
  originalText: string;
  translatedText: string;
  language: string;
  start: number;
  end: number;
  targetDuration: number;
  speaker?: string;
  confidence?: number;
  isHook?: boolean; // first 10s of video
}

export interface SyncInstruction {
  segmentIndex: number;
  speedFactor: number;
  silenceBefore: number;
  silenceAfter: number;
  originalDuration: number;
  targetDuration: number;
}

export interface DubbingResult {
  jobId: string;
  language: string;
  subtitleUrl: string;
  subtitleFormat: 'srt' | 'vtt';
  audioUrl: string;
  videoUrl: string;
  translationUrl?: string;
  segments: number;
  processingTime: number;
  meta?: {
    voice?: string;
    durationSec: number;
  };
}

// ============================================
// ARTIFACT REGISTRY TYPES
// ============================================

export interface TranscriptionArtifacts {
  jsonUrl?: string;
  srtUrl?: string;
  vttUrl?: string;
  sourceLanguage?: string;
}

export interface LanguageArtifacts {
  status: "completed" | "processing" | "failed";
  translationUrl?: string;
  audioUrl?: string;
  videoUrl?: string;
  subtitleUrl?: string;
  dubbedLanguage?: string;
  meta?: {
    segments: number;
    durationSec: number;
    voice?: string;
  };
}

export interface ArtifactsMap {
  transcription?: TranscriptionArtifacts;
  languages?: Record<string, LanguageArtifacts>;
  subtitles?: Record<string, any>;
  dubbing?: Record<string, any>;
  audio?: Record<string, string>;
}

export interface VisualContext {
  jobId: string;
  frames: FrameAnalysis[];
  scenes: SceneInfo[];
  ocrTexts: OCRResult[];
  totalFramesAnalyzed: number;
  hasOnScreenText?: boolean;
}

export interface FrameAnalysis {
  timestamp: number;
  labels: string[];
  objects: string[];
  confidence: number;
}

export interface SceneInfo {
  sceneIndex: number;
  start: number;
  end: number;
  description: string;
  dominantLabels: string[];
}

export interface OCRResult {
  timestamp: number;
  text: string;
  confidence: number;
  boundingBox?: { x: number; y: number; width: number; height: number };
}

export interface AggregatedOutput {
  jobId: string;
  userId: string;
  videoUrl: string;
  trustScore: number;       // v3.0 Institutional Score
  trustLabel: TrustLabel;   // Highly Reliable | Reliable | etc.
  confidence: number;       // 0-1
  confidenceTier: 'high' | 'medium' | 'low';
  speakerConfidence?: number; // v5.3
  videoRating?: number;     // v4.2 Public score
  rating: number;           // LEGACY: trustIndex compatibility
  summary?: string;
  conclusion?: {
    label: string;
    text: string;
    confidence: number;
  };
  keyThemes?: string[];
  viewerNote?: string;
  domain?: string;
  isLaunchNews?: boolean;   // v5.0
  launchGrounded?: boolean; // v5.0
  vertical?: TrustVertical;
  verticalScores?: Record<TrustVertical, number>; // Added
  reviewTriggered?: boolean;
  reviewReason?: string;
  confidenceNotes?: string[];
  checkedClaimsRatio?: number; // v5.0
  speakerMetrics?: SpeakerBreakdown[]; // v5.0
  contentIntent?: {
    primaryIntent: string;
    confidence: number;
    subjectiveRatio: number;
    promotionalSignals: string[];
    genre?: string; // v5.0
  };
  verifiedAt?: number;
  factCheckUrl?: string; // v7.5: Direct link to GCS report
  diagnostics?: string[];   // v4.0 repair path
  claims: ExplainabilityResult[];
  chapters?: Array<{
    startTimeMs: number;
    endTimeMs: number;
    title: string;
    summary: string;
  }>;
  fullResultPath?: string;
  subtitles: Record<string, any>; // Support both native and generated metadata
  media: {
    subtitles: Record<string, string>;
    audioTracks: Record<string, string>;
    factCheckUrl?: string;
  };
  dubbedVideoUrl: string;
  dubbedVideos?: Record<string, any>;
  audioTracks?: Record<string, string>;
  artifacts?: ArtifactsMap;
  status: 'completed' | 'partial' | 'failed';
  processingTime: number;
  completedAt: number;
  cdnUrl?: string;
}

export interface AggregationState {
  jobId: string;
  factComplete: boolean;
  dubbingComplete: boolean;
  aggregated?: boolean;
  aggregationComplete?: boolean;
  completedAt?: number;
  factResult?: CredibilityResult;
  dubbingResults?: DubbingResult[];
  receivedAt: {
    fact?: number;
    dubbing?: number;
  };
}

export interface CreatorReputation {
  userId:           string;
  channelId:        string;
  channelRating:    number;             // v4.2 Public score
  trustScore:       number;             // 0-100 Aggregate
  trustLevel:       'elite' | 'high' | 'developing' | 'risk' | 'critical';
  
  // Aggregate Stats
  lifetimeClaims:   number;
  accurateCount:    number;
  nuanceCount:      number;             // mostly_correct + needs_context
  incorrectCount:   number;
  
  // Nuance Metrics
  accuracyRate:     number;             // accurateCount / lifetimeClaims
  nuanceRate:       number;             // nuanceCount / lifetimeClaims
  correctionRate:   number;             // How often they fix their own mistakes in follow-up videos
  drift:            number;             // v3.5 - Trajectory: change in score over last 3 videos
  trend:            'improving' | 'stable' | 'deteriorating';
  
  // Domain Specificity (Where are they most/least credible?)
  domainScores:     Record<string, number>;
  
  // Time-series (Monthly snapshots)
  history: Array<{
    month:          string;             // YYYY-MM
    avgScore:       number;
    videoCount:     number;
  }>;
  
  lastScores:       number[];           // last 5 video scores
  metadataReliability?: {               // v7.3: Field-specific trust breakdown
    speakerAccuracy: number;            // 0-1
    languageAccuracy: number;           // 0-1
    formatAccuracy: number;             // 0-1
    overall: number;                    // Composite score
  };
  updatedAt:        number;
}

export interface TrustAppeal {
  appealId:         string;
  jobId:            string;
  userId:           string;
  reason:           string;
  evidenceLinks?:   string[];
  status:           'pending' | 'under_review' | 'resolved' | 'rejected';
  reviewerId?:      string;
  resolutionNote?:  string;
  originalScore:    number;
  newScore?:        number;
  createdAt:        number;
  resolvedAt?:      number;
}

export interface GovernanceAuditLog {
  logId:            string;
  targetId:         string; // jobId or userId
  action:           'manual_override' | 'appeal_resolved' | 'weight_calibration' | 'threshold_update';
  performerId:      string; // admin/system
  previousValue:    any;
  newValue:         any;
  rationale:        string;
  timestamp:        number;
}

export interface TrustLedgerEntry {
  jobId:            string;
  timestamp:        number;
  overallScore:     number;
  accuracyRate:     number;
  claimsCount:      number;
  penalties:        number;
  topMisleading:    string[];           // IDs of major incorrect claims
}

export interface CacheEntry<T = any> {
  key: string;
  value: T;
  ttl: number;
  createdAt: number;
  hitCount: number;
  source: 'memory' | 'firestore';
}

export interface CostMetrics {
  jobId: string;
  geminiCalls: number;
  geminiTokens: number;
  ttsCalls: number;
  ttsCharacters: number;
  translationCalls: number;
  translationCharacters: number;
  cacheSavings: {
    geminiCallsAvoided: number;
    ttsCallsAvoided: number;
    translationCallsAvoided: number;
  };
  estimatedCostUsd: number;
}

export interface PerformanceConfig {
  maxClaimsPerType: Record<ChannelType, number>;

  cacheEnabled: boolean;
  cacheTTL: Record<string, number>;
  parallelWorkers: number;
  chunkDuration: number;
  priorityQueue: boolean;
}

export interface ScalingConfig {
  serviceName: string;
  minInstances: number;
  maxInstances: number;
  concurrency: number;
  cpu: number;
  memoryMb: number;
  timeoutSeconds: number;
}

export interface WorkerConfig {
  type: 'fact' | 'dubbing' | 'transcription' | 'aggregation';
  instances: number;
  queueName: string;
  deadLetterTopic: string;
  maxRetries: number;
  ackDeadline: number;
}

export interface HealthStatus {
  service: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  uptime: number;
  activeJobs: number;
  memoryUsage: number;
  lastCheck: number;
}

export interface CDNConfig {
  enabled: boolean;
  bucketName: string;
  cacheTTL: number;
  signedUrlExpiry: number;
  allowedOrigins: string[];
}
