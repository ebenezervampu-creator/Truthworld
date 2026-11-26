/**
 * AssemblyAI `speaker_options` for a job (dependency-free, unit-tested).
 *
 * AssemblyAI treats min/max speakers as hard limits. Its default cap is 10 speakers for 2–10 minute
 * audio and 30 for longer audio; beyond the cap, extra people are merged into existing labels —
 * and a merged label becomes one dubbed voice for several people.
 *
 * Policy:
 *  - Creator gave a count → use it (min = their number, max = min + 2 headroom, unless they set max).
 *  - Dubbing job, no count → raise only the cap, never the floor, so crowded videos are not merged:
 *      < 2 min → 12, 2–10 min → 20, ≥ 10 min → 30.
 *    A floor is never guessed: a one-person video must stay one voice.
 *    Too high a cap can over-split one person into two labels; the diarization check
 *    (diarization-reconcile.ts) merges those back, while a merge AssemblyAI made under a low cap is
 *    much harder to undo.
 *  - Otherwise → nothing (AssemblyAI defaults).
 */

export interface SpeakerCountHint {
  min?: number;
  max?: number;
}

export interface AssemblySpeakerOptions {
  min_speakers_expected?: number;
  max_speakers_expected?: number;
}

const HEADROOM = 2;
const HARD_CEILING = 30;

export function capForDuration(durationSec: number | undefined): number {
  if (!durationSec || durationSec <= 0 || durationSec < 120) return 12;
  if (durationSec < 600) return 20;
  return 30;
}

export function assemblySpeakerOptions(
  durationSec: number | undefined,
  hint: SpeakerCountHint | undefined,
  forDubbing: boolean
): AssemblySpeakerOptions | undefined {
  const min = Number(hint?.min);
  const max = Number(hint?.max);
  const hasMin = Number.isInteger(min) && min >= 1;
  const hasMax = Number.isInteger(max) && max >= 1;

  if (hasMin || hasMax) {
    const opts: AssemblySpeakerOptions = {};
    if (hasMin) opts.min_speakers_expected = Math.min(min, HARD_CEILING);
    const floor = opts.min_speakers_expected ?? 1;
    const ceiling = hasMax ? max : floor + HEADROOM;
    opts.max_speakers_expected = Math.min(HARD_CEILING, Math.max(floor, ceiling));
    return opts;
  }

  if (forDubbing) {
    return { max_speakers_expected: capForDuration(durationSec) };
  }
  return undefined;
}
