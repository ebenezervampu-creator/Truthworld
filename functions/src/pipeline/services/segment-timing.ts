/**
 * Word-anchored timing for dubbed lines (2026-11-24).
 *
 * A long utterance (> 8 s or > 140 chars) is split into sentences for dubbing. Each sentence used to be
 * timed by its share of the utterance's characters. With a pause inside the utterance (a scene cut, a
 * long beat) that put later sentences seconds early: in the 60 s Telugu test, "Are you Steve Rogers?"
 * played 6.6 s before it is spoken and "Years ago, we did what was needed" 8.6 s early.
 * Sentences are now timed from their own words; the character share is kept only when no word timings
 * exist.
 */

export interface WordTiming {
  text: string;
  start: number;
  end: number;
  confidence?: number;
}

export interface Span {
  start: number;
  end: number;
}

/** Whether a transcript already carries word timings on its utterances. */
export function hasUtteranceWordTimings(utterances: Array<{ words?: unknown[]; timingWords?: unknown[] }> | undefined): boolean {
  return (
    Array.isArray(utterances) &&
    utterances.some((u) => (Array.isArray(u.words) && u.words.length > 0) || (Array.isArray(u.timingWords) && u.timingWords.length > 0))
  );
}

/** Every word timing in a stored transcript result: top-level `words`, else the segments'/utterances' words. */
export function collectWordTimings(parsed: any): WordTiming[] {
  const ok = (w: any) => w && typeof w.start === "number" && typeof w.end === "number" && w.end >= w.start && typeof w.text === "string";
  if (Array.isArray(parsed?.words) && parsed.words.some(ok)) return parsed.words.filter(ok);
  const lists = [parsed?.segments, parsed?.utterances].filter(Array.isArray) as any[][];
  for (const list of lists) {
    const words = list.flatMap((s) => (Array.isArray(s?.words) ? s.words : [])).filter(ok);
    if (words.length > 0) return words.sort((a, b) => a.start - b.start);
  }
  return [];
}

/**
 * Gives each utterance, as `timingWords`, the words whose midpoint falls inside it (±toleranceMs at
 * its edges). Only the line splitter reads `timingWords`; `words` is left as it was, so subtitles and
 * everything else that reads `words` behave exactly as before. Utterances that already have words
 * keep them. Returns new objects; the input is not changed.
 */
export function attachWordsToUtterances<U extends Span & { words?: WordTiming[]; timingWords?: WordTiming[] }>(
  utterances: U[],
  words: WordTiming[],
  toleranceMs = 200
): U[] {
  return utterances.map((u) => {
    if (Array.isArray(u.words) && u.words.length > 0) return u;
    const own = words
      .filter((w) => {
        const mid = (w.start + w.end) / 2;
        return mid >= u.start - toleranceMs && mid <= u.end + toleranceMs;
      })
      .map((w) => ({ text: w.text, start: w.start, end: w.end, confidence: typeof w.confidence === "number" ? w.confidence : 1 }));
    return { ...u, timingWords: own };
  });
}

function normToken(t: string): string {
  return t.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");
}

function tokens(text: string): string[] {
  return text.trim().split(/\s+/).map(normToken).filter(Boolean);
}

/** How far (in words) a sentence edge may sit from where counting alone puts it. */
const ALIGN_LOOKAROUND = 8;

/**
 * Times each chunk of an utterance from its own words. Each chunk's first and last words are found
 * by their text, near where counting puts them (±8 words), so a word missing from or added to the
 * word list (fillers, contractions, ASR text cleanup) does not shift every later sentence. Returns
 * null when the words cannot carry the chunks (too few words, or the counts differ by more than
 * 25 %), so the caller can fall back to the character share.
 */
export function chunkTimesFromWords(chunks: string[], words: WordTiming[]): Span[] | null {
  const sorted = [...words].filter((w) => w.end >= w.start).sort((a, b) => a.start - b.start);
  const wn = sorted.map((w) => normToken(w.text));
  const chunkTokens = chunks.map(tokens);
  const total = chunkTokens.reduce((a, t) => a + t.length, 0);
  if (sorted.length < 2 || chunks.length === 0 || total === 0) return null;
  if (Math.abs(sorted.length - total) > Math.max(1, total * 0.25)) return null;

  const findNear = (token: string, expected: number, lo: number, hi: number): number => {
    let best = -1;
    for (let i = Math.max(lo, expected - ALIGN_LOOKAROUND); i <= Math.min(hi, expected + ALIGN_LOOKAROUND); i++) {
      if (wn[i] === token && (best < 0 || Math.abs(i - expected) < Math.abs(best - expected))) best = i;
    }
    return best;
  };

  const spans: Span[] = [];
  let cursor = 0;
  let expectedStart = 0;
  for (let c = 0; c < chunks.length; c++) {
    const toks = chunkTokens[c];
    const isLast = c === chunks.length - 1;
    const remainingChunks = chunks.length - 1 - c;
    const hi = sorted.length - 1 - remainingChunks;
    if (cursor > hi) return null;
    const n = Math.max(1, toks.length);
    // The first chunk must start at sorted[0] so leading words of an utterance are never orphaned.
    let first = c === 0 ? 0 : (toks.length > 0 ? findNear(toks[0], Math.max(cursor, expectedStart), cursor, hi) : -1);
    if (first < 0) first = Math.min(Math.max(cursor, expectedStart), hi);
    let last: number;
    if (isLast) {
      last = sorted.length - 1;
    } else {
      const expectedLast = first + n - 1;
      last = toks.length > 0 ? findNear(toks[toks.length - 1], expectedLast, first, hi) : -1;
      if (last < 0) last = Math.min(Math.max(first, expectedLast), hi);
    }
    spans.push({ start: sorted[first].start, end: Math.max(sorted[first].start + 1, sorted[last].end) });
    cursor = last + 1;
    expectedStart = cursor;
  }
  return spans;
}
