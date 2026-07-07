/**
 * Error types — error codes, extraction errors, events.
 */

import type { ExecutionPlan } from './pipeline.js';
import { TranscriptData } from './media.js';

export type CredibilityErrorCode =
  | 'TRANSCRIPT_EMPTY'
  | 'CLAIM_EXTRACTION_FAILED'
  | 'VERIFICATION_FAILED'
  | 'JSON_PARSE_FAILED'
  | 'GEMINI_FAILURE'
  | 'INSUFFICIENT_DATA'
  | 'AI_CAPACITY_EXCEEDED';

export class ExtractionError extends Error {
  constructor(public code: CredibilityErrorCode, message: string) {
    super(message);
    this.name = 'ExtractionError';
  }
}

export interface FactCheckJob {
  videoId: string;
  userId: string;
  transcript: TranscriptData;
  language: string;
  status: 'pending' | 'extracting' | 'verifying' | 'scoring' | 'completed' | 'failed';
  createdAt: number;
  updatedAt: number;
  progress: number;
  error?: string;
}

// ============================================
// EVENTS
// ============================================

export type EventType =
  | 'video-uploaded'
  | 'transcription-complete'
  | 'fact-processing'
  | 'dubbing-processing'
  | 'fact-complete'
  | 'dubbing-complete'
  | 'aggregation-ready'
  | 'resolution-requested';

export interface PipelineEvent<T = Record<string, any>> {
  eventId: string;
  eventType: EventType;
  jobId: string;
  userId: string;
  timestamp: number;
  data: T;
  retryCount: number;
  source: string;
  traceId?: string;
}

export interface TranscriptionCompleteData {
  transcriptPath: string;
  language: string;
  confidence: number;
  wordCount: number;
  duration: number;
  speakerCount: number;
  executionPlan: ExecutionPlan;
}

export interface FactCompleteData {
  honestRating: number | null;
  claimsEvaluated: number;
  correct: number;
  incorrect: number;
  unverifiable: number;
  resultPath: string;
}

export interface DubbingCompleteData {
  languages: string[];
  subtitlePaths: Record<string, string>;
  dubbedVideoPaths: Record<string, string>;
  audioPaths: Record<string, string>;
}
