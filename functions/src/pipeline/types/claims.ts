/**
 * Claim types — extraction, classification, and verification.
 */

export enum ClaimNature {
  VERIFIABLE_FACT = 'VERIFIABLE_FACT',
  HISTORICAL_FACT = 'HISTORICAL_FACT',
  RELIGIOUS_CLAIM = 'RELIGIOUS_CLAIM',
  SUPERNATURAL_CLAIM = 'SUPERNATURAL_CLAIM',
  SCIENTIFIC_CLAIM = 'SCIENTIFIC_CLAIM',
  OPINION = 'OPINION',
  BELIEF = 'BELIEF',
  ESTIMATION = 'ESTIMATION',
  PREDICTION = 'PREDICTION',
  SATIRE = 'SATIRE'
}

export enum FramingStyle {
  HEDGED = 'HEDGED',
  BALANCED = 'BALANCED',
  ASSERTIVE = 'ASSERTIVE',
  ABSOLUTE = 'ABSOLUTE',
  MANIPULATIVE = 'MANIPULATIVE'
}

export type ClaimType = string;

export type ReasonCategory =
  | 'scientific_consensus'
  | 'historical_record'
  | 'government_record'
  | 'peer_review'
  | 'primary_source'
  | 'logical_impossibility'
  | 'future_prediction'
  | 'religious_claim'
  | 'insufficient_evidence'
  | 'mixed_evidence';

export type ClaimSeverity = 'low' | 'medium' | 'high' | 'extreme';
export type ClaimAssertiveness = 'casual' | 'moderate' | 'confident' | 'authoritative' | 'absolute';
export type ClaimStrength = 'hedged' | 'moderate' | 'strong' | 'absolute';

export type ClaimStatus =
  | "verified_true"
  | "verified_false"
  | "partially_true"
  | "inconclusive"
  | "opinion_or_prediction"
  | "mostly_true"
  | "disputed"
  | "unproven"
  | "misleading"
  | "false_claim"
  | "religious_belief"
  | "opinion_claim"
  | "satire_claim"
  | "verification_timeout"
  | "unverified"
  | "limited_support"
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
  | "not_historically_verifiable";

export interface ExtractedClaim {
  text: string;
  nature: ClaimNature;
  framing: FramingStyle;
  speaker?: string;
  confidence: number;
  importance: number;
  isVerifiableEvent?: boolean;
  assertiveness?: ClaimAssertiveness;
  claimStrength?: ClaimStrength;
  honestyWashingRisk?: boolean;
  isFramingViolation?: boolean;
  start?: number;
  end?: number;
  chunkIndex: number;
  category?: string;
  rhetoricalManipulations?: string[];
}

export interface FilteredClaim extends ExtractedClaim {
  claimId: string;
}

export interface EnhancedClaim extends ExtractedClaim {
  claimStrength: ClaimStrength;
  importance: number;
  speaker?: string;
  context?: string;
}
