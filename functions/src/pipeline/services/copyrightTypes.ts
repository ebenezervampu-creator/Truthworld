/**
 * 🛡️ COPYRIGHT PROTECTION SYSTEM — Type Definitions
 *
 * Firestore Collections:
 *   copyright_assets/{assetId}    — Registered content (one per video)
 *   copyright_chunks/{chunkId}    — 30s transcript chunks with embeddings
 *   copyright_matches/{matchId}   — Detected matches (separate collection)
 *   copyright_claims/{claimId}    — Active claims
 *   copyright_appeals/{appealId}  — Dispute/appeal records
 *
 * Architecture:
 *   MD5 (0ms) → Embedding Search (50ms) → Transcript Similarity (100ms)
 *   → Gemini Verification (ONLY if confidence > 0.80)
 *   → Fair Use Score (0-100) → Evidence Bundle → Claim/Track/No Action
 */

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTION 1: copyright_assets — Registered Content
// ═══════════════════════════════════════════════════════════════════════════════

export type ProtectionLevel = 'strict' | 'standard' | 'lenient';
export type ClaimPolicy = 'block' | 'monetize_shared' | 'track_only';

export interface CopyrightAsset {
  assetId: string;               // Same as videoId for simplicity

  // ── Identity Fingerprints ──────────────────────────────────────────────────
  md5Hash: string | null;        // Exact file hash from GCS
  summaryEmbedding: number[];    // 256-dim embedding of video summary (Vertex AI text-embedding-005)
  transcriptHash: string | null; // MD5 of full normalized transcript (fast pre-filter)

  // ── Ownership ──────────────────────────────────────────────────────────────
  originalVideoId: string;
  ownerId: string;
  channelId: string;
  videoTitle: string;
  videoDuration: number;         // Seconds

  // ── Detection Config (set by owner) ────────────────────────────────────────
  protectionLevel: ProtectionLevel;
  allowFairUse: boolean;         // Default true — allow commentary/review
  claimPolicy: ClaimPolicy;

  // ── Metadata ───────────────────────────────────────────────────────────────
  chunkCount: number;            // Number of 30s transcript chunks
  registeredAt: number;
  updatedAt: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTION 2: copyright_chunks — 30-Second Transcript Chunks
// ═══════════════════════════════════════════════════════════════════════════════

export interface CopyrightChunk {
  chunkId: string;               // {assetId}_chunk_{index}
  assetId: string;               // Parent copyright_assets ref
  ownerId: string;               // Denormalized for query efficiency

  // ── Chunk Data ─────────────────────────────────────────────────────────────
  chunkIndex: number;            // 0-based position in video
  startTime: number;             // Seconds
  endTime: number;               // Seconds
  transcriptText: string;        // Raw transcript for this chunk

  // ── Embedding (Firestore vector field) ─────────────────────────────────────
  chunkEmbedding: number[];      // 256-dim embedding (text-embedding-005)

  registeredAt: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTION 3: copyright_matches — Detected Matches (Scalable)
// ═══════════════════════════════════════════════════════════════════════════════

export type MatchType = 'exact_md5' | 'embedding_similarity' | 'transcript_similarity' | 'semantic_verified';

export interface SegmentMatch {
  originalStart: number;         // Seconds in original video
  originalEnd: number;
  infringingStart: number;       // Seconds in new video
  infringingEnd: number;
  chunkSimilarity: number;       // 0-1 cosine similarity of this chunk pair
}

export interface CopyrightMatch {
  matchId: string;
  assetId: string;               // Original copyright_assets ref
  matchedVideoId: string;        // New video that matched
  matchedOwnerId: string;        // Uploader of the matched video
  matchedChannelId: string;

  // ── Detection Results ──────────────────────────────────────────────────────
  matchType: MatchType;
  matchedSegments: SegmentMatch[];
  
  // ── Weighted Confidence (your #7) ──────────────────────────────────────────
  confidenceBreakdown: WeightedConfidence;
  finalConfidence: number;       // 0-1 weighted composite

  // ── Status ─────────────────────────────────────────────────────────────────
  status: 'detected' | 'claimed' | 'dismissed' | 'expired';
  claimId: string | null;        // Set when a claim is created from this match
  detectedAt: number;
}

export interface WeightedConfidence {
  md5Score: number | null;       // 0 or 1 (binary)
  embeddingScore: number | null; // 0-1 cosine similarity
  transcriptScore: number | null;// 0-1 text overlap
  semanticScore: number | null;  // 0-1 from Gemini verification

  // Weights (configurable, sum = 1.0)
  weights: {
    md5: number;                 // 0.40 default
    embedding: number;           // 0.30 default
    transcript: number;          // 0.20 default
    semantic: number;            // 0.10 default
  };
}

/** Default confidence weights */
export const DEFAULT_CONFIDENCE_WEIGHTS = {
  md5: 0.40,
  embedding: 0.30,
  transcript: 0.20,
  semantic: 0.10,
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTION 4: copyright_claims — Active Claims
// ═══════════════════════════════════════════════════════════════════════════════

export type ClaimNoticeType = 'Content Match' | 'Takedown Request' | 'Revenue Share';
export type ClaimStatus = 'active' | 'disputed' | 'resolved' | 'retracted' | 'expired';
export type ClaimImpact = 'No Impact' | 'Revenue Shared' | 'Video Blocked' | 'Action Required';

export interface FairUseAnalysis {
  score: number;                 // 0-100 (NOT binary)
  factors: {
    commentary: number;          // 0-100
    transformation: number;      // 0-100
    lengthUsed: number;          // 0-100 (100 = used very little)
    purpose: number;             // 0-100 (100 = educational/criticism)
    commercialIntent: number;    // 0-100 (100 = non-commercial)
  };
  category: 'commentary' | 'review' | 'education' | 'parody' | 'news' | 'criticism' | 'none';
  reasoning: string;            // Gemini explanation
  confidence: number;           // 0-1
}

export interface EvidenceBundle {
  matchingTranscriptPairs: {
    originalText: string;
    originalTimeRange: string;   // "03:10-05:43"
    matchedText: string;
    matchedTimeRange: string;
    similarity: number;
  }[];
  similarityTimeline: {          // Similarity scores across time — visualizable
    timeSeconds: number;
    similarity: number;
  }[];
  confidenceBreakdown: WeightedConfidence;
  fairUseAnalysis: FairUseAnalysis | null;
  geminiExplanation: string | null;
  generatedAt: number;
}

export interface CopyrightClaim {
  claimId: string;

  // ── Infringer ──────────────────────────────────────────────────────────────
  videoId: string;
  videoTitle: string;
  channelId: string;
  uploaderId: string;

  // ── Rights Holder ──────────────────────────────────────────────────────────
  originalVideoId: string;
  ownerId: string;
  ownerChannelId: string;
  claimant: string;              // Channel name of rights holder

  // ── Detection ──────────────────────────────────────────────────────────────
  matchId: string;               // Reference to copyright_matches
  matchType: MatchType;
  finalConfidence: number;       // Weighted composite
  matchedSegments: SegmentMatch[];
  evidenceBundle: EvidenceBundle;
  fairUseAnalysis: FairUseAnalysis;

  // ── Policy & Status ────────────────────────────────────────────────────────
  noticeType: ClaimNoticeType;
  policy: string;
  status: ClaimStatus;
  impact: ClaimImpact;
  description: string;

  // ── Timestamps ─────────────────────────────────────────────────────────────
  date: number;                  // Firestore Timestamp (creation)
  expiresAt: number | null;
  resolvedAt: number | null;
  updatedAt: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTION 5: copyright_appeals — Dispute Records
// ═══════════════════════════════════════════════════════════════════════════════

export type AppealStage = 
  | 'creator_submitted'          // Creator filed appeal
  | 'ai_review'                  // Gemini re-analyzing
  | 'owner_review'               // Rights holder reviewing
  | 'human_override'             // Manual review (escalation)
  | 'resolved';

export type AppealOutcome = 'upheld' | 'overturned' | 'modified' | 'pending';

export interface CopyrightAppeal {
  appealId: string;
  claimId: string;               // Reference to copyright_claims
  matchId: string;               // Reference to copyright_matches

  // ── Parties ────────────────────────────────────────────────────────────────
  appellantId: string;           // Creator who appealed
  claimantId: string;            // Rights holder

  // ── Appeal Details ─────────────────────────────────────────────────────────
  reason: string;                // Creator's explanation
  evidence: string | null;       // Additional evidence from creator
  category: 'fair_use' | 'original_content' | 'licensed' | 'public_domain' | 'false_match' | 'other';

  // ── Stage & Outcome ────────────────────────────────────────────────────────
  stage: AppealStage;
  outcome: AppealOutcome;

  // ── AI Review ──────────────────────────────────────────────────────────────
  aiReviewResult: {
    fairUseScore: number;        // Re-evaluated 0-100
    recommendation: 'uphold' | 'overturn' | 'escalate';
    reasoning: string;
  } | null;

  // ── Owner Response ─────────────────────────────────────────────────────────
  ownerResponse: string | null;
  ownerDecision: 'uphold' | 'retract' | null;

  // ── Timestamps ─────────────────────────────────────────────────────────────
  submittedAt: number;
  aiReviewedAt: number | null;
  ownerRespondedAt: number | null;
  resolvedAt: number | null;
  updatedAt: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETECTION PIPELINE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/** Thresholds for the layered detection pipeline */
export const DETECTION_THRESHOLDS = {
  /** Summary embedding cosine similarity to become a candidate */
  EMBEDDING_CANDIDATE: 0.75,
  /** Chunk embedding similarity to count as a segment match */
  CHUNK_MATCH: 0.85,
  /** Minimum weighted confidence to trigger Gemini verification */
  GEMINI_GATE: 0.80,
  /** Minimum final confidence to auto-generate a claim */
  AUTO_CLAIM: 0.90,
  /** Confidence above which to create a temporary hold */
  TEMPORARY_HOLD: 0.95,
  /** Fair use score below which Gemini flags are auto-dismissed */
  FAIR_USE_DISMISS: 70,
  /** Chunk duration in seconds */
  CHUNK_DURATION_SECONDS: 30,
  /** Embedding dimensions (text-embedding-005) */
  EMBEDDING_DIMENSIONS: 256,
  /** Max candidates to retrieve from embedding search */
  MAX_CANDIDATES: 20,
} as const;

/** Result from the full layered detection pipeline */
export interface DetectionResult {
  hasMatch: boolean;
  matches: CopyrightMatch[];
  totalCandidatesScanned: number;
  pipelineStages: {
    md5: { ran: boolean; hitCount: number; durationMs: number };
    embedding: { ran: boolean; candidateCount: number; durationMs: number };
    transcript: { ran: boolean; matchCount: number; durationMs: number };
    gemini: { ran: boolean; verifiedCount: number; durationMs: number };
  };
  totalDurationMs: number;
}
