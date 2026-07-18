/**
 * Verification types — evidence, sources, lineage, and verified claims.
 */

import {
  FilteredClaim,
  ClaimStatus,
  ClaimType,
  ReasonCategory,
  ClaimSeverity,
  ClaimAssertiveness,
  ClaimStrength,
} from './claims.js';

export enum EvidenceLevel {
  VERY_STRONG = 'VERY_STRONG',
  STRONG = 'STRONG',
  MODERATE = 'MODERATE',
  LIMITED = 'LIMITED',
  CONTRADICTED = 'CONTRADICTED',
  NONE = 'NONE',
}

export type SourceTier = 'A' | 'B' | 'C' | 'D' | 'E';
export type VerificationMethod = 'grounded' | 'deterministic' | 'cache_hit' | 'llm_training' | 'not_verified';

export interface RichSource {
  title: string;
  url: string;
  domain?: string;
  publisher?: string;
  type?: string;
  publishedAt?: string;
  tier: SourceTier;
  snippet?: string;
  lastPublished?: string;
  lastVerified?: string;
  retrievalMethod?: string;
}

export interface EvidenceSummary {
  independentPublishers: number;
  tierA: number;
  tierB: number;
  secondarySources: number;
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

export interface VerifiedClaim extends FilteredClaim {
  status: ClaimStatus;
  displayLabel?: string;
  isLowRiskTrivia?: boolean;
  evidenceLevel?: EvidenceLevel;
  speaker?: string;
  verificationConfidence: number;
  reasoning: string;
  sources?: string[];
  richSources?: RichSource[];
  isGrounded?: boolean;
  freshnessScore?: number;
  importance: number;
  severity?: ClaimSeverity;
  evidenceConfidence?: number;
  ontology?: ClaimType;
  trueAsOf?: string;

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
  timedOutAt?: number;
  failureReason?: string;
  verificationMethod?: VerificationMethod;
  lineage?: EvidenceLineage;
  /** v17.0: Contextual note for BELIEF/OPINION claims shown in UI */
  contextNote?: string;
  reasonCategory?: ReasonCategory;
  sourceStatus?: 'complete' | 'partial' | 'missing';
  evidenceSchemaVersion?: string;
  evidenceSummary?: EvidenceSummary;
  processingMetadata?: {
    recoveryMethod?: string;
    requiresCitationRetry?: boolean;
    cacheSource?: string;
    [key: string]: any;
  };
}

// Zod schemas for Gemini response validation
import { z } from 'zod';

export const GeminiExtractionSchema = z.object({
  claims: z.array(z.object({
    text: z.string(),
    nature: z.string(),
    framing: z.string(),
    confidence: z.number(),
    importance: z.number().optional().default(0.5),
    isVerifiableEvent: z.boolean().optional().default(true),
    honestyWashingRisk: z.boolean().optional().default(false),
    assertiveness: z.string().optional().default('moderate'),
    claimStrength: z.string().optional().default('moderate'),
    category: z.string().optional().default('default'),
    rhetoricalManipulations: z.array(z.string()).optional().default([])
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
    primaryTopics: z.array(z.string())
  })).optional()
});

/**
 * v17.0: Per-claim source schema.
 * Gemini returns sources directly in structured JSON for precise claim-level attribution.
 * This eliminates the fragile groundingSupports substring-matching approach.
 */
const GeminiSourceSchema = z.object({
  title: z.string().optional().default('Reference Source'),
  url: z.string().optional().default(''),
  snippet: z.string().optional().default(''),
  publishedAt: z.string().optional(),
});

export const GeminiVerificationSchema = z.object({
  verifications: z.array(z.object({
    claimId: z.string(),
    claim: z.string(),
    claimType: z.string(), // Relaxed: Gemini may return values outside the predefined enum
    label: z.string(), // Relaxed: Gemini may use varied status labels
    evidenceLevel: z.string(), // Relaxed: Gemini may use varied evidence levels
    reasonCategory: z.string().optional().default('insufficient_evidence'), // Relaxed + optional
    rating: z.number(),
    confidence: z.number(),
    freshness: z.string(),
    summary: z.string(),
    verifiedFacts: z.array(z.string()),
    missingEvidence: z.array(z.string()),
    sourceConsensus: z.string(),
    riskLevel: z.string(),
    publicNote: z.string(),
    recommendedAction: z.string(),
    /** v17.0: Per-claim sources returned directly by Gemini */
    sources: z.array(GeminiSourceSchema).optional().default([]),
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
  constraintBasedVerification: boolean;
}
