/**
 * 🔑 FINGERPRINT SERVICE — Content Identity Generation
 *
 * Generates fingerprints for copyright detection:
 *   1. MD5 hash      — from GCS metadata (already exists at upload time)
 *   2. Transcript embedding — 256-dim via Vertex AI text-embedding-005
 *   3. Summary embedding    — 256-dim for coarse-grained video-level search
 *   4. Transcript chunks    — 30-second segments with per-chunk embeddings
 *
 * Cost: text-embedding-005 is ~$0.000025 per 1K characters — orders of
 *       magnitude cheaper than Gemini inference. A 10-minute video transcript
 *       (~3000 words) costs about $0.001 to fingerprint.
 */

import * as admin from "firebase-admin";
import { GoogleAuth } from "google-auth-library";
import { logger } from "../utils/logger";
import {
  CopyrightAsset,
  CopyrightChunk,
  DETECTION_THRESHOLDS,
} from "./copyrightTypes";

const db = () => admin.firestore();
const EMBEDDING_MODEL = "text-embedding-005";
const VERTEX_PROJECT = "truthworld-1";
const VERTEX_LOCATION = "asia-south1";

// ─── Embedding Generation ────────────────────────────────────────────────────

/**
 * Generate a 256-dimensional text embedding using Vertex AI text-embedding-005.
 * Uses REST API with Application Default Credentials (no extra deps needed).
 */
async function generateEmbedding(text: string): Promise<number[]> {
  if (!text || text.trim().length < 10) {
    return new Array(DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS).fill(0);
  }

  // Truncate to 2048 tokens (~8000 chars) — text-embedding-005 limit
  const truncated = text.slice(0, 8000);

  try {
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    const client = await auth.getClient();
    const accessTokenResponse = await client.getAccessToken();
    const token = accessTokenResponse.token;

    const endpoint = `https://${VERTEX_LOCATION}-aiplatform.googleapis.com/v1/projects/${VERTEX_PROJECT}/locations/${VERTEX_LOCATION}/publishers/google/models/${EMBEDDING_MODEL}:predict`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        instances: [{ content: truncated }],
        parameters: {
          outputDimensionality: DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS,
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Embedding API error ${response.status}: ${errorText.slice(0, 200)}`);
    }

    const data = await response.json();
    const values = data.predictions?.[0]?.embeddings?.values;

    if (!values || !Array.isArray(values)) {
      throw new Error("No embedding values in response");
    }

    return values as number[];
  } catch (error) {
    logger.error("[Fingerprint] Embedding generation failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return new Array(DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS).fill(0);
  }
}

/**
 * Generate embeddings for a batch of texts (max 5 per call).
 * Batching reduces API round-trips for chunk processing.
 */
async function generateEmbeddingBatch(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return [];

  try {
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    const client = await auth.getClient();
    const accessTokenResponse = await client.getAccessToken();
    const token = accessTokenResponse.token;

    const endpoint = `https://${VERTEX_LOCATION}-aiplatform.googleapis.com/v1/projects/${VERTEX_PROJECT}/locations/${VERTEX_LOCATION}/publishers/google/models/${EMBEDDING_MODEL}:predict`;

    // Process in batches of 5 (API limit)
    const results: number[][] = [];
    const batchSize = 5;

    for (let i = 0; i < texts.length; i += batchSize) {
      const batch = texts.slice(i, i + batchSize);
      const instances = batch.map((text) => ({
        content: text.slice(0, 8000),
      }));

      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          instances,
          parameters: {
            outputDimensionality: DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS,
          },
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        logger.warn("[Fingerprint] Batch embedding failed", {
          status: response.status,
          error: errorText.slice(0, 200),
        });
        // Fill with zero vectors for failed batch
        for (let j = 0; j < batch.length; j++) {
          results.push(new Array(DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS).fill(0));
        }
        continue;
      }

      const data = await response.json();
      const predictions = data.predictions || [];

      for (let j = 0; j < batch.length; j++) {
        const values = predictions[j]?.embeddings?.values;
        results.push(
          values && Array.isArray(values)
            ? values
            : new Array(DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS).fill(0)
        );
      }
    }

    return results;
  } catch (error) {
    logger.error("[Fingerprint] Batch embedding failed", { error: String(error) });
    return texts.map(() => new Array(DETECTION_THRESHOLDS.EMBEDDING_DIMENSIONS).fill(0));
  }
}

// ─── Transcript Chunking ─────────────────────────────────────────────────────

interface TranscriptChunk {
  index: number;
  startTime: number;
  endTime: number;
  text: string;
}

/**
 * Split transcript into ~30-second chunks using utterance boundaries.
 * If utterances have timestamps, uses those for precise splitting.
 * Otherwise, splits by character count proportional to duration.
 */
function chunkTranscript(
  text: string,
  duration: number,
  utterances?: { start: number; end: number; text: string }[]
): TranscriptChunk[] {
  const chunkDuration = DETECTION_THRESHOLDS.CHUNK_DURATION_SECONDS;
  const chunks: TranscriptChunk[] = [];

  if (utterances && utterances.length > 0) {
    // ── Timestamp-aware chunking ───────────────────────────────────────────
    let currentChunkTexts: string[] = [];
    let chunkStart = utterances[0].start;
    let chunkIndex = 0;

    for (const utt of utterances) {
      currentChunkTexts.push(utt.text);

      if (utt.end - chunkStart >= chunkDuration) {
        chunks.push({
          index: chunkIndex,
          startTime: chunkStart,
          endTime: utt.end,
          text: currentChunkTexts.join(" ").trim(),
        });
        chunkIndex++;
        currentChunkTexts = [];
        chunkStart = utt.end;
      }
    }

    // Flush remaining
    if (currentChunkTexts.length > 0) {
      const lastUtt = utterances[utterances.length - 1];
      chunks.push({
        index: chunkIndex,
        startTime: chunkStart,
        endTime: lastUtt.end,
        text: currentChunkTexts.join(" ").trim(),
      });
    }
  } else {
    // ── Proportional text splitting ────────────────────────────────────────
    const numChunks = Math.max(1, Math.ceil(duration / chunkDuration));
    const charsPerChunk = Math.ceil(text.length / numChunks);

    for (let i = 0; i < numChunks; i++) {
      const start = i * charsPerChunk;
      const end = Math.min((i + 1) * charsPerChunk, text.length);
      const chunkText = text.slice(start, end).trim();

      if (chunkText.length > 0) {
        chunks.push({
          index: i,
          startTime: i * chunkDuration,
          endTime: Math.min((i + 1) * chunkDuration, duration),
          text: chunkText,
        });
      }
    }
  }

  return chunks;
}

/**
 * Compute MD5 hash of normalized transcript for fast pre-filtering.
 */
function hashTranscript(text: string): string {
  const normalized = text.toLowerCase().replace(/[^a-z0-9\s]/g, "").replace(/\s+/g, " ").trim();
  const crypto = require("crypto");
  return crypto.createHash("md5").update(normalized).digest("hex");
}

// ─── Asset Registration ──────────────────────────────────────────────────────

export class FingerprintService {
  /**
   * Register a video's fingerprints for copyright protection.
   *
   * Called after transcription completes — we need the transcript to generate
   * embeddings. MD5 hash is already available from ingestion.
   *
   * Cost: ~$0.001 per video (embedding generation only).
   */
  async registerAsset(params: {
    videoId: string;
    ownerId: string;
    channelId: string;
    videoTitle: string;
    videoDuration: number;
    md5Hash: string | null;
    transcript: string;
    summary: string;
    utterances?: { start: number; end: number; text: string }[];
    protectionLevel?: 'strict' | 'standard' | 'lenient';
    allowFairUse?: boolean;
    claimPolicy?: 'block' | 'monetize_shared' | 'track_only';
  }): Promise<CopyrightAsset> {
    const t0 = Date.now();
    const assetId = params.videoId;

    logger.info("[Fingerprint] Registering copyright asset", {
      assetId,
      transcriptLength: params.transcript.length,
      duration: params.videoDuration,
    });

    // 1. Generate summary embedding (coarse-grained search)
    const summaryEmbedding = await generateEmbedding(
      params.summary || params.transcript.slice(0, 2000)
    );

    // 2. Compute transcript hash (fast pre-filter)
    const transcriptHash = hashTranscript(params.transcript);

    // 3. Chunk transcript into 30s segments
    const chunks = chunkTranscript(
      params.transcript,
      params.videoDuration,
      params.utterances
    );

    // 4. Generate embeddings for all chunks (batched)
    const chunkTexts = chunks.map((c) => c.text);
    const chunkEmbeddings = await generateEmbeddingBatch(chunkTexts);

    // 5. Write copyright_asset document
    const asset: CopyrightAsset = {
      assetId,
      md5Hash: params.md5Hash || null,
      summaryEmbedding,
      transcriptHash,
      originalVideoId: params.videoId,
      ownerId: params.ownerId,
      channelId: params.channelId,
      videoTitle: params.videoTitle,
      videoDuration: params.videoDuration,
      protectionLevel: params.protectionLevel || "standard",
      allowFairUse: params.allowFairUse ?? true,
      claimPolicy: params.claimPolicy || "track_only",
      chunkCount: chunks.length,
      registeredAt: Date.now(),
      updatedAt: Date.now(),
    };

    // Use FieldValue.vector() for Firestore native vector search
    const assetDoc: Record<string, any> = {
      ...asset,
      summaryEmbedding: admin.firestore.FieldValue.vector(summaryEmbedding),
    };

    // 6. Batch write: asset + all chunks
    const batch = db().batch();

    batch.set(db().collection("copyright_assets").doc(assetId), assetDoc);

    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      const chunkId = `${assetId}_chunk_${String(i).padStart(3, "0")}`;

      const chunkDoc: CopyrightChunk = {
        chunkId,
        assetId,
        ownerId: params.ownerId,
        chunkIndex: i,
        startTime: chunk.startTime,
        endTime: chunk.endTime,
        transcriptText: chunk.text,
        chunkEmbedding: chunkEmbeddings[i],
        registeredAt: Date.now(),
      };

      const chunkFirestoreDoc: Record<string, any> = {
        ...chunkDoc,
        chunkEmbedding: admin.firestore.FieldValue.vector(chunkEmbeddings[i]),
      };

      batch.set(db().collection("copyright_chunks").doc(chunkId), chunkFirestoreDoc);
    }

    await batch.commit();

    // 7. Also update the legacy video_hashes collection for backward compat
    if (params.md5Hash) {
      await db().collection("video_hashes").doc(params.md5Hash).set({
        jobId: assetId,
        assetId,
        registeredAt: Date.now(),
        expiresAt: null, // No expiry for registered content
      }, { merge: true });
    }

    const durationMs = Date.now() - t0;
    logger.info("[Fingerprint] Asset registered successfully", {
      assetId,
      chunks: chunks.length,
      durationMs,
    });

    return asset;
  }

  /**
   * Generate fingerprints for a NEW video (not yet registered) to check
   * against existing assets. Returns the fingerprint data without persisting.
   */
  async generateFingerprints(params: {
    transcript: string;
    summary: string;
    duration: number;
    md5Hash: string | null;
    utterances?: { start: number; end: number; text: string }[];
  }): Promise<{
    md5Hash: string | null;
    transcriptHash: string;
    summaryEmbedding: number[];
    chunks: { index: number; startTime: number; endTime: number; text: string; embedding: number[] }[];
  }> {
    const summaryEmbedding = await generateEmbedding(
      params.summary || params.transcript.slice(0, 2000)
    );

    const transcriptHash = hashTranscript(params.transcript);

    const chunks = chunkTranscript(
      params.transcript,
      params.duration,
      params.utterances
    );

    const chunkTexts = chunks.map((c) => c.text);
    const chunkEmbeddings = await generateEmbeddingBatch(chunkTexts);

    return {
      md5Hash: params.md5Hash || null,
      transcriptHash,
      summaryEmbedding,
      chunks: chunks.map((c, i) => ({
        ...c,
        embedding: chunkEmbeddings[i],
      })),
    };
  }
}

// ─── Math Utilities ──────────────────────────────────────────────────────────

/**
 * Compute cosine similarity between two vectors.
 * Returns 0-1 where 1 = identical, 0 = orthogonal.
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0;

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  const denominator = Math.sqrt(normA) * Math.sqrt(normB);
  if (denominator === 0) return 0;

  return Math.max(0, Math.min(1, dotProduct / denominator));
}

export const fingerprintService = new FingerprintService();
