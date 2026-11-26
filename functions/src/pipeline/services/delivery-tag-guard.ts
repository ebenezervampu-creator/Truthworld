/**
 * 🛡️ Delivery Tag Guard — False Whisper Prevention & Scene Delivery Smoothing
 *
 * Rules:
 * 1. Whisper only when the line is genuinely whispered, with positive evidence (isVerifiedWhisper):
 *    no pitch, a MEASURED voiced frame share below MAX_WHISPER_VOICED_SHARE (0.20), and Gemini
 *    not hearing a modal/pressed voice. A missing measurement is "unknown", never "unvoiced".
 *    Every other line proposed as whispers is downgraded to "soft".
 * 2. Relative, not absolute, quietness: a line is quiet only when its energy is
 *    at least QUIET_SPEAKER_OFFSET_DB (10 dB) below that speaker's own median energy.
 *    A quiet line gets "soft" (or no tag), never "whispers" from energy alone.
 * 3. Soft delivery: quiet, grounded, fully voiced speech using the speaker's locked
 *    stability (no 0.34 drop). Maps to no tag for ElevenLabs v4 synthesis based on
 *    measurements showing [softly] induces breathiness and pitch drop.
 * 4. Scene delivery smoothing: within a scene (same speaker, gap < 3 s), keep delivery
 *    steady between soft/neutral/calm unless source evidence (energy change >= 6 dB or
 *    emotional intensity >= 0.72) is strong. Strong emotion tags are untouched.
 * 5. Full traceability: log per segment and per job.
 * 6. Rollback flag: DUBBING_WHISPER_GUARD=false restores previous behavior exactly.
 */

import { ElevenLabsEmotionTag, EmotionalIntensityProfile } from "../types";
import { logger } from "../utils/logger";

/** Maximum voiced-frame share (0..1) for a line to be considered genuinely whispered. */
export const MAX_WHISPER_VOICED_SHARE = 0.20;

/** Relative quietness offset (dB) below speaker's median energy in the video. */
export const QUIET_SPEAKER_OFFSET_DB = 10.0;

/** Relative loudness offset (dB) above speaker's median energy in the video. */
export const SHOUT_SPEAKER_OFFSET_DB = 10.0;

/** Maximum gap between adjacent lines (ms) for scene delivery smoothing. */
export const MAX_SCENE_GAP_MS = 3000;

/** Minimum energy change (dB) required to switch delivery between soft/neutral/calm within a scene. */
export const STRONG_ENERGY_CHANGE_THRESHOLD_DB = 6.0;

/** Emotional intensity threshold above which source evidence for delivery change is considered strong. */
export const STRONG_EMOTION_INTENSITY_THRESHOLD = 0.72;

/** Cache key version for the prosody step so changes in delivery tag rules invalidate prior prosody caches. */
export const PROSODY_RULE_VERSION = 3;

/** Set of gentle tags that may be smoothed when scene evidence for switching is weak. */
export const GENTLE_DELIVERY_TAGS = new Set<string>(["soft", "calm", "neutral", ""]);

/** Set of strong emotion tags that are NEVER smoothed away or changed by scene smoothing. */
export const STRONG_EMOTION_TAGS = new Set<string>([
  "shouts",
  "shouting",
  "screaming",
  "crying",
  "distressed",
  "menacing",
  "intense",
  "laughs",
  "sighs",
  "gasps",
  "angry",
  "said angrily",
  "excited",
  "sorrowful",
  "sad",
  "whispers",
]);

export function isDubbingWhisperGuardEnabled(): boolean {
  return String(process.env.DUBBING_WHISPER_GUARD ?? "true").toLowerCase() !== "false";
}

export interface DeliveryTagInput {
  index: number;
  speaker?: string;
  startMs?: number;
  endMs?: number;
  f0Hz?: number | null;
  voicedShare?: number | null;
  energyDb?: number | null;
  speakerMedianDb?: number | null;
  voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
  geminiTag?: string;
  proposedTag?: string;
  emotionalIntensity?: EmotionalIntensityProfile;
  peakIntensity?: number;
}

export type WhisperEvidence = "verified" | "voiced" | "unmeasured" | "voice_heard";

/**
 * Whether a line proposed as a whisper really is one. The only whisper rule in the pipeline:
 * mapEmotionToElevenLabsCue and decideDeliveryTag both call it.
 *
 * Needs positive evidence. On 2026-11-24 (te run dub-test-te-1795522961000) lines 0, 4 and 10 logged
 * f0Hz null / voicedShare 0 because the pitch estimator found too few frames, not because they were
 * unvoiced; line 0 is 5.3 s that Gemini rated "modal". Treating that as "unvoiced" kept [whispers]
 * on line 10 (00:54), which the reviewer flagged, and on two Hindi lines.
 */
export function whisperEvidence(input: {
  f0Hz?: number | null;
  voicedShare?: number | null;
  voiceQuality?: string | null;
}): WhisperEvidence {
  const hasPitch = typeof input.f0Hz === "number" && input.f0Hz > 0;
  if (hasPitch) return "voiced";
  const share = input.voicedShare;
  if (typeof share !== "number" || !Number.isFinite(share)) return "unmeasured";
  if (share >= MAX_WHISPER_VOICED_SHARE) return "voiced";
  const quality = (input.voiceQuality || "").toLowerCase();
  if (quality === "modal" || quality === "pressed") return "voice_heard";
  return "verified";
}

export function isVerifiedWhisper(input: { f0Hz?: number | null; voicedShare?: number | null; voiceQuality?: string | null }): boolean {
  return whisperEvidence(input) === "verified";
}

export interface DeliveryTagDecision {
  finalTag?: ElevenLabsEmotionTag;
  reason: string;
  wasWhisperProposed: boolean;
  wasWhisperKept: boolean;
  wasDowngradedToSoft: boolean;
  proposedTag?: string;
}

/**
 * Decides whether a proposed delivery tag is acoustically justified.
 * Prevents false whispers on voiced lines and ensures relative quietness.
 */
export function decideDeliveryTag(
  input: DeliveryTagInput,
  options: { enabled?: boolean } = {}
): DeliveryTagDecision {
  const enabled = options.enabled ?? isDubbingWhisperGuardEnabled();
  const rawProposed = (input.proposedTag || input.geminiTag || "").toLowerCase().trim();

  // If guard is disabled, restore exact legacy behavior
  if (!enabled) {
    const isWhisper = rawProposed === "whispers" || rawProposed === "whisper" || rawProposed === "intimate";
    let legacyTag: ElevenLabsEmotionTag | undefined = isWhisper ? "whispers" : (input.proposedTag as ElevenLabsEmotionTag);
    if (!legacyTag && typeof input.energyDb === "number" && Number.isFinite(input.energyDb)) {
      if (input.energyDb <= -32) legacyTag = "whispers";
      else if (input.energyDb >= -11) legacyTag = "shouts";
    }
    return {
      finalTag: legacyTag,
      reason: "guard_disabled",
      wasWhisperProposed: isWhisper || (typeof input.energyDb === "number" && input.energyDb <= -32),
      wasWhisperKept: legacyTag === "whispers",
      wasDowngradedToSoft: false,
      proposedTag: legacyTag,
    };
  }

  // 1. Determine the candidate tag (evaluating lexical, Gemini, and relative acoustic energy)
  let candidateTag = rawProposed;
  if (candidateTag === "intimate" || candidateTag === "softly" || candidateTag === "quiet") {
    candidateTag = "soft";
  } else if (candidateTag === "whisper") {
    candidateTag = "whispers";
  }

  // Relative energy check if no explicit emotion tag is set
  if (!candidateTag && typeof input.energyDb === "number" && Number.isFinite(input.energyDb)) {
    if (typeof input.speakerMedianDb === "number" && Number.isFinite(input.speakerMedianDb)) {
      if (input.energyDb <= input.speakerMedianDb - QUIET_SPEAKER_OFFSET_DB) {
        candidateTag = "soft";
      } else if (input.energyDb >= input.speakerMedianDb + SHOUT_SPEAKER_OFFSET_DB) {
        candidateTag = "shouts";
      }
    } else {
      // Fallback if speaker median is unavailable
      if (input.energyDb <= -36) {
        candidateTag = "soft";
      } else if (input.energyDb >= -11) {
        candidateTag = "shouts";
      }
    }
  }

  const isWhisperProposed = candidateTag === "whispers";

  if (isWhisperProposed) {
    // A true whisper is unvoiced airflow, and that has to be measured (whisperEvidence).
    const evidence = whisperEvidence(input);

    if (evidence !== "verified") {
      // Voiced, or not measurable: downgrade to "soft"
      const f0Str = typeof input.f0Hz === "number" ? `${input.f0Hz}Hz` : "none";
      const vsStr = typeof input.voicedShare === "number" ? `${(input.voicedShare * 100).toFixed(0)}%` : "unmeasured";
      const why =
        evidence === "unmeasured"
          ? "whisper_unverified_no_voicing_measurement"
          : evidence === "voice_heard"
            ? `whisper_unverified_voice_heard(${input.voiceQuality})`
            : "voiced_whisper_downgraded_to_soft";
      return {
        finalTag: "soft",
        reason: `${why}(pitch=${f0Str},voiced=${vsStr})`,
        wasWhisperProposed: true,
        wasWhisperKept: false,
        wasDowngradedToSoft: true,
        proposedTag: "whispers",
      };
    } else {
      // Genuinely unvoiced breath
      return {
        finalTag: "whispers",
        reason: "unvoiced_whisper_verified",
        wasWhisperProposed: true,
        wasWhisperKept: true,
        wasDowngradedToSoft: false,
        proposedTag: "whispers",
      };
    }
  }

  const normalizedFinal = candidateTag ? (candidateTag as ElevenLabsEmotionTag) : undefined;
  return {
    finalTag: normalizedFinal,
    reason: normalizedFinal ? `accepted_${normalizedFinal}` : "neutral_untagged",
    wasWhisperProposed: false,
    wasWhisperKept: false,
    wasDowngradedToSoft: false,
    proposedTag: candidateTag || undefined,
  };
}

export interface SmoothDeliveryItem {
  index: number;
  speaker?: string;
  startMs?: number;
  endMs?: number;
  energyDb?: number | null;
  finalTag?: ElevenLabsEmotionTag;
  peakIntensity?: number;
  reason?: string;
}

export interface SmoothingChange {
  index: number;
  speaker?: string;
  fromTag?: string;
  toTag?: string;
  gapMs: number;
  energyChangeDb: number;
  reason: string;
}

/**
 * Keeps delivery steady within a scene:
 * Smooths per speaker over adjacent lines (gap < MAX_SCENE_GAP_MS):
 * Switches between soft/neutral/calm are only permitted with strong source evidence
 * (energy change >= STRONG_ENERGY_CHANGE_THRESHOLD_DB or peak intensity >= STRONG_EMOTION_INTENSITY_THRESHOLD).
 * Strong emotion tags (crying, shouting, laughs...) are untouched.
 */
export function smoothDeliveryTagsPerSpeaker<T extends SmoothDeliveryItem>(
  segments: T[],
  options: { enabled?: boolean; maxSceneGapMs?: number } = {}
): {
  smoothedSegments: T[];
  smoothedCount: number;
  changes: SmoothingChange[];
} {
  const enabled = options.enabled ?? isDubbingWhisperGuardEnabled();
  const maxGap = options.maxSceneGapMs ?? MAX_SCENE_GAP_MS;

  if (!enabled || segments.length <= 1) {
    return { smoothedSegments: segments, smoothedCount: 0, changes: [] };
  }

  const changes: SmoothingChange[] = [];
  const out = segments.map((s) => ({ ...s }));

  // Group indices by speaker to smooth within each speaker's scene turns
  const speakerIndices = new Map<string, number[]>();
  for (let i = 0; i < out.length; i++) {
    const spk = out[i].speaker || "speaker_0";
    if (!speakerIndices.has(spk)) speakerIndices.set(spk, []);
    speakerIndices.get(spk)!.push(i);
  }

  for (const [_spk, indices] of speakerIndices) {
    for (let k = 1; k < indices.length; k++) {
      const prevIdx = indices[k - 1];
      const currIdx = indices[k];
      const prev = out[prevIdx];
      const curr = out[currIdx];

      const gapMs = (curr.startMs ?? 0) - (prev.endMs ?? 0);
      if (gapMs < 0 || gapMs > maxGap) continue;

      const prevTag = (prev.finalTag || "").toLowerCase().trim();
      const currTag = (curr.finalTag || "").toLowerCase().trim();

      // Strong emotion tags are untouched
      if (STRONG_EMOTION_TAGS.has(currTag) || STRONG_EMOTION_TAGS.has(prevTag)) {
        continue;
      }

      // Both are gentle tags (soft, calm, neutral, untagged)
      const isPrevGentle = GENTLE_DELIVERY_TAGS.has(prevTag);
      const isCurrGentle = GENTLE_DELIVERY_TAGS.has(currTag);

      if (isPrevGentle && isCurrGentle && currTag !== prevTag) {
        const energyChange =
          typeof curr.energyDb === "number" && typeof prev.energyDb === "number"
            ? Math.abs(curr.energyDb - prev.energyDb)
            : 0;
        const peakIntensity = curr.peakIntensity ?? 0;

        const hasStrongEvidence =
          energyChange >= STRONG_ENERGY_CHANGE_THRESHOLD_DB ||
          peakIntensity >= STRONG_EMOTION_INTENSITY_THRESHOLD;

        if (!hasStrongEvidence) {
          // Evidence is weak: maintain steady delivery from previous line
          const targetTag = prev.finalTag;
          changes.push({
            index: curr.index,
            speaker: curr.speaker,
            fromTag: curr.finalTag,
            toTag: targetTag,
            gapMs,
            energyChangeDb: Number(energyChange.toFixed(1)),
            reason: `scene_smoothing(gap=${gapMs}ms,dE=${energyChange.toFixed(1)}dB,intensity=${peakIntensity.toFixed(2)})`,
          });

          curr.finalTag = targetTag;
          curr.reason = `${curr.reason || ""}; smoothed_from_${currTag || "neutral"}_to_${prevTag || "neutral"}`;
          logger.info("[Dubbing:DeliveryTag] Smoothed line delivery within scene", {
            index: curr.index,
            speaker: curr.speaker,
            from: currTag || "neutral",
            to: prevTag || "neutral",
            gapMs,
            energyChangeDb: Number(energyChange.toFixed(1)),
          });
        }
      }
    }
  }

  return {
    smoothedSegments: out,
    smoothedCount: changes.length,
    changes,
  };
}

/** Summarizes delivery tag metrics for job telemetry. */
export function summarizeDeliveryTags(
  decisions: Array<{ wasWhisperProposed: boolean; wasWhisperKept: boolean; wasDowngradedToSoft: boolean }>,
  smoothedCount = 0
): {
  whispersProposed: number;
  whispersKept: number;
  downgradedToSoft: number;
  smoothed: number;
} {
  let whispersProposed = 0;
  let whispersKept = 0;
  let downgradedToSoft = 0;

  for (const d of decisions) {
    if (d.wasWhisperProposed) whispersProposed++;
    if (d.wasWhisperKept) whispersKept++;
    if (d.wasDowngradedToSoft) downgradedToSoft++;
  }

  return {
    whispersProposed,
    whispersKept,
    downgradedToSoft,
    smoothed: smoothedCount,
  };
}
