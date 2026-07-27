/**
 * Report types — UI reports, credibility results, synthesis, explainability,
 * aggregation, governance, appeals, and telemetry.
 */

import { ClaimStatus, ClaimSeverity } from './claims.js';
import {
  EvidenceLevel,
  SourceTier,
  VerifiedClaim,
} from './verification.js';
import {
  VerificationState,
  ErrorState,
  AnalysisFailureReason,
  InstitutionalTrustFactors,
  TrustLabel,
  TrustVertical,
  TrustDeduction,
  HonestyBreakdown,
  ContextualFlag,
  HardeningMetadata,
  RepairSuggestion,
  ConsistencyIssue,
} from './scoring.js';
import { TranscriptData, ArtifactsMap, DubbingResult } from './media.js';
import { CredibilityErrorCode } from './errors.js';


// ============================================
// UI TYPES
// ============================================

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
    text: string;
    evidenceLevel: EvidenceLevel;
  }[];
  modelInterpretations: {
    text: string;
    basis: string;
  }[];
  uncertainInferences: {
    text: string;
    missingDataReason: string;
  }[];
  narrative: string;
}

export interface TraceabilityMap {
  [sentenceHash: string]: string[];
}

export interface UIReport {
  summary: {
    rating: number | null;
    truthScore?: number | null;
    honestyScore?: number | null;
    rationalityScore?: number | null;
    label: string;
    confidence: 'high' | 'medium' | 'low';
    confidenceInterpretation: string;
    rationalityContributedToComposite?: boolean;
    analysisState: VerificationState | ErrorState;
    verificationState?: VerificationState;
    evidenceCoverage: {
      checked: number;
      total: number;
      label: string;
      isPartial?: boolean;
    } | null;
  };
  quickVerdict: string;
  narrative: string;
  riskNote: string;
  positiveDrivers: UIDriver[];
  negativeDrivers: UIDriver[];
  sources: UISource[];
  conclusion: string;
  recommendation?: string;
  disclaimer?: string;
  counterSignals?: string[];
  reviewRequestEnabled?: boolean;
  claimResults: {
    claimId: string;
    text: string;
    status: ClaimStatus;
    evidenceLevel: EvidenceLevel;
    publicNote: string;
    claimType?: string;
    reasonCategory?: string;
    confidence?: number;
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
  keyClaims: {
    claimId: string;
    text: string;
    status: ClaimStatus;
    evidenceLevel: EvidenceLevel;
    publicNote: string;
    claimType?: string;
    reasonCategory?: string;
    confidence?: number;
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

// ============================================
// SYNTHESIS
// ============================================

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

// ============================================
// FACT CHECK RESULT
// ============================================

export interface FactCheckResult {
  videoId: string;
  userId: string;
  scoringVersion: string;
  transcript: TranscriptData;
  analysisState: VerificationState | ErrorState;
  scoreAvailable: boolean;
  analysisFailureReason?: AnalysisFailureReason;
  viewerNote?: string;
  uiReport?: UIReport;

  trustScore: number | null;
  truthScore?: number | null;
  honestyScore?: number | null;
  rationalityScore?: number | null;
  structuralReliabilityScore?: number | null;
  compositeRating?: number | null;

  verificationState?: VerificationState;

  trustLabel: TrustLabel;
  confidence: number;
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
    genre?: string;
  };

  factors: InstitutionalTrustFactors | null;
  chapters: TrustChapter[];
  speakers: SpeakerBreakdown[];
  speakerIdentities?: Record<string, { id: string, name: string, confidence: number }>;
  claims: VerifiedClaim[];

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
    verificationCoverageRatio?: number;
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
  isLaunchNews?: boolean;
  launchGrounded?: boolean;
  extractionError?: string;
  speakerCount?: number;
  detectedLanguage?: string;

  generatedAt: number;
  verifiedAsOf: string;
  language: string;
  riskDomain: string;
  domainRiskMultiplier: number;

  reputationModifier?: number;
  recalculateAt?: number;

  deductions: TrustDeduction[];

  videoCategory?: string;
  categoryWeightProfile?: Record<string, number>;
  honestyBreakdown?: HonestyBreakdown;
  contextualFlags?: ContextualFlag[];
  harmCapApplied?: boolean;
  harmCapReason?: string;
  rawScoreBeforeCap?: number;
  penaltyApplied?: number;

  hardeningMetadata?: HardeningMetadata;
  intentToMisleadScore?: number;
  effectiveCategory?: string;

  reanalysisAvailable?: boolean;

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

  versions: {
    model: string;
    scoring: string;
    registry: string;
  };
}

// ============================================
// EXPLAINABILITY & CREDIBILITY
// ============================================

export interface ExplainabilityResult {
  claimId: string;
  claim: string;
  status: ClaimStatus;
  nature?: string;
  framing?: string;
  evidenceLevel?: EvidenceLevel;
  ontology?: string;
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
  tier?: SourceTier;
  provenance?: string;
}

export interface SpeakerBreakdown {
  speakerId: string;
  label: string;
  role?: string;
  trustIndex: number;
  wordCount: number;
  claimCount: number;
}

export interface TrustChapter {
  index: number;
  title: string;
  start: number;
  end: number;
  primaryTopics: string[];
}

export interface CredibilityResult {
  analysisState: VerificationState | ErrorState;
  scoreAvailable: boolean;
  analysisFailureReason?: AnalysisFailureReason;
  viewerNote?: string;
  uiReport?: UIReport;

  trustScore: number | null;
  trustLabel: TrustLabel;
  confidence: number;
  confidenceTier: 'high' | 'medium' | 'low';

  factors: InstitutionalTrustFactors | null;
  chapters: TrustChapter[];
  speakers: SpeakerBreakdown[];
  claims: ExplainabilityResult[];

  speakerIdentities?: Record<string, { id: string, name: string, confidence: number }>;

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
    religious_belief: number;
    opinion_claim: number;
    satire_claim: number;
    verification_timeout: number;
    cacheHitRate?: number;
    checkedClaimsRatio?: number;
    extractionPartial?: boolean;
    verificationCoverageRatio?: number;
  };
  contentIntent?: {
    primaryIntent: string;
    intentScores?: Record<string, number>;
    confidence: number;
    subjectiveRatio: number;
    promotionalSignals: string[];
    ratingFloor: number;
    ratingCeiling: number;
    genre?: string;
  };
  filteringReasons: string[];

  deductions?: TrustDeduction[];

  videoCategory?: string;
  categoryWeightProfile?: Record<string, number>;
  honestyBreakdown?: HonestyBreakdown;
  contextualFlags?: ContextualFlag[];
  harmCapApplied?: boolean;
  harmCapReason?: string;
  rawScoreBeforeCap?: number;
  penaltyApplied?: number;

  hardeningMetadata?: HardeningMetadata;
  intentToMisleadScore?: number;
  effectiveCategory?: string;

  scoringMethod: 'strict' | 'balanced';
  synthesisTier: 'standard' | 'deep' | 'podcast';
  isLongform: boolean;
  isFinal: boolean;

  summary?: string;
  conclusion?: {
    label: string;
    text: string;
    confidence: number;
  };

  keyThemes?: string[];
  domain?: string;
  isLaunchNews?: boolean;
  launchGrounded?: boolean;
  extractionError?: string;
  speakerCount?: number;
  detectedLanguage?: string;
  manipulationScore?: number;
  trustIndexFormatted?: string;
  isAppealed?: boolean;
  appealStatus?: 'none' | 'pending' | 'reviewed' | 'resolved';
  diagnostics?: string[];
  sourceLedger?: Record<string, string>;
  verifiedAsOf?: string;
  verifiedAt: number;
  processingTime: number;
  vertical?: TrustVertical;
  verticalScores?: Record<TrustVertical, number>;
  confidenceNotes?: string[];
  reviewTriggered?: boolean;
  reviewReason?: string;
  scoreDrivers?: string[];
  knowledgeDensity?: number;

  telemetry: {
    transcriptLoaded: boolean;
    utteranceCount: number;
    claimsExtracted: number;
    verificationCompleted: boolean;
    claimsVerified?: boolean;
    verificationPipelineCompleted?: boolean;
    summaryGenerated: boolean;
    consistencyCheckCompleted: boolean;
    checkedClaimsRatio?: number;
    verificationAttempted?: number;
    verificationSucceeded?: number;
    verificationTimedOut?: number;
    verificationCoverage?: number;
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

// ============================================
// AGGREGATION
// ============================================

export interface AggregatedOutput {
  jobId: string;
  userId: string;
  videoUrl: string;
  trustScore: number;
  trustLabel: TrustLabel;
  confidence: number;
  confidenceTier: 'high' | 'medium' | 'low';
  speakerConfidence?: number;
  rating: number;
  summary?: string;
  conclusion?: {
    label: string;
    text: string;
    confidence: number;
  };
  keyThemes?: string[];
  viewerNote?: string;
  domain?: string;
  isLaunchNews?: boolean;
  launchGrounded?: boolean;
  vertical?: TrustVertical;
  verticalScores?: Record<TrustVertical, number>;
  reviewTriggered?: boolean;
  reviewReason?: string;
  confidenceNotes?: string[];
  checkedClaimsRatio?: number;
  speakerMetrics?: SpeakerBreakdown[];
  contentIntent?: {
    primaryIntent: string;
    confidence: number;
    subjectiveRatio: number;
    promotionalSignals: string[];
    genre?: string;
  };
  verifiedAt?: number;
  factCheckUrl?: string;
  diagnostics?: string[];
  claims: ExplainabilityResult[];
  chapters?: Array<{
    startTimeMs: number;
    endTimeMs: number;
    title: string;
    summary: string;
  }>;
  fullResultPath?: string;
  subtitles: Record<string, any>;
  media: {
    subtitles: Record<string, string>;
    audioTracks: Record<string, string>;
    factCheckUrl?: string;
    transcripts?: string | Record<string, any>;
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

// ============================================
// GOVERNANCE
// ============================================

export interface CreatorReputation {
  userId: string;
  channelId: string;
  channelRating: number;
  trustScore: number;
  trustLevel: 'elite' | 'high' | 'developing' | 'risk' | 'critical';
  lifetimeClaims: number;
  accurateCount: number;
  nuanceCount: number;
  incorrectCount: number;
  accuracyRate: number;
  nuanceRate: number;
  correctionRate: number;
  drift: number;
  trend: 'improving' | 'stable' | 'deteriorating';
  domainScores: Record<string, number>;
  history: Array<{
    month: string;
    avgScore: number;
    videoCount: number;
  }>;
  lastScores: number[];
  metadataReliability?: {
    speakerAccuracy: number;
    languageAccuracy: number;
    formatAccuracy: number;
    overall: number;
  };
  updatedAt: number;
}

export interface TrustAppeal {
  appealId: string;
  jobId: string;
  userId: string;
  reason: string;
  evidenceLinks?: string[];
  status: 'pending' | 'under_review' | 'resolved' | 'rejected';
  reviewerId?: string;
  resolutionNote?: string;
  originalScore: number;
  newScore?: number;
  createdAt: number;
  resolvedAt?: number;
}

export interface GovernanceAuditLog {
  logId: string;
  targetId: string;
  action: 'manual_override' | 'appeal_resolved' | 'weight_calibration' | 'threshold_update';
  performerId: string;
  previousValue: any;
  newValue: any;
  rationale: string;
  timestamp: number;
}

export interface TrustLedgerEntry {
  jobId: string;
  timestamp: number;
  overallScore: number;
  accuracyRate: number;
  claimsCount: number;
  penalties: number;
  topMisleading: string[];
}
