/**
 * Pipeline types — Job, stage, and execution plan definitions.
 */

export interface VideoJob {
  jobId: string;
  userId: string;
  videoUrl: string;
  fileName: string;
  duration: number;
  status: JobStatus;
  stage: ProcessingStage;
  progress: number;
  languages: string[];
  options: ProcessingOptions;
  outputs: OutputMetadata;
  timestamp: number;
  updatedAt: number;
  errors?: ErrorLog[];
}

export type JobStatus = "pending" | "processing" | "completed" | "failed" | "cancelled";
export type ProcessingStage = "queued" | "transcription" | "translation" | "subtitles" | "tts" | "dubbing" | "voice_cloning" | "media_processing" | "finalizing";

export interface JobData {
  jobId: string;
  userId: string;
  videoUrl: string;
  fileName: string;
  status: "accepted" | "processing" | "completed" | "failed";
  eventId: string;
  shard: string;
  executionPlan: ExecutionPlan;
  config: UserConfig;
  videoId?: string;
  channelId?: string;
  linkedVideoIds?: string[];
  linkedVideoCount?: number;
  estimatedCostUsd: number;
  stages: {
    transcription: StageStatus;
    credibility: StageStatus;
    dubbing?: StageStatus;
    truthEngine?: StageStatus;
    reachEngine?: StageStatus;
    aggregation?: StageStatus;
    [key: string]: StageStatus | undefined;
  };
  createdAt: number;
  updatedAt: number;
  completedAt?: number;
  completionSource?: string;
  version: number;
  finalOutput?: AggregatedOutput;

  etaSeconds?: number;
  etaMin?: number;
  etaMax?: number;
  etaMode?: "cold" | "stable" | "high-variance";
  estimatedCompletionAt?: number;
  actualCompletedAt?: number;
  stageDurations?: Record<string, number>;
  sourceLanguage?: string;
  outputs?: {
    subtitles?: Record<string, any>;
    dubbed?: Record<string, any>;
    [key: string]: any;
  };
}

export interface ProcessingOptions {
  genLangSubs: boolean;
  generateDubbing: boolean;
  enableVoiceCloning: boolean;
  chunkSize?: number;
  priority: "low" | "normal" | "high";
}

export interface OutputMetadata {
  subtitles: {
    [language: string]: {
      path: string;
      format: "srt" | "vtt";
      createdAt: number;
      followersCount: number;
      views: number;
    };
  };
  dubbed: {
    [language: string]: {
      path: string;
      audioUrl: string;
      createdAt: number;
    };
  };
  voiceCloning?: {
    cloneId: string;
    provider: string;
    createdAt: number;
  };
  transcript: {
    [language: string]: {
      text: string;
      path: string;
      createdAt: number;
    };
  };
}

export interface ErrorLog {
  stage: ProcessingStage;
  error: string;
  timestamp: number;
  retryCount: number;
  maxRetries: number;
}

export interface CloudTaskPayload {
  jobId: string;
  userId: string;
  operation: "orchestrate" | "transcode" | "merge";
  data: Record<string, any>;
  retryCount: number;
}

export interface StageStatus {
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  progress: number;
  startedAt?: number;
  completedAt?: number;
  error?: string;
}

export interface UserConfig {
  userId: string;
  channelType: ChannelType;
  languages: string[];
  subtitleLanguages?: string[];
  dubbingLanguages?: string[];
  dubbingMode: 'none' | 'standard' | 'voice_clone';
  genLangSubs: boolean;
  generateDubbing: boolean;
  enableFactCheck: boolean;
  priority: 'low' | 'normal' | 'high';
  duration?: number;
}

export interface ExecutionPlan {
  jobId: string;
  videoId?: string;
  title?: string;
  description?: string;
  thumbnailUrl?: string;
  thumbnail?: string;
  channelId?: string;
  channelName?: string;
  channelAvatarUrl?: string;
  category?: string;
  tags?: string[];
  topics?: string[];
  providedSources?: string[];
  visibility?: string;
  enablePath1: boolean;
  enablePath2: boolean;
  enableTruthEngine: boolean;
  enableReachEngine: boolean;
  enableAuxiliary: boolean;
  languages: string[];
  subtitleLanguages?: string[];
  dubbingLanguages?: string[];
  dubbingMode: 'none' | 'standard' | 'voice_clone';
  translationModel?: 'standard' | 'premium' | 'dynamic';
  toneMode?: 'casual' | 'formal';
  localeStyle?: 'neutral' | 'hinglish' | 'hinglish_urban' | 'hinglish_professional' | 'slang';
  targetPlatform?: 'youtube' | 'reels' | 'shorts' | 'linkedin' | 'tiktok';

  expectedSpeakerCount?: '1' | '2-3' | '4+' | 'not_sure';
  contentFormat?: 'solo' | 'interview' | 'podcast' | 'debate' | 'commentary' | 'general';
  primaryLanguage?: string;
  guestNames?: string[];
  sensitiveTopics?: ('health' | 'politics' | 'finance' | 'religion' | 'other')[];
  priorityMode?: 'speed' | 'balanced' | 'accuracy';
  synthesisTier?: 'standard' | 'deep' | 'podcast';

  videoCategory?: string;
  scoringProfile?: string;

  creatorDNA?: CreatorDNA;
  enableABHooks?: boolean;
  generateDubbing: boolean;
  genLangSubs: boolean;
  generateSubtitles?: boolean;
  channelType: ChannelType;
  autoChapters?: boolean;

  duration?: number;
  maxClaims: number;
  priority: 'low' | 'normal' | 'high';
  skipCache: boolean;
}

export interface CreatorDNA {
  vibe: 'energetic' | 'authoritative' | 'humorous' | 'educational' | 'controversial';
  slangTolerance: 'low' | 'medium' | 'high';
  vocabPreference: 'simple' | 'tech_heavy' | 'academic';
  customInstructions?: string;
}

export type ChannelType = 'standard' | 'custom';

export interface Channel {
  id: string;
  ownerId: string;
  handle: string;
  displayName: string;
  about?: string;
  type: ChannelType;
  outstandingCosts: number;
  hasPaidSubscriptionBuyout: boolean;
  createdAt: number;
  updatedAt: number;
  profile: {
    photoUrl?: string;
    coverUrl?: string;
    category: string;
    about?: string;
    links?: Record<string, string>;
  };
  stats: {
    videoCount: number;
    avgTrustIndex: number;
    subscriberCount: number;
    viewCount: number;
  };
  settings: {
    adsEnabled: boolean;
    adsRevenueShare: number;
    memberRevenueShare: number;
    locale: string;
    defaultPlatform: string;
  };
  limits: {
    maxDurationSec: number;
    maxChannels: number;
  };
  status?: string;
  geminiApproved?: boolean;
  moderationReason?: string | null;
  moderationRetryCount?: number;
}

export interface ProcessLog {
  jobId: string;
  timestamp: number;
  stage: ProcessingStage;
  action: string;
  details?: Record<string, any>;
}

export interface Checkpoint {
  jobId: string;
  language: string;
  stage: ProcessingStage;
  data: Record<string, any>;
  timestamp: number;
}

export interface EdgeResponse {
  jobId: string;
  status: 'accepted' | 'rejected';
  message: string;
  estimatedTime?: number;
  trackingUrl?: string;
}

export interface ProgressiveStatus {
  jobId: string;
  overall: number;
  stages: {
    transcription: StageStatus;
    credibility: StageStatus;
    dubbing?: StageStatus;
    aggregation?: StageStatus;
    [key: string]: StageStatus | undefined;
  };
  partialResults?: Partial<AggregatedOutput>;
  etaSeconds?: number;
  etaMin?: number;
  etaMax?: number;
  etaMode?: "cold" | "stable" | "high-variance";
  estimatedCompletionAt?: number;
}

// Forward declaration — full type in reports.ts
import type { AggregatedOutput } from './reports.js';
export type { AggregatedOutput };
