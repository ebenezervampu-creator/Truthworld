/**
 * Expressive voice mode (2026-11-24, flag DUBBING_EXPRESSIVE=true, off by default) — "version B".
 *
 * Why: viewers who watched the te test dub said the voices are obviously AI and they could not listen
 * for one minute. Two of our own settings hold every line to the same steady read:
 *   - a stability floor of 0.5 on every non-English line (dubbing-guards.ts MIN_DUBBING_STABILITY), and
 *   - one stability per speaker, each line within ±0.05 of it (speaker-voice-lock.ts); the te run
 *     locked the two speakers at 0.57 and 0.55.
 * On eleven_v4, stability is the expressiveness control: "Lower values allow more expressive delivery;
 * higher values make delivery more consistent" (default 0.5). Style and Speed are not available on v4,
 * so there is nothing else to turn up.
 *
 * Here, when on: a lower floor, each speaker's baseline capped lower, and a wider per-line range so
 * Gemini's per-line stability (from the original's delivery) actually reaches the voice.
 * Risk recorded in dubbing-guards.ts: near 0.2 Telugu slurred; the floor stays well above that.
 * This is an experiment to be judged by listeners, not a tuned default.
 */

export const EXPRESSIVE = {
  /** Stability floor for non-English lines (normal mode: 0.5). Bounded to [0.3, 0.5]. */
  stabilityFloor: 0.38,
  /** Highest per-speaker baseline (normal mode: the median of the speaker's lines, ~0.55). */
  baselineCap: 0.42,
  /** Per-line move allowed around the speaker's baseline (normal mode: 0.05). */
  maxDeviation: 0.15,
} as const;

export function expressiveModeEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_EXPRESSIVE ?? "").toLowerCase() === "true";
}

/** Floor, overridable with DUBBING_EXPRESSIVE_STABILITY_FLOOR (clamped to 0.3–0.5). */
export function expressiveStabilityFloor(env: Record<string, string | undefined> = process.env): number {
  const raw = Number(env.DUBBING_EXPRESSIVE_STABILITY_FLOOR);
  const v = env.DUBBING_EXPRESSIVE_STABILITY_FLOOR !== undefined && env.DUBBING_EXPRESSIVE_STABILITY_FLOOR !== "" && Number.isFinite(raw)
    ? raw
    : EXPRESSIVE.stabilityFloor;
  return Math.max(0.3, Math.min(0.5, v));
}
