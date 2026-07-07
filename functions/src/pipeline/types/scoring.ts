/**
 * Scoring types — trust factors, deductions, labels, and category-aware scoring.
 */

import { ClaimSeverity } from './claims.js';

export enum VerificationState {
  VERIFIED             = 'VERIFIED',
  PARTIALLY_VERIFIED   = 'PARTIALLY_VERIFIED',
  STRUCTURAL_ONLY      = 'STRUCTURAL_ONLY',
  INSUFFICIENT_EVIDENCE = 'INSUFFICIENT_EVIDENCE',
  ANALYSIS_INCOMPLETE  = 'ANALYSIS_INCOMPLETE',
  FORCE_INCOMPLETE     = 'FORCE_INCOMPLETE',
  FORCE_TIMEOUT        = 'FORCE_TIMEOUT',
  FORCE_OPERATIONAL_FAILURE = 'FORCE_OPERATIONAL_FAILURE'
}

export enum ErrorState {
  FAILED = 'FAILED'
}

export type AnalysisFailureReason =
  | "AI_CAPACITY"
  | "TIMEOUT"
  | "NO_CLAIMS"
  | "LOW_INFORMATION"
  | "UNSUPPORTED_LANGUAGE"
  | "UNKNOWN_ERROR";

export interface InstitutionalTrustFactors {
  accuracy: number | null;
  evidence: number | null;
  consensus: number;
  consistency: number;
  integrity: number;
  expertise: number;
  freshness: number;
  safety: number;
  honesty: number;
  rationality?: number;
  reputation?: number;
  intentToMislead?: number;
}

export type TrustVertical = 'general' | 'finance' | 'health' | 'religion' | 'history' | 'politics';

export interface TrustDeduction {
  factor: keyof InstitutionalTrustFactors | 'intent' | 'reputation' | 'harm_cap';
  points: number;
  reason: string;
}

export type TrustLabel =
  | "Highly Reliable"
  | "Generally Credible"
  | "Generally Credible with Some Exaggeration"
  | "Mixed Credibility"
  | "Low Reliability"
  | "Significant Credibility Concerns"
  | "Reliable"
  | "Mixed"
  | "Low"
  | "Misleading"
  | "Opinion/Belief Content"
  | "Manipulative Opinion"
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
  | "In-Depth Legal/Political Inquiry"
  | "Commentary – Mixed Detail"
  | "Poorly Supported Commentary"
  | "Unverified – Insufficient Data"
  | "No Factual Claims"
  | "Analysis in Progress"
  | "Faithfully Presented"
  | "Safety Capped – Verify Claims";

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

export interface HonestyBreakdown {
  score: number;
  opinionLabeledOpinion: number;
  beliefLabeledBelief: number;
  beliefPresentedAsFact: number;
  opinionPresentedAsFact: number;
  speculationLabeledSpeculation: number;
  assertivenessMismatchPenalty: number;
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
  falsehood_penalty: number;
  misleading_penalty: number;
  harm_cap: number | null;
  harm_cap_severity: ClaimSeverity[];
}

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
  intentToMisleadScore: number;
  penalties: { type: string; value: number }[];
  auditTimestamp: string;
}

export interface RepairSuggestion {
  claimId: string;
  type: 'factual_error' | 'missing_source' | 'verification_timeout' | 'hedging_needed' | 'outdated_info';
  severity: 'low' | 'medium' | 'high' | 'info';
  currentText: string;
  suggestion: string;
  impactEstimate: string;
}

export interface ConsistencyIssue {
  claim1: string;
  claim2: string;
  type: 'contradiction' | 'mixed_accuracy' | 'temporal_inconsistency';
  severity: 'low' | 'medium' | 'high';
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
