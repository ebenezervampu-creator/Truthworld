/**
 * 🎙️ AUDIO IDENTITY SERVICE — Studio-Grade Acoustic Fingerprinting
 * 
 * This service preserves the creator's "Session Identity" by capturing 
 * mic texture, room aesthetics, and production energy.
 */

import * as admin from "firebase-admin";
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import { execFile } from "child_process";
import { promisify } from "util";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText, normalizeToGcsUri } from "../utils/ai-utils";
import { downloadStorageBuffer, getFfmpegPath } from "./media";
import { measureLineAcoustics } from "./emotion-transfer";
import { ElevenLabsEmotionTag, EmotionalIntensityProfile, SegmentProsodyCue } from "../types";
import {
  decideDeliveryTag,
  smoothDeliveryTagsPerSpeaker,
  summarizeDeliveryTags,
  isDubbingWhisperGuardEnabled,
  QUIET_SPEAKER_OFFSET_DB,
  SHOUT_SPEAKER_OFFSET_DB,
  MAX_WHISPER_VOICED_SHARE,
  PROSODY_RULE_VERSION,
  isVerifiedWhisper,
  type DeliveryTagDecision,
} from "./delivery-tag-guard";

export {
  decideDeliveryTag,
  smoothDeliveryTagsPerSpeaker,
  summarizeDeliveryTags,
  isDubbingWhisperGuardEnabled,
  QUIET_SPEAKER_OFFSET_DB,
  SHOUT_SPEAKER_OFFSET_DB,
  MAX_WHISPER_VOICED_SHARE,
  PROSODY_RULE_VERSION,
  type DeliveryTagDecision,
};

const execFileAsync = promisify(execFile);

export type VoiceQualityType = "breathy" | "modal" | "creaky" | "pressed";

const VOICE_QUALITY_STABILITY: Record<VoiceQualityType, number> = {
  breathy: 0.60,
  modal: 0.45,
  creaky: 0.30,
  pressed: 0.35,
};

const VOICE_QUALITY_SIMILARITY: Record<VoiceQualityType, number> = {
  breathy: 0.90,
  modal: 0.85,
  creaky: 0.82,
  pressed: 0.84,
};

const EMOTION_TAG_SETTINGS: Record<ElevenLabsEmotionTag, { stability: number; similarityBoost: number }> = {
  whispers:      { stability: 0.34, similarityBoost: 0.88 },
  soft:          { stability: 0.55, similarityBoost: 0.86 },
  shouts:        { stability: 0.28, similarityBoost: 0.84 },
  laughs:        { stability: 0.32, similarityBoost: 0.85 },
  sighs:         { stability: 0.38, similarityBoost: 0.87 },
  gasps:         { stability: 0.30, similarityBoost: 0.86 },
  excited:       { stability: 0.34, similarityBoost: 0.85 },
  sorrowful:     { stability: 0.36, similarityBoost: 0.88 },
  sad:           { stability: 0.38, similarityBoost: 0.88 },
  angry:         { stability: 0.30, similarityBoost: 0.84 },
  "said angrily":{ stability: 0.26, similarityBoost: 0.82 },
  sarcastic:     { stability: 0.40, similarityBoost: 0.85 },
  calm:          { stability: 0.62, similarityBoost: 0.86 },
  serious:       { stability: 0.56, similarityBoost: 0.87 },
  shouting:      { stability: 0.28, similarityBoost: 0.84 },
  screaming:     { stability: 0.30, similarityBoost: 0.84 },
  crying:        { stability: 0.30, similarityBoost: 0.86 },
  distressed:    { stability: 0.32, similarityBoost: 0.86 },
  menacing:      { stability: 0.32, similarityBoost: 0.85 },
  intense:       { stability: 0.32, similarityBoost: 0.85 },
};

export function mapEmotionToElevenLabsCue(
  emotion?: string,
  energyDb?: number,
  voiceQuality?: VoiceQualityType,
  emotionalIntensity?: EmotionalIntensityProfile,
  options?: {
    speakerMedianDb?: number;
    f0Hz?: number | null;
    voicedShare?: number | null;
    whisperGuard?: boolean;
  }
): { emotionTag?: ElevenLabsEmotionTag; stabilityOverride: number; similarityBoostOverride: number } {
  const guard = options?.whisperGuard ?? isDubbingWhisperGuardEnabled();
  const norm = (emotion || "").toLowerCase().trim();
  const aliasMap: Record<string, ElevenLabsEmotionTag> = {
    whisper: "whispers",
    whispers: "whispers",
    soft: "soft",
    softly: "soft",
    quiet: "soft",
    intimate: guard ? "soft" : "whispers",
    shout: "shouts",
    shouts: "shouts",
    shouting: "shouting",
    yelling: "shouting",
    screaming: "screaming",
    screams: "screaming",
    menacing: "menacing",
    growling: "menacing",
    threatening: "menacing",
    distressed: "distressed",
    pleading: "distressed",
    panicked: "distressed",
    sobbing: "crying",
    laugh: "laughs",
    laughs: "laughs",
    laughing: "laughs",
    chuckle: "laughs",
    sigh: "sighs",
    sighs: "sighs",
    exhausted: "sighs",
    gasp: "gasps",
    gasps: "gasps",
    shocked: "gasps",
    excited: "excited",
    enthusiastic: "excited",
    energetic: "excited",
    happy: "excited",
    sad: "sad",
    sorrowful: "sorrowful",
    crying: "crying",
    grief: "sorrowful",
    angry: "angry",
    furious: "angry",
    frustrated: "angry",
    "said angrily": "said angrily",
    angrily: "said angrily",
    sarcastic: "sarcastic",
    sarcastically: "sarcastic",
    ironic: "sarcastic",
    calm: "calm",
    relaxed: "calm",
    serious: "serious",
    authoritative: "serious",
  };

  let tag = aliasMap[norm];

  // Auto-promote dominant 6-axis emotional peak when no explicit lexical/model tag is set
  let peakIntensity = 0;
  if (emotionalIntensity) {
    const axisToTag: Array<[keyof EmotionalIntensityProfile, ElevenLabsEmotionTag]> = [
      ["anger", "angry"],
      ["fear", "gasps"],
      ["surprise", "excited"],
      ["sadness", "sorrowful"],
      ["joy", "laughs"],
      ["disgust", "serious"],
    ];
    let bestTag: ElevenLabsEmotionTag | undefined;
    for (const [axis, mappedTag] of axisToTag) {
      const val = Number(emotionalIntensity[axis] ?? 0);
      if (Number.isFinite(val) && val > peakIntensity) {
        peakIntensity = val;
        bestTag = mappedTag;
      }
    }
    if (!tag && peakIntensity >= 0.72 && bestTag) {
      tag = bestTag;
    }
  }

  // Acoustic energy override when lexical/model emotion is neutral
  if (!tag && typeof energyDb === "number" && Number.isFinite(energyDb)) {
    if (!guard) {
      if (energyDb <= -32) tag = "whispers";
      else if (energyDb >= -11) tag = "shouts";
    } else {
      if (typeof options?.speakerMedianDb === "number" && Number.isFinite(options.speakerMedianDb)) {
        if (energyDb <= options.speakerMedianDb - QUIET_SPEAKER_OFFSET_DB) tag = "soft";
        else if (energyDb >= options.speakerMedianDb + SHOUT_SPEAKER_OFFSET_DB) tag = "shouts";
      } else {
        if (energyDb <= -36) tag = "soft";
        else if (energyDb >= -11) tag = "shouts";
      }
    }
  }

  // Whisper guard: verify unvoiced airflow if whispers was proposed
  if (guard && tag === "whispers") {
    // Same rule as decideDeliveryTag (delivery-tag-guard.ts): a whisper needs measured evidence.
    if (!isVerifiedWhisper({ f0Hz: options?.f0Hz, voicedShare: options?.voicedShare, voiceQuality })) {
      tag = "soft";
    }
  }

  const qualityStability = voiceQuality ? VOICE_QUALITY_STABILITY[voiceQuality] : undefined;
  const qualitySimilarity = voiceQuality ? VOICE_QUALITY_SIMILARITY[voiceQuality] : undefined;

  if (tag && EMOTION_TAG_SETTINGS[tag]) {
    const preset = EMOTION_TAG_SETTINGS[tag];
    // Blend emotion preset with vocal-fold voiceQuality dynamics when available
    let stability =
      qualityStability !== undefined
        ? preset.stability * 0.7 + qualityStability * 0.3
        : preset.stability;
    if (peakIntensity >= 0.7) {
      stability -= (peakIntensity - 0.65) * 0.08;
    }
    const similarity =
      qualitySimilarity !== undefined
        ? preset.similarityBoost * 0.65 + qualitySimilarity * 0.35
        : preset.similarityBoost;

    return {
      emotionTag: tag,
      stabilityOverride: Number(Math.max(0.25, Math.min(0.75, stability)).toFixed(2)),
      similarityBoostOverride: Number(Math.max(0.75, Math.min(0.95, similarity)).toFixed(2)),
    };
  }

  // Dynamic stability scaled gently by voiceQuality & RMS energy if available
  const energyStability =
    typeof energyDb === "number" && Number.isFinite(energyDb)
      ? Math.max(0.32, Math.min(0.60, 0.48 - (energyDb + 20) * 0.01))
      : 0.45;
  const blendedStability =
    qualityStability !== undefined
      ? qualityStability * 0.6 + energyStability * 0.4
      : energyStability;

  return {
    stabilityOverride: Number(Math.max(0.25, Math.min(0.75, blendedStability)).toFixed(2)),
    similarityBoostOverride: Number((qualitySimilarity ?? 0.85).toFixed(2)),
  };
}

export interface AcousticFingerprint {
  micStyle:    "warm-broadcast" | "crisp-modern" | "natural-flat" | "vlog-raw" | "laptop-bright";
  roomTone:    "dry-studio" | "small-room" | "stone-hall" | "large-reflective" | "outdoor-open";
  roomToneConfidence?: number;
  compression: "punchy" | "transparent" | "heavy" | "none";
  energy:      "high" | "moderate" | "relaxed" | "intimate";
  pacingStyle: "fast-energetic" | "steady-educational" | "slow-dramatic";
  pitchBand?:  "high" | "mid" | "deep";
  pitchSemitones?: number;
  speakingRate?: number;
}

export class AudioIdentityService {
  private get model() {
    return getVertexAI().getGenerativeModel({
      model: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || "gemini-3.5-flash-lite",
    });
  }

  /**
   * 2. 🧠 Capture Acoustic Fingerprint (Semantic Descriptors)
   * Uses Vertex AI Gemini 3.5 Flash Lite Multimodal Audio to analyze the creator's
   * microphone texture, room aesthetics, dynamics, pacing, and vocal resonance.
   */
  async captureFingerprint(jobId: string, vocalUrl: string): Promise<AcousticFingerprint> {
    logger.info("[AudioIdentity] Capturing authentic acoustic fingerprint via Vertex AI Gemini", { jobId, vocalUrl });

    const gcsUri = vocalUrl
      ? (normalizeToGcsUri(vocalUrl) || (vocalUrl.startsWith("gs://") ? vocalUrl : null))
      : null;

    try {
      const prompt = `You are a world-class audio mastering engineer and vocal acoustic analyst.
Analyze the speaker's vocal recording and its acoustic environment.
Assess:
1. Microphone style:
   - "warm-broadcast" (deep podcast proximity effect, rich lows)
   - "crisp-modern" (condenser mic, bright high-end, studio clarity)
   - "natural-flat" (neutral response, standard studio)
   - "vlog-raw" (lapel or shotgun mic in real-world space)
   - "laptop-bright" (built-in mic, thin, high mids)
2. Room tone / reverb environment:
   - "dry-studio" (treated vocal booth, zero reverb; standard for YouTube Shorts, talking-head videos, podcasts, vlogs)
   - "small-room" (slight natural bedroom/office reflections)
   - "stone-hall" (stone prison cell, dungeon, cathedral, ancient stone chamber, cave with distinct stone wall reflections)
   - "large-reflective" (large auditorium, untreated hall, noticeable long echo)
   - "outdoor-open" (wind, open space, no room reflections)
3. Compression style:
   - "punchy" (broadcast radio, tight dynamic range)
   - "transparent" (natural dynamics, gentle evening)
   - "heavy" (loud, aggressive, highly compressed)
   - "none" (raw dynamic peaks)
4. Energy: "high" | "moderate" | "relaxed" | "intimate"
5. Pacing style: "fast-energetic" | "steady-educational" | "slow-dramatic"
6. Pitch band: "deep" | "mid" | "high"
7. Pitch semitones: number from -3.0 to +3.0 (negative for deep resonance, positive for higher pitch)
8. Speaking rate: number from 0.88 to 1.15 (relative tempo multiplier)

Return ONLY a valid JSON object matching this schema:
{
  "micStyle": "warm-broadcast" | "crisp-modern" | "natural-flat" | "vlog-raw" | "laptop-bright",
  "roomTone": "dry-studio" | "small-room" | "stone-hall" | "large-reflective" | "outdoor-open",
  "roomToneConfidence": 0.85,
  "compression": "punchy" | "transparent" | "heavy" | "none",
  "energy": "high" | "moderate" | "relaxed" | "intimate",
  "pacingStyle": "fast-energetic" | "steady-educational" | "slow-dramatic",
  "pitchBand": "deep" | "mid" | "high",
  "pitchSemitones": 0.0,
  "speakingRate": 1.00
}`;

      let result;
      if (gcsUri) {
        const mimeType = gcsUri.endsWith(".wav")
          ? "audio/wav"
          : (gcsUri.endsWith(".mp3") ? "audio/mp3" : "video/mp4");

        result = await this.model.generateContent({
          contents: [
            {
              role: "user",
              parts: [
                {
                  fileData: {
                    mimeType,
                    fileUri: gcsUri,
                  },
                },
                { text: prompt },
              ],
            },
          ],
        });
      } else {
        result = await this.model.generateContent(prompt);
      }

      const text = extractCandidateText(result.response.candidates?.[0]) || result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const jsonMatch = text.match(/\{[\s\S]*\}/);

      if (!jsonMatch) {
        throw new Error("No JSON object found in Gemini acoustic fingerprint response");
      }

      const parsed = JSON.parse(jsonMatch[0]);

      const validMicStyles = ["warm-broadcast", "crisp-modern", "natural-flat", "vlog-raw", "laptop-bright"];
      const validRoomTones = ["dry-studio", "small-room", "large-reflective", "outdoor-open"];
      const validCompressions = ["punchy", "transparent", "heavy", "none"];
      const validEnergies = ["high", "moderate", "relaxed", "intimate"];
      const validPacing = ["fast-energetic", "steady-educational", "slow-dramatic"];

      const fingerprint: AcousticFingerprint = {
        micStyle: validMicStyles.includes(parsed.micStyle) ? parsed.micStyle : "warm-broadcast",
        roomTone: validRoomTones.includes(parsed.roomTone) ? parsed.roomTone : "small-room",
        compression: validCompressions.includes(parsed.compression) ? parsed.compression : "transparent",
        energy: validEnergies.includes(parsed.energy) ? parsed.energy : "moderate",
        pacingStyle: validPacing.includes(parsed.pacingStyle) ? parsed.pacingStyle : "steady-educational",
        pitchBand: (parsed.pitchBand === "deep" || parsed.pitchBand === "high" || parsed.pitchBand === "mid") ? parsed.pitchBand : "mid",
        pitchSemitones: typeof parsed.pitchSemitones === "number" ? Math.max(-3.0, Math.min(3.0, parsed.pitchSemitones)) : 0.0,
        speakingRate: typeof parsed.speakingRate === "number" ? Math.max(0.88, Math.min(1.15, parsed.speakingRate)) : 1.0,
      };

      logger.info("[AudioIdentity] ✅ Real acoustic fingerprint captured", { jobId, fingerprint });
      return fingerprint;
    } catch (error) {
      logger.warn("[AudioIdentity] Fingerprinting fallback to calibrated broadcast default", { jobId, err: String(error) });
      return {
        micStyle: "warm-broadcast",
        roomTone: "dry-studio",
        compression: "transparent",
        energy: "moderate",
        pacingStyle: "steady-educational",
        pitchBand: "mid",
        pitchSemitones: 0.0,
        speakingRate: 1.0,
      };
    }
  }

  /**
   * 3. 🎛️ Map Semantic Descriptors to Deterministic FFmpeg Filters
   * This is the "DSP Rules Engine" that transforms AI intent into audio engineering.
   */
  getDSPFilters(fingerprint: AcousticFingerprint): string {
    const filters: string[] = [];

    // A. Mic Style (Parametric EQ profiles)
    switch(fingerprint.micStyle) {
      case "warm-broadcast": 
        filters.push("equalizer=f=120:width_type=h:w=100:g=3,equalizer=f=3000:width_type=h:w=200:g=-1"); 
        break;
      case "crisp-modern": 
        filters.push("equalizer=f=5000:width_type=h:w=500:g=2,equalizer=f=100:width_type=h:w=100:g=-2"); 
        break;
      case "laptop-bright": 
        filters.push("equalizer=f=200:width_type=h:w=150:g=4,lowpass=f=12000"); 
        break;
      case "vlog-raw":
        filters.push("highpass=f=80,equalizer=f=2500:width_type=h:w=300:g=1.5");
        break;
      case "natural-flat":
        filters.push("highpass=f=60");
        break;
    }

    // B. Compression (Dynamics)
    switch(fingerprint.compression) {
      case "punchy": 
        filters.push("compand=attacks=0.03:points=-80/-80|-40/-30|-20/-10|0/0:soft-knee=0.01"); 
        break;
      case "heavy": 
        filters.push("compand=attacks=0.01:points=-80/-80|-50/-20|0/-10"); 
        break;
      case "transparent":
        filters.push("compand=attacks=0.05:points=-70/-70|-35/-28|-15/-8|0/0:soft-knee=0.02");
        break;
    }

    // C. Room Tone (Reverb emulation) - STRICTLY CONDITIONAL
    // Never apply stone dungeon reverb to YouTube Shorts, vlogs, or standard studio talking heads.
    const conf = typeof fingerprint.roomToneConfidence === "number" ? fingerprint.roomToneConfidence : 0.8;

    switch(fingerprint.roomTone) {
      case "stone-hall":
        if (conf >= 0.70) {
          // Authentic 3-tap stone chamber early reflection + stone high-frequency damping
          filters.push("equalizer=f=200:width_type=h:w=140:g=1.8,lowpass=f=9400,aecho=0.85:0.42:35|65|95:0.22|0.14|0.08");
        } else {
          filters.push("aecho=0.88:0.25:40:0.12");
        }
        break;
      case "large-reflective": 
        filters.push("aecho=0.85:0.35:75:0.20"); 
        break;
      case "small-room": 
        filters.push("aecho=0.88:0.25:35:0.12"); 
        break;
      case "dry-studio":
      case "outdoor-open":
      default:
        // Zero reverb default (clean, dry studio speech)
        break;
    }

    // Always target -14 LUFS (EBU R128 / ITU-R BS.1770 Global Broadcast Standard)
    filters.push("loudnorm=I=-14:TP=-1:LRA=11");

    return filters.join(",");
  }

  public async getAccessibleUrl(url: string): Promise<string> {
    if (!url) return url;
    if (url.includes("X-Goog-Signature") || url.includes("GoogleAccessId")) return url;

    let bucketName = admin.storage().bucket().name;
    let filePath = url;
    let isStorage = false;

    if (url.startsWith("gs://")) {
      const parts = url.replace("gs://", "").split("/");
      bucketName = parts[0];
      filePath = parts.slice(1).join("/");
      isStorage = true;
    } else if (url.startsWith("http://") || url.startsWith("https://")) {
      try {
        const parsed = new URL(url);
        if (parsed.hostname.includes("firebasestorage.googleapis.com")) {
          const match = parsed.pathname.match(/\/v0\/b\/([^/]+)\/o\/(.+)/);
          if (match) {
            bucketName = decodeURIComponent(match[1]);
            filePath = decodeURIComponent(match[2].split("?")[0]);
            isStorage = true;
          }
        } else if (parsed.hostname === "storage.googleapis.com") {
          const segments = parsed.pathname.replace(/^\/+/, "").split("/");
          if (segments.length >= 2) {
            bucketName = decodeURIComponent(segments[0]);
            filePath = decodeURIComponent(segments.slice(1).join("/").split("?")[0]);
            isStorage = true;
          }
        } else if (parsed.hostname.endsWith(".storage.googleapis.com")) {
          bucketName = decodeURIComponent(parsed.hostname.replace(".storage.googleapis.com", ""));
          filePath = decodeURIComponent(parsed.pathname.replace(/^\/+/, "").split("?")[0]);
          isStorage = true;
        }
      } catch (_) {}
    }

    if (!isStorage && (url.startsWith("http://") || url.startsWith("https://"))) {
      return url;
    }

    try {
      const bucket = admin.storage().bucket(bucketName);
      const file = bucket.file(filePath.replace(/^\/+/, ""));
      try {
        const [signedUrl] = await file.getSignedUrl({
          action: "read",
          expires: Date.now() + 3600 * 1000,
        });
        return signedUrl;
      } catch (signErr) {
        // Fallback for runtimes without iam.serviceAccounts.signBlob permission:
        // reuse or mint a Firebase Storage download token so browsers can download directly.
        const [meta] = await file.getMetadata();
        let rawTokens = String(meta?.metadata?.firebaseStorageDownloadTokens || "").trim();
        let token = rawTokens.split(",")[0]?.trim() || "";
        if (!token) {
          const { randomUUID } = require("crypto");
          token = randomUUID();
          await file.setMetadata({
            metadata: {
              ...(meta?.metadata || {}),
              firebaseStorageDownloadTokens: token,
            },
          });
        }
        return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(filePath.replace(/^\/+/, ""))}?alt=media&token=${encodeURIComponent(token)}`;
      }
    } catch (_) {
      return url;
    }
  }

  /**
   * 3. Deep Per-Segment Emotion & Multimodal Prosody Extraction
   *    (FFmpeg RMS + Base64 16kHz WAV Clip Gemini Multimodal Audio + Fallback Whole-Track)
   *
   * Extracts pitch range (semitones), speaking rate (syl/s), voice quality (breathy/modal/creaky/pressed),
   * 6-axis emotional intensity, energy envelope, breathing & stress markers, mapped to ElevenLabs v4 tags
   * and continuous stability/similarity_boost curves.
   */
  async analyzeSegmentProsody(
    jobId: string,
    audioUrl: string,
    segments: Array<{ index: number; start: number; end: number; text: string }>
  ): Promise<Map<number, SegmentProsodyCue>> {
    const cues = new Map<number, SegmentProsodyCue>();
    if (!segments.length) return cues;

    const validVoiceQualities = new Set<VoiceQualityType>(["breathy", "modal", "creaky", "pressed"]);
    const validEnvelopes = new Set(["rising", "falling", "flat", "dynamic"]);
    const validBreathing = new Set(["natural", "rapid", "suppressed"]);

    interface GeminiDeepProsody {
      emotion?: string;
      style?: string;
      pitchRangeSemitones?: number;
      speakingRateSyllablesPerSec?: number;
      voiceQuality?: VoiceQualityType;
      emotionalIntensity?: EmotionalIntensityProfile;
      energyEnvelopePattern?: "rising" | "falling" | "flat" | "dynamic";
      breathingPattern?: "natural" | "rapid" | "suppressed";
      accentStressMarkers?: string[];
      recommendedStability?: number;
      recommendedSimilarityBoost?: number;
    }

    const geminiProsodyMap = new Map<number, GeminiDeepProsody>();
    const energyMap = new Map<number, number>();
    // Pitch and voiced loudness for EVERY line (Gemini only hears the first 40); see emotion-transfer.ts.
    const acousticMap = new Map<number, { f0Hz: number | null; voicedRmsDb: number | null; voicedShare?: number | null }>();
    const workDir = path.join(os.tmpdir(), `prosody_deep_${jobId}_${Date.now()}`);
    let localAudioPath: string | null = null;
    const ffmpegPath = getFfmpegPath();

    try {
      // 1. Download source audio once for both RMS volumedetect & per-segment WAV slice extraction
      if (audioUrl && ffmpegPath) {
        try {
          const buf = await downloadStorageBuffer(audioUrl);
          if (buf && buf.length >= 256) {
            fs.mkdirSync(workDir, { recursive: true });
            localAudioPath = path.join(workDir, "source_audio.bin");
            fs.writeFileSync(localAudioPath, buf);

            for (const seg of segments.slice(0, 60)) {
              const startSec = Math.max(0, seg.start / 1000);
              const durSec = Math.max(0.2, Math.min(20, (seg.end - seg.start) / 1000));
              try {
                const { stderr } = await execFileAsync(
                  ffmpegPath,
                  [
                    "-ss", startSec.toFixed(3),
                    "-t", durSec.toFixed(3),
                    "-i", localAudioPath,
                    "-af", "volumedetect",
                    "-f", "null",
                    process.platform === "win32" ? "NUL" : "/dev/null",
                  ],
                  { timeout: 10000 }
                );
                const meanMatch = stderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
                if (meanMatch) {
                  const db = parseFloat(meanMatch[1]);
                  if (Number.isFinite(db)) energyMap.set(seg.index, Number(db.toFixed(1)));
                }
              } catch {
                // Non-fatal per-segment probe
              }
            }
          }
        } catch {
          // Offline / signed URL unavailable — fall back gracefully to GCS URI or lexical cues
        }
      }

      // 2a. Deep Per-Segment Gemini 3.5 Flash Lite Multimodal Audio Analysis (inlineData WAV slices, bounded concurrency)
      if (localAudioPath && ffmpegPath) {
        try {
          const { stdout } = await execFileAsync(
            ffmpegPath,
            ["-v", "error", "-i", localAudioPath, "-ac", "1", "-ar", "8000", "-f", "f32le", "pipe:1"],
            { encoding: "buffer", maxBuffer: 400 * 1024 * 1024, timeout: 120000 } as any
          );
          const buf = Buffer.from(stdout as unknown as Buffer);
          const pcm = new Float32Array(buf.buffer, buf.byteOffset, Math.floor(buf.length / 4));
          for (const seg of segments) {
            acousticMap.set(seg.index, measureLineAcoustics(pcm, 8000, seg.start, seg.end));
          }
        } catch (acousticErr) {
          logger.warn("[AudioIdentity] Line pitch/loudness measurement skipped", { jobId, error: (acousticErr as Error).message });
        }
      }

      if (localAudioPath && ffmpegPath) {
        const activeSegments = segments
          .slice(0, 40)
          .filter((seg) => {
            const durMs = seg.end - seg.start;
            const eDb = energyMap.get(seg.index);
            return durMs >= 250 && (eDb === undefined || eDb > -50);
          });

        const CONCURRENCY = 5;
        for (let i = 0; i < activeSegments.length; i += CONCURRENCY) {
          const batch = activeSegments.slice(i, i + CONCURRENCY);
          await Promise.allSettled(
            batch.map(async (seg) => {
              const startSec = Math.max(0, seg.start / 1000);
              const durSec = Math.max(0.3, Math.min(6.0, (seg.end - seg.start) / 1000));
              const clipPath = path.join(workDir, `seg_${seg.index}.wav`);
              try {
                await execFileAsync(
                  ffmpegPath,
                  [
                    "-y",
                    "-ss", startSec.toFixed(3),
                    "-t", durSec.toFixed(3),
                    "-i", localAudioPath!,
                    "-ar", "16000",
                    "-ac", "1",
                    "-f", "wav",
                    clipPath,
                  ],
                  { timeout: 10000 }
                );
                const wavBuf = await fs.promises.readFile(clipPath);
                if (!wavBuf || wavBuf.length < 256) return;

                const prompt = `Analyze this speaker audio clip for cinema-grade voice acting transfer.
Transcript text: ${JSON.stringify(seg.text)}
Measured RMS energy: ${energyMap.get(seg.index) ?? "unknown"} dBFS

Delivery rules: Use "soft" for quiet, grounded, fully voiced speech (has audible vocal pitch; NOT an unvoiced whisper). Reserve "whispers" strictly for unvoiced, breathy vocal airflow with no vocal fold vibration.

Return ONLY valid JSON:
{
  "pitchRangeSemitones": number (0 to 24),
  "speakingRateSyllablesPerSec": number (1.5 to 9.0),
  "voiceQuality": "breathy" | "modal" | "creaky" | "pressed",
  "emotionalIntensity": { "anger": 0-1, "sadness": 0-1, "joy": 0-1, "fear": 0-1, "disgust": 0-1, "surprise": 0-1 },
  "energyEnvelopePattern": "rising" | "falling" | "flat" | "dynamic",
  "breathingPattern": "natural" | "rapid" | "suppressed",
  "accentStressMarkers": string[],
  "recommendedElevenLabsTag": "whispers" | "soft" | "shouting" | "screaming" | "crying" | "distressed" | "menacing" | "laughs" | "sighs" | "gasps" | "excited" | "sorrowful" | "angry" | "calm" | "serious" | "neutral",
  "recommendedStability": number (0.25 to 0.75),
  "recommendedSimilarityBoost": number (0.75 to 0.95),
  "style": string
}`;

                const result = await this.model.generateContent({
                  contents: [
                    {
                      role: "user",
                      parts: [
                        { inlineData: { mimeType: "audio/wav", data: wavBuf.toString("base64") } },
                        { text: prompt },
                      ],
                    },
                  ],
                  generationConfig: { responseMimeType: "application/json", temperature: 0.1 },
                } as any);

                const rawText = extractCandidateText(result.response.candidates?.[0]) || "{}";
                const parsed = JSON.parse(rawText);
                const intensity = parsed?.emotionalIntensity && typeof parsed.emotionalIntensity === "object"
                  ? {
                      anger: Math.max(0, Math.min(1, Number(parsed.emotionalIntensity.anger || 0))),
                      sadness: Math.max(0, Math.min(1, Number(parsed.emotionalIntensity.sadness || 0))),
                      joy: Math.max(0, Math.min(1, Number(parsed.emotionalIntensity.joy || 0))),
                      fear: Math.max(0, Math.min(1, Number(parsed.emotionalIntensity.fear || 0))),
                      disgust: Math.max(0, Math.min(1, Number(parsed.emotionalIntensity.disgust || 0))),
                      surprise: Math.max(0, Math.min(1, Number(parsed.emotionalIntensity.surprise || 0))),
                    }
                  : undefined;

                geminiProsodyMap.set(seg.index, {
                  emotion: typeof parsed?.recommendedElevenLabsTag === "string" ? parsed.recommendedElevenLabsTag : undefined,
                  style: typeof parsed?.style === "string" ? parsed.style : undefined,
                  pitchRangeSemitones: typeof parsed?.pitchRangeSemitones === "number"
                    ? Number(Math.max(0, Math.min(24, parsed.pitchRangeSemitones)).toFixed(1))
                    : undefined,
                  speakingRateSyllablesPerSec: typeof parsed?.speakingRateSyllablesPerSec === "number"
                    ? Number(Math.max(1.0, Math.min(10.0, parsed.speakingRateSyllablesPerSec)).toFixed(2))
                    : undefined,
                  voiceQuality: validVoiceQualities.has(parsed?.voiceQuality) ? parsed.voiceQuality : undefined,
                  emotionalIntensity: intensity,
                  energyEnvelopePattern: validEnvelopes.has(parsed?.energyEnvelopePattern)
                    ? parsed.energyEnvelopePattern
                    : undefined,
                  breathingPattern: validBreathing.has(parsed?.breathingPattern)
                    ? parsed.breathingPattern
                    : undefined,
                  accentStressMarkers: Array.isArray(parsed?.accentStressMarkers)
                    ? parsed.accentStressMarkers.filter((m: any) => typeof m === "string").slice(0, 8)
                    : undefined,
                  recommendedStability: typeof parsed?.recommendedStability === "number"
                    ? Number(Math.max(0.25, Math.min(0.75, parsed.recommendedStability)).toFixed(2))
                    : undefined,
                  recommendedSimilarityBoost: typeof parsed?.recommendedSimilarityBoost === "number"
                    ? Number(Math.max(0.75, Math.min(0.95, parsed.recommendedSimilarityBoost)).toFixed(2))
                    : undefined,
                });
              } catch {
                // Non-fatal per-segment multimodal failure — falls back below
              } finally {
                await fs.promises.unlink(clipPath).catch(() => {});
              }
            })
          );
        }
      }

      // 2b. Fallback: Single whole-track GCS multimodal batch call if inline WAV slices yielded zero cues
      const gcsUri = audioUrl
        ? (normalizeToGcsUri(audioUrl) || (audioUrl.startsWith("gs://") ? audioUrl : null))
        : null;

      if (geminiProsodyMap.size === 0 && gcsUri) {
        try {
          const sampleSegments = segments.slice(0, 40).map((s) => ({
            index: s.index,
            startSec: Number((s.start / 1000).toFixed(2)),
            endSec: Number((s.end / 1000).toFixed(2)),
            text: s.text,
            measuredEnergyDb: energyMap.get(s.index),
          }));

          const prompt = `Listen to the vocal audio track and classify the emotional delivery and vocal prosody for each speech segment below.
Allowed emotions: "whispers", "soft", "shouting", "screaming", "crying", "distressed", "menacing", "laughs", "sighs", "gasps", "excited", "sorrowful", "angry", "calm", "serious", "neutral".
Segments:
${JSON.stringify(sampleSegments)}
Return JSON: { "cues": [{ "index": 0, "emotion": "neutral", "voiceQuality": "modal", "pitchRangeSemitones": 6, "style": "conversational" }] }`;

          const mimeType = gcsUri.endsWith(".wav")
            ? "audio/wav"
            : (gcsUri.endsWith(".mp3") ? "audio/mp3" : "video/mp4");

          const result = await this.model.generateContent({
            contents: [
              {
                role: "user",
                parts: [
                  { fileData: { mimeType, fileUri: gcsUri } },
                  { text: prompt },
                ],
              },
            ],
            generationConfig: { responseMimeType: "application/json", temperature: 0.1 },
          } as any);

          const rawText = extractCandidateText(result.response.candidates?.[0]) || "{}";
          const parsed = JSON.parse(rawText);
          if (Array.isArray(parsed?.cues)) {
            for (const item of parsed.cues) {
              if (typeof item?.index === "number" && typeof item?.emotion === "string") {
                geminiProsodyMap.set(item.index, {
                  emotion: item.emotion,
                  style: typeof item.style === "string" ? item.style : undefined,
                  voiceQuality: validVoiceQualities.has(item.voiceQuality) ? item.voiceQuality : undefined,
                  pitchRangeSemitones: typeof item.pitchRangeSemitones === "number"
                    ? Number(Math.max(0, Math.min(24, item.pitchRangeSemitones)).toFixed(1))
                    : undefined,
                });
              }
            }
          }
        } catch (err) {
          logger.warn("[AudioIdentity] Gemini multimodal prosody note (using acoustic RMS + textual cues):", {
            jobId,
            error: (err as Error).message,
          });
        }
      }
    } finally {
      try {
        if (fs.existsSync(workDir)) {
          fs.rmSync(workDir, { recursive: true, force: true });
        }
      } catch {}
    }

    // 3. Compute per-speaker median energy across this video
    const energyBySpeaker = new Map<string, number[]>();
    for (const seg of segments) {
      const e = energyMap.get(seg.index);
      if (typeof e === "number" && Number.isFinite(e)) {
        const spk = (seg as any).speaker || "speaker_0";
        if (!energyBySpeaker.has(spk)) energyBySpeaker.set(spk, []);
        energyBySpeaker.get(spk)!.push(e);
      }
    }
    const speakerMedianMap = new Map<string, number>();
    for (const [spk, energies] of energyBySpeaker) {
      const sorted = [...energies].sort((a, b) => a - b);
      const mid = Math.floor(sorted.length / 2);
      speakerMedianMap.set(spk, sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2);
    }

    interface SegmentDraftItem {
      seg: { index: number; start: number; end: number; text: string; speaker?: string };
      decision: DeliveryTagDecision;
      energyDb?: number;
      speakerMedianDb?: number;
      f0Hz: number | null;
      voicedShare: number | null;
      geminiTag?: string;
      voiceQuality?: VoiceQualityType;
      stabilityOverride: number;
      similarityBoostOverride: number;
      geminiCue?: GeminiDeepProsody;
    }

    const drafts: SegmentDraftItem[] = [];

    for (const seg of segments) {
      const energyDb = energyMap.get(seg.index);
      const spk = (seg as any).speaker || "speaker_0";
      const speakerMedianDb = speakerMedianMap.get(spk);
      const acoustic = acousticMap.get(seg.index);
      const f0Hz = acoustic?.f0Hz ?? null;
      const voicedShare = acoustic?.voicedShare ?? null;
      const geminiCue = geminiProsodyMap.get(seg.index);
      const lexicalEmotion = this.inferLexicalEmotionHint(seg.text);
      const rawEmotion =
        geminiCue?.emotion && geminiCue.emotion.toLowerCase() !== "neutral"
          ? geminiCue.emotion
          : lexicalEmotion;

      const decision = decideDeliveryTag({
        index: seg.index,
        speaker: (seg as any).speaker,
        startMs: seg.start,
        endMs: seg.end,
        f0Hz,
        voicedShare,
        energyDb,
        speakerMedianDb,
        voiceQuality: geminiCue?.voiceQuality,
        geminiTag: geminiCue?.emotion,
        proposedTag: rawEmotion,
        emotionalIntensity: geminiCue?.emotionalIntensity,
      });

      const mapped = mapEmotionToElevenLabsCue(
        decision.finalTag,
        energyDb,
        geminiCue?.voiceQuality,
        geminiCue?.emotionalIntensity,
        {
          speakerMedianDb,
          f0Hz,
          voicedShare,
        }
      );

      const finalStability =
        typeof geminiCue?.recommendedStability === "number" && Number.isFinite(geminiCue.recommendedStability)
          ? geminiCue.recommendedStability
          : mapped.stabilityOverride;
      const finalSimilarity =
        typeof geminiCue?.recommendedSimilarityBoost === "number" && Number.isFinite(geminiCue.recommendedSimilarityBoost)
          ? geminiCue.recommendedSimilarityBoost
          : mapped.similarityBoostOverride;

      drafts.push({
        seg,
        decision,
        energyDb,
        speakerMedianDb,
        f0Hz,
        voicedShare,
        geminiTag: geminiCue?.emotion,
        voiceQuality: geminiCue?.voiceQuality,
        stabilityOverride: finalStability,
        similarityBoostOverride: finalSimilarity,
        geminiCue,
      });
    }

    // 4. Keep delivery steady within a scene: smooth adjacent lines for same speaker
    const smoothInputs = drafts.map((d) => ({
      index: d.seg.index,
      speaker: (d.seg as any).speaker,
      startMs: d.seg.start,
      endMs: d.seg.end,
      energyDb: d.energyDb,
      finalTag: d.decision.finalTag,
      peakIntensity: d.geminiCue?.emotionalIntensity
        ? Math.max(...Object.values(d.geminiCue.emotionalIntensity).map((v) => Number(v) || 0))
        : 0,
      reason: d.decision.reason,
    }));

    const { smoothedSegments, smoothedCount } = smoothDeliveryTagsPerSpeaker(smoothInputs);

    // 5. Build cues, log segment traceability & summary
    for (let i = 0; i < drafts.length; i++) {
      const d = drafts[i];
      const smoothed = smoothedSegments[i];
      const finalTag = smoothed.finalTag;

      logger.info("[Dubbing:DeliveryTag]", {
        index: d.seg.index,
        speaker: (d.seg as any).speaker,
        energyDb: d.energyDb,
        speakerMedianDb: d.speakerMedianDb,
        f0Hz: d.f0Hz,
        voicedShare: d.voicedShare,
        geminiTag: d.geminiTag,
        voiceQuality: d.voiceQuality,
        proposedTag: d.decision.proposedTag,
        finalTag,
        reason: smoothed.reason || d.decision.reason,
      });

      const durSec = Math.max(0.25, (d.seg.end - d.seg.start) / 1000);
      const words = d.seg.text.trim().split(/\s+/).filter(Boolean).length;
      const wordsPerSec = words / durSec;
      const speakingRateRatio = Number(Math.max(0.75, Math.min(1.35, wordsPerSec / 2.6)).toFixed(2));

      cues.set(d.seg.index, {
        segmentIndex: d.seg.index,
        emotionTag: finalTag,
        energyDb: d.energyDb,
        speakingRateRatio,
        stabilityOverride: d.stabilityOverride,
        similarityBoostOverride: d.similarityBoostOverride,
        deliveryStyle: d.geminiCue?.style || (finalTag ? `expressive:${finalTag}` : "natural"),
        pitchRangeSemitones: d.geminiCue?.pitchRangeSemitones,
        speakingRateSyllablesPerSec: d.geminiCue?.speakingRateSyllablesPerSec,
        voiceQuality: d.geminiCue?.voiceQuality,
        emotionalIntensity: d.geminiCue?.emotionalIntensity,
        energyEnvelopePattern: d.geminiCue?.energyEnvelopePattern,
        breathingPattern: d.geminiCue?.breathingPattern,
        accentStressMarkers: d.geminiCue?.accentStressMarkers,
        f0Hz: d.f0Hz,
        voicedRmsDb: acousticMap.get(d.seg.index)?.voicedRmsDb ?? null,
        voicedShare: d.voicedShare,
      });
    }

    const summary = summarizeDeliveryTags(
      drafts.map((d) => d.decision),
      smoothedCount
    );
    logger.info("[Dubbing:DeliveryTag] Summary", summary);

    logger.info("[AudioIdentity] Deep segment prosody analysis complete", {
      jobId,
      totalSegments: segments.length,
      taggedCount: Array.from(cues.values()).filter((c) => Boolean(c.emotionTag)).length,
      multimodalCuesCount: geminiProsodyMap.size,
      measuredEnergyCount: energyMap.size,
    });

    return cues;
  }

  private inferLexicalEmotionHint(text: string): string | undefined {
    const lower = text.toLowerCase();
    if (/\[(laugh|chuckle|haha|giggle)/.test(lower) || /\b(haha+|lmao)\b/.test(lower)) return "laughs";
    if (isDubbingWhisperGuardEnabled()) {
      if (/\[(soft|softly|quietly)\]/.test(lower)) return "soft";
      if (/\[(whisper|whispers)\]/.test(lower)) return "whispers";
    } else {
      if (/\[(whisper|whispers|softly)\]/.test(lower)) return "whispers";
    }
    if (/\[(sigh|sighs)\]/.test(lower)) return "sighs";
    if (/\[(gasp|gasps)\]/.test(lower)) return "gasps";
    if (/\[(shout|shouts|scream|yell)/.test(lower) || (text.includes("!!") && text === text.toUpperCase() && text.length > 6)) {
      return "shouts";
    }
    if (/\[(angry|furious)\]/.test(lower)) return "angry";
    if (/\[(sad|sorrowful|cry|crying)\]/.test(lower)) return "sorrowful";
    if (/\[(excited)\]/.test(lower) || (text.match(/!/g)?.length ?? 0) >= 2) return "excited";
    return undefined;
  }
}

export const audioIdentityService = new AudioIdentityService();
