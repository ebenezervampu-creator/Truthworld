/**
 * Picks which of a speaker's turns are used to profile their voice (dependency-free, unit-tested).
 *
 * Before: one slice of at most 5 s from the speaker's single longest turn. For a speaker whose
 * longest line is ~2 s that is too little audio, and one unlucky turn (shouting, cross-talk, music
 * swell) decided their voice for the whole video.
 *
 * Now: up to MAX_TURNS of their longest clean turns (no overlap with another speaker when avoidable),
 * each capped at MAX_SECONDS_PER_TURN, up to MAX_TOTAL_SECONDS in all, returned in time order so they
 * can be joined into one profiling clip.
 */

export const MAX_TURNS = 3;
export const MAX_SECONDS_PER_TURN = 4;
export const MAX_TOTAL_SECONDS = 9;
export const MIN_TURN_SECONDS = 0.6;

export interface TurnLike {
  speaker?: string;
  /** Start / end in seconds. */
  startSec: number;
  endSec: number;
}

export interface ProfilingTurn {
  startSec: number;
  durationSec: number;
}

function overlapsOtherSpeaker(turn: TurnLike, all: TurnLike[], speakerId: string): boolean {
  return all.some(
    (o) => (o.speaker || "speaker_0") !== speakerId && o.startSec < turn.endSec && o.endSec > turn.startSec
  );
}

export function selectProfilingTurns(all: TurnLike[], speakerId: string): ProfilingTurn[] {
  const own = all
    .filter((t) => (t.speaker || "speaker_0") === speakerId && t.endSec > t.startSec)
    .map((t) => ({
      turn: t,
      duration: t.endSec - t.startSec,
      clean: !overlapsOtherSpeaker(t, all, speakerId),
    }));
  if (own.length === 0) return [];

  // Prefer clean turns long enough to carry voice, longest first; fall back to whatever exists.
  const ranked = [...own].sort((a, b) => {
    const aOk = a.clean && a.duration >= MIN_TURN_SECONDS ? 1 : 0;
    const bOk = b.clean && b.duration >= MIN_TURN_SECONDS ? 1 : 0;
    return bOk - aOk || b.duration - a.duration;
  });

  const picked: ProfilingTurn[] = [];
  let total = 0;
  for (const { turn, duration } of ranked) {
    if (picked.length >= MAX_TURNS || total >= MAX_TOTAL_SECONDS) break;
    const take = Math.min(duration, MAX_SECONDS_PER_TURN, MAX_TOTAL_SECONDS - total);
    if (take < 0.3) continue;
    picked.push({ startSec: Number(turn.startSec.toFixed(3)), durationSec: Number(take.toFixed(3)) });
    total += take;
  }
  return picked.sort((a, b) => a.startSec - b.startSec);
}

// ── Pitch clip (2026-11-24) ────────────────────────────────────────────────────────────────────────
// Gender came out wrong when the 3 longest turns were breathy or shouted: no voiced frames, so no pitch.
// Pitch is now measured over all of a speaker's turns, up to PITCH_MAX_TOTAL_SECONDS (the decoder reads
// at most 30 s), clean turns first, in time order.

export const PITCH_MAX_TOTAL_SECONDS = 30;
export const PITCH_MAX_SECONDS_PER_TURN = 8;
export const PITCH_MIN_TURN_SECONDS = 0.3;

export function selectPitchTurns(all: TurnLike[], speakerId: string): ProfilingTurn[] {
  const own = all.filter((t) => (t.speaker || "speaker_0") === speakerId && t.endSec - t.startSec >= PITCH_MIN_TURN_SECONDS);
  if (own.length === 0) return [];
  const clean = own.filter((t) => !overlapsOtherSpeaker(t, all, speakerId));
  const pool = clean.length > 0 ? clean : own;
  const picked: ProfilingTurn[] = [];
  let total = 0;
  for (const t of [...pool].sort((a, b) => a.startSec - b.startSec)) {
    if (total >= PITCH_MAX_TOTAL_SECONDS) break;
    const take = Math.min(t.endSec - t.startSec, PITCH_MAX_SECONDS_PER_TURN, PITCH_MAX_TOTAL_SECONDS - total);
    if (take < PITCH_MIN_TURN_SECONDS) continue;
    picked.push({ startSec: Number(t.startSec.toFixed(3)), durationSec: Number(take.toFixed(3)) });
    total += take;
  }
  return picked;
}

/** "01:02.4" for 62.4 s. */
function clock(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec - m * 60;
  return `${String(m).padStart(2, "0")}:${s.toFixed(1).padStart(4, "0")}`;
}

/**
 * Time ranges where one speaker talks, as text for a Gemini prompt that receives the whole recording
 * ("00:02.4–00:07.8, 00:12.9–00:15.1"). Without them Gemini cannot tell which voice in a multi-speaker
 * recording it is meant to describe. Times are taken as milliseconds when any turn ends after 1000.
 */
export function describeSpeakerTurns(
  all: Array<{ speaker?: string; start: number; end: number }>,
  speakerId: string,
  maxRanges = 8
): string {
  const inMs = all.some((t) => t.end > 1000);
  const toSec = (v: number) => (inMs ? v / 1000 : v);
  return all
    .filter((t) => (t.speaker || "speaker_0") === speakerId && t.end > t.start)
    .slice(0, maxRanges)
    .map((t) => `${clock(toSec(t.start))}–${clock(toSec(t.end))}`)
    .join(", ");
}
