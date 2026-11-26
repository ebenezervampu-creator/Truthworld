/**
 * Word timings for the long-form reel assembler (2026-11-25).
 *
 * dispatchLongFormReels stores them in reel_orchestration/meta so assembleDubbingReels' word-aware
 * steps (the dub speech check, tight stem, bed match) have them. Before this, the assembler read
 * meta.words, which was never written, so long films ran those steps without word timings.
 */

/** Max word timings kept for the reel assembler (reel_orchestration/meta.wordSpans). */
export const MAX_META_WORDS = 40000;

/** Word timings (ms) → flat [start, end, …] integers, or [] when absent; capped at MAX_META_WORDS. */
export function encodeWordSpans(words: Array<{ start?: number; end?: number }> | undefined | null): number[] {
  const out: number[] = [];
  for (const w of words || []) {
    const a = Math.round(Number(w?.start));
    const b = Math.round(Number(w?.end));
    if (!Number.isFinite(a) || !Number.isFinite(b) || b <= a) continue;
    out.push(a, b);
    if (out.length >= MAX_META_WORDS * 2) break;
  }
  return out;
}

/** reel_orchestration/meta → word timings: wordSpans (flat) first, else an older `words` list. */
export function decodeWordSpans(meta: { wordSpans?: unknown; words?: unknown } | null | undefined): Array<{ start: number; end: number }> {
  const flat = Array.isArray(meta?.wordSpans) ? (meta!.wordSpans as unknown[]) : [];
  const out: Array<{ start: number; end: number }> = [];
  for (let i = 0; i + 1 < flat.length; i += 2) {
    const a = Number(flat[i]);
    const b = Number(flat[i + 1]);
    if (Number.isFinite(a) && Number.isFinite(b) && b > a) out.push({ start: a, end: b });
  }
  if (out.length > 0) return out;
  const list = Array.isArray(meta?.words) ? (meta!.words as Array<{ start?: number; end?: number }>) : [];
  return list
    .map((w) => ({ start: Number(w?.start) || 0, end: Number(w?.end) || 0 }))
    .filter((w) => w.end > w.start);
}

