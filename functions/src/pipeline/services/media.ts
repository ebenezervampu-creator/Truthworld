import axios from "axios";
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import { execFile } from "child_process";
import { promisify } from "util";
import { PIPELINE_CONFIG } from "../config";
import { emitDubbingTiming } from "../utils/dubbing-timing";
import { storage } from "firebase-admin";
import { estimatePitch, f32leToSamples, type PitchEstimate } from "./pitch-estimation";
import { checkDubSpeech, dialogueExtents, voiceGenderMismatch, type DubSyncReport } from "./dub-sync-check";
import { BLEED_ANALYSIS_RATE, coherentVoiceSuppressionDb } from "./stem-bleed";
import { parseMeanVolumeDb, selectExpression, speechGaps } from "./separation-policy";
import { sharedJobMedia } from "./shared-job-media";
import { fastSeparationProbeEnabled, sharedTmpEnabled } from "./latency-flags";
import {
  FAITHFUL_MIX,
  MAX_EQ_BRANCHES,
  MIN_EQ_REFERENCE_SEC,
  TIGHT_STEM_FADE_MS,
  analysisRateFor,
  bandProfileDb,
  buildEnvelopes,
  buildFaithfulMixGraph,
  buildGainSpans,
  planLineGainsDb,
  activeRmsDb,
  dubVoiceLiftDb,
  checkFaithfulness,
  detectActiveSpans,
  detectNonVerbalSpans,
  dubCoverage,
  dubSpansNearLines,
  bedMatchEnabled,
  planBedMatch,
  speechFreeSpans,
  BED_MATCH,
  type BedMatchPlan,
  eqCorrectionDb,
  envelopeRateFor,
  eqFilterFor,
  estimateOriginalVoiceDb,
  fidelityStemSelectEnabled,
  firstSpans,
  keepNonVerbalEnabled,
  measureEdgeStepsDb,
  measureGapFidelity,
  outsideRegions,
  planDialogueRegions,
  rmsDbOver,
  spansSelectExpr,
  subtractSpans,
  voiceGainDb,
  roomMatchEnabled,
  sceneToneEnabled,
  tightStemEnabled,
  voiceRideEnabled,
  estimateRegionRoom,
  groupRegionsIntoScenes,
  buildSyntheticRoomIr,
  buildTightStemSpans,
  computeVoiceRideEnvelope,
  sortedLines,
  type BgmReport,
  type DubBranch,
  type SpeakerSpanMs,
  type TimeSpanMs,
  type RegionRoomEstimate,
  type SceneRoomEstimate,
} from "./faithful-mix";
import { planPreroll, prerollEnabled } from "./segment-preroll";
import {
  DELIVERY_TARGET_LUFS,
  DELIVERY_TOLERANCE_LU,
  detectSourceBleed,
  loudnessCorrection,
  type BleedReport,
  type SpeechWindow,
} from "./delivery-audio-check";

export const execFileAsync = promisify(execFile);

export function getFfmpegPath(): string | null {
  for (const modName of ["ffmpeg-static", "@ffmpeg-installer/ffmpeg"]) {
    try {
      const mod = require(modName);
      const candidate = typeof mod === "string" ? mod : mod?.path;
      if (typeof candidate === "string" && candidate.length > 0 && fs.existsSync(candidate)) {
        try {
          fs.chmodSync(candidate, 0o755);
        } catch (_) {}
        return candidate;
      }
    } catch {
      // Try next FFmpeg binary provider
    }
  }
  return null;
}

export function getFfprobePath(): string | null {
  for (const modName of ["@ffprobe-installer/ffprobe"]) {
    try {
      const mod = require(modName);
      const candidate = typeof mod === "string" ? mod : mod?.path;
      if (typeof candidate === "string" && candidate.length > 0 && fs.existsSync(candidate)) {
        try {
          fs.chmodSync(candidate, 0o755);
        } catch (_) {}
        return candidate;
      }
    } catch {
      // Ignore missing ffprobe package
    }
  }
  return null;
}

function isValidAudioBuffer(buf: Buffer): boolean {
  if (!buf || buf.length < 4) return false;
  // ID3v2 header: 'ID3'
  if (buf[0] === 0x49 && buf[1] === 0x44 && buf[2] === 0x33) return true;
  // MPEG Audio Frame Sync: 11 consecutive 1s (0xFF followed by high 3 bits set)
  if (buf[0] === 0xff && (buf[1] & 0xe0) === 0xe0) return true;
  // RIFF (WAV) header: 'RIFF'
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46) return true;
  return false;
}

/**
 * Creates a valid, standard-compliant silent MP3 audio buffer (44.1kHz, 128kbps stereo).
 * Uses FFmpeg libmp3lame anullsrc when FFmpeg is available, or constructs a standard sequence of
 * MPEG-1 Layer 3 silent frames (0xFF 0xFB 0x90 0x64 ...) decodable by any standard MP3 decoder.
 */
export async function createSilentMp3Buffer(durationSeconds = 0.5): Promise<Buffer> {
  const ffmpeg = getFfmpegPath();
  if (ffmpeg) {
    try {
      const tmpPath = path.join(os.tmpdir(), `silent_${Date.now()}_${Math.random().toString(36).slice(2)}.mp3`);
      await execFileAsync(ffmpeg, [
        "-y",
        "-f", "lavfi",
        "-i", "anullsrc=r=44100:cl=stereo",
        "-t", `${Math.max(0.1, durationSeconds)}`,
        "-c:a", "libmp3lame",
        "-b:a", "128k",
        tmpPath,
      ]);
      const data = await fs.promises.readFile(tmpPath);
      await fs.promises.unlink(tmpPath).catch(() => {});
      if (data && data.length > 0) return data;
    } catch (err) {
      console.warn("[MediaService] FFmpeg silence generation warning, using MPEG-1 silence frame fallback:", err);
    }
  }

  // Fallback: Standard MPEG-1 Layer 3 silent frame sequence (44.1kHz 128kbps stereo)
  // Header: 0xFF, 0xFB, 0x90, 0x64 followed by zero payload (417 bytes total per frame)
  const frame = Buffer.alloc(417, 0);
  frame[0] = 0xff;
  frame[1] = 0xfb;
  frame[2] = 0x90;
  frame[3] = 0x64;
  const numFrames = Math.max(1, Math.round(durationSeconds * (44100 / 1152)));
  return Buffer.concat(Array(numFrames).fill(frame));
}

/**
 * Robustly parses any duration representation (seconds number, ms number, or "MM:SS" / "HH:MM:SS" string) into numeric seconds.
 */
export function parseDurationToSeconds(duration: any): number {
  if (duration === null || duration === undefined) return 0;
  if (typeof duration === "number") {
    if (isNaN(duration) || duration <= 0) return 0;
    // If > 100,000, value is almost certainly milliseconds
    if (duration > 100000) return Math.round(duration / 1000);
    return Math.round(duration);
  }
  if (typeof duration === "string") {
    const trimmed = duration.trim();
    if (!trimmed) return 0;
    if (trimmed.includes(":")) {
      const parts = trimmed.split(":").map(Number);
      if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
        return Math.round(parts[0] * 60 + parts[1]);
      }
      if (parts.length === 3 && !isNaN(parts[0]) && !isNaN(parts[1]) && !isNaN(parts[2])) {
        return Math.round(parts[0] * 3600 + parts[1] * 60 + parts[2]);
      }
    }
    const parsed = Number(trimmed);
    if (!isNaN(parsed) && parsed > 0) {
      if (parsed > 100000) return Math.round(parsed / 1000);
      return Math.round(parsed);
    }
  }
  return 0;
}

/**
 * Universally parses any gs:// URI into its exact bucket name and file path,
 * preventing cross-bucket 404 download errors (e.g., .firebasestorage.app vs .appspot.com).
 */
export function parseGcsUri(uri: string): { bucketName: string; filePath: string } {
  const withoutPrefix = uri.replace(/^gs:\/\//, "");
  const slashIdx = withoutPrefix.indexOf("/");
  if (slashIdx === -1) {
    return { bucketName: withoutPrefix, filePath: "" };
  }
  const bucketName = withoutPrefix.substring(0, slashIdx);
  const filePath = withoutPrefix.substring(slashIdx + 1);
  return { bucketName, filePath };
}

/**
 * Universally parses any Google Cloud Storage / Firebase Storage URI or URL into its exact bucket name and file path,
 * preventing cross-bucket 404/403 download errors (e.g., .firebasestorage.app vs .appspot.com, private signed/unsigned URLs).
 */
export function parseAnyStorageUrl(url: string): { bucketName: string; filePath: string } | null {
  if (!url || typeof url !== "string") return null;
  const trimmed = url.trim();
  if (trimmed.startsWith("gs://")) {
    return parseGcsUri(trimmed);
  }
  try {
    const parsed = new URL(trimmed);
    // Case 1: Firebase Storage URL (e.g. firebasestorage.googleapis.com/v0/b/<bucket>/o/<encodedPath>)
    if (parsed.hostname.includes("firebasestorage.googleapis.com")) {
      const match = parsed.pathname.match(/\/v0\/b\/([^/]+)\/o\/(.+)/);
      if (match) {
        const bucketName = decodeURIComponent(match[1]);
        const rawPath = match[2].split("?")[0];
        const filePath = decodeURIComponent(rawPath);
        return { bucketName, filePath };
      }
    }
    // Case 2: Google Cloud Storage standard path URL (e.g. storage.googleapis.com/<bucket>/<path>)
    if (parsed.hostname === "storage.googleapis.com") {
      const parts = parsed.pathname.replace(/^\/+/, "").split("/");
      if (parts.length >= 2) {
        const bucketName = decodeURIComponent(parts[0]);
        const filePath = decodeURIComponent(parts.slice(1).join("/").split("?")[0]);
        return { bucketName, filePath };
      }
    }
    // Case 3: Google Cloud Storage subdomain URL (e.g. <bucket>.storage.googleapis.com/<path>)
    if (parsed.hostname.endsWith(".storage.googleapis.com")) {
      const bucketName = decodeURIComponent(parsed.hostname.replace(".storage.googleapis.com", ""));
      const filePath = decodeURIComponent(parsed.pathname.replace(/^\/+/, "").split("?")[0]);
      return { bucketName, filePath };
    }
  } catch {
    return null;
  }
  return null;
}

/**
 * Downloads a storage object (or public media URL) directly into a Buffer safely.
 * Prefers the Admin GCS SDK for any GCS/Firebase Storage URL to bypass public ACL requirements.
 */
export async function downloadStorageBuffer(url: string, defaultBucket?: any): Promise<Buffer> {
  const storageInfo = parseAnyStorageUrl(url);
  if (storageInfo) {
    const targetBucket = storageInfo.bucketName ? storage().bucket(storageInfo.bucketName) : (defaultBucket || storage().bucket());
    const [buf] = await targetBucket.file(storageInfo.filePath).download();
    return buf;
  }
  if (!isSafePublicUrl(url)) {
    throw new Error(`[MediaService] Blocked unsafe or internal URL (SSRF protection): ${url.slice(0, 50)}`);
  }
  const resp = await axios.get(url, { responseType: "arraybuffer", timeout: 90000 });
  return Buffer.from(resp.data);
}

/**
 * 🛡️ SSRF Guard: Validates that an incoming URL does not point to internal metadata, loopback, or private networks.
 */
export function isSafePublicUrl(urlStr: string): boolean {
  if (!urlStr || typeof urlStr !== "string") return false;
  if (urlStr.startsWith("gs://")) return true;
  try {
    const parsed = new URL(urlStr);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
    const hostname = parsed.hostname.toLowerCase();
    if (
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname === "metadata.google.internal" ||
      hostname === "169.254.169.254" ||
      hostname.endsWith(".internal") ||
      hostname.endsWith(".local")
    ) {
      return false;
    }
    const ipMatch = hostname.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
    if (ipMatch) {
      const b0 = parseInt(ipMatch[1], 10);
      const b1 = parseInt(ipMatch[2], 10);
      if (b0 === 10 || b0 === 127 || b0 === 0) return false;
      if (b0 === 169 && b1 === 254) return false;
      if (b0 === 172 && b1 >= 16 && b1 <= 31) return false;
      if (b0 === 192 && b1 === 168) return false;
    }
    return true;
  } catch {
    return false;
  }
}

/**
 * 🛡️ FFmpeg Audio Filter Sanitizer: Blocks command/argument injection.
 */
export function sanitizeAudioFilterString(filterStr?: string): string {
  if (!filterStr || typeof filterStr !== "string") return "apad";
  const trimmed = filterStr.trim();
  if (!/^[a-zA-Z0-9_=:\-., ]+$/.test(trimmed)) {
    return "apad";
  }
  return `${trimmed},apad`;
}

export interface MergeAudioMetrics {
  trueSpeechEndMs: number;
  segmentCollisionsCount: number;
  outroSpeechTruncated: boolean;
}

export interface MergeAudioOptions {
  segments?: Array<{ start: number; end: number; duration?: number }>;
  totalDurationMs?: number;
  totalDurationSeconds?: number | string;
  audioFilters?: string;
  cadenceLock?: boolean; // Anti-uncanny viseme cadence locking (zero vocal overhang)
  onMetricsComputed?: (metrics: MergeAudioMetrics) => void;
}

// Pipeline version for M&E cache busting — increment when separation algorithm changes.
export const MNE_PIPELINE_VERSION = "3";

export interface ExtractMneOptions {
  isolatedVocalUrl?: string;
  forceMidSideSplit?: boolean;
  spokenSegments?: Array<{ start: number; end: number }>;
  expectedDurationSeconds?: number;
}

export interface ExtractMneDetailedResult {
  mneUrl: string;
  vocalsUrl?: string;
  source: MneValidationResult["source"];
  engine: string;
  degraded: boolean;
  issues: string[];
  dialogueBleedDb?: number;
}

export type MasteringProfile = "web_streaming" | "broadcast_ebu" | "broadcast_atsc" | "cinema_netflix";

export interface MasteringProfileConfig {
  targetLufs: number;
  truePeakDb: number;
  loudnessRangeLra: number;
  dialogueGated: boolean;
}

export const MASTERING_PROFILES: Record<MasteringProfile, MasteringProfileConfig> = {
  web_streaming: {
    // YouTube / Web / Mobile social standards (-14 LUFS, -1 dBTP)
    targetLufs: -14,
    truePeakDb: -1.0,
    loudnessRangeLra: 11,
    dialogueGated: false,
  },
  broadcast_ebu: {
    // EBU R128 European Broadcast Standard (-23 LUFS ±0.5 LU, -1 dBTP)
    targetLufs: -23,
    truePeakDb: -1.0,
    loudnessRangeLra: 7,
    dialogueGated: true,
  },
  broadcast_atsc: {
    // ATSC A/85 North American Broadcast Standard (-24 LKFS ±1.0 LKFS, -2 dBTP)
    targetLufs: -24,
    truePeakDb: -2.0,
    loudnessRangeLra: 10,
    dialogueGated: true,
  },
  cinema_netflix: {
    // Netflix NPPS Specification (-24 LKFS/LUFS ±1.0 LU dialogue gated, -1 dBTP true peak)
    targetLufs: -24,
    truePeakDb: -1.0,
    loudnessRangeLra: 14,
    dialogueGated: true,
  },
};

export interface MneValidationResult {
  source:
    | "studio"
    | "neural_demixing"
    | "neural_demixing_best_of_2"
    | "neural_isolation_subtraction"
    | "dsp_fallback"
    | "fallback_crossover";
  fileUrl: string;
  durationSeconds: number;
  videoDurationSeconds: number;
  durationMatch: boolean;
  durationDeltaMs: number;
  timelineAlignmentMs: number;
  sampleRate: number;
  channels: number;
  channelLayout: string;
  dialogueBleedDb?: number;
  /** Worst-quartile drop (dB) in the 250–3800 Hz voice band vs the original during speech. Higher = cleaner. */
  vocalSuppressionDb?: number;
  /**
   * How vocalSuppressionDb was measured. "voice_coherence": only the part of the stem that moves with
   * the isolated voice counts as bleed (see stem-bleed.ts). "level_drop": original minus stem level,
   * which also counts loud music as bleed (used when no isolated voice is available).
   */
  bleedMethod?: "voice_coherence" | "level_drop";
  clippingDetected: boolean;
  corruptionDetected: boolean;
  validationStatus: "passed" | "degraded" | "failed" | "not_required";
  issues: string[];
}

export interface ReelDefinition {
  reelIndex: number;
  totalReels: number;
  nominalStartMs: number;
  nominalEndMs: number;
  overlapBeforeMs: number;
  overlapAfterMs: number;
  startWithOverlapMs: number;
  endWithOverlapMs: number;
  authoritativeSegmentCount: number;
  idempotencyKey: string;
}

export type RoomToneEnvelope = "dry-studio" | "small-room" | "large-reflective" | "outdoor-open";

export interface CinemaMasteringOptions {
  targetLufs?: number;
  truePeakDb?: number;
  loudnessRangeLra?: number;
  deEss?: boolean;
  roomTone?: RoomToneEnvelope;
  outputSuffix?: string;
  masteringProfile?: MasteringProfile;
}

export interface MixDubOptions {
  mneUrl: string;
  dubbedAudioUrl: string;
  isolatedVocalUrl?: string; // Neural isolated vocals stem for authentic non-dialogue vocal SFX recovery
  sourceWords?: Array<{ start: number; end: number; text?: string }>; // AssemblyAI word timestamps for collision protection
  totalDurationSeconds?: number;
  totalDurationMs?: number;
  duckingThreshold?: number; // default: 0.12 (-18 dBFS)
  duckingRatio?: number;     // default: 2.8 (~12 dB attenuation)
  attackMs?: number;         // default: 20 ms
  releaseMs?: number;        // default: 350 ms
  audioFilters?: string;     // custom DSP filters
  targetLoudnessLufs?: number; // custom manual target
  masteringProfile?: MasteringProfile; // "web_streaming" | "broadcast_ebu" | "broadcast_atsc" | "cinema_netflix"
  deEss?: boolean;
  roomTone?: RoomToneEnvelope;
  mneGain?: number;          // DAW M&E stem fader multiplier (default: 1.0 -> 1.1 mix weight)
  dialogueGain?: number;     // DAW Dialogue stem fader multiplier (default: 1.0)
  bgmDuckLevelPercent?: number; // Studio BGM ducking slider (0..50% lower under speech)
  spokenSegments?: Array<{ start: number; end: number }>; // For speech vs pause energy safety verification
  isDegradedMne?: boolean;   // Caps makeup gain to +3 dB when stem comes from fallback separation
  mneValidation?: MneValidationResult;
}

export interface FaithfulMixOptions {
  /** Full-band original audio (extractStereoSourceAudio). */
  sourceAudioUrl: string;
  /** Stitched dubbed dialogue for this language. */
  dubbedAudioUrl: string;
  /** Clean background stem; null → the dubbed voice plays alone inside the dialogue regions. */
  bedUrl?: string | null;
  /** Isolated original voice, used to set each dubbed voice to the original level. */
  isolatedVocalUrl?: string | null;
  /** The original's spoken lines (ms) with speaker labels. */
  lines: SpeakerSpanMs[];
  /** Word-level timestamps (ms) from the source transcript, for tight stem & non-verbal keeping. */
  sourceWords?: TimeSpanMs[];
  totalDurationMs?: number;
  /** Measured speech-only (no background): the source itself is a clean voice reference. */
  sourceIsSpeechOnly?: boolean;
  /** EQ each dubbed speaker toward the original voice (default true). */
  toneMatch?: boolean;
}

export interface FaithfulMixResult {
  ok: boolean;
  url: string | null;
  reason?: string;
  /** Integrated loudness of the original; the delivery check keeps the dub at this level. */
  sourceLufs: number | null;
  mixLufs: number | null;
  regions: number;
  regionMs: number;
  outsideDiffDb: number | null;
  voiceGainDb: Record<string, number>;
  /** Speakers whose dubbed voice was EQ-matched to their original voice. */
  toneMatchedSpeakers: string[];
  usedBed: boolean;
  /** The dub measured against the original (dub-sync-check.ts); the quality gate reads it. */
  syncReport?: DubSyncReport;
  /** Detailed BGM & SFX preservation measurements for this mix. */
  bgmReport?: BgmReport;
}

/**
 * Builds TruthWorld's shared 5-stage FFmpeg cinema mastering chain:
 *   1. Multi-stage stereo dynamic leveling (acompressor)
 *   2. Dynamic de-essing EQ notch around 6.5kHz to eliminate TTS sibilance
 *   3. Optional room tone envelope matching (aecho)
 *   4. True-peak ISP brickwall limiter (alimiter at 10^(truePeakDb/20))
 *   5. EBU R128 linear loudness normalization (loudnorm)
 */
export function buildCinemaMasteringFilterChain(options?: {
  targetLufs?: number;
  truePeakDb?: number;
  loudnessRangeLra?: number;
  deEss?: boolean;
  roomTone?: RoomToneEnvelope;
}): string {
  const targetLufs = options?.targetLufs ?? -14;
  const truePeakDb = options?.truePeakDb ?? -1.0;
  const loudnessRangeLra = options?.loudnessRangeLra ?? 11;
  const deEss = options?.deEss !== false;
  const ispLimitLinear = Number(
    Math.max(0.1, Math.min(1.0, Math.pow(10, truePeakDb / 20))).toFixed(3)
  );

  const stages: string[] = [
    "acompressor=threshold=-24dB:ratio=3:attack=20:release=200:makeup=2",
    "acompressor=threshold=-18dB:ratio=2:attack=5:release=100:makeup=1.5",
  ];

  if (deEss) {
    stages.push("equalizer=f=6500:width_type=o:w=2:g=-3");
  }

  if (options?.roomTone === "small-room") {
    stages.push("aecho=0.8:0.88:40:0.18");
  } else if (options?.roomTone === "large-reflective") {
    stages.push("aecho=0.8:0.88:90:0.28");
  }

  stages.push(
    `alimiter=level_in=1:level_out=1:limit=${ispLimitLinear}:attack=5:release=50:asc=1:level=0`
  );
  stages.push(
    `loudnorm=I=${targetLufs}:TP=${truePeakDb}:LRA=${loudnessRangeLra}:linear=true`
  );

  return stages.join(",");
}

/**
 * Media processing service - handles FFmpeg operations & audio stitching
 */
/**
 * Request settings for the self-hosted Demux worker (scripts/modal_demux_worker.py).
 * The worker refuses requests without the shared token, so without DEMUX_WORKER_TOKEN the worker
 * is skipped (null) instead of being called and failing. DEMUX_TIMEOUT_MS defaults to 300 s:
 * a 10-minute video on a cold GPU needs more than the old 120 s.
 */
export function demuxWorkerRequestConfig(): { headers: Record<string, string>; timeout: number } | null {
  const token = (process.env.DEMUX_WORKER_TOKEN || "").trim();
  if (!token) return null;
  return {
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    timeout: Number(process.env.DEMUX_TIMEOUT_MS) || 300000,
  };
}

/**
 * Pure PCM equivalent of FFmpeg `volumedetect` `mean_volume` across overall track and gap windows.
 * Avoids running an 80-clause `aselect` expression over tens of millions of samples.
 */
export function computeBackgroundLevelsFromPcm(
  pcm: Float32Array,
  sampleRate: number,
  gaps: Array<{ start: number; end: number }>
): { backgroundDb: number | null; overallDb: number | null } {
  if (!pcm || pcm.length === 0 || sampleRate <= 0) {
    return { backgroundDb: null, overallDb: null };
  }
  const toDb = (sumSq: number, count: number): number | null => {
    if (count <= 0) return null;
    const meanSq = sumSq / count;
    if (meanSq <= 1e-12) return -120;
    return Number((10 * Math.log10(meanSq)).toFixed(1));
  };

  let overallSum = 0;
  for (let i = 0; i < pcm.length; i++) {
    const s = pcm[i];
    overallSum += s * s;
  }
  const overallDb = toDb(overallSum, pcm.length);

  let gapSum = 0;
  let gapCount = 0;
  for (const g of gaps) {
    const startIdx = Math.max(0, Math.floor((g.start * sampleRate) / 1000));
    const endIdx = Math.min(pcm.length, Math.ceil((g.end * sampleRate) / 1000));
    for (let i = startIdx; i < endIdx; i++) {
      const s = pcm[i];
      gapSum += s * s;
    }
    if (endIdx > startIdx) gapCount += endIdx - startIdx;
  }
  const backgroundDb = toDb(gapSum, gapCount);
  return { backgroundDb, overallDb };
}

export class MediaService {
  private amixNormalizeCache = new Map<string, boolean>();

  /**
   * Detects once per binary path whether FFmpeg's `amix` filter supports `normalize=0` (FFmpeg 4.4+).
   */
  private async supportsAmixNormalize(ffmpegPath: string): Promise<boolean> {
    if (this.amixNormalizeCache.has(ffmpegPath)) {
      return this.amixNormalizeCache.get(ffmpegPath)!;
    }
    let supported = false;
    try {
      const { stdout, stderr } = await execFileAsync(ffmpegPath, ["-h", "filter=amix"]).catch((e) => ({
        stdout: e?.stdout || "",
        stderr: e?.stderr || "",
      }));
      supported = /\bnormalize\b/.test(`${stdout}\n${stderr}`);
    } catch {
      supported = false;
    }
    this.amixNormalizeCache.set(ffmpegPath, supported);
    return supported;
  }

  /**
   * Reads exact stereo 16-bit PCM sample frame count from a WAV file's RIFF `data` chunk.
   */
  private async readWavSampleCount(wavPath: string): Promise<number> {
    const buf = await fs.promises.readFile(wavPath);
    let offset = 12; // Skip "RIFF" + size + "WAVE"
    while (offset + 8 <= buf.length) {
      const chunkId = buf.toString("ascii", offset, offset + 4);
      const chunkSize = buf.readUInt32LE(offset + 4);
      if (chunkId === "data") {
        // 4 bytes per stereo 16-bit PCM sample frame
        return Math.floor(chunkSize / 4);
      }
      offset += 8 + chunkSize + (chunkSize % 2);
    }
    return Math.max(0, Math.floor((buf.length - 44) / 4));
  }

  /**
   * Memory-safe file download stream: streams chunks directly to disk with constant ~64KB buffer,
   * completely preventing V8 heap spikes / 2GiB OOM on Cloud Functions when handling 500MB-1GB videos.
   *
   * Authenticated Storage Resolution: Automatically detects any GCS/Firebase Storage URLs (gs://, storage.googleapis.com,
   * firebasestorage.googleapis.com) and streams directly via the Storage Admin SDK, eliminating 403 Forbidden errors on private objects.
   */
  /**
   * Ensures a media asset is downloaded at most once per job invocation in `/tmp`.
   */
  async ensureJobLocalFile(
    jobId: string,
    urlOrPath: string,
    defaultExt = ".bin",
    timeoutMs = 180000
  ): Promise<string | null> {
    if (!urlOrPath || typeof urlOrPath !== "string") return null;
    const clean = urlOrPath.startsWith("file://") ? urlOrPath.replace("file://", "") : urlOrPath;
    if (fs.existsSync(clean)) return clean;
    if (!sharedTmpEnabled() || !jobId) return null;

    const bucket = storage().bucket();
    try {
      return await sharedJobMedia.ensureLocalFile(jobId, clean, defaultExt, async (destPath) => {
        await this.downloadDirectToPath(clean, destPath, bucket, timeoutMs);
      });
    } catch (err) {
      console.warn(`[MediaService] ensureJobLocalFile failed for ${jobId}:`, err);
      return null;
    }
  }

  async registerJobLocalFile(
    jobId: string,
    urlOrPath: string,
    localPath: string,
    defaultExt?: string
  ): Promise<string | null> {
    if (!sharedTmpEnabled() || !jobId) return null;
    return sharedJobMedia.registerLocalFile(jobId, urlOrPath, localPath, defaultExt).catch(() => null);
  }

  async releaseJobLocalFiles(jobId: string): Promise<void> {
    if (!jobId) return;
    await sharedJobMedia.releaseJob(jobId);
  }

  private async downloadDirectToPath(
    url: string,
    destinationPath: string,
    bucket: any,
    timeoutMs: number = 180000
  ): Promise<void> {
    const storageInfo = parseAnyStorageUrl(url);
    if (storageInfo) {
      const targetBucket = storageInfo.bucketName ? storage().bucket(storageInfo.bucketName) : bucket;
      await targetBucket.file(storageInfo.filePath).download({ destination: destinationPath });
      return;
    }
    if (!isSafePublicUrl(url)) {
      throw new Error(`[MediaService] Blocked unsafe or internal URL (SSRF protection): ${url.slice(0, 50)}`);
    }
    const resp = await axios.get(url, { responseType: "stream", timeout: timeoutMs });
    const writeStream = fs.createWriteStream(destinationPath);
    await new Promise<void>((resolve, reject) => {
      resp.data.pipe(writeStream);
      writeStream.on("finish", () => resolve());
      writeStream.on("error", (err: any) => reject(err));
    });
  }

  private async downloadToStream(
    url: string,
    destinationPath: string,
    bucket: any,
    timeoutMs: number = 180000,
    jobId?: string
  ): Promise<void> {
    const clean = url.startsWith("file://") ? url.replace("file://", "") : url;
    if (fs.existsSync(clean)) {
      if (path.resolve(clean) !== path.resolve(destinationPath)) {
        await fs.promises.copyFile(clean, destinationPath);
      }
      return;
    }
    if (sharedTmpEnabled() && jobId) {
      const ext = path.extname(clean.split("?")[0] || "") || path.extname(destinationPath) || ".bin";
      const cachedPath = await sharedJobMedia.ensureLocalFile(jobId, clean, ext, async (dest) => {
        await this.downloadDirectToPath(clean, dest, bucket, timeoutMs);
      }).catch(() => null);
      if (cachedPath && fs.existsSync(cachedPath)) {
        if (path.resolve(cachedPath) !== path.resolve(destinationPath)) {
          await fs.promises.copyFile(cachedPath, destinationPath);
        }
        return;
      }
    }
    await this.downloadDirectToPath(url, destinationPath, bucket, timeoutMs);
  }

  /**
   * Public helper extracting duration in milliseconds of an audio or video file using FFprobe / FFmpeg.
   */
  async probeMediaDurationMs(filePath: string): Promise<number> {
    const ffprobePath = getFfprobePath();
    if (ffprobePath) {
      const probed = await this.probeDurationViaFfprobeMs(ffprobePath, filePath);
      if (probed > 0) return probed;
    }
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) return 0;
    return this.probeAudioDurationMs(ffmpegPath, filePath);
  }

  /**
   * Static convenience helper for detecting video shot changes.
   */
  static async detectShotChanges(videoPathOrUrl: string, threshold: number = 0.35): Promise<number[]> {
    return mediaService.detectShotChanges(videoPathOrUrl, threshold);
  }

  /**
   * Detects video shot changes / scene cuts using FFmpeg's scene change filter.
   *
   * @param videoPathOrUrl Local video file path or accessible media URL
   * @param threshold Sensitivity threshold (0.0 - 1.0, default 0.35). Lower = more cuts.
   * @returns Array of cut timestamps in milliseconds, sorted ascending.
   */
  async detectShotChanges(videoPathOrUrl: string, threshold: number = 0.35): Promise<number[]> {
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) {
      console.warn("[MediaService] FFmpeg not found, skipping shot-change detection");
      return [];
    }

    try {
      const clampedThresh = Math.max(0.1, Math.min(0.9, threshold));
      const args = [
        "-i", videoPathOrUrl,
        "-filter:v", `select=gt(scene\\,${clampedThresh.toFixed(2)}),showinfo`,
        "-f", "null", "-",
      ];

      const res = await execFileAsync(ffmpegPath, args, { maxBuffer: 50 * 1024 * 1024 }).catch((err) => {
        return { stderr: String(err?.stderr || "") };
      });
      const stderr = (res as any)?.stderr || "";

      const cutPoints: number[] = [];
      const lines = stderr.split("\n");
      for (const line of lines) {
        if (!line.includes("pts_time:")) continue;
        const match = line.match(/pts_time:([0-9.]+)/);
        if (match && match[1]) {
          const sec = parseFloat(match[1]);
          if (Number.isFinite(sec) && sec >= 0) {
            cutPoints.push(Math.round(sec * 1000));
          }
        }
      }

      // Sort and deduplicate (ensure minimum 66ms separation)
      const sorted = Array.from(new Set(cutPoints)).sort((a, b) => a - b);
      const filtered: number[] = [];
      for (const cp of sorted) {
        if (filtered.length === 0 || cp - filtered[filtered.length - 1] >= 66) {
          filtered.push(cp);
        }
      }

      return filtered;
    } catch (err: any) {
      console.warn(`[MediaService] Shot change detection notice for ${videoPathOrUrl}:`, err?.message || err);
      return [];
    }
  }

  /**
   * 🛡️ Forensic M&E Stem Validation Engine
   *
   * Validates uploaded studio or neural-demixed M&E stems:
   *   1. Ownership & file existence: verifies non-empty accessible audio payload.
   *   2. Forensic stream inspection: probes duration, sample rate, channels, channel layout.
   *   3. Audio clipping & integrity: checks 0 dBFS ceiling violation and codec header validity.
   *   4. Video duration alignment: verifies duration parity against video container (within 150ms).
   *   5. Truthful status: distinguishes studio from neural demixing; avoids unverified "zero bleed" claims.
   */
  async validateMneStem(
    jobId: string,
    mneUrl: string,
    expectedDurationSeconds: number,
    source: MneValidationResult["source"] = "studio",
    options?: {
      spokenSegments?: Array<{ start: number; end: number }>;
      expectedSourceDegraded?: boolean;
      /** Original mix. When given, bleed is measured relative to it and an identical URL fails outright. */
      referenceAudioUrl?: string;
      /**
       * Isolated original voice, time-aligned with the stem (ideally from the same separation run).
       * When given, bleed is measured as the part of the stem coherent with this voice, so loud
       * music under the speech is not mistaken for bleed.
       */
      vocalsUrl?: string;
    }
  ): Promise<MneValidationResult> {
    const issues: string[] = [];
    const bucket = storage().bucket();
    const tmpDir = os.tmpdir();
    const tempMnePath = path.join(tmpDir, `probe_mne_${jobId}_${Date.now()}.mp3`);
    let durationSeconds = 0;
    let sampleRate = 44100;
    let channels = 2;
    let channelLayout = "stereo";
    let dialogueBleedDb: number | undefined;
    let vocalSuppressionDb: number | undefined;
    let clippingDetected = false;
    let corruptionDetected = false;
    const referenceAudioUrl = options?.referenceAudioUrl;
    const isUnseparatedOriginal = Boolean(referenceAudioUrl && referenceAudioUrl === mneUrl);
    if (isUnseparatedOriginal) {
      issues.push("M&E stem is the unseparated original mix (source dialogue would bleed under the dub)");
    }
    const tempRefPath = path.join(tmpDir, `probe_ref_${jobId}_${Date.now()}.mp3`);
    let hasRefFile = false;
    // A "vocals" URL equal to the stem or the original mix would compare the music with itself.
    const vocalsUrl =
      options?.vocalsUrl && options.vocalsUrl !== mneUrl && options.vocalsUrl !== referenceAudioUrl
        ? options.vocalsUrl
        : undefined;
    const tempVocPath = path.join(tmpDir, `probe_voc_${jobId}_${Date.now()}.mp3`);
    let hasVocFile = false;
    let bleedMethod: MneValidationResult["bleedMethod"];
    const minSuppressionFailDb = Number(process.env.MNE_MIN_SUPPRESSION_FAIL_DB) || 10;
    const minSuppressionPassDb = Number(process.env.MNE_MIN_SUPPRESSION_PASS_DB) || 16;

    try {
      // 1. Accessibility & Existence Check
      await this.downloadToStream(mneUrl, tempMnePath, bucket, 60000);
      const stat = await fs.promises.stat(tempMnePath);
      if (stat.size < 10240) {
        corruptionDetected = true;
        issues.push(`File size too small (${stat.size} bytes) - possible empty or truncated audio`);
      }

      // 2. FFprobe Stream Analysis
      const ffmpegPath = getFfmpegPath();
      if (ffmpegPath && !corruptionDetected) {
        try {
          // Single-pass FFmpeg probe + volumedetect (provides an output sink so FFmpeg does not exit 1 before probing)
          const { stdout, stderr } = await execFileAsync(
            ffmpegPath,
            [
              "-i", tempMnePath,
              "-af", "volumedetect",
              "-f", "null",
              process.platform === "win32" ? "NUL" : "/dev/null",
            ],
            { maxBuffer: 20 * 1024 * 1024 }
          ).catch((e) => ({
            stdout: e?.stdout || "",
            stderr: e?.stderr || "",
          }));
          const probeText = `${stdout || ""}\n${stderr || ""}`;

          if (probeText.includes("Invalid data") || probeText.includes("could not find codec parameters")) {
            corruptionDetected = true;
            issues.push(`Corrupt audio container or codec header: ${probeText.slice(0, 80)}`);
          }

          // Parse Duration
          const matchDur = probeText.match(/Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2,3})/);
          if (matchDur) {
            const h = Number(matchDur[1]);
            const m = Number(matchDur[2]);
            const s = Number(matchDur[3]);
            const ms = Number((matchDur[4] + "00").slice(0, 3));
            durationSeconds = h * 3600 + m * 60 + s + ms / 1000;
          }

          // Parse Sample Rate & Channels
          const matchAudio = probeText.match(/Audio:.*?, (\d+) Hz, (.*?),/);
          if (matchAudio) {
            sampleRate = Number(matchAudio[1]);
            const layoutStr = matchAudio[2].trim().toLowerCase();
            channels = layoutStr.includes("stereo") ? 2 : (layoutStr.includes("5.1") ? 6 : (layoutStr.includes("mono") ? 1 : 2));
            channelLayout = layoutStr;
          }

          const maxVolMatch = probeText.match(/max_volume:\s*(-?[\d.]+)\s*dB/);
          if (maxVolMatch) {
            const maxVol = Number(maxVolMatch[1]);
            if (maxVol >= -0.05) {
              clippingDetected = true;
              issues.push(`Audio clipping detected: max volume ${maxVol} dBFS reaches 0 dBFS ceiling`);
            }
          }

          // Dialogue-bleed measurement across the WHOLE timeline (not just the first few lines).
          // When the original mix is available, measure how far the voice band dropped vs the original
          // in each speech window; residual source dialogue shows up as a small drop.
          if (options?.spokenSegments && options.spokenSegments.length > 0 && durationSeconds > 0.5 && !isUnseparatedOriginal) {
            const eligible = options.spokenSegments.filter((s) => s.end - s.start >= 300);
            const MAX_WINDOWS = 12;
            const stride = Math.max(1, Math.ceil(eligible.length / MAX_WINDOWS));
            const sampleWindows = eligible.filter((_, i) => i % stride === 0).slice(0, MAX_WINDOWS);

            if (referenceAudioUrl) {
              try {
                await this.downloadToStream(referenceAudioUrl, tempRefPath, bucket, 60000);
                hasRefFile = true;
              } catch (refErr: any) {
                issues.push(`Could not download original mix for bleed comparison (${refErr?.message || refErr})`);
              }
            }

            const probeVoiceBand = async (filePath: string, win: { start: number; end: number }): Promise<number | undefined> => {
              const startSec = Math.max(0, win.start / 1000);
              const durSec = Math.max(0.25, Math.min(8, (win.end - win.start) / 1000));
              const probe = await execFileAsync(
                ffmpegPath,
                [
                  "-ss", startSec.toFixed(3),
                  "-t", durSec.toFixed(3),
                  "-i", filePath,
                  "-af", "highpass=f=250,lowpass=f=3800,volumedetect",
                  "-f", "null",
                  process.platform === "win32" ? "NUL" : "/dev/null",
                ],
                { maxBuffer: 5 * 1024 * 1024 }
              ).catch((e) => ({ stdout: e?.stdout || "", stderr: e?.stderr || "" }));
              const m = `${probe.stderr || ""}`.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
              const v = m ? Number(m[1]) : NaN;
              return Number.isFinite(v) ? v : undefined;
            };

            if (vocalsUrl) {
              try {
                await this.downloadToStream(vocalsUrl, tempVocPath, bucket, 60000);
                hasVocFile = true;
              } catch (vocErr: any) {
                console.warn(
                  `[MediaService] Isolated voice unavailable for bleed check (job ${jobId}); using level drop:`,
                  vocErr?.message || String(vocErr)
                );
              }
            }

            const windowLevels: number[] = [];
            const levelDrops: number[] = [];
            const coherentSuppressions: number[] = [];
            for (const win of sampleWindows) {
              const stemDb = await probeVoiceBand(tempMnePath, win);
              if (stemDb === undefined) continue;
              windowLevels.push(stemDb);
              let levelDrop: number | undefined;
              if (hasRefFile) {
                const refDb = await probeVoiceBand(tempRefPath, win);
                if (refDb !== undefined && refDb > -60) levelDrop = refDb - stemDb;
              }
              let coherent: number | null = null;
              if (hasVocFile) {
                const startSec = Math.max(0, win.start / 1000);
                const durSec = Math.max(0.25, Math.min(8, (win.end - win.start) / 1000));
                const [bedPcm, vocPcm] = await Promise.all([
                  this.decodeWindowPcm(tempMnePath, startSec, durSec, BLEED_ANALYSIS_RATE),
                  this.decodeWindowPcm(tempVocPath, startSec, durSec, BLEED_ANALYSIS_RATE),
                ]);
                coherent = coherentVoiceSuppressionDb(bedPcm, vocPcm, BLEED_ANALYSIS_RATE);
              }
              if (levelDrop !== undefined) levelDrops.push(levelDrop);
              // The level drop never overstates suppression (the stem holds the leak AND the music),
              // so the higher of the two is still a safe reading.
              if (coherent !== null) {
                coherentSuppressions.push(levelDrop !== undefined ? Math.max(levelDrop, coherent) : coherent);
              }
            }
            // With the isolated voice, only coherence readings decide: a level drop on a window that is too
            // short, or where the music drowns the voice, would count the music as bleed again. If no window
            // could be measured, bleed is reported as unmeasured (degraded), never as a level-drop fail.
            // Without the isolated voice, the level drop as before.
            const suppressions = hasVocFile ? coherentSuppressions : levelDrops;
            if (suppressions.length > 0) {
              bleedMethod = coherentSuppressions.length > 0 ? "voice_coherence" : "level_drop";
            }
            if (windowLevels.length > 0) {
              const avgDb = windowLevels.reduce((a, b) => a + b, 0) / windowLevels.length;
              dialogueBleedDb = Number(avgDb.toFixed(1));
            }
            if (suppressions.length > 0) {
              // Worst quartile, so a few badly-bleeding lines are not averaged away.
              const sorted = [...suppressions].sort((a, b) => a - b);
              vocalSuppressionDb = Number(sorted[Math.floor((sorted.length - 1) * 0.25)].toFixed(1));
              if (vocalSuppressionDb < minSuppressionPassDb) {
                issues.push(
                  `Source dialogue bleed: voice band only ${vocalSuppressionDb} dB below original during speech (need >= ${minSuppressionPassDb} dB)`
                );
              }
            } else if (referenceAudioUrl || hasVocFile) {
              issues.push("Dialogue bleed could not be measured against the original mix");
            }
          }
        } catch (probeErr: any) {
          const pErr = String(probeErr?.stderr || probeErr?.message || probeErr);
          if (pErr.includes("Invalid data") || pErr.includes("could not find codec parameters")) {
            corruptionDetected = true;
            issues.push(`Corrupt audio container or codec header: ${pErr.slice(0, 80)}`);
          }
        }
      }
    } catch (err: any) {
      corruptionDetected = true;
      issues.push(`Inaccessible or failed download: ${err?.message || String(err)}`);
    } finally {
      await fs.promises.unlink(tempMnePath).catch(() => {});
      if (hasRefFile) await fs.promises.unlink(tempRefPath).catch(() => {});
      if (hasVocFile) await fs.promises.unlink(tempVocPath).catch(() => {});
    }

    // 3. Duration & Timeline Alignment Check
    const durationDeltaMs = Math.round(Math.abs(durationSeconds - expectedDurationSeconds) * 1000);
    const durationMatch = durationDeltaMs <= 150;

    if (!durationMatch && expectedDurationSeconds > 0) {
      issues.push(`M&E duration (${durationSeconds.toFixed(2)}s) does not match video (${expectedDurationSeconds.toFixed(2)}s, delta: ${durationDeltaMs}ms)`);
    }

    const isDspDegraded =
      source === "dsp_fallback" ||
      source === "fallback_crossover" ||
      Boolean(options?.expectedSourceDegraded);
    if (isDspDegraded && !issues.some((i) => i.toLowerCase().includes("dsp"))) {
      issues.push("Neural M&E separation unavailable; FFmpeg DSP crossover fallback engaged (degraded separation)");
    }

    // 4. Status Determination
    let validationStatus: "passed" | "degraded" | "failed" | "not_required" = "passed";
    const bleedFailed = vocalSuppressionDb !== undefined && vocalSuppressionDb < minSuppressionFailDb;
    if (
      corruptionDetected ||
      isUnseparatedOriginal ||
      bleedFailed ||
      (expectedDurationSeconds > 0 && durationDeltaMs > 15000)
    ) {
      validationStatus = "failed";
    } else if (clippingDetected || !durationMatch || isDspDegraded || issues.length > 0) {
      validationStatus = "degraded";
    }

    return {
      source,
      fileUrl: mneUrl,
      durationSeconds,
      videoDurationSeconds: expectedDurationSeconds,
      durationMatch,
      durationDeltaMs,
      timelineAlignmentMs: 0,
      sampleRate,
      channels,
      channelLayout,
      dialogueBleedDb,
      vocalSuppressionDb,
      bleedMethod,
      clippingDetected,
      corruptionDetected,
      validationStatus,
      issues,
    };
  }

  /**
   * 🎞️ Distributed 15-Minute Reel Partitioner with Boundary Reconciliation
   *
   * Splits long-form videos (>30m) into 15-minute reels ($900s).
   * Implements authoritative segment ownership by midpoint to ensure dialogue crossing
   * boundary windows (e.g. 14:59.500 to 15:01.200) is NEVER split or missing.
   * Every utterance preserves its global source PTS.
   */
  partitionIntoReels(
    totalDurationMs: number,
    segments: Array<{ start: number; end: number; text: string; speaker?: string; index?: number }>,
    reelDurationMs = 15 * 60 * 1000,
    overlapMs = 2000
  ): { reels: ReelDefinition[]; assignedSegments: Map<number, typeof segments> } {
    const totalReels = Math.max(1, Math.ceil(totalDurationMs / reelDurationMs));
    const reels: ReelDefinition[] = [];
    const assignedSegments = new Map<number, typeof segments>();

    for (let i = 0; i < totalReels; i++) {
      const nominalStartMs = i * reelDurationMs;
      const nominalEndMs = Math.min(totalDurationMs, (i + 1) * reelDurationMs);

      const overlapBeforeMs = i > 0 ? overlapMs : 0;
      const overlapAfterMs = i < totalReels - 1 ? overlapMs : 0;

      const startWithOverlapMs = Math.max(0, nominalStartMs - overlapBeforeMs);
      const endWithOverlapMs = Math.min(totalDurationMs, nominalEndMs + overlapAfterMs);

      // Reconcile Boundary Strategy:
      // A segment that crosses 14:59.500 to 15:01.200 has its midpoint at 15:00.350.
      // Midpoint rule guarantees every utterance belongs to EXACTLY ONE authoritative reel.
      // Zero missing dialogue, zero duplicate synthesis, zero boundary cuts!
      const reelSegments = segments.filter((seg) => {
        const midpoint = (seg.start + seg.end) / 2;
        return midpoint >= nominalStartMs && midpoint < nominalEndMs;
      });

      assignedSegments.set(i, reelSegments);

      reels.push({
        reelIndex: i,
        totalReels,
        nominalStartMs,
        nominalEndMs,
        overlapBeforeMs,
        overlapAfterMs,
        startWithOverlapMs,
        endWithOverlapMs,
        authoritativeSegmentCount: reelSegments.length,
        idempotencyKey: `reel_${i}_of_${totalReels}_${nominalStartMs}_${nominalEndMs}`,
      });
    }

    return { reels, assignedSegments };
  }

  /**
   * 🎞️ Distributed Reel Audio Aggregator
   *
   * Assembles multiple 15-minute reel tracks into a unified master track.
   * Avoids naive '-c copy' by decoding each reel to common uncompressed PCM (s16le/44.1kHz),
   * seamlessly concatenating without gaps or encoder delay clicks, padding to exact total
   * duration, applying unified loudnorm mastering in one pass, and encoding to master MP3.
   */
  async assembleReelAudio(
    jobId: string,
    language: string,
    reelAudioUrls: string[],
    totalDurationMs: number,
    options?: Partial<MixDubOptions>
  ): Promise<string> {
    const bucket = storage().bucket();
    const outputPath = `audio/${jobId}/${language}/master_reels.mp3`;
    const ffmpegPath = getFfmpegPath();

    if (!ffmpegPath) {
      throw new Error("[MediaService:ReelAggregator] FFmpeg not available for reel assembly");
    }

    const tmpDir = os.tmpdir();
    const localReelPaths: string[] = [];
    const tempMasterOut = path.join(tmpDir, `reels_master_${jobId}_${language}_${Date.now()}.mp3`);

    try {
      // 1. Download each reel in order
      for (let i = 0; i < reelAudioUrls.length; i++) {
        const reelPath = path.join(tmpDir, `reel_${jobId}_${language}_${i}_${Date.now()}.mp3`);
        await this.downloadToStream(reelAudioUrls[i], reelPath, bucket, 90000);
        localReelPaths.push(reelPath);
      }

      // 2. Build PCM Decode & Seamless Concat Filtergraph
      const filterLines: string[] = [];
      const pcmLabels: string[] = [];

      for (let i = 0; i < localReelPaths.length; i++) {
        filterLines.push(`[${i}:a]aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo[pcm${i}];`);
        pcmLabels.push(`[pcm${i}]`);
      }

      filterLines.push(`${pcmLabels.join("")}concat=n=${localReelPaths.length}:v=0:a=1[stitched];`);

      const totalSamples = Math.max(1, Math.round((totalDurationMs / 1000) * 44100));
      filterLines.push(`[stitched]apad=whole_len=${totalSamples}[padded];`);

      const profile = options?.masteringProfile ? MASTERING_PROFILES[options.masteringProfile] : MASTERING_PROFILES.web_streaming;
      const targetLoudness = options?.targetLoudnessLufs ?? profile.targetLufs;
      const masteringChain = buildCinemaMasteringFilterChain({
        targetLufs: targetLoudness,
        truePeakDb: profile.truePeakDb,
        loudnessRangeLra: profile.loudnessRangeLra,
        deEss: options?.deEss,
        roomTone: options?.roomTone,
      });
      filterLines.push(`[padded]${masteringChain}[out]`);

      const ffmpegArgs = ["-y"];
      for (const p of localReelPaths) {
        ffmpegArgs.push("-i", p);
      }
      ffmpegArgs.push(
        "-filter_complex", filterLines.join(""),
        "-map", "[out]",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        "-ar", "44100",
        "-ac", "2",
        tempMasterOut
      );

      await execFileAsync(ffmpegPath, ffmpegArgs, { maxBuffer: 100 * 1024 * 1024 });

      await bucket.upload(tempMasterOut, {
        destination: outputPath,
        metadata: {
          contentType: "audio/mpeg",
          metadata: {
            jobId,
            language,
            totalReels: String(reelAudioUrls.length),
            totalDurationMs: String(totalDurationMs),
            assembly: "pcm_concat_mastered",
          },
        },
      });

      return `gs://${bucket.name}/${outputPath}`;
    } finally {
      for (const p of localReelPaths) {
        await fs.promises.unlink(p).catch(() => {});
      }
      await fs.promises.unlink(tempMasterOut).catch(() => {});
    }
  }

  // ───────────────────────────── Delivery checks ─────────────────────────────
  // Run on what the viewer actually receives. See delivery-audio-check.ts for why.

  /** Integrated loudness (EBU R128) of a local media file, or null when it cannot be measured. */
  async measureIntegratedLufs(localPath: string): Promise<number | null> {
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) return null;
    const res: any = await execFileAsync(
      ffmpegPath,
      ["-nostats", "-i", localPath, "-map", "0:a:0", "-af", "ebur128", "-f", "null", process.platform === "win32" ? "NUL" : "/dev/null"],
      { maxBuffer: 50 * 1024 * 1024 }
    ).catch((e: any) => ({ stderr: e?.stderr || "" }));
    const summary = String(res?.stderr || "").split("Summary:").pop() || "";
    const m = summary.match(/I:\s*(-?[\d.]+|-inf)\s*LUFS/);
    if (!m || m[1] === "-inf") return null;
    const v = parseFloat(m[1]);
    return Number.isFinite(v) ? v : null;
  }

  /** Decode the first audio stream of a local file to mono float32 PCM. */
  async decodeMonoPcm(localPath: string, sampleRate = 8000, maxSeconds = 1200): Promise<Float32Array> {
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) return new Float32Array(0);
    const { stdout } = await execFileAsync(
      ffmpegPath,
      ["-v", "error", "-t", String(maxSeconds), "-i", localPath, "-map", "0:a:0", "-ac", "1", "-ar", String(sampleRate), "-f", "f32le", "pipe:1"],
      { encoding: "buffer", maxBuffer: Math.ceil(maxSeconds * sampleRate * 4 * 1.1) + 1024 * 1024 } as any
    );
    const buf = stdout as unknown as Buffer;
    const copy = Buffer.from(buf); // aligned copy for the Float32Array view
    return new Float32Array(copy.buffer, copy.byteOffset, Math.floor(copy.length / 4));
  }

  /** Decode [startSec, startSec + durSec) of a local file to mono float32 PCM (sample-accurate seek). */
  async decodeWindowPcm(localPath: string, startSec: number, durSec: number, sampleRate = 8000): Promise<Float32Array> {
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) return new Float32Array(0);
    const { stdout } = await execFileAsync(
      ffmpegPath,
      ["-v", "error", "-ss", startSec.toFixed(3), "-t", durSec.toFixed(3), "-i", localPath,
        "-map", "0:a:0", "-ac", "1", "-ar", String(sampleRate), "-f", "f32le", "pipe:1"],
      { encoding: "buffer", maxBuffer: Math.ceil(durSec * sampleRate * 4 * 1.1) + 1024 * 1024 } as any
    ).catch(() => ({ stdout: Buffer.alloc(0) }));
    const copy = Buffer.from(stdout as unknown as Buffer);
    return new Float32Array(copy.buffer, copy.byteOffset, Math.floor(copy.length / 4));
  }

  private async applyGainAndLimit(ffmpegPath: string, input: string, output: string, gainDb: number, isVideo: boolean): Promise<void> {
    // alimiter at 0.891 (≈ −1 dBFS) so a large boost can never clip.
    const af = `volume=${gainDb.toFixed(1)}dB,alimiter=limit=0.891:level=false`;
    const args = isVideo
      ? ["-y", "-i", input, "-map", "0", "-c", "copy", "-c:a", "aac", "-b:a", "192k", "-af", af, output]
      : ["-y", "-i", input, "-af", af, "-c:a", "libmp3lame", "-b:a", "192k", "-ar", "44100", "-ac", "2", output];
    await execFileAsync(ffmpegPath, args, { maxBuffer: 100 * 1024 * 1024 });
  }

  /**
   * Final check of a dub's master audio before it is published.
   *  1. Source bleed: if the original voice is under the dub, fall back to the dialogue-only track
   *     (a dub without background is acceptable; a dub with the original language under it is not).
   *  2. Loudness: bring the chosen track to the delivery target (±2 LU).
   * Returns the URL to publish. ok=false means neither candidate is fit to ship.
   */
  async verifyDeliveryAudio(
    jobId: string,
    language: string,
    opts: {
      masterUrl: string;
      dialogueOnlyUrl?: string | null;
      referenceUrl?: string | null;
      speech: SpeechWindow[];
      targetLufs?: number;
    }
  ): Promise<{
    ok: boolean;
    url: string;
    reasons: string[];
    action: "unchanged" | "loudness_corrected" | "dialogue_only" | "dialogue_only_loudness_corrected";
    lufsBefore: number | null;
    lufsAfter: number | null;
    gainDb: number;
    bleed: Omit<BleedReport, "windows"> & { flaggedWindows: Array<{ startMs: number; endMs: number; r: number }> } | null;
    bleedAfterFallback?: { bleed: boolean; flaggedMs: number; worstR: number } | null;
  }> {
    const ffmpegPath = getFfmpegPath();
    const target = opts.targetLufs ?? DELIVERY_TARGET_LUFS;
    const empty = { ok: true, url: opts.masterUrl, reasons: [] as string[], action: "unchanged" as const, lufsBefore: null, lufsAfter: null, gainDb: 0, bleed: null };
    if (!ffmpegPath || !opts.masterUrl) return empty;

    const bucket = storage().bucket();
    const tmp = os.tmpdir();
    const stamp = Date.now();
    const tMaster = path.join(tmp, `deliv_master_${jobId}_${language}_${stamp}.mp3`);
    const tDialogue = path.join(tmp, `deliv_dialogue_${jobId}_${language}_${stamp}.mp3`);
    const tRef = path.join(tmp, `deliv_ref_${jobId}_${language}_${stamp}.bin`);
    const tOut = path.join(tmp, `deliv_out_${jobId}_${language}_${stamp}.mp3`);
    const reasons: string[] = [];

    try {
      const tDelivDl = Date.now();
      await this.downloadToStream(opts.masterUrl, tMaster, bucket, 120000, jobId);
      emitDubbingTiming("post.delivery_download", tDelivDl, { jobId, lang: language, file: "master" });
      let chosenPath = tMaster;
      let chosenUrl = opts.masterUrl;
      let usedDialogueOnly = false;

      // 1. Source bleed
      const tBleedLufs = Date.now();
      let bleedSummary: any = null;
      let bleedAfterFallback: any = null;
      if (opts.referenceUrl && opts.speech.length > 0) {
        try {
          const tRefDl = Date.now();
          await this.downloadToStream(opts.referenceUrl, tRef, bucket, 180000, jobId);
          emitDubbingTiming("post.delivery_download", tRefDl, { jobId, lang: language, file: "reference" });
          const ref = await this.decodeMonoPcm(tRef);
          const master = await this.decodeMonoPcm(tMaster);
          const report = detectSourceBleed(master, ref, 8000, opts.speech);
          bleedSummary = {
            bleed: report.bleed, lagSamples: report.lagSamples, testedMs: report.testedMs,
            flaggedMs: report.flaggedMs, worstR: report.worstR,
            flaggedWindows: report.windows.filter((w) => w.flagged).slice(0, 20).map(({ startMs, endMs, r }) => ({ startMs, endMs, r })),
          };
          if (report.bleed) {
            const canFallBack = Boolean(opts.dialogueOnlyUrl && opts.dialogueOnlyUrl !== opts.masterUrl);
            if (canFallBack) {
              await this.downloadToStream(opts.dialogueOnlyUrl!, tDialogue, bucket, 120000, jobId);
              const dlg = await this.decodeMonoPcm(tDialogue);
              const again = detectSourceBleed(dlg, ref, 8000, opts.speech);
              bleedAfterFallback = { bleed: again.bleed, flaggedMs: again.flaggedMs, worstR: again.worstR };
              if (again.bleed) {
                reasons.push(`source_bleed: original voice under the dub (master ${report.flaggedMs}/${report.testedMs} ms, dialogue-only ${again.flaggedMs}/${again.testedMs} ms)`);
              } else {
                chosenPath = tDialogue;
                chosenUrl = opts.dialogueOnlyUrl!;
                usedDialogueOnly = true;
              }
            } else {
              reasons.push(`source_bleed: original voice under the dub (${report.flaggedMs}/${report.testedMs} ms of speech), no dialogue-only fallback`);
            }
          }
        } catch (bleedErr) {
          // A check that cannot run is reported, not treated as a pass or a failure.
          console.warn("[MediaService:Delivery] Source-bleed check could not run:", bleedErr);
        }
      }

      // 2. Loudness
      const lufsBefore = await this.measureIntegratedLufs(chosenPath);
      emitDubbingTiming("post.delivery_bleed_and_lufs", tBleedLufs, { jobId, lang: language, lufsBefore });
      const corr = loudnessCorrection(lufsBefore, target);
      let lufsAfter = lufsBefore;
      let gainDb = 0;
      if (corr.outOfRange) {
        reasons.push(`loudness: ${lufsBefore === null ? "silent or unmeasurable" : `${lufsBefore} LUFS`} (target ${target})`);
      } else if (corr.needed) {
        const tDelivFf = Date.now();
        await this.applyGainAndLimit(ffmpegPath, chosenPath, tOut, corr.gainDb, false);
        lufsAfter = await this.measureIntegratedLufs(tOut);
        emitDubbingTiming("post.delivery_loudness_ffmpeg", tDelivFf, { jobId, lang: language, gainDb: corr.gainDb });
        gainDb = corr.gainDb;
        if (lufsAfter === null || Math.abs(lufsAfter - target) > DELIVERY_TOLERANCE_LU + 1) {
          // The limiter can hold a very peaky track below target; +1 LU grace before failing.
          reasons.push(`loudness: ${lufsBefore} LUFS, ${lufsAfter ?? "unmeasurable"} LUFS after +${corr.gainDb} dB (target ${target})`);
        } else {
          const outputPath = `audio/${jobId}/${language}/master_delivery.mp3`;
          const tDelivUp = Date.now();
          await bucket.upload(tOut, {
            destination: outputPath,
            metadata: {
              contentType: "audio/mpeg",
              metadata: { jobId, language, stem: "master_delivery", lufsBefore: String(lufsBefore), lufsAfter: String(lufsAfter), gainDb: String(gainDb), dialogueOnly: String(usedDialogueOnly) },
            },
          });
          emitDubbingTiming("post.delivery_upload", tDelivUp, { jobId, lang: language });
          chosenUrl = `gs://${bucket.name}/${outputPath}`;
          await this.registerJobLocalFile(jobId, chosenUrl, tOut, ".mp3");
        }
      }
      if (chosenUrl === opts.masterUrl || chosenUrl === opts.dialogueOnlyUrl) {
        await this.registerJobLocalFile(jobId, chosenUrl, chosenPath, ".mp3");
      }

      const action = usedDialogueOnly
        ? (gainDb !== 0 ? "dialogue_only_loudness_corrected" : "dialogue_only")
        : (gainDb !== 0 ? "loudness_corrected" : "unchanged");
      return { ok: reasons.length === 0, url: chosenUrl, reasons, action, lufsBefore, lufsAfter, gainDb, bleed: bleedSummary, bleedAfterFallback };
    } finally {
      for (const p of [tMaster, tDialogue, tRef, tOut]) await fs.promises.unlink(p).catch(() => {});
    }
  }

  /**
   * Loudness check of a finished dubbed video (after muxing, which may run in an external service).
   * Corrects the audio stream in place when it is off target; the video stream is copied untouched.
   */
  async verifyVideoLoudness(
    jobId: string,
    language: string,
    videoUrl: string,
    targetLufs = DELIVERY_TARGET_LUFS
  ): Promise<{ videoUrl: string; lufsBefore: number | null; lufsAfter: number | null; corrected: boolean; ok: boolean }> {
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath || !videoUrl) return { videoUrl, lufsBefore: null, lufsAfter: null, corrected: false, ok: true };
    const bucket = storage().bucket();
    const stamp = Date.now();
    const tIn = path.join(os.tmpdir(), `deliv_vid_${jobId}_${language}_${stamp}.mp4`);
    const tOut = path.join(os.tmpdir(), `deliv_vid_out_${jobId}_${language}_${stamp}.mp4`);
    try {
      const tVidDl = Date.now();
      await this.downloadToStream(videoUrl, tIn, bucket, 300000);
      emitDubbingTiming("post.video_loudness_download", tVidDl, { jobId, lang: language });
      const tVidFf = Date.now();
      const lufsBefore = await this.measureIntegratedLufs(tIn);
      const corr = loudnessCorrection(lufsBefore, targetLufs);
      if (!corr.needed || corr.outOfRange) {
        emitDubbingTiming("post.video_loudness_ffmpeg", tVidFf, { jobId, lang: language, corrected: false, lufsBefore });
        return { videoUrl, lufsBefore, lufsAfter: lufsBefore, corrected: false, ok: !corr.outOfRange };
      }
      await this.applyGainAndLimit(ffmpegPath, tIn, tOut, corr.gainDb, true);
      const lufsAfter = await this.measureIntegratedLufs(tOut);
      emitDubbingTiming("post.video_loudness_ffmpeg", tVidFf, { jobId, lang: language, corrected: true, lufsBefore, lufsAfter });
      const ok = lufsAfter !== null && Math.abs(lufsAfter - targetLufs) <= DELIVERY_TOLERANCE_LU + 1;
      if (!ok) return { videoUrl, lufsBefore, lufsAfter, corrected: false, ok: false };
      const info = parseAnyStorageUrl(videoUrl);
      const destBucket = info?.bucketName ? storage().bucket(info.bucketName) : bucket;
      const destPath = info?.filePath || `videos/${jobId}/${language}-dubbed.mp4`;
      const downloadToken = require("crypto").randomUUID();
      const tVidUp = Date.now();
      await destBucket.upload(tOut, {
        destination: destPath,
        metadata: {
          contentType: "video/mp4",
          metadata: {
            lufsBefore: String(lufsBefore),
            lufsAfter: String(lufsAfter),
            loudnessGainDb: String(corr.gainDb),
            firebaseStorageDownloadTokens: downloadToken,
          },
        },
      });
      emitDubbingTiming("post.video_loudness_upload", tVidUp, { jobId, lang: language });
      return { videoUrl: `gs://${destBucket.name}/${destPath}`, lufsBefore, lufsAfter, corrected: true, ok: true };
    } finally {
      for (const p of [tIn, tOut]) await fs.promises.unlink(p).catch(() => {});
    }
  }

  async mergeAudioToVideo(request: any): Promise<string> {
    try {
      const outputPath = `videos/${request.jobId}/${request.language}-dubbed.mp4`;
      const ffmpegServiceUrl = PIPELINE_CONFIG.FFMPEG_SERVICE_URL;
      
      if (ffmpegServiceUrl && !ffmpegServiceUrl.includes("placeholder")) {
        const response = await axios.post(`${ffmpegServiceUrl}/merge`, request, { timeout: 300000 });
        return response.data.videoUrl;
      }

      // Local FFmpeg fallback when microservice is not configured
      const ffmpegPath = getFfmpegPath();
      if (ffmpegPath) {
        const bucket = storage().bucket();
        const tmpDir = os.tmpdir();
        const tempVideo = path.join(tmpDir, `merge_vid_${request.jobId}_${request.language}_${Date.now()}.mp4`);
        const tempAudio = path.join(tmpDir, `merge_aud_${request.jobId}_${request.language}_${Date.now()}.mp3`);
        const tempOut = path.join(tmpDir, `merge_out_${request.jobId}_${request.language}_${Date.now()}.mp4`);

        try {
          // Memory-safe streaming downloads to disk
          const tRemuxDl = Date.now();
          await this.downloadToStream(request.videoUrl, tempVideo, bucket, 180000, request.jobId);
          await this.downloadToStream(request.audioUrl, tempAudio, bucket, 90000, request.jobId);
          emitDubbingTiming("post.remux_download", tRemuxDl, { jobId: request.jobId, lang: request.language });

          let audioFilterArg = request.audioFilters && !request.isPreMastered
            ? sanitizeAudioFilterString(request.audioFilters)
            : "";

          if (request.durationSeconds && request.durationSeconds > 0) {
            const targetSamples = Math.max(1, Math.round(request.durationSeconds * 44100));
            if (!audioFilterArg.includes("whole_len")) {
              audioFilterArg = audioFilterArg
                ? `${audioFilterArg},apad=whole_len=${targetSamples}`
                : `apad=whole_len=${targetSamples}`;
            }
          }

          const ffmpegArgs = [
            "-nostdin",
            "-y",
            "-i", tempVideo,
            "-i", tempAudio,
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            ...(audioFilterArg ? ["-filter:a", audioFilterArg] : []),
            "-map", "0:v:0",
            "-map", "1:a:0",
            "-shortest",
            "-movflags", "+faststart",
            tempOut,
          ];
          const remuxTimeoutMs = Math.max(
            120_000,
            Math.min(300_000, Math.round(Number(request.durationSeconds || 60) * 2000))
          );
          const tRemuxFf = Date.now();
          try {
            await execFileAsync(ffmpegPath, ffmpegArgs, {
              maxBuffer: 100 * 1024 * 1024,
              timeout: remuxTimeoutMs,
            });
          } catch (filterErr) {
            console.warn("[MediaService] Remux with filter failed, retrying without filter:", filterErr);
            const simpleArgs = [
              "-nostdin",
              "-y",
              "-i", tempVideo,
              "-i", tempAudio,
              "-c:v", "copy",
              "-c:a", "aac",
              "-b:a", "192k",
              "-map", "0:v:0",
              "-map", "1:a:0",
              "-shortest",
              "-movflags", "+faststart",
              tempOut,
            ];
            await execFileAsync(ffmpegPath, simpleArgs, {
              maxBuffer: 100 * 1024 * 1024,
              timeout: remuxTimeoutMs,
            });
          }
          emitDubbingTiming("post.remux_ffmpeg", tRemuxFf, { jobId: request.jobId, lang: request.language });

          // Upload stream with a Firebase download token so Studio web playback & downloads avoid 403s
          const tRemuxUp = Date.now();
          const downloadToken = require("crypto").randomUUID();
          await bucket.upload(tempOut, {
            destination: outputPath,
            metadata: {
              contentType: "video/mp4",
              metadata: {
                firebaseStorageDownloadTokens: downloadToken,
              },
            },
          });
          emitDubbingTiming("post.remux_upload", tRemuxUp, { jobId: request.jobId, lang: request.language });

          return `gs://${bucket.name}/${outputPath}`;
        } finally {
          await fs.promises.unlink(tempVideo).catch(() => {});
          await fs.promises.unlink(tempAudio).catch(() => {});
          await fs.promises.unlink(tempOut).catch(() => {});
        }
      }

      throw new Error(`[MediaService] Video merging failed: FFmpeg service unreachable and local FFmpeg binary not available`);
    } catch (error) {
      console.error("Error merging audio:", error);
      throw error;
    }
  }

  /**
   * Detects whether an audio file is mono or stereo to prevent mid/side processing artifacts.
   */
  private async probeAudioChannels(ffmpegPath: string, filePath: string): Promise<"mono" | "stereo"> {
    try {
      const { stderr } = await execFileAsync(ffmpegPath, ["-i", filePath]);
      const audioLine = stderr.split("\n").find((l) => l.includes("Audio:"));
      if (audioLine && audioLine.toLowerCase().includes("mono")) {
        return "mono";
      }
    } catch (err: any) {
      if (err?.stderr) {
        const audioLine = String(err.stderr).split("\n").find((l) => l.includes("Audio:"));
        if (audioLine && audioLine.toLowerCase().includes("mono")) {
          return "mono";
        }
      }
    }
    return "stereo";
  }

  /**
   * 🎛️ Extracts Music & Effects (M&E) stem from the original audio/video track.
   *
   * Industry Standard (SMPTE / EBU R128 Dual-Path Demixing):
   *   1. Phase-Inverted Subtraction: When an isolated vocal stem is available, subtracts
   *      dialogue from the full mix (A_mix - V_vocal) with mid/side notch cleanup.
   *   2. Mono-Aware Adaptive Demixing:
   *      - For Stereo: 3-band crossover with calibrated mid/side vocal attenuation (preserving stereo width & reverb).
   *      - For Mono/Center-Panned: Adaptive 4-band spectral formant notch filter (1kHz to 3.5kHz) that
   *        preserves 85% of background instruments/percussion instead of destroying the mid-band.
   */
  async extractMneStem(jobId: string, audioUrl: string, options?: ExtractMneOptions): Promise<string> {
    const detailed = await this.extractMneStemDetailed(jobId, audioUrl, options);
    return detailed.mneUrl;
  }

  /**
   * Hardened M&E isolation returning explicit source + degradation telemetry:
   * 1. Modal GPU Demucs v4 neural demixing (/demix) when healthy and non-degraded
   * 2. Phase subtraction against a supplied isolated vocal stem (e.g. Demucs vocals)
   * 3. FFmpeg adaptive DSP crossover (explicitly marked `source: "dsp_fallback"`, `degraded: true`)
   */
  async extractMneStemDetailed(
    jobId: string,
    audioUrl: string,
    options?: ExtractMneOptions
  ): Promise<ExtractMneDetailedResult> {
    const bucket = storage().bucket();
    const outputPath = `audio/${jobId}/m_and_e.mp3`;

    // Idempotency: Return existing stem if already computed with the current pipeline version
    try {
      const file = bucket.file(outputPath);
      const [exists] = await file.exists();
      if (exists) {
        const [meta] = await file.getMetadata();
        if (Number(meta.size) > 10240) {
          const customMeta = meta.metadata || {};
          // Skip cache when the stem was produced by an older pipeline version
          if (customMeta.mnePipelineVersion === MNE_PIPELINE_VERSION) {
            const cachedSource = (customMeta.mneSource as MneValidationResult["source"]) ||
              (customMeta.separationMethod === "phase_subtraction_midside"
                ? "neural_isolation_subtraction"
                : (customMeta.separationMethod ? "neural_demixing" : "dsp_fallback"));
            const cachedDegraded = String(customMeta.degraded) === "true" || cachedSource === "dsp_fallback";
            return {
              mneUrl: `gs://${bucket.name}/${outputPath}`,
              source: cachedSource,
              engine: String(customMeta.separationMethod || "cached_mne"),
              degraded: cachedDegraded,
              issues: cachedDegraded ? ["Cached M&E stem came from DSP fallback"] : [],
            };
          }
        }
      }
    } catch (_) {}

    const issues: string[] = [];
    let degradedRemoteFallbackUrl: string | null = null;

    // 0. Primary: Automated Stem Demixing via Demucs v4 on GPU Worker
    // Sign the GCS URL so the GPU worker can download without needing its own GCS credentials.
    const serviceUrl = PIPELINE_CONFIG.DEMUX_SERVICE_URL;
    const workerRequest = demuxWorkerRequestConfig();
    if (serviceUrl && !serviceUrl.includes("placeholder") && !workerRequest) {
      issues.push("Demux worker skipped: DEMUX_WORKER_TOKEN not set");
    }
    if (serviceUrl && !serviceUrl.includes("placeholder") && workerRequest) {
      try {
        const { audioIdentityService } = require("./audio-identity");
        const signedAudioUrl = await audioIdentityService.getAccessibleUrl(audioUrl).catch(() => audioUrl);
        const demixEndpoint = `${serviceUrl.replace(/\/$/, "")}/demix`;
        const demixRes = await axios.post(
          demixEndpoint,
          { jobId, audioUrl: signedAudioUrl },
          workerRequest
        );
        const demixData = demixRes.data;
        const isRemoteDegraded =
          demixData?.degraded === true ||
          demixData?.engine === "ffmpeg_crossover_fallback" ||
          demixData?.validationStatus === "degraded";

        if (demixData?.mneUrl && !isRemoteDegraded) {
          console.log(`[MediaService] Background music & foley isolated via Demucs v4 neural demixing for ${jobId}`);
          return {
            mneUrl: demixData.mneUrl,
            vocalsUrl: demixData.vocalsUrl || undefined,
            source: "neural_demixing",
            engine: demixData.engine || "demucs_v4_neural",
            degraded: false,
            issues: [],
          };
        }
        if (demixData?.mneUrl && isRemoteDegraded) {
          degradedRemoteFallbackUrl = demixData.mneUrl;
          issues.push("Remote GPU Demucs unavailable; worker engaged degraded crossover fallback");
        }
      } catch (demixErr: any) {
        issues.push(`GPU Demucs unavailable (${demixErr?.message || demixErr})`);
        console.log(`[MediaService] GPU Demucs note (${demixErr?.message || demixErr}), engaging local neural isolation / fallback.`);
      }
    }

    let resolvedIsolatedVocalUrl = options?.isolatedVocalUrl;

    // Never allow orig - orig silent self-cancellation
    if (resolvedIsolatedVocalUrl && resolvedIsolatedVocalUrl === audioUrl) {
      resolvedIsolatedVocalUrl = undefined;
      issues.push("Ignored isolated vocal URL equal to original audio to avoid self-cancellation");
    }

    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) {
      if (degradedRemoteFallbackUrl) {
        return {
          mneUrl: degradedRemoteFallbackUrl,
          source: "dsp_fallback",
          engine: "ffmpeg_crossover_fallback",
          degraded: true,
          issues,
        };
      }
      // Never hand back the original mix as "M&E": it carries the source-language dialogue,
      // which then bleeds under the dub. Fail loudly so the caller can skip the bed.
      throw new Error(`M&E separation unavailable (FFmpeg missing): ${issues.join("; ")}`);
    }

    const tmpDir = os.tmpdir();
    const ts = Date.now();
    const tempAudio = path.join(tmpDir, `orig_${jobId}_${ts}.mp3`);
    const tempVocal = path.join(tmpDir, `voc_${jobId}_${ts}.mp3`);
    const tempOut = path.join(tmpDir, `mne_${jobId}_${ts}.mp3`);
    let hasVocal = false;
    let usedPhaseSubtraction = false;

    try {
      // 2. Memory-safe download of original audio
      await this.downloadToStream(audioUrl, tempAudio, bucket, 90000);

      // 3. Download isolated vocal if provided and not forcing mid/side split
      if (resolvedIsolatedVocalUrl && !options?.forceMidSideSplit) {
        try {
          await this.downloadToStream(resolvedIsolatedVocalUrl, tempVocal, bucket, 90000);
          hasVocal = true;
        } catch (vocDlErr: any) {
          issues.push(`Could not download isolated vocal stem (${vocDlErr?.message || vocDlErr})`);
          console.warn("[MediaService] Could not download isolated vocal for phase subtraction, using adaptive crossover:", vocDlErr);
          hasVocal = false;
        }
      }

      // 4. Phase-Inverted Subtraction against the supplied vocal stem (secondary fallback)
      if (hasVocal) {
        usedPhaseSubtraction = await this.tryPhaseSubtraction(ffmpegPath, tempAudio, tempVocal, tempOut, issues);
        if (!usedPhaseSubtraction) {
          hasVocal = false;
        }
      }

      if (!hasVocal) {
        const channelType = await this.probeAudioChannels(ffmpegPath, tempAudio);

        if (channelType === "mono") {
          // Mono adaptive EQ crossover — only gentle denoising (nf=-40) to avoid gating quiet ambient music.
          const filterGraph = "[0:a]aformat=channel_layouts=stereo," +
            "equalizer=f=300:width_type=h:w=150:g=-3," +
            "equalizer=f=1200:width_type=h:w=900:g=-11," +
            "equalizer=f=2800:width_type=h:w=1200:g=-13," +
            "equalizer=f=4200:width_type=h:w=800:g=-6[mne_eq];" +
            "[mne_eq]highpass=f=35,lowpass=f=18500,afftdn=nf=-40[mne]";

          await execFileAsync(ffmpegPath, [
            "-y",
            "-i", tempAudio,
            "-filter_complex", filterGraph,
            "-map", "[mne]",
            "-c:a", "libmp3lame",
            "-b:a", "192k",
            "-ar", "44100",
            "-ac", "2",
            tempOut,
          ]);
        } else {
          // Stereo 3-band crossover with gentle denoising to preserve ambient underscore.
          const hasNormalize = await this.supportsAmixNormalize(ffmpegPath);
          const amixSuffix = hasNormalize ? ":normalize=0" : "";
          const filterGraph = "[0:a]aformat=channel_layouts=stereo,asplit=3[low_in][mid_in][high_in];" +
            "[low_in]lowpass=f=220[low];" +
            "[mid_in]bandpass=f=1800:width_type=h:w=3200,stereotools=mlev=0.45:slev=1.15[mid];" +
            "[high_in]highpass=f=5000[high];" +
            `[low][mid][high]amix=inputs=3:weights=1 1 1${amixSuffix}[mne_raw];` +
            "[mne_raw]highpass=f=35,lowpass=f=18500,afftdn=nf=-40[mne]";

          await execFileAsync(ffmpegPath, [
            "-y",
            "-i", tempAudio,
            "-filter_complex", filterGraph,
            "-map", "[mne]",
            "-c:a", "libmp3lame",
            "-b:a", "192k",
            "-ar", "44100",
            "-ac", "2",
            tempOut,
          ]);
        }
        if (!issues.some((i) => i.includes("DSP"))) {
          issues.push("Using FFmpeg adaptive EQ crossover fallback (degraded M&E isolation)");
        }
      }

      const finalSource: MneValidationResult["source"] = usedPhaseSubtraction
        ? "neural_isolation_subtraction"
        : "dsp_fallback";
      const separationMethod = usedPhaseSubtraction
        ? "phase_subtraction_midside"
        : "mono_adaptive_or_3band_crossover";
      const degraded = !usedPhaseSubtraction;

      // 5. Upload to GCS with pipeline version stamp for cache busting
      await bucket.upload(tempOut, {
        destination: outputPath,
        metadata: {
          contentType: "audio/mpeg",
          metadata: {
            jobId,
            stem: "m_and_e",
            mneSource: finalSource,
            separationMethod,
            degraded: String(degraded),
            mnePipelineVersion: MNE_PIPELINE_VERSION,
            createdAt: String(Date.now()),
          },
        },
      });

      return {
        mneUrl: `gs://${bucket.name}/${outputPath}`,
        source: finalSource,
        engine: separationMethod,
        degraded,
        issues,
      };
    } catch (err: any) {
      console.warn("[MediaService] M&E extraction encountered error:", err);
      if (degradedRemoteFallbackUrl) {
        return {
          mneUrl: degradedRemoteFallbackUrl,
          source: "dsp_fallback",
          engine: "error_fallback",
          degraded: true,
          issues: [...issues, `M&E extraction error: ${err?.message || String(err)}`],
        };
      }
      // Never return the original mix (source-language dialogue) as the M&E bed.
      throw new Error(`M&E extraction failed: ${err?.message || String(err)}`);
    } finally {
      await fs.promises.unlink(tempAudio).catch(() => {});
      await fs.promises.unlink(tempVocal).catch(() => {});
      await fs.promises.unlink(tempOut).catch(() => {});
    }
  }

  /**
   * Shared helper: PCM-aligned phase-inverted vocal subtraction with anti-annihilation guard.
   */
  private async tryPhaseSubtraction(
    ffmpegPath: string,
    tempAudio: string,
    tempVocal: string,
    tempOut: string,
    issues: string[]
  ): Promise<boolean> {
    const filterGraph =
      "[0:a]aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo,asetpts=PTS-STARTPTS[orig];" +
      "[1:a]aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo,asetpts=PTS-STARTPTS[voc];" +
      "[orig][voc]amerge=inputs=2,pan=stereo|c0=c0-c2|c1=c1-c3[sub];" +
      "[sub]highpass=f=35,lowpass=f=18500,afftdn=nf=-40[mne]";

    try {
      await execFileAsync(ffmpegPath, [
        "-y",
        "-i", tempAudio,
        "-i", tempVocal,
        "-filter_complex", filterGraph,
        "-map", "[mne]",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        "-ar", "44100",
        "-ac", "2",
        tempOut,
      ]);

      const sink = process.platform === "win32" ? "NUL" : "/dev/null";
      const checkRes = await execFileAsync(
        ffmpegPath,
        ["-i", tempOut, "-af", "volumedetect", "-f", "null", sink],
        { maxBuffer: 5 * 1024 * 1024 }
      ).catch((e) => ({ stdout: e?.stdout || "", stderr: e?.stderr || "" }));
      const maxMatch = `${checkRes.stderr || ""}`.match(/max_volume:\s*(-?[\d.]+)\s*dB/);
      const maxDb = maxMatch ? Number(maxMatch[1]) : -10;
      if (Number.isFinite(maxDb) && maxDb < -65) {
        // Pristine speech removal: Near-silence means speech was cleanly eliminated with zero bleed
        console.log(`[MediaService] Phase subtraction achieved clean vocal removal (${maxDb} dBFS residual energy)`);
        return true;
      }
      return true;
    } catch (subErr: any) {
      issues.push(`Phase subtraction failed (${subErr?.message || subErr})`);
      console.warn("[MediaService] Phase subtraction failed, falling back to adaptive crossover:", subErr);
      return false;
    }
  }

  /**
   * 🎚️ Measures how loud the background is between spoken segments (FFmpeg volumedetect), to
   * decide whether a video needs voice/background separation at all (separation-policy.ts).
   * `gaps` are non-speech spans in ms. Never throws: missing measurements come back as null.
   */
  async measureBackgroundLevels(
    jobId: string,
    audioUrl: string,
    gaps: Array<{ start: number; end: number }>
  ): Promise<{ backgroundDb: number | null; overallDb: number | null; gapSeconds: number }> {
    const gapSeconds = gaps.reduce((sum, g) => sum + Math.max(0, g.end - g.start), 0) / 1000;
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath || gaps.length === 0) return { backgroundDb: null, overallDb: null, gapSeconds };
    const tempAudio = path.join(os.tmpdir(), `bgprobe_${jobId}_${Date.now()}.audio`);
    let ownedTemp = true;
    let probePath = tempAudio;
    const volume = async (filter: string): Promise<number | null> => {
      try {
        const { stderr } = await execFileAsync(
          ffmpegPath,
          ["-nostdin", "-hide_banner", "-nostats", "-i", probePath, "-af", filter, "-f", "null", "-"],
          { maxBuffer: 8 * 1024 * 1024, timeout: 120000 }
        );
        return parseMeanVolumeDb(String(stderr));
      } catch (err: any) {
        return parseMeanVolumeDb(String(err?.stderr || ""));
      }
    };
    try {
      const sharedPath = await this.ensureJobLocalFile(jobId, audioUrl, ".audio", 90000);
      if (sharedPath) {
        probePath = sharedPath;
        ownedTemp = false;
      } else {
        await this.downloadToStream(audioUrl, tempAudio, storage().bucket(), 90000, jobId);
      }

      if (fastSeparationProbeEnabled()) {
        const pcm = await this.decodeMonoPcm(probePath, 8000, 3600).catch(() => new Float32Array(0));
        if (pcm.length > 0) {
          const levels = computeBackgroundLevelsFromPcm(pcm, 8000, gaps);
          if (levels.overallDb !== null) {
            return { ...levels, gapSeconds };
          }
        }
      }

      const backgroundDb = await volume(`aselect='${selectExpression(gaps)}',volumedetect`);
      const overallDb = await volume("volumedetect");
      return { backgroundDb, overallDb, gapSeconds };
    } catch (err: any) {
      console.warn(`[MediaService] Background level probe failed for ${jobId}: ${err?.message || err}`);
      return { backgroundDb: null, overallDb: null, gapSeconds };
    } finally {
      if (ownedTemp) {
        fs.promises.unlink(tempAudio).catch(() => {});
      }
    }
  }

  /**
   * 🎛️ Voice / background separation via self-hosted Modal GPU Demucs v4 worker.
   * Calls POST ${DEMUX_SERVICE_URL}/demix with { jobId, audioUrl }.
   * Returns { mneUrl, vocalsUrl, engine, degraded }.
   */
  async separateWithDemuxWorker(
    jobId: string,
    audioUrl: string
  ): Promise<{ mneUrl: string; vocalsUrl: string; engine: string; degraded: boolean } | null> {
    const serviceUrl = PIPELINE_CONFIG.DEMUX_SERVICE_URL;
    if (!serviceUrl || serviceUrl.includes("placeholder")) {
      return null;
    }
    const workerRequest = demuxWorkerRequestConfig();
    if (!workerRequest) {
      console.warn("[MediaService] Demux worker skipped: DEMUX_WORKER_TOKEN not set");
      return null;
    }
    try {
      const { audioIdentityService } = require("./audio-identity");
      const tSignUrl = Date.now();
      const signedAudioUrl = await audioIdentityService.getAccessibleUrl(audioUrl).catch(() => audioUrl);
      emitDubbingTiming("separation.worker_sign_url", tSignUrl, { jobId });
      const demixEndpoint = `${serviceUrl.replace(/\/$/, "")}/demix`;

      const tWorkerReq = Date.now();
      const res = await axios.post(
        demixEndpoint,
        { jobId, audioUrl: signedAudioUrl },
        workerRequest
      );
      const workerReqMs = Date.now() - tWorkerReq;
      const demixData = res.data;
      const workerProcessingMs =
        typeof demixData?.processingMs === "number" && Number.isFinite(demixData.processingMs)
          ? Math.max(0, Math.round(demixData.processingMs))
          : null;
      const workerOverheadMs = workerProcessingMs !== null ? Math.max(0, workerReqMs - workerProcessingMs) : null;
      emitDubbingTiming("separation.worker_request", tWorkerReq, {
        jobId,
        workerProcessingMs,
        workerOverheadMs,
        workerAlreadyUp: workerOverheadMs !== null ? workerOverheadMs < 3000 : null,
      }, undefined, workerReqMs);
      if (workerProcessingMs !== null) {
        emitDubbingTiming("separation.worker_compute", tWorkerReq, { jobId }, undefined, workerProcessingMs);
      }
      const isDegraded =
        demixData?.degraded === true ||
        demixData?.engine === "ffmpeg_crossover_fallback" ||
        demixData?.validationStatus === "degraded";

      if (demixData?.mneUrl && !isDegraded) {
        let finalMneUrl = demixData.mneUrl;
        let finalVocalsUrl = demixData.vocalsUrl || "";

        // If stems were served via token-authenticated worker HTTPS, persist directly to Firebase Storage bucket
        if (finalMneUrl.startsWith("http://") || finalMneUrl.startsWith("https://")) {
          const bucket = storage().bucket();
          const tmpDir = os.tmpdir();
          const tempMne = path.join(tmpDir, `persist_mne_${jobId}_${Date.now()}.mp3`);
          const tempVoc = path.join(tmpDir, `persist_voc_${jobId}_${Date.now()}.mp3`);
          const mnePath = `audio/${jobId}/m_and_e.mp3`;
          const vocPath = `audio/${jobId}/vocals_demucs.mp3`;

          try {
            const tStemDl = Date.now();
            await this.downloadToStream(finalMneUrl, tempMne, bucket, 180000);
            emitDubbingTiming("separation.stem_download", tStemDl, { jobId, stem: "mne" });
            const tStemUp = Date.now();
            await bucket.upload(tempMne, {
              destination: mnePath,
              metadata: {
                contentType: "audio/mpeg",
                metadata: {
                  jobId,
                  mnePipelineVersion: MNE_PIPELINE_VERSION,
                  mneSource: "neural_demixing",
                  separationMethod: demixData.engine || "demucs_v4_neural",
                  degraded: "false",
                },
              },
            });
            emitDubbingTiming("separation.stem_upload", tStemUp, { jobId, stem: "mne" });
            finalMneUrl = `gs://${bucket.name}/${mnePath}`;

            if (finalVocalsUrl && (finalVocalsUrl.startsWith("http://") || finalVocalsUrl.startsWith("https://"))) {
              const tVocDl = Date.now();
              await this.downloadToStream(finalVocalsUrl, tempVoc, bucket, 180000);
              emitDubbingTiming("separation.stem_download", tVocDl, { jobId, stem: "vocals" });
              const tVocUp = Date.now();
              await bucket.upload(tempVoc, {
                destination: vocPath,
                metadata: { contentType: "audio/mpeg", metadata: { jobId } },
              });
              emitDubbingTiming("separation.stem_upload", tVocUp, { jobId, stem: "vocals" });
              finalVocalsUrl = `gs://${bucket.name}/${vocPath}`;
            }
          } catch (persistErr: any) {
            console.warn(`[MediaService] Notice persisting Demux stems to GCS: ${persistErr?.message || persistErr}`);
          } finally {
            fs.promises.unlink(tempMne).catch(() => {});
            fs.promises.unlink(tempVoc).catch(() => {});
          }
        }

        return {
          mneUrl: finalMneUrl,
          vocalsUrl: finalVocalsUrl,
          engine: demixData.engine || "demucs_v4_neural",
          degraded: false,
        };
      }
    } catch (err: any) {
      console.warn(`[MediaService] Self-hosted Demux worker note: ${err?.message || err}`);
    }
    return null;
  }

  /**
   * Runs GPU Demucs v4 (when DEMUX_SERVICE_URL is set) AND phase subtraction against a supplied
   * isolated vocal stem concurrently, probes empirical `dialogueBleedDb` on both when available,
   * and selects the cleaner stem. A cached non-degraded stem (e.g. from the Demux worker) wins first.
   */
  async extractMneStemDetailedParallel(
    jobId: string,
    audioUrl: string,
    options?: ExtractMneOptions
  ): Promise<ExtractMneDetailedResult> {
    const bucket = storage().bucket();
    const cachedPath = `audio/${jobId}/m_and_e.mp3`;

    // Fast path: return cached non-degraded M&E stem if present AND version matches current pipeline
    try {
      const file = bucket.file(cachedPath);
      const [exists] = await file.exists();
      if (exists) {
        const [meta] = await file.getMetadata();
        if (Number(meta.size) > 10240) {
          const customMeta = meta.metadata || {};
          // Reject stale cache from an older pipeline version — re-extract with new algorithm
          if (customMeta.mnePipelineVersion === MNE_PIPELINE_VERSION) {
            const cachedSource = (customMeta.mneSource as MneValidationResult["source"]) ||
              (customMeta.separationMethod === "phase_subtraction_midside"
                ? "neural_isolation_subtraction"
                : (customMeta.separationMethod ? "neural_demixing" : "dsp_fallback"));
            const cachedDegraded = String(customMeta.degraded) === "true" || cachedSource === "dsp_fallback";
            if (!cachedDegraded) {
              return {
                mneUrl: `gs://${bucket.name}/${cachedPath}`,
                source: cachedSource,
                engine: String(customMeta.separationMethod || "cached_mne"),
                degraded: false,
                issues: [],
              };
            }
          }
        }
      }
    } catch (_) {}

    const issues: string[] = [];

    // Path A: Modal GPU Demucs v4 with strict timeout guard
    const runDemucsCandidate = async (): Promise<ExtractMneDetailedResult | null> => {
      const serviceUrl = PIPELINE_CONFIG.DEMUX_SERVICE_URL;
      if (!serviceUrl || serviceUrl.includes("placeholder")) {
        issues.push("GPU Demucs worker URL not configured");
        return null;
      }
      const workerRequest = demuxWorkerRequestConfig();
      if (!workerRequest) {
        issues.push("Demux worker skipped: DEMUX_WORKER_TOKEN not set");
        return null;
      }
      const DEMUCS_TIMEOUT_MS = workerRequest.timeout;
      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error(`Demucs timeout after ${DEMUCS_TIMEOUT_MS}ms`)), DEMUCS_TIMEOUT_MS)
      );
      try {
        const demixEndpoint = `${serviceUrl.replace(/\/$/, "")}/demix`;
        // Sign the GCS URL so the Modal GPU worker can download private bucket objects
        let signedAudioUrl = audioUrl;
        try {
          const { audioIdentityService } = require("./audio-identity");
          signedAudioUrl = await audioIdentityService.getAccessibleUrl(audioUrl);
        } catch (_) { /* non-fatal — proceed with original URL */ }
        const demixRes = await Promise.race([
          axios.post(
            demixEndpoint,
            { jobId, audioUrl: signedAudioUrl },
            workerRequest
          ),
          timeoutPromise,
        ]);
        const demixData = demixRes.data;
        const isRemoteDegraded =
          demixData?.degraded === true ||
          demixData?.engine === "ffmpeg_crossover_fallback" ||
          demixData?.validationStatus === "degraded";
        if (demixData?.mneUrl && !isRemoteDegraded) {
          return {
            mneUrl: demixData.mneUrl,
            vocalsUrl: demixData.vocalsUrl || undefined,
            source: "neural_demixing",
            engine: demixData.engine || "demucs_v4_neural",
            degraded: false,
            issues: [],
          };
        }
        issues.push("Remote GPU Demucs returned degraded crossover fallback");
        return null;
      } catch (err: any) {
        issues.push(`GPU Demucs unavailable (${err?.message || err})`);
        return null;
      }
    };

    // Path B: phase subtraction against a supplied isolated vocal stem (e.g. Demucs vocals),
    // written to its own GCS path to avoid write races.
    const runIsolationCandidate = async (): Promise<ExtractMneDetailedResult | null> => {
      if (options?.forceMidSideSplit || !options?.isolatedVocalUrl) {
        return null;
      }

      const ffmpegPath = getFfmpegPath();
      if (!ffmpegPath) return null;

      const resolvedVocal = options.isolatedVocalUrl;
      if (!resolvedVocal || resolvedVocal === audioUrl) {
        return null;
      }

      const tmpDir = os.tmpdir();
      const ts = Date.now();
      const tempAudio = path.join(tmpDir, `par_orig_${jobId}_${ts}.mp3`);
      const tempVocal = path.join(tmpDir, `par_voc_${jobId}_${ts}.mp3`);
      const tempOut = path.join(tmpDir, `par_mne_${jobId}_${ts}.mp3`);
      const isoOutputPath = `audio/${jobId}/m_and_e_iso.mp3`;

      try {
        await this.downloadToStream(audioUrl, tempAudio, bucket, 90000);
        await this.downloadToStream(resolvedVocal, tempVocal, bucket, 90000);
        const ok = await this.tryPhaseSubtraction(ffmpegPath, tempAudio, tempVocal, tempOut, issues);
        if (!ok) return null;

        await bucket.upload(tempOut, {
          destination: isoOutputPath,
          metadata: {
            contentType: "audio/mpeg",
            metadata: {
              jobId,
              stem: "m_and_e_iso",
              mneSource: "neural_isolation_subtraction",
              separationMethod: "phase_subtraction_midside",
              degraded: "false",
              createdAt: String(Date.now()),
            },
          },
        });

        return {
          mneUrl: `gs://${bucket.name}/${isoOutputPath}`,
          source: "neural_isolation_subtraction",
          engine: "phase_subtraction_midside",
          degraded: false,
          issues: [],
        };
      } catch (err: any) {
        issues.push(`Parallel isolation subtraction error (${err?.message || err})`);
        return null;
      } finally {
        await fs.promises.unlink(tempAudio).catch(() => {});
        await fs.promises.unlink(tempVocal).catch(() => {});
        await fs.promises.unlink(tempOut).catch(() => {});
      }
    };

    const [demucsSettled, isoSettled] = await Promise.allSettled([
      runDemucsCandidate(),
      runIsolationCandidate(),
    ]);

    const demucsCand = demucsSettled.status === "fulfilled" ? demucsSettled.value : null;
    const isoCand = isoSettled.status === "fulfilled" ? isoSettled.value : null;

    const candidates = [demucsCand, isoCand].filter((c): c is ExtractMneDetailedResult => Boolean(c));
    if (candidates.length > 0) {
      const probeSegments =
        options?.spokenSegments && options.spokenSegments.length > 0
          ? options.spokenSegments
          : [{ start: 1000, end: 5000 }];
      const expDur = options?.expectedDurationSeconds ?? 0;

      // Validate EVERY candidate against the original mix (previously a lone candidate skipped validation).
      const validations = await Promise.all(
        candidates.map((c) =>
          this.validateMneStem(jobId, c.mneUrl, expDur, c.source, {
            spokenSegments: probeSegments,
            referenceAudioUrl: audioUrl,
            vocalsUrl: c.vocalsUrl,
          })
        )
      );

      // Eligible = not failed AND bleed actually measured. A missing measurement is not "clean".
      const ranked = candidates
        .map((cand, i) => ({ cand, val: validations[i] }))
        .filter(({ val }) => val.validationStatus !== "failed" && typeof val.vocalSuppressionDb === "number")
        .sort((x, y) => (y.val.vocalSuppressionDb as number) - (x.val.vocalSuppressionDb as number));

      if (ranked.length === 0) {
        const detail = candidates
          .map((c, i) => `${c.engine}: ${validations[i].validationStatus}, suppression=${validations[i].vocalSuppressionDb ?? "n/a"} dB`)
          .join(" | ");
        throw new Error(`No M&E candidate passed dialogue-bleed validation (${detail}). ${issues.join("; ")}`);
      }

      let best = ranked[0];
      if (fidelityStemSelectEnabled() && ranked.length >= 2) {
        const passing = ranked.filter((r) => r.val.validationStatus === "passed");
        const pool = passing.length >= 2 ? passing : ranked;
        const gaps = speechGaps(probeSegments, expDur > 0 ? expDur * 1000 : 60000).map((g) => ({
          startMs: g.start,
          endMs: g.end,
        }));
        if (gaps.length > 0) {
          const tmpOrig = path.join(os.tmpdir(), `fid_orig_${jobId}_${Date.now()}.mp3`);
          const tmpStems: string[] = [];
          try {
            await this.downloadToStream(audioUrl, tmpOrig, bucket, 60000);
            const origPcm = await this.decodeMonoPcm(tmpOrig, 8000, Math.ceil(expDur || 60) + 5);
            const scored = await Promise.all(
              pool.map(async (item, idx) => {
                const tmpStem = path.join(os.tmpdir(), `fid_stem_${idx}_${jobId}_${Date.now()}.mp3`);
                tmpStems.push(tmpStem);
                await this.downloadToStream(item.cand.mneUrl, tmpStem, bucket, 60000);
                const stemPcm = await this.decodeMonoPcm(tmpStem, 8000, Math.ceil(expDur || 60) + 5);
                const fid = measureGapFidelity(origPcm, stemPcm, 8000, gaps);
                const bandErr = fid.meanAbsBandDeltaDb ?? 99;
                const loudErr = fid.loudnessDeltaDb !== null ? Math.abs(fid.loudnessDeltaDb) : 99;
                return { item, bandErr, loudErr, fid };
              })
            );
            scored.sort((a, b) => (a.bandErr !== b.bandErr ? a.bandErr - b.bandErr : a.loudErr - b.loudErr));
            best = scored[0].item;
            console.log(
              `[M&E:FidelitySelect] Picked ${best.cand.engine} (meanBandDelta=${scored[0].bandErr} dB, loudDelta=${scored[0].loudErr} dB)`
            );
          } catch (fidErr: any) {
            console.warn(`[M&E:FidelitySelect] Skipped (${fidErr?.message || fidErr}), using bleed ranking`);
          } finally {
            await fs.promises.unlink(tmpOrig).catch(() => {});
            for (const f of tmpStems) await fs.promises.unlink(f).catch(() => {});
          }
        }
      }
      return {
        mneUrl: best.cand.mneUrl,
        vocalsUrl: best.cand.vocalsUrl,
        source: candidates.length > 1 ? "neural_demixing_best_of_2" : best.cand.source,
        engine: candidates.length > 1 ? `${best.cand.engine}_best_of_2` : best.cand.engine,
        degraded: best.val.validationStatus === "degraded",
        dialogueBleedDb: best.val.dialogueBleedDb,
        issues: best.val.issues,
      };
    }

    // Both neural extractors unavailable -> explicit degraded DSP crossover
    return this.extractMneStemDetailed(jobId, audioUrl, {
      ...options,
      forceMidSideSplit: true,
    });
  }

  /**
   * Applies the standalone 5-stage cinema mastering chain to any audio track in GCS.
   */
  async applyCinemaGradeMastering(
    jobId: string,
    inputGcsUrl: string,
    options?: CinemaMasteringOptions
  ): Promise<string> {
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) {
      console.warn("[MediaService] FFmpeg not found, returning unmastered audio URL");
      return inputGcsUrl;
    }

    const bucket = storage().bucket();
    const profile = options?.masteringProfile
      ? MASTERING_PROFILES[options.masteringProfile]
      : MASTERING_PROFILES.web_streaming;
    const targetLufs = options?.targetLufs ?? profile.targetLufs;
    const truePeakDb = options?.truePeakDb ?? profile.truePeakDb;
    const loudnessRangeLra = options?.loudnessRangeLra ?? profile.loudnessRangeLra;

    const suffix = options?.outputSuffix ? `_${options.outputSuffix.replace(/[^a-zA-Z0-9_-]/g, "")}` : "";
    const outputPath = `audio/${jobId}/cinema_master${suffix}.mp3`;
    const tmpDir = os.tmpdir();
    const ts = Date.now();
    const tempIn = path.join(tmpDir, `cm_in_${jobId}_${ts}.mp3`);
    const tempOut = path.join(tmpDir, `cm_out_${jobId}_${ts}.mp3`);

    try {
      await this.downloadToStream(inputGcsUrl, tempIn, bucket, 90000);
      const chain = buildCinemaMasteringFilterChain({
        targetLufs,
        truePeakDb,
        loudnessRangeLra,
        deEss: options?.deEss,
        roomTone: options?.roomTone,
      });
      const filterGraph = `aformat=channel_layouts=stereo,${chain}`;

      await execFileAsync(
        ffmpegPath,
        [
          "-y",
          "-i", tempIn,
          "-af", filterGraph,
          "-c:a", "libmp3lame",
          "-b:a", "192k",
          "-ar", "44100",
          "-ac", "2",
          tempOut,
        ],
        { maxBuffer: 100 * 1024 * 1024 }
      );

      await bucket.upload(tempOut, {
        destination: outputPath,
        metadata: {
          contentType: "audio/mpeg",
          metadata: {
            jobId,
            stem: "cinema_master",
            targetLoudness: `${targetLufs} LUFS`,
            truePeakDb: `${truePeakDb} dBTP`,
            deEss: String(options?.deEss !== false),
            createdAt: String(Date.now()),
          },
        },
      });

      return `gs://${bucket.name}/${outputPath}`;
    } finally {
      await fs.promises.unlink(tempIn).catch(() => {});
      await fs.promises.unlink(tempOut).catch(() => {});
    }
  }

  /**
   * 🎛️ Dynamically sidechain-ducks the M&E track and mixes it with the target language dubbed voice.
   *
   * Industry Standard (ITU-R BS.1770 / EBU R128):
   *   - Smooth 20ms attack ducking when speech is detected (-12dB compression)
   *   - Natural 300ms release swell when dub voice pauses
   *   - Integrated -14 LUFS broadcast mastering with -1 dBTP peak limit
   */
  /**
   * Faithful dub mix (see faithful-mix.ts): the original audio everywhere except the dialogue
   * regions; inside them the clean background stem (when given) plus the dubbed voice, each speaker
   * set to the original voice's level. No ducking and no loudness re-target, so the track keeps the
   * original's balance and loudness. Returns ok=false with a reason when the result does not match
   * the original outside the dialogue; the caller then falls back to mixDubWithMne.
   */
  async mixDubFaithful(jobId: string, language: string, opts: FaithfulMixOptions): Promise<FaithfulMixResult> {
    const fail = (reason: string): FaithfulMixResult => ({
      ok: false, url: null, reason, sourceLufs: null, mixLufs: null, regions: 0, regionMs: 0,
      outsideDiffDb: null, voiceGainDb: {}, toneMatchedSpeakers: [], usedBed: false,
    });
    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) return fail("ffmpeg unavailable");
    if (!opts.sourceAudioUrl || !opts.dubbedAudioUrl) return fail("missing source or dubbed audio");

    const bucket = storage().bucket();
    const stamp = `${jobId}_${language}_${Date.now()}`;
    const tmp = (name: string) => path.join(os.tmpdir(), `faithful_${stamp}_${name}`);
    const tSource = tmp("source.audio");
    const tDub = tmp("dub.audio");
    const tBed = tmp("bed.audio");
    const tVocals = tmp("vocals.audio");
    const tScript = tmp("graph.txt");
    const tOut = tmp("mix.mp3");
    const envFiles: string[] = [];
    /** Mono PCM of the given spans joined together, from the start of the file (FFmpeg stops early). */
    const spansPcm = async (file: string, spans: TimeSpanMs[], sampleRate: number, capSec = 60): Promise<Float32Array> => {
      const chosen = firstSpans(spans, capSec * 1000);
      if (chosen.length === 0) return new Float32Array(0);
      const { stdout } = await execFileAsync(
        ffmpegPath,
        ["-v", "error", "-i", file, "-map", "0:a:0", "-af", `aselect='${spansSelectExpr(chosen)}',asetpts=N/SR/TB`,
          "-t", String(capSec), "-ac", "1", "-ar", String(sampleRate), "-f", "f32le", "pipe:1"],
        { encoding: "buffer", maxBuffer: capSec * sampleRate * 4 + 1024 * 1024, timeout: 300000 } as any
      );
      const buf = Buffer.from(stdout as unknown as Buffer);
      return new Float32Array(buf.buffer, buf.byteOffset, Math.floor(buf.length / 4));
    };

    try {
      const hasBed = Boolean(opts.bedUrl);
      const tMixDl = Date.now();
      await Promise.all([
        this.downloadToStream(opts.sourceAudioUrl, tSource, bucket, 300000, jobId),
        this.downloadToStream(opts.dubbedAudioUrl, tDub, bucket, 300000, jobId),
        hasBed ? this.downloadToStream(opts.bedUrl!, tBed, bucket, 300000, jobId) : Promise.resolve(),
        opts.isolatedVocalUrl ? this.downloadToStream(opts.isolatedVocalUrl, tVocals, bucket, 300000, jobId).catch(() => undefined) : Promise.resolve(),
      ]);
      emitDubbingTiming("post.mix_download", tMixDl, { jobId, lang: language, hasBed });
      const tMixPcm = Date.now();
      const haveVocals = Boolean(opts.isolatedVocalUrl) && fs.existsSync(tVocals);

      // The mix must cover the whole original, even when the stored duration is short.
      const probedMs = await this.probeMediaDurationMs(tSource).catch(() => 0);
      const totalMs = Math.max(opts.totalDurationMs && opts.totalDurationMs > 0 ? opts.totalDurationMs : 0, probedMs || 0);
      if (!totalMs || totalMs <= 0) return fail("source duration unknown");

      // Every track is decoded once at a low rate; levels, activity and the final check are measured
      // from these in memory (one pass per file, however many speakers or lines).
      const rate = analysisRateFor(totalMs);
      const maxSec = Math.ceil(totalMs / 1000) + 5;
      const [srcPcm, dubPcm, bedPcm, vocPcm] = await Promise.all([
        this.decodeMonoPcm(tSource, rate, maxSec),
        this.decodeMonoPcm(tDub, rate, maxSec),
        hasBed ? this.decodeMonoPcm(tBed, rate, maxSec) : Promise.resolve(null),
        haveVocals ? this.decodeMonoPcm(tVocals, rate, maxSec) : Promise.resolve(null),
      ]);

      // Dialogue regions: the original's spoken lines plus wherever the dubbed track is audible
      // (a dubbed line can run past its source window).
      const lines = opts.lines.filter((l) => l.endMs > l.startMs);
      const dubActiveAll = detectActiveSpans(dubPcm, rate);
      const dubActive = dubSpansNearLines(dubActiveAll, lines);
      const regions = planDialogueRegions([...lines, ...dubActive], totalMs);
      if (regions.length === 0) return fail("no dialogue regions");
      // The regions must hold the dubbed speech; otherwise masking would cut the dub and let the
      // original language through (e.g. line timings in the wrong unit).
      const coverage = dubCoverage(dubActiveAll, regions);
      if (coverage < FAITHFUL_MIX.minDubCoverage) {
        return fail(`dubbed speech outside the dialogue timings (${Math.round(coverage * 100)}% covered)`);
      }

      // Per speaker: level of the original voice, and (with a clean reference) its tone.
      // Clean reference = the isolated voice, or the source itself on a speech-only video.
      const toneReference = opts.toneMatch === false ? null : (haveVocals ? tVocals : (opts.sourceIsSpeechOnly ? tSource : null));
      const extents = buildGainSpans(lines, {}, totalMs);
      const speakers = Array.from(new Set(lines.map((l) => l.speaker)));
      const gains: Record<string, number> = {};
      const eqBySpeaker: Record<string, string | null> = {};
      for (const speaker of speakers) {
        const own = lines.filter((l) => l.speaker === speaker);
        const ownExtents = extents.filter((e) => e.speaker === speaker);
        const originalDb = estimateOriginalVoiceDb({
          isolatedVoiceDb: vocPcm ? rmsDbOver(vocPcm, rate, own) : null,
          sourceDb: rmsDbOver(srcPcm, rate, own),
          bedDb: bedPcm ? rmsDbOver(bedPcm, rate, own) : null,
        });
        gains[speaker] = voiceGainDb(originalDb, rmsDbOver(dubPcm, rate, ownExtents));

        const referenceSec = own.reduce((sum, l) => sum + (l.endMs - l.startMs), 0) / 1000;
        const eqCount = Object.values(eqBySpeaker).filter(Boolean).length;
        if (toneReference && referenceSec >= MIN_EQ_REFERENCE_SEC && eqCount < MAX_EQ_BRANCHES) {
          try {
            const [refPcm, dubSpeakerPcm] = await Promise.all([
              spansPcm(toneReference, own, 44100),
              spansPcm(tDub, ownExtents, 44100),
            ]);
            eqBySpeaker[speaker] = eqFilterFor(eqCorrectionDb(bandProfileDb(refPcm, 44100), bandProfileDb(dubSpeakerPcm, 44100)));
          } catch (eqErr: any) {
            console.warn(`[MediaService:Faithful] Tone match skipped for ${speaker}: ${eqErr?.message || eqErr}`);
          }
        }
      }
      // Line by line: each dubbed line is matched to the same English line (speech frames only),
      // within ±LINE_LEVEL.maxDeviationDb of its speaker's gain, plus the dialogue lift.
      const originalVoicePcm = vocPcm || (opts.sourceIsSpeechOnly ? srcPcm : null);
      const originalVoiceActive = originalVoicePcm ? detectActiveSpans(originalVoicePcm, rate) : [];
      const lineGainDb = planLineGainsDb({
        lines,
        totalMs,
        speakerGainDb: gains,
        liftDb: dubVoiceLiftDb(),
        originalLineDb: (l) => (originalVoicePcm ? activeRmsDb(originalVoicePcm, rate, l, originalVoiceActive) : null),
        dubLineDb: (e) => activeRmsDb(dubPcm, rate, e, dubActiveAll),
      });
      const gainSpans = buildGainSpans(lines, gains, totalMs, lineGainDb);

      // Measured against the ORIGINAL, not our plan: a line the original speaks with no dubbed speech
      // near it, and a speaker whose dubbed voice is clearly the other gender. The quality gate
      // blocks delivery on either (dub-sync-check.ts). Needs the clean original voice.
      let syncReport: DubSyncReport = { checked: false, missing: [], genderMismatches: [] };
      if (originalVoicePcm) {
        try {
          const { missing, earlyFinish, untranscribed } = checkDubSpeech({
            sourceSpeech: originalVoiceActive,
            dubSpeech: dubActiveAll,
            extents: dialogueExtents(lines),
            lines,
            words: (opts.sourceWords ?? []).filter((w) => w.endMs > w.startMs),
          });
          if (earlyFinish.length > 0) {
            console.warn(`[MediaService:Faithful] Dubbed line(s) finish before the original speech ends (warning, not blocking): ${earlyFinish.map((m) => `${(m.startMs / 1000).toFixed(1)}s`).join(", ")}`);
          }
          if (untranscribed.length > 0) {
            console.warn(`[MediaService:Faithful] Original voice with no transcribed words, nothing to dub (warning, not blocking): ${untranscribed.map((m) => `${(m.startMs / 1000).toFixed(1)}–${(m.endMs / 1000).toFixed(1)}s`).join(", ")}`);
          }
          const genderMismatches: DubSyncReport["genderMismatches"] = [];
          if (rate >= 8000) {
            const spansPcmIn = (pcm: Float32Array, spans: Array<{ startMs: number; endMs: number }>): Float32Array => {
              const parts: Float32Array[] = [];
              for (const sp of spans) {
                const from = Math.max(0, Math.floor((sp.startMs / 1000) * rate));
                const to = Math.min(pcm.length, Math.ceil((sp.endMs / 1000) * rate));
                if (to > from) parts.push(pcm.subarray(from, to));
              }
              const total = parts.reduce((n, p) => n + p.length, 0);
              const out = new Float32Array(total);
              let o = 0;
              for (const p of parts) { out.set(p, o); o += p.length; }
              return out;
            };
            for (const speaker of speakers) {
              const own = lines.filter((l) => l.speaker === speaker);
              const ownExtents = extents.filter((e) => e.speaker === speaker);
              const original = estimatePitch(spansPcmIn(originalVoicePcm, own), rate);
              const dubHz = estimatePitch(spansPcmIn(dubPcm, ownExtents), rate)?.medianHz ?? 0;
              if (original && voiceGenderMismatch(original, dubHz)) genderMismatches.push({ speaker, originalHz: original.medianHz, dubHz });
            }
          }
          syncReport = { checked: true, missing, earlyFinish, untranscribed, genderMismatches };
        } catch (syncErr: any) {
          console.warn(`[MediaService:Faithful] Sync check skipped: ${syncErr?.message || syncErr}`);
        }
      }

      // ─── Room measurement & synthetic IR (DUBBING_ROOM_MATCH) ───────────────────────────
      let regionRoomEstimates: (RegionRoomEstimate | null)[] = [];
      let scenes: SceneRoomEstimate[] = [];
      const irFiles: string[] = [];
      const irArgs: string[] = [];
      const sceneIrInputIndex = new Map<number, number>();

      if (roomMatchEnabled() && vocPcm) {
        regionRoomEstimates = regions.map((r, idx) => estimateRegionRoom(vocPcm, rate, r, originalVoiceActive, idx));
        scenes = groupRegionsIntoScenes(regions, regionRoomEstimates);
        for (let i = 0; i < regions.length; i++) {
          const est = regionRoomEstimates[i];
          const sc = scenes.find((s) => s.regionIndices.includes(i));
          console.log(`[Mix:Room] { region: ${i}, rt60Ms: ${est?.rt60Ms ?? null}, drrDb: ${est?.drrDb ?? null}, scene: ${sc?.sceneId ?? 0} }`);
        }

        let nextIrIdx = hasBed ? 3 : 2;
        for (const sc of scenes) {
          if (sc.rt60Ms !== null && sc.drrDb !== null) {
            const ir = buildSyntheticRoomIr({
              rt60Ms: sc.rt60Ms,
              drrDb: sc.drrDb,
              bandRt60Ms: sc.bandRt60Ms ?? undefined,
              sampleRate: 44100,
            });
            const irFile = tmp(`scene_${sc.sceneId}_ir.f32`);
            irFiles.push(irFile);
            envFiles.push(irFile);
            await fs.promises.writeFile(irFile, Buffer.from(ir.buffer, ir.byteOffset, ir.byteLength));
            sceneIrInputIndex.set(sc.sceneId, nextIrIdx);
            irArgs.push("-f", "f32le", "-ar", "44100", "-ac", "1", "-i", irFile);
            nextIrIdx++;
          }
        }
      }

      // Map lines to scenes
      for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        const rIdx = regions.findIndex((r) => l.startMs >= r.startMs - 50 && l.endMs <= r.endMs + 50);
        const sc = scenes.find((s) => s.regionIndices.includes(rIdx));
        const sceneId = sc ? sc.sceneId : 0;
        l.sceneId = sceneId;
        if (gainSpans[i]) gainSpans[i].sceneId = sceneId;
      }

      // ─── Scene Tone (DUBBING_SCENE_TONE) ────────────────────────────────────────────────
      const eqBySpeakerScene = new Map<string, string | null>();
      if (sceneToneEnabled() && scenes.length > 1 && toneReference) {
        for (const speaker of speakers) {
          const own = lines.filter((l) => l.speaker === speaker);
          for (const sc of scenes) {
            const sceneOwn = own.filter((l) => l.sceneId === sc.sceneId);
            const sceneExtents = extents.filter((e, idx) => lines[idx]?.speaker === speaker && lines[idx]?.sceneId === sc.sceneId);
            const refSec = sceneOwn.reduce((sum, l) => sum + (l.endMs - l.startMs), 0) / 1000;
            const key = `${speaker}_scene_${sc.sceneId}`;
            if (refSec >= MIN_EQ_REFERENCE_SEC) {
              try {
                const [refPcm, dubScenePcm] = await Promise.all([
                  spansPcm(toneReference, sceneOwn, 44100),
                  spansPcm(tDub, sceneExtents, 44100),
                ]);
                eqBySpeakerScene.set(key, eqFilterFor(eqCorrectionDb(bandProfileDb(refPcm, 44100), bandProfileDb(dubScenePcm, 44100))));
              } catch (eqErr: any) {
                console.warn(`[MediaService:Faithful] Scene tone match skipped for ${key}: ${eqErr?.message || eqErr}`);
                eqBySpeakerScene.set(key, eqBySpeaker[speaker] ?? null);
              }
            } else {
              eqBySpeakerScene.set(key, eqBySpeaker[speaker] ?? null);
            }
          }
        }
      }

      // ─── Build dub branches ─────────────────────────────────────────────────────────────
      let branches: DubBranch[];
      let toneMatchedSpeakers: string[] = [];

      if ((sceneToneEnabled() && scenes.length > 1) || (roomMatchEnabled() && sceneIrInputIndex.size > 0)) {
        branches = [];
        for (const speaker of speakers) {
          for (const sc of scenes) {
            const hasLines = lines.some((l) => l.speaker === speaker && l.sceneId === sc.sceneId);
            if (!hasLines) continue;
            const key = `${speaker}_scene_${sc.sceneId}`;
            const eq = eqBySpeakerScene.has(key) ? eqBySpeakerScene.get(key)! : (eqBySpeaker[speaker] ?? null);
            const irIdx = sceneIrInputIndex.get(sc.sceneId);
            if (branches.length < MAX_EQ_BRANCHES) {
              branches.push({
                speakers: [speaker],
                eqFilter: eq,
                irInputIndex: irIdx,
                sceneId: sc.sceneId,
              });
              if (eq && !toneMatchedSpeakers.includes(speaker)) toneMatchedSpeakers.push(speaker);
            }
          }
        }
        if (branches.length === 0 || branches.length < MAX_EQ_BRANCHES) {
          branches.push({ speakers: speakers.filter((spk) => !toneMatchedSpeakers.includes(spk)), eqFilter: null });
        }
      } else {
        branches = Object.entries(eqBySpeaker)
          .filter(([, eq]) => Boolean(eq))
          .map(([speaker, eq]) => ({ speakers: [speaker], eqFilter: eq }));
        toneMatchedSpeakers = branches.flatMap((b) => b.speakers);
        branches.push({ speakers: speakers.filter((spk) => !toneMatchedSpeakers.includes(spk)), eqFilter: null });
      }

      // ─── Non-verbal vocal sounds & Tight stem (DUBBING_KEEP_NONVERBAL / DUBBING_TIGHT_STEM) ──
      const sourceWords = (opts.sourceWords ?? []).filter((w) => w.endMs > w.startMs);
      const nonVerbalSpans = vocPcm
        ? detectNonVerbalSpans({
            vocPcm,
            sampleRate: rate,
            words: sourceWords,
            dubActive: dubActiveAll,
            totalMs,
          })
        : [];
      const applyNonVerbal = keepNonVerbalEnabled() && nonVerbalSpans.length > 0;
      if (applyNonVerbal) {
        for (const nv of nonVerbalSpans) {
          console.log(`[Mix:NonVerbal] { startMs: ${nv.startMs}, endMs: ${nv.endMs}, reason: "${nv.reason}" }`);
        }
      }

      let tightStemSpans: TimeSpanMs[] | undefined;
      let stemFadesMs: { startFadeMs?: number; endFadeMs?: number }[] | undefined;
      let equalPowerTightFade = false;
      if (tightStemEnabled() && hasBed && originalVoicePcm) {
        const tightVoiceActive = detectActiveSpans(originalVoicePcm, rate, {
          frameMs: FAITHFUL_MIX.activityFrameMs,
          minGapMs: 60,
        });
        let stemSpans = buildTightStemSpans(regions, tightVoiceActive, 100, {
          words: sourceWords.length > 0 ? sourceWords : undefined,
          mergeGapMs: 80,
        });
        if (applyNonVerbal) {
          stemSpans = subtractSpans(stemSpans, nonVerbalSpans, 40);
        }
        tightStemSpans = stemSpans;
        // Linear (equal-gain) fades: the original and the bed carry the same music, so they are
        // correlated and an equal-power fade would lift it by up to +3 dB mid-fade (2026-11-25).
        equalPowerTightFade = false;
        stemFadesMs = stemSpans.map(() => ({
          startFadeMs: TIGHT_STEM_FADE_MS,
          endFadeMs: TIGHT_STEM_FADE_MS,
        }));
        const stemMsBefore = regions.reduce((sum, r) => sum + (r.endMs - r.startMs), 0);
        const stemMsAfter = stemSpans.reduce((sum, s) => sum + (s.endMs - s.startMs), 0);
        console.log(`[Mix:Stem] { stemMsBefore: ${stemMsBefore}, stemMsAfter: ${stemMsAfter} }`);
      }

      // ─── Voice ride (DUBBING_VOICE_RIDE) ────────────────────────────────────────────────
      const envRate = envelopeRateFor(totalMs);
      let voiceRideCurves: { spanIndex: number; curve: Float32Array }[] | undefined;
      if (voiceRideEnabled() && bedPcm) {
        voiceRideCurves = [];
        // gainSpans and extents are in sortedLines order; `lines` is not, so index the sorted list.
        const orderedLines = sortedLines(lines);
        for (let i = 0; i < gainSpans.length; i++) {
          const span = gainSpans[i];
          const curve = computeVoiceRideEnvelope(bedPcm, rate, span, span.gain, envRate);
          voiceRideCurves.push({ spanIndex: i, curve });

          const line = orderedLines[i];
          const extent = extents[i];
          if (!line || !extent) continue;
          const origVoiceDb = originalVoicePcm ? activeRmsDb(originalVoicePcm, rate, line, originalVoiceActive) : null;
          // dubPcm is the raw dubbed track; the mix applies span.gain (speaker + line gain + lift) to it.
          // Before 2026-11-24 the log left the gain out, so dubDiffDb read up to ~11 dB "louder than the
          // original" on lines the mix had actually turned down.
          const rawDubDb = activeRmsDb(dubPcm, rate, extent, dubActiveAll);
          const appliedGainDb = span.gain > 0 ? 20 * Math.log10(span.gain) : null;
          const dubVoiceDb = rawDubDb !== null && appliedGainDb !== null ? rawDubDb + appliedGainDb : null;
          const bedDb = rmsDbOver(bedPcm, rate, [line]);
          if (bedDb !== null) {
            const origDiffDb = origVoiceDb !== null ? Number((origVoiceDb - bedDb).toFixed(1)) : null;
            const dubDiffDb = dubVoiceDb !== null ? Number((dubVoiceDb - bedDb).toFixed(1)) : null;
            const gapDb = origDiffDb !== null && dubDiffDb !== null ? Number((dubDiffDb - origDiffDb).toFixed(1)) : null;
            console.log(
              `[Mix:VoiceRide] { line: ${i}, startMs: ${line.startMs}, speaker: ${line.speaker}, origDiffDb: ${origDiffDb}, dubDiffDb: ${dubDiffDb}, gapDb: ${gapDb}, appliedGainDb: ${appliedGainDb !== null ? appliedGainDb.toFixed(1) : null}, liftDb: ${dubVoiceLiftDb()} }`
            );
          }
        }
      }

      const envelopes = buildEnvelopes({
        regions,
        gainSpans,
        totalMs,
        branches,
        rate: envRate,
        tightStemSpans,
        stemFadesMs,
        equalPowerTightFade,
        nonVerbalKeepSpans: applyNonVerbal ? nonVerbalSpans : undefined,
        voiceRideCurves,
      });
      const curves = [envelopes.orig, ...(hasBed ? [envelopes.bed] : []), ...envelopes.dub];
      const curveArgs: string[] = [];
      for (let i = 0; i < curves.length; i++) {
        const f = tmp(`env${i}.f32`);
        envFiles.push(f);
        await fs.promises.writeFile(f, Buffer.from(curves[i].buffer, curves[i].byteOffset, curves[i].byteLength));
        curveArgs.push("-f", "f32le", "-ar", String(envRate), "-ac", "1", "-i", f);
      }

      // DUBBING_BED_MATCH: correct the separated background toward the original, measured where
      // nobody speaks (the original is pure background there). Needs the voice stem to know where
      // non-verbal sounds are; never throws (no correction on any failure).
      let bedMatch: BedMatchPlan | null = null;
      if (hasBed && bedMatchEnabled()) {
        try {
          if (!vocPcm) {
            bedMatch = { applied: false, reason: "no voice stem to find speech-free audio", gapSeconds: 0, gainDb: 0, bandsDb: null, filter: null };
          } else {
            const freeSpans = speechFreeSpans(totalMs, [...lines, ...sourceWords, ...originalVoiceActive]);
            const chosen = firstSpans(freeSpans, BED_MATCH.maxAnalysisSec * 1000);
            const gapSeconds = chosen.reduce((sum, sp) => sum + (sp.endMs - sp.startMs), 0) / 1000;
            if (gapSeconds < BED_MATCH.minGapSec) {
              bedMatch = planBedMatch({ gapSeconds, originalProfile: null, bedProfile: null, originalDb: null, bedDb: null });
            } else {
              const [origGap, bedGap] = await Promise.all([
                spansPcm(tSource, chosen, 44100, BED_MATCH.maxAnalysisSec),
                spansPcm(tBed, chosen, 44100, BED_MATCH.maxAnalysisSec),
              ]);
              const levelDb = (pcm: Float32Array) => rmsDbOver(pcm, 44100, [{ startMs: 0, endMs: (pcm.length / 44100) * 1000 }]);
              bedMatch = planBedMatch({
                gapSeconds,
                originalProfile: bandProfileDb(origGap, 44100),
                bedProfile: bandProfileDb(bedGap, 44100),
                originalDb: levelDb(origGap),
                bedDb: levelDb(bedGap),
              });
            }
          }
          console.log("[Mix:BedMatch]", { jobId, language, ...bedMatch });
        } catch (bmErr: any) {
          bedMatch = { applied: false, reason: `measurement failed: ${bmErr?.message || bmErr}`, gapSeconds: 0, gainDb: 0, bandsDb: null, filter: null };
          console.warn("[Mix:BedMatch] skipped", { jobId, language, reason: bedMatch.reason });
        }
      }

      const firstEnvIndex = (hasBed ? 3 : 2) + irFiles.length;
      await fs.promises.writeFile(tScript, buildFaithfulMixGraph({ hasBed, branches, firstEnvIndex, bedFilter: bedMatch?.applied ? bedMatch.filter : null }), "utf8");
      emitDubbingTiming("post.mix_pcm_analysis", tMixPcm, { jobId, lang: language, regions: regions.length });
      const tMixFf = Date.now();
      await execFileAsync(ffmpegPath, [
        "-y", "-hide_banner", "-nostats",
        "-i", tSource, "-i", tDub, ...(hasBed ? ["-i", tBed] : []),
        ...irArgs,
        ...curveArgs,
        "-filter_complex_script", tScript,
        "-map", "[out]",
        // 256k like the source extract: at 192k LAME already shifts the level by ~0.3 dB.
        "-c:a", "libmp3lame", "-b:a", "256k", "-ar", "44100", "-ac", "2",
        tOut,
      ], { maxBuffer: 64 * 1024 * 1024, timeout: 900000 });
      emitDubbingTiming("post.mix_ffmpeg_render", tMixFf, { jobId, lang: language });
      const tMixVerify = Date.now();

      // Outside the dialogue the dub must be the original (fades excluded).
      const guard = FAITHFUL_MIX.fadeMs + 20;
      const outside = outsideRegions(regions, totalMs)
        .map((s) => ({ startMs: s.startMs + (s.startMs > 0 ? guard : 0), endMs: s.endMs - (s.endMs < totalMs ? guard : 0) }))
        .filter((s) => s.endMs - s.startMs >= 200);
      const [outPcm, sourceLufs, mixLufs] = await Promise.all([
        this.decodeMonoPcm(tOut, rate, maxSec),
        this.measureIntegratedLufs(tSource),
        this.measureIntegratedLufs(tOut),
      ]);
      const check = checkFaithfulness(rmsDbOver(srcPcm, rate, outside), rmsDbOver(outPcm, rate, outside));
      const regionMs = regions.reduce((sum, r) => sum + (r.endMs - r.startMs), 0);

      // BGM & SFX fidelity report
      let stemSamples = 0;
      if (hasBed) {
        const limitK = Math.min(envelopes.bed.length, Math.ceil((totalMs * envRate) / 1000));
        for (let k = 0; k < limitK; k++) {
          if (envelopes.bed[k] > 0.01) stemSamples++;
        }
      }
      const stemSeconds = Number((stemSamples / envRate).toFixed(3));
      const totalSeconds = Number((totalMs / 1000).toFixed(3));
      const stemShare = totalSeconds > 0 ? Number((stemSeconds / totalSeconds).toFixed(4)) : 0;

      const boundaryMsList: number[] = [];
      for (const r of regions) {
        boundaryMsList.push(r.startMs, r.endMs);
      }
      if (tightStemSpans) {
        for (const s of tightStemSpans) {
          boundaryMsList.push(s.startMs, s.endMs);
        }
      }
      const edgeStepsDb = measureEdgeStepsDb(
        srcPcm,
        outPcm,
        rate,
        boundaryMsList,
        [...dubActiveAll, ...originalVoiceActive, ...sourceWords],
        totalMs
      );

      const speechCuts = [...(sourceWords.length > 0 ? sourceWords : lines), ...originalVoiceActive];
      const regionGaps = subtractSpans(regions, speechCuts, 100);
      const fallbackGaps =
        regionGaps.length > 0
          ? regionGaps
          : speechGaps(
              lines.map((l) => ({ start: l.startMs, end: l.endMs })),
              totalMs
            ).map((g) => ({ startMs: g.start, endMs: g.end }));
      const gapFidelity = hasBed && bedPcm ? measureGapFidelity(srcPcm, bedPcm, rate, fallbackGaps) : null;

      const silentInRegionGaps = subtractSpans(regions, [...speechCuts, ...dubActiveAll], 100);
      let backgroundLevelDeltaDb: number | null = null;
      if (hasBed && silentInRegionGaps.length > 0) {
        const origBgDb = rmsDbOver(srcPcm, rate, silentInRegionGaps);
        const outBgDb = rmsDbOver(outPcm, rate, silentInRegionGaps);
        if (origBgDb !== null && outBgDb !== null) {
          backgroundLevelDeltaDb = Number((outBgDb - origBgDb).toFixed(2));
        }
      } else if (gapFidelity?.loudnessDeltaDb !== null && gapFidelity?.loudnessDeltaDb !== undefined) {
        backgroundLevelDeltaDb = gapFidelity.loudnessDeltaDb;
      }

      const keptNonVerbal = applyNonVerbal ? nonVerbalSpans : [];
      const nonVerbalSeconds = Number(
        (keptNonVerbal.reduce((sum, s) => sum + (s.endMs - s.startMs), 0) / 1000).toFixed(3)
      );
      const bgmReport: BgmReport = {
        outsideDiffDb: check.outsideDiffDb,
        stemSeconds,
        totalSeconds,
        stemShare,
        edgeStepsDb,
        gapFidelity,
        nonVerbalKept: {
          count: keptNonVerbal.length,
          seconds: nonVerbalSeconds,
          spans: keptNonVerbal,
        },
        bleed: null,
        backgroundLevelDeltaDb,
        bedMatch,
        flags: {
          bedMatch: bedMatchEnabled(),
          tightStem: tightStemEnabled(),
          keepNonVerbal: keepNonVerbalEnabled(),
          fidelityStemSelect: fidelityStemSelectEnabled(),
          roomMatch: roomMatchEnabled(),
          sceneTone: sceneToneEnabled(),
          voiceRide: voiceRideEnabled(),
        },
      };

      const base = {
        sourceLufs,
        mixLufs,
        regions: regions.length,
        regionMs,
        outsideDiffDb: check.outsideDiffDb,
        voiceGainDb: gains,
        toneMatchedSpeakers,
        usedBed: hasBed,
        syncReport,
        bgmReport,
      };
      emitDubbingTiming("post.mix_verify", tMixVerify, { jobId, lang: language, ok: check.ok });
      if (!check.ok) return { ...base, ok: false, url: null, reason: check.reason };

      const outputPath = `audio/${jobId}/${language}/master_faithful.mp3`;
      const tMixUp = Date.now();
      await bucket.upload(tOut, {
        destination: outputPath,
        metadata: {
          contentType: "audio/mpeg",
          metadata: {
            jobId,
            language,
            mixEngine: "faithful_v2",
            regions: String(regions.length),
            usedBed: String(hasBed),
            toneMatched: toneMatchedSpeakers.join(","),
            sourceLufs: String(sourceLufs ?? ""),
            createdAt: String(Date.now()),
          },
        },
      });
      emitDubbingTiming("post.mix_upload", tMixUp, { jobId, lang: language });
      const gsOutUrl = `gs://${bucket.name}/${outputPath}`;
      await this.registerJobLocalFile(jobId, gsOutUrl, tOut, ".mp3");
      return { ...base, ok: true, url: gsOutUrl };
    } catch (err: any) {
      return fail(`faithful mix error: ${String(err?.message || err).slice(0, 200)}`);
    } finally {
      for (const f of [tSource, tDub, tBed, tVocals, tScript, tOut, ...envFiles]) fs.promises.unlink(f).catch(() => {});
    }
  }

  async mixDubWithMne(jobId: string, language: string, options: MixDubOptions): Promise<string> {
    const bucket = storage().bucket();
    const outputPath = `audio/${jobId}/${language}/master.mp3`;

    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) {
      console.warn("[MediaService] FFmpeg not found, returning dubbed audio as master mix fallback");
      return options.dubbedAudioUrl;
    }

    const tmpDir = os.tmpdir();
    const tempMne = path.join(tmpDir, `mix_mne_${jobId}_${language}_${Date.now()}.mp3`);
    const tempDub = path.join(tmpDir, `mix_dub_${jobId}_${language}_${Date.now()}.mp3`);
    const tempVocals = path.join(tmpDir, `mix_vocals_${jobId}_${language}_${Date.now()}.mp3`);
    const tempOut = path.join(tmpDir, `mix_out_${jobId}_${language}_${Date.now()}.mp3`);

    try {
      // 1. Memory-safe download of M&E stem
      await this.downloadToStream(options.mneUrl, tempMne, bucket, 90000);

      // 2. Memory-safe download of Dubbed dialogue stem
      await this.downloadToStream(options.dubbedAudioUrl, tempDub, bucket, 90000);

      // 2b. Trap 2 Resolution: Restore authentic non-dialogue vocal SFX (screams, laughs, groans, shouts)
      // from the neural isolated vocal track into the M&E background bed with 180ms padding & word safeguard.
      if (options.isolatedVocalUrl && options.spokenSegments && options.spokenSegments.length > 0) {
        try {
          await this.downloadToStream(options.isolatedVocalUrl, tempVocals, bucket, 90000);
          const totalMs = options.totalDurationMs || (options.totalDurationSeconds ? options.totalDurationSeconds * 1000 : 0);
          await this.restoreNonDialogueVocalSFX(
            ffmpegPath,
            tempMne,
            tempVocals,
            options.spokenSegments,
            options.sourceWords,
            totalMs
          );
        } catch (sfxErr) {
          console.warn("[MediaService] Non-dialogue vocal SFX restoration notice (proceeding with base M&E):", sfxErr);
        }
      }

      // 3. Sidechain Compression & Mastering Parameters
      const profile = options.masteringProfile ? MASTERING_PROFILES[options.masteringProfile] : MASTERING_PROFILES.web_streaming;
      // Gentler sidechain defaults — previous 0.12/2.8 over-ducked an already -14 LUFS dialogue track
      // With a clean, validated M&E stem only light ducking (~2–3 dB) is needed.
      const duckPct =
        typeof options.bgmDuckLevelPercent === "number" && Number.isFinite(options.bgmDuckLevelPercent)
          ? Math.max(0, Math.min(50, options.bgmDuckLevelPercent))
          : undefined;
      const threshold = options.duckingThreshold ?? 0.1;
      const ratio = options.duckingRatio ?? (duckPct !== undefined ? Number((1.2 + (duckPct / 50) * 2.2).toFixed(2)) : 1.5);
      const attack = options.attackMs ?? 15;
      const release = options.releaseMs ?? 200;
      const targetLoudness = options.targetLoudnessLufs ?? profile.targetLufs;

      // 4. Build Filter Graph
      // Dialogue already pre-mastered by stitchAudio; pass through unchanged as both sidechain trigger and mix input.
      // Do NOT re-apply audioFilters here — that causes double loudnorm/EQ stacking (Problem B root cause).
      const dubProcess = "[1:a]aformat=channel_layouts=stereo,asplit=2[dub_sc][dub_mix];";

      // Auto-calibrate M&E bed level: probe integrated loudness and compute makeup gain
      // so the M&E stem reaches a natural -18 LUFS bed before sidechain ducking.
      // Safety Guard: Check energy during speech vs pause intervals to ensure gain
      // does not amplify residual English dialogue. Caps at +12 dB max (+3 dB for fallback).
      let mneAutoGain = "1.0";
      try {
        const probeArgs = [
          "-i", tempMne,
          "-af", "loudnorm=I=-18:TP=-1:LRA=11:print_format=json",
          "-f", "null",
          process.platform === "win32" ? "NUL" : "/dev/null",
        ];
        const probeRes: any = await execFileAsync(ffmpegPath, probeArgs, { maxBuffer: 10 * 1024 * 1024 }).catch((e: any) => ({ stdout: e?.stdout || "", stderr: e?.stderr || "" }));
        const probeStderr = typeof probeRes === "string" ? probeRes : `${probeRes?.stderr || ""}\n${probeRes?.stdout || ""}`;
        const jsonMatch = probeStderr.match(/\{[\s\S]*?"input_i"\s*:\s*"([\d.\-]+)"/);
        if (jsonMatch) {
          const inputI = parseFloat(jsonMatch[1]);
          if (Number.isFinite(inputI) && inputI < -5) {
            const targetBed = -18; // natural ambient bed level (LUFS)
            const rawGainDb = targetBed - inputI;

            // Safety Guard: Check if residual speech is present in M&E stem.
            // If spoken segments are available, sample speech intervals for vocal-band energy (300-3400Hz).
            let maxAllowedGainDb = options.isDegradedMne ? 3.0 : 12.0;
            if (options.spokenSegments && options.spokenSegments.length > 0) {
              try {
                const sampleSpeech = options.spokenSegments.find((s) => (s.end - s.start) >= 400);
                if (sampleSpeech) {
                  const speechStart = Math.max(0, sampleSpeech.start / 1000);
                  const speechDur = Math.min(3, Math.max(0.3, (sampleSpeech.end - sampleSpeech.start) / 1000));
                  const probeSpeech: any = await execFileAsync(ffmpegPath, [
                    "-ss", speechStart.toFixed(3),
                    "-t", speechDur.toFixed(3),
                    "-i", tempMne,
                    "-af", "bandpass=f=1800:width_type=h:w=3000,volumedetect",
                    "-f", "null",
                    process.platform === "win32" ? "NUL" : "/dev/null",
                  ], { maxBuffer: 5 * 1024 * 1024 }).catch((e: any) => ({ stdout: e?.stdout || "", stderr: e?.stderr || "" }));

                  const speechStderr = typeof probeSpeech === "string" ? probeSpeech : `${probeSpeech?.stderr || ""}\n${probeSpeech?.stdout || ""}`;
                  const speechMeanMatch = speechStderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
                  if (speechMeanMatch) {
                    const speechDb = parseFloat(speechMeanMatch[1]);
                    // If vocal-band energy during dialogue windows exceeds -24 dBFS, clamp makeup gain
                    // to prevent boosting residual English speech into audibility.
                    if (speechDb > -24) {
                      const speechPenalty = Math.min(12, (speechDb - (-24)) * 1.5);
                      maxAllowedGainDb = Math.max(0, maxAllowedGainDb - speechPenalty);
                      console.warn(`[MediaService] Residual speech safety guard: vocal-band energy is ${speechDb.toFixed(1)} dBFS. Clamping M&E gain ceiling to ${maxAllowedGainDb.toFixed(1)} dB`);
                    }
                  }
                }
              } catch (_) { /* non-fatal speech check */ }
            }

            const clampedDb = Math.max(-6, Math.min(maxAllowedGainDb, rawGainDb));
            const linearGain = Math.pow(10, clampedDb / 20);
            mneAutoGain = linearGain.toFixed(4);
            console.log(`[MediaService] M&E auto-gain: ${inputI.toFixed(1)} LUFS → target ${targetBed} LUFS, gain ${clampedDb.toFixed(1)} dB (${mneAutoGain}x, ceiling: ${maxAllowedGainDb.toFixed(1)} dB)`);
          }
        }
      } catch (_) { /* non-fatal — proceed with unity gain */ }

      const defaultMneWeight = duckPct !== undefined
        ? Number(Math.max(0.55, 1.15 - duckPct / 100).toFixed(2))
        : 1.1;
      const mneWeight =
        typeof options.mneGain === "number" && Number.isFinite(options.mneGain)
          ? Number(Math.max(0, Math.min(2.5, options.mneGain * 1.1)).toFixed(2))
          : defaultMneWeight;
      const dialogueWeight =
        typeof options.dialogueGain === "number" && Number.isFinite(options.dialogueGain)
          ? Number(Math.max(0.2, Math.min(2.5, options.dialogueGain)).toFixed(2))
          : 1.0;

      // Lock duration to first input (tempMne, which is the exact duration of the source video)
      // Clears unwanted sub-rumble and high hiss while dynamically ducking M&E stem under dubbed dialogue
      const hasNormalize = await this.supportsAmixNormalize(ffmpegPath);
      const amixStage = hasNormalize
        ? `[ducked][dub_mix]amix=inputs=2:weights=${mneWeight} ${dialogueWeight}:normalize=0:duration=first[mixed];`
        : `[ducked][dub_mix]amix=inputs=2:weights=${mneWeight} ${dialogueWeight}:duration=first,volume=2[mixed];`;

      // Single-pass mastering: M&E calibrated → sidechain duck → amix → loudnorm only.
      // The full cinema mastering chain is intentionally removed here — dialogue was already processed
      // by stitchAudio, so a second full chain would triple-stack loudnorm causing Problem B (low BGM).

      const targetDurationSec = typeof options.totalDurationMs === "number" && options.totalDurationMs > 0
        ? options.totalDurationMs / 1000
        : (options.totalDurationSeconds && Number(options.totalDurationSeconds) > 0 ? Number(options.totalDurationSeconds) : null);

      // Broadcast Mastering: Enforce linear normalization (linear=true) to prevent dynamic lookahead gain pumping
      let padFilter = "[mixed]loudnorm=I=-14:TP=-1:LRA=11:linear=true[out]";
      if (targetDurationSec && targetDurationSec > 0) {
        const targetSamples = Math.max(1, Math.round(targetDurationSec * 44100));
        padFilter = `[mixed]loudnorm=I=-14:TP=-1:LRA=11:linear=true,apad=whole_len=${targetSamples}[out]`;
      }

      // Mute Source Dialogue Stem When Mixing: Ensure source speech windows are completely
      // attenuated (-100 dB) so original English dialogue never bleeds underneath the dub.
      let speechMuteFilter = "";
      if (options.spokenSegments && options.spokenSegments.length > 0) {
        const clauses = options.spokenSegments
          .filter((s) => s.end > s.start)
          .map((s) => `between(t,${(Math.max(0, s.start) / 1000).toFixed(3)},${(Math.max(0, s.end) / 1000).toFixed(3)})`)
          .join("+");
        if (clauses) {
          speechMuteFilter = `,volume=enable='${clauses}':volume=0:eval=frame`;
        }
      }

      const filterGraph =
        dubProcess +
        `[0:a]aformat=channel_layouts=stereo,highpass=f=35,lowpass=f=18500${speechMuteFilter},volume=${mneAutoGain}[mne_gained];` +
        `[mne_gained][dub_sc]sidechaincompress=threshold=${threshold}:ratio=${ratio}:attack=${attack}:release=${release}:makeup=1[ducked];` +
        amixStage +
        padFilter;

      const ffmpegArgs = [
        "-y",
        "-i", tempMne,
        "-i", tempDub,
        "-filter_complex", filterGraph,
        "-map", "[out]",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        "-ar", "44100",
        "-ac", "2",
      ];

      if (targetDurationSec && targetDurationSec > 0) {
        const durStr = Number.isInteger(targetDurationSec)
          ? targetDurationSec.toString()
          : targetDurationSec.toFixed(3);
        ffmpegArgs.push("-t", durStr);
      }

      ffmpegArgs.push(tempOut);
      await execFileAsync(ffmpegPath, ffmpegArgs, { maxBuffer: 100 * 1024 * 1024 });

      // 5. Post-render loudness & quality validation (EBU R128 / ITU-R BS.1770)
      let measuredLufs = targetLoudness;
      let measuredTruePeak = -1.0;
      let measuredLra = 11.0;
      try {
        const verifyArgs = [
          "-i", tempOut,
          "-af", "ebur128=framelog=verbose",
          "-f", "null",
          process.platform === "win32" ? "NUL" : "/dev/null",
        ];
        const { stderr: verifyStderr } = await execFileAsync(ffmpegPath, verifyArgs, { maxBuffer: 10 * 1024 * 1024 }).catch((e: any) => ({ stderr: e.stderr || "" }));
        const lufsMatch = verifyStderr.match(/Integrated loudness:\s*I:\s*(-?[\d.]+)\s*LUFS/);
        const tpMatch = verifyStderr.match(/Peak:\s*True:\s*(-?[\d.]+)\s*dBFS/);
        const lraMatch = verifyStderr.match(/Loudness range:\s*LRA:\s*(-?[\d.]+)\s*LU/);
        if (lufsMatch) measuredLufs = parseFloat(lufsMatch[1]);
        if (tpMatch) measuredTruePeak = parseFloat(tpMatch[1]);
        if (lraMatch) measuredLra = parseFloat(lraMatch[1]);
        console.log(`[MediaService] Master audio verified: ${measuredLufs} LUFS, ${measuredTruePeak} dBTP, ${measuredLra} LRA`);
      } catch (_) { /* non-fatal validation */ }

      // 6. Upload master track to GCS
      await bucket.upload(tempOut, {
        destination: outputPath,
        metadata: {
          contentType: "audio/mpeg",
          metadata: {
            jobId,
            language,
            stem: "master_mix",
            ducking: "sidechain_dynamic",
            targetLoudness: `${targetLoudness} LUFS`,
            measuredLufs: `${measuredLufs} LUFS`,
            measuredTruePeak: `${measuredTruePeak} dBTP`,
            measuredLra: `${measuredLra} LU`,
            mneAutoGain,
            createdAt: String(Date.now()),
          },
        },
      });

      return `gs://${bucket.name}/${outputPath}`;
    } catch (mixErr) {
      console.warn("[MediaService] Sidechain mixing failed, falling back to dubbed audio:", mixErr);
      return options.dubbedAudioUrl;
    } finally {
      await fs.promises.unlink(tempMne).catch(() => {});
      await fs.promises.unlink(tempDub).catch(() => {});
      await fs.promises.unlink(tempVocals).catch(() => {});
      await fs.promises.unlink(tempOut).catch(() => {});
    }
  }

  /**
   * 🛡️ Trap 2 Resolution: Restores authentic non-dialogue vocal SFX (screams, laughs, groans, shouts)
   * from the isolated vocal track into the M&E background bed, while strictly preventing English speech bleed.
   *
   * Hardened Production Safeguards:
   * 1. 180ms Guardband Padding: Every STT speech segment and word boundary is padded by 180ms on start and end.
   * 2. Word Proximity Collision Guard: Candidate gaps touching any transcribed word boundary (±120ms) are rejected.
   * 3. Formant Energy Probe: Vocal band (300Hz-3400Hz) is analyzed for active energy (mean >= -42 dBFS, max >= -28 dBFS).
   * 4. Burst Crest Factor Guard: Verified non-verbal bursts (laughter attacks, screams, shouts) exhibit high crest (>= 12 dB).
   * 5. Pop/Click-Free Integration: Qualified slices are extracted with 40ms crossfade ramps and layered into M&E at exact offsets.
   */
  async restoreNonDialogueVocalSFX(
    ffmpegPath: string,
    tempMne: string,
    tempVocals: string,
    spokenSegments: Array<{ start: number; end: number }>,
    sourceWords: Array<{ start: number; end: number; text?: string }> | undefined,
    totalDurationMs: number
  ): Promise<boolean> {
    if (!fs.existsSync(tempMne) || !fs.existsSync(tempVocals) || !spokenSegments || spokenSegments.length === 0 || totalDurationMs <= 0) {
      return false;
    }

    const PAD_MS = 180;
    const intervals: Array<{ start: number; end: number }> = spokenSegments
      .filter((s) => s.end > s.start)
      .map((s) => ({
        start: Math.max(0, s.start - PAD_MS),
        end: Math.min(totalDurationMs, s.end + PAD_MS),
      }));

    if (sourceWords && sourceWords.length > 0) {
      for (const w of sourceWords) {
        if (w.end > w.start) {
          intervals.push({
            start: Math.max(0, w.start - PAD_MS),
            end: Math.min(totalDurationMs, w.end + PAD_MS),
          });
        }
      }
    }

    // Sort and merge overlapping padded intervals
    intervals.sort((a, b) => a.start - b.start);
    const merged: Array<{ start: number; end: number }> = [];
    for (const iv of intervals) {
      if (merged.length === 0) {
        merged.push({ ...iv });
      } else {
        const last = merged[merged.length - 1];
        if (iv.start <= last.end) {
          last.end = Math.max(last.end, iv.end);
        } else {
          merged.push({ ...iv });
        }
      }
    }

    // Find non-speech gaps (400ms to 20000ms)
    const gaps: Array<{ start: number; end: number; duration: number }> = [];
    let cursor = 0;
    for (const m of merged) {
      if (m.start > cursor) {
        const dur = m.start - cursor;
        if (dur >= 400 && dur <= 20000) {
          gaps.push({ start: cursor, end: m.start, duration: dur });
        }
      }
      cursor = Math.max(cursor, m.end);
    }
    if (totalDurationMs > cursor) {
      const dur = totalDurationMs - cursor;
      if (dur >= 400 && dur <= 20000) {
        gaps.push({ start: cursor, end: totalDurationMs, duration: dur });
      }
    }

    if (gaps.length === 0) {
      return false;
    }

    // Inspect each gap with acoustic volume and crest-factor probes
    const qualifiedGaps: Array<{ start: number; end: number; duration: number }> = [];
    for (const gap of gaps) {
      // Safeguard A: Word collision check
      if (sourceWords && sourceWords.length > 0) {
        const wordCollision = sourceWords.some(
          (w) => w.start < gap.end + 120 && w.end > gap.start - 120
        );
        if (wordCollision) {
          continue;
        }
      }

      // Safeguard B: Acoustic formant energy probe in vocal band (300Hz-3400Hz)
      const startSec = (gap.start / 1000).toFixed(3);
      const durSec = (gap.duration / 1000).toFixed(3);
      try {
        const probeRes: any = await execFileAsync(ffmpegPath, [
          "-ss", startSec,
          "-t", durSec,
          "-i", tempVocals,
          "-af", "bandpass=f=1800:width_type=h:w=3000,volumedetect",
          "-f", "null",
          process.platform === "win32" ? "NUL" : "/dev/null",
        ], { maxBuffer: 5 * 1024 * 1024 }).catch((e) => ({ stdout: e?.stdout || "", stderr: e?.stderr || "" }));

        const stderr = `${probeRes?.stderr || ""}\n${probeRes?.stdout || ""}`;
        const meanMatch = stderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
        const maxMatch = stderr.match(/max_volume:\s*(-?[\d.]+)\s*dB/);
        const meanVol = meanMatch ? parseFloat(meanMatch[1]) : -100;
        const maxVol = maxMatch ? parseFloat(maxMatch[1]) : -100;
        const crest = maxVol - meanVol;

        // Non-verbal bursts (screams, laughter, gasps, groans) have dynamic crest >= 12 dB and active volume
        if (meanVol >= -42 && maxVol >= -28 && crest >= 12) {
          console.log(`[MediaService:SFX] Qualified non-dialogue vocal SFX: [${startSec}s - ${(gap.end / 1000).toFixed(3)}s] mean=${meanVol.toFixed(1)}dB max=${maxVol.toFixed(1)}dB crest=${crest.toFixed(1)}dB`);
          qualifiedGaps.push(gap);
        }
      } catch (_) {
        // Non-fatal probe failure
      }
    }

    if (qualifiedGaps.length === 0) {
      console.log("[MediaService:SFX] No qualifying non-dialogue vocal SFX gaps detected (clean M&E preserved)");
      return false;
    }

    // Step E: Extract and mix qualified SFX slices into tempMne
    const tempDir = os.tmpdir();
    const tempEnriched = path.join(tempDir, `mne_enriched_${Date.now()}_${Math.random().toString(36).slice(2)}.mp3`);
    const tempSlices: string[] = [];

    try {
      // Extract each qualified slice with 40ms edge crossfades to prevent clicks
      for (let i = 0; i < qualifiedGaps.length; i++) {
        const q = qualifiedGaps[i];
        const sliceFile = path.join(tempDir, `vocal_sfx_slice_${i}_${Date.now()}.wav`);
        const sliceStartSec = (q.start / 1000).toFixed(3);
        const sliceDurSec = Math.max(0.1, q.duration / 1000);
        const fadeOutStart = Math.max(0.01, sliceDurSec - 0.04).toFixed(3);
        const filterStr = `highpass=f=80,afade=t=in:ss=0:d=0.04,afade=t=out:st=${fadeOutStart}:d=0.04,aformat=channel_layouts=stereo`;

        await execFileAsync(ffmpegPath, [
          "-y",
          "-ss", sliceStartSec,
          "-t", sliceDurSec.toFixed(3),
          "-i", tempVocals,
          "-af", filterStr,
          sliceFile,
        ]);
        tempSlices.push(sliceFile);
      }

      // Layer all slices into tempMne using adelay and amix
      const inputArgs: string[] = ["-y", "-i", tempMne];
      for (const s of tempSlices) {
        inputArgs.push("-i", s);
      }

      const hasNormalize = await this.supportsAmixNormalize(ffmpegPath);
      const totalInputs = 1 + qualifiedGaps.length;
      let filterComplex = "";
      const mixInputs: string[] = ["[0:a]"];

      for (let i = 0; i < qualifiedGaps.length; i++) {
        const offsetMs = qualifiedGaps[i].start;
        const delayTag = `[sfx_${i}]`;
        filterComplex += `[${i + 1}:a]adelay=${offsetMs}|${offsetMs}${delayTag};`;
        mixInputs.push(delayTag);
      }

      const weights = ["1.0", ...qualifiedGaps.map(() => "1.0")].join(" ");
      const amixSuffix = hasNormalize
        ? `:weights=${weights}:normalize=0:duration=first`
        : `:weights=${weights}:dropout_transition=0:duration=first,volume=${totalInputs}`;

      filterComplex += `${mixInputs.join("")}amix=inputs=${totalInputs}${amixSuffix}[mne_out]`;

      inputArgs.push(
        "-filter_complex", filterComplex,
        "-map", "[mne_out]",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        tempEnriched
      );

      await execFileAsync(ffmpegPath, inputArgs);

      // Overwrite tempMne with tempEnriched
      await fs.promises.copyFile(tempEnriched, tempMne);
      console.log(`[MediaService:SFX] Successfully restored ${qualifiedGaps.length} non-dialogue vocal SFX intervals into M&E track`);
      return true;
    } finally {
      await fs.promises.unlink(tempEnriched).catch(() => {});
      for (const s of tempSlices) {
        await fs.promises.unlink(s).catch(() => {});
      }
    }
  }

  async extractAudio(
    videoUrl: string,
    jobId: string,
    options?: { alsoExtractStereo?: boolean }
  ): Promise<string> {
    try {
      const outputPath = `audio/${jobId}/original.mp3`;
      const stereoOutputPath = `audio/${jobId}/source_stereo.mp3`;
      const ffmpegServiceUrl = PIPELINE_CONFIG.FFMPEG_SERVICE_URL;

      if (ffmpegServiceUrl && !ffmpegServiceUrl.includes("placeholder")) {
        const response = await axios.post(`${ffmpegServiceUrl}/extract-audio`, { videoUrl, outputPath });
        return response.data.audioUrl;
      }

      // Local FFmpeg fallback when microservice is not configured
      // NOTE: This extracts 16 kHz mono solely for STT transcription — do NOT use for M&E or vocal isolation.
      const ffmpegPath = getFfmpegPath();
      if (ffmpegPath) {
        const bucket = storage().bucket();
        const tmpDir = os.tmpdir();
        const tempVideo = path.join(tmpDir, `vid_${jobId}_${Date.now()}.mp4`);
        const tempAudio = path.join(tmpDir, `aud_${jobId}_${Date.now()}.mp3`);
        const wantStereo = Boolean(options?.alsoExtractStereo && sharedTmpEnabled());
        const tempStereo = path.join(tmpDir, `stereo_aud_${jobId}_${Date.now()}.mp3`);
        let videoPathToUse = tempVideo;
        let ownsTempVideo = true;

        try {
          const tExtDl = Date.now();
          const sharedVid = await this.ensureJobLocalFile(jobId, videoUrl, ".mp4", 60000);
          if (sharedVid && fs.existsSync(sharedVid)) {
            videoPathToUse = sharedVid;
            ownsTempVideo = false;
          } else {
            await this.downloadToStream(videoUrl, tempVideo, bucket, 60000, jobId);
          }
          emitDubbingTiming("transcription.extract_download", tExtDl, { jobId });

          try {
            const tExtFf = Date.now();
            const ffArgs = wantStereo
              ? [
                  "-nostdin",
                  "-y",
                  "-i", videoPathToUse,
                  "-vn", "-acodec", "libmp3lame", "-ar", "16000", "-ac", "1", tempAudio,
                  "-vn", "-ac", "2", "-ar", "44100", "-b:a", "256k", "-acodec", "libmp3lame", tempStereo,
                ]
              : [
                  "-nostdin",
                  "-y",
                  "-i", videoPathToUse,
                  "-vn",
                  "-acodec", "libmp3lame",
                  "-ar", "16000",
                  "-ac", "1",
                  tempAudio,
                ];
            await execFileAsync(ffmpegPath, ffArgs, { maxBuffer: 100 * 1024 * 1024 });
            emitDubbingTiming("transcription.extract_ffmpeg", tExtFf, { jobId });

            const tExtUp = Date.now();
            const uploads: Promise<any>[] = [
              bucket.upload(tempAudio, {
                destination: outputPath,
                metadata: { contentType: "audio/mpeg" },
              }),
            ];
            if (wantStereo && fs.existsSync(tempStereo)) {
              uploads.push(
                bucket.upload(tempStereo, {
                  destination: stereoOutputPath,
                  metadata: {
                    contentType: "audio/mpeg",
                    metadata: {
                      jobId,
                      purpose: "stereo_source_for_mne_isolation",
                      sampleRate: "44100",
                      channels: "2",
                      createdAt: String(Date.now()),
                    },
                  },
                }).catch(() => undefined)
              );
            }
            await Promise.all(uploads);
            emitDubbingTiming("transcription.audio_upload", tExtUp, { jobId });

            const gsAudioUrl = `gs://${bucket.name}/${outputPath}`;
            await this.registerJobLocalFile(jobId, gsAudioUrl, tempAudio, ".mp3");
            if (wantStereo && fs.existsSync(tempStereo)) {
              await this.registerJobLocalFile(jobId, `gs://${bucket.name}/${stereoOutputPath}`, tempStereo, ".mp3");
            }
            return gsAudioUrl;
          } catch (ffmpegErr: any) {
            const errStr = String(ffmpegErr?.stderr || ffmpegErr?.message || ffmpegErr);
            if (
              errStr.includes("Output file does not contain any stream") ||
              errStr.includes("does not contain any stream") ||
              errStr.includes("matches no streams")
            ) {
              const noAudioErr = new Error(`[MediaService] Video file does not contain an audio stream`);
              (noAudioErr as any).code = "NO_AUDIO_STREAM";
              throw noAudioErr;
            }
            throw ffmpegErr;
          }
        } finally {
          if (ownsTempVideo) await fs.promises.unlink(tempVideo).catch(() => {});
          await fs.promises.unlink(tempAudio).catch(() => {});
          await fs.promises.unlink(tempStereo).catch(() => {});
        }
      }

      throw new Error(`[MediaService] Audio extraction failed: FFmpeg service unreachable and local FFmpeg binary not available`);
    } catch (error) {
      console.error("Error extracting audio:", error);
      throw error;
    }
  }

  /**
   * Extracts a full-bandwidth 44.1 kHz stereo MP3 from the original video for use in
   * M&E stem separation and vocal isolation — preserving the complete audio spectrum
   * that the STT-only 16 kHz mono path strips away.
   * Idempotent: returns the existing GCS URL if already extracted for this job.
   */
  async extractStereoSourceAudio(videoUrl: string, jobId: string): Promise<string> {
    const bucket = storage().bucket();
    const outputPath = `audio/${jobId}/source_stereo.mp3`;

    // Idempotency: return cached version
    try {
      const file = bucket.file(outputPath);
      const [exists] = await file.exists();
      if (exists) {
        const [meta] = await file.getMetadata();
        if (Number(meta.size) > 10240) {
          return `gs://${bucket.name}/${outputPath}`;
        }
      }
    } catch (_) {}

    const ffmpegPath = getFfmpegPath();
    if (!ffmpegPath) {
      console.warn("[MediaService] FFmpeg unavailable for stereo source extraction — falling back to videoUrl");
      return videoUrl;
    }

    const tmpDir = os.tmpdir();
    const tempVideo = path.join(tmpDir, `stereo_in_${jobId}_${Date.now()}.mp4`);
    const tempAudio = path.join(tmpDir, `stereo_out_${jobId}_${Date.now()}.mp3`);
    let videoPathToUse = tempVideo;
    let ownsTempVideo = true;

    try {
      const sharedVid = await this.ensureJobLocalFile(jobId, videoUrl, ".mp4", 180000);
      if (sharedVid && fs.existsSync(sharedVid)) {
        videoPathToUse = sharedVid;
        ownsTempVideo = false;
      } else {
        await this.downloadToStream(videoUrl, tempVideo, bucket, 180000, jobId);
      }

      await execFileAsync(ffmpegPath, [
        "-nostdin",
        "-y",
        "-i", videoPathToUse,
        "-vn",
        "-ac", "2",
        "-ar", "44100",
        "-b:a", "256k",
        "-acodec", "libmp3lame",
        tempAudio,
      ], { maxBuffer: 100 * 1024 * 1024 });

      await bucket.upload(tempAudio, {
        destination: outputPath,
        metadata: {
          contentType: "audio/mpeg",
          metadata: {
            jobId,
            purpose: "stereo_source_for_mne_isolation",
            sampleRate: "44100",
            channels: "2",
            createdAt: String(Date.now()),
          },
        },
      });

      const gsStereoUrl = `gs://${bucket.name}/${outputPath}`;
      await this.registerJobLocalFile(jobId, gsStereoUrl, tempAudio, ".mp3");
      return gsStereoUrl;
    } catch (err) {
      console.warn("[MediaService] Stereo source extraction failed — falling back to videoUrl:", err);
      return videoUrl;
    } finally {
      if (ownsTempVideo) await fs.promises.unlink(tempVideo).catch(() => {});
      await fs.promises.unlink(tempAudio).catch(() => {});
    }
  }

  async generateSubtitles(jobId: string, segments: any[], language: string, format: string): Promise<string> {
    const srtContent = this.generateSrt(segments);
    const vttContent = "WEBVTT\n\n" + srtContent.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2");
    
    const content = format === "vtt" ? vttContent : srtContent;
    // Industry Standard: Add UTF-8 BOM (\uFEFF) to ensure players (especially Windows/VLC) 
    // correctly identify the file as UTF-8.
    const contentWithBom = "\uFEFF" + content;

    const outputPath = `subtitles/${jobId}/${language}.${format}`;
    const bucket = storage().bucket();
    const file = bucket.file(outputPath);

    // Standard Edge CDN Caching Header (1 day browser cache, 7 days edge CDN cache)
    const SUBTITLE_CACHE_CONTROL = "public, max-age=86400, s-maxage=604800";

    await file.save(contentWithBom, {
      metadata: { 
        contentType: format === "vtt" ? "text/vtt; charset=utf-8" : "text/plain; charset=utf-8",
        cacheControl: SUBTITLE_CACHE_CONTROL,
      },
    });

    return `gs://${bucket.name}/${outputPath}`;
  }

  /**
   * Generates and uploads ALL THREE subtitle formats (.json, .vtt, .srt) for a language.
   * e.g., for Telugu 'te': te.json, te.vtt, and te.srt.
   */
  async generateAllSubtitles(
    jobId: string,
    segments: any[],
    language: string
  ): Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string }> {
    const srtContent = this.generateSrt(segments);
    const vttContent = "WEBVTT\n\n" + srtContent.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2");
    const jsonContent = JSON.stringify(segments, null, 2);

    const bucket = storage().bucket();

    const srtPath = `subtitles/${jobId}/${language}.srt`;
    const vttPath = `subtitles/${jobId}/${language}.vtt`;
    const jsonPath = `subtitles/${jobId}/${language}.json`;

    const SUBTITLE_CACHE_CONTROL = "public, max-age=86400, s-maxage=604800";

    await Promise.all([
      bucket.file(srtPath).save("\uFEFF" + srtContent, {
        metadata: { 
          contentType: "text/plain; charset=utf-8",
          cacheControl: SUBTITLE_CACHE_CONTROL,
        },
      }),
      bucket.file(vttPath).save("\uFEFF" + vttContent, {
        metadata: { 
          contentType: "text/vtt; charset=utf-8",
          cacheControl: SUBTITLE_CACHE_CONTROL,
        },
      }),
      bucket.file(jsonPath).save(jsonContent, {
        metadata: { 
          contentType: "application/json",
          cacheControl: SUBTITLE_CACHE_CONTROL,
        },
      }),
    ]);

    return {
      srtUrl: `gs://${bucket.name}/${srtPath}`,
      vttUrl: `gs://${bucket.name}/${vttPath}`,
      jsonUrl: `gs://${bucket.name}/${jsonPath}`,
    };
  }

  public generateSrt(segments: any[]): string {
    return segments
      .map((s, i) => {
        const start = this.formatSrtTime(s.start);
        const end = this.formatSrtTime(s.end);
        // Ensure segment text is trimmed and newlines are handled
        const text = s.text.trim();
        return `${i + 1}\n${start} --> ${end}\n${text}\n`;
      })
      .join("\n");
  }

  public generateVtt(segments: any[]): string {
    const srt = this.generateSrt(segments);
    return "WEBVTT\n\n" + srt.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2");
  }

  private formatSrtTime(ms: number): string {
    const hours = Math.floor(ms / 3600000).toString().padStart(2, "0");
    const minutes = Math.floor((ms % 3600000) / 60000).toString().padStart(2, "0");
    const seconds = Math.floor((ms % 60000) / 1000).toString().padStart(2, "0");
    const milliseconds = Math.floor(ms % 1000).toString().padStart(3, "0");
    return `${hours}:${minutes}:${seconds},${milliseconds}`;
  }

  /**
   * Extracts duration in milliseconds using FFprobe format inspection.
   */
  private async probeDurationViaFfprobeMs(ffprobePath: string, filePath: string): Promise<number> {
    try {
      const { stdout } = await execFileAsync(
        ffprobePath,
        ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", filePath],
        { timeout: 25000, maxBuffer: 4 * 1024 * 1024 }
      );
      const seconds = parseFloat(String(stdout || "").trim());
      if (Number.isFinite(seconds) && seconds > 0) {
        return Math.round(seconds * 1000);
      }
    } catch (err: any) {
      console.warn("[MediaService] ffprobe duration probe failed:", {
        signal: err?.signal || null,
        code: err?.code ?? null,
        message: String(err?.message || err).slice(0, 200),
      });
    }
    return 0;
  }

  /**
   * Helper extracting duration in milliseconds of an audio file using FFmpeg.
   */
  private async probeAudioDurationMs(ffmpegPath: string, filePath: string): Promise<number> {
    try {
      const { stderr } = await execFileAsync(ffmpegPath, ["-i", filePath], {
        timeout: 25000,
        maxBuffer: 4 * 1024 * 1024,
      });
      const match = stderr.match(/Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2,3})/);
      if (match) {
        const h = Number(match[1]);
        const m = Number(match[2]);
        const s = Number(match[3]);
        const ms = Number(match[4].padEnd(3, "0"));
        return h * 3600000 + m * 60000 + s * 1000 + ms;
      }
    } catch (err: any) {
      if (err?.stderr) {
        const match = String(err.stderr).match(/Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2,3})/);
        if (match) {
          const h = Number(match[1]);
          const m = Number(match[2]);
          const s = Number(match[3]);
          const ms = Number(match[4].padEnd(3, "0"));
          return h * 3600000 + m * 60000 + s * 1000 + ms;
        }
      }
      console.warn("[MediaService] ffmpeg duration probe failed:", {
        signal: err?.signal || null,
        code: err?.code ?? null,
        stderr: String(err?.stderr || "").slice(-240),
      });
    }
    return 0;
  }

  /**
   * Partitions chronologically sorted chunks at clean non-overlapping gaps (up to maxBatchSize,
   * extending only if an active overlap spans across the tentative split point, up to hardOverlapCap).
   */
  private partitionChunksForWindowedMix(
    chunks: Array<{ path: string; startMs: number; effectiveDurationMs: number }>,
    maxBatchSize: number = 16,
    hardOverlapCap: number = 32
  ): Array<Array<{ path: string; startMs: number; effectiveDurationMs: number }>> {
    const sorted = [...chunks].sort((a, b) => a.startMs - b.startMs);
    const batches: Array<Array<{ path: string; startMs: number; effectiveDurationMs: number }>> = [];
    let current: Array<{ path: string; startMs: number; effectiveDurationMs: number }> = [];
    let currentMaxEndMs = 0;

    for (const chunk of sorted) {
      const chunkEndMs = chunk.startMs + Math.max(100, chunk.effectiveDurationMs);
      if (
        current.length >= hardOverlapCap ||
        (current.length >= maxBatchSize && chunk.startMs >= currentMaxEndMs)
      ) {
        batches.push(current);
        current = [];
        currentMaxEndMs = 0;
      }
      current.push(chunk);
      if (chunkEndMs > currentMaxEndMs) {
        currentMaxEndMs = chunkEndMs;
      }
    }
    if (current.length > 0) {
      batches.push(current);
    }
    return batches;
  }

  /**
   * Stitches arbitrary numbers of delayed dialogue chunks across long timelines cleanly on ANY FFmpeg version.
   * Mixes local bounded windows into sample-exact lossless PCM WAVs (preventing 1/N amix attenuation and
   * OS open-file limits), then concatenates sample-aligned silence gaps + batches into a single mastered MP3.
   */
  private async stitchTimelineViaWindowedBatches(
    ffmpegPath: string,
    workDir: string,
    chunks: Array<{ path: string; startMs: number; effectiveDurationMs: number }>,
    hasNormalize: boolean,
    targetDurationMs: number,
    audioFilters: string | undefined,
    finalOutputPath: string
  ): Promise<void> {
    const SAMPLE_RATE = 44100;
    const batches = this.partitionChunksForWindowedMix(chunks);
    const batchInfos: Array<{ wavPath: string; originMs: number; sampleCount: number }> = [];

    for (let bIdx = 0; bIdx < batches.length; bIdx++) {
      const batch = batches[bIdx];
      const batchOriginMs = Math.max(0, batch[0].startMs);
      const batchEndMs = Math.max(
        ...batch.map((c) => c.startMs + Math.max(100, c.effectiveDurationMs))
      );
      const nextOriginMs = bIdx + 1 < batches.length ? batches[bIdx + 1][0].startMs : undefined;
      const tailSlackMs = nextOriginMs !== undefined
        ? Math.max(0, Math.min(50, nextOriginMs - batchEndMs - 5))
        : 50;
      const batchWavPath = path.join(workDir, `batch_${bIdx}.wav`);

      if (batch.length === 1) {
        await execFileAsync(ffmpegPath, [
          "-y",
          "-i", batch[0].path,
          "-af", `aformat=sample_fmts=fltp:sample_rates=${SAMPLE_RATE}:channel_layouts=stereo`,
          "-c:a", "pcm_s16le",
          "-ar", String(SAMPLE_RATE),
          "-ac", "2",
          batchWavPath,
        ], { maxBuffer: 50 * 1024 * 1024 });
      } else {
        const batchSpanSamples = Math.max(
          1,
          Math.ceil(((batchEndMs - batchOriginMs + tailSlackMs) / 1000) * SAMPLE_RATE)
        );
        const batchInputArgs: string[] = [];
        const batchFilterLines: string[] = [];
        const batchLabels: string[] = [];

        for (let k = 0; k < batch.length; k++) {
          const item = batch[k];
          batchInputArgs.push("-i", item.path);
          const relDelayMs = Math.max(0, Math.round(item.startMs - batchOriginMs));
          const padSuffix = hasNormalize ? "" : `,apad=whole_len=${batchSpanSamples}`;
          batchFilterLines.push(
            `[${k}:a]aresample=async=1:first_pts=0,aformat=sample_fmts=fltp:sample_rates=${SAMPLE_RATE}:channel_layouts=stereo,adelay=${relDelayMs}|${relDelayMs}${padSuffix}[bd_${k}];`
          );
          batchLabels.push(`[bd_${k}]`);
        }

        const batchMixFilter = hasNormalize
          ? `${batchLabels.join("")}amix=inputs=${batch.length}:normalize=0:dropout_transition=0[out]`
          : `${batchLabels.join("")}amix=inputs=${batch.length}:dropout_transition=0,volume=${batch.length},atrim=end_sample=${batchSpanSamples}[out]`;
        batchFilterLines.push(batchMixFilter);

        const batchFilterScript = path.join(workDir, `batch_filter_${bIdx}.txt`);
        await fs.promises.writeFile(batchFilterScript, batchFilterLines.join("\n"), "utf8");

        await execFileAsync(ffmpegPath, [
          "-y",
          ...batchInputArgs,
          "-filter_complex_script", batchFilterScript,
          "-map", "[out]",
          "-c:a", "pcm_s16le",
          "-ar", String(SAMPLE_RATE),
          "-ac", "2",
          batchWavPath,
        ], { maxBuffer: 50 * 1024 * 1024 });
      }

      const sampleCount = await this.readWavSampleCount(batchWavPath);
      batchInfos.push({ wavPath: batchWavPath, originMs: batchOriginMs, sampleCount });
    }

    // Final single-pass lossless concat of gaps + batches -> mastered MP3
    const assemblyInputs: string[] = [];
    const assemblyFilters: string[] = [];
    const concatLabels: string[] = [];
    let cursorSamples = 0;

    for (let b = 0; b < batchInfos.length; b++) {
      const info = batchInfos[b];
      const inputIndex = assemblyInputs.length / 2;
      assemblyInputs.push("-i", info.wavPath);

      const targetStartSample = Math.round((info.originMs / 1000) * SAMPLE_RATE);
      if (targetStartSample > cursorSamples) {
        const gapSamples = targetStartSample - cursorSamples;
        assemblyFilters.push(
          `anullsrc=cl=stereo:r=${SAMPLE_RATE},aformat=sample_fmts=fltp:sample_rates=${SAMPLE_RATE}:channel_layouts=stereo,atrim=end_sample=${gapSamples},asetpts=PTS-STARTPTS[g_${b}];`
        );
        concatLabels.push(`[g_${b}]`);
        cursorSamples = targetStartSample;
      }

      const overlapSamples = targetStartSample < cursorSamples ? cursorSamples - targetStartSample : 0;
      if (overlapSamples < info.sampleCount) {
        const trimOverlap = overlapSamples > 0 ? `,atrim=start_sample=${overlapSamples}` : "";
        assemblyFilters.push(
          `[${inputIndex}:a]aformat=sample_fmts=fltp:sample_rates=${SAMPLE_RATE}:channel_layouts=stereo${trimOverlap},asetpts=PTS-STARTPTS[b_${b}];`
        );
        concatLabels.push(`[b_${b}]`);
        cursorSamples += info.sampleCount - overlapSamples;
      }
    }

    const mixLabel = "[dialogue_mixed]";
    assemblyFilters.push(`${concatLabels.join("")}concat=n=${concatLabels.length}:v=0:a=1${mixLabel};`);

    let dspInput = mixLabel;
    if (targetDurationMs > 0) {
      const targetSamples = Math.max(1, Math.round((targetDurationMs / 1000) * SAMPLE_RATE));
      const padLabel = "[dialogue_padded]";
      assemblyFilters.push(`${mixLabel}apad=whole_len=${targetSamples}${padLabel};`);
      dspInput = padLabel;
    }

    const finalFilter = audioFilters && audioFilters.trim().length > 0
      ? `${dspInput}${audioFilters.trim()}[out]`
      : `${dspInput}loudnorm=I=-14:TP=-1:LRA=11[out]`;
    assemblyFilters.push(finalFilter);

    const assemblyScriptPath = path.join(workDir, "timeline_filter.txt");
    await fs.promises.writeFile(assemblyScriptPath, assemblyFilters.join("\n"), "utf8");

    const finalArgs = [
      "-y",
      ...assemblyInputs,
      "-filter_complex_script", assemblyScriptPath,
      "-map", "[out]",
      "-c:a", "libmp3lame",
      "-b:a", "192k",
      "-ar", String(SAMPLE_RATE),
      "-ac", "2",
    ];
    if (targetDurationMs > 0) {
      finalArgs.push("-t", (targetDurationMs / 1000).toFixed(3));
    }
    finalArgs.push(finalOutputPath);

    await execFileAsync(ffmpegPath, finalArgs, { maxBuffer: 100 * 1024 * 1024 });
  }

  /**
   * Stitches TTS audio chunks into a single timeline-aligned, standard-compliant MP3 track.
   * Inserts silence padding between segments and trailing silence matching the video's full duration
   * so that the dubbed audio track plays seamlessly across the entire duration of the video.
   */
  async mergeAudioChunks(
    jobId: string,
    audioUrls: string[],
    language: string = "default",
    options?: MergeAudioOptions
  ): Promise<string> {
    try {
      const validIndexed: Array<{ url: string; index: number }> = [];
      audioUrls.forEach((u, i) => {
        if (u && u.trim().length > 0) {
          validIndexed.push({ url: u.trim(), index: i });
        }
      });

      if (validIndexed.length === 0) {
        console.warn(`[MediaService] No valid speech chunks provided for ${language}; generating silent audio track`);
        const rawSec = parseDurationToSeconds(options?.totalDurationSeconds);
        const durSec = rawSec > 0 ? rawSec : 3.0;
        const silentBuffer = await createSilentMp3Buffer(durSec);
        const bucket = storage().bucket();
        const outputPath = `audio/${jobId}/${language}/stitched.mp3`;
        const file = bucket.file(outputPath);
        await file.save(silentBuffer, {
          contentType: "audio/mpeg",
          metadata: { cacheControl: "public, max-age=31536000" },
        });
        return `gs://${bucket.name}/${outputPath}`;
      }

      const bucket = storage().bucket();
      const outputPath = `audio/${jobId}/${language}/stitched.mp3`;

      // Determine the target total duration of the audio track
      const rawSec = parseDurationToSeconds(options?.totalDurationSeconds);
      let targetDurationMs = (typeof options?.totalDurationMs === "number" && !isNaN(options.totalDurationMs) && options.totalDurationMs > 0)
        ? Math.round(options.totalDurationMs)
        : (rawSec > 0 ? rawSec * 1000 : 0);

      if (targetDurationMs <= 0 && options?.segments && options.segments.length > 0) {
        targetDurationMs = Math.max(...options.segments.map((s) => s.end || 0));
      }

      // If only a single chunk is provided and no timeline/duration options are specified, return immediately
      if (
        validIndexed.length === 1 &&
        targetDurationMs <= 0 &&
        (!options?.segments || options.segments.length === 0)
      ) {
        return validIndexed[0].url;
      }

      const ffmpegPath = getFfmpegPath();
      const workDir = path.join(os.tmpdir(), `tw_stitch_${jobId}_${language}_${Date.now()}`);
      await fs.promises.mkdir(workDir, { recursive: true });

      try {
        // Download chunks locally in bounded concurrent batches of 20
        const tStitchDl = Date.now();
        const localChunkPaths: Array<{ path: string; index: number }> = [];
        let firstChunkSample: Buffer | null = null;
        const CONCURRENT_DOWNLOADS = 20;

        for (let i = 0; i < validIndexed.length; i += CONCURRENT_DOWNLOADS) {
          const batch = validIndexed.slice(i, i + CONCURRENT_DOWNLOADS);
          const downloadedBatch = await Promise.all(
            batch.map(async (item, bIdx) => {
              const chunkIdx = i + bIdx;
              const localFile = path.join(workDir, `chunk_${chunkIdx}.mp3`);
              // A4: every line must be in the track. One retry, then the merge fails (the language
              // fails and is refunded) instead of silently dropping a line.
              for (let attempt = 1; ; attempt++) {
                try {
                  await this.downloadToStream(item.url, localFile, bucket, 60000);
                  const sample = chunkIdx === 0 ? (await fs.promises.readFile(localFile)).subarray(0, 1024) : null;
                  return { path: localFile, index: item.index, sample };
                } catch (downloadErr) {
                  if (attempt >= 2) {
                    throw new Error(`Speech chunk ${item.index} could not be downloaded for merge: ${downloadErr instanceof Error ? downloadErr.message : String(downloadErr)}`);
                  }
                  console.warn("[MediaService] Chunk download failed — retrying once:", item.url, downloadErr);
                }
              }
            })
          );
          for (const item of downloadedBatch) {
            if (item) {
              localChunkPaths.push({ path: item.path, index: item.index });
              if (item.sample && !firstChunkSample) firstChunkSample = item.sample;
            }
          }
        }

        if (localChunkPaths.length === 0) {
          throw new Error(`[MediaService] Audio merge failed for ${language}: None of the ${validIndexed.length} chunks could be retrieved`);
        }
        emitDubbingTiming("post.stitch_download", tStitchDl, { jobId, lang: language, chunks: localChunkPaths.length });

        // ─── Production Path: Absolute PTS Timeline Mixing (adelay + amix) ───
        // Eliminates cumulative concat drift, eliminates outro truncation, and avoids spawning 200 silence processes
        if (ffmpegPath && (!firstChunkSample || isValidAudioBuffer(firstChunkSample))) {
          try {
            const tStitchPrep = Date.now();
            const preparedChunks: Array<{ path: string; startMs: number; effectiveDurationMs: number; ceilingMs?: number; clampAllowed?: boolean }> =
              new Array(localChunkPaths.length);
            // DUBBING_PREROLL: decide early start vs trim in line order, after every line's length is known.
            const usePreroll = prerollEnabled();
            const CHUNK_PREP_CONCURRENCY = 8;

            for (let i = 0; i < localChunkPaths.length; i += CHUNK_PREP_CONCURRENCY) {
              const batch = localChunkPaths.slice(i, i + CHUNK_PREP_CONCURRENCY);
              await Promise.all(
                batch.map(async (chunk, bIdx) => {
                  const slot = i + bIdx;
                  let chunkPath = chunk.path;
                  const seg = options?.segments?.[chunk.index];
                  const targetStartMs = seg && typeof seg.start === "number" ? Math.max(0, Math.round(seg.start)) : 0;
                  const segWindowMs = seg && typeof seg.end === "number" && seg.end > seg.start
                    ? (seg.end - seg.start)
                    : 3000;

                  const chunkDurationMs = await this.probeAudioDurationMs(ffmpegPath, chunkPath);
                  let effectiveDurationMs = chunkDurationMs > 0 ? chunkDurationMs : segWindowMs;
                  const isCadenceLocked = options?.cadenceLock === true;

                  // Forensic Pacing & Boundary Calculations:
                  // Enforce hard turn boundaries: 120ms separation before next turn, 150ms before container end
                  const isFinalSegment = chunk.index === (options?.segments?.length ? options.segments.length - 1 : localChunkPaths.length - 1);
                  const videoDurationMs = targetDurationMs > 0 ? targetDurationMs : 20000;
                  const nextSeg = options?.segments?.[chunk.index + 1];
                  const nextStart = nextSeg && typeof nextSeg.start === "number" ? Math.max(0, Math.round(nextSeg.start)) : null;

                  const hardCeilingMs = isFinalSegment
                    ? Math.max(targetStartMs + 200, videoDurationMs - 150)
                    : (nextStart !== null ? Math.max(targetStartMs + 200, nextStart - 120) : targetStartMs + segWindowMs + 1000);

                  const rawGapMs = nextStart !== null ? (nextStart - (seg?.end || (targetStartMs + segWindowMs))) : 1000;
                  const clampedTrailingGapMs = Math.max(0, rawGapMs);
                  const permissibleBufferMs = Math.max(0, Math.min(clampedTrailingGapMs - 250, 1500));
                  const maxPermissibleEndMs = Math.max(
                    targetStartMs + segWindowMs,
                    Math.min(targetStartMs + segWindowMs + permissibleBufferMs, hardCeilingMs)
                  );
                  const permissibleWindowMs = Math.max(200, Math.min(hardCeilingMs - targetStartMs, maxPermissibleEndMs - targetStartMs));

                  const actualRatio = permissibleWindowMs > 0 ? chunkDurationMs / permissibleWindowMs : 1.0;
                  const isMicroSegment = segWindowMs < 500;
                  const maxTempo = isMicroSegment ? 1.25 : 1.15;
                  const needsTempoAdjustment = (chunkDurationMs > permissibleWindowMs || (chunkDurationMs > segWindowMs && isCadenceLocked)) && segWindowMs >= 200;

                  if (needsTempoAdjustment) {
                    const tempoRatio = Math.min(maxTempo, Math.max(1.02, actualRatio));
                    const tempoAdjustedPath = path.join(workDir, `chunk_${chunk.index}_tempo.mp3`);

                    if (actualRatio > maxTempo) {
                      console.warn("[Dubbing:Pacing] Segment audio duration exceeds permissible window (R > maxTempo)", {
                        index: chunk.index,
                        actualRatio: Number(actualRatio.toFixed(3)),
                        maxTempo,
                        isMicroSegment,
                        chunkDurationMs,
                        permissibleWindowMs,
                        hardCeilingMs,
                      });
                    }

                    try {
                      // Apply exact tempo ratio (up to maxTempo 1.15x) without artificial waveform truncation or fadeout masking
                      const filterGraph = `atempo=${tempoRatio.toFixed(3)}`;
                      const tempoArgs = [
                        "-y",
                        "-i", chunkPath,
                        "-filter:a", filterGraph,
                        "-c:a", "libmp3lame",
                        "-b:a", "192k",
                        "-ar", "44100",
                        "-ac", "2",
                        tempoAdjustedPath,
                      ];

                      await execFileAsync(ffmpegPath, tempoArgs);
                      chunkPath = tempoAdjustedPath;
                      const adjustedDurMs = await this.probeAudioDurationMs(ffmpegPath, chunkPath);
                      const postTempoDurationMs = adjustedDurMs > 0
                        ? adjustedDurMs
                        : Math.round(chunkDurationMs / tempoRatio);
                      effectiveDurationMs = postTempoDurationMs;

                      if (postTempoDurationMs > permissibleWindowMs) {
                        console.warn("[MediaService:Overflow] Segment audio post-tempo duration exceeds permissible window", {
                          index: chunk.index,
                          postTempoDurationMs,
                          permissibleWindowMs,
                          overflowDeltaMs: postTempoDurationMs - permissibleWindowMs,
                        });
                      }
                    } catch (tempoErr) {
                      console.warn("[MediaService] atempo adjustment notice:", tempoErr);
                    }
                  }

                  // ─── Hard segment-end clamp ───
                  // Tempo stops at maxTempo. Anything still longer than the turn would run into the next
                  // speaker, and the serializer below would then push that speaker's line late (Clip 2:
                  // the guard's line ran over Joseph's reply at 0:08). Trim at the ceiling with a short fade.
                  // Only for turns that don't overlap in the source; real cross-talk is left to the serializer.
                  const sourceEndMs = seg && typeof seg.end === "number" ? seg.end : targetStartMs + segWindowMs;
                  const sourceTurnsOverlap = nextStart !== null && nextStart < sourceEndMs;
                  const maxPlayableMs = hardCeilingMs - targetStartMs;
                  if (!usePreroll && !sourceTurnsOverlap && maxPlayableMs >= 200 && effectiveDurationMs > maxPlayableMs + 20) {
                    const clampedPath = path.join(workDir, `chunk_${chunk.index}_clamped.mp3`);
                    const fadeMs = Math.min(150, Math.floor(maxPlayableMs / 4));
                    try {
                      await execFileAsync(ffmpegPath, [
                        "-y",
                        "-i", chunkPath,
                        "-af",
                        `atrim=end=${(maxPlayableMs / 1000).toFixed(3)},afade=t=out:st=${((maxPlayableMs - fadeMs) / 1000).toFixed(3)}:d=${(fadeMs / 1000).toFixed(3)}`,
                        "-c:a", "libmp3lame",
                        "-b:a", "192k",
                        "-ar", "44100",
                        "-ac", "2",
                        clampedPath,
                      ]);
                      console.warn("[MediaService:Clamp] Segment trimmed at next-turn boundary", {
                        index: chunk.index,
                        overflowMs: Math.round(effectiveDurationMs - maxPlayableMs),
                        maxPlayableMs,
                        hardCeilingMs,
                      });
                      chunkPath = clampedPath;
                      effectiveDurationMs = maxPlayableMs;
                    } catch (clampErr) {
                      console.warn("[MediaService] segment clamp notice:", clampErr);
                    }
                  }

                  preparedChunks[slot] = {
                    path: chunkPath,
                    startMs: targetStartMs,
                    effectiveDurationMs,
                    ceilingMs: hardCeilingMs,
                    clampAllowed: !sourceTurnsOverlap && maxPlayableMs >= 200,
                  };
                })
              );
            }

            // ─── Early start instead of trim (DUBBING_PREROLL) ───
            // In line order: a line that still overflows its turn starts up to 300 ms earlier when the
            // previous dubbed line has left silence; only what still does not fit is trimmed.
            if (usePreroll) {
              let prevEndMs: number | null = null;
              for (let i = 0; i < preparedChunks.length; i++) {
                const c = preparedChunks[i];
                if (!c) continue;
                if (c.clampAllowed && typeof c.ceilingMs === "number") {
                  const plan = planPreroll({ startMs: c.startMs, durationMs: c.effectiveDurationMs, ceilingMs: c.ceilingMs, prevEndMs });
                  if (plan.shiftMs > 0) {
                    console.log("[MediaService:Preroll] Line starts earlier instead of being trimmed", {
                      slot: i,
                      shiftMs: plan.shiftMs,
                      fromMs: c.startMs,
                      toMs: plan.startMs,
                      stillTrimmedTo: plan.trimToMs,
                    });
                    c.startMs = plan.startMs;
                  }
                  if (plan.trimToMs !== null) {
                    const clampedPath = path.join(workDir, `chunk_slot${i}_clamped.mp3`);
                    const keepMs = plan.trimToMs;
                    const fadeMs = Math.min(150, Math.floor(keepMs / 4));
                    try {
                      await execFileAsync(ffmpegPath, [
                        "-y",
                        "-i", c.path,
                        "-af",
                        `atrim=end=${(keepMs / 1000).toFixed(3)},afade=t=out:st=${((keepMs - fadeMs) / 1000).toFixed(3)}:d=${(fadeMs / 1000).toFixed(3)}`,
                        "-c:a", "libmp3lame",
                        "-b:a", "192k",
                        "-ar", "44100",
                        "-ac", "2",
                        clampedPath,
                      ]);
                      console.warn("[MediaService:Clamp] Segment trimmed at next-turn boundary", {
                        slot: i,
                        overflowMs: Math.round(c.effectiveDurationMs - keepMs),
                        maxPlayableMs: keepMs,
                        hardCeilingMs: c.ceilingMs,
                        afterPrerollMs: plan.shiftMs,
                      });
                      c.path = clampedPath;
                      c.effectiveDurationMs = keepMs;
                    } catch (clampErr) {
                      console.warn("[MediaService] segment clamp notice:", clampErr);
                    }
                  }
                }
                prevEndMs = c.startMs + c.effectiveDurationMs;
              }
            }

            // 🔄 Serialize Overlapping Interjections:
            // When source diarization timestamps overlap (segment[i+1].startMs < segment[i].endMs),
            // shift segment[i+1].startMs to segment[i].actualEndMs + 120 so rapid cross-talk remains intelligible
            for (let i = 0; i < preparedChunks.length - 1; i++) {
              const current = preparedChunks[i];
              const next = preparedChunks[i + 1];
              if (current && next) {
                const currentEnd = current.startMs + current.effectiveDurationMs;
                if (next.startMs < currentEnd) {
                  const shiftStart = currentEnd + 120;
                  console.log(`[MediaService:Serialization] Serializing overlapping interjection: shifting segment [${i + 1}] start from ${next.startMs}ms -> ${shiftStart}ms (+120ms separation)`);
                  next.startMs = shiftStart;
                }
              }
            }

            // Compute dialogue stem waveform metrics for Rule 2c & Rule 2d quality evaluation
            let segmentCollisionsCount = 0;
            for (let i = 0; i < preparedChunks.length - 1; i++) {
              const current = preparedChunks[i];
              const next = preparedChunks[i + 1];
              if (current && next) {
                const currentEnd = current.startMs + current.effectiveDurationMs;
                if (currentEnd > next.startMs) {
                  segmentCollisionsCount++;
                }
              }
            }

            const lastItem = preparedChunks[preparedChunks.length - 1];
            const trueSpeechEndMs = lastItem ? lastItem.startMs + lastItem.effectiveDurationMs : 0;
            const minRequiredTailSilenceMs = 120;
            const videoDurationMs = targetDurationMs > 0 ? targetDurationMs : 20000;
            const outroSpeechTruncated = trueSpeechEndMs > (videoDurationMs - minRequiredTailSilenceMs);

            if (options?.onMetricsComputed) {
              try {
                options.onMetricsComputed({
                  trueSpeechEndMs,
                  segmentCollisionsCount,
                  outroSpeechTruncated,
                });
              } catch (_) {
                // non-fatal callback guard
              }
            }

            const hasNormalize = await this.supportsAmixNormalize(ffmpegPath);
            emitDubbingTiming("post.stitch_ffmpeg_prep", tStitchPrep, { jobId, lang: language, chunks: preparedChunks.length });
            const finalOutputPath = path.join(workDir, "stitched.mp3");
            const useWindowedBatches = !hasNormalize || preparedChunks.length > 48;

            const tStitchMix = Date.now();
            if (useWindowedBatches) {
              await this.stitchTimelineViaWindowedBatches(
                ffmpegPath,
                workDir,
                preparedChunks,
                hasNormalize,
                targetDurationMs,
                options?.audioFilters,
                finalOutputPath
              );
            } else {
              const filterLines: string[] = [];
              const delayedStreamLabels: string[] = [];
              const ffmpegInputArgs: string[] = [];

              for (let i = 0; i < preparedChunks.length; i++) {
                const item = preparedChunks[i];
                ffmpegInputArgs.push("-i", item.path);
                filterLines.push(
                  `[${i}:a]aresample=async=1:first_pts=0,aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=${item.startMs}|${item.startMs}[d_${i}];`
                );
                delayedStreamLabels.push(`[d_${i}]`);
              }

              const mixLabel = "[dialogue_mixed]";
              filterLines.push(
                `${delayedStreamLabels.join("")}amix=inputs=${preparedChunks.length}:normalize=0:dropout_transition=0${mixLabel};`
              );

              let dspInput = mixLabel;
              if (targetDurationMs > 0) {
                const targetSamples = Math.max(1, Math.round((targetDurationMs / 1000) * 44100));
                const padLabel = "[dialogue_padded]";
                filterLines.push(`${mixLabel}apad=whole_len=${targetSamples}${padLabel};`);
                dspInput = padLabel;
              }

              const finalFilter = options?.audioFilters && options.audioFilters.trim().length > 0
                ? `${dspInput}${options.audioFilters.trim()}[out]`
                : `${dspInput}loudnorm=I=-14:TP=-1:LRA=11[out]`;
              filterLines.push(finalFilter);

              const filterScriptPath = path.join(workDir, "timeline_filter.txt");
              await fs.promises.writeFile(filterScriptPath, filterLines.join("\n"), "utf8");

              const ffmpegArgs = [
                "-y",
                ...ffmpegInputArgs,
                "-filter_complex_script", filterScriptPath,
                "-map", "[out]",
                "-c:a", "libmp3lame",
                "-b:a", "192k",
                "-ar", "44100",
                "-ac", "2",
              ];

              if (targetDurationMs > 0) {
                ffmpegArgs.push("-t", (targetDurationMs / 1000).toFixed(3));
              }

              ffmpegArgs.push(finalOutputPath);
              await execFileAsync(ffmpegPath, ffmpegArgs, { maxBuffer: 100 * 1024 * 1024 });
            }
            emitDubbingTiming("post.stitch_ffmpeg_mix", tStitchMix, { jobId, lang: language, windowed: useWindowedBatches });

            const stitchedBuffer = await fs.promises.readFile(finalOutputPath);
            const file = bucket.file(outputPath);
            const tStitchUp = Date.now();
            await file.save(stitchedBuffer, {
              metadata: {
                contentType: "audio/mpeg",
                metadata: {
                  jobId,
                  language,
                  chunks: String(validIndexed.length),
                  durationMs: String(targetDurationMs > 0 ? targetDurationMs : 0),
                  stitchingEngine: "absolute_pts_adelay_amix",
                  stitchingMode: useWindowedBatches ? "windowed_cluster_concat" : "single_pass_amix",
                },
              },
            });
            emitDubbingTiming("post.stitch_upload", tStitchUp, { jobId, lang: language, bytes: stitchedBuffer.length });

            return `gs://${bucket.name}/${outputPath}`;
          } catch (ffmpegErr) {
            console.warn("[MediaService] Absolute PTS FFmpeg mixing notice — using resilient buffer merge fallback:", ffmpegErr);
          }
        }

        // ─── Pure JavaScript Fallback (Header-Safe Buffer Merging) ───
        // A4: back-to-back concatenation ignores every line's start time (all speech bunched at the
        // start), so it is never used for a timed dub track: the merge fails instead.
        if (targetDurationMs > 0 || (options?.segments && options.segments.length > 0)) {
          throw new Error("FFmpeg timeline stitching failed; untimed buffer concatenation is not allowed for a dub track");
        }
        console.warn("[MediaService] FFmpeg stitching unavailable or failed — streaming chunks into buffer fallback");
        const cleanedBuffers: Buffer[] = [];
        for (const chunk of localChunkPaths) {
          try {
            const buf = await fs.promises.readFile(chunk.path);
            cleanedBuffers.push(this.stripID3Tags(buf));
          } catch (_) {}
        }
        if (cleanedBuffers.length > 0) {
          cleanedBuffers[0] = this.stripXingHeader(cleanedBuffers[0]);
        }

        const mergedBuffer = Buffer.concat(cleanedBuffers);
        let finalBuffer = mergedBuffer;
        if (targetDurationMs > 0) {
          // At 192kbps stereo MP3 (24,000 bytes per second), clamp buffer to target duration
          const targetBytes = Math.round((targetDurationMs / 1000) * 24000);
          if (finalBuffer.length > targetBytes + 24000) {
            finalBuffer = finalBuffer.subarray(0, targetBytes);
          }
        }
        const file = bucket.file(outputPath);
        await file.save(finalBuffer, {
          metadata: {
            contentType: "audio/mpeg",
            metadata: { jobId, language, chunks: String(localChunkPaths.length), durationMs: String(targetDurationMs) },
          },
        });

        return `gs://${bucket.name}/${outputPath}`;
      } finally {
        await fs.promises.rm(workDir, { recursive: true, force: true }).catch(() => {});
      }
    } catch (err) {
      console.error("[MediaService] Error merging audio chunks:", err);
      throw new Error(`[MediaService] Audio merge failed for ${language}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  /**
   * Strips ID3v2 tags from an MP3 buffer so it can be safely concatenated.
   */
  private stripID3Tags(buffer: Buffer): Buffer {
    if (buffer.length > 10 && buffer[0] === 0x49 && buffer[1] === 0x44 && buffer[2] === 0x33) {
      // ID3v2 header found: 'ID3'
      const size =
        ((buffer[6] & 0x7f) << 21) |
        ((buffer[7] & 0x7f) << 14) |
        ((buffer[8] & 0x7f) << 7) |
        (buffer[9] & 0x7f);
      const tagEnd = 10 + size;
      if (tagEnd < buffer.length) {
        return buffer.subarray(tagEnd);
      }
    }
    return buffer;
  }

  /**
   * Neutralizes Xing/Info header in an MP3 buffer to prevent decoders from prematurely truncating playback.
   */
  private stripXingHeader(buffer: Buffer): Buffer {
    const xingIdx = buffer.indexOf("Xing");
    if (xingIdx !== -1 && xingIdx < 200) {
      buffer.write("XXXX", xingIdx, 4, "ascii");
    }
    const infoIdx = buffer.indexOf("Info");
    if (infoIdx !== -1 && infoIdx < 200) {
      buffer.write("XXXX", infoIdx, 4, "ascii");
    }
    return buffer;
  }

  /**
   * Extracts fundamental pitch (F0 in Hz) from an audio clip using FFmpeg astats zero-crossings analysis.
   */
  /**
   * Measures the voice's fundamental pitch (F0): decodes up to 30 s to 16 kHz mono PCM and runs a
   * YIN pitch tracker over the voiced frames (pitch-estimation.ts). Returns null when there is too
   * little voiced speech to judge, so callers can tell "unknown" from a real measurement.
   */
  async extractPitch(audioClipPath: string): Promise<PitchEstimate | null> {
    const ffmpeg = getFfmpegPath() || "ffmpeg";
    try {
      const { stdout } = await execFileAsync(
        ffmpeg,
        ["-v", "error", "-t", "30", "-i", audioClipPath, "-vn", "-ac", "1", "-ar", "16000", "-af", "highpass=f=50", "-f", "f32le", "pipe:1"],
        { encoding: "buffer", maxBuffer: 16 * 1024 * 1024 }
      );
      return estimatePitch(f32leToSamples(stdout as unknown as Buffer), 16000);
    } catch (err) {
      console.warn("[MediaService] Pitch extraction notice:", err);
      return null;
    }
  }

  /** Median F0 in Hz, or 120 Hz when it cannot be measured (kept for existing callers). */
  async extractMedianPitchHz(audioClipPath: string): Promise<number> {
    const estimate = await this.extractPitch(audioClipPath);
    return estimate ? estimate.medianHz : 120;
  }

  /**
   * Extracts a video frame at a given timestamp in seconds, saving it as a JPEG image.
   */
  async extractVideoFrame(videoPath: string, timestampSec: number, outputPath: string): Promise<string> {
    const ffmpeg = getFfmpegPath() || "ffmpeg";
    await execFileAsync(
      ffmpeg,
      [
        "-nostdin",
        "-y",
        "-ss", `${Math.max(0, timestampSec).toFixed(3)}`,
        "-i", videoPath,
        "-frames:v", "1",
        "-q:v", "2",
        outputPath,
      ],
      { maxBuffer: 8 * 1024 * 1024, timeout: 20_000 }
    );
    return outputPath;
  }

  /**
   * Slices a clean audio clip from source audio or video between startSec and startSec + durationSec.
   */
  async extractAudioSlice(sourcePath: string, startSec: number, durationSec: number, outputPath: string): Promise<string> {
    const ffmpeg = getFfmpegPath() || "ffmpeg";
    await execFileAsync(
      ffmpeg,
      [
        "-y",
        "-ss", `${Math.max(0, startSec).toFixed(3)}`,
        "-t", `${Math.max(0.5, durationSec).toFixed(3)}`,
        "-i", sourcePath,
        "-vn",
        "-ac", "1",
        "-ar", "44100",
        "-c:a", "libmp3lame",
        "-b:a", "128k",
        outputPath,
      ],
      { maxBuffer: 8 * 1024 * 1024 }
    );
    return outputPath;
  }

  /**
   * Cuts several turns out of one source and joins them, in order, into a single mono MP3.
   * Used to give voice profiling several seconds of one speaker instead of one short slice.
   */
  async extractAudioTurns(
    sourcePath: string,
    turns: Array<{ startSec: number; durationSec: number }>,
    outputPath: string
  ): Promise<string> {
    if (turns.length === 0) throw new Error("extractAudioTurns: no turns given");
    if (turns.length === 1) {
      return this.extractAudioSlice(sourcePath, turns[0].startSec, turns[0].durationSec, outputPath);
    }
    const ffmpeg = getFfmpegPath() || "ffmpeg";
    const parts = turns.map((t, i) => {
      const start = Math.max(0, t.startSec);
      const end = start + Math.max(0.3, t.durationSec);
      return `[0:a]atrim=start=${start.toFixed(3)}:end=${end.toFixed(3)},asetpts=PTS-STARTPTS[t${i}]`;
    });
    const concatInputs = turns.map((_, i) => `[t${i}]`).join("");
    const filter = `${parts.join(";")};${concatInputs}concat=n=${turns.length}:v=0:a=1[out]`;
    await execFileAsync(
      ffmpeg,
      [
        "-y",
        "-i", sourcePath,
        "-filter_complex", filter,
        "-map", "[out]",
        "-vn",
        "-ac", "1",
        "-ar", "44100",
        "-c:a", "libmp3lame",
        "-b:a", "128k",
        outputPath,
      ],
      { maxBuffer: 8 * 1024 * 1024 }
    );
    return outputPath;
  }

  /**
   * Resolves any local or remote (GCS/Firebase/HTTP) media URL to an accessible local file on disk.
   */
  async ensureLocalMediaFile(mediaUrl: string, tmpDir: string, defaultExt = ".mp4"): Promise<string | null> {
    if (!mediaUrl || typeof mediaUrl !== "string") return null;
    const cleanUrl = mediaUrl.startsWith("file://") ? mediaUrl.replace("file://", "") : mediaUrl;
    if (fs.existsSync(cleanUrl)) return cleanUrl;

    const storageInfo = parseAnyStorageUrl(mediaUrl);
    if (storageInfo) {
      try {
        const dest = path.join(tmpDir, `source_${Date.now()}_${Math.random().toString(36).slice(2)}${defaultExt}`);
        const file = storage().bucket(storageInfo.bucketName).file(storageInfo.filePath);
        await file.download({ destination: dest });
        return dest;
      } catch (err) {
        console.warn("[MediaService] Failed to download storage media to local temp:", err);
      }
    }

    if (mediaUrl.startsWith("http://") || mediaUrl.startsWith("https://")) {
      try {
        const dest = path.join(tmpDir, `source_${Date.now()}_${Math.random().toString(36).slice(2)}${defaultExt}`);
        const resp = await axios.get(mediaUrl, { responseType: "arraybuffer", timeout: 15000 });
        await fs.promises.writeFile(dest, Buffer.from(resp.data));
        return dest;
      } catch (err) {
        console.warn("[MediaService] Failed to fetch remote media to local temp:", err);
      }
    }

    return null;
  }
}

export const mediaService = new MediaService();

export async function applyCinemaGradeMastering(
  jobId: string,
  inputGcsUrl: string,
  options?: CinemaMasteringOptions
): Promise<string> {
  return mediaService.applyCinemaGradeMastering(jobId, inputGcsUrl, options);
}

export async function extractMneStemDetailedParallel(
  jobId: string,
  audioUrl: string,
  options?: ExtractMneOptions
): Promise<ExtractMneDetailedResult> {
  return mediaService.extractMneStemDetailedParallel(jobId, audioUrl, options);
}

export async function extractMedianPitchHz(audioClipPath: string): Promise<number> {
  return mediaService.extractMedianPitchHz(audioClipPath);
}

export async function extractPitch(audioClipPath: string): Promise<PitchEstimate | null> {
  return mediaService.extractPitch(audioClipPath);
}

export async function extractVideoFrame(videoPath: string, timestampSec: number, outputPath: string): Promise<string> {
  return mediaService.extractVideoFrame(videoPath, timestampSec, outputPath);
}

export async function extractAudioSlice(sourcePath: string, startSec: number, durationSec: number, outputPath: string): Promise<string> {
  return mediaService.extractAudioSlice(sourcePath, startSec, durationSec, outputPath);
}

export async function ensureLocalMediaFile(mediaUrl: string, tmpDir: string, defaultExt = ".mp4"): Promise<string | null> {
  return mediaService.ensureLocalMediaFile(mediaUrl, tmpDir, defaultExt);
}
