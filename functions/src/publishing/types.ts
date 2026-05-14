/**
 * 📋 SCHEDULED PUBLISHING — TYPE DEFINITIONS
 *
 * Centralized types for the scheduled publishing module
 */

import * as admin from "firebase-admin";

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO & PUBLISHING TYPES
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Scheduled Video Document Structure
 */
export interface ScheduledVideo {
  /** Unique video identifier */
  id: string;

  /** Video title */
  title: string;

  /** Video description */
  description: string;

  /** Owner/creator user ID */
  ownerId: string;

  /** Channel ID where video belongs */
  channelId: string;

  /** Channel name */
  channelName: string;

  /** When to publish the video (Firestore Timestamp) */
  scheduledTime: admin.firestore.Timestamp;

  /** Current status: 'scheduled' | 'published' | 'failed' */
  status: "scheduled" | "published" | "failed" | "uploading";

  /** When the video was uploaded */
  uploadedAt: admin.firestore.Timestamp;

  /** When the video was actually published (if applicable) */
  publishedAt?: admin.firestore.Timestamp;

  /** AI processing features (triggers pipeline on publish) */
  aiFeatures?: AIFeaturesMap;

  /** Video URL in storage */
  videoUrl: string;

  /** Thumbnail URL */
  thumbnailUrl: string;

  /** Video category */
  category: string;

  /** Video tags */
  tags: string[];

  /** Languages for translation */
  translationLanguages: string[];

  /** Whether to allow comments */
  enableComments?: boolean;

  /** Whether to allow ratings */
  allowRatings?: boolean;

  /** Video visibility: 'Public' | 'Private' | 'Unlisted' | 'Scheduled' */
  visibility: string;

  /** Whether video is kid-friendly */
  isKidFriendly?: boolean;

  /** Whether this is a short-form video */
  isShort?: boolean;

  /** If admin manually published this before scheduled time */
  manualPublishBy?: string;
}

/**
 * AI Features Configuration (Stage 1 & 2 Processing)
 */
export interface AIFeaturesMap {
  // Stage 1: Upload (Cheap compute)
  transcript: boolean;
  draftTranscription: boolean;
  speakerCount: string; // '2' | '3' | '4' | 'not_sure'
  mediaProbe: boolean;
  thumbnailGen: boolean;

  // Stage 2: Publish (Expensive AI)
  factChecking: boolean;
  finalTranscription: boolean;
  genLangSubs: boolean;
  generateDubbing: boolean;
  translationLanguages: string[];
  tts?: {
    enabled: boolean;
    voiceType: "standard" | "voice_clone";
  };
  diarization: boolean;
  summary: boolean;

  // Pipeline state
  pipelineStage: "draft" | "published";
}

// ─────────────────────────────────────────────────────────────────────────────
// OPERATION RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Result of publishing a single video
 */
export interface PublishResult {
  /** Whether the publish was successful */
  success: boolean;

  /** The video ID that was processed */
  videoId: string;

  /** Error message if failed */
  error?: string;

  /** When this operation occurred */
  timestamp?: Date;
}

/**
 * Summary of a scheduled publishing execution
 */
export interface ExecutionSummary {
  /** Unique execution ID from Pub/Sub */
  executionId: string;

  /** When the execution started */
  timestamp: string;

  /** How many videos were found due for publishing */
  videosFound: number;

  /** How many were successfully published */
  videosPublished: number;

  /** How long execution took (milliseconds) */
  executionTimeMs: number;

  /** Throughput: videos per second */
  videosPerSecond: number;

  /** Overall status */
  status: "success" | "error";
}

/**
 * Detailed result of manual trigger endpoint
 */
export interface ManualTriggerResponse {
  /** Operation status */
  status: "success" | "error";

  /** Message from the operation */
  message?: string;

  /** Error message if failed */
  error?: string;

  /** The Pub/Sub message ID that was published */
  messageId?: string;

  /** When the trigger was sent */
  timestamp?: string;
}

/**
 * Response from get scheduled videos endpoint
 */
export interface ScheduledVideosResponse {
  /** Operation status */
  status: "success" | "error";

  /** Summary counts */
  summary?: {
    total: number;
    due: number;
    upcoming: number;
  };

  /** Videos that are due for publishing right now */
  due?: Array<{
    id: string;
    title: string;
    ownerId: string;
    scheduledTime: string;
    isDue: boolean;
    createdAt?: string;
  }>;

  /** Videos scheduled for future publishing */
  upcoming?: Array<{
    id: string;
    title: string;
    ownerId: string;
    scheduledTime: string;
    isDue: boolean;
    createdAt?: string;
  }>;

  /** Error message if failed */
  error?: string;
}

/**
 * Response from publish single video endpoint
 */
export interface PublishSingleResponse {
  /** Operation status */
  status: "success" | "error";

  /** The video ID */
  videoId?: string;

  /** Previous status before publishing */
  previousStatus?: string;

  /** New status after publishing */
  newStatus?: string;

  /** Message describing the result */
  message?: string;

  /** Error message if failed */
  error?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGGING TYPES
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Structured log entry for monitoring
 */
export interface LogEntry {
  /** Function name */
  functionName: string;

  /** Execution or request ID for tracing */
  executionId?: string;

  /** Log level */
  level: "debug" | "info" | "warn" | "error";

  /** Log message */
  message: string;

  /** Additional metadata */
  metadata?: Record<string, any>;

  /** When the log was created */
  timestamp: Date;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION TYPES
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Configuration for scheduled publishing function
 */
export interface ScheduledPublishingConfig {
  /** Batch size for Firestore writes (max 500) */
  batchSize: number;

  /** Maximum clock skew allowed (milliseconds) */
  maxClockSkewMs: number;

  /** Maximum number of videos to process in one execution */
  maxVideosPerExecution: number;

  /** Whether to dry-run (don't actually update) */
  dryRun: boolean;

  /** Enable detailed logging */
  verboseLogging: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT VALUES
// ─────────────────────────────────────────────────────────────────────────────

export const DEFAULT_CONFIG: ScheduledPublishingConfig = {
  batchSize: 100,
  maxClockSkewMs: 5000,
  maxVideosPerExecution: 500,
  dryRun: false,
  verboseLogging: false,
};
