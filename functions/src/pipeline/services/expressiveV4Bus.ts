/**
 * 🎙️ TRUTHWORLD EXPRESSIVE V4 BUS
 *
 * Sits directly between the Translation Layer (Google Cloud Translation v3)
 * and the Synthesis Layer (ElevenLabs v4).
 *
 * Ingests per-segment acoustic telemetry (pitch dynamics, RMS loudness, speaking tempo,
 * and emotional intensity extracted during Step 1.6) and dynamically parameterizes
 * ElevenLabs v4 synthesis:
 *   1. Dynamic Stability (0.20 to 0.85) — allows vocal strain, breathiness, and emotional cracks
 *   2. Dynamic Style Exaggeration (0.00 to 0.65) — drives sarcasm, theatrical acting, and emphasis
 *   3. Dynamic Similarity Boost (0.65 to 0.90) — acoustic headroom for emotional vocal peaks
 *   4. Contextual Inline Tag Injection ([whispers], [shouts], [laughs], [sighs], [excited])
 */

import { VALID_ELEVENLABS_AUDIO_TAGS, sanitizeTextForElevenLabsV4 } from "./tts";
import { logger } from "../utils/logger";

export interface SegmentAcousticTelemetry {
  energyDb?: number;                    // RMS power, e.g. -24 dBFS
  pitchRangeSemitones?: number;         // F0 delta, e.g. 14 semitones
  speakingRateRatio?: number;           // Tempo ratio, e.g. 1.2x
  speakingRateSyllablesPerSec?: number; // e.g. 4.5
  emotionTag?: string;                  // e.g. "whispers", "laughs", "excited"
  emotionalIntensity?: {
    anger?: number;
    sadness?: number;
    joy?: number;
    fear?: number;
    disgust?: number;
    surprise?: number;
  };
  deliveryStyle?: string;               // e.g. "sarcastic", "matter-of-fact", "argumentative"
  voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
  energyEnvelopePattern?: "rising" | "falling" | "flat" | "dynamic";
  breathingPattern?: "natural" | "rapid" | "suppressed";
  stabilityOverride?: number;
  similarityBoostOverride?: number;
  styleOverride?: number;
}

export interface ExpressiveV4BusParams {
  jobId: string;
  language: string;
  translatedText: string;
  sourceText?: string;
  telemetry?: SegmentAcousticTelemetry;
  preferVoiceCloning?: boolean;
  voiceType?: "standard" | "cloned" | "voice_clone";
  targetDurationMs?: number;
  previousText?: string;
  nextText?: string;
}

export interface ExpressiveV4BusPayload {
  text: string;
  voiceSettings: {
    stability: number;
    similarity_boost: number;
    style: number;
    use_speaker_boost: boolean;
  };
  emotionTag?: string;
  stability: number;
  similarityBoost: number;
  style: number;
  detectedStyle: string;
  previousText?: string;
  nextText?: string;
  pacingAdjustment?: "compressed" | "expanded" | "neutral";
}

export class ExpressiveV4Bus {
  private static readonly CLAMP_01 = (v: number): number =>
    Number(Math.max(0, Math.min(1, v)).toFixed(2));

  /**
   * Transforms raw translated text + source acoustic telemetry into an
   * emotionally conditioned ElevenLabs v4 payload.
   */
  public processSegment(params: ExpressiveV4BusParams): ExpressiveV4BusPayload {
    const {
      jobId,
      language,
      translatedText,
      telemetry,
      preferVoiceCloning = false,
    } = params;

    const t = telemetry || {};

    // ── 1. Contextual Inline Tag Resolution ──────────────────────────────────
    let resolvedTag: string | undefined = undefined;

    if (t.emotionTag && VALID_ELEVENLABS_AUDIO_TAGS.has(t.emotionTag.toLowerCase().trim())) {
      resolvedTag = t.emotionTag.toLowerCase().trim();
    } else {
      // Infer emotion tag from acoustic metrics if not explicitly set
      const energy = t.energyDb;
      const emotions = t.emotionalIntensity || {};
      const anger = emotions.anger || 0;
      const joy = emotions.joy || 0;
      const sadness = emotions.sadness || 0;
      const surprise = emotions.surprise || 0;
      const delivery = (t.deliveryStyle || "").toLowerCase();

      if (energy !== undefined && energy < -38 || t.voiceQuality === "breathy") {
        resolvedTag = "whispers";
      } else if (anger > 0.6 && energy !== undefined && energy > -15) {
        resolvedTag = "shouts";
      } else if (anger > 0.6 || (energy !== undefined && energy > -14)) {
        resolvedTag = "said angrily";
      } else if (delivery.includes("sarcastic") || delivery.includes("ironic")) {
        resolvedTag = "sarcastic";
      } else if (joy > 0.65 || delivery.includes("laugh") || delivery.includes("chuckle")) {
        resolvedTag = "laughs";
      } else if (sadness > 0.55 || t.voiceQuality === "creaky") {
        resolvedTag = "sad";
      } else if (delivery.includes("sigh") || t.breathingPattern === "suppressed") {
        resolvedTag = "sighs";
      } else if (anger > 0.45) {
        resolvedTag = "said angrily";
      } else if (joy > 0.5 && surprise > 0.4) {
        resolvedTag = "excited";
      }
    }

    // ── 2. Dynamic Stability Calculation ──────────────────────────────────────
    let stability: number;
    if (typeof t.stabilityOverride === "number" && Number.isFinite(t.stabilityOverride)) {
      stability = ExpressiveV4Bus.CLAMP_01(t.stabilityOverride);
    } else {
      // Base stability: 0.55 for standard voices, 0.45 for voice clone
      let baseStability = preferVoiceCloning ? 0.45 : 0.55;

      const emotions = t.emotionalIntensity || {};
      const peakHighArousal = Math.max(
        emotions.anger || 0,
        emotions.joy || 0,
        emotions.surprise || 0
      );
      const peakLowArousal = Math.max(
        emotions.sadness || 0,
        emotions.fear || 0
      );

      // High arousal (anger/joy/sarcasm) lowers stability to allow natural vocal strain and cracks
      if (peakHighArousal > 0.3) {
        baseStability -= peakHighArousal * 0.25; // Drop up to -0.25 (e.g. 0.55 -> 0.30)
      } else if (peakLowArousal > 0.4) {
        baseStability -= peakLowArousal * 0.15; // Trembling / emotional hesitation
      }

      // Energy-based stability adjustment
      if (typeof t.energyDb === "number") {
        if (t.energyDb > -16) {
          baseStability -= 0.08; // Projecting loudly / shouting
        } else if (t.energyDb < -36) {
          baseStability = Math.min(baseStability, 0.38); // Breathy whisper
        }
      }

      // Pitch dynamics (F0 range): wide semitone range indicates dynamic acting/questioning
      if (typeof t.pitchRangeSemitones === "number") {
        if (t.pitchRangeSemitones > 12) {
          baseStability -= 0.08; // Dynamic inflections
        } else if (t.pitchRangeSemitones < 4 && peakHighArousal < 0.2) {
          baseStability += 0.20; // Monotone / formal reading
        }
      }

      // Clamp between 0.20 (lively/unstable acting) and 0.85 (anchor/liturgical steady)
      stability = Number(Math.max(0.20, Math.min(0.85, baseStability)).toFixed(2));
    }

    // ── 3. Dynamic Style Exaggeration Calculation (style) ─────────────────────
    let style: number;
    if (typeof t.styleOverride === "number" && Number.isFinite(t.styleOverride)) {
      style = ExpressiveV4Bus.CLAMP_01(t.styleOverride);
    } else {
      let baseStyle = 0.10; // Natural baseline

      const emotions = t.emotionalIntensity || {};
      const peakEmotion = Math.max(
        emotions.anger || 0,
        emotions.joy || 0,
        emotions.surprise || 0,
        emotions.sadness || 0
      );

      if (peakEmotion > 0.2) {
        baseStyle += peakEmotion * 0.50; // Scale style up to +0.50
      }

      const delivery = (t.deliveryStyle || "").toLowerCase();
      if (delivery.includes("sarcastic") || delivery.includes("argumentative") || delivery.includes("dramatic")) {
        baseStyle += 0.15;
      } else if (delivery.includes("matter-of-fact") || delivery.includes("formal") || delivery.includes("news")) {
        baseStyle = Math.min(baseStyle, 0.05);
      }

      // Cap style at 0.65 to maintain acoustic stability and avoid audio distortion
      style = Number(Math.max(0.00, Math.min(0.65, baseStyle)).toFixed(2));
    }

    // ── 4. Dynamic Similarity Boost Calculation ──────────────────────────────
    let similarityBoost: number;
    if (typeof t.similarityBoostOverride === "number" && Number.isFinite(t.similarityBoostOverride)) {
      similarityBoost = ExpressiveV4Bus.CLAMP_01(t.similarityBoostOverride);
    } else {
      let baseSimilarity = preferVoiceCloning ? 0.85 : 0.75;
      // High emotion/shouting: slight reduction gives voice model headroom to project without clipping
      if (style > 0.40 || stability < 0.35) {
        baseSimilarity = Math.max(0.70, baseSimilarity - 0.07);
      }
      similarityBoost = Number(Math.max(0.65, Math.min(0.95, baseSimilarity)).toFixed(2));
    }

    // ── 5. Pre-Synthesis Micro-Pacing Punctuation Conditioning ───────────────
    const { pacedText, pacingAdjustment } = this.applyMicroPacing(
      translatedText,
      language,
      params.targetDurationMs,
      t.speakingRateRatio
    );

    // ── 6. Clean Text Sanitization & Inline Tag Formatting ───────────────────
    const vocalText = sanitizeTextForElevenLabsV4(pacedText, resolvedTag);

    // Clean context texts for non-billed ElevenLabs cadence continuity
    const cleanContext = (ctx?: string): string | undefined => {
      if (!ctx || typeof ctx !== "string") return undefined;
      const stripped = ctx.replace(/\[[^\]]+\]/g, " ").replace(/\s+/g, " ").trim();
      return stripped.length > 0 ? stripped : undefined;
    };
    const cleanPrev = cleanContext(params.previousText);
    const cleanNext = cleanContext(params.nextText);

    const detectedStyle = t.deliveryStyle || (resolvedTag ? `expressive:${resolvedTag}` : "natural");

    logger.debug("[ExpressiveV4Bus] Conditioned speech turn:", {
      jobId,
      language,
      resolvedTag,
      stability,
      style,
      similarityBoost,
      detectedStyle,
      pacingAdjustment,
      hasPrevContext: Boolean(cleanPrev),
      hasNextContext: Boolean(cleanNext),
      originalLength: translatedText.length,
      vocalLength: vocalText.length,
    });

    return {
      text: vocalText,
      voiceSettings: {
        stability,
        similarity_boost: similarityBoost,
        style,
        use_speaker_boost: true,
      },
      emotionTag: resolvedTag,
      stability,
      similarityBoost,
      style,
      detectedStyle,
      previousText: cleanPrev,
      nextText: cleanNext,
      pacingAdjustment,
    };
  }

  /**
   * Applies pre-synthesis punctuation micro-pacing based on target duration
   * and speaking tempo ratio to optimize cadence and minimize post-synthesis ffmpeg atempo warping.
   */
  public applyMicroPacing(
    text: string,
    language: string,
    targetDurationMs?: number,
    speakingRateRatio?: number
  ): { pacedText: string; pacingAdjustment: "compressed" | "expanded" | "neutral" } {
    if (!text || text.trim().length === 0) {
      return { pacedText: text, pacingAdjustment: "neutral" };
    }

    const clean = text.replace(/\[[^\]]+\]/g, "").trim();
    const charsPerSec = ["te", "ta", "ml", "kn", "hi", "mr", "bn"].includes(language) ? 14 : 16;
    const estDurationMs = (clean.length / charsPerSec) * 1000;

    const isFastTempo =
      (speakingRateRatio !== undefined && speakingRateRatio > 1.15) ||
      (targetDurationMs !== undefined && targetDurationMs > 500 && estDurationMs > targetDurationMs * 1.15);

    const isSlowTempo =
      (speakingRateRatio !== undefined && speakingRateRatio < 0.88) ||
      (targetDurationMs !== undefined && targetDurationMs > 1500 && estDurationMs < targetDurationMs * 0.72);

    if (isFastTempo) {
      // Tight window / fast speech: prune non-essential pauses so speech articulates briskly
      let paced = text
        .replace(/\.{3,}/g, ",")                     // Ellipses into short comma pause
        .replace(/—|–/g, ",")                        // Em/en-dashes into short comma pause
        .replace(/,\s*,+/g, ",")                     // Collapse duplicate commas
        .replace(/,\s*(మరియు|కానీ|కాబట్టి|and|but|because|so|pero|mais|ou)(?=\s|$)/gi, " $1") // Prune pause before coordinating conjunctions
        .replace(/\s{2,}/g, " ")
        .trim();
      return { pacedText: paced, pacingAdjustment: "compressed" };
    }

    if (isSlowTempo && clean.length > 35) {
      // Loose window / slow speech: insert natural syntactic clause micro-pauses at conjunctions
      // to let the speaker naturally breathe instead of rushing through followed by dead air.
      let paced = text
        .replace(/(?<![,;:!?.—])\s+(మరియు|కానీ|కాబట్టి|and|but|because|so|pero|mais)(?=\s|$)/gi, ", $1")
        .replace(/;\s*/g, ", ")
        .replace(/\s{2,}/g, " ")
        .trim();
      return { pacedText: paced, pacingAdjustment: "expanded" };
    }

    return { pacedText: text, pacingAdjustment: "neutral" };
  }
}

export const expressiveV4Bus = new ExpressiveV4Bus();
