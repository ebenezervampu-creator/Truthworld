/**
 * When two transcript lines are joined before translation (07-dubbing.ts stitchSegments).
 *
 * A line is joined with the next one only if it is very short or ends on a connecting word, the same
 * person says both, and the pause between them is short. Audit A8 (2026-11-21): the old check had no
 * word boundary ("also", "into", "breathe" matched "so", "to", "the"; any Hindi line ending in है
 * matched) and no pause limit, so lines were merged across long pauses and the timing drifted.
 */

/** Longest pause (ms) across which two lines of the same speaker may still be joined. */
export const MAX_STITCH_GAP_MS = 400;
/** Lines shorter than this many characters are joined with the next one (same speaker, short pause). */
export const MIN_STANDALONE_CHARS = 15;

// Whole words only. Devanagari has no \b in JS regexes, so a space (or line start) marks the boundary.
const ENGLISH_CONNECTOR_END = /\b(?:and|the|so|but|or|to|for|with)$/i;
const HINDI_CONNECTOR_END = /(?:^|\s)(?:तो|और|कि|है)$/;

export function endsOnConnector(text: string): boolean {
  const t = String(text || "").trim().replace(/[,;:–—-]+$/, "").trim();
  return ENGLISH_CONNECTOR_END.test(t) || HINDI_CONNECTOR_END.test(t);
}

export interface StitchLine {
  text: string;
  start: number;
  end: number;
  speaker?: string;
}

/** Whether `current` should be joined with `next` (times in ms). */
export function shouldStitch(current: StitchLine, next: StitchLine, maxGapMs: number = MAX_STITCH_GAP_MS): boolean {
  if ((current.speaker || "speaker_0") !== (next.speaker || "speaker_0")) return false;
  const gap = Number(next.start) - Number(current.end);
  if (!(gap <= maxGapMs)) return false;
  return String(current.text || "").trim().length < MIN_STANDALONE_CHARS || endsOnConnector(current.text);
}
