/**
 * 🧠 Credibility Pipeline — Stage Types
 *
 * Shared context object passed between pipeline stages.
 * Each stage reads what it needs and writes its outputs here.
 */

import {
  ExecutionPlan,
  ExtractedClaim,
  VerifiedClaim,
  CredibilityResult,
  SynthesisResult,
  ClaimStrength,
} from '../../types';

/** Mutable context bag passed through all stages. */
export interface PipelineContext {
  // --- Inputs ---
  jobId: string;
  userId: string;
  executionPlan: ExecutionPlan;
  eventId: string;
  traceId?: string;

  // --- Stage 1: Transcript ---
  transcript: any;
  durationSeconds: number;
  durationMinutes: number;
  isLongform: boolean;

  // --- Stage 2: Extraction ---
  rawClaims: ExtractedClaim[];
  extractionPartial: boolean;
  extractionCoverage: number;
  domainInfo: {
    domain: string;
    stance: string;
    cautionLevel: string;
    isLaunchNews: boolean;
    primaryIntent: string;
    isSensitive: boolean;
    extractionError?: string;
  };
  speakerIdentities: Record<string, any>;
  contentIntent: any;

  // --- Stage 3: Classification & Caching ---
  topClaims: Array<ExtractedClaim & { claimStrength: ClaimStrength; importance: number }>;
  filteredCount: number;
  filteringReasons: string[];

  // --- Stage 4: Verification ---
  allVerified: VerifiedClaim[];
  cached: VerifiedClaim[];
  registryHits: VerifiedClaim[];
  newlyVerified: VerifiedClaim[];
  labeledOpinions: VerifiedClaim[];
  hitRate: number;
  batchStats: { completed: number; timedOut: number };

  // --- Stage 5: Synthesis ---
  synthesis: SynthesisResult;
  consistencyResult: any;
  speakerPriors: Record<string, any>;
  pipelineMode: 'solo' | 'multi' | 'debate';
  synthesisTier: 'standard' | 'deep' | 'podcast';

  // --- Stage 6: Scoring ---
  evaluationHealth: any;
  result: CredibilityResult;

  // --- Timing ---
  t0: number;
  t1: number;
  tVerificationEnd: number;
  tConsistencyStart: number;
  tConsistencyEnd: number;
  tFinal: number;
}
