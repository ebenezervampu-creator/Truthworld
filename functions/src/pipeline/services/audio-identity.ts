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
import { ElevenLabsEmotionTag, EmotionalIntensityProfile, SegmentProsodyCue } from "../types";

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
  whispers:  { stability: 0.34, similarityBoost: 0.88 },
  shouts:    { stability: 0.28, similarityBoost: 0.84 },
  laughs:    { stability: 0.32, similarityBoost: 0.85 },
  sighs:     { stability: 0.38, similarityBoost: 0.87 },
  gasps:     { stability: 0.30, similarityBoost: 0.86 },
  excited:   { stability: 0.34, similarityBoost: 0.85 },
  sorrowful: { stability: 0.36, similarityBoost: 0.88 },
  angry:     { stability: 0.30, similarityBoost: 0.84 },
  calm:      { stability: 0.62, similarityBoost: 0.86 },
  serious:   { stability: 0.56, similarityBoost: 0.87 },
};

export function mapEmotionToElevenLabsCue(
  emotion?: string,
  energyDb?: number,
  voiceQuality?: VoiceQualityType,
  emotionalIntensity?: EmotionalIntensityProfile
): { emotionTag?: ElevenLabsEmotionTag; stabilityOverride: number; similarityBoostOverride: number } {
  const norm = (emotion || "").toLowerCase().trim();
  const aliasMap: Record<string, ElevenLabsEmotionTag> = {
    whisper: "whispers",
    whispers: "whispers",
    intimate: "whispers",
    shout: "shouts",
    shouts: "shouts",
    yelling: "shouts",
    screaming: "shouts",
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
    sad: "sorrowful",
    sorrowful: "sorrowful",
    crying: "sorrowful",
    grief: "sorrowful",
    angry: "angry",
    furious: "angry",
    frustrated: "angry",
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
    if (energyDb <= -32) tag = "whispers";
    else if (energyDb >= -11) tag = "shouts";
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
  roomTone:    "dry-studio" | "small-room" | "large-reflective" | "outdoor-open";
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
      model: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || "gemini-2.5-flash",
    });
  }

  /**
   * 1. 🎙️ Isolate Vocals using ElevenLabs Audio Isolation API
   * Removes background music/noise to extract pure "Vocal Identity".
   */
  async isolateVocals(jobId: string, audioUrl: string): Promise<string> {
    logger.info("[AudioIdentity] Isolating vocals", { jobId, audioUrl });

    try {
      const apiKey = PIPELINE_CONFIG.ELEVENLABS_API_KEY;
      if (!apiKey) {
        throw new Error("ELEVENLABS_API_KEY is not configured for vocal isolation");
      }

      // Download audio directly via Authenticated Storage SDK (eliminates 403 Forbidden on private objects)
      const rawBuffer = await downloadStorageBuffer(audioUrl);

      // If the input is a video container (.mp4, .mov, etc.), extract clean MP3 audio with FFmpeg first
      let audioBuffer: Buffer = rawBuffer;
      const isVideo = audioUrl.toLowerCase().includes(".mp4") || audioUrl.toLowerCase().includes(".mov") || audioUrl.toLowerCase().includes(".webm");

      if (isVideo) {
        const ffmpegPath = getFfmpegPath();
        if (!ffmpegPath) {
          logger.warn("[AudioIdentity] FFmpeg binary unavailable for video container audio extraction; returning original URL", { jobId, audioUrl });
          return audioUrl;
        }
        const tmpDir = os.tmpdir();
        const tmpInput = path.join(tmpDir, `vocal_iso_in_${jobId}_${Date.now()}.mp4`);
        const tmpOutput = path.join(tmpDir, `vocal_iso_out_${jobId}_${Date.now()}.mp3`);
        try {
          await fs.promises.writeFile(tmpInput, rawBuffer);
          await execFileAsync(ffmpegPath, [
            "-y",
            "-i", tmpInput,
            "-vn",
            "-ac", "2",
            "-ar", "44100",
            "-b:a", "192k",
            tmpOutput,
          ]);
          audioBuffer = await fs.promises.readFile(tmpOutput);
        } finally {
          await fs.promises.unlink(tmpInput).catch(() => {});
          await fs.promises.unlink(tmpOutput).catch(() => {});
        }
      }

      const formData = new FormData();
      formData.append("audio", new Blob([audioBuffer as any]), "original.mp3");

      const xiResponse = await fetch("https://api.elevenlabs.io/v1/audio-isolation", {
        method: "POST",
        headers: {
          "xi-api-key": apiKey,
        },
        body: formData,
      });

      if (!xiResponse.ok) {
        const errBody = await xiResponse.text().catch(() => "");
        throw new Error(`ElevenLabs Isolation failed (${xiResponse.status} ${xiResponse.statusText}): ${errBody || "Unknown error"}`);
      }

      const isolatedBuffer = await xiResponse.arrayBuffer();
      const bucket = admin.storage().bucket();
      const filePath = `audio/${jobId}/isolated-vocal.mp3`;
      const file = bucket.file(filePath);

      await file.save(Buffer.from(isolatedBuffer), {
        metadata: { contentType: "audio/mpeg" },
      });

      return `gs://${bucket.name}/${filePath}`;
    } catch (error) {
      logger.error("[AudioIdentity] Isolation failed", { jobId, error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  }

  /**
   * 2. 🧠 Capture Acoustic Fingerprint (Semantic Descriptors)
   * Uses Vertex AI Gemini 2.5 Flash Multimodal Audio to analyze the creator's
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
   - "dry-studio" (treated vocal booth, zero reverb)
   - "small-room" (slight natural bedroom/office reflections)
   - "large-reflective" (hall, large untreated room, noticeable echo)
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
  "roomTone": "dry-studio" | "small-room" | "large-reflective" | "outdoor-open",
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

    // C. Room Tone (Reverb emulation)
    switch(fingerprint.roomTone) {
      case "small-room": 
        filters.push("aecho=0.8:0.88:40:0.25"); 
        break;
      case "large-reflective": 
        filters.push("aecho=0.8:0.88:90:0.35"); 
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
      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 3600 * 1000,
      });
      return signedUrl;
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

      // 2a. Deep Per-Segment Gemini 2.5 Flash Multimodal Audio Analysis (inlineData WAV slices, bounded concurrency)
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

Return ONLY valid JSON:
{
  "pitchRangeSemitones": number (0 to 24),
  "speakingRateSyllablesPerSec": number (1.5 to 9.0),
  "voiceQuality": "breathy" | "modal" | "creaky" | "pressed",
  "emotionalIntensity": { "anger": 0-1, "sadness": 0-1, "joy": 0-1, "fear": 0-1, "disgust": 0-1, "surprise": 0-1 },
  "energyEnvelopePattern": "rising" | "falling" | "flat" | "dynamic",
  "breathingPattern": "natural" | "rapid" | "suppressed",
  "accentStressMarkers": string[],
  "recommendedElevenLabsTag": "whispers" | "shouts" | "laughs" | "sighs" | "gasps" | "excited" | "sorrowful" | "angry" | "calm" | "serious" | "neutral",
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
Allowed emotions: "whispers", "shouts", "laughs", "sighs", "gasps", "excited", "sorrowful", "angry", "calm", "serious", "neutral".
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

    // 3. Fuse acoustic energy + speaking rate + deep multimodal prosody into ElevenLabs v4 cues
    for (const seg of segments) {
      const energyDb = energyMap.get(seg.index);
      const durSec = Math.max(0.25, (seg.end - seg.start) / 1000);
      const words = seg.text.trim().split(/\s+/).filter(Boolean).length;
      const wordsPerSec = words / durSec;
      const speakingRateRatio = Number(Math.max(0.75, Math.min(1.35, wordsPerSec / 2.6)).toFixed(2));

      const geminiCue = geminiProsodyMap.get(seg.index);
      const lexicalEmotion = this.inferLexicalEmotionHint(seg.text);
      const rawEmotion =
        geminiCue?.emotion && geminiCue.emotion.toLowerCase() !== "neutral"
          ? geminiCue.emotion
          : lexicalEmotion;

      const mapped = mapEmotionToElevenLabsCue(
        rawEmotion,
        energyDb,
        geminiCue?.voiceQuality,
        geminiCue?.emotionalIntensity
      );

      // Gemini recommended stability/similarity take precedence when explicitly provided
      const finalStability =
        typeof geminiCue?.recommendedStability === "number" && Number.isFinite(geminiCue.recommendedStability)
          ? geminiCue.recommendedStability
          : mapped.stabilityOverride;
      const finalSimilarity =
        typeof geminiCue?.recommendedSimilarityBoost === "number" && Number.isFinite(geminiCue.recommendedSimilarityBoost)
          ? geminiCue.recommendedSimilarityBoost
          : mapped.similarityBoostOverride;

      cues.set(seg.index, {
        segmentIndex: seg.index,
        emotionTag: mapped.emotionTag,
        energyDb,
        speakingRateRatio,
        stabilityOverride: finalStability,
        similarityBoostOverride: finalSimilarity,
        deliveryStyle: geminiCue?.style || (mapped.emotionTag ? `expressive:${mapped.emotionTag}` : "natural"),
        pitchRangeSemitones: geminiCue?.pitchRangeSemitones,
        speakingRateSyllablesPerSec: geminiCue?.speakingRateSyllablesPerSec,
        voiceQuality: geminiCue?.voiceQuality,
        emotionalIntensity: geminiCue?.emotionalIntensity,
        energyEnvelopePattern: geminiCue?.energyEnvelopePattern,
        breathingPattern: geminiCue?.breathingPattern,
        accentStressMarkers: geminiCue?.accentStressMarkers,
      });
    }

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
    if (/\[(whisper|whispers|softly)\]/.test(lower)) return "whispers";
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
