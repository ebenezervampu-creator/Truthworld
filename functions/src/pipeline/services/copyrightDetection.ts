/**
 * 🔍 COPYRIGHT DETECTION SERVICE — Layered Detection Pipeline
 *
 * Architecture (cost-optimized):
 *   1. MD5 check       — 0ms, free, exact duplicates
 *   2. Embedding search — 50ms, ~$0 (Firestore vector query)
 *   3. Transcript sim   — 100ms, ~$0 (chunk comparison)
 *   4. Gemini verify    — ONLY if weighted confidence > 0.80 ($0.001 per call)
 *
 * Gemini runs on <5% of uploads. Total cost per video: ~$0.001-$0.002
 *
 * Key Design Decisions:
 *   - Matches stored in separate `copyright_matches` collection (not arrays)
 *   - 30-second chunk matching detects partial copies
 *   - Weighted confidence: 40% MD5, 30% embedding, 20% transcript, 10% semantic
 *   - Never auto-blocks — only claims, holds, or tracking
 *   - Fair use scored 0-100, not binary
 */

import * as admin from "firebase-admin";
import { VertexAI } from "@google-cloud/vertexai";
import { logger } from "../utils/logger";
import { cosineSimilarity } from "./fingerprintService";
import {
  CopyrightMatch,
  WeightedConfidence,
  SegmentMatch,
  DetectionResult,
  DETECTION_THRESHOLDS,
  DEFAULT_CONFIDENCE_WEIGHTS,
  FairUseAnalysis,
  EvidenceBundle,
} from "./copyrightTypes";
import { v4 as uuidv4 } from "uuid";

const db = () => admin.firestore();

// ─── Detection Pipeline ──────────────────────────────────────────────────────

export class CopyrightDetectionService {
  /**
   * Run the full layered detection pipeline on a new video.
   *
   * Call this AFTER transcription completes — we need the transcript
   * and summary to generate embeddings for comparison.
   */
  async detectCopyright(params: {
    videoId: string;
    ownerId: string;
    channelId: string;
    md5Hash: string | null;
    transcript: string;
    summary: string;
    duration: number;
    utterances?: { start: number; end: number; text: string }[];
    summaryEmbedding: number[];
    transcriptHash: string;
    chunks: { index: number; startTime: number; endTime: number; text: string; embedding: number[] }[];
  }): Promise<DetectionResult> {
    const t0 = Date.now();
    const result: DetectionResult = {
      hasMatch: false,
      matches: [],
      totalCandidatesScanned: 0,
      pipelineStages: {
        md5: { ran: false, hitCount: 0, durationMs: 0 },
        embedding: { ran: false, candidateCount: 0, durationMs: 0 },
        transcript: { ran: false, matchCount: 0, durationMs: 0 },
        gemini: { ran: false, verifiedCount: 0, durationMs: 0 },
      },
      totalDurationMs: 0,
    };

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // STAGE 1: MD5 Exact Match (0ms, free)
      // ═══════════════════════════════════════════════════════════════════════
      const md5Start = Date.now();
      const md5Hits = await this.checkMd5(params.md5Hash, params.videoId);
      result.pipelineStages.md5 = {
        ran: true,
        hitCount: md5Hits.length,
        durationMs: Date.now() - md5Start,
      };

      if (md5Hits.length > 0) {
        // Exact duplicate — 100% confidence, no need for further stages
        for (const hit of md5Hits) {
          const match = this.createMatch(params, hit, "exact_md5", {
            md5Score: 1.0,
            embeddingScore: null,
            transcriptScore: null,
            semanticScore: null,
            weights: DEFAULT_CONFIDENCE_WEIGHTS,
          }, 1.0, []);
          result.matches.push(match);
        }
        result.hasMatch = true;
        result.totalDurationMs = Date.now() - t0;

        // Persist matches
        await this.persistMatches(result.matches);
        return result;
      }

      // ═══════════════════════════════════════════════════════════════════════
      // STAGE 2: Embedding Similarity Search (50ms, ~$0)
      // ═══════════════════════════════════════════════════════════════════════
      const embStart = Date.now();
      const candidates = await this.searchByEmbedding(
        params.summaryEmbedding,
        params.videoId
      );
      result.pipelineStages.embedding = {
        ran: true,
        candidateCount: candidates.length,
        durationMs: Date.now() - embStart,
      };
      result.totalCandidatesScanned = candidates.length;

      if (candidates.length === 0) {
        // No similar content found — exit early
        result.totalDurationMs = Date.now() - t0;
        return result;
      }

      logger.info("[CopyrightDetection] Embedding candidates found", {
        videoId: params.videoId,
        candidateCount: candidates.length,
        topScore: candidates[0]?.similarity.toFixed(3),
      });

      // ═══════════════════════════════════════════════════════════════════════
      // STAGE 3: Chunk-Level Transcript Comparison (100ms)
      // ═══════════════════════════════════════════════════════════════════════
      const txStart = Date.now();
      const chunkMatches = await this.compareChunks(params, candidates);
      result.pipelineStages.transcript = {
        ran: true,
        matchCount: chunkMatches.length,
        durationMs: Date.now() - txStart,
      };

      if (chunkMatches.length === 0) {
        result.totalDurationMs = Date.now() - t0;
        return result;
      }

      // ═══════════════════════════════════════════════════════════════════════
      // Calculate weighted confidence for each candidate
      // ═══════════════════════════════════════════════════════════════════════
      for (const chunkMatch of chunkMatches) {
        const confidence: WeightedConfidence = {
          md5Score: 0,
          embeddingScore: chunkMatch.embeddingSimilarity,
          transcriptScore: chunkMatch.avgChunkSimilarity,
          semanticScore: null, // Will be set by Gemini if it runs
          weights: DEFAULT_CONFIDENCE_WEIGHTS,
        };

        const weightedScore = this.calculateWeightedScore(confidence);

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 4: Gemini Verification (ONLY if weighted confidence > 0.80)
        // ═════════════════════════════════════════════════════════════════════
        if (weightedScore >= DETECTION_THRESHOLDS.GEMINI_GATE) {
          const geminiStart = Date.now();
          const semanticScore = await this.geminiVerify(
            params.transcript,
            chunkMatch.originalTranscript,
            params.summary,
            chunkMatch.originalTitle
          );
          confidence.semanticScore = semanticScore;
          result.pipelineStages.gemini.ran = true;
          result.pipelineStages.gemini.verifiedCount++;
          result.pipelineStages.gemini.durationMs += Date.now() - geminiStart;
        }

        const finalConfidence = this.calculateWeightedScore(confidence);

        if (finalConfidence >= DETECTION_THRESHOLDS.EMBEDDING_CANDIDATE) {
          const match = this.createMatch(
            params,
            chunkMatch,
            confidence.semanticScore !== null ? "semantic_verified" : "transcript_similarity",
            confidence,
            finalConfidence,
            chunkMatch.segments
          );
          result.matches.push(match);
          result.hasMatch = true;
        }
      }

      // Persist all matches
      if (result.matches.length > 0) {
        await this.persistMatches(result.matches);
      }

      result.totalDurationMs = Date.now() - t0;

      logger.info("[CopyrightDetection] Pipeline complete", {
        videoId: params.videoId,
        hasMatch: result.hasMatch,
        matchCount: result.matches.length,
        stages: result.pipelineStages,
        totalMs: result.totalDurationMs,
      });

      return result;
    } catch (error) {
      logger.error("[CopyrightDetection] Pipeline error", {
        videoId: params.videoId,
        error: error instanceof Error ? error.message : String(error),
      });
      result.totalDurationMs = Date.now() - t0;
      return result;
    }
  }

  // ─── Stage 1: MD5 Check ──────────────────────────────────────────────────

  private async checkMd5(
    md5Hash: string | null,
    excludeVideoId: string
  ): Promise<CandidateAsset[]> {
    if (!md5Hash) return [];

    try {
      const snap = await db()
        .collection("copyright_assets")
        .where("md5Hash", "==", md5Hash)
        .limit(5)
        .get();

      return snap.docs
        .filter((doc) => doc.id !== excludeVideoId)
        .map((doc) => ({
          assetId: doc.id,
          ...doc.data(),
          similarity: 1.0,
        } as CandidateAsset));
    } catch (err) {
      logger.warn("[CopyrightDetection] MD5 check failed", { err });
      return [];
    }
  }

  // ─── Stage 2: Embedding Vector Search ────────────────────────────────────

  private async searchByEmbedding(
    queryEmbedding: number[],
    excludeVideoId: string
  ): Promise<CandidateAsset[]> {
    try {
      // Use Firestore's native vector search (findNearest)
      const collectionRef = db().collection("copyright_assets");
      const vectorQuery = collectionRef.findNearest({
        vectorField: "summaryEmbedding",
        queryVector: admin.firestore.FieldValue.vector(queryEmbedding),
        limit: DETECTION_THRESHOLDS.MAX_CANDIDATES,
        distanceMeasure: "COSINE",
      });

      const snap = await vectorQuery.get();

      const candidates: CandidateAsset[] = [];
      for (const doc of snap.docs) {
        if (doc.id === excludeVideoId) continue;

        const data = doc.data();
        // Firestore COSINE distance = 1 - cosine_similarity
        // So similarity = 1 - distance
        // But findNearest doesn't return distance directly,
        // we compute similarity from the stored embedding
        const storedEmbedding = data.summaryEmbedding?.toArray?.() || data.summaryEmbedding || [];
        const similarity = cosineSimilarity(queryEmbedding, storedEmbedding);

        if (similarity >= DETECTION_THRESHOLDS.EMBEDDING_CANDIDATE) {
          candidates.push({
            assetId: doc.id,
            ...data,
            similarity,
          } as CandidateAsset);
        }
      }

      // Sort by similarity descending
      candidates.sort((a, b) => b.similarity - a.similarity);
      return candidates;
    } catch (err) {
      // Fallback: brute-force if vector index not yet created
      logger.warn("[CopyrightDetection] Vector search failed — using brute-force fallback", {
        error: err instanceof Error ? err.message : String(err),
      });
      return this.bruteForceEmbeddingSearch(queryEmbedding, excludeVideoId);
    }
  }

  /**
   * Brute-force fallback for when Firestore vector index isn't created yet.
   * Loads all assets and computes cosine similarity locally.
   * Fine for < 10K assets. Replace with vector index for scale.
   */
  private async bruteForceEmbeddingSearch(
    queryEmbedding: number[],
    excludeVideoId: string
  ): Promise<CandidateAsset[]> {
    try {
      // Only load assets registered in the last 365 days to cap query size
      const oneYearAgo = Date.now() - 365 * 86400 * 1000;
      const snap = await db()
        .collection("copyright_assets")
        .where("registeredAt", ">", oneYearAgo)
        .limit(5000)
        .get();

      const candidates: CandidateAsset[] = [];
      for (const doc of snap.docs) {
        if (doc.id === excludeVideoId) continue;

        const data = doc.data();
        const storedEmbedding = data.summaryEmbedding?.toArray?.() || data.summaryEmbedding || [];
        if (!storedEmbedding || storedEmbedding.length === 0) continue;

        const similarity = cosineSimilarity(queryEmbedding, storedEmbedding);
        if (similarity >= DETECTION_THRESHOLDS.EMBEDDING_CANDIDATE) {
          candidates.push({
            assetId: doc.id,
            ...data,
            similarity,
          } as CandidateAsset);
        }
      }

      candidates.sort((a, b) => b.similarity - a.similarity);
      return candidates.slice(0, DETECTION_THRESHOLDS.MAX_CANDIDATES);
    } catch (err) {
      logger.error("[CopyrightDetection] Brute-force search failed", { err });
      return [];
    }
  }

  // ─── Stage 3: Chunk-Level Transcript Comparison ──────────────────────────

  private async compareChunks(
    newVideo: {
      videoId: string;
      chunks: { index: number; startTime: number; endTime: number; text: string; embedding: number[] }[];
    },
    candidates: CandidateAsset[]
  ): Promise<ChunkMatchResult[]> {
    const results: ChunkMatchResult[] = [];

    for (const candidate of candidates) {
      try {
        // Load chunks for this candidate asset
        const chunkSnap = await db()
          .collection("copyright_chunks")
          .where("assetId", "==", candidate.assetId)
          .orderBy("chunkIndex")
          .get();

        if (chunkSnap.empty) continue;

        const originalChunks = chunkSnap.docs.map((doc) => {
          const data = doc.data();
          return {
            index: data.chunkIndex as number,
            startTime: data.startTime as number,
            endTime: data.endTime as number,
            text: data.transcriptText as string,
            embedding: data.chunkEmbedding?.toArray?.() || data.chunkEmbedding || [],
          };
        });

        // Compare each new chunk against all original chunks
        const segments: SegmentMatch[] = [];
        let totalSimilarity = 0;
        let comparisonCount = 0;

        for (const newChunk of newVideo.chunks) {
          let bestSimilarity = 0;
          let bestOriginalChunk = originalChunks[0];

          for (const origChunk of originalChunks) {
            if (origChunk.embedding.length === 0) continue;
            const sim = cosineSimilarity(newChunk.embedding, origChunk.embedding);
            if (sim > bestSimilarity) {
              bestSimilarity = sim;
              bestOriginalChunk = origChunk;
            }
          }

          totalSimilarity += bestSimilarity;
          comparisonCount++;

          if (bestSimilarity >= DETECTION_THRESHOLDS.CHUNK_MATCH) {
            segments.push({
              originalStart: bestOriginalChunk.startTime,
              originalEnd: bestOriginalChunk.endTime,
              infringingStart: newChunk.startTime,
              infringingEnd: newChunk.endTime,
              chunkSimilarity: bestSimilarity,
            });
          }
        }

        const avgSimilarity = comparisonCount > 0 ? totalSimilarity / comparisonCount : 0;

        // Need at least 1 matching segment to be a candidate
        if (segments.length > 0) {
          // Reconstruct original transcript from chunks
          const originalTranscript = originalChunks.map((c) => c.text).join(" ");

          results.push({
            assetId: candidate.assetId,
            ownerId: (candidate as any).ownerId || "",
            channelId: (candidate as any).channelId || "",
            originalVideoId: (candidate as any).originalVideoId || candidate.assetId,
            originalTitle: (candidate as any).videoTitle || "Unknown",
            originalTranscript,
            embeddingSimilarity: candidate.similarity,
            avgChunkSimilarity: avgSimilarity,
            segments,
            matchingChunkRatio: segments.length / Math.max(1, newVideo.chunks.length),
          });
        }
      } catch (err) {
        logger.warn("[CopyrightDetection] Chunk comparison failed for candidate", {
          assetId: candidate.assetId,
          err: err instanceof Error ? err.message : String(err),
        });
      }
    }

    // Sort by average chunk similarity
    results.sort((a, b) => b.avgChunkSimilarity - a.avgChunkSimilarity);
    return results;
  }

  // ─── Stage 4: Gemini Semantic Verification ───────────────────────────────

  /**
   * Gemini runs ONLY when previous stages indicate confidence > 0.80.
   * Returns a 0-1 semantic similarity score.
   */
  private async geminiVerify(
    newTranscript: string,
    originalTranscript: string,
    newSummary: string,
    originalTitle: string
  ): Promise<number> {
    try {
      const vertexAI = new VertexAI({
        project: "truthworld-1",
        location: "asia-south1",
      });

      const model = vertexAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.1,
        },
      });

      const prompt = `You are a copyright verification specialist. Compare these two pieces of content and determine if the SECOND is a copy (or partial copy) of the FIRST.

ORIGINAL CONTENT (Title: "${originalTitle}"):
${originalTranscript.slice(0, 3000)}

NEW CONTENT:
${newTranscript.slice(0, 3000)}

Consider:
- Is the new content substantively the same as the original?
- Does it use the same arguments, examples, structure?
- Could this be independent creation on the same topic, or is it clearly derived?
- Is it a re-narration, paraphrase, or translation of the original?

Return JSON:
{
  "semanticSimilarity": 0.0 to 1.0,
  "isDerived": boolean,
  "reasoning": "Brief explanation"
}`;

      const result = await Promise.race([
        model.generateContent(prompt),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("GEMINI_TIMEOUT")), 30_000)
        ),
      ]);

      const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const parsed = JSON.parse(text);
      return Math.max(0, Math.min(1, parsed.semanticSimilarity || 0));
    } catch (error) {
      logger.warn("[CopyrightDetection] Gemini verification failed — skipping", {
        error: error instanceof Error ? error.message : String(error),
      });
      return 0; // Fail open — don't claim without verification
    }
  }

  // ─── Fair Use Analysis ─────────────────────────────────────────────────────

  /**
   * Run Gemini fair use analysis. Returns a 0-100 score (NOT binary).
   * Only called when a match is confirmed and a claim is being considered.
   */
  async analyzeFairUse(
    newTranscript: string,
    originalTranscript: string,
    matchedSegments: SegmentMatch[]
  ): Promise<FairUseAnalysis> {
    try {
      const vertexAI = new VertexAI({
        project: "truthworld-1",
        location: "asia-south1",
      });

      const model = vertexAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.2,
        },
      });

      const totalMatchedSeconds = matchedSegments.reduce(
        (sum, s) => sum + (s.infringingEnd - s.infringingStart), 0
      );

      const prompt = `You are a copyright fair use analyst. Analyze whether the NEW content qualifies as fair use of the ORIGINAL content.

ORIGINAL CONTENT (excerpt):
${originalTranscript.slice(0, 2000)}

NEW CONTENT (excerpt):
${newTranscript.slice(0, 2000)}

MATCH INFO:
- ${matchedSegments.length} matching segments found
- Total matched duration: ${totalMatchedSeconds} seconds

Evaluate each fair use factor on a 0-100 scale where 100 = STRONGLY favors fair use:

1. Commentary: Does the new content add commentary, criticism, or analysis?
2. Transformation: Is the original content transformed into something new?
3. LengthUsed: How much of the original was used? (100 = very little)
4. Purpose: Is the purpose educational, criticism, or news? (100 = clearly educational/criticism)
5. CommercialIntent: Is the use non-commercial? (100 = non-commercial)

Return JSON:
{
  "score": 0-100 overall fair use score,
  "factors": {
    "commentary": 0-100,
    "transformation": 0-100,
    "lengthUsed": 0-100,
    "purpose": 0-100,
    "commercialIntent": 0-100
  },
  "category": "commentary" | "review" | "education" | "parody" | "news" | "criticism" | "none",
  "reasoning": "Explanation of the fair use analysis"
}`;

      const result = await Promise.race([
        model.generateContent(prompt),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("FAIRUSE_TIMEOUT")), 30_000)
        ),
      ]);

      const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const parsed = JSON.parse(text);

      return {
        score: Math.max(0, Math.min(100, parsed.score || 0)),
        factors: {
          commentary: parsed.factors?.commentary || 0,
          transformation: parsed.factors?.transformation || 0,
          lengthUsed: parsed.factors?.lengthUsed || 0,
          purpose: parsed.factors?.purpose || 0,
          commercialIntent: parsed.factors?.commercialIntent || 0,
        },
        category: parsed.category || "none",
        reasoning: parsed.reasoning || "Analysis unavailable",
        confidence: 0.7,
      };
    } catch (error) {
      logger.warn("[CopyrightDetection] Fair use analysis failed", {
        error: error instanceof Error ? error.message : String(error),
      });
      // Default to moderate fair use — don't punish creator for system failure
      return {
        score: 50,
        factors: {
          commentary: 50,
          transformation: 50,
          lengthUsed: 50,
          purpose: 50,
          commercialIntent: 50,
        },
        category: "none",
        reasoning: "Fair use analysis could not be completed — defaulting to neutral",
        confidence: 0,
      };
    }
  }

  /**
   * Generate an evidence bundle for transparency.
   * Both the uploader and rights holder see the same evidence.
   */
  generateEvidenceBundle(
    newChunks: { startTime: number; endTime: number; text: string }[],
    originalChunks: { startTime: number; endTime: number; text: string }[],
    segments: SegmentMatch[],
    confidence: WeightedConfidence,
    fairUse: FairUseAnalysis | null,
    geminiExplanation: string | null
  ): EvidenceBundle {
    // Build matching transcript pairs
    const matchingPairs = segments.map((seg) => {
      const origChunk = originalChunks.find(
        (c) => c.startTime <= seg.originalStart && c.endTime >= seg.originalEnd
      );
      const newChunk = newChunks.find(
        (c) => c.startTime <= seg.infringingStart && c.endTime >= seg.infringingEnd
      );

      const formatTime = (seconds: number) => {
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
      };

      return {
        originalText: origChunk?.text || "",
        originalTimeRange: `${formatTime(seg.originalStart)}-${formatTime(seg.originalEnd)}`,
        matchedText: newChunk?.text || "",
        matchedTimeRange: `${formatTime(seg.infringingStart)}-${formatTime(seg.infringingEnd)}`,
        similarity: seg.chunkSimilarity,
      };
    });

    // Build similarity timeline (one point per 30s chunk)
    const timeline = newChunks.map((chunk) => {
      const matchingSegment = segments.find(
        (s) => s.infringingStart <= chunk.startTime && s.infringingEnd >= chunk.endTime
      );
      return {
        timeSeconds: chunk.startTime,
        similarity: matchingSegment?.chunkSimilarity || 0,
      };
    });

    return {
      matchingTranscriptPairs: matchingPairs,
      similarityTimeline: timeline,
      confidenceBreakdown: confidence,
      fairUseAnalysis: fairUse,
      geminiExplanation,
      generatedAt: Date.now(),
    };
  }

  // ─── Weighted Confidence Scoring ─────────────────────────────────────────

  private calculateWeightedScore(confidence: WeightedConfidence): number {
    const w = confidence.weights;
    let totalWeight = 0;
    let weightedSum = 0;

    if (confidence.md5Score !== null) {
      weightedSum += confidence.md5Score * w.md5;
      totalWeight += w.md5;
    }
    if (confidence.embeddingScore !== null) {
      weightedSum += confidence.embeddingScore * w.embedding;
      totalWeight += w.embedding;
    }
    if (confidence.transcriptScore !== null) {
      weightedSum += confidence.transcriptScore * w.transcript;
      totalWeight += w.transcript;
    }
    if (confidence.semanticScore !== null) {
      weightedSum += confidence.semanticScore * w.semantic;
      totalWeight += w.semantic;
    }

    // Normalize by available weights
    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }

  // ─── Match Persistence ─────────────────────────────────────────────────────

  private createMatch(
    newVideo: { videoId: string; ownerId: string; channelId: string },
    candidate: CandidateAsset | ChunkMatchResult,
    matchType: CopyrightMatch["matchType"],
    confidence: WeightedConfidence,
    finalConfidence: number,
    segments: SegmentMatch[]
  ): CopyrightMatch {
    return {
      matchId: `match_${Date.now()}_${uuidv4().substring(0, 8)}`,
      assetId: candidate.assetId,
      matchedVideoId: newVideo.videoId,
      matchedOwnerId: newVideo.ownerId,
      matchedChannelId: newVideo.channelId,
      matchType,
      matchedSegments: segments,
      confidenceBreakdown: confidence,
      finalConfidence,
      status: "detected",
      claimId: null,
      detectedAt: Date.now(),
    };
  }

  private async persistMatches(matches: CopyrightMatch[]): Promise<void> {
    if (matches.length === 0) return;

    try {
      const batch = db().batch();
      for (const match of matches) {
        batch.set(
          db().collection("copyright_matches").doc(match.matchId),
          match
        );
      }
      await batch.commit();
    } catch (err) {
      logger.error("[CopyrightDetection] Failed to persist matches", {
        matchCount: matches.length,
        err: err instanceof Error ? err.message : String(err),
      });
    }
  }
}

// ─── Internal Types ──────────────────────────────────────────────────────────

interface CandidateAsset {
  assetId: string;
  similarity: number;
  [key: string]: any;
}

interface ChunkMatchResult {
  assetId: string;
  ownerId: string;
  channelId: string;
  originalVideoId: string;
  originalTitle: string;
  originalTranscript: string;
  embeddingSimilarity: number;
  avgChunkSimilarity: number;
  segments: SegmentMatch[];
  matchingChunkRatio: number;
}

export const copyrightDetectionService = new CopyrightDetectionService();
