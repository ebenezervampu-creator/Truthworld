/**
 * TruthWorld Standalone Dubbing Studio Type Definitions
 */

export type DubbingMode = "dubbing" | "subtitles_only";

export type DubbingJobStatus =
  | "queued"
  | "pending"
  | "processing"
  | "running"
  | "ingesting"
  | "demuxing"
  | "diarizing"
  | "transcribing"
  | "awaiting_transcription_review" // Pre-TTS human-in-the-loop review
  | "translating"
  | "synthesizing_speech"           // Neural Voice Cloning & Synthesis
  | "awaiting_post_tts_review"      // Post-TTS segment adjustment
  | "muxing_audio"
  | "generating_subtitles"
  | "completed"
  | "failed";

export interface DubbingSpeakerProfile {
  speakerId: string;
  speakerLabel: string;
  gender?: "male" | "female" | "unknown";
  detectedLanguage?: string;
  assignedVoiceId: string;
  isClonedVoice: boolean;
  sampleAudioUrl?: string;
  pitchAdjustment?: number; // -12 to +12 semitones
  speedAdjustment?: number; // 0.5x to 2.0x
}

export interface DubbingSegment {
  id: string;
  speakerId: string;
  startTimeMs: number;
  endTimeMs: number;
  originalText: string;
  translatedText: string;
  targetLanguage: string;
  audioStemUrl?: string;
  status: "pending" | "synthesized" | "edited" | "locked";
  durationMs?: number;
  speedMultiplier?: number;
}

export interface DubbingDemuxOptions {
  isolateVocals: boolean;
  preserveBgm: boolean;
  bgmDuckLevelPercent: number; // e.g. 25% volume ducking under speech
  noiseSuppression: boolean;
}

export interface DubbingJob {
  id: string;
  userId: string;
  userEmail?: string;
  title: string;
  mode: DubbingMode;
  status: DubbingJobStatus;
  progressPercent: number;
  currentStepMessage: string;
  videoId?: string;
  pipelineJobId?: string;
  channelId?: string;
  
  // Media source
  sourceMediaUrl: string;
  sourceMediaType: "video" | "audio";
  durationSeconds: number;
  characterCount: number;
  
  // Languages
  sourceLanguage: string;
  targetLanguages: string[];
  
  // Custom Controls
  demuxOptions: DubbingDemuxOptions;
  voiceCloningEnabled: boolean;
  speakers: DubbingSpeakerProfile[];
  twoStageReviewEnabled: boolean; // Pause before TTS
  publishToTruthworld: boolean;   // Discounted $3 rate vs $5 export
  
  // Pricing & Billing
  chargeBasis: "characters" | "free_trial";
  totalCharactersCharged: number;
  costUsd: number;
  
  // Segments per target language
  segmentsByLanguage?: Record<string, DubbingSegment[]>;
  
  // Export Artifacts
  exportUrls?: {
    dubbedVideoByLanguage?: Record<string, string>;
    dubbedAudioByLanguage?: Record<string, string>;
    dialogueAudioByLanguage?: Record<string, string>;
    translationJsonByLanguage?: Record<string, string>;
    dubbedVideoMp4?: string;
    dubbedAudioMp3?: string;
    dubbedAudioWav?: string;
    vocalsOnlyWav?: string;
    vocalsStemMp3?: string;
    backgroundStemMp3?: string;
    reportJson?: string;
    subtitlesSrt?: Record<string, string>;
    subtitlesVtt?: Record<string, string>;
    subtitlesAss?: Record<string, string>;
    subtitlesJson?: Record<string, string>;
  };
  
  createdAt: number;
  updatedAt: number;
  completedAt?: number;
  error?: string;
}

export interface DubbingWalletTransaction {
  id: string;
  type: "trial_credit" | "topup" | "job_debit" | "refund" | "admin_grant" | "admin_adjustment";
  amountCredits: number;
  amountUsd: number;
  description: string;
  jobId?: string;
  orderId?: string;
  timestamp: number;
}

export interface DubbingWallet {
  userId: string;
  balanceCredits: number; // 1 credit = 1 character
  balanceUsd: number;
  trialClaimed: boolean;
  trialClaimedAt?: number;
  claimedIpHash?: string;
  totalCharactersUsed: number;
  totalSpentUsd: number;
  specialDiscountPercent?: number;
  specialDiscountType?: "none" | "percent" | "free" | string;
  isDubbingFree?: boolean;
  discountAppliedBy?: string;
  discountReason?: string;
  discountUpdatedAt?: number;
  transactions: DubbingWalletTransaction[];
  updatedAt: number;
}
