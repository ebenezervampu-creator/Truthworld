/**
 * Per-language voice assignment (dependency-free, unit-tested).
 *
 * Speakers are profiled once per job and get a base voice from the multilingual presets
 * (voice-matcher.ts). For each target language, this picks native voices from the curated Voice
 * Library catalog (registry/library_voice_catalog.json) first:
 *   - unique within that language's track (each viewer hears one track at a time, so the same
 *     voice may appear in another language's track — exclusivity per language is not needed),
 *   - same gender, nearest in age/timbre by the matcher's own distance score,
 *   - speakers who talk most are served first, so main characters get native voices.
 * When a language has too few native voices, the remaining speakers keep their base preset voice —
 * eleven_v4 voices speak every supported language, so this is a quality fallback, not a failure.
 * Speakers locked to a creator's own voice clone are never changed.
 */

export interface AssignmentSpeaker {
  speakerId: string;
  gender: "male" | "female" | "neutral";
  /** Voice from the job-wide (multilingual) assignment. */
  baseVoiceId: string;
  /** Creator voice clone or another voice that must not change. */
  locked?: boolean;
}

export interface NativeVoice {
  voiceId: string;
  gender: "male" | "female" | "neutral";
}

export interface LanguageAssignment {
  /** speakerId → voice to use in this language. */
  mapping: Record<string, string>;
  /** native voiceId → base voice to fall back to if the library voice becomes unavailable. */
  fallbacks: Record<string, string>;
  /** Speakers who got a native library voice. */
  nativeSpeakers: string[];
}

export function assignLanguageVoices<V extends NativeVoice>(
  speakers: AssignmentSpeaker[],
  nativeVoices: V[],
  distance: (speaker: AssignmentSpeaker, voice: V) => number
): LanguageAssignment {
  const mapping: Record<string, string> = {};
  const fallbacks: Record<string, string> = {};
  const nativeSpeakers: string[] = [];
  const used = new Set<string>();
  // Base voices of speakers who keep them must not be handed out again in this language.
  const reservedBase = new Set(speakers.map((s) => s.baseVoiceId));

  for (const speaker of speakers) {
    if (speaker.locked) {
      mapping[speaker.speakerId] = speaker.baseVoiceId;
      used.add(speaker.baseVoiceId);
      continue;
    }
    const pool = nativeVoices.filter(
      (v) => !used.has(v.voiceId) && !reservedBase.has(v.voiceId) && (speaker.gender === "neutral" || v.gender === speaker.gender)
    );
    if (pool.length === 0) {
      mapping[speaker.speakerId] = speaker.baseVoiceId;
      used.add(speaker.baseVoiceId);
      continue;
    }
    let best = pool[0];
    let bestDistance = Number.POSITIVE_INFINITY;
    for (const v of pool) {
      const d = distance(speaker, v);
      if (d < bestDistance) {
        bestDistance = d;
        best = v;
      }
    }
    mapping[speaker.speakerId] = best.voiceId;
    fallbacks[best.voiceId] = speaker.baseVoiceId;
    used.add(best.voiceId);
    nativeSpeakers.push(speaker.speakerId);
  }
  return { mapping, fallbacks, nativeSpeakers };
}

// ─── Strict native-voice assignment ───────────────────────────────────────────

export interface NativeCandidate extends NativeVoice {
  /** 2 = this language, 1 = same region (Indian voice for another Indic language). Foreign voices are not passed in. */
  tier: 1 | 2;
  /** From the curated Voice Library catalog (may be withdrawn by its owner). */
  fromLibrary?: boolean;
}

export interface SpeakerTurn {
  speaker: string;
  start: number;
  end: number;
}

export interface NativeAssignment extends LanguageAssignment {
  /** Speakers with no native voice of their gender — the language must not be dubbed. */
  unresolvedSpeakers: string[];
  /** Speakers sharing a native voice with someone far away in the video. */
  reusedSpeakers: string[];
  /** speakerId → match distance of the chosen voice (lower = closer to the original voice). */
  matchDistance: Record<string, number>;
}

/**
 * How much closer (in match distance) an Indian voice of another Indic language must be before it
 * beats a voice of exactly the target language. Small on purpose: sounding like the original
 * speaker matters more than the voice's home language, as long as both are native to the region.
 */
export const EXACT_LANGUAGE_PREFERENCE = 0.05;

/** Total speaking time per speaker, ms-agnostic (same unit as the turns). */
function talkTime(turns: SpeakerTurn[]): Map<string, number> {
  const out = new Map<string, number>();
  for (const t of turns) out.set(t.speaker, (out.get(t.speaker) || 0) + Math.max(0, t.end - t.start));
  return out;
}

function closestApproachMs(a: SpeakerTurn[], b: SpeakerTurn[]): number {
  let best = Number.POSITIVE_INFINITY;
  for (const x of a) {
    for (const y of b) {
      const gap = x.end <= y.start ? y.start - x.end : y.end <= x.start ? x.start - y.end : 0;
      if (gap < best) best = gap;
    }
  }
  return best;
}

/**
 * Every non-locked speaker gets a native voice of their gender, or is reported as unresolved.
 * Speakers who talk most choose first, so main characters get the closest voices.
 *   1. the unused native voice that sounds closest to the original speaker (measured pitch, age,
 *      timbre); a voice of exactly this language wins near-ties (EXACT_LANGUAGE_PREFERENCE);
 *   2. when those run out, a native voice already used in this language by someone who speaks
 *      furthest away in time (never by someone talking at the same moment);
 *   3. otherwise unresolved — no foreign fallback.
 * Library voices get a fallback to the best native non-library voice of the same gender, if any,
 * so a withdrawn voice never turns into a foreign one.
 */
export function assignNativeVoices<V extends NativeCandidate>(
  speakers: AssignmentSpeaker[],
  candidates: V[],
  distance: (speaker: AssignmentSpeaker, voice: V) => number,
  turns: SpeakerTurn[] = []
): NativeAssignment {
  const mapping: Record<string, string> = {};
  const fallbacks: Record<string, string> = {};
  const nativeSpeakers: string[] = [];
  const unresolvedSpeakers: string[] = [];
  const reusedSpeakers: string[] = [];
  const matchDistance: Record<string, number> = {};
  const owners = new Map<string, string[]>();
  const turnsOf = (ids: string[]) => turns.filter((t) => ids.includes(t.speaker));
  const fits = (spk: AssignmentSpeaker, v: V) => spk.gender === "neutral" || v.gender === spk.gender;
  const effective = (spk: AssignmentSpeaker, v: V) => distance(spk, v) - (v.tier === 2 ? EXACT_LANGUAGE_PREFERENCE : 0);
  const rank = (spk: AssignmentSpeaker) => (a: V, b: V) => effective(spk, a) - effective(spk, b) || b.tier - a.tier;
  const spoken = talkTime(turns);
  const order = speakers
    .map((s, i) => ({ s, i }))
    .sort((a, b) => (spoken.get(b.s.speakerId) || 0) - (spoken.get(a.s.speakerId) || 0) || a.i - b.i)
    .map((x) => x.s);

  for (const spk of order) {
    if (spk.locked) {
      mapping[spk.speakerId] = spk.baseVoiceId;
      owners.set(spk.baseVoiceId, [...(owners.get(spk.baseVoiceId) || []), spk.speakerId]);
      continue;
    }
    const sameGender = candidates.filter((v) => fits(spk, v));
    if (sameGender.length === 0) {
      unresolvedSpeakers.push(spk.speakerId);
      continue;
    }
    let chosen = sameGender.filter((v) => !owners.has(v.voiceId)).sort(rank(spk))[0];
    if (!chosen) {
      const own = turnsOf([spk.speakerId]);
      const scored = sameGender
        .map((v) => ({ v, gap: own.length ? closestApproachMs(own, turnsOf(owners.get(v.voiceId) || [])) : Number.POSITIVE_INFINITY }))
        .filter((x) => x.gap > 0)
        .sort((a, b) => b.gap - a.gap || effective(spk, a.v) - effective(spk, b.v));
      if (scored.length === 0) {
        unresolvedSpeakers.push(spk.speakerId);
        continue;
      }
      chosen = scored[0].v;
      reusedSpeakers.push(spk.speakerId);
    }
    mapping[spk.speakerId] = chosen.voiceId;
    matchDistance[spk.speakerId] = Math.round(distance(spk, chosen) * 1000) / 1000;
    owners.set(chosen.voiceId, [...(owners.get(chosen.voiceId) || []), spk.speakerId]);
    nativeSpeakers.push(spk.speakerId);
    if (chosen.fromLibrary) {
      const backup = sameGender.filter((v) => !v.fromLibrary && v.voiceId !== chosen!.voiceId).sort(rank(spk))[0];
      if (backup) fallbacks[chosen.voiceId] = backup.voiceId;
    }
  }
  return { mapping, fallbacks, nativeSpeakers, unresolvedSpeakers, reusedSpeakers, matchDistance };
}
