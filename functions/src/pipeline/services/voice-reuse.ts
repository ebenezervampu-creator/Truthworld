/**
 * Voice reuse when a video has more speakers than distinct voices (dependency-free, unit-tested).
 *
 * The voice catalog has a few dozen voices per gender. On crowded videos (20–30 speakers, or a
 * skewed gender split) the matcher used to wrap around and hand out whichever voice was nearest in
 * timbre — possibly the voice of someone in the same scene, so two people in one conversation
 * sounded identical.
 *
 * Now, once a gender's unique voices are used up, only the voices whose current owners speak
 * furthest away in time from the new speaker are allowed. Speakers are assigned in order of how
 * much they talk, so main characters keep unique voices and only minor ones share.
 */

export interface SpeakerSpan {
  speaker: string;
  start: number;
  end: number;
}

export interface ReuseCandidate {
  voiceId: string;
  owners: string[];
  /** Smallest gap between any turn of the new speaker and any turn of the voice's owners (ms). 0 = same moment. */
  minGapMs: number;
}

/** How many of the best-separated voices the matcher may choose between (it then picks by timbre). */
export const REUSE_SHORTLIST = 3;

function gapBetween(a: SpeakerSpan, b: SpeakerSpan): number {
  if (a.end <= b.start) return b.start - a.end;
  if (b.end <= a.start) return a.start - b.end;
  return 0; // overlapping
}

export function minGapMs(aTurns: SpeakerSpan[], bTurns: SpeakerSpan[]): number {
  let best = Number.POSITIVE_INFINITY;
  for (const a of aTurns) {
    for (const b of bTurns) {
      const g = gapBetween(a, b);
      if (g < best) best = g;
      if (best === 0) return 0;
    }
  }
  return best;
}

/**
 * Ranks voices that may be reused for `speakerId`, best-separated first.
 * `voiceOwners` maps each already-assigned voice to the speakers using it; only `candidateVoiceIds`
 * (e.g. the same gender) are considered.
 */
export function rankReusableVoices(
  speakerId: string,
  turns: SpeakerSpan[],
  voiceOwners: Map<string, string[]>,
  candidateVoiceIds: string[]
): ReuseCandidate[] {
  const own = turns.filter((t) => t.speaker === speakerId);
  const ranked: ReuseCandidate[] = [];
  for (const voiceId of candidateVoiceIds) {
    const owners = voiceOwners.get(voiceId) || [];
    if (owners.length === 0 || owners.includes(speakerId)) continue;
    const ownerTurns = turns.filter((t) => owners.includes(t.speaker));
    const gap = own.length && ownerTurns.length ? minGapMs(own, ownerTurns) : Number.POSITIVE_INFINITY;
    ranked.push({ voiceId, owners, minGapMs: gap });
  }
  return ranked.sort((a, b) => b.minGapMs - a.minGapMs || a.owners.length - b.owners.length || a.voiceId.localeCompare(b.voiceId));
}
