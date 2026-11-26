/**
 * Per-speaker voice-settings lock (dependency-free, unit-tested).
 *
 * Problem: per-line prosody analysis (audio-identity.analyzeSegmentProsody) asks Gemini about each
 * line in isolation and gets back a stability (0.25–0.75) and similarity boost (0.75–0.95) for that
 * line alone. When a line has no Gemini value, the expressive bus derives stability from emotion and
 * energy (0.20–0.85). Either way, one speaker's lines reach ElevenLabs with different voice settings,
 * so the same voice ID sounds like a different person from line to line.
 *
 * Fix: each speaker gets ONE baseline (median of their lines' values, or the bus default when there
 * are none). Similarity boost — how tightly the output sticks to the voice — is set to the baseline on
 * every line. Stability may move at most ±MAX_STABILITY_DEVIATION from the baseline, so delivery can
 * still lift or soften. Emotion tags ("[sad]", "[whispers]") are untouched and still vary per line.
 */

import { EXPRESSIVE, expressiveModeEnabled } from "./expressive-mode";

/** Largest per-line stability move away from the speaker's baseline. */
export const MAX_STABILITY_DEVIATION = 0.05;

/** Expressive-bus defaults, used when a speaker has no per-line values at all. */
export const DEFAULT_STABILITY = 0.55;
export const DEFAULT_CLONE_STABILITY = 0.45;
export const DEFAULT_SIMILARITY = 0.85;

export interface VoiceLockable {
  speaker?: string;
  stabilityOverride?: number;
  similarityBoostOverride?: number;
}

export interface SpeakerVoiceBaseline {
  stability: number;
  similarityBoost: number;
  /** Lines of this speaker that carried their own value (0 = defaults were used). */
  measuredLines: number;
}

const isNum = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);
const round2 = (v: number): number => Number(v.toFixed(2));

function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/** One baseline per speaker label. Lines without a speaker are grouped as "speaker_0", matching voiceMapping. */
export function computeSpeakerVoiceBaselines(
  segments: VoiceLockable[],
  opts: { preferVoiceCloning?: boolean; expressive?: boolean } = {}
): Map<string, SpeakerVoiceBaseline> {
  const expressive = opts.expressive ?? expressiveModeEnabled();
  const bySpeaker = new Map<string, { stab: number[]; sim: number[] }>();
  for (const seg of segments) {
    const id = seg.speaker || "speaker_0";
    if (!bySpeaker.has(id)) bySpeaker.set(id, { stab: [], sim: [] });
    const bucket = bySpeaker.get(id)!;
    if (isNum(seg.stabilityOverride)) bucket.stab.push(seg.stabilityOverride);
    if (isNum(seg.similarityBoostOverride)) bucket.sim.push(seg.similarityBoostOverride);
  }

  const defaultStability = opts.preferVoiceCloning ? DEFAULT_CLONE_STABILITY : DEFAULT_STABILITY;
  const baselines = new Map<string, SpeakerVoiceBaseline>();
  for (const [id, { stab, sim }] of bySpeaker) {
    const stability = stab.length ? median(stab) : defaultStability;
    baselines.set(id, {
      // DUBBING_EXPRESSIVE: cap the speaker's steady point lower (expressive-mode.ts).
      stability: round2(expressive ? Math.min(stability, EXPRESSIVE.baselineCap) : stability),
      similarityBoost: round2(sim.length ? median(sim) : DEFAULT_SIMILARITY),
      measuredLines: Math.max(stab.length, sim.length),
    });
  }
  return baselines;
}

/**
 * Returns copies of the segments with stabilityOverride / similarityBoostOverride locked to their
 * speaker's baseline. Every line ends up with explicit values, so no later step can fall back to a
 * per-line emotion-derived stability. Input order and every other field are preserved.
 */
export function lockVoiceSettingsPerSpeaker<T extends VoiceLockable>(
  segments: T[],
  opts: { preferVoiceCloning?: boolean; expressive?: boolean } = {}
): {
  segments: Array<T & { stabilityOverride: number; similarityBoostOverride: number }>;
  baselines: Map<string, SpeakerVoiceBaseline>;
} {
  const expressive = opts.expressive ?? expressiveModeEnabled();
  const baselines = computeSpeakerVoiceBaselines(segments, { ...opts, expressive });
  const deviation = expressive ? EXPRESSIVE.maxDeviation : MAX_STABILITY_DEVIATION;
  const locked = segments.map((seg) => {
    const base = baselines.get(seg.speaker || "speaker_0")!;
    const own = isNum(seg.stabilityOverride) ? seg.stabilityOverride : base.stability;
    const stability = round2(
      Math.min(base.stability + deviation, Math.max(base.stability - deviation, own))
    );
    return { ...seg, stabilityOverride: stability, similarityBoostOverride: base.similarityBoost };
  });
  return { segments: locked, baselines };
}
