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
    credibility: StageStatus; // Independent Credibility / Fact-Checking system
    dubbing?: StageStatus;    // Independent Dubbing / Localization system
    subtitles?: StageStatus;  // Independent Subtitles stage
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
  artifacts?: {
    transcription?: {
      audioUrl?: string;
      [key: string]: any;
    };
    mneValidation?: import("./services/media").MneValidationResult;
    [key: string]: any;
  };
}

export type IndependentSystemStatus = "pending" | "running" | "completed" | "failed" | "cancelled";

export interface CredibilityJobData {
  jobId: string;
  videoId?: string;
  userId: string;
  channelId?: string;
  videoUrl?: string;
  executionPlan: ExecutionPlan;
  status: IndependentSystemStatus;
  progress: number;
  retryCount?: number;
  error?: string;
  factCheckUrl?: string;
  rating?: number;
  startedAt?: number;
  completedAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface DubbingJobData {
  jobId: string;
  videoId?: string;
  userId: string;
  channelId?: string;
  videoUrl?: string;
  executionPlan: ExecutionPlan;
  status: IndependentSystemStatus;
  progress: number;
  error?: string;
  languages?: string[];
  subtitleLanguages?: string[];
  startedAt?: number;
  completedAt?: number;
  createdAt: number;
  updatedAt: number;
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
  emotionTag?: string;
  energyDb?: number;
  stabilityOverride?: number;
  similarityBoostOverride?: number;
  pitchRangeSemitones?: number;
  voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
  emotionalIntensity?: {
    anger?: number;
    sadness?: number;
    joy?: number;
    fear?: number;
    disgust?: number;
    surprise?: number;
  };
  energyEnvelopePattern?: "rising" | "falling" | "flat" | "dynamic";
  breathingPattern?: "natural" | "rapid" | "suppressed";
  syllableBudgetCompliance?: number;
  isHook?: boolean;
  variants?: {
    viral: string;
    safe: string;
    professional: string;
  };
  terminologyWarning?: string;
  terminologyViolations?: Array<{
    termId: string;
    source: string;
    disallowedFound: string;
    suggested: string;
    context?: string;
  }>;
  terminologyComplianceRate?: number;
  numericalParityVerified?: boolean;
  numericalParityWarning?: string;
  semanticParityScore?: number;
  reviewRecommended?: boolean;
  polarityFlipped?: boolean;
}

export interface TTSRequest {
  jobId: string;
  language: string;
  text: string;
  voiceId?: string;
  speakerId?: string;
  userId?: string;
  provider?: "google-cloud-tts" | "elevenlabs" | "auto";
  preferVoiceCloning?: boolean;
  voiceCloneId?: string;
  ttsTier?: "audio_track";
  voiceType?: "standard" | "fast_api" | "cloned" | "voice_clone";
  gender?: "MALE" | "FEMALE" | "NEUTRAL";
  speakingRate?: number;
  pitch?: number;
  stability?: number;
  similarityBoost?: number;
  style?: number;
  useSpeakerBoost?: boolean;
  emotionTag?: string;
  energyDb?: number;
  pronunciationGlossary?: PronunciationRule[];
  previousText?: string;
  nextText?: string;
}

export interface TTSResult {
  jobId: string;
  language: string;
  audioUrl: string;
  duration: number;
  format: string;
  provider?: "google-cloud-tts" | "elevenlabs";
  voiceName?: string;
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
  INSUFFICIENT_EVIDENCE = 'INSUFFICIENT_EVIDENCE', // Claims found but no reliable data available
  ANALYSIS_INCOMPLETE  = 'ANALYSIS_INCOMPLETE',   // Verification timed out for significant portion
  FORCE_INCOMPLETE     = 'FORCE_INCOMPLETE',      // v11.5: Injected during critical operational failure
  FORCE_TIMEOUT        = 'FORCE_TIMEOUT',         // v11.5
  FORCE_OPERATIONAL_FAILURE = 'FORCE_OPERATIONAL_FAILURE' // v11.5
}

/**
 * 🏛 v10.0: Analysis Error State
 */
export enum ErrorState {
  FAILED = 'FAILED'
}


export enum ClaimNature {
  VERIFIABLE_FACT = 'VERIFIABLE_FACT',   // Bucket 1: Empirical/Historical
  HISTORICAL_FACT = 'HISTORICAL_FACT',
  RELIGIOUS_CLAIM = 'RELIGIOUS_CLAIM',
  SUPERNATURAL_CLAIM = 'SUPERNATURAL_CLAIM',
  SCIENTIFIC_CLAIM = 'SCIENTIFIC_CLAIM',
  OPINION = 'OPINION',                   // Bucket 2: Subjective preference
  BELIEF = 'BELIEF',                     // Bucket 3: Faith/Scripture/Miracle
  ESTIMATION = 'ESTIMATION',             // Bucket 4: Projection/Prediction
  PREDICTION = 'PREDICTION',
  SATIRE = 'SATIRE',
  NOVEL_HYPOTHESIS = 'NOVEL_HYPOTHESIS',
  RHETORICAL_EXAGGERATION = 'RHETORICAL_EXAGGERATION'
}

export enum FramingStyle {
  HEDGED = 'HEDGED',
  BALANCED = 'BALANCED',
  ASSERTIVE = 'ASSERTIVE',
  ABSOLUTE = 'ABSOLUTE',
  MANIPULATIVE = 'MANIPULATIVE'
}

export enum EvidenceLevel {
  VERY_STRONG = 'VERY_STRONG',
  STRONG = 'STRONG',
  MODERATE = 'MODERATE',
  LIMITED = 'LIMITED',
  CONTRADICTED = 'CONTRADICTED',
  NONE = 'NONE',
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
  isFramingViolation?: boolean; // NEW: Belief/Opinion presented as Fact
  framingViolationDetail?: FramingViolationDetail;
  start?: number;
  end?: number;
  chunkIndex: number;
}

export interface FilteredClaim extends ExtractedClaim {
  claimId: string;
}

export type SourceTier = 'A' | 'B' | 'C' | 'D' | 'E';
export type VerificationMethod = 'grounded' | 'deterministic' | 'cache_hit' | 'llm_training' | 'not_verified';
export type SourceCategory = 'book' | 'journal' | 'newspaper' | 'website' | 'government' | 'scripture' | 'legal' | 'encyclopedia' | 'academic_press' | 'archive';

export enum EvidenceRole {
  PRIMARY_RECORD = "primary_record",
  INDEPENDENT_CORROBORATION = "independent_corroboration",
  EXPERT_SYNTHESIS = "expert_synthesis",
  INVESTIGATIVE_REPORTING = "investigative_reporting",
  OFFICIAL_ASSERTION = "official_assertion",
  SECONDARY_COMMENTARY = "secondary_commentary",
}

export type EvidentiaryStance = "SUPPORTS" | "CONTRADICTS" | "CONTEXTUAL" | "NEUTRAL";

export type EvidenceAdmissionStatus =
  | 'pending'
  | 'admitted'
  | 'quarantined'
  | 'rejected';

export interface DocumentEvidenceAssessment {
  admissionStatus: EvidenceAdmissionStatus;
  publisherTier: SourceTier;
  publisherVerified: boolean;
  claimRelevanceScore: number;
  directEvidenceScore: number;
  isPrimaryEvidence: boolean;
  isIndependent: boolean;
  isContradictory?: boolean;
  wireOrigin?: string;
  publicationDate?: string;
  retrievedAt: string;
  rejectionReason?: string;
  evidenceRole?: EvidenceRole;
  evidentiaryCapacity?: number;
  stance?: EvidentiaryStance;
}

export type UrlVerificationStatus =
  | 'VERIFIED'
  | 'NOT_FOUND'
  | 'SOFT_404'
  | 'BOT_BLOCKED'
  | 'FETCH_FAILED'
  | 'IRRELEVANT'
  | 'UNVERIFIED';

export interface UrlVerificationRecord {
  status: UrlVerificationStatus;
  originalUrl: string;
  canonicalUrl: string;
  domain: string;
  httpStatus: number;
  redirectHops: number;
  isSoft404: boolean;
  soft404Reason?: string;
  isGenericHomepage?: boolean;
  contentType?: string;
  contentTitle?: string;
  excerpt?: string;
  verifiedAtUtc: string;
  verifierMethod: 'http_get' | 'api_record' | 'grounding_resolved' | 'snapshot';
  fetchStatus: DeterministicVerification['fetchStatus'];
  relevanceScore?: number;
  errorReason?: string;
}

export interface VerifiedAcademicMetadata {
  title: string;
  authors?: string[];
  journalName?: string;
  yearPublished?: number;
  volume?: string;
  issue?: string;
  pages?: string;
  doi?: string;
  pmid?: string;
  abstractExcerpt?: string;
  retrievalProvider: string;
}

export interface EvidenceCandidate {
  evidenceId?: string;
  title: string;
  url: string;
  canonicalUrl?: string;
  domain: string;
  publisher?: string;
  snippet: string;
  publishedAt?: string;
  doi?: string;
  pmid?: string;
  sourceType?: SourceCategory;
  tier?: SourceTier;
  retrievalProvider: string;
  retrievalMethod: string;
  verification?: UrlVerificationRecord;
  verifiedAcademicMetadata?: VerifiedAcademicMetadata;
}

export interface RejectedEvidenceCandidate {
  url: string;
  title?: string;
  status: UrlVerificationStatus;
  reason: string;
  provider?: string;
  httpStatus?: number;
}

export interface EvidenceCatalog {
  claimText: string;
  normalizedQueries: string[];
  candidatesById: Record<string, EvidenceCandidate>;
  orderedCandidates: EvidenceCandidate[];
  rejectedCandidates: RejectedEvidenceCandidate[];
  verifiedAcademicMetadata: VerifiedAcademicMetadata[];
  retrievedAtUtc: string;
}

export type EvidenceProvider =
  | "PUBMED"
  | "CROSSREF"
  | "WIKIPEDIA"
  | "FRED"
  | "WORLDBANK"
  | "WIKIDATA"
  | "SERP"
  | "VERTEX_GROUNDING";

export interface VerifiedSource {
  evidenceId: string; // e.g., "E1", "E2"
  title: string;
  uri: string;
  snippet?: string; // Passage excerpt or abstract injected into closed-world prompt
  sourceProvider?: EvidenceProvider;
  claimIds?: string[]; // Optional claim association for batch-scoped prompt injection
}

export interface AdjudicatedClaim {
  claimId: string;
  verdict: "VERIFIED" | "FALSE" | "MISLEADING" | "DISPUTED" | "UNVERIFIABLE";
  confidence: number;
  rationale: string;
  citedEvidenceIds: string[];
  v2VerifiedUrls: VerifiedSource[];
  hasConflictingEvidence: boolean;
  escalatedToTier3: boolean;
  thinkingLevelUsed: "LOW" | "HIGH" | string;
  usedPreRetrievedEvidence: boolean;
}

export interface RichSource {
  evidenceId?: string;
  title: string;
  url: string;
  domain?: string;
  publisher?: string;
  type?: string;
  publishedAt?: string;
  tier: SourceTier;
  snippet?: string; // Stored in full.json only
  author?: string;
  sourceType?: SourceCategory;
  bookTitle?: string;
  chapter?: string;
  pageNumbers?: string;
  volume?: string;
  edition?: string;
  isbn?: string;
  doi?: string;
  journalName?: string;
  sectionAnchor?: string;
  directUrl?: string;
  yearPublished?: number;
  accessDate?: string;
  lastPublished?: string;
  lastVerified?: string;
  retrievalMethod?: string;
  retrievalProvider?: string;
  whatItSupports?: string;
  whatItDoesNotEstablish?: string;
  sourceRole?: 'primary_scripture' | 'independent_corroboration' | 'scholarly_reference' | 'scientific_reference' | 'news_reporting';
  evidenceRole?: EvidenceRole;
  stance?: EvidentiaryStance;
  evidentiaryCapacity?: number;
  baseReliability?: number;
  domainRelevance?: number;
  independenceFactor?: number;
  independenceGroup?: string;
  calculationVersion?: string;
  sourceTier?: SourceTier;
  status?: string;
  evidenceAssessment?: DocumentEvidenceAssessment;
  urlVerification?: UrlVerificationRecord;
  isContradictory?: boolean;
  wireOrigin?: string;
}

// ============================================
// P2: TEMPORAL NORMALIZATION & COMPARATIVE CLAIMS
// ============================================

export type TemporalPrecision =
  | 'exact'
  | 'year'
  | 'decade'
  | 'historical_period'
  | 'unspecified';

export interface TemporalConstraint {
  startDate?: string;
  endDate?: string;
  startYear?: number;
  endYear?: number;
  referenceEvent?: string;
  temporalPrecision: TemporalPrecision;
  isExplicit: boolean;
  coverageYears?: number[];
  missingYears?: number[];
  rawExpression?: string;
}

export type AccountingReconciliationStatus =
  | 'compatible'
  | 'normalizable'
  | 'incompatible';

export type GrowthCalculationMethod =
  | 'cagr'
  | 'arithmetic_annual_mean'
  | 'single_year'
  | 'unspecified';

export interface ComparableMetric {
  entity: string;
  metric: string;
  value: number;
  unit: string;
  startDate?: string;
  endDate?: string;
  startYear?: number;
  endYear?: number;
  methodology?: string;
  sourceId?: string;
  sourceTitle?: string;
  priceBasis?: 'real' | 'nominal' | 'constant_price' | 'current_price' | 'unspecified';
  populationBasis?: 'total' | 'per_capita' | 'unspecified';
  calendarVsFiscal?: 'calendar' | 'fiscal' | 'unspecified';
  accountingReconciliation?: AccountingReconciliationStatus;
  calculationMethod?: GrowthCalculationMethod;
  annualized?: boolean;
  coverageYears?: number[];
  missingYears?: number[];
  rawObservations?: { year: number; value: number }[];
}

export interface HistoricalEventBoundary {
  eventId: string;
  name: string;
  aliases: string[];
  startDate: string;
  endDate: string;
  startYear: number;
  endYear: number;
  description: string;
  region?: string;
}

export interface ConflictingHistoricalSource {
  sourceTitle: string;
  sourceId?: string;
  metricValue: number;
  unit: string;
  varianceDescription: string;
}

export interface SensitivityAnalysisItem {
  windowDescription: string;
  startYear: number;
  endYear: number;
  percentagePointsDiff: number;
  verdictImpact: string;
  verdictShiftType: 'flips_verdict' | 'changes_ranking' | 'alters_magnitude_only' | 'no_effect';
  resultSummary: string;
}

export interface ComparabilityAssessment {
  sameMetric: boolean;
  sameUnit: boolean;
  compatiblePeriods: boolean;
  compatibleMethodology: boolean;
  comparableDefinitions: boolean;
  isComparable: boolean;
  accountingReconciliationStatus?: AccountingReconciliationStatus;
  reconciliationNotes?: string[];
  reasons: string[];
  coverageGapNotice?: string;
  conflictingSources?: ConflictingHistoricalSource[];
  sensitivityAnalysis?: SensitivityAnalysisItem[];
  normalizedMetrics?: ComparableMetric[];
}

// ============================================
// P3: BENCHMARK & EVALUATION SUITE
// ============================================

export type EpistemicCategory =
  | 'historical_event'
  | 'textual_record'
  | 'traditional_religious_belief'
  | 'scientific_empirical_claim'
  | 'unfalsifiable_metaphysical_belief'
  | 'economic_statistical_indicator'
  | 'political_attribution'
  | 'counterfactual_opinion';

export type BenchmarkCategory =
  | 'straightforward_factual'
  | 'historical'
  | 'economic_statistical'
  | 'political'
  | 'scientific_medical'
  | 'religious_philosophical'
  | 'misleading_partially_true'
  | 'comparative_temporal';

export interface ConfidenceInterval95 {
  lower: number;
  upper: number;
  confidenceLevel: 0.95;
}

export interface BenchmarkClaimRecord {
  id: string;
  category: BenchmarkCategory;
  epistemicCategory?: EpistemicCategory;
  claimText: string;
  transcriptSnippet?: string;
  normalizedProposition: string;
  referenceVerdict: ClaimStatus;
  acceptableVerdicts?: ClaimStatus[];
  referenceSources: RichSource[];
  contradictorySources?: RichSource[];
  relevantTemporalConstraints?: TemporalConstraint[];
  expectedComparableMetrics?: ComparableMetric[];
  expertAnnotationNotes: string;
  annotatorAgreementRate: number; // e.g. 1.0 (unanimous) or 0.85
  difficultyTier?: 'standard' | 'nuanced' | 'adversarial';
  // P3 Provenance & Independence Metadata
  annotatorId?: string;
  annotationTimestamp?: string;
  adjudicationHistory?: { timestamp: string; annotatorId: string; verdict: ClaimStatus; rationale: string }[];
  datasetVersion?: string;
  isIndependentlyEstablished?: boolean; // Verified independent of TruthWorld AI predictions
}

export interface VerdictAccuracyMetrics {
  totalClaims: number;
  evaluatedClaims: number;
  correctPredictions: number;
  accuracy: number;
  accuracyConfidenceInterval?: ConfidenceInterval95;
  precisionMacro: number;
  recallMacro: number;
  f1Macro: number;
  f1Weighted: number;
  perVerdictMetrics: Record<string, { precision: number; recall: number; f1: number; support: number }>;
  confusionMatrix: Record<string, Record<string, number>>;
  abstentionRate: number; // percentage marked inconclusive or unproven
  coverageRate: number;   // percentage of claims given definitive verdicts
}

export interface CalibrationBin {
  binLower: number;
  binUpper: number;
  binCenter: number;
  sampleCount: number;
  meanPredictedConfidence: number;
  observedAccuracy: number;
  calibrationError: number;
}

export interface ConfidenceCalibrationMetrics {
  brierScore: number;
  multiclassBrierScore?: number;
  expectedCalibrationError: number; // ECE
  eceConfidenceInterval?: ConfidenceInterval95;
  maxCalibrationError: number;      // MCE
  overconfidenceError: number;
  underconfidenceError: number;
  reliabilityBins: CalibrationBin[];
  decoupledScoresEvaluated: boolean; // Confirms verdictConfidence != evidenceStrength
}

export interface EvidenceQualityMetrics {
  totalAdmittedSources: number;
  relevantAdmittedSources: number;
  evidencePrecision: number; // relevantAdmittedSources / totalAdmittedSources
  tierEExclusionRate: number; // 1.0 = 100% of Tier-E candidates correctly excluded/quarantined
  contradictoryPreservationRate: number; // percentage of known contradictory evidence preserved
  wireDeduplicationAccuracy: number;
  provenanceCompletenessRate: number; // percentage of claims with full lineage & URL traces
  quarantinedSourcesAudited: number;
}

export interface TemporalEvaluationMetrics {
  totalComparativeClaims: number;
  invalidComparisonsTested: number;
  invalidComparisonsAcceptedAsTrue: number; // MUST BE 0 FOR RELEASE GATE
  temporalConstraintExtractionAccuracy: number;
  eventBoundaryResolutionAccuracy: number;
  accountingMismatchDetectionRate: number;
}

export interface ReleaseGateRule {
  gateName: string;
  threshold: number | string;
  actualValue: number | string;
  passed: boolean;
  isBlocking: boolean;
  description: string;
}

export interface BenchmarkReport {
  reportId: string;
  timestamp: string;
  modelVersion: string;
  totalDatasetSize: number;
  categoryBreakdown: Record<string, number>;
  verdictBreakdown?: Record<string, number>;
  classImbalanceRatio?: number;
  datasetIntegrityVerified?: boolean;
  verdictAccuracy: VerdictAccuracyMetrics;
  confidenceCalibration: ConfidenceCalibrationMetrics;
  evidenceQuality: EvidenceQualityMetrics;
  temporalEvaluation: TemporalEvaluationMetrics;
  releaseGates: {
    passed: boolean;
    blockingViolations: string[];
    rules: ReleaseGateRule[];
  };
  historicalRegressions?: {
    claimId: string;
    claimText: string;
    previousVerdict: ClaimStatus;
    currentVerdict: ClaimStatus;
    isRegression: boolean;
  }[];
}

// ============================================
// P4: ADVERSARIAL ROBUSTNESS & RED-TEAM TYPES
// ============================================

export type AdversarialVector =
  | 'prompt_injection_source'
  | 'fabricated_citation'
  | 'misleading_quotation'
  | 'cherry_picked_statistics'
  | 'coordinated_source_manipulation'
  | 'translation_semantic_drift'
  | 'multimodal_contradiction'
  | 'ambiguous_compound_claim';

export interface MultilingualPropositionRecord {
  claimId: string;
  originalTranscript: string;
  sourceLanguage: string; // 'te', 'hi', 'ta', 'kn', 'mr', 'bn', etc.
  literalTranslation: string;
  contextualTranslation: string;
  normalizedProposition: string;
  semanticDivergenceScore: number; // 0.0 (identical) to 1.0 (severe divergence)
  divergenceNotes: string[];
  adjudicationBasis: 'normalized_proposition';
  culturalContextualEquivalence: boolean;
}

export interface PromptInjectionAuditResult {
  hasInjectionAttempt: boolean;
  sanitizedContent: string;
  quarantinedSnippet?: string;
  detectedPatterns: string[];
  severity: 'none' | 'low' | 'medium' | 'high' | 'critical';
}

export interface FabricatedCitationAuditResult {
  isVerifiable: boolean;
  doiValid?: boolean;
  domainResolvable?: boolean;
  registryFound?: boolean;
  discrepancies: string[];
  riskScore: number;
}

export interface CircularSyndicationCluster {
  clusterId: string;
  canonicalOriginUrl: string;
  syndicatedUrls: string[];
  similarityScore: number;
  isCircularRing: boolean;
  effectiveIndependentSourceCount: number;
}

export interface MultiModalConsistencyReport {
  isConsistent: boolean;
  crossModalDiscordanceScore: number;
  audioTranscript: string;
  visualOcrText?: string;
  subtitleText?: string;
  discordanceDetails?: string[];
}

export interface AtomicSubProposition {
  subClaimId: string;
  text: string;
  status: ClaimStatus;
  verdictConfidence: number;
  reasoning: string;
  supportingSourceCount: number;
}

export interface CompoundClaimDecompositionResult {
  originalClaim: string;
  isCompound: boolean;
  atomicPropositions: AtomicSubProposition[];
  aggregateStatus: ClaimStatus;
  synthesisRationale: string;
}

export interface AdversarialEvaluationReport {
  reportId: string;
  timestamp: string;
  totalAttacksTested: number;
  successfulDefenses: number;
  defenseRate: number;
  perVectorResults: Record<AdversarialVector, {
    attacksTested: number;
    defended: number;
    defenseRate: number;
    passed: boolean;
  }>;
  multilingualIntegrityScore: number;
  promptInjectionDefendedCount: number;
  circularSyndicationCollapsedCount: number;
  adversarialReleaseGatePassed: boolean;
}

// ============================================
// P5: INDEPENDENT VALIDATION & PRODUCTION TRUST CERTIFICATION
// ============================================

export interface CryptographicProvenanceRecord {
  recordId: string;
  payloadHash: string; // SHA-256 of canonical JSON
  merkleRoot?: string;
  signature: string; // Ed25519 signature in hex
  signerId: string; // e.g. 'audit_authority_truthworld_main'
  publicKeyPem?: string; // Ed25519 public key in PEM format for universal verification
  timestamp: string; // ISO 8601
  algorithm: 'Ed25519' | 'HMAC-SHA256' | 'ECDSA-P256-SHA256';
  isTamperEvident: boolean;
}

export interface DatasetIntegrityManifest {
  manifestId: string;
  datasetVersion: string;
  datasetName: string;
  totalRecords: number;
  datasetContentHash: string; // SHA-256 of sorted record hashes
  recordHashes: Record<string, string>; // recordId -> sha256
  createdAt: string;
  signedBy: string;
  signature: string;
  publicKeyPem?: string;
  algorithm?: 'Ed25519' | 'HMAC-SHA256';
}

export interface StructuralBreakEvent {
  year: number;
  event: string;
  impactType: 'exogenous_shock' | 'policy_regime_shift' | 'measurement_standard_revision';
  historicalMagnitude: number;
  description: string;
}

export interface NeweyWestHacDetails {
  lagTruncation: number; // L = floor(4 * (n / 100)^(2/9))
  bartlettWeights: number[];
  autocovariances: number[]; // gamma_0 ... gamma_L
  longRunVarianceOmega: number; // Omega_HAC
  standardErrorHac: number;
  effectiveSampleSizeAr1: number; // Moran/Bayley-Hammersley AR(1) formula: n * (1 - r1) / (1 + r1)
}

export interface EconometricTrendAssessment {
  entity: string;
  metric: string;
  targetYear: number;
  targetValue: number;
  sampleMean: number;
  sampleStandardDeviation: number;
  standardErrorOfMean: number;
  zScore: number;
  degreesOfFreedom: number;
  meanConfidenceInterval95: [number, number]; // CI for the mean: \mu \pm t * (s / \sqrt{n})
  observationPredictionInterval95: [number, number]; // PI for an observation: \mu \pm t * s * \sqrt{1 + 1/n}
  confidenceInterval95: [number, number]; // Legacy alias for backward compatibility
  autocorrelationCoefficient?: number; // First-order serial correlation r_1
  neweyWestHacDetails?: NeweyWestHacDetails; // Formal Newey-West (1987) HAC Long-Run Variance
  isStatisticallyAnomalous: boolean; // |z| >= 2.5
  structuralBreakIdentified?: StructuralBreakEvent;
  anomalyClassification: 'structural_break_event' | 'statistical_anomaly_requiring_context' | 'expected_historical_volatility';
  isCherryPickedAnomaly: boolean;
  rationale: string;
}

export interface RetractionRegistryRecord {
  doi: string;
  title: string;
  journal: string;
  retractionDate?: string;
  retractionReason?: string;
  retractionNoticeUrl?: string;
  lastCheckedTimestamp?: string;
  status: 'active' | 'retracted' | 'expression_of_concern' | 'corrected' | 'partially_corrected' | 'reinstated';
  evidentiaryWeight?: number; // 0.0 if retracted
}

export type MultiModalDiscrepancyClassification =
  | 'deliberate_deception'
  | 'contextual_contrast'
  | 'measurement_basis_difference'
  | 'speaker_self_correction'
  | 'unresolved';

export interface MultimodalReconciliation {
  classification: MultiModalDiscrepancyClassification;
  discrepancyDetected: boolean;
  explanationSupported: boolean;
  propositionVerdictUnaffected: boolean;
  requiresHumanReview: boolean;
  evidence: string[];
  adjudicationNote: string;
}

export interface ContextAwareMultiModalReport {
  isConsistent: boolean;
  discordanceScore: number;
  classification: MultiModalDiscrepancyClassification;
  audioValue?: number;
  ocrValue?: number;
  speechContext?: string;
  isPermissibleVariance: boolean;
  adjudicationNote: string;
  reconciliation?: MultimodalReconciliation;
}

export interface SourceSnapshot {
  sourceUrl: string;
  title: string;
  retrievedAt: string;
  contentSha256: string;
  permissibleExcerpt: string;
  tier: 'A' | 'B' | 'C' | 'D' | 'E';
  admissionDecision: 'admitted' | 'quarantined' | 'rejected';
  admissionRationale: string;
}

export interface PublicAuditPackV1 {
  schemaVersion: '1.0.0-auditpack' | '1.1.0-auditpack' | '2.0.0-auditpack';
  packId: string;
  generatedAt: string;
  claimId: string;
  proposition: {
    originalText: string;
    normalizedAtomicClaim: string;
    sourceLanguage: string;
    epistemicCategory: EpistemicCategory;
  };
  verdict: {
    finalStatus: ClaimStatus;
    verdictConfidence: number;
    evidenceStrength: number;
    sourceIndependenceScore: number;
    publicExplanation: string;
  };
  evidenceGraph: {
    admittedSources: RichSource[];
    quarantinedSources?: RichSource[];
    retractedSourcesAudit?: RetractionRegistryRecord[];
    evidencePrecision: number;
  };
  sourceSnapshots?: SourceSnapshot[];
  comparabilityAudit?: {
    isComparative: boolean;
    comparabilityStatus?: string;
    reconciliationMethod?: string;
  };
  engineMetadata?: {
    modelIdentifier: string;
    pipelineVersion: string;
    policyCommitHash: string;
    retrievalConfiguration?: {
      provider: string;
      minTier: string;
      crossValidationThreshold: number;
    };
  };
  cryptographicAttestation: {
    auditPackSha256: string;
    datasetManifestHash: string;
    signerId: string;
    keyId?: string;
    algorithm: 'Ed25519' | 'HMAC-SHA256';
    publicKeyPem?: string;
    signature: string;
    verificationInstructions: string;
  };
  sevenCoreAnswers: {
    q1_exactClaim: string;
    q2_supportingEvidence: string;
    q3_contradictoryEvidence: string;
    q4_sourceAdmissionRationale: string;
    q5_comparabilityIntegrity: string;
    q6_epistemicConfidence: string;
    q7_limitationsAndUnresolvedDisagreements: string;
  };
}

export type PublicAuditPackV2 = PublicAuditPackV1;
export type PublicAuditPack = PublicAuditPackV1;

// ============================================
// P6: INDEPENDENT EXTERNAL AUDIT & REAL-WORLD CERTIFICATION
// ============================================

export interface AuthorityKeyRecord {
  kid: string;
  algorithm: 'Ed25519';
  publicKeyPem: string;
  publicKeyFingerprintSha256: string;
  status: 'active' | 'revoked' | 'deprecated';
  validFrom: string;
  validUntil?: string;
  revokedAt?: string;
  revocationReason?: string;
}

export interface WellKnownKeySet {
  authority: string;
  endpoint: string;
  publishedAt: string;
  keys: AuthorityKeyRecord[];
}

export interface PassageEvidenceAssessment {
  findingId: string;
  targetPassage: string;
  isAffectedByRetractionOrCorrection: boolean;
  findingSpecificWeight: number; // 0.0 to 1.0
  findingRationale: string;
}

export interface BlindEvaluationItem {
  claimId: string;
  claimText: string;
  language: 'en' | 'te' | 'hi' | 'ta' | 'mr' | 'bn';
  epistemicCategory: EpistemicCategory;
  expertAnnotation: {
    expertVerdict: ClaimStatus;
    expertConfidence: number;
    domainExpertise: 'economist' | 'historian' | 'scientist' | 'linguist' | 'legal_scholar';
    notes: string;
  };
  truthworldEvaluation?: {
    verdict: ClaimStatus;
    verdictConfidence: number;
    evidenceStrength: number;
    isAbstained: boolean;
  };
}

export interface BlindEvaluationReport {
  reportId: string;
  evaluatedAt: string;
  totalClaims: number;
  agreementRate: number; // overall observed agreement p_o
  cohenKappa: number;    // inter-rater agreement statistic
  definitiveClaimCount: number;
  abstainedClaimCount: number;
  definitiveAgreementRate: number; // Agreement on claims with definitive verdicts
  abstentionAgreementRate: number; // Agreement on abstentions (inconclusive / unproven)
  accuracyConditionalOnCoverage: number; // Accuracy conditional on rendering a definitive verdict
  abstentionRate: number;
  coverageRate: number;
  wilsonConfidenceInterval95?: [number, number];
  confusionMatrix: Record<string, Record<string, number>>;
  byLanguage: Record<string, { total: number; agreed: number; agreementRate: number }>;
  byCategory: Record<string, { total: number; agreed: number; agreementRate: number }>;
  disagreements: {
    claimId: string;
    claimText: string;
    language: string;
    expertVerdict: ClaimStatus;
    truthworldVerdict: ClaimStatus;
    analysis: string;
  }[];
}

export interface AuditPackAmendment {
  amendmentId: string;
  originalPackId: string;
  originalPackHash: string;
  amendedAt: string;
  amendmentReason: string;
  amendedBy: string;
  previousVerdict: ClaimStatus;
  newVerdict: ClaimStatus;
  newAuditPackSha256: string;
  immutableChainHash: string;
}

export interface SignedLedgerCheckpoint {
  checkpointId: string;
  checkpointSequence: number;
  ledgerRootHash: string;
  previousCheckpointRootHash: string;
  totalAmendments: number;
  timestamp: string;
  signedBy: string;
  publicKeyPem: string;
  publicKeyFingerprint: string;
  signature: string;
  externalAnchors?: {
    anchorType: 'rfc3161_timestamp' | 'git_commit_anchor' | 'public_transparency_log';
    anchorUri: string;
    anchorProof: string;
  }[];
}

export interface TruthPerformanceDashboardMetrics {
  totalAuditPacksPublished: number;
  overallExpertAgreement: number;
  definitiveAccuracy: number;
  abstentionRate: number;
  coverageRate: number;
  interRaterKappa: number;
  totalAmendmentsLogged: number;
  signedCheckpointsCount: number;
  activeAuthorityKeyFingerprint: string;
  byLanguage: Record<string, { agreementRate: number; total: number }>;
  byCategory: Record<string, { agreementRate: number; total: number }>;
  lastUpdated: string;
}


export type ClaimType = string;

export type ClaimSeverity = 'low' | 'medium' | 'high' | 'extreme';
export type ClaimAssertiveness = 'casual' | 'moderate' | 'confident' | 'authoritative' | 'absolute';
export type ClaimStrength = 'hedged' | 'moderate' | 'strong' | 'absolute';

export type ClaimStatus = 
  | "verified_true"     // Verified against Tier A-D
  | "mostly_true"      // Broadly true but approximate
  | "disputed"         // Contradictory evidence exists
  | "unproven"         // Evidence missing but not contradicted (Neutral)
  | "misleading"       // Technically true but framed to deceive
  | "false_claim"      // Contradicted by evidence
  | "religious_belief" // Bucket 3: Respected faith claim
  | "opinion_claim"    // Bucket 2: Respected subjective claim
  | "satire_claim"     // Satire
  | "verification_timeout" // NEW: Search/Model timed out
  | "unverified"      // No verification attempted
  | "inconclusive"    // Evidence retrieval failed or search was weak
  | "limited_support" // Trivia/Common knowledge with weak formal citations
  | "verified_false"
  | "partially_true"
  | "opinion_or_prediction"
  | "correct"
  | "mostly_correct"
  | "incorrect"
  | "outdated"
  | "unsupported"
  | "needs_context"
  | "incorrect_citation"
  | "historical_consensus_denial"
  | "faith_context"
  | "tradition_linked"
  | "historical_tradition"
  | "opinion"
  | "satire"
  | "unverifiable"
  | "faith_based_claim"
  | "contested_interpretation"
  | "not_historically_verifiable"
  | "novel_hypothesis"
  | "developing_story";

export interface EvidenceAssessment {
  scripturalSupport?: 'DOCUMENTED' | 'STRONG' | 'PARTIAL' | 'NOT_ESTABLISHED' | 'NOT_APPLICABLE';
  independentHistoricalCorroboration?: 'DOCUMENTED' | 'STRONG' | 'PARTIAL' | 'NOT_ESTABLISHED' | 'NOT_APPLICABLE';
  empiricalVerification?: 'ESTABLISHED' | 'CONSISTENT' | 'NOT_ESTABLISHED' | 'CONTRADICTED' | 'NOT_APPLICABLE';
}

export interface FramingViolationDetail {
  violationType?: 'UNSUPPORTED_PROOF_ASSERTION' | 'BELIEF_AS_EMPIRICAL_FACT' | 'OPINION_AS_FACT' | 'NONE';
  assertedEvidenceQuality?: string;
  explanation?: string;
}

export type VerificationLifecycle =
  | 'primary_verification'
  | 'provisional'
  | 'citation_recovery'
  | 're_adjudication'
  | 'finalized'
  | 'failed';

export interface RecoveredClaimContext {
  claimId: string;
  originalClaim: string;
  provisionalStatus: ClaimStatus;
  recoveredSources: RichSource[];
  previousReasoning?: string;
  previousConfidence: number;
  retrievalStage: 'citation_retry';
}

export interface VerifiedClaim extends FilteredClaim {
  status: ClaimStatus; // Pipeline state
  lifecycle?: VerificationLifecycle;
  provisionalStatus?: ClaimStatus;
  isProvisional?: boolean;
  adjudicationVersion?: number;
  lastAdjudicatedAt?: string;
  evidenceStrength?: number; // 0.0 - 1.0: Quality & direct relevance of supporting sources
  verdictConfidence?: number; // 0.0 - 1.0: Confidence that the assigned verdict is correct
  sourceIndependenceScore?: number; // 0.0 - 1.0: Distinct independent corroboration without circular syndication
  lineage?: EvidenceLineage;
  rhetoricalManipulations?: string[];
  displayLabel?: string; // NEW: Semantic override for UI (e.g., "Popular Claim")
  isLowRiskTrivia?: boolean; // NEW: Marker for science/animal/geography facts
  evidenceLevel?: EvidenceLevel; // Epistemic classification
  speaker?: string; // Explicitly added to ensure visibility in v5
  verificationConfidence: number;
  reasoning: string;
  sources?: string[]; // Legacy / Concatenated
  richSources?: RichSource[]; // Production rich links (strictly verified against closed-world EvidenceCatalog)
  quarantinedSources?: RichSource[]; // P1 Strict Source Gating: Audit trail of rejected or quarantined citations
  verifiedAcademicMetadata?: VerifiedAcademicMetadata[]; // Non-clickable bibliographic records when landing URL unavailable
  evidenceCatalogVersion?: string; // Closed-world evidence contract version (e.g., v2_verified_urls)
  temporalConstraints?: TemporalConstraint[]; // P2 Temporal Normalization: Time constraints extracted from claim
  comparabilityAssessment?: ComparabilityAssessment; // P2 Temporal Normalization: Comparability gate assessment
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
  rating?: number | null;
  freshness?: string;
  verificationSummary?: string;
  verifiedFacts?: string[];
  missingEvidence?: string[];
  sourceConsensus?: string;
  riskLevel?: string;
  publicNote?: string;
  recommendedAction?: string;
  timedOutAt?: number;   // v10.6: set when claim timed out, cleared after retry conversion
  verificationMethod?: VerificationMethod; // v11.5: deterministic | grounded | cache_hit
  sourceStatus?: 'complete' | 'partial' | 'missing';
  evidenceSchemaVersion?: string;
  evidenceSummary?: EvidenceSummary;
  processingMetadata?: {
    recoveryMethod?: string;
    requiresCitationRetry?: boolean;
    cacheSource?: string;
    [key: string]: any;
  };
  classificationConfidence?: number;
  historicalEvidenceConfidence?: number;
  evidenceDetails?: {
    scriptural?: string;
    historical?: string;
    scientific?: string;
  };
  consensusDetails?: {
    theology?: string;
    historical?: string;
    scientific?: string;
  };
  evidenceAssessment?: EvidenceAssessment;
  beliefAssessment?: string;
  misinformationVerdict?: 'NOT_MISINFORMATION' | 'MISINFORMATION' | 'NOT_ESTABLISHED' | 'NOT_ESTABLISHED_AS_MISINFORMATION' | 'NOT_APPLICABLE';
  framingViolationDetail?: FramingViolationDetail;
  confidenceMeaning?: string;
  framingAssessment?: string;
  epistemicLimitations?: string[];
  multiModelConsensus?: MultiModelConsensusMetadata;
  evidenceTraceability?: EvidenceToClaimTraceability;
  calibratedConfidence?: CalibratedConfidenceBreakdown;
  assessmentV2?: CredibilityAssessmentV2;
  claimDomain?: string;
  claimNature?: string;
  verdictBasis?: string[];
  evidence?: Array<{ type: string; strength: string }>;
  consensus?: Array<{ domain: string; level: string }>;
}

export type ComponentVerificationStatus =
  | 'VERIFIED_OBSERVATION'
  | 'CONTRADICTED_OBSERVATION'
  | 'INVALID_INFERENCE'
  | 'VALID_INFERENCE'
  | 'UNSUPPORTED'
  | 'UNVERIFIED_CITATION'
  | 'INSUFFICIENT_EVIDENCE';

export type EvidenceRelationship = 'SUPPORTS' | 'CONTRADICTS' | 'IRRELEVANT' | 'EXPLAINS_OBSERVATION';

export type CorroborationType =
  | 'independent_primary_observation'
  | 'independent_analysis_of_primary_data'
  | 'subject_self_reporting'
  | 'dependent_repetition';

export interface SourceIndependenceMatrix {
  publisherIndependentOfSubject: boolean;
  underlyingDataIndependentOfSubject: boolean;
  analysisIndependentlyConducted: boolean;
  corroborationType: CorroborationType;
}

export interface AutomatedPassageVerification {
  urlResolved: boolean;
  passageLocated: boolean;
  passageMatchesSource: boolean;
  supportsClaimComponent: boolean;
  verificationMethod: 'retrieved_text_and_passage_match' | 'offline_corpus_match' | 'live_http_retrieval' | 'unverified_citation';
  lastVerifiedAt: string;
  locatedContextSnippet?: string;
  omittedContextDetected?: boolean;
  omittedContextExplanation?: string;
}

export interface CalibratedConfidenceBreakdown {
  claimDecomposition?: number | null;
  premiseAssessment?: number | null;
  sourceVerification?: number | null;
  inferenceAssessment?: number | null;
  overallVerdict?: number | null;
}

export interface EvidenceProvenance {
  originAgencyOrAuthor: string;
  isIndependentOfSubject: boolean;
  independenceValidation: string;
}

export interface EvidenceTraceItem {
  evidenceId: string;
  componentId: string;
  sourceTitle: string;
  sourceUrl: string;
  retrievalTimestamp: number;
  sourceType: string;
  provenance: EvidenceProvenance;
  sourceIndependence?: SourceIndependenceMatrix;
  automatedVerification?: AutomatedPassageVerification;
  exactPassage: string;
  claimComponentAddressed: string;
  relationship: EvidenceRelationship;
  verificationStatus: ComponentVerificationStatus;
  knownLimitations: string[];
}

export interface ClaimComponent {
  componentId: string;
  statement: string;
  type: 'PREMISE_OBSERVATION' | 'INFERENTIAL_CONCLUSION' | 'CONTEXTUAL_ASSERTION';
  factualAccuracy: 'ACCURATE_OBSERVATION' | 'INACCURATE_OBSERVATION' | 'UNVERIFIABLE';
  inferentialValidity?: 'VALID' | 'INVALID_NON_SEQUITUR' | 'NOT_APPLICABLE';
  explanation: string;
  detectedFallacy?: 'NON_SEQUITUR' | 'APPEAL_TO_IGNORANCE' | 'CHERRY_PICKING' | 'POST_HOC' | 'FALSE_DILEMMA' | 'NONE';
  evidenceIds: string[];
}

export interface EvidenceToClaimTraceability {
  isCompoundClaim: boolean;
  components: ClaimComponent[];
  evidenceTraces: EvidenceTraceItem[];
  inferentialBridgeSummary: string;
  overallSynthesis: {
    premisesVerdict: 'ALL_PREMISES_OBSERVABLE' | 'MIXED_PREMISES' | 'FALSE_PREMISES';
    conclusionVerdict: 'CONCLUSION_UNSUPPORTED_BY_PREMISES' | 'CONCLUSION_SUBSTANTIATED';
    finalAdjudication: string;
  };
}

// ============================================================================
// TRUTHWORLD V2 CREDIBILITY SPECIFICATION: 3-AXIS ORTHOGONAL CLASSIFICATION
// AND CLOSED-WORLD DETERMINISTIC EVIDENCE REGISTRY (schemaVersion: "2.0.0")
// ============================================================================

export type PropositionType =
  | 'EMPIRICAL_OBSERVATION'
  | 'CAUSAL_CLAIM'
  | 'CAUSAL_INFERENCE'
  | 'CLINICAL_OUTCOME'
  | 'INTENT_CLAIM'
  | 'HISTORICAL_ACCOUNT'
  | 'HISTORICAL_DOCUMENTARY_CLAIM'
  | 'DESCRIPTIVE_RELIGIOUS_TEACHING'
  | 'THEOLOGICAL_DOCTRINE'
  | 'EXTRAORDINARY_EMPIRICAL_ASSERTION'
  | 'NORMATIVE_OPINION'
  | 'FUTURE_PREDICTION';

export type EvidenceStatus =
  | 'SUPPORTED'
  | 'CONTRADICTED'
  | 'MIXED_SUPPORT'
  | 'INSUFFICIENT_EVIDENCE'
  | 'CONFLICTING_EVIDENCE'
  | 'NOT_EMPIRICALLY_TESTABLE';

export type ReasoningValidity =
  | 'SOUND_INFERENCE'
  | 'NON_SEQUITUR'
  | 'CHERRY_PICKED_PREMISES'
  | 'CONTEXT_DISTORTION'
  | 'NOT_APPLICABLE';

export type DisplayBadge =
  | 'VERIFIED_FACT'
  | 'EMPIRICALLY_VERIFIED'
  | 'MISLEADING_INFERENCE'
  | 'FACTUAL_CONTRADICTION'
  | 'UNSUPPORTED_CONJECTURE'
  | 'FAITH_DOCTRINE'
  | 'NORMATIVE_VALUE_JUDGMENT'
  | 'UNVERIFIED_PREDICTION'
  | 'CONFLICTING_EVIDENCE'
  | 'INSUFFICIENT_EVIDENCE'
  | 'CORROBORATION_NOT_ESTABLISHED'
  | 'PARTIALLY_SUPPORTED'
  | 'MISLEADING_EVIDENCE_PRESENTATION';

export type SpeakerStance =
  | 'SPEAKER_ASSERTS'
  | 'SPEAKER_QUOTES_OTHER'
  | 'SPEAKER_QUESTIONS'
  | 'SPEAKER_HYPOTHESIZES'
  | 'SATIRICAL_FRAME';

export type EvaluatedModality =
  | 'AUDIO_TRANSCRIPT'
  | 'KEYFRAME_OCR'
  | 'VISUAL_INSPECTION'
  | 'TELEMETRY'
  | 'DOCUMENT_TEXT';

export interface AssessmentVideoContext {
  videoId: string;
  startTimeMs: number;
  endTimeMs: number;
  asrMinTokenConfidence: number;
  speakerStance: SpeakerStance;
  modalityEvaluated: EvaluatedModality[];
}

export interface OrthogonalClassification {
  propositionType: PropositionType;
  evidenceStatus: EvidenceStatus;
  reasoningValidity: ReasoningValidity;
  displayBadge: DisplayBadge;
}

export interface ClaimDecompositionProposition {
  propositionId: string;
  role: 'PREMISE' | 'CONCLUSION' | 'CONTEXT';
  text: string;
  propositionType: PropositionType;
  assessment: EvidenceStatus;
  supportingEvidenceIds: string[];
  contradictingEvidenceIds: string[];
  independentPrimarySourceCount: number;
}

export interface SourceIdentity {
  publisher: string;
  url: string;
  publicationDate?: string;
  sourceClassification?: 'PRIMARY' | 'SECONDARY' | 'REGULATORY_RECORD';
  primaryArtifactId?: string | null;
}

export interface DeterministicVerification {
  fetchStatus: 'HTTP_200_OK' | 'ARCHIVE_LOCAL' | 'API_RESOLVED' | 'FETCH_FAILED' | 'UNVERIFIED' | 'NOT_FOUND' | 'SOFT_404' | 'BOT_BLOCKED';
  snapshotSha256: string;
  retrievedAtUtc: string;
  verifiedPassage: string;
  charStart: number;
  charEnd: number;
  exactMatchScore: number; // 0.0 - 1.0 (>= 0.95 required for deterministic verification)
  contextDistortionDetected: boolean;
}

export type LineageType =
  | 'PRIMARY_TECHNICAL_RECORD'
  | 'PEER_REVIEWED_RESEARCH'
  | 'PRIMARY_DATASET'
  | 'HISTORICAL_ARCHIVE'
  | 'LEGAL_DOCKET'
  | 'SECONDARY_SCHOLARLY'
  | 'SYNDICATED_DERIVATIVE'
  | 'SUBJECT_SELF_REPORT';

export interface SourceIndependenceProfile {
  lineageType: LineageType;
  upstreamSourceId?: string | null;
  independenceWeight: number; // 0.0 - 1.0 (syndicated = 0.0, primary = 1.0)
}

export interface EpidemiologicalParameters {
  populationStudied?: string;
  ageGroup?: string;
  sex?: string;
  vaccineProduct?: string;
  doseNumber?: string;
  absoluteRisk?: string;
  relativeRisk?: string;
  outcomeDefinition?: string;
  followUpDuration?: string;
  confoundingLimitations?: string;
}

export interface EpistemicScope {
  establishes: string;
  doesNotEstablish: string;
  limitations: string;
  epidemiologicalParameters?: EpidemiologicalParameters;
}

export type EvidenceDomain =
  | 'IN_VITRO_LABORATORY'
  | 'ANIMAL_MODEL'
  | 'OBSERVATIONAL_COHORT'
  | 'RANDOMIZED_CONTROLLED_TRIAL'
  | 'SYSTEMATIC_REVIEW_META_ANALYSIS'
  | 'REGULATORY_DOCKET'
  | 'HISTORICAL_DOCUMENT'
  | 'EXPERT_CONSENSUS';

export interface EvidenceRegistryItem {
  sourceIdentity: SourceIdentity;
  deterministicVerification: DeterministicVerification;
  independence: SourceIndependenceProfile;
  epistemicScope: EpistemicScope;
  epidemiologicalParameters?: EpidemiologicalParameters;
  evidenceDomain?: EvidenceDomain;
}

export type InferenceType =
  | 'MECHANISTIC_TO_CLINICAL'
  | 'ANIMAL_TO_HUMAN'
  | 'CORRELATION_TO_CAUSATION'
  | 'SUBGROUP_TO_GENERAL'
  | 'EVIDENCE_OF_ABSENCE_INFERENCE'
  | 'INTENT_IMPUTATION'
  | 'DIRECT_DEDUCTION';

export type InferenceFallacyType =
  | 'EVIDENCE_DOMAIN_TRANSFER'
  | 'POST_HOC_ERGO_PROPTER_HOC'
  | 'BASE_RATE_NEGLECT'
  | 'NON_SEQUITUR'
  | 'CHERRY_PICKING'
  | 'INTENT_IMPUTATION'
  | 'UNWARRANTED_EXTRAPOLATION';

export interface InferenceStepAudit {
  inferenceId: string;
  sourcePropositionIds: string[];
  targetPropositionId: string;
  inferenceType: InferenceType;
  validity: 'VALID_DEDUCTIVE' | 'VALID_INDUCTIVE' | 'INVALID_WITHOUT_ADDITIONAL_EVIDENCE' | 'INVALID_FALLACIOUS';
  detectedFallacy?: InferenceFallacyType;
  missingEvidence: string[];
  contradictingEvidenceIds: string[];
  explanation: string;
}

export interface EvaluatedAlternativeExplanation {
  explanation: string;
  supportingEvidenceIds: string[];
}

export interface ReasoningAssessment {
  premisesVerifiedAccurate: string[];
  conclusionFollowsDeductively: boolean;
  conclusionFollowsInductively: boolean;
  evaluatedAlternativeExplanations: EvaluatedAlternativeExplanation[];
  inferenceAudits?: InferenceStepAudit[];
}

export interface BackendAuditFlags {
  allReferencedCitationsDeterministicallyVerified: boolean;
  unverifiedEvidencePresent: boolean;
  closedWorldCitationCheckPassed: boolean;
  semanticGroundingVerified?: boolean;
  zeroOverclaimingViolations?: boolean;
}

export type SemanticEvidenceRelationship =
  | 'SUPPORTS'
  | 'CONTRADICTS'
  | 'PARTIALLY_SUPPORTS'
  | 'CONTEXTUALLY_LIMITS'
  | 'IRRELEVANT'
  | 'AMBIGUOUS';

export type HypothesisVsFindingDistinction =
  | 'EMPIRICAL_FINDING'
  | 'STUDY_HYPOTHESIS_DISCUSSED'
  | 'LITERATURE_REVIEW_CITATION'
  | 'METHODOLOGICAL_CAVEAT';

export type ScopeOfSupport =
  | 'FULL_PROPOSITION'
  | 'PARTIAL_PREMISE_ONLY'
  | 'CONTEXTUAL_BACKGROUND'
  | 'CONTRADICTING_EVIDENCE'
  | 'NO_SUPPORT';

export interface SemanticEvidenceLink {
  evidenceId: string;
  targetPropositionId: string;
  semanticRelationship: SemanticEvidenceRelationship;
  rationale: string;
  disclosedCaveats?: string[];
  hypothesisVsFindingDistinction?: HypothesisVsFindingDistinction;
  scopeOfSupport: ScopeOfSupport;
  quantifierMatch?: boolean;
}

export type OverclaimingViolationType =
  | 'AUTHENTIC_BUT_IRRELEVANT'
  | 'PARTIAL_SUPPORT_TREATED_AS_FULL'
  | 'QUALIFICATION_OMISSION'
  | 'HYPOTHESIS_TREATED_AS_FINDING'
  | 'CONCLUSION_CONTRADICTS_ABSTRACT_INTERPRETATION'
  | 'DUPLICATE_DATASET_DOUBLE_COUNTING';

export interface OverclaimingAudit {
  overclaimingDetected: boolean;
  violationTypes: OverclaimingViolationType[];
  details: string[];
}

export interface ProvenanceEntityNode {
  nodeId: string;
  type: 'PUBLICATION' | 'ORGANIZATION' | 'AUTHOR' | 'PRIMARY_DATASET' | 'WITNESS' | 'PHYSICAL_ARTIFACT';
  label: string;
  canonicalId?: string;
}

export interface ProvenanceEdge {
  fromNodeId: string;
  toNodeId: string;
  relation: 'DERIVED_FROM' | 'AUTHORED_BY' | 'ANALYZES_DATASET' | 'SYNDICATES' | 'CITES_WITNESS';
}

export interface EvidentiaryProvenanceGraph {
  nodes: ProvenanceEntityNode[];
  edges: ProvenanceEdge[];
  effectiveIndependentSourcesCount: number;
  underlyingDatasetCount: number;
  distinctInvestigatorCount: number;
}

export interface SemanticEvidenceValidationResult {
  links: SemanticEvidenceLink[];
  overclaimingAudit: OverclaimingAudit;
  provenanceGraph?: EvidentiaryProvenanceGraph;
  semanticEvidenceLevel: 'ROBUST_SUPPORT' | 'PARTIAL_CONCORDANCE' | 'MIXED_EVIDENCE' | 'CONTRADICTED' | 'IRRELEVANT_EVIDENCE' | 'INSUFFICIENT_GROUNDING';
  semanticEvidenceScope?: 'INDIVIDUAL_EVIDENCE_LINKS' | 'OVERALL_CLAIM';
  sourceCountScope?: 'ENTIRE_ASSESSMENT' | 'PER_PROPOSITION';
  effectiveIndependentSourcesCount?: number;
}

export type QualitativeTier =
  | 'HIGH_EVIDENCE_CONCORDANCE'
  | 'MODERATE_EVIDENCE_CONCORDANCE'
  | 'PRELIMINARY_EVIDENCE'
  | 'CONTRADICTED_BY_EVIDENCE'
  | 'NOT_EMPIRICALLY_TESTABLE'
  | 'INSUFFICIENT_EVIDENCE';

export interface EpistemicUncertainty {
  numericalConfidenceAvailable: boolean; // strictly false until calibration model version is set
  calibrationModelVersion?: string | null;
  qualitativeTier: QualitativeTier;
  conformalPredictionSet: DisplayBadge[];
  disclosedGaps: string[];
}

export type ExtrapolationFallacyType =
  | 'ANNUALIZATION_ERROR'
  | 'BASE_RATE_CONFLATION'
  | 'SAMPLE_TO_POPULATION_LEAP'
  | 'CHERRY_PICKED_TIMEFRAME'
  | 'CROSS_CATEGORY_EQUATION'
  | 'GEOGRAPHIC_GENERALIZATION';

export interface StatisticalDistortionGenealogy {
  sourceMetric: {
    rawFigure: number | string;
    unit: string;
    timeframe: string;
    description: string;
  };
  claimedMetric: {
    rawFigure: number | string;
    unit: string;
    timeframe: string;
    description: string;
  };
  extrapolationFallacy: ExtrapolationFallacyType;
  multiplicationFactor?: number;
  genealogyExplanation: string;
  citedEvidenceIds: string[]; // Strictly bound to evidenceRegistry [E1..En]
}

export interface CredibilityAssessmentV2 {
  assessmentId: string;
  schemaVersion: '2.0.0';
  assessmentVersion?: number;
  supersededBy?: string | null;
  correctionReason?: string | null;
  videoContext?: AssessmentVideoContext;
  claimText: string;
  classification: OrthogonalClassification;
  claimDecomposition: ClaimDecompositionProposition[];
  evidenceRegistry: Record<string, EvidenceRegistryItem>;
  reasoningAssessment: ReasoningAssessment;
  backendAuditFlags: BackendAuditFlags;
  uncertainty: EpistemicUncertainty;
  semanticValidation?: SemanticEvidenceValidationResult;
  inferenceAudits?: InferenceStepAudit[];
  distortionGenealogy?: StatisticalDistortionGenealogy;
}

export interface MultiModelConsensusMetadata {
  checked: boolean;
  agreed: boolean;
  primaryVerdict: string;
  secondaryVerdict?: string;
  adjudicationRationale?: string;
  crossExaminedAt: number;
  steelManDefense?: string;
  inquisitorChallenge?: string;
  evidentiaryBalance?: string;
  epistemicConfidence?: number;
  detectedFallacies?: string[];
  isNormativeValueJudgment?: boolean;
  isMultilateralWarObservation?: boolean;
  blindReviewApplied?: boolean;
  bayesFactor?: number;
  priorProbability?: number;
}

export interface ClaimLedgerSummary {
  totalClaimsChecked: number;
  confirmedCount: number;
  disputedCount: number;
  unprovenCount: number;
  falseCount: number;
  contextualCount: number;
  highestSeverityVerdict: 'verified_true' | 'mostly_true' | 'disputed' | 'false_claim' | 'unproven' | 'none';
  verdictHeadline: string;
  priorityNotice?: string;
  verifiableRatio: number;
}

export interface EvidenceSummary {
  independentPublishers: number;
  tierA: number;
  tierB: number;
  secondarySources: number;
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
    label: string;
    confidence: 'high' | 'medium' | 'low';
    confidenceInterpretation: string; // v8.5
    analysisState: VerificationState | ErrorState; // v10.0: Migration from AnalysisState
    verificationState?: VerificationState; // v10.0
    evidenceCoverage: {
      checked: number;
      total: number;
      label: string;   // e.g. "3 of 10 claims verified"
      isPartial?: boolean; // v11.1: Signal if extraction was timed out
    } | null;          // null for STRUCTURAL_ONLY state
  };
  quickVerdict: string;
  narrative: string;
  riskNote: string;
  positiveDrivers: UIDriver[];
  negativeDrivers: UIDriver[];
  sources: UISource[];
  conclusion: string;
  conclusionSources?: UISource[];
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
    sources?: Array<{
      title: string;
      url?: string;
      domain?: string;
      trustLevel?: string;
      type?: string;
      snippet?: string;
    }>;
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
    verified_true: number;
    mostly_true: number;
    disputed: number;
    unproven: number;
    misleading: number;
    false_claim: number;
    religious_belief: number;
    opinion_claim: number;
    satire_claim: number;
    verification_timeout: number;
    checkedClaimsRatio?: number;
    extractionPartial?: boolean;
    verificationCoverageRatio?: number; // v11.5: % of factual claims reaching terminal verification
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
  processingMetadata?: {
    verificationPipeline?: VerificationPipelineProvenance;
    [key: string]: any;
  };
}

export interface VerificationPipelineProvenance {
  verifiedBy: string;
  grounded: boolean;
  groundingProvider: string;
  embeddingModel: string;
  cacheVersion: {
    embedding: number;
    verification: number;
    citation: number;
  };
  verifiedAt: string;          // ISO String when Gemini ran verification
  cacheGeneratedAt: string;     // ISO String when written to cache
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
  | "Highly Reliable"
  | "Reliable"
  | "Mixed"
  | "Low"
  | "Misleading"
  | "Opinion/Belief Content"
  | "Misleading Framing"
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
  | "Safety Capped – Verify Claims" // Harm cap applied
  | "Manipulative Opinion";

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
  reputation?: number;   // v8.8: Historical reliability score
  intentToMislead?: number; // v8.1: System exploitation/manipulation detection (0-100)
}

export type TrustVertical = 'general' | 'finance' | 'health' | 'religion' | 'history' | 'politics';

// ============================================
// v8.0: CATEGORY-AWARE EPISTEMIC SCORING TYPES
// ============================================

export type VideoCategory =
  | 'science'
  | 'science_trivia'
  | 'health'
  | 'financial'
  | 'legal'
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
  honestRating: number | null; // v12.0: Nullable after scoring removal
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

export const GeminiSingleExtractionSchema = z.object({
  text: z.string(),
  nature: z.string().optional().default("FACTUAL"), // FACTUAL | OPINION | PREDICTION | THEORY | BELIEF | SATIRE
  framing: z.string().optional().default("ASSERTIVE"), // HEDGED | BALANCED | ASSERTIVE | ABSOLUTE | MANIPULATIVE
  confidence: z.coerce.number().default(0.7),
  importance: z.coerce.number().optional().default(0.5),
  isVerifiableEvent: z.boolean().optional().default(true),
  honestyWashingRisk: z.boolean().optional().default(false),
  assertiveness: z.string().optional().default("moderate"),
  claimStrength: z.string().optional().default("moderate"),
  start: z.coerce.number().optional(),
  end: z.coerce.number().optional(),
  speaker: z.string().optional(),
});

export const GeminiExtractionSchema = z.object({
  claims: z.array(GeminiSingleExtractionSchema),
  summary: z.string().optional().default(""),
  detectedLanguage: z.string().optional(),
  domain: z.string().optional(),
  stance: z.string().optional(),
  cautionLevel: z.string().optional(),
  isLaunchNews: z.boolean().optional(),
  primaryIntent: z.string().optional(),
  isSensitive: z.boolean().optional(),
});

export const GeminiIntelligenceSchema = z.object({
  summary: z.string(),
  conclusion: z.object({
    label: z.string(),
    text: z.string(),
    confidence: z.number(),
    sources: z.array(z.object({
      title: z.string(),
      url: z.string().optional(),
      domain: z.string().optional(),
      trustLevel: z.string().optional(),
      type: z.string().optional(),
      snippet: z.string().optional()
    })).optional()
  }),
  knowledgeDensity: z.number().optional(),
  keyThemes: z.array(z.string()),
  viewerNote: z.string(),
  chapters: z.array(z.object({
    index: z.number(),
    title: z.string(),
    start: z.number(),
    end: z.number(),
    videoRating: z.number().optional(), // Replaces trustIndex
    primaryTopics: z.array(z.string())
  })).optional()
});

export const GeminiSingleVerificationSchema = z.object({
  claimId: z.string(),
  claim: z.string().optional().default(""),
  claimType: z.string().optional().default("factual"), // Relaxed: Gemini may return values outside the predefined enum
  nature: z.string().optional(),
  label: z.string(),
  evidenceLevel: z.string().optional().default("MODERATE"), // STRONG | MODERATE | WEAK | NONE | CONTRADICTED
  rating: z.coerce.number().nullable().optional(),
  confidence: z.coerce.number().default(0.7),
  freshness: z.string().optional().default("current"),
  summary: z.string().optional().default(""),
  verifiedFacts: z.preprocess((val) => {
    if (Array.isArray(val)) return val;
    if (typeof val === "string") return val.split(/\n|;/).map((s) => s.trim()).filter(Boolean);
    return [];
  }, z.array(z.string())).default([]),
  missingEvidence: z.preprocess((val) => {
    if (Array.isArray(val)) return val;
    if (typeof val === "string") return val.split(/\n|;/).map((s) => s.trim()).filter(Boolean);
    return [];
  }, z.array(z.string())).default([]),
  sourceConsensus: z.string().optional().default("CONSENSUS"),
  riskLevel: z.string().optional().default("low"),
  publicNote: z.string().optional().default(""),
  recommendedAction: z.string().optional().default(""),
  reasonCategory: z.string().optional().default("insufficient_evidence"),
  citedEvidenceIds: z.array(z.string()).optional().default([]),
  sources: z.array(z.object({
    title: z.string().optional().default("Reference Source"),
    url: z.string().optional().default(""),
    snippet: z.string().optional().default(""),
    sourceType: z.string().optional(),
    whatItSupports: z.string().optional(),
    whatItDoesNotEstablish: z.string().optional(),
    sourceRole: z.string().optional(),
  })).optional().default([]),
  classificationConfidence: z.coerce.number().optional(),
  historicalEvidenceConfidence: z.coerce.number().optional(),
  evidenceDetails: z.object({
    scriptural: z.string().optional(),
    historical: z.string().optional(),
    scientific: z.string().optional(),
  }).optional(),
  consensusDetails: z.object({
    theology: z.string().optional(),
    historical: z.string().optional(),
    scientific: z.string().optional(),
  }).optional(),
  evidenceAssessment: z.object({
    scripturalSupport: z.string().optional(),
    independentHistoricalCorroboration: z.string().optional(),
    empiricalVerification: z.string().optional(),
  }).optional(),
  beliefAssessment: z.string().optional(),
  misinformationVerdict: z.string().optional(),
  confidenceMeaning: z.string().optional(),
  framingAssessment: z.string().optional(),
  epistemicLimitations: z.preprocess((val) => {
    if (Array.isArray(val)) return val;
    if (typeof val === "string") return [val];
    return [];
  }, z.array(z.string())).optional().default([]),
  framingViolationDetail: z.object({
    violationType: z.string().optional(),
    assertedEvidenceQuality: z.string().optional(),
    explanation: z.string().optional(),
  }).optional(),
  claimDomain: z.string().optional(),
  claimNature: z.string().optional(),
  verdictBasis: z.preprocess((val) => {
    if (Array.isArray(val)) return val;
    if (typeof val === "string") return [val];
    return [];
  }, z.array(z.string())).optional().default([]),
  evidence: z.array(z.object({
    type: z.string(),
    strength: z.string(),
  })).optional(),
  consensus: z.array(z.object({
    domain: z.string(),
    level: z.string(),
  })).optional(),
  evidenceTraceability: z.object({
    isCompoundClaim: z.boolean().optional().default(false),
    components: z.array(z.object({
      componentId: z.string().optional().default(""),
      statement: z.string().optional().default(""),
      type: z.enum(['PREMISE_OBSERVATION', 'INFERENTIAL_CONCLUSION', 'CONTEXTUAL_ASSERTION']).or(z.string()).optional().default('PREMISE_OBSERVATION'),
      factualAccuracy: z.enum(['ACCURATE_OBSERVATION', 'INACCURATE_OBSERVATION', 'UNVERIFIABLE']).or(z.string()).optional().default('ACCURATE_OBSERVATION'),
      inferentialValidity: z.string().optional(),
      explanation: z.string().optional().default(""),
      detectedFallacy: z.string().optional(),
      evidenceIds: z.array(z.string()).optional().default([]),
    }).passthrough()).optional().default([]),
    evidenceTraces: z.array(z.object({
      evidenceId: z.string().optional().default(""),
      componentId: z.string().optional().default(""),
      sourceTitle: z.string().optional().default(""),
      sourceUrl: z.string().optional().default(""),
      retrievalTimestamp: z.number().optional().default(Date.now()),
      sourceType: z.string().optional().default(""),
      provenance: z.object({
        originAgencyOrAuthor: z.string().optional().default(""),
        isIndependentOfSubject: z.boolean().optional().default(true),
        independenceValidation: z.string().optional().default(""),
      }).passthrough().optional().default({
        originAgencyOrAuthor: "",
        isIndependentOfSubject: true,
        independenceValidation: "",
      }),
      sourceIndependence: z.object({
        publisherIndependentOfSubject: z.boolean().optional().default(true),
        underlyingDataIndependentOfSubject: z.boolean().optional().default(true),
        analysisIndependentlyConducted: z.boolean().optional().default(true),
        corroborationType: z.string().optional().default(""),
      }).passthrough().optional(),
      automatedVerification: z.object({
        urlResolved: z.boolean().optional().default(false),
        passageLocated: z.boolean().optional().default(false),
        passageMatchesSource: z.boolean().optional().default(false),
        supportsClaimComponent: z.boolean().optional().default(false),
        verificationMethod: z.string().optional().default(""),
        lastVerifiedAt: z.string().optional().default(""),
        locatedContextSnippet: z.string().optional(),
        omittedContextDetected: z.boolean().optional(),
        omittedContextExplanation: z.string().optional(),
      }).passthrough().optional(),
      exactPassage: z.string().optional().default(""),
      claimComponentAddressed: z.string().optional().default(""),
      relationship: z.string().optional().default(""),
      verificationStatus: z.string().optional().default(""),
      knownLimitations: z.array(z.string()).optional().default([]),
    }).passthrough()).optional().default([]),
    inferentialBridgeSummary: z.string().optional().default(""),
    overallSynthesis: z.object({
      premisesVerdict: z.string().optional(),
      conclusionVerdict: z.string().optional(),
      finalAdjudication: z.string().optional(),
    }).passthrough().optional(),
  }).passthrough().optional(),
  calibratedConfidence: z.object({
    claimDecomposition: z.number().nullable().optional(),
    premiseAssessment: z.number().nullable().optional(),
    sourceVerification: z.number().nullable().optional(),
    inferenceAssessment: z.number().nullable().optional(),
    overallVerdict: z.number().nullable().optional(),
  }).passthrough().optional(),
  classification: z.object({
    propositionType: z.string().optional(),
    evidenceStatus: z.string().optional(),
    reasoningValidity: z.string().optional(),
    displayBadge: z.string().optional(),
  }).passthrough().optional(),
  claimDecomposition: z.array(z.object({
    propositionId: z.string(),
    role: z.string(),
    text: z.string(),
    propositionType: z.string(),
    assessment: z.string(),
    supportingEvidenceIds: z.array(z.string()).optional().default([]),
    contradictingEvidenceIds: z.array(z.string()).optional().default([]),
    independentPrimarySourceCount: z.number().optional().default(0),
  }).passthrough()).optional(),
  evidenceRegistry: z.record(z.string(), z.any()).optional(),
  reasoningAssessment: z.object({
    premisesVerifiedAccurate: z.array(z.string()).optional().default([]),
    conclusionFollowsDeductively: z.boolean().optional().default(false),
    conclusionFollowsInductively: z.boolean().optional().default(false),
    evaluatedAlternativeExplanations: z.array(z.object({
      explanation: z.string(),
      supportingEvidenceIds: z.array(z.string()).optional().default([]),
    }).passthrough()).optional().default([]),
  }).passthrough().optional(),
  uncertainty: z.object({
    numericalConfidenceAvailable: z.boolean().optional().default(false),
    calibrationModelVersion: z.string().nullable().optional(),
    qualitativeTier: z.string().optional(),
    conformalPredictionSet: z.array(z.string()).optional().default([]),
    disclosedGaps: z.array(z.string()).optional().default([]),
  }).passthrough().optional(),
}).passthrough();

export const GeminiVerificationSchema = z.object({
  verifications: z.array(GeminiSingleVerificationSchema),
}).passthrough();

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
  webhookPending?: boolean;
}


export interface UserConfig {
  userId: string;
  channelType: ChannelType;

  languages: string[];
  dubbingMode: 'none' | 'standard' | 'voice_clone';
  genLangSubs: boolean;
  generateDubbing: boolean;
  enableDubbing?: boolean;
  dubbingLanguages?: string[];
  enableFactCheck: boolean;
  priority: 'low' | 'normal' | 'high';
  duration?: number; // duration in seconds
  primaryLanguage?: string;
  spokenLanguages?: string[];
}

export interface ExecutionPlan {
  jobId: string;
  videoId?: string;
  title?: string;
  description?: string;
  thumbnailUrl?: string;
  thumbnail?: string;
  channelId?: string;
  channelName?: string;
  channelAvatarUrl?: string;
  category?: string;
  tags?: string[];
  topics?: string[];
  providedSources?: string[];
  visibility?: string;
  enableCredibility?: boolean; // Independent Credibility / Fact-Checking system
  enableDubbing?: boolean;     // Independent Dubbing system
  enableSubtitles?: boolean;   // Independent Subtitles system
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
  sourceLanguage?: string;  // Authentic source/original video spoken language
  spokenLanguages?: string[]; // Multilingual / code-mixed spoken languages
  guestNames?: string[];    // v7.2: Persistent identity help
  sensitiveTopics?: ('health' | 'politics' | 'finance' | 'religion' | 'other')[]; // v7.2: Risk-aware scoring
  priorityMode?: 'speed' | 'balanced' | 'accuracy'; // v7.2: Pipeline depth control
  synthesisTier?: 'standard' | 'deep' | 'podcast';
  factCheckTier?: 'short' | 'standard' | 'full_ground';
  factCheckEnabled?: boolean;
  
  // v8.0: Category-Aware Scoring
  videoCategory?: string;      // Upload category mapped to scoring profile
  scoringProfile?: string;     // Override for custom scoring profiles
  
  creatorDNA?: CreatorDNA; // persistent style memory
  enableABHooks?: boolean; // generate 3 variants for first 10s
  generateDubbing: boolean;
  genLangSubs: boolean;
  generateSubtitles?: boolean;
  channelType: ChannelType;
  autoChapters?: boolean;
  enableDiarization?: boolean;
  diarization?: boolean;
  dubbingLanguages?: string[];
  dubbingTier?: 'audio_track';
  uncannyMitigation?: 'none' | 'cadence_lock' | 'smart_cutaway';
  isometryMode?: 'natural' | 'strict_syllable';
  cinemaGrade?: boolean;
  stemIsolation?: boolean;
  studioMneStemUrl?: string; // Original studio-provided clean M&E stem URL (bypasses neural demixing for 100% clean M&E)
  reelIndex?: number;        // For distributed 15-minute reel processing (0-based)
  totalReels?: number;       // Total reels in multi-reel film job
  reelTimeOffsetMs?: number; // Starting offset in milliseconds for this reel
  isReelJob?: boolean;       // Flag indicating this is a sub-reel task
  subtitleLanguages?: string[];
  subtitleTier?: 'ultra';
  voiceGender?: 'auto' | 'male' | 'female';
  durationSeconds?: number;

  duration?: number;
  maxClaims: number;
  priority: 'low' | 'normal' | 'high';
  skipCache: boolean;
  disputedClaimIndex?: number;
}

/**
 * Returns true when the independent Credibility / Fact-Checking system is enabled.
 */
export function isCredibilityEnabled(plan?: Partial<ExecutionPlan> | Record<string, any> | null): boolean {
  if (!plan) return false;
  const p = plan as Record<string, any>;
  if (typeof p.enableCredibility === "boolean") return p.enableCredibility;
  if (typeof p.factCheckEnabled === "boolean") return p.factCheckEnabled;
  if (typeof p.enableFactCheck === "boolean") return p.enableFactCheck;
  return !!p.enableFactChecking;
}

/**
 * Returns true when Dubbing / Audio Localization is specifically enabled.
 * ZERO AUTOMATIC DUBBING: Dubbing is strictly opt-in and manual.
 * Requires both the dubbing flag AND explicit dubbing target languages.
 */
export function isDubbingEnabled(plan?: Partial<ExecutionPlan> | Record<string, any> | null): boolean {
  if (!plan) return false;
  const p = plan as Record<string, any>;
  const dubLangs = Array.isArray(p.dubbingLanguages) && p.dubbingLanguages.length > 0
    ? p.dubbingLanguages
    : (Array.isArray(p.languages) ? p.languages : []);
  const flag = typeof p.enableDubbing === "boolean" ? p.enableDubbing : !!p.generateDubbing;
  return flag && dubLangs.length > 0;
}

/**
 * Returns true when Subtitles generation is specifically enabled.
 */
export function isSubtitlesEnabled(plan?: Partial<ExecutionPlan> | Record<string, any> | null): boolean {
  if (!plan) return false;
  const p = plan as Record<string, any>;
  if (typeof p.enableSubtitles === "boolean") return p.enableSubtitles;
  if (typeof p.genLangSubs === "boolean") return p.genLangSubs;
  return !!p.generateSubtitles;
}

/**
 * Returns true when any Localization system (Dubbing or Subtitles) is enabled.
 * Completely independent from Credibility.
 */
export function isLocalizationEnabled(plan?: Partial<ExecutionPlan> | Record<string, any> | null): boolean {
  return isDubbingEnabled(plan) || isSubtitlesEnabled(plan);
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
  | 'dubbing-reel-requested'
  | 'dubbing-reel-assemble'
  | 'fact-complete'
  | 'dubbing-complete'
  | 'aggregation-ready'
  | 'resolution-requested'
  | 'copyright-processing'
  | 'copyright-complete'
  | 'credibility-synthesis';

export type GatewayDecisionStatus = 'APPROVED' | 'REJECTED' | 'MANUAL_REVIEW';

export interface ViolatingClaimInfo {
  text: string;
  timestampMs?: number;
  reason: string;
}

export interface FlaggedTimestampInfo {
  startMs: number;
  endMs: number;
  reason: string;
}

export interface AutoChapterInfo {
  startMs: number;
  endMs: number;
  title: string;
  summary: string;
}

export interface ExtractedEntityInfo {
  name: string;
  category: "PERSON" | "ORGANIZATION" | "LOCATION" | "LAW_POLICY" | "EVENT" | "CONCEPT" | string;
  context?: string;
}

export interface VideoGatewayDecision {
  status: GatewayDecisionStatus;
  confidence: number;
  evaluatedAt: number;
  
  // Available when status === 'APPROVED'
  summary?: string;
  category?: string;
  tags?: string[];
  autoChapters?: AutoChapterInfo[];
  entities?: ExtractedEntityInfo[];
  
  // Available when status === 'REJECTED'
  rejectionReason?: string;
  violatingPolicies?: string[];
  violatingClaims?: ViolatingClaimInfo[];
  
  // Available when status === 'MANUAL_REVIEW'
  reviewReason?: string;
  sensitiveTopics?: string[];
  flaggedTimestamps?: FlaggedTimestampInfo[];

  // Appeal fields
  appealed?: boolean;
  appealedAt?: number;
  appealReason?: string;
  appealStatus?: 'pending' | 'approved' | 'rejected';
}

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
  mneStemPath?: string;
  stems?: {
    mne?: string;
    dialogue?: Record<string, string>;
    master?: Record<string, string>;
    vocals?: string;
  };
  mneValidation?: Record<string, any>;
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
  model?: string;
  provider?: string;
  spokenLanguages?: string[];
  isMultilingual?: boolean;
  isCodeMixed?: boolean;
  entities?: ExtractedEntityInfo[];
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
  language?: string;
  words: WordTimestamp[];
  emotionTag?: string;
  energyDb?: number;
  speakingRateRatio?: number;
  stabilityOverride?: number;
  similarityBoostOverride?: number;
  deliveryStyle?: string;
  pitchRangeSemitones?: number;
  voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
  emotionalIntensity?: {
    anger: number;
    sadness: number;
    joy: number;
    fear: number;
    disgust: number;
    surprise: number;
  };
  energyEnvelopePattern?: "rising" | "falling" | "flat" | "dynamic";
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
  richSources?: RichSource[];
  sourceStatus?: 'complete' | 'partial' | 'missing';
  verifiedAcademicMetadata?: VerifiedAcademicMetadata[];
  timestampStart: number;
  timestampEnd: number;
  confidence: number;
  severity?: ClaimSeverity;
  severityLabel?: string;
  multiModelConsensus?: MultiModelConsensusMetadata;
}

export interface SourceReference {
  title: string;
  url?: string;
  snippet: string;
  relevanceScore: number;
  tier?: SourceTier;       // v5.0: Evidence provenance
  provenance?: string;     // v5.0: Source description (e.g. "News Archive")
  urlVerification?: UrlVerificationRecord;
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
  videoRating?: number;
  primaryTopics: string[];
}

export interface CredibilityResult {
  analysisState: VerificationState | ErrorState;      // v8.2: Epistemic state layer
  scoreAvailable: boolean;           // v8.2: UI guard
  analysisFailureReason?: AnalysisFailureReason; // v8.2: Structured failure
  viewerNote?: string;               // v8.2: Dynamic message
  uiReport?: UIReport;               // v8.3: Human-friendly UI format
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
    religious_belief: number;   // v11.5
    opinion_claim: number;      // v11.5
    satire_claim: number;       // v11.5
    verification_timeout: number; // v11.5
    cacheHitRate?: number;
    checkedClaimsRatio?: number; // v5.0: transparency metric
    extractionPartial?: boolean; // v11.1
    verificationCoverageRatio?: number; // v11.5
  };
  claimLedger?: ClaimLedgerSummary;
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
  contextualFlags?: ContextualFlag[];
  harmCapApplied?: boolean;
  harmCapReason?: string;
  rawScoreBeforeCap?: number;
  honestyBreakdown?: any;
  penaltyApplied?: number;
  
  // v8.1 Hardened Trust (Stable)
  hardeningMetadata?: HardeningMetadata;           // Structured logs for regulators
  intentToMisleadScore?: number;                   // Strategic manipulation (0-100)
  effectiveCategory?: string;                      // Risk-hierarchy resolved category
  
  scoringMethod: 'strict' | 'balanced';
  synthesisTier: 'standard' | 'deep' | 'podcast';
  factCheckTier?: 'short' | 'standard' | 'full_ground';
  isLongform: boolean;
  isFinal: boolean;         // Preliminary vs Final
  
  sources?: any[];
  richSources?: RichSource[];

  summary?: string;
  conclusion?: {
    label: string;
    text: string;
    confidence: number;
    sources?: any[];
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
    verificationAttempted?: number;   // v11.5: Granular tracking
    verificationSucceeded?: number;   // v11.5
    verificationTimedOut?: number;    // v11.5
    verificationCoverage?: number;    // v12.0
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
  processingMetadata?: {
    verificationPipeline?: VerificationPipelineProvenance;
    [key: string]: any;
  };
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
  emotionTag?: string;
  energyDb?: number;
  speakingRateRatio?: number;
  stabilityOverride?: number;
  similarityBoostOverride?: number;
  deliveryStyle?: string;
  pitchRangeSemitones?: number;
  voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
  emotionalIntensity?: {
    anger?: number;
    sadness?: number;
    joy?: number;
    fear?: number;
    disgust?: number;
    surprise?: number;
  };
  energyEnvelopePattern?: "rising" | "falling" | "flat" | "dynamic";
  breathingPattern?: "natural" | "rapid" | "suppressed";
  syllableBudgetCompliance?: number;
  synthesizedAudioUrl?: string;
  durationMs?: number;
  actualSynthesizedDurationMs?: number;
  speedFactor?: number;
  terminologyWarning?: string;
  terminologyViolations?: Array<{
    termId: string;
    source: string;
    disallowedFound: string;
    suggested: string;
    context?: string;
  }>;
  terminologyComplianceRate?: number;
  numericalParityVerified?: boolean;
  numericalParityWarning?: string;
  semanticParityScore?: number;
  reviewRecommended?: boolean;
  polarityFlipped?: boolean;
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
  stems?: {
    mne?: string | null;
    dialogue?: string;
    master?: string;
    vocals?: string | null;
  };
  meta?: {
    voice?: string;
    durationSec: number;
    mneValidationStatus?: 'passed' | 'degraded' | 'failed' | 'not_required';
    mneSource?: string;
    dialogueBleedDb?: number;
  };
}

/**
 * 🛡️ Persistent Dubbing Checkpoint Schema
 * Persists all 5 resume anchors atomically to guarantee zero duplicate Google Cloud Translation v3 calls
 * and zero re-billed ElevenLabs eleven_v4 credits on partial failure resumption.
 */
export interface DubbingCheckpoint {
  jobId: string;
  targetLang: string;
  stage: "translated" | "synthesizing" | "stitching" | "completed";
  isolatedVocalUrl?: string | null;              // Skips Step 1.6 neural separation on rerun
  meStemUrl?: string | null;                     // Reused directly in FFmpeg mastering
  voiceMapping?: Record<string, string>;         // Locks speaker -> voiceId across partial reruns
  translatedSegments?: DubbingSegment[];         // 100% preserved ($0 Translation v3 rerun cost)
  synthesizedUrls?: Record<number | string, string>; // Only commits ffprobe-verified chunks (>1KB, >100ms)
  leaseExpiresAt?: number;                       // Prevents duplicate concurrent retry workers
  updatedAt: number;
  status?: string;                               // Backward-compatible status alias
  masterAudioUrl?: string;
  directAudioUrl?: string;
  dialogueStemUrl?: string;
  subtitleUrl?: string;
  translationUrl?: string;
  masterVideoUrl?: string;
  totalSegments?: number;
  completedAt?: number;
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
  trustLabel: TrustLabel;   // Highly Reliable | Reliable | etc.
  confidence: number;       // 0-1
  confidenceTier: 'high' | 'medium' | 'low';
  speakerConfidence?: number; // v5.3
  rating?: number;
  summary?: string;
  conclusion?: {
    label: string;
    text: string;
    confidence: number;
    sources?: any[];
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
    transcriptionUrl?: string;
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

export interface EvidenceLineage {
  evidenceId: string;
  sourceGraph: string[];
  retrievalSources: string[];
  retrievalTimestamp: number;
  verificationPath: string;
  modelVersion: string;
  confidenceTrace: number[];
}

export interface EpistemicTelemetry {
  claimId: string;
  claimHash: string;
  videoId: string;
  category: string;
  riskLevel: string;
  verificationOutcome: string;
  verificationPath: string;
  latencyMs: number;
  providerUsed: string;
  fallbackUsed: boolean;
  cacheHit: boolean;
  retryCount: number;
  confidenceDelta: number;
  costUsd: number;
  timestamp: number;
}

// ============================================
// DUBBING PROSODY, REEL ORCHESTRATION & CREATOR STUDIO TYPES
// ============================================

export type ElevenLabsEmotionTag =
  | 'whispers'
  | 'shouts'
  | 'laughs'
  | 'sighs'
  | 'gasps'
  | 'excited'
  | 'sorrowful'
  | 'sad'
  | 'angry'
  | 'said angrily'
  | 'sarcastic'
  | 'calm'
  | 'serious';

export interface EmotionalIntensityProfile {
  anger: number;
  sadness: number;
  joy: number;
  fear: number;
  disgust: number;
  surprise: number;
}

export interface SegmentProsodyCue {
  segmentIndex: number;
  emotionTag?: ElevenLabsEmotionTag;
  energyDb?: number;
  speakingRateRatio?: number;
  stabilityOverride?: number;
  similarityBoostOverride?: number;
  deliveryStyle?: string;
  pitchRangeSemitones?: number;
  speakingRateSyllablesPerSec?: number;
  voiceQuality?: 'breathy' | 'modal' | 'creaky' | 'pressed';
  emotionalIntensity?: EmotionalIntensityProfile;
  energyEnvelopePattern?: 'rising' | 'falling' | 'flat' | 'dynamic';
  breathingPattern?: 'natural' | 'rapid' | 'suppressed';
  accentStressMarkers?: string[];
}

export interface PronunciationRule {
  id: string;
  term: string;
  replacement: string;
  ipaOrPhonetic?: string;
  caseSensitive?: boolean;
}

export interface DubbingEditableSegment {
  index: number;
  startMs: number;
  endMs: number;
  speaker?: string;
  originalText: string;
  translatedText: string;
  editedText?: string;
  emotionTag?: string;
  energyDb?: number;
  stabilityOverride?: number;
  similarityBoostOverride?: number;
  pitchRangeSemitones?: number;
  speakingRateRatio?: number;
  deliveryStyle?: string;
  voiceQuality?: 'breathy' | 'modal' | 'creaky' | 'pressed';
  voiceId?: string;
  synthesizedAudioUrl?: string;
  durationMs?: number;
  actualSynthesizedDurationMs?: number;
  speedFactor?: number;
  locked?: boolean;
  updatedAt?: number;
  terminologyWarning?: string;
  terminologyViolations?: Array<{
    termId: string;
    source: string;
    disallowedFound: string;
    suggested: string;
    context?: string;
  }>;
  terminologyComplianceRate?: number;
  numericalParityVerified?: boolean;
  numericalParityWarning?: string;
  semanticParityScore?: number;
  reviewRecommended?: boolean;
  polarityFlipped?: boolean;
}

export interface DubbingEditableManifest {
  jobId: string;
  videoId?: string;
  userId: string;
  language: string;
  sourceLanguage: string;
  totalDurationMs: number;
  mneStemUrl?: string | null;
  dialogueStemUrl?: string | null;
  masterAudioUrl?: string | null;
  masterVideoUrl?: string | null;
  subtitleUrl?: string | null;
  subtitleFormat?: 'srt' | 'vtt';
  mneGain?: number;
  dialogueGain?: number;
  pronunciationGlossary: PronunciationRule[];
  segments: DubbingEditableSegment[];
  version: number;
  revision?: number;
  regenerationCount?: number;
  updatedAt: number;
}

export interface DubbingReelTaskPayload {
  jobId: string;
  videoId?: string;
  userId: string;
  reelIndex: number;
  totalReels: number;
  startMs: number;
  endMs: number;
  durationMs: number;
  languages: string[];
  sourceLanguage: string;
  dubbingTier?: 'audio_track';
  preferVoiceCloning: boolean;
  mneStemUrl?: string | null;
  voiceIdsBySpeaker?: Record<string, Record<string, string>>;
  speakerProfiles?: Array<{
    speakerId: string;
    gender: string;
    tone: string;
    emotion: string;
    style: string;
    pitch?: number;
    speakingRate?: number;
  }>;
  segmentsByLanguage: Record<string, Array<{
    index: number;
    start: number;
    end: number;
    originalText: string;
    translatedText: string;
    speaker?: string;
    isHook?: boolean;
    emotionTag?: string;
    energyDb?: number;
    stabilityOverride?: number;
    similarityBoostOverride?: number;
  }>>;
  idempotencyKey: string;
}

export interface DubbingReelAssemblyPayload {
  jobId: string;
  videoId?: string;
  userId: string;
  totalReels: number;
  totalDurationMs: number;
  languages: string[];
  sourceLanguage: string;
  mneStemUrl?: string | null;
  mneValidation?: Record<string, any>;
  dubbingTier?: 'audio_track';
  videoUrl: string;
  idempotencyKey: string;
}


