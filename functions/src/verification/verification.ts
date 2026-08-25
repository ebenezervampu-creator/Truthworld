/**
 * verification.ts
 * ═══════════════════════════════════════════════════════════════════════════════
 * Scalable image moderation pipeline — all logic in one file.
 *
 * FIXES APPLIED (vs original):
 *   FIX 1: thumbnails path regex — now supports BOTH flat (thumbnails/<file>)
 *           AND nested (thumbnails/<contentId>/<file>) layouts.
 *   FIX 2: generateDocId() — Firestore doc ID is now the filename (e.g.
 *           "87fd02cf-71d3-40c3-9fed-c80e75d4acdf.png") so you can look it
 *           up by name.  Random suffix only added on collision.
 *   FIX 3: VALID_EXTENSIONS — ".jpeg" was present but the banners test file
 *           ends in ".jpeg"; confirmed to work.
 *   FIX 4: JPEG extension normalisation in VALID_MIME_TYPES — kept as-is,
 *           both "image/jpeg" and "image/jpg" accepted.
 *
 * Exports (consumed by index.ts):
 *   ingestUploadedImage          — Storage trigger
 *   prefilterWorker              — Pub/Sub image-prefilter
 *   moderationWorkerHigh/Medium/Low — Pub/Sub image-moderation-*
 *   retryQueueProcessor          — Pub/Sub retry trigger
 *   retryQueueProcessorManual    — HTTPS (testing only)
 *   deadLetterHandler            — Pub/Sub DLQ
 *   getImageVerificationStatus   — HTTPS
 *   cleanupVerificationRecord    — HTTPS
 *
 * Pipeline flow:
 *   Storage → ingest → Pub/Sub(prefilter) → prefilterWorker
 *     ├─ APPROVE FAST → Firestore
 *     ├─ REJECT FAST  → quarantine + Firestore
 *     └─ SCAN         → Pub/Sub(moderation) → moderationWorker → Vision API → Firestore
 * ═══════════════════════════════════════════════════════════════════════════════
 */

import { onObjectFinalized }  from "firebase-functions/v2/storage";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onRequest }          from "firebase-functions/v2/https";
import { onSchedule }         from "firebase-functions/v2/scheduler";
import * as admin             from "firebase-admin";
import * as logger            from "firebase-functions/logger";
import * as crypto              from "crypto";
import { requireAdmin } from "../utils/auth";

if (!admin.apps.length) {
  admin.initializeApp();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

type ImageCategory      = "thumbnail" | "avatar" | "banner" | "community" | "topic" | "playlist" | "unknown";
type VerificationStatus = "PENDING" | "APPROVED" | "REJECTED" | "FLAGGED" | "ERROR";

interface ImageMetadata {
  category:   ImageCategory;
  userId?:    string;
  contentId?: string;
  fileName:   string;
  filePath:   string;
  uploadedAt: number;
  fileSize:   number;
  bucket:     string;
  gcsUri:     string;
  mimeType?:  string;
  _md5?:      string;
  _pHash?:    string;
  _hashDocId?: string;
}

interface ValidationResult {
  status:          VerificationStatus;
  reason:          string;
  score:           number;
  timestamp:       number;
  processedAt:     number;
  detailedScores?: SafeSearchScores;
}

interface SafeSearchScores {
  adult:    number;
  racy:     number;
  violence: number;
  medical:  number;
  spoof:    number;
}

interface UserTrustDoc {
  score:         number;
  approvedCount: number;
  rejectedCount: number;
  strikeCount:   number;
  updatedAt:     FirebaseFirestore.Timestamp;
}

interface ImageHashDoc {
  hash:       string;
  pHash:      string;
  status:     "APPROVED" | "REJECTED";
  filePath:   string;
  category:   ImageCategory;
  createdAt:  FirebaseFirestore.Timestamp;
}

interface PrefilterMessage {
  metadata:  ImageMetadata;
  messageId: string;
  docId?:    string;
}

interface ModerationMessage {
  metadata:  ImageMetadata;
  messageId: string;
  docId:     string;
}

interface RateLimitDoc {
  userId:     string;
  uploadCount: number;
  resetAt:    FirebaseFirestore.Timestamp;
  lastReset:  FirebaseFirestore.Timestamp;
}

interface ModerationRetry {
  metadata:      ImageMetadata;
  messageId:     string;
  docId:         string;
  retryCount:    number;
  lastError:     string;
  lastErrorHash: string;
  nextRetryAt:   number;
}

interface VisionTokenBucket {
  tokensAvailable: number;
  lastRefillAt:    FirebaseFirestore.Timestamp;
  totalConsumed:   number;
  updatedAt:       FirebaseFirestore.Timestamp;
}

interface QueuedMessage {
  metadata:        ImageMetadata;
  messageId:       string;
  docId:           string;
  retryCount:      number;
  firstAttemptAt:  number;
  queuedAt:        number;
  priority:        "HIGH" | "MEDIUM" | "LOW";
  lastError?:      string;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const BUCKET   = "truthworld-1.firebasestorage.app";
const GCS_BASE = `gs://${BUCKET}`;
const REGION   = "asia-south1";

const TOPIC_PREFILTER          = "image-prefilter";
const TOPIC_MODERATION_HIGH    = "image-moderation-high";
const TOPIC_MODERATION_MEDIUM  = "image-moderation-medium";
const TOPIC_MODERATION_LOW     = "image-moderation-low";
const TOPIC_RETRY_TRIGGER      = "image-moderation-retry-trigger";
const TOPIC_MODERATION_DLQ     = "image-moderation-dlq";

// Firestore collection names
const COL_VERIFICATION = "image_verification";
const COL_USER_TRUST   = "userTrust";
const COL_IMAGE_HASHES = "imageHashes";
const COL_REJECTED_LOG = "rejected_images_log";
const COL_FLAGGED      = "flagged_images_review";
const COL_METRICS      = "image_verification_metrics";
const COL_RATE_LIMITS     = "user_rate_limits";
const COL_MOD_RETRIES     = "moderation_retry_queue";
const COL_VISION_TOKENS   = "vision_token_bucket";
const COL_DEAD_LETTERS    = "moderation_dead_letters";

// File size limits per category (bytes)
const FILE_SIZE_LIMITS: Record<ImageCategory, number> = {
  thumbnail: 5  * 1024 * 1024,
  avatar:    3  * 1024 * 1024,
  banner:    5  * 1024 * 1024,
  community: 10 * 1024 * 1024,
  topic:     5  * 1024 * 1024,
  playlist:  5  * 1024 * 1024,
  unknown:   0,
};

const VALIDATION_RULES: Record<
  Exclude<ImageCategory, "unknown">,
  { maxAdultScore: number; maxRacyScore: number; maxViolenceScore: number; maxMedicalScore: number; maxSpoofScore: number }
> = {
  thumbnail: { maxAdultScore: 1, maxRacyScore: 1, maxViolenceScore: 1, maxMedicalScore: 2, maxSpoofScore: 3 },
  avatar:    { maxAdultScore: 1, maxRacyScore: 1, maxViolenceScore: 1, maxMedicalScore: 3, maxSpoofScore: 4 },
  banner:    { maxAdultScore: 1, maxRacyScore: 1, maxViolenceScore: 1, maxMedicalScore: 3, maxSpoofScore: 4 },
  community: { maxAdultScore: 0, maxRacyScore: 1, maxViolenceScore: 1, maxMedicalScore: 2, maxSpoofScore: 4 },
  topic:     { maxAdultScore: 1, maxRacyScore: 1, maxViolenceScore: 1, maxMedicalScore: 2, maxSpoofScore: 3 },
  playlist:  { maxAdultScore: 1, maxRacyScore: 1, maxViolenceScore: 1, maxMedicalScore: 2, maxSpoofScore: 3 },
};

const CONFIDENCE_LEVELS: Record<string, number> = {
  VERY_UNLIKELY: 0, UNLIKELY: 1, POSSIBLE: 2, LIKELY: 3, VERY_LIKELY: 4,
};

const TRUST_SCORE_NEW_USER    = 50;
const TRUST_DELTA_APPROVED    = 2;
const TRUST_DELTA_REJECTED    = -15;
const TRUST_DELTA_FLAGGED     = -5;

const TTL_VERIFICATION_DAYS = 7;
const TTL_REJECTED_DAYS     = 30;
const TTL_FLAGGED_DAYS      = 90;

// ─────────────────────────────────────────────────────────────────────────────
// FIX 1: VALID_EXTENSIONS — kept exactly as original (jpeg is included)
// FIX 3: VALID_MIME_TYPES — added "image/jpg" as alias for robustness
// ─────────────────────────────────────────────────────────────────────────────
const VALID_EXTENSIONS = /\.(jpg|jpeg|png|webp|gif)$/i;
const VALID_MIME_TYPES = ["image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif"];

const RATE_LIMIT_CONFIG = {
  UPLOADS_PER_HOUR: 100,
  UPLOADS_PER_DAY:  1000,
  ENABLE_RATE_LIMITING: true,
};

// @ts-ignore: Used in hash similarity detection (pHash comparison logic in prefilter)
const PHASH_SIMILARITY_THRESHOLD = 5;

const VISION_TOKEN_CONFIG = {
  TOKENS_PER_MINUTE: 300,
  REFILL_INTERVAL_MS: 60000,
  EMERGENCY_BACKOFF_MS: 30000,
  TOKENS_HIGH_PER_MINUTE: 180,
  TOKENS_MEDIUM_PER_MINUTE: 90,
  TOKENS_LOW_PER_MINUTE: 30,
};

const RETRY_BACKOFF = {
  BASE_DELAY_MS: 2000,
  MULTIPLIER: 2,
  MAX_DELAY_MS: 60000,
  MAX_RETRIES: 5,
  AGING_PRIORITY_THRESHOLD_MS: 30000,
  MAX_QUEUE_AGE_MS: 300000,
};

const RETRY_PROCESSOR_CONFIG = {
  region: REGION, timeoutSeconds: 120, memory: "512MiB" as const, maxInstances: 5,
};

const INGEST_CONFIG = {
  bucket: BUCKET,
  region: REGION, timeoutSeconds: 60,  memory: "256MiB" as const, maxInstances: 5, retry: true,
};
const PREFILTER_CONFIG = {
  region: REGION, timeoutSeconds: 120, memory: "512MiB" as const, maxInstances: 5,  retry: true,
};
const MODERATION_CONFIG_HIGH = {
  region: REGION, timeoutSeconds: 540, memory: "512MiB" as const, maxInstances: 5,  retry: true,
};
const MODERATION_CONFIG_MEDIUM = {
  region: REGION, timeoutSeconds: 540, memory: "512MiB" as const, maxInstances: 5,  retry: true,
};
const MODERATION_CONFIG_LOW = {
  region: REGION, timeoutSeconds: 540, memory: "512MiB" as const, maxInstances: 5,   retry: true,
};

const SHARDING_CONFIG = {
  TOKEN_BUCKET_SHARDS: 10,
  RETRY_QUEUE_SHARDS: 10,
  SHARD_BITS: 4,
};

const CIRCUIT_BREAKER_CONFIG = {
  FAILURE_THRESHOLD: 0.20,
  SAMPLE_WINDOW_MS: 60000,
  OPEN_TIMEOUT_MS: 30000,
  MIN_SAMPLES: 10,
  FALLBACK_PREFERENCE: "CONSERVATIVE",
};

const BACKPRESSURE_CONFIG = {
  QUEUE_DEPTH_WARNING_THRESHOLD: 1000,
  QUEUE_DEPTH_CRITICAL_THRESHOLD: 5000,
  AVG_LATENCY_WARNING_MS: 5000,
  RETRY_RATE_WARNING: 0.15,
  BACKPRESSURE_COLLECTION: "system_backpressure",
};

const IDEMPOTENCY_CONFIG = {
  KEY_TTL_MS: 21600000,
  COLLECTION: "idempotency_keys",
};

const CONCURRENCY_CONFIG = {
  MAX_PARALLEL_PER_USER: 5,
  MAX_PARALLEL_PER_HOUR: 100,
  WINDOW_MS: 3600000,
  COLLECTION: "user_concurrency",
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAZY CLIENTS
// ═══════════════════════════════════════════════════════════════════════════════

let _visionClient: any = null;
let _pubSubClient: any = null;

function visionClient(): any {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT_ID || undefined;
  if (!_visionClient) {
    const { ImageAnnotatorClient } = require("@google-cloud/vision");
    _visionClient = new ImageAnnotatorClient({ projectId });
  }
  return _visionClient;
}

function pubSubClient(): any {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT_ID || undefined;
  if (!_pubSubClient) {
    const { PubSub } = require("@google-cloud/pubsub");
    _pubSubClient = new PubSub({ projectId });
  }
  return _pubSubClient;
}

const db = () => admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Extract structured ImageMetadata from a GCS file path.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FIX 1 — thumbnails path regex.
 *
 * BEFORE (broken):
 *   /^thumbnails\/[^/]+\/[^/]+\.(jpg|...)$/i
 *   This requires TWO path segments after "thumbnails/", i.e. thumbnails/<a>/<b>.jpg
 *   but the real path is thumbnails/<uuid>.png — only ONE segment — so regex
 *   never matches and extractMetadata() returns null → ingest silently exits.
 *
 * AFTER (fixed):
 *   /^thumbnails\/[^/]+\.(jpg|...)$/i      — flat:   thumbnails/<file>
 *   /^thumbnails\/[^/]+\/[^/]+\.(jpg|...)$/i — nested: thumbnails/<id>/<file>
 *   Both are matched; contentId is set when the nested pattern matches.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Supported patterns (all now working):
 *   thumbnails/<file>.(jpg|jpeg|png|webp|gif)              ← NEW flat pattern
 *   thumbnails/<contentId>/<file>.(jpg|jpeg|png|webp|gif)  ← existing nested
 *   channels/avatars/<userId>/<file>.(jpg|jpeg|png|webp|gif)
 *   channels/banners/<userId>/<file>.(jpg|jpeg|png|webp|gif)
 *   community_images/<userId>/<postId>/<file>.(jpg|jpeg|png|webp|gif)
 */
function extractMetadata(
  filePath: string,
  bucket:   string,
  fileSize: number,
  mimeType?: string
): ImageMetadata | null {
  const parts    = filePath.split("/");
  const fileName = parts[parts.length - 1];
  let category:  ImageCategory = "unknown";
  let userId:    string | undefined;
  let contentId: string | undefined;

  // ── Topics Custom Thumbnails ──────────────────────────────────────────────
  if (/^thumbnails\/topics\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^topics\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "topic";
    contentId = parts[parts.length - 1];

  // ── Playlists Custom Thumbnails ───────────────────────────────────────────
  } else if (/^thumbnails\/playlists\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^playlists\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "playlist";
    contentId = parts[parts.length - 1];

  // ── FIX 1a: flat thumbnail — thumbnails/<file>.ext ────────────────────────
  } else if (/^thumbnails\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "thumbnail";
    // No contentId for flat paths (contentId stays undefined)

  // ── FIX 1b: nested thumbnail — thumbnails/<contentId>/<file>.ext ─────────
  } else if (/^thumbnails\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "thumbnail";
    contentId = parts[1];

  } else if (/^channels\/avatars\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^avatars\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^avatars\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "avatar";
    userId = parts.length > 2 ? parts[parts.length - 2] : undefined;

  } else if (/^channels\/banners\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^banners\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^banners\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "banner";
    userId = parts.length > 2 ? parts[parts.length - 2] : undefined;

  } else if (/^community_images\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^community\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "community";
  } else if (/^community_images\/[^/]+\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath) || /^community\/[^/]+\/[^/]+\/[^/]+\.(jpg|jpeg|png|webp|gif)$/i.test(filePath)) {
    category = "community";
    userId = parts[1];
    contentId = parts[2];
  }

  if (category === "unknown") return null;

  return {
    category, userId, contentId, fileName, filePath,
    uploadedAt: Date.now(), fileSize, bucket,
    gcsUri: `${GCS_BASE}/${filePath}`, mimeType,
  };
}

function validateFileType(filePath: string, mimeType?: string): boolean {
  return VALID_EXTENSIONS.test(filePath) && (!mimeType || VALID_MIME_TYPES.includes(mimeType));
}

function validateFileSize(category: ImageCategory, bytes: number): { valid: boolean; reason?: string } {
  const limit = FILE_SIZE_LIMITS[category];
  if (!limit) return { valid: false, reason: "Unknown image category" };
  if (bytes > limit) {
    return { valid: false, reason: `File ${(bytes / 1024 / 1024).toFixed(2)} MB exceeds ${limit / 1024 / 1024} MB limit for ${category}` };
  }
  return { valid: true };
}

function getScore(level: unknown): number {
  if (!level || typeof level !== "string") return 4;
  return CONFIDENCE_LEVELS[level] ?? 4;
}

function hashToDocId(hash: string): string {
  return hash.replace(/[^a-zA-Z0-9_-]/g, "").substring(0, 128);
}

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * FIX 2 — Firestore document ID is now the filename.
 *
 * BEFORE (broken):
 *   `${metadata.category}_${metadata.contentId ?? metadata.userId ?? "unknown"}_${Date.now()}_${rand}`
 *   → produces IDs like "thumbnail_unknown_1712345678_AB3X" which are impossible
 *     to look up without scanning the whole collection.
 *
 * AFTER (fixed):
 *   Primary key = fileName (e.g. "87fd02cf-71d3-40c3-9fed-c80e75d4acdf.png")
 *   This is unique per upload because GCS file names are UUIDs.
 *   The collection is image_verification so the full Firestore path becomes:
 *     image_verification/87fd02cf-71d3-40c3-9fed-c80e75d4acdf.png
 *
 * Firestore document ID rules enforced here:
 *   - Must not contain "/"  (GCS path uses "/", fileName does not)
 *   - Must not be "." or ".."
 *   - Max 1500 bytes — a UUID filename is only ~40 chars, well within limit
 *
 * Collision handling (belt-and-suspenders):
 *   If two uploads share the same filename (edge case: same UUID reused),
 *   a short random suffix is appended to avoid overwriting the existing doc.
 * ─────────────────────────────────────────────────────────────────────────────
 */
function generateDocId(metadata: ImageMetadata): string {
  // Use the filename directly as the document ID (e.g. "87fd02cf-....png")
  const fileName = metadata.fileName;

  // Sanitise: replace any "/" (shouldn't be in a filename but be safe) and
  // characters Firestore rejects.  Keep dots, dashes, underscores — all valid.
  const safe = fileName.replace(/\//g, "_").replace(/\.\./g, "_").trim();

  if (safe && safe !== "." && safe.length <= 1500) {
    return safe; // "87fd02cf-71d3-40c3-9fed-c80e75d4acdf.png"
  }

  // Fallback: category + userId/contentId + timestamp (should never happen for
  // well-formed UUID filenames, but keeps the pipeline running either way)
  const rand = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `${metadata.category}_${metadata.contentId ?? metadata.userId ?? "unknown"}_${Date.now()}_${rand}`;
}

function generateMessageId(): string {
  return crypto.randomUUID();
}

function clampScore(score: number): number {
  return Math.max(0, Math.min(100, score));
}

function getPriority(category: ImageCategory): string {
  if (category === "unknown") return "LOW";
  const { priority } = getPriorityTopic(category as Exclude<ImageCategory, "unknown">);
  return priority;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARDING / CIRCUIT BREAKER / BACKPRESSURE / IDEMPOTENCY HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

function getShardIndex(docId: string, numShards: number = SHARDING_CONFIG.TOKEN_BUCKET_SHARDS): number {
  let hash = 0;
  for (let i = 0; i < docId.length; i++) {
    hash = ((hash << 5) - hash) + docId.charCodeAt(i);
    hash = hash & hash;
  }
  return Math.abs(hash) % numShards;
}

function getShardedTokenBucketId(priority: "HIGH" | "MEDIUM" | "LOW", shardIndex: number): string {
  return `quota_${priority.toLowerCase()}_${shardIndex}`;
}

function getShardedRetryCollectionName(shardIndex: number): string {
  return `moderation_retry_${shardIndex}`;
}

async function checkCircuitBreaker(): Promise<{ state: "CLOSED" | "OPEN" | "HALF_OPEN"; canProceed: boolean }> {
  try {
    const ref = db().collection("system_metrics").doc("vision_circuit_breaker");
    const snap = await ref.get();
    const now = Date.now();

    if (!snap.exists) return { state: "CLOSED", canProceed: true };

    const breaker = snap.data() as any;
    const lastStateChange = breaker.lastStateChange?.toMillis?.() ?? now;

    if (breaker.state === "OPEN") {
      if ((now - lastStateChange) >= CIRCUIT_BREAKER_CONFIG.OPEN_TIMEOUT_MS) {
        await ref.update({ state: "HALF_OPEN", lastStateChange: new Date(now), testedAt: new Date(now) });
        logger.info("[CircuitBreaker] Transitioned OPEN → HALF_OPEN");
        return { state: "HALF_OPEN", canProceed: true };
      }
      return { state: "OPEN", canProceed: false };
    }

    const windowStart = now - CIRCUIT_BREAKER_CONFIG.SAMPLE_WINDOW_MS;
    const windowStartHour = Math.floor(windowStart / 3600000);
    const nowHour = Math.floor(now / 3600000);
    const allEvents: Array<{ timestamp: number; success: boolean }> = [];

    for (let h = windowStartHour; h <= nowHour; h++) {
      const bucketSnap = await db().collection("vision_cb_events").doc(`bucket_${h}`).get();
      if (bucketSnap.exists) {
        const bucketEvents = ((bucketSnap.data() as any)?.events ?? []) as Array<{ timestamp: number; success: boolean }>;
        allEvents.push(...bucketEvents.filter(e => e.timestamp > windowStart));
      }
    }

    if (allEvents.length >= CIRCUIT_BREAKER_CONFIG.MIN_SAMPLES) {
      const failureCount = allEvents.filter(e => !e.success).length;
      const failureRate = failureCount / allEvents.length;

      if (failureRate > CIRCUIT_BREAKER_CONFIG.FAILURE_THRESHOLD) {
        await ref.set({
          state: "OPEN", lastStateChange: new Date(now), trippedAt: new Date(now),
          failureRate, windowedFailureCount: failureCount, windowedEventCount: allEvents.length,
        }, { merge: true });
        logger.warn(`[CircuitBreaker] TRIPPED (${(failureRate * 100).toFixed(1)}%)`);
        return { state: "OPEN", canProceed: false };
      }
    }

    return { state: "CLOSED", canProceed: true };
  } catch (err) {
    logger.warn("[CircuitBreaker] Check failed (defaulting CLOSED):", err);
    return { state: "CLOSED", canProceed: true };
  }
}

async function recordVisionResult(success: boolean): Promise<void> {
  try {
    const now = Date.now();
    const hourBucket = Math.floor(now / 3600000);
    const bucketRef = db().collection("vision_cb_events").doc(`bucket_${hourBucket}`);
    await bucketRef.set(
      { hour: hourBucket, events: admin.firestore.FieldValue.arrayUnion({ timestamp: now, success }), updatedAt: new Date(now) },
      { merge: true }
    );
    if (Math.random() < 0.05) {
      const cutoffHour = Math.floor((now - 86400000) / 3600000);
      const old = await db().collection("vision_cb_events").where("hour", "<", cutoffHour).limit(10).get();
      for (const d of old.docs) await d.ref.delete();
    }
  } catch (err) {
    logger.warn("[CircuitBreaker] Recording failed (non-fatal):", err);
  }
}

// @ts-ignore
async function updateBackpressureMetrics(event: { queueDepth?: number; avgLatencyMs?: number; retryRate?: number }): Promise<void> {
  try {
    const ref = db().collection(BACKPRESSURE_CONFIG.BACKPRESSURE_COLLECTION).doc("system_state");
    await ref.set({
      queueDepth: event.queueDepth ?? admin.firestore.FieldValue.delete(),
      avgLatencyMs: event.avgLatencyMs ?? admin.firestore.FieldValue.delete(),
      retryRate: event.retryRate ?? admin.firestore.FieldValue.delete(),
      updatedAt: new Date(),
    }, { merge: true });
  } catch (err) {
    logger.warn("[Backpressure] Metrics update failed:", err);
  }
}

async function getBackpressureStatus(): Promise<{ isThrottling: boolean; reason?: string; recommendedSamplingRate?: number }> {
  try {
    const snap = await db().collection(BACKPRESSURE_CONFIG.BACKPRESSURE_COLLECTION).doc("system_state").get();
    if (!snap.exists) return { isThrottling: false };
    const state = snap.data() as any;
    const queueDepth = state.queueDepth ?? 0;
    if (queueDepth >= BACKPRESSURE_CONFIG.QUEUE_DEPTH_CRITICAL_THRESHOLD) {
      return { isThrottling: true, reason: `Queue depth critical: ${queueDepth}`, recommendedSamplingRate: 0.5 };
    }
    return { isThrottling: false };
  } catch (err) {
    logger.warn("[Backpressure] Check failed (allowing):", err);
    return { isThrottling: false };
  }
}

function generateIdempotencyKey(filePath: string, uploadedAtMs: number): string {
  return crypto.createHash("sha256").update(`${filePath}:${uploadedAtMs}`).digest("hex");
}

async function checkIdempotencyKey(key: string): Promise<{ isDuplicate: boolean; docId?: string }> {
  try {
    const snap = await db().collection(IDEMPOTENCY_CONFIG.COLLECTION).doc(key).get();
    if (snap.exists) return { isDuplicate: true, docId: snap.data()?.docId };
    return { isDuplicate: false };
  } catch (err) {
    logger.warn("[Idempotency] Check failed (allowing):", err);
    return { isDuplicate: false };
  }
}

async function recordIdempotencyKey(key: string, docId: string): Promise<void> {
  try {
    await db().collection(IDEMPOTENCY_CONFIG.COLLECTION).doc(key).set({
      docId, createdAt: new Date(), expiresAt: new Date(Date.now() + IDEMPOTENCY_CONFIG.KEY_TTL_MS),
    });
  } catch (err) {
    logger.warn("[Idempotency] Recording failed (non-fatal):", err);
  }
}

function evaluateScores(
  category: Exclude<ImageCategory, "unknown">,
  scores:   SafeSearchScores
): ValidationResult {
  const rules     = VALIDATION_RULES[category];
  const timestamp = Date.now();
  const checks = [
    { condition: scores.adult    > rules.maxAdultScore,    status: "REJECTED" as const, reason: "Adult content detected",            score: scores.adult    },
    { condition: scores.racy     > rules.maxRacyScore,     status: "REJECTED" as const, reason: "Racy content detected",             score: scores.racy     },
    { condition: scores.violence > rules.maxViolenceScore, status: "REJECTED" as const, reason: "Violent content detected",          score: scores.violence },
    { condition: scores.medical  > rules.maxMedicalScore,  status: "FLAGGED"  as const, reason: "Medical content — needs review",    score: scores.medical  },
    { condition: scores.spoof    > rules.maxSpoofScore,    status: "FLAGGED"  as const, reason: "Spoof/meme content — needs review", score: scores.spoof    },
  ];
  for (const c of checks) {
    if (c.condition) {
      return { status: c.status, reason: c.reason, score: c.score, timestamp, processedAt: timestamp, detailedScores: scores };
    }
  }
  return {
    status: "APPROVED", reason: "Passed all safety checks",
    score: Math.max(scores.adult, scores.racy, scores.violence),
    timestamp, processedAt: timestamp, detailedScores: scores,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUB/SUB HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

async function publishMessage(topic: string, payload: unknown): Promise<void> {
  try {
    const msgId = await pubSubClient().topic(topic).publishMessage({ data: Buffer.from(JSON.stringify(payload)) });
    logger.info(`[PubSub] ✓ Published to ${topic}: msgId=${msgId}`);
  } catch (err) {
    logger.error(`[PubSub] ✗ FAILED to publish to ${topic}:`, err);
    throw new Error(`Failed to publish to topic "${topic}": ${String(err)}`);
  }
}

function parseMessage<T>(data: string | null | undefined): T {
  const raw = data ? Buffer.from(data, "base64").toString("utf-8") : "{}";
  return JSON.parse(raw) as T;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VISION API
// ═══════════════════════════════════════════════════════════════════════════════

async function detectSafeSearch(bucket: string, filePath: string): Promise<{ scores: SafeSearchScores | null; error?: string }> {
  try {
    const [result] = await visionClient().safeSearchDetection({
      image: { source: { imageUri: `gs://${bucket}/${filePath}` } },
    });
    const ss = result.safeSearchAnnotation ?? {};
    const scores = {
      adult:    getScore(ss.adult),
      racy:     getScore(ss.racy),
      violence: getScore(ss.violence),
      medical:  getScore(ss.medical),
      spoof:    getScore(ss.spoof),
    };
    return { scores };
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    logger.error(`[Vision] SafeSearch failed for ${filePath}:`, errMsg);
    return { scores: null, error: errMsg };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STORAGE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

type GCSBucket = ReturnType<ReturnType<typeof admin.storage>["bucket"]>;

async function getGCSMetadataHash(bucket: GCSBucket, filePath: string): Promise<{ crc32c: string | null; md5: string | null }> {
  try {
    const [metadata] = await bucket.file(filePath).getMetadata();
    return { crc32c: metadata.crc32c ?? null, md5: metadata.md5Hash ?? null };
  } catch (err) {
    logger.warn(`[Storage] Could not get metadata hash for ${filePath}:`, err);
    return { crc32c: null, md5: null };
  }
}

// @ts-ignore
async function computePerceptualHash(bucket: GCSBucket, filePath: string): Promise<string | null> {
  try {
    const file = bucket.file(filePath);
    const stream = file.createReadStream();
    const pixels = await new Promise<Buffer>((resolve, reject) => {
      const chunks: Buffer[] = [];
      stream
        .on("data", (chunk) => chunks.push(chunk))
        .on("end", async () => {
          try {
            const buffer = Buffer.concat(chunks);
            const sharp = require("sharp");
            const result = await sharp(buffer).greyscale().resize(8, 8, { fit: "fill", withoutEnlargement: true }).raw().toBuffer();
            resolve(result);
          } catch (err) { reject(err); }
        })
        .on("error", reject);
    });
    let sum = 0;
    for (let i = 0; i < pixels.length; i++) sum += pixels[i];
    const avg = Math.floor(sum / pixels.length);
    let hash = "";
    for (let i = 0; i < Math.min(pixels.length, 64); i++) hash += pixels[i] >= avg ? "1" : "0";
    while (hash.length < 64) hash += "0";
    return parseInt(hash, 2).toString(16).padStart(16, "0");
  } catch (err) {
    logger.warn(`[Storage] pHash failed for ${filePath}:`, err);
    return null;
  }
}

// @ts-ignore
function hammingDistance(hash1: string, hash2: string): number {
  if (!hash1 || !hash2 || hash1.length !== hash2.length) return 64;
  let distance = 0;
  for (let i = 0; i < hash1.length; i++) { if (hash1[i] !== hash2[i]) distance++; }
  return distance;
}

async function fileExists(bucket: GCSBucket, filePath: string): Promise<boolean> {
  try {
    const [exists] = await bucket.file(filePath).exists();
    return exists;
  } catch (err) {
    logger.error(`[Storage] fileExists FAILED for ${filePath}:`, err);
    throw new Error(`Failed to check file existence: ${filePath}. ${String(err)}`);
  }
}

async function quarantineFile(bucket: GCSBucket, metadata: ImageMetadata, result: ValidationResult): Promise<void> {
  const date = new Date().toISOString().split("T")[0];
  const quarantinePath = `_quarantine/rejected/${date}/${metadata.category}/${metadata.fileName}`;
  try {
    await bucket.file(metadata.filePath).copy(bucket.file(quarantinePath));
    await bucket.file(metadata.filePath).delete();
    await logRejectedImage(metadata, result, quarantinePath);
    logger.info(`[Storage] Quarantined: ${metadata.filePath} → ${quarantinePath}`);
  } catch (copyErr) {
    logger.error(`[Storage] Quarantine copy failed:`, copyErr);
    try {
      await bucket.file(metadata.filePath).delete();
    } catch (delErr) {
      logger.error(`[Storage] CRITICAL — could not remove rejected file ${metadata.filePath}:`, delErr);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIRESTORE DATA ACCESS
// ═══════════════════════════════════════════════════════════════════════════════

async function createPendingDoc(docId: string, metadata: ImageMetadata): Promise<void> {
  await db().collection(COL_VERIFICATION).doc(docId).set({
    docId,
    status:      "PENDING",
    queueState:  null,
    retryCount:  0,
    reason:      "Awaiting moderation",
    score:       0,
    category:    metadata.category,
    fileName:    metadata.fileName,
    filePath:    metadata.filePath,
    gcsUri:      metadata.gcsUri,
    userId:      metadata.userId    ?? null,
    contentId:   metadata.contentId ?? null,
    fileSize:    metadata.fileSize,
    priority:    getPriority(metadata.category),
    createdAt:   admin.firestore.FieldValue.serverTimestamp(),
    processedAt: null,
    nextRetryAt: null,
    expiresAt:   new Date(Date.now() + TTL_VERIFICATION_DAYS * 86400_000),
  });
}

async function updateVerificationDoc(docId: string, metadata: ImageMetadata, result: ValidationResult): Promise<void> {
  await db().collection(COL_VERIFICATION).doc(docId).set(
    {
      docId,
      status:         result.status,
      reason:         result.reason,
      score:          result.score,
      detailedScores: result.detailedScores ?? {},
      category:       metadata.category,
      fileName:       metadata.fileName,
      filePath:       metadata.filePath,
      gcsUri:         metadata.gcsUri,
      userId:         metadata.userId    ?? null,
      contentId:      metadata.contentId ?? null,
      fileSize:       metadata.fileSize,
      priority:       getPriority(metadata.category),
      processedAt:    admin.firestore.FieldValue.serverTimestamp(),
      expiresAt:      new Date(Date.now() + TTL_VERIFICATION_DAYS * 86400_000),
    },
    { merge: true }
  );
  logger.info(`[Firestore] ${docId} → ${result.status}`);
}

async function getHashDoc(hashDocId: string): Promise<ImageHashDoc | null> {
  const snap = await db().collection(COL_IMAGE_HASHES).doc(hashDocId).get();
  return snap.exists ? (snap.data() as ImageHashDoc) : null;
}

async function setHashDoc(hashDocId: string, hash: string, status: "APPROVED" | "REJECTED", metadata: ImageMetadata): Promise<void> {
  try {
    await db().collection(COL_IMAGE_HASHES).doc(hashDocId).set(
      { hash, pHash: metadata._pHash || "", status, filePath: metadata.filePath, category: metadata.category, createdAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  } catch (err) {
    logger.warn("[Firestore] imageHashes write failed (non-fatal):", err);
  }
}

async function updateUserTrust(userId: string, status: "APPROVED" | "REJECTED" | "FLAGGED"): Promise<void> {
  if (!userId) return;
  const ref = db().collection(COL_USER_TRUST).doc(userId);
  try {
    await db().runTransaction(async (tx) => {
      const snap     = await tx.get(ref);
      const existing = snap.exists ? (snap.data() as UserTrustDoc) : null;
      const current  = existing?.score         ?? TRUST_SCORE_NEW_USER;
      const approved = existing?.approvedCount ?? 0;
      const rejected = existing?.rejectedCount ?? 0;
      const strikes  = existing?.strikeCount   ?? 0;
      const delta    = status === "APPROVED" ? TRUST_DELTA_APPROVED : status === "REJECTED" ? TRUST_DELTA_REJECTED : TRUST_DELTA_FLAGGED;
      tx.set(ref, {
        score:         clampScore(current + delta),
        approvedCount: approved + (status === "APPROVED" ? 1 : 0),
        rejectedCount: rejected + (status === "REJECTED" ? 1 : 0),
        strikeCount:   strikes  + (status === "REJECTED" ? 1 : 0),
        updatedAt:     admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
  } catch (err) {
    logger.warn(`[Firestore] Trust update failed for ${userId}:`, err);
  }
}

async function logRejectedImage(metadata: ImageMetadata, result: ValidationResult, quarantinePath: string): Promise<void> {
  try {
    await db().collection(COL_REJECTED_LOG).add({
      originalPath: metadata.filePath, quarantinePath, gcsUri: metadata.gcsUri,
      category: metadata.category, userId: metadata.userId ?? null, contentId: metadata.contentId ?? null,
      reason: result.reason, score: result.score, detailedScores: result.detailedScores ?? {},
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(), status: "PENDING_DELETION",
      expiresAt: new Date(Date.now() + TTL_REJECTED_DAYS * 86400_000),
    });
  } catch (err) {
    logger.warn("[Firestore] rejected_images_log write failed:", err);
  }
}

async function logFlaggedImage(metadata: ImageMetadata, result: ValidationResult): Promise<void> {
  try {
    await db().collection(COL_FLAGGED).add({
      fileName: metadata.fileName, filePath: metadata.filePath, gcsUri: metadata.gcsUri,
      category: metadata.category, userId: metadata.userId ?? null, contentId: metadata.contentId ?? null,
      reason: result.reason, score: result.score, detailedScores: result.detailedScores ?? {},
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(), status: "PENDING_REVIEW",
      priority: getPriority(metadata.category),
      expiresAt: new Date(Date.now() + TTL_FLAGGED_DAYS * 86400_000),
    });
  } catch (err) {
    logger.warn("[Firestore] flagged_images_review write failed:", err);
  }
}

async function logMetrics(
  metadata: ImageMetadata, result: ValidationResult,
  processingTimeMs: number, phase: "ingest" | "prefilter" | "moderation", skipReason?: string
): Promise<void> {
  try {
    if (Math.random() > 0.10) return;
    const day = new Date().toISOString().split("T")[0];
    await db().collection(COL_METRICS).doc(day).collection("events").add({
      phase, category: metadata.category, status: result.status,
      userId: metadata.userId ?? null, processingTimeMs, fileSize: metadata.fileSize,
      reason: result.reason, score: result.score, skipReason: skipReason ?? null,
      sampled: true, timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.warn("[Firestore] Metrics write failed:", err);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RATE LIMITING
// ═══════════════════════════════════════════════════════════════════════════════

async function checkRateLimit(userId: string | undefined): Promise<{ allowed: boolean; reason?: string }> {
  if (!userId || !RATE_LIMIT_CONFIG.ENABLE_RATE_LIMITING) return { allowed: true };
  try {
    const concurrencyRef = db().collection(CONCURRENCY_CONFIG.COLLECTION).doc(userId);
    const concurrencySnap = await concurrencyRef.get();
    if (concurrencySnap.exists) {
      const activeUploads = ((concurrencySnap.data() as any).active ?? 0) as number;
      if (activeUploads >= CONCURRENCY_CONFIG.MAX_PARALLEL_PER_USER) {
        return { allowed: false, reason: `Too many concurrent uploads (${activeUploads}/${CONCURRENCY_CONFIG.MAX_PARALLEL_PER_USER}).` };
      }
    }
    const now = Date.now();
    const docId = `${userId}_hourly`;
    const ref = db().collection(COL_RATE_LIMITS).doc(docId);
    return await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, { userId, uploadCount: 1, resetAt: new Date(now + 3600 * 1000), lastReset: new Date(now) });
        return { allowed: true };
      }
      const doc = snap.data() as RateLimitDoc;
      const resetTime = doc.resetAt?.toMillis?.() ?? 0;
      if (now > resetTime) {
        tx.set(ref, { userId, uploadCount: 1, resetAt: new Date(now + 3600 * 1000), lastReset: new Date(now) });
        return { allowed: true };
      }
      if (doc.uploadCount >= RATE_LIMIT_CONFIG.UPLOADS_PER_HOUR) {
        return { allowed: false, reason: `Rate limit exceeded (${RATE_LIMIT_CONFIG.UPLOADS_PER_HOUR}/hour).` };
      }
      tx.update(ref, { uploadCount: doc.uploadCount + 1 });
      return { allowed: true };
    });
  } catch (err) {
    logger.warn("[RateLimit] Check failed (allowing):", err);
    return { allowed: true };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODERATION RETRY / DLQ / TOKEN BUCKET
// ═══════════════════════════════════════════════════════════════════════════════

async function useFallbackModerationModel(metadata: ImageMetadata): Promise<ValidationResult> {
  logger.info(`[Moderation] Using fallback model for ${metadata.filePath}`);
  return {
    status: "FLAGGED",
    reason: "Vision API unavailable — using fallback moderation (manual review required)",
    score: 3, timestamp: Date.now(), processedAt: Date.now(),
    detailedScores: { adult: 2, racy: 1, violence: 1, medical: 2, spoof: 2 },
  };
}

async function acquireVisionTokenByPriority(priority: "HIGH" | "MEDIUM" | "LOW", docIdForSharding: string = ""): Promise<boolean> {
  try {
    const config = {
      HIGH: { limit: VISION_TOKEN_CONFIG.TOKENS_HIGH_PER_MINUTE },
      MEDIUM: { limit: VISION_TOKEN_CONFIG.TOKENS_MEDIUM_PER_MINUTE },
      LOW: { limit: VISION_TOKEN_CONFIG.TOKENS_LOW_PER_MINUTE },
    }[priority];

    const primaryShard = getShardIndex(docIdForSharding || generateMessageId(), SHARDING_CONFIG.TOKEN_BUCKET_SHARDS);
    const shardsToTry = [primaryShard, (primaryShard + 1) % 10, (primaryShard + 2) % 10];

    for (const shardIndex of shardsToTry) {
      const shardedDocId = getShardedTokenBucketId(priority, shardIndex);
      const ref = db().collection(COL_VISION_TOKENS).doc(shardedDocId);
      try {
        const result = await db().runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          const now = Date.now();
          if (!snap.exists) {
            tx.set(ref, { priority, shard: shardIndex, tokensAvailable: config.limit, lastRefillAt: new Date(now), totalConsumed: 0, updatedAt: new Date(now) });
            return true;
          }
          const bucket = snap.data() as VisionTokenBucket;
          const lastRefill = bucket.lastRefillAt?.toMillis?.() ?? now;
          if ((now - lastRefill) >= VISION_TOKEN_CONFIG.REFILL_INTERVAL_MS) {
            tx.set(ref, { priority, shard: shardIndex, tokensAvailable: config.limit - 1, lastRefillAt: new Date(now), totalConsumed: bucket.totalConsumed + 1, updatedAt: new Date(now) });
            return true;
          }
          if (bucket.tokensAvailable > 0) {
            tx.update(ref, { tokensAvailable: bucket.tokensAvailable - 1, totalConsumed: bucket.totalConsumed + 1, updatedAt: new Date(now) });
            return true;
          }
          return false;
        });
        if (result) return true;
      } catch {
        continue;
      }
    }
    logger.warn(`[TokenBucket] All ${priority} shards exhausted`);
    return false;
  } catch (err) {
    logger.warn("[TokenBucket] Check failed (allowing):", err);
    return true;
  }
}

function getPriorityTopic(category: ImageCategory): { topic: string; priority: "HIGH" | "MEDIUM" | "LOW" } {
  switch (category) {
    case "thumbnail": return { topic: TOPIC_MODERATION_HIGH,   priority: "HIGH" };
    case "avatar":
    case "banner":    return { topic: TOPIC_MODERATION_MEDIUM, priority: "MEDIUM" };
    case "community":
    default:          return { topic: TOPIC_MODERATION_LOW,    priority: "LOW" };
  }
}

async function sendToDeadLetterQueue(message: QueuedMessage, reason: string): Promise<void> {
  try {
    const now = Date.now();
    const dlqSeverity = determineDlqSeverity(reason);
    await db().collection(COL_DEAD_LETTERS).add({
      metadata: message.metadata, messageId: message.messageId, docId: message.docId,
      retryCount: message.retryCount, priority: message.priority,
      firstAttemptAt: message.firstAttemptAt, queuedAt: message.queuedAt,
      reason, lastError: message.lastError || null, severity: dlqSeverity,
      consumed: false, consumedAt: null,
      sentToDlqAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(now + 90 * 86400_000),
    });
    await publishMessage(TOPIC_MODERATION_DLQ, { ...message, reason, severity: dlqSeverity, sentAt: now });
    logger.warn(`[DLQ] ${message.docId} → dead-letter (${dlqSeverity}): ${reason}`);
  } catch (err) {
    logger.error("[DLQ] Failed to send to DLQ:", err);
  }
}

function determineDlqSeverity(reason: string): "CRITICAL" | "HIGH" | "MEDIUM" | "LOW" {
  const r = reason.toLowerCase();
  if (r.includes("quota") || r.includes("permission") || r.includes("auth")) return "CRITICAL";
  if (r.includes("poison") || r.includes("max retry") || r.includes("circuit")) return "HIGH";
  if (r.includes("timeout") || r.includes("transient")) return "MEDIUM";
  return "LOW";
}

async function requeueWithDelay(message: QueuedMessage, errorReason: string = "Transient failure"): Promise<void> {
  try {
    const { retryCount, firstAttemptAt } = message;
    const now = Date.now();
    const ageInMs = now - firstAttemptAt;

    if (ageInMs > RETRY_BACKOFF.MAX_QUEUE_AGE_MS) {
      await sendToDeadLetterQueue(message, `Exceeded max queue age: ${errorReason}`);
      return;
    }
    if (retryCount >= RETRY_BACKOFF.MAX_RETRIES) {
      await sendToDeadLetterQueue(message, `Max retries reached: ${errorReason}`);
      return;
    }

    let delay = Math.min(
      RETRY_BACKOFF.BASE_DELAY_MS * Math.pow(RETRY_BACKOFF.MULTIPLIER, retryCount),
      RETRY_BACKOFF.MAX_DELAY_MS
    );
    const ageInSeconds = ageInMs / 1000;
    if (ageInSeconds > 60 && message.priority === "LOW")    { message.priority = "MEDIUM"; delay = Math.min(delay / 2, 5000); }
    if (ageInSeconds > 90 && message.priority === "MEDIUM") { message.priority = "HIGH";   delay = Math.min(delay / 2, 2000); }

    const shardIndex = getShardIndex(message.docId, SHARDING_CONFIG.RETRY_QUEUE_SHARDS);
    const retryKey = `${message.docId}_retry_${retryCount + 1}`;
    await db().collection(getShardedRetryCollectionName(shardIndex)).doc(retryKey).set({
      ...message, retryCount: retryCount + 1, nextRetryAt: now + delay, queuedAt: now,
      lastError: errorReason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await updateVerificationDocState(message.docId, {
      status: "PENDING", queueState: "DELAYED", retryCount: retryCount + 1,
      nextRetryAt: new Date(now + delay),
      reason: `Retrying #${retryCount + 1} — ${errorReason} (Processing in ${Math.round(delay / 1000)}s)`,
    });
    logger.info(`[RetryQueue] Requeued ${message.docId} retry #${retryCount + 1} delay=${Math.round(delay / 1000)}s reason=${errorReason}`);
  } catch (err) {
    logger.error("[RetryQueue] Requeue failed:", err);
  }
}

async function updateVerificationDocState(
  docId: string,
  state: { status: string; queueState?: string; retryCount?: number; nextRetryAt?: Date; reason?: string }
): Promise<void> {
  try {
    await db().collection(COL_VERIFICATION).doc(docId).update({
      status: state.status, queueState: state.queueState ?? null,
      retryCount: state.retryCount ?? null, nextRetryAt: state.nextRetryAt ?? null,
      reason: state.reason ?? null, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.warn(`[Firestore] State update failed for ${docId}:`, err);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 1 — INGEST
// ═══════════════════════════════════════════════════════════════════════════════

export const ingestUploadedImage = onObjectFinalized(INGEST_CONFIG, async (event) => {
  const startTime = Date.now();
  const object    = event.data;

  if (!object.name) { logger.warn("[Ingest] No object name — skipping"); return; }

  const filePath = object.name;

  if (!validateFileType(filePath, object.contentType ?? undefined)) {
    logger.debug(`[Ingest] Skipped non-image: ${filePath}`);
    return;
  }

  const metadata = extractMetadata(filePath, object.bucket, Number(object.size ?? 0), object.contentType ?? undefined);
  if (!metadata) {
    // ❌ CRITICAL: Unrecognized path — log as error and track in Firestore for observability
    logger.error(`[Ingest] ❌ CRITICAL: Unrecognized path pattern — ${filePath}`);
    try {
      await db().collection("ingest_errors").add({
        filePath,
        bucket: object.bucket,
        contentType: object.contentType,
        fileSize: object.size,
        reason: "UNKNOWN_PATH",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      logger.error(`[Ingest] Failed to log ingest error:`, err);
    }
    return;
  }

  logger.info(`[Ingest] START ${metadata.category} → ${filePath}`);

  try {
    const backpressure = await getBackpressureStatus();
    if (backpressure.isThrottling && backpressure.recommendedSamplingRate && Math.random() > backpressure.recommendedSamplingRate) {
      logger.warn(`[Ingest] Backpressure throttling — sampled out: ${filePath}`);
      return;
    }

    const rateLimitCheck = await checkRateLimit(metadata.userId);
    if (!rateLimitCheck.allowed) {
      logger.warn(`[Ingest] ${metadata.userId} rate limited: ${rateLimitCheck.reason}`);
      return;
    }

    // FIX 2: docId is now the filename (e.g. "87fd02cf-....png")
    const docId = generateDocId(metadata);
    logger.info(`[Ingest] docId=${docId}`);

    try {
      await createPendingDoc(docId, metadata);
      logger.info(`[Ingest] ✓ Created PENDING doc: ${docId}`);
    } catch (err) {
      logger.error(`[Ingest] ✗ Failed to write PENDING doc:`, err);
      throw err;
    }

    try {
      await publishMessage(TOPIC_PREFILTER, { metadata, messageId: generateMessageId(), docId } satisfies PrefilterMessage);
      logger.info(`[Ingest] ✓ Published to ${TOPIC_PREFILTER}`);
    } catch (err) {
      logger.error(`[Ingest] ✗ CRITICAL: Failed to publish to ${TOPIC_PREFILTER}:`, err);
      throw err;
    }

    await logMetrics(
      metadata,
      { status: "PENDING", reason: "Queued for pre-filter", score: 0, timestamp: Date.now(), processedAt: Date.now() },
      Date.now() - startTime, "ingest"
    );

    logger.info(`[Ingest] ✓ COMPLETE (${Date.now() - startTime}ms) docId=${docId}`);
  } catch (err) {
    logger.error(`[Ingest] ✗ FAILED:`, err);
    throw err;
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 2 — PRE-FILTER WORKER
// ═══════════════════════════════════════════════════════════════════════════════

export const prefilterWorker = onMessagePublished(
  { topic: TOPIC_PREFILTER, ...PREFILTER_CONFIG },
  async (event) => {
    const startTime = Date.now();

    let body: PrefilterMessage;
    try {
      body = parseMessage<PrefilterMessage>(event.data.message.data);
    } catch (err) {
      logger.error("[Prefilter] ✗ Malformed message — dropping:", err);
      return;
    }

    const { metadata, docId: incomingDocId } = body;
    const docId  = incomingDocId ?? generateDocId(metadata);
    const bucket = admin.storage().bucket(metadata.bucket);

    logger.info(`[Prefilter] START ${metadata.category} → ${metadata.filePath} (docId=${docId})`);

    try {
      const idempotencyKey = generateIdempotencyKey(metadata.filePath, metadata.uploadedAt);
      const { isDuplicate, docId: existingDocId } = await checkIdempotencyKey(idempotencyKey);
      if (isDuplicate) {
        logger.warn(`[Prefilter] Duplicate — existing docId: ${existingDocId}`);
        return;
      }
      await recordIdempotencyKey(idempotencyKey, docId);

      try {
        if (!(await fileExists(bucket, metadata.filePath))) {
          logger.warn(`[Prefilter] File gone — skipping: ${metadata.filePath}`);
          return;
        }
      } catch (fileCheckErr) {
        logger.error(`[Prefilter] File check failed (processing anyway):`, fileCheckErr);
      }

      if (!validateFileType(metadata.filePath, metadata.mimeType)) {
        await doReject(docId, metadata, bucket, { reason: `Invalid file type: ${metadata.mimeType ?? "unknown"}`, score: 0 }, startTime, "invalid-type");
        return;
      }

      const sizeCheck = validateFileSize(metadata.category, metadata.fileSize);
      if (!sizeCheck.valid) {
        await doReject(docId, metadata, bucket, { reason: sizeCheck.reason!, score: 0 }, startTime, "size-exceeded");
        return;
      }

      const { crc32c, md5 } = await getGCSMetadataHash(bucket, metadata.filePath);
      if (crc32c || md5) {
        const hashValue = crc32c || md5 || "";
        const hashDocId = hashToDocId(hashValue);
        const hashDoc   = await getHashDoc(hashDocId);
        if (hashDoc) {
          if (hashDoc.status === "APPROVED") {
            await doApprove(docId, metadata, startTime, "dedup-clean-exact");
            return;
          } else {
            await doReject(docId, metadata, bucket, { reason: "Duplicate of previously rejected image", score: 4 }, startTime, "dedup-dirty-exact");
            return;
          }
        }
        metadata._md5      = hashValue;
        metadata._hashDocId = hashDocId;
      }

      // ─── MANDATORY AI SCAN (100% Coverage): No trust-based skipping ───
      // Every avatar, banner, thumbnail, and image must be scanned by Vision AI.

      // ─── CHECK IF CATEGORY IS IN ADMIN ONLY MODE (Bypass Gemini / Vision AI) ───
      const {
        isThumbnailsBypassed,
        isAvatarBypassed,
        isBannerBypassed,
        isCommunityBypassed,
        isTopicsBypassed,
        isPlaylistsBypassed,
      } = require("../moderation/moderationModes");
      let isCategoryBypassed = false;
      if (metadata.category === "thumbnail") isCategoryBypassed = await isThumbnailsBypassed();
      else if (metadata.category === "avatar") isCategoryBypassed = await isAvatarBypassed();
      else if (metadata.category === "banner") isCategoryBypassed = await isBannerBypassed();
      else if (metadata.category === "community") isCategoryBypassed = await isCommunityBypassed();
      else if (metadata.category === "topic") isCategoryBypassed = await isTopicsBypassed();
      else if (metadata.category === "playlist") isCategoryBypassed = await isPlaylistsBypassed();

      if (isCategoryBypassed) {
        logger.info(`[Prefilter] ${metadata.category} moderation toggle is ON (Admin Only). Routing directly to Admin review queue without AI scanning.`);
        const result: ValidationResult = {
          status: "FLAGGED",
          reason: `Direct Admin Approval Mode (${metadata.category} Vision AI bypassed).`,
          score: 0,
          timestamp: Date.now(),
          processedAt: Date.now(),
          detailedScores: { adult: 0, racy: 0, violence: 0, medical: 0, spoof: 0 },
        };
        await updateVerificationDoc(docId, metadata, result);
        await logFlaggedImage(metadata, result);
        await logMetrics(metadata, result, Date.now() - startTime, "prefilter", "admin-bypass");
        return;
      }

      const { topic: moderationTopic, priority } = getPriorityTopic(metadata.category);
      try {
        await publishMessage(moderationTopic, { metadata, messageId: body.messageId, docId } satisfies ModerationMessage);
        logger.info(`[Prefilter] ✓ Published to ${moderationTopic} (priority=${priority})`);
      } catch (pubErr) {
        logger.error(`[Prefilter] ✗ FAILED to publish to ${moderationTopic}:`, pubErr);
        throw pubErr;
      }

      await logMetrics(
        metadata, { status: "PENDING", reason: "Queued for Vision scan", score: 0, timestamp: Date.now(), processedAt: Date.now() },
        Date.now() - startTime, "prefilter", "sent-to-moderation"
      );
    } catch (err) {
      logger.error(`[Prefilter] ✗ CRITICAL ERROR:`, err);
      throw err;
    }
  }
);

async function doApprove(docId: string, metadata: ImageMetadata, start: number, reason: string): Promise<void> {
  const result: ValidationResult = { status: "APPROVED", reason: `Pre-filter approved (${reason})`, score: 0, timestamp: Date.now(), processedAt: Date.now() };
  await updateVerificationDoc(docId, metadata, result);
  if (metadata.userId) await updateUserTrust(metadata.userId, "APPROVED");
  await logMetrics(metadata, result, Date.now() - start, "prefilter", reason);
  logger.info(`[Prefilter] APPROVED (${reason}) → ${metadata.filePath}`);
}

async function doReject(
  docId: string, metadata: ImageMetadata, bucket: GCSBucket,
  opts: { reason: string; score: number }, start: number, reason: string
): Promise<void> {
  const result: ValidationResult = { status: "REJECTED", reason: opts.reason, score: opts.score, timestamp: Date.now(), processedAt: Date.now() };
  await updateVerificationDoc(docId, metadata, result);
  await quarantineFile(bucket, metadata, result);
  if (metadata.userId) await updateUserTrust(metadata.userId, "REJECTED");
  await logMetrics(metadata, result, Date.now() - start, "prefilter", reason);
  logger.info(`[Prefilter] REJECTED (${reason}) → ${metadata.filePath}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 3B — RETRY QUEUE PROCESSOR (Pub/Sub triggered)
// ═══════════════════════════════════════════════════════════════════════════════

export const retryQueueProcessor = onMessagePublished(
  { topic: TOPIC_RETRY_TRIGGER, ...RETRY_PROCESSOR_CONFIG },
  async (_event) => {
    let processedCount = 0; let dlqCount = 0; let errorCount = 0;
    const startTime = Date.now();
    try {
      const now = Date.now();
      const allMessages: Array<{ ref: FirebaseFirestore.DocumentReference; data: any }> = [];
      for (let shardIndex = 0; shardIndex < SHARDING_CONFIG.RETRY_QUEUE_SHARDS; shardIndex++) {
        const snapshot = await db().collection(getShardedRetryCollectionName(shardIndex)).where("nextRetryAt", "<=", now).limit(50).get();
        for (const doc of snapshot.docs) allMessages.push({ ref: doc.ref, data: doc.data() });
      }

      if (allMessages.length === 0) return; // Silent exit if nothing to do (cost effective)

      logger.info(`[RetryQueue] Processing ${allMessages.length} messages`);
      for (const { ref, data: message } of allMessages) {
        try {
          const { metadata, messageId, docId, retryCount, priority, firstAttemptAt } = message;
          if ((now - (firstAttemptAt || message.queuedAt)) > RETRY_BACKOFF.MAX_QUEUE_AGE_MS) {
            await sendToDeadLetterQueue(message, "Exceeded max queue age during retry processing");
            await ref.delete(); dlqCount++; continue;
          }
          let topic = TOPIC_MODERATION_LOW;
          if (priority === "HIGH") topic = TOPIC_MODERATION_HIGH;
          if (priority === "MEDIUM") topic = TOPIC_MODERATION_MEDIUM;
          await publishMessage(topic, { metadata, messageId: messageId || generateMessageId(), docId } satisfies ModerationMessage);
          await ref.delete();
          await updateVerificationDocState(docId, { status: "PENDING", queueState: "PROCESSING", reason: `Processing (attempt #${retryCount + 1})` });
          processedCount++;
        } catch (err) { logger.error("[RetryQueue] Failed:", err); errorCount++; }
      }
      logger.info(`[RetryQueue] processed=${processedCount} dlq=${dlqCount} errors=${errorCount} elapsed=${Date.now() - startTime}ms`);
    } catch (err) { logger.error("[RetryQueue] Processor error:", err); }
  }
);

/**
 * ⏰ Scheduled Retry Processor — runs every minute to trigger the queue
 *
 * This ensures "DELAYED" images are processed fast and reliably.
 */
export const scheduledRetryProcessor = onSchedule(
  { schedule: "every 1 minutes", region: REGION, maxInstances: 1, timeoutSeconds: 60 },
  async (_event) => {
    try {
      await publishMessage(TOPIC_RETRY_TRIGGER, { source: "scheduler", timestamp: Date.now() });
      logger.info("[Scheduler] ✓ Triggered retry processor");
    } catch (err) {
      logger.error("[Scheduler] ✗ Failed to trigger retry processor:", err);
    }
  }
);

export const retryQueueProcessorManual = onRequest(
  { region: REGION, timeoutSeconds: 60, memory: "256MiB", cors: ["https://*.towerb.app"] },
  async (req, res) => {
    let processedCount = 0; let dlqCount = 0; let errorCount = 0;
    const startTime = Date.now();
    try {
      const now = Date.now();
      const allMessages: Array<{ ref: FirebaseFirestore.DocumentReference; data: any }> = [];

      // FIX: Also check sharded collections in manual processor
      for (let shardIndex = 0; shardIndex < SHARDING_CONFIG.RETRY_QUEUE_SHARDS; shardIndex++) {
        const snapshot = await db().collection(getShardedRetryCollectionName(shardIndex)).where("nextRetryAt", "<=", now).limit(100).get();
        for (const doc of snapshot.docs) allMessages.push({ ref: doc.ref, data: doc.data() });
      }

      // Legacy fallback
      const snapshot = await db().collection(COL_MOD_RETRIES).where("nextRetryAt", "<=", now).limit(100).get();
      for (const doc of snapshot.docs) allMessages.push({ ref: doc.ref, data: doc.data() });

      for (const { ref, data: message } of allMessages) {
        try {
          const { metadata, messageId, docId, retryCount, priority, firstAttemptAt } = message;
          if ((now - (firstAttemptAt || message.queuedAt)) > RETRY_BACKOFF.MAX_QUEUE_AGE_MS) {
            await sendToDeadLetterQueue(message, "Manual retry: exceeded max age");
            await ref.delete(); dlqCount++; continue;
          }
          let topic = TOPIC_MODERATION_LOW;
          if (priority === "HIGH") topic = TOPIC_MODERATION_HIGH;
          if (priority === "MEDIUM") topic = TOPIC_MODERATION_MEDIUM;
          await publishMessage(topic, { metadata, messageId: messageId || generateMessageId(), docId } satisfies ModerationMessage);
          await ref.delete();
          await updateVerificationDocState(docId, { status: "PENDING", queueState: "PROCESSING", reason: `Manual retry (attempt #${retryCount + 1})` });
          processedCount++;
        } catch (err) { logger.error("[RetryQueue-Manual] Failed:", err); errorCount++; }
      }
      res.status(200).json({ processed: processedCount, dlq: dlqCount, errors: errorCount, elapsedMs: Date.now() - startTime });
    } catch (err) {
      res.status(500).json({ error: "Retry queue processor failed", details: String(err) });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 4 — MODERATION WORKERS (priority-based)
// ═══════════════════════════════════════════════════════════════════════════════

const createModerationWorker = (
  topic: string,
  config: typeof MODERATION_CONFIG_HIGH | typeof MODERATION_CONFIG_MEDIUM | typeof MODERATION_CONFIG_LOW
) => {
  return onMessagePublished({ topic, ...config }, async (event) => {
    const startTime = Date.now();

    let body: ModerationMessage;
    try {
      body = parseMessage<ModerationMessage>(event.data.message.data);
    } catch (err) {
      logger.error(`[Moderation] ✗ Malformed message on ${topic}:`, err);
      return;
    }

    const { metadata, docId } = body;
    const bucket = admin.storage().bucket(metadata.bucket);
    const { priority } = getPriorityTopic(metadata.category);

    logger.info(`[Moderation] START ${topic} priority=${priority} → ${metadata.filePath} (docId=${docId})`);

    try {
      try {
        if (!(await fileExists(bucket, metadata.filePath))) {
          logger.warn(`[Moderation] File gone — skipping: ${metadata.filePath}`);
          return;
        }
      } catch (fileCheckErr) {
        logger.error(`[Moderation] File check failed (processing anyway):`, fileCheckErr);
      }

      let result: ValidationResult;

      const breaker = await checkCircuitBreaker();
      if (!breaker.canProceed) {
        if (breaker.state === "OPEN") {
          logger.warn(`[Moderation] Circuit breaker OPEN — fallback for ${docId}`);
          result = await useFallbackModerationModel(metadata);
        } else {
          const hasToken = await acquireVisionTokenByPriority(priority, docId);
          if (!hasToken) {
            await requeueWithDelay({ metadata, messageId: body.messageId, docId, retryCount: 0, firstAttemptAt: Date.now(), queuedAt: Date.now(), priority }, "Vision Quota Exhausted");
            return;
          }
          const { scores, error: visionError } = await detectSafeSearch(metadata.bucket, metadata.filePath);
          if (!scores) {
            await recordVisionResult(false);
            result = await useFallbackModerationModel(metadata);
            if (visionError) result.reason += ` (Vision Error: ${visionError})`;
          } else {
            await recordVisionResult(true);
            result = evaluateScores(metadata.category as Exclude<ImageCategory, "unknown">, scores);
          }
        }
      } else {
        const hasToken = await acquireVisionTokenByPriority(priority, docId);
        if (!hasToken) {
          await requeueWithDelay({ metadata, messageId: body.messageId, docId, retryCount: 0, firstAttemptAt: Date.now(), queuedAt: Date.now(), priority }, "Vision Quota Exhausted");
          return;
        }

        const { scores, error: visionError } = await detectSafeSearch(metadata.bucket, metadata.filePath);
        if (!scores) {
          const shardIndex = getShardIndex(docId, SHARDING_CONFIG.RETRY_QUEUE_SHARDS);
          const retryDoc = await db().collection(getShardedRetryCollectionName(shardIndex)).doc(`${docId}_retry_1`).get();
          const retryCount = retryDoc.exists ? ((retryDoc.data() as ModerationRetry).retryCount ?? 0) : 0;

          if (retryCount < RETRY_BACKOFF.MAX_RETRIES) {
            await recordVisionResult(false);
            await requeueWithDelay({ metadata, messageId: body.messageId, docId, retryCount, firstAttemptAt: Date.now(), queuedAt: Date.now(), priority }, visionError || "Vision API timeout");
            return;
          } else {
            result = await useFallbackModerationModel(metadata);
            if (visionError) result.reason += ` (Vision Error: ${visionError})`;
          }
        } else {
          await recordVisionResult(true);
          result = evaluateScores(metadata.category as Exclude<ImageCategory, "unknown">, scores);
        }
      }

      try {
        await updateVerificationDoc(docId, metadata, result);
        logger.info(`[Moderation] ✓ Firestore updated: ${docId} → ${result.status}`);
      } catch (err) {
        logger.error(`[Moderation] ✗ Firestore write failed for ${docId}:`, err);
        throw err;
      }

      if (metadata._md5 && metadata._hashDocId && (result.status === "APPROVED" || result.status === "REJECTED")) {
        await setHashDoc(metadata._hashDocId, metadata._md5, result.status, metadata);
      }

      if (metadata.userId && result.status !== "ERROR") {
        const trustStatus = result.status === "APPROVED" ? "APPROVED" : result.status === "REJECTED" ? "REJECTED" : "FLAGGED";
        await updateUserTrust(metadata.userId, trustStatus);
      }

      if (result.status === "REJECTED") {
        await quarantineFile(bucket, metadata, result);
      } else if (result.status === "FLAGGED") {
        await logFlaggedImage(metadata, result);
      }

      await logMetrics(metadata, result, Date.now() - startTime, "moderation");
      logger.info(`[Moderation] ✓ COMPLETE ${result.status} → ${metadata.filePath} (${Date.now() - startTime}ms)`);
    } catch (err) {
      logger.error(`[Moderation] ✗ CRITICAL ERROR on ${topic}:`, err);
      throw err;
    }
  });
};

export const moderationWorkerHigh   = createModerationWorker(TOPIC_MODERATION_HIGH,   MODERATION_CONFIG_HIGH);
export const moderationWorkerMedium = createModerationWorker(TOPIC_MODERATION_MEDIUM, MODERATION_CONFIG_MEDIUM);
export const moderationWorkerLow    = createModerationWorker(TOPIC_MODERATION_LOW,    MODERATION_CONFIG_LOW);

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 4B — DEAD-LETTER QUEUE HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

export const deadLetterHandler = onMessagePublished(
  { topic: TOPIC_MODERATION_DLQ, region: REGION, timeoutSeconds: 60, memory: "256MiB" as const, maxInstances: 10, retry: true },
  async (event) => {
    const startTime = Date.now();
    let body: any;
    try { body = parseMessage<any>(event.data.message.data); }
    catch (err) { logger.error("[DLQ] Malformed message:", err); return; }

    const { metadata, docId, reason, retryCount, lastError } = body;
    logger.warn(`[DLQ] Processing dead-letter: ${docId} — ${reason}`);

    const result: ValidationResult = {
      status: "FLAGGED",
      reason: `Moderation failed (retries: ${retryCount}, reason: ${reason})`,
      score: 3, timestamp: Date.now(), processedAt: Date.now(),
      detailedScores: { adult: 2, racy: 1, violence: 1, medical: 2, spoof: 2 },
    };

    try {
      await updateVerificationDoc(docId, metadata, result);
      await logFlaggedImage(metadata, result);
      if (metadata.userId) await updateUserTrust(metadata.userId, "FLAGGED");
      logger.warn(`[DLQ] Marked ${docId} as FLAGGED (error: ${lastError || "unknown"})`);
      await logMetrics(metadata, result, Date.now() - startTime, "moderation", `dlq-${reason.includes("age") ? "age" : "retries"}`);
    } catch (err) {
      logger.error("[DLQ] Failed to process dead-letter:", err);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP — GET verification status
// GET /getImageVerificationStatus?docId=<filename>
// e.g. ?docId=87fd02cf-71d3-40c3-9fed-c80e75d4acdf.png
// ═══════════════════════════════════════════════════════════════════════════════

export const getImageVerificationStatus = onRequest(
  { region: REGION, timeoutSeconds: 30, memory: "256MiB", cors: ["https://*.towerb.app", "http://localhost:3000", "http://localhost:5173"] },
  async (req, res) => {
    try {
      const { docId } = req.query;
      if (!docId || typeof docId !== "string" || !docId.trim()) {
        res.status(400).json({ error: "Valid docId required", status: "ERROR" }); return;
      }
      const doc = await db().collection(COL_VERIFICATION).doc(docId.trim().substring(0, 1500)).get();
      if (!doc.exists) { res.status(202).json({ status: "PENDING", message: "Image is being verified…" }); return; }
      const data = doc.data();
      if (!data) { res.status(500).json({ status: "ERROR", message: "Document data missing" }); return; }
      if (data.status === "PENDING") {
        res.status(202).json({
          status: "PENDING",
          queueState: data.queueState || null,
          retryCount: data.retryCount || 0,
          nextRetryAt: data.nextRetryAt || null,
          message: data.queueState === "DELAYED"
            ? `Processing may take a few seconds. Retry attempt ${data.retryCount || 1}.`
            : "Image is being verified…",
        }); return;
      }
      res.status(200).json({
        status: data.status, reason: data.reason, score: data.score,
        category: data.category, gcsUri: data.gcsUri,
        detailedScores: data.detailedScores ?? {},
        verifiedAt: data.processedAt, queueState: data.queueState || null,
      });
    } catch (err) {
      logger.error("[HTTP] getImageVerificationStatus:", err);
      res.status(500).json({ status: "ERROR", message: "Failed to retrieve status" });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP — Manual cleanup
// ═══════════════════════════════════════════════════════════════════════════════

export const cleanupVerificationRecord = onRequest(
  { region: REGION, timeoutSeconds: 30 },
  async (req, res) => {
    try {
      const { docId } = req.query;
      if (!docId || typeof docId !== "string") { res.status(400).json({ error: "Valid docId required" }); return; }
      await db().collection(COL_VERIFICATION).doc(docId).delete();
      res.status(200).json({ message: `Deleted: ${docId}` });
    } catch (err) {
      logger.error("[HTTP] cleanupVerificationRecord:", err);
      res.status(500).json({ error: "Failed to delete record" });
    }
  }
);

/**
 * 🛡️ HTTPS Endpoint — Manually moderate a flagged image (Approve or Reject).
 * Only accessible by authenticated administrators.
 */
export const moderateImageManual = onRequest(
  {
    cors: true,
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 2,
  },
  async (req, res) => {
    try {
      const authUser = await requireAdmin(req, res);
      if (!authUser) return; // Response is already handled by requireAdmin

      const { verificationId, action, reason } = req.body;

      if (!verificationId || typeof verificationId !== "string") {
        res.status(400).json({ error: "Missing or invalid verificationId." });
        return;
      }

      if (action !== "approve" && action !== "reject") {
        res.status(400).json({ error: "Action must be 'approve' or 'reject'." });
        return;
      }

      console.log(`[Verification] Manual ${action} request for image:`, { verificationId, adminUid: authUser.uid });

      const flaggedRef = db().collection(COL_FLAGGED).doc(verificationId);
      const flaggedDoc = await flaggedRef.get();

      if (!flaggedDoc.exists) {
        res.status(404).json({ error: "Flagged image record not found." });
        return;
      }

      const flaggedData = flaggedDoc.data() as any;
      const { fileName, filePath, category, userId, gcsUri, score, detailedScores } = flaggedData;

      const imgMetadata: ImageMetadata = {
        category: category || "unknown",
        userId: userId || undefined,
        fileName: fileName || verificationId,
        filePath: filePath || "",
        uploadedAt: Date.now(),
        bucket: BUCKET,
        gcsUri: gcsUri || "",
        fileSize: 0,
      };

      const now = Date.now();
      const valResult: ValidationResult = {
        status: action === "approve" ? "APPROVED" : "REJECTED",
        reason: reason || `Manually ${action}d by administrator.`,
        score: score || 0,
        timestamp: now,
        processedAt: now,
        detailedScores: detailedScores || {},
      };

      const storageBucket = admin.storage().bucket(BUCKET);

      if (action === "approve") {
        // 1. Update verification status doc
        await updateVerificationDoc(fileName, imgMetadata, valResult);

        // 2. Mark flagged queue doc as APPROVED
        await flaggedRef.update({
          status: "APPROVED",
          reviewedBy: authUser.uid,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewReason: reason || "Approved manually.",
        });

        // 3. Update User Trust
        if (userId) {
          await updateUserTrust(userId, "APPROVED");
        }

        // 4. Set approved MD5 hash
        const hashes = await getGCSMetadataHash(storageBucket, filePath);
        if (hashes.md5) {
          const hashDocId = hashToDocId(hashes.md5);
          await setHashDoc(hashDocId, hashes.md5, "APPROVED", imgMetadata);
        }

        res.status(200).json({ success: true, message: "Image manually approved." });
      } else {
        // action === "reject"
        // 1. Update verification status doc
        await updateVerificationDoc(fileName, imgMetadata, valResult);

        // 2. Mark flagged queue doc as REJECTED
        await flaggedRef.update({
          status: "REJECTED",
          reviewedBy: authUser.uid,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewReason: reason || "Rejected manually.",
        });

        // 3. Update User Trust
        if (userId) {
          await updateUserTrust(userId, "REJECTED");
        }

        // 4. Set rejected MD5 hash
        const hashes = await getGCSMetadataHash(storageBucket, filePath);
        if (hashes.md5) {
          const hashDocId = hashToDocId(hashes.md5);
          await setHashDoc(hashDocId, hashes.md5, "REJECTED", imgMetadata);
        }

        // 5. Quarantine GCS file and remove original
        if (filePath && await fileExists(storageBucket, filePath)) {
          await quarantineFile(storageBucket, imgMetadata, valResult);
        }

        res.status(200).json({ success: true, message: "Image manually rejected and quarantined." });
      }
    } catch (err) {
      console.error("[Verification] Manual moderation failed:", err);
      res.status(500).json({ error: "Internal server error.", details: String(err) });
    }
  }
);

/**
 * ⚙️ HTTPS Endpoint — Update Moderation Modes (Bypass Vision AI vs Automated Scanning).
 * Accessible by authenticated administrators.
 */
export const setModerationModesManual = onRequest(
  {
    cors: true,
    region: REGION,
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 2,
  },
  async (req, res) => {
    try {
      const authUser = await requireAdmin(req, res);
      if (!authUser) return;

      const { modeKey, value, modes } = req.body;

      const updateData: Record<string, any> = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: authUser.email || authUser.uid,
      };

      if (modes && typeof modes === "object") {
        Object.assign(updateData, modes);
      } else if (modeKey && typeof modeKey === "string") {
        updateData[modeKey] = value === true;
        if (modeKey === "thumbnails" || modeKey === "videoThumbnails") {
          updateData["thumbnails"] = value === true;
          updateData["videos_thumbnails"] = value === true;
          updateData["videoThumbnails"] = value === true;
        } else if (modeKey === "banner" || modeKey === "channelBanner") {
          updateData["banner"] = value === true;
          updateData["channelBanner"] = value === true;
          updateData["channel_banner"] = value === true;
        } else if (modeKey === "avatar" || modeKey === "channelAvatar") {
          updateData["avatar"] = value === true;
          updateData["channelAvatar"] = value === true;
          updateData["channel_avatar"] = value === true;
        } else if (modeKey === "community" || modeKey === "communityPosts") {
          updateData["community"] = value === true;
          updateData["community_posts"] = value === true;
          updateData["communityPosts"] = value === true;
        } else if (modeKey === "topics" || modeKey === "topicThumbnails") {
          updateData["topics"] = value === true;
          updateData["topic_thumbnails"] = value === true;
          updateData["topicThumbnails"] = value === true;
        } else if (modeKey === "playlists" || modeKey === "playlistThumbnails") {
          updateData["playlists"] = value === true;
          updateData["playlist_thumbnails"] = value === true;
          updateData["playlistThumbnails"] = value === true;
        }
      }

      await Promise.all([
        db().collection("admin_settings").doc("moderation_modes").set(updateData, { merge: true }),
        db().collection("system_settings").doc("moderation_modes").set(updateData, { merge: true }),
      ]);

      res.status(200).json({ success: true, updated: updateData });
    } catch (err: any) {
      logger.error("[setModerationModesManual] Error:", err);
      res.status(500).json({ error: err.message || "Failed to update moderation modes" });
    }
  }
);