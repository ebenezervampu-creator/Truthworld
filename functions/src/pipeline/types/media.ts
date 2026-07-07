/**
 * Media types — transcripts, segments, dubbing, artifacts, visual context.
 */

export interface TranscriptData {
  text: string;
  utterances: Utterance[];
  segments?: Segment[];
  language: string;
  confidence: number;
  duration: number;
}

export interface Utterance {
  start: number;
  end: number;
  speaker?: string;
  text: string;
}

export interface Segment {
  start: number;
  end: number;
  text: string;
}

export interface TranscriptionResult {
  jobId: string;
  language: string;
  text: string;
  confidence: number;
  segments: Segment[];
}

export interface TranslationResult {
  jobId: string;
  sourceLanguage: string;
  targetLanguage: string;
  segments: TranslatedSegment[];
}

export interface TranslatedSegment {
  original: string;
  translated: string;
  start: number;
  end: number;
  confidence?: number;
  isHook?: boolean;
  variants?: {
    viral: string;
    safe: string;
    professional: string;
  };
}

export interface TTSRequest {
  jobId: string;
  language: string;
  text: string;
  voiceId?: string;
  speakerId?: string;
}

export interface TTSResult {
  jobId: string;
  language: string;
  audioUrl: string;
  duration: number;
  format: string;
}

export interface MediaMergeRequest {
  jobId: string;
  videoUrl: string;
  audioUrl: string;
  subtitleUrl?: string;
  language: string;
  format: "mp4" | "webm";
}

export interface EnhancedTranscriptionResult {
  jobId: string;
  language: string;
  detectedLanguage: string;
  text: string;
  confidence: number;
  speakerConfidence?: number;
  words: WordTimestamp[];
  segments: TimedSegment[];
  utterances?: TimedSegment[];
  speakers: SpeakerInfo[];
  chapters?: Array<{
    startTimeMs: number;
    endTimeMs: number;
    title: string;
    summary: string;
  }>;
  duration: number;
}

export interface WordTimestamp {
  text: string;
  start: number;
  end: number;
  confidence: number;
  speaker?: string;
}

export interface TimedSegment {
  index: number;
  text: string;
  start: number;
  end: number;
  duration: number;
  speaker?: string;
  isHook?: boolean;
  words: WordTimestamp[];
}

export interface SpeakerInfo {
  speakerId: string;
  label: string;
  totalDuration: number;
  segments: number[];
}

export interface DubbingSegment {
  index: number;
  originalText: string;
  translatedText: string;
  language: string;
  start: number;
  end: number;
  targetDuration: number;
  speaker?: string;
  confidence?: number;
  isHook?: boolean;
}

export interface SyncInstruction {
  segmentIndex: number;
  speedFactor: number;
  silenceBefore: number;
  silenceAfter: number;
  originalDuration: number;
  targetDuration: number;
}

export interface DubbingResult {
  jobId: string;
  language: string;
  subtitleUrl: string;
  subtitleFormat: 'srt' | 'vtt';
  audioUrl: string;
  videoUrl: string;
  translationUrl?: string;
  segments: number;
  processingTime: number;
  meta?: {
    voice?: string;
    durationSec: number;
  };
}

// ============================================
// ARTIFACT REGISTRY
// ============================================

export interface TranscriptionArtifacts {
  jsonUrl?: string;
  srtUrl?: string;
  vttUrl?: string;
  sourceLanguage?: string;
}

export interface LanguageArtifacts {
  status: "completed" | "processing" | "failed";
  translationUrl?: string;
  audioUrl?: string;
  videoUrl?: string;
  subtitleUrl?: string;
  dubbedLanguage?: string;
  meta?: {
    segments: number;
    durationSec: number;
    voice?: string;
  };
}

export interface ArtifactsMap {
  transcription?: TranscriptionArtifacts;
  languages?: Record<string, LanguageArtifacts>;
  subtitles?: Record<string, any>;
  dubbing?: Record<string, any>;
  audio?: Record<string, string>;
}

export interface VisualContext {
  jobId: string;
  frames: FrameAnalysis[];
  scenes: SceneInfo[];
  ocrTexts: OCRResult[];
  totalFramesAnalyzed: number;
  hasOnScreenText?: boolean;
}

export interface FrameAnalysis {
  timestamp: number;
  labels: string[];
  objects: string[];
  confidence: number;
}

export interface SceneInfo {
  sceneIndex: number;
  start: number;
  end: number;
  description: string;
  dominantLabels: string[];
}

export interface OCRResult {
  timestamp: number;
  text: string;
  confidence: number;
  boundingBox?: { x: number; y: number; width: number; height: number };
}
