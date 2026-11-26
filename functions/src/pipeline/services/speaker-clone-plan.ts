/**
 * Per-speaker voice cloning plan (dependency-free, unit-tested). Added 2026-11-24.
 *
 * The standard clone path makes ONE clone from the whole vocal track and only for single-speaker
 * videos (07-dubbing.ts, A5). With DUBBING_CLONE_ALL_SPEAKERS=true and a voice_clone job with
 * consent recorded, each speaker of a multi-speaker video (up to MAX_CLONED_SPEAKERS) gets a clone
 * made only from their own clean lines, so every character speaks the dub in their own voice.
 *
 * A speaker is cloned only with enough clean speech. "Clean" means the line does not overlap any
 * other speaker's line, so the sample never mixes two voices. Speakers without enough clean speech,
 * beyond the speaker limit, or beyond the ElevenLabs plan's free slots / monthly operations keep a
 * matched library voice; each is reported with the reason.
 *
 * Sample lengths follow ElevenLabs' Instant Voice Cloning guidance: at least 10 s in total (their
 * upload minimum), 1–2 minutes recommended, and more than 2–3 minutes gives little improvement.
 * These are ElevenLabs' guidelines, not TruthWorld measurements of clone quality.
 *
 * Strict mode (DUBBING_CLONE_STRICT=true, test use): no speaker may fall back to a library voice.
 * A speaker short of clean speech gets the best sample available instead, in this order:
 *   1. "clean"        — clean lines of at least 1 s (the normal rule);
 *   2. "short_lines"  — also clean lines from 0.3 s;
 *   3. "with_overlap" — also lines that overlap another speaker (the sample may carry that voice);
 *   4. "looped"       — what exists is repeated until it reaches the 10 s minimum (needs ≥ 1 s).
 * Each speaker's sample kind is recorded so a weak clone can be traced to its sample. If any speaker
 * still cannot be cloned (under 1 s of speech, over the speaker limit, or the plan's capacity), no
 * clone is made and the dub fails with the reason, instead of shipping a library voice.
 */

import type { VoiceCapacity } from "./voice-capacity";

export const CLONE_ALL = {
  /** Most speakers cloned in one job. */
  maxSpeakers: 10,
  /** Least clean speech (seconds) a speaker needs to be cloned; ElevenLabs' upload minimum. */
  minSeconds: 10,
  /** Sample cap (seconds); ElevenLabs recommends 1–2 minutes. */
  maxSeconds: 120,
  /** Shortest line used in a sample; shorter fragments are mostly breath and edges. */
  minTurnSeconds: 1.0,
} as const;

export interface CloneTurnLike {
  speaker?: string;
  /** Start / end in seconds. */
  startSec: number;
  endSec: number;
}

export interface CloneTurn {
  startSec: number;
  durationSec: number;
}

export type SpeakerCloneSkipReason =
  | "too_little_clean_speech"
  | "no_usable_speech"
  | "over_speaker_limit"
  | "plan_capacity";

export type CloneSampleKind = "clean" | "short_lines" | "with_overlap" | "looped";

/** Least speech (seconds) a looped sample may be built from in strict mode. */
export const MIN_LOOP_SOURCE_SECONDS = 1;

export interface SpeakerClonePlan {
  /** Speakers to clone, most clean speech first. */
  clone: Array<{ speakerId: string; turns: CloneTurn[]; seconds: number; sample: CloneSampleKind }>;
  skipped: Array<{ speakerId: string; reason: SpeakerCloneSkipReason; seconds: number }>;
}

/** On only when DUBBING_CLONE_ALL_SPEAKERS is "true" (off by default). */
export function cloneAllSpeakersEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_CLONE_ALL_SPEAKERS ?? "").trim().toLowerCase() === "true";
}

/** Strict mode: every speaker must be cloned, or the dub fails (DUBBING_CLONE_STRICT=true). */
export function cloneStrict(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_CLONE_STRICT ?? "").trim().toLowerCase() === "true";
}

/** Speaker limit, DUBBING_CLONE_MAX_SPEAKERS overrides (1–10). */
export function cloneMaxSpeakers(env: Record<string, string | undefined> = process.env): number {
  const raw = Number(env.DUBBING_CLONE_MAX_SPEAKERS);
  if (!Number.isFinite(raw) || raw < 1) return CLONE_ALL.maxSpeakers;
  return Math.min(CLONE_ALL.maxSpeakers, Math.floor(raw));
}

/** Least clean speech per speaker, DUBBING_CLONE_MIN_SECONDS overrides (never below 10 s). */
export function cloneMinSeconds(env: Record<string, string | undefined> = process.env): number {
  const raw = Number(env.DUBBING_CLONE_MIN_SECONDS);
  if (!Number.isFinite(raw)) return CLONE_ALL.minSeconds;
  return Math.min(CLONE_ALL.maxSeconds, Math.max(CLONE_ALL.minSeconds, raw));
}

function overlapsOther(turn: CloneTurnLike, all: CloneTurnLike[], speakerId: string): boolean {
  return all.some(
    (o) => (o.speaker || "speaker_0") !== speakerId && o.startSec < turn.endSec && o.endSec > turn.startSec
  );
}

/**
 * A speaker's clean lines for a clone sample: no overlap with another speaker, at least
 * minTurnSeconds long, longest first up to maxSeconds in total, returned in time order.
 */
export function selectCloneTurns(
  all: CloneTurnLike[],
  speakerId: string,
  maxSeconds: number = CLONE_ALL.maxSeconds,
  rule: { minTurnSeconds?: number; allowOverlap?: boolean } = {}
): { turns: CloneTurn[]; seconds: number } {
  const minTurn = rule.minTurnSeconds ?? CLONE_ALL.minTurnSeconds;
  const clean = all
    .filter((t) => (t.speaker || "speaker_0") === speakerId)
    .filter((t) => t.endSec - t.startSec >= minTurn)
    .filter((t) => rule.allowOverlap || !overlapsOther(t, all, speakerId))
    .sort((a, b) => (b.endSec - b.startSec) - (a.endSec - a.startSec));

  const turns: CloneTurn[] = [];
  let seconds = 0;
  for (const t of clean) {
    if (seconds >= maxSeconds) break;
    const take = Math.min(t.endSec - t.startSec, maxSeconds - seconds);
    if (take < minTurn) break;
    turns.push({ startSec: Number(t.startSec.toFixed(3)), durationSec: Number(take.toFixed(3)) });
    seconds += take;
  }
  turns.sort((a, b) => a.startSec - b.startSec);
  return { turns, seconds: Number(seconds.toFixed(3)) };
}

/**
 * Strict-mode sample: the first rung of the ladder (see the header) that reaches minSeconds; below
 * that, the most speech found, repeated to minSeconds when it is at least MIN_LOOP_SOURCE_SECONDS.
 */
export function selectStrictCloneSample(
  all: CloneTurnLike[],
  speakerId: string,
  minSeconds: number = CLONE_ALL.minSeconds,
  maxSeconds: number = CLONE_ALL.maxSeconds
): { turns: CloneTurn[]; seconds: number; sample: CloneSampleKind } | null {
  const ladder: Array<{ sample: CloneSampleKind; rule: { minTurnSeconds?: number; allowOverlap?: boolean } }> = [
    { sample: "clean", rule: {} },
    { sample: "short_lines", rule: { minTurnSeconds: 0.3 } },
    { sample: "with_overlap", rule: { minTurnSeconds: 0.3, allowOverlap: true } },
  ];
  let best = { turns: [] as CloneTurn[], seconds: 0 };
  for (const step of ladder) {
    const got = selectCloneTurns(all, speakerId, maxSeconds, step.rule);
    if (got.seconds >= minSeconds) return { ...got, sample: step.sample };
    if (got.seconds > best.seconds) best = got;
  }
  if (best.seconds < MIN_LOOP_SOURCE_SECONDS) return null;
  const repeats = Math.ceil(minSeconds / best.seconds);
  const turns: CloneTurn[] = [];
  for (let i = 0; i < repeats; i++) turns.push(...best.turns);
  return { turns, seconds: Number((best.seconds * repeats).toFixed(3)), sample: "looped" };
}

/**
 * Speakers whose assigned voice is not one of this job's clones (strict mode check).
 */
export function unclonedSpeakers(
  speakerIds: string[],
  voiceMapping: Record<string, string>,
  cloneVoiceIds: Iterable<string>
): string[] {
  const clones = new Set(cloneVoiceIds);
  return speakerIds.filter((id) => !clones.has(voiceMapping[id]));
}

/**
 * How many more clones the plan allows right now, or null when the account did not report it.
 * Each clone uses one voice slot and one monthly add/edit operation.
 */
export function remainingCloneCapacity(capacity: VoiceCapacity | null | undefined): number | null {
  if (!capacity) return null;
  if (!capacity.canClone) return 0;
  const limits: number[] = [];
  if (typeof capacity.slotLimit === "number" && typeof capacity.slotsUsed === "number") {
    limits.push(capacity.slotLimit - capacity.slotsUsed);
  }
  if (typeof capacity.editLimit === "number" && typeof capacity.editsUsed === "number") {
    limits.push(capacity.editLimit - capacity.editsUsed);
  }
  return limits.length > 0 ? Math.max(0, Math.min(...limits)) : null;
}

/**
 * Which speakers to clone. Speakers with the most clean speech go first, so when the speaker limit
 * or the plan's capacity runs out, the speakers heard most keep their own voice.
 */
export function planSpeakerClones(
  speakerIds: string[],
  all: CloneTurnLike[],
  opts: { maxSpeakers?: number; minSeconds?: number; maxSeconds?: number; capacityLeft?: number | null; strict?: boolean } = {}
): SpeakerClonePlan {
  const maxSpeakers = opts.maxSpeakers ?? CLONE_ALL.maxSpeakers;
  const minSeconds = opts.minSeconds ?? CLONE_ALL.minSeconds;
  const maxSeconds = opts.maxSeconds ?? CLONE_ALL.maxSeconds;
  const capacityLeft = opts.capacityLeft ?? null;

  const measured = [...new Set(speakerIds)]
    .map((speakerId) => {
      if (opts.strict) {
        const strict = selectStrictCloneSample(all, speakerId, minSeconds, maxSeconds);
        return strict
          ? { speakerId, ...strict, unusable: false }
          : { speakerId, turns: [] as CloneTurn[], seconds: selectCloneTurns(all, speakerId, maxSeconds, { minTurnSeconds: 0.3, allowOverlap: true }).seconds, sample: "clean" as CloneSampleKind, unusable: true };
      }
      return { speakerId, ...selectCloneTurns(all, speakerId, maxSeconds), sample: "clean" as CloneSampleKind, unusable: false };
    })
    .sort((a, b) => b.seconds - a.seconds);

  const plan: SpeakerClonePlan = { clone: [], skipped: [] };
  for (const s of measured) {
    if (s.unusable) {
      plan.skipped.push({ speakerId: s.speakerId, reason: "no_usable_speech", seconds: s.seconds });
    } else if (s.seconds < minSeconds) {
      plan.skipped.push({ speakerId: s.speakerId, reason: "too_little_clean_speech", seconds: s.seconds });
    } else if (plan.clone.length >= maxSpeakers) {
      plan.skipped.push({ speakerId: s.speakerId, reason: "over_speaker_limit", seconds: s.seconds });
    } else if (capacityLeft !== null && plan.clone.length >= capacityLeft) {
      plan.skipped.push({ speakerId: s.speakerId, reason: "plan_capacity", seconds: s.seconds });
    } else {
      plan.clone.push({ speakerId: s.speakerId, turns: s.turns, seconds: s.seconds, sample: s.sample });
    }
  }
  return plan;
}
