/**
 * Netflix-style subtitle conformer.
 *
 * Takes timed subtitle cues and FIXES them to the Netflix Timed Text Style Guide general
 * requirements instead of only reporting violations:
 *   - 5/6 s (or the language's own) minimum and 7 s maximum per subtitle
 *   - reading speed (characters per second) and characters per line per language
 *   - 2 lines maximum, broken at natural phrase boundaries (never after "the", "of", ...)
 *   - 2-frame minimum gap between subtitles, no overlaps
 *   - two speakers in one subtitle marked with hyphens, one speaker per line
 *   - song lyrics in italics (or plain where the language guide says so)
 *
 * Pure functions, no I/O. Text condensation (when a subtitle is still too fast to read after
 * all timing fixes) is done by the caller with Gemini; see multilingual_subtitle_localizer.ts.
 */

import { LocalizedSubtitleCue } from "./subtitle_readability_validator";
import {
  SubtitleLanguageProfile,
  getGraphemeCount,
  getReadableCharCount,
  calculateMinInterCueGapMs,
} from "./subtitle_language_profiles";

export interface TimeInterval {
  startMs: number;
  endMs: number;
}

export interface ConformOptions {
  profile: SubtitleLanguageProfile;
  /** Video frame rate, for the 2-frame gap. Defaults to 30. */
  fps?: number;
  /** Time ranges where a song is being sung. Cues inside them are styled as lyrics. */
  songIntervalsMs?: TimeInterval[];
  /** How far a subtitle may start before its speech to reach the minimum duration. Default 250 ms. */
  maxEarlyStartMs?: number;
  /** Two cues closer than this may be merged into one subtitle. Default 1000 ms. */
  mergeGapMs?: number;
  /** Video shot change timestamps in milliseconds from start of video. */
  shotChangesMs?: number[];
}

export type ConformRule = "min_duration" | "max_duration" | "reading_speed" | "line_length" | "line_count" | "overlap" | "shot_change";

export interface ConformIssue {
  cueId: number;
  rule: ConformRule;
  detail: string;
}

export interface ConformReport {
  merged: number;
  dualSpeaker: number;
  split: number;
  extended: number;
  trimmed: number;
  lyrics: number;
  shotSnaps: number;
  /** Rules still broken after every automatic fix. Usually reading speed, fixed next by condensation. */
  unresolved: ConformIssue[];
}

interface WorkCue {
  startMs: number;
  endMs: number;
  text: string;
  speaker?: string;
  dual?: [string, string];
  isLyric: boolean;
  sourceWordStartIndex: number;
  sourceWordEndIndex: number;
  alignmentConfidence: number;
  languageCode: string;
}

// ─── Text helpers ────────────────────────────────────────────────────────────

/** Removes formatting tags and line breaks, collapses whitespace. */
export function plainText(text: string): string {
  return (text || "")
    .replace(/<\/?i>/gi, "")
    .replace(/\{\\an\d\}/g, "")
    .replace(/\s*\n\s*/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

const PUNCT_END = /[,;:.!?।॥。，、！？—–]$/u;
const UNIT_START = /^(%|percent|km|kg|cm|mm|m\b|USD|INR|EUR|GBP|\$|₹|€|£|crore|lakh|million|billion|thousand|శాతం|प्रतिशत|करोड़|लाख|కోట్లు|లక్షలు)/iu;
const TITLE_WORD = /^(Mr|Mrs|Ms|Dr|Prof|St|Sr|Sra|Srta|Dra)\.$/i;

function wordsOf(text: string): string[] {
  return plainText(text).split(" ").filter(Boolean);
}

function graphemes(text: string): string[] {
  if (typeof Intl !== "undefined" && (Intl as any).Segmenter) {
    const seg = new (Intl as any).Segmenter(undefined, { granularity: "grapheme" });
    return Array.from(seg.segment(text), (s: any) => s.segment as string);
  }
  return Array.from(text);
}

/** Cost of ending a line (or a subtitle) after words[k-1], before words[k]. Lower is better. */
function boundaryCost(words: string[], k: number, profile: SubtitleLanguageProfile): number {
  const last = words[k - 1];
  const next = words[k];
  const weak = new Set((profile.weakLineEndWords || []).map((w) => w.toLowerCase()));
  let cost = 0;
  if (PUNCT_END.test(last)) cost -= 12;
  if (weak.has(last.toLowerCase())) cost += 25;
  if (/^[\d.,]+$/.test(last) && next && UNIT_START.test(next)) cost += 40; // keep "12 %" / "5 crore" together
  if (TITLE_WORD.test(last)) cost += 40;                                   // keep "Dr. Rao" together
  return cost;
}

/**
 * Segments unspaced or continuous text (Japanese, Thai, Chinese) into word/semantic units
 * using Intl.Segmenter with granularity: "word". Prevents breaking mid-word or mid-grapheme cluster.
 */
function wordSegmentsOf(text: string, langCode: string): string[] {
  if (typeof Intl !== "undefined" && (Intl as any).Segmenter) {
    try {
      const seg = new (Intl as any).Segmenter(langCode || "ja", { granularity: "word" });
      const segs: string[] = [];
      for (const item of seg.segment(text)) {
        if (item.segment) segs.push(item.segment);
      }
      if (segs.length > 0) return segs;
    } catch {
      // Fallback below
    }
  }
  return graphemes(text);
}

/** Splits unspaced text (Chinese, Japanese, Thai) into two parts within `max` characters, respecting word boundaries. */
function breakUnspaced(text: string, max: number, langCode: string = "ja"): [string, string] | null {
  const totalChars = getGraphemeCount(text);
  if (totalChars > max * 2) return null;

  // 1. Try word-boundary splitting using Intl.Segmenter (crucial for Thai, Japanese, Chinese)
  const segments = wordSegmentsOf(text, langCode);
  if (segments.length > 1) {
    let best: [string, string] | null = null;
    let bestScore = Infinity;

    for (let k = 1; k < segments.length; k++) {
      const a = segments.slice(0, k).join("");
      const b = segments.slice(k).join("");
      const na = getGraphemeCount(a);
      const nb = getGraphemeCount(b);
      if (na > max || nb > max) continue;

      let score = Math.abs(na - nb);
      if (na > nb) score += 3; // prefer bottom-heavy
      if (PUNCT_END.test(a)) score -= 15; // prioritize natural clause/punctuation break
      if (score < bestScore) {
        bestScore = score;
        best = [a, b];
      }
    }
    if (best) return best;
  }

  // 2. Grapheme-level fallback if word segmentation doesn't fit within max limits
  const g = graphemes(text);
  let bestG: [string, string] | null = null;
  let bestCost = Infinity;
  for (let k = Math.max(1, g.length - max); k <= Math.min(max, g.length - 1); k++) {
    const a = g.slice(0, k).join("");
    const b = g.slice(k).join("");
    let cost = Math.abs(a.length - b.length);
    if (PUNCT_END.test(a)) cost -= 12;
    if (cost < bestCost) {
      bestCost = cost;
      bestG = [a, b];
    }
  }
  return bestG;
}

/**
 * Breaks a subtitle into at most 2 lines that each fit the language's characters-per-line
 * limit, at the most natural phrase boundary. Prefers a slightly longer bottom line
 * ("bottom-heavy pyramid"). Returns null when the text cannot fit in 2 lines.
 */
export function breakLines(text: string, profile: SubtitleLanguageProfile): string[] | null {
  const t = plainText(text);
  const max = profile.maxCharactersPerLine;
  if (getGraphemeCount(t) <= max) return [t];
  if (profile.maxLines < 2) return null;

  const words = wordsOf(t);
  if (words.length < 2) {
    const pair = breakUnspaced(t, max, profile.languageCode);
    return pair ? [pair[0], pair[1]] : null;
  }

  let best: string[] | null = null;
  let bestScore = Infinity;
  for (let k = 1; k < words.length; k++) {
    const l1 = words.slice(0, k).join(" ");
    const l2 = words.slice(k).join(" ");
    const n1 = getGraphemeCount(l1);
    const n2 = getGraphemeCount(l2);
    if (n1 > max || n2 > max) continue;
    let score = Math.abs(n1 - n2) + boundaryCost(words, k, profile);
    if (n1 > n2) score += 4; // prefer bottom-heavy
    if (score < bestScore) {
      bestScore = score;
      best = [l1, l2];
    }
  }
  return best;
}

/** Splits text into two subtitles at the best boundary near the middle. */
export function splitTextInTwo(text: string, profile: SubtitleLanguageProfile): [string, string] | null {
  const t = plainText(text);
  const words = wordsOf(t);
  if (words.length < 2) {
    const segments = wordSegmentsOf(t, profile.languageCode);
    if (segments.length >= 2) {
      const total = getGraphemeCount(t);
      let bestK = Math.ceil(segments.length / 2);
      let bestCost = Infinity;
      for (let k = 1; k < segments.length; k++) {
        const left = getGraphemeCount(segments.slice(0, k).join(""));
        const right = total - left;
        let cost = Math.abs(left - right);
        if (PUNCT_END.test(segments[k - 1])) cost -= 10;
        if (cost < bestCost) {
          bestCost = cost;
          bestK = k;
        }
      }
      return [segments.slice(0, bestK).join(""), segments.slice(bestK).join("")];
    }
    const g = graphemes(t);
    if (g.length < 2) return null;
    const mid = Math.floor(g.length / 2);
    let k = mid;
    for (let d = 0; d < Math.floor(g.length / 3); d++) {
      if (PUNCT_END.test(g[mid + d - 1] || "")) { k = mid + d; break; }
      if (PUNCT_END.test(g[mid - d - 1] || "")) { k = mid - d; break; }
    }
    return [g.slice(0, k).join(""), g.slice(k).join("")];
  }
  if (words.length < 2) {
    const g = graphemes(t);
    if (g.length < 2) return null;
    const mid = Math.floor(g.length / 2);
    let k = mid;
    for (let d = 0; d < Math.floor(g.length / 3); d++) {
      if (PUNCT_END.test(g[mid + d - 1] || "")) { k = mid + d; break; }
      if (PUNCT_END.test(g[mid - d - 1] || "")) { k = mid - d; break; }
    }
    return [g.slice(0, k).join(""), g.slice(k).join("")];
  }
  const total = getGraphemeCount(t);
  let bestK = Math.ceil(words.length / 2);
  let bestCost = Infinity;
  for (let k = 1; k < words.length; k++) {
    const left = getGraphemeCount(words.slice(0, k).join(" "));
    const balance = Math.abs(left - (total - left)) / Math.max(1, total); // 0 = perfectly balanced
    const cost = balance * 60 + boundaryCost(words, k, profile);
    if (cost < bestCost) {
      bestCost = cost;
      bestK = k;
    }
  }
  return [words.slice(0, bestK).join(" "), words.slice(bestK).join(" ")];
}

/** Formats two speakers' lines with the language's hyphen convention. */
export function formatDualSpeaker(a: string, b: string, profile: SubtitleLanguageProfile): [string, string] {
  const clean = (s: string) => plainText(s).replace(/^[-–—]\s*/, "");
  switch (profile.dualSpeakerStyle) {
    case "dash_space":
      return [`- ${clean(a)}`, `- ${clean(b)}`];
    case "dash_second_only":
      return [clean(a), `-${clean(b)}`];
    default:
      return [`-${clean(a)}`, `-${clean(b)}`];
  }
}

// ─── Keeping subtitles on their speech ─────────────────────────────────────

export interface SpeechWindow {
  /** Source word index the window's cues carry in `sourceWordStartIndex`. */
  key: number;
  startMs: number;
  endMs: number;
}

/**
 * Re-anchors each sentence's subtitles inside that sentence's speech window, so a long or fast
 * sentence can never push every later subtitle out of sync. A window runs from the sentence's
 * first word to just before the next sentence (at most 1.4 s into the silence after it). Cues
 * that already fit are left alone; overflowing groups are re-spread by text length, and any
 * reading-speed problem that creates is then fixed by merging, extending or condensing.
 */
export function anchorCuesToSpeech(
  cues: LocalizedSubtitleCue[],
  windows: SpeechWindow[],
  gapMs: number
): LocalizedSubtitleCue[] {
  const sorted = [...windows].sort((a, b) => a.startMs - b.startMs);
  const out: LocalizedSubtitleCue[] = [];
  for (let w = 0; w < sorted.length; w++) {
    const win = sorted[w];
    const next = sorted[w + 1];
    const winEnd = next
      ? Math.max(win.endMs, Math.min(next.startMs - gapMs, win.endMs + 1400))
      : win.endMs + 1400;
    const group = cues.filter((c) => c.sourceWordStartIndex === win.key).sort((a, b) => a.startMs - b.startMs);
    if (group.length === 0) continue;
    const fits = group[0].startMs >= win.startMs - 1 && group[group.length - 1].endMs <= winEnd + 1;
    if (fits) {
      out.push(...group);
      continue;
    }
    const weights = group.map((c) => Math.max(1, getReadableCharCount(c.text)));
    const total = weights.reduce((x, y) => x + y, 0);
    const span = Math.max(group.length, winEnd - win.startMs - gapMs * (group.length - 1));
    let t = win.startMs;
    group.forEach((c, k) => {
      const dur = Math.max(1, Math.round(span * (weights[k] / total)));
      out.push({ ...c, startMs: t, endMs: t + dur, durationMs: dur });
      t += dur + gapMs;
    });
  }
  // Cues that belong to no window (should not happen) are kept as they are.
  const keys = new Set(sorted.map((w) => w.key));
  out.push(...cues.filter((c) => !keys.has(c.sourceWordStartIndex)));
  return out.sort((a, b) => a.startMs - b.startMs);
}

// ─── Conformer ───────────────────────────────────────────────────────────────

function chars(c: WorkCue): number {
  return c.dual ? getGraphemeCount(c.dual[0]) + getGraphemeCount(c.dual[1]) : getGraphemeCount(c.text);
}

function cps(c: WorkCue): number {
  const dur = Math.max(1, c.endMs - c.startMs);
  return chars(c) / (dur / 1000);
}

function overlapRatio(c: TimeInterval, intervals: TimeInterval[]): number {
  const dur = Math.max(1, c.endMs - c.startMs);
  let covered = 0;
  for (const s of intervals) {
    covered += Math.max(0, Math.min(c.endMs, s.endMs) - Math.max(c.startMs, s.startMs));
  }
  return covered / dur;
}

/**
 * Fixes a dialogue track so it follows the Netflix rules wherever timing and line
 * breaking can do it. Forced narratives (on-screen text) must be added afterwards; they
 * are positioned separately and are not merged with dialogue.
 */
export function conformCues(
  input: LocalizedSubtitleCue[],
  opts: ConformOptions
): { cues: LocalizedSubtitleCue[]; report: ConformReport } {
  const p = opts.profile;
  const gap = calculateMinInterCueGapMs(opts.fps ?? 30, p);
  const minDur = p.minimumCueDurationMs;
  const maxDur = p.maximumCueDurationMs;
  const maxCps = p.maxReadingSpeedCps;
  const cpl = p.maxCharactersPerLine;
  const maxEarly = opts.maxEarlyStartMs ?? 250;
  const mergeGap = opts.mergeGapMs ?? 1000;
  const songs = opts.songIntervalsMs || [];
  const report: ConformReport = { merged: 0, dualSpeaker: 0, split: 0, extended: 0, trimmed: 0, lyrics: 0, shotSnaps: 0, unresolved: [] };

  let work: WorkCue[] = [...input]
    .filter((c) => plainText(c.text).length > 0)
    .sort((a, b) => a.startMs - b.startMs)
    .map((c) => ({
      startMs: c.startMs,
      endMs: Math.max(c.endMs, c.startMs + 1),
      text: plainText(c.text),
      speaker: c.speaker,
      isLyric: Boolean((c as any).isLyric) || (songs.length > 0 && overlapRatio(c, songs) >= 0.5),
      sourceWordStartIndex: c.sourceWordStartIndex,
      sourceWordEndIndex: c.sourceWordEndIndex,
      alignmentConfidence: c.alignmentConfidence,
      languageCode: c.languageCode,
    }));

  // 1. Merge: a subtitle that is too short or too fast joins its neighbour.
  //    Different speakers -> one line each, marked with hyphens.
  const needsHelp = (c: WorkCue) => c.endMs - c.startMs < minDur || cps(c) > maxCps;
  let i = 0;
  while (i < work.length - 1) {
    const a = work[i];
    const b = work[i + 1];
    const canTry =
      !a.dual && !b.dual &&
      a.isLyric === b.isLyric &&
      b.startMs - a.endMs <= mergeGap &&
      b.endMs - a.startMs <= maxDur &&
      (needsHelp(a) || needsHelp(b));
    let merged: WorkCue | null = null;
    if (canTry) {
      // The merged subtitle may stay on screen until just before the following subtitle
      // (or a little into silence), so judge reading speed on that achievable span.
      const after = work[i + 2];
      const achievableEnd = Math.min(
        a.startMs + maxDur,
        after ? after.startMs - gap : b.endMs + 1500
      );
      const spanSec = Math.max(b.endMs, achievableEnd) - a.startMs > 0
        ? (Math.max(b.endMs, achievableEnd) - a.startMs) / 1000
        : (b.endMs - a.startMs) / 1000;
      const differentSpeakers = Boolean(a.speaker && b.speaker && a.speaker !== b.speaker);
      if (differentSpeakers) {
        const [l1, l2] = formatDualSpeaker(a.text, b.text, p);
        const fits = getGraphemeCount(l1) <= cpl && getGraphemeCount(l2) <= cpl;
        const total = getGraphemeCount(l1) + getGraphemeCount(l2);
        if (fits && total / spanSec <= maxCps) {
          merged = { ...a, endMs: b.endMs, speaker: undefined, dual: [a.text, b.text], text: `${a.text} ${b.text}`, sourceWordEndIndex: b.sourceWordEndIndex };
          report.dualSpeaker++;
        }
      } else {
        const text = `${a.text} ${b.text}`;
        if (breakLines(text, p) && getGraphemeCount(text) / spanSec <= maxCps) {
          merged = { ...a, endMs: b.endMs, text, sourceWordEndIndex: b.sourceWordEndIndex };
        }
      }
    }
    if (merged) {
      work.splice(i, 2, merged);
      report.merged++;
    } else {
      i++;
    }
  }

  // 2. Split: text that cannot fit in 2 lines, or a long text shown for more than the maximum.
  const out: WorkCue[] = [];
  const queue = [...work];
  let guard = 0;
  while (queue.length > 0 && guard++ < 10000) {
    const c = queue.shift()!;
    const dur = c.endMs - c.startMs;
    const fits = c.dual ? true : breakLines(c.text, p) !== null;
    const tooLongWithText = dur > maxDur && chars(c) > cpl;
    if (!c.dual && (!fits || tooLongWithText)) {
      const parts = splitTextInTwo(c.text, p);
      if (parts && parts[0] && parts[1]) {
        const w0 = Math.max(1, getGraphemeCount(parts[0]));
        const w1 = Math.max(1, getGraphemeCount(parts[1]));
        const mid = c.startMs + Math.round(dur * (w0 / (w0 + w1)));
        const halfGap = Math.ceil(gap / 2);
        queue.unshift(
          { ...c, text: parts[0], endMs: Math.max(c.startMs + 1, mid - halfGap) },
          { ...c, text: parts[1], startMs: Math.min(c.endMs - 1, mid + halfGap) }
        );
        report.split++;
        continue;
      }
    }
    out.push(c);
  }
  work = out;

  // 3. Timing: minimum time and reading speed (extend into silence, or start slightly early),
  //    maximum duration, and the 2-frame gap.
  for (let k = 0; k < work.length; k++) {
    const c = work[k];
    const prev = k > 0 ? work[k - 1] : null;
    const next = k < work.length - 1 ? work[k + 1] : null;
    const ceiling = next ? next.startMs - gap : Number.POSITIVE_INFINITY;
    const need = Math.min(maxDur, Math.max(minDur, Math.ceil((chars(c) / maxCps) * 1000)));

    if (c.endMs - c.startMs < need) {
      const newEnd = Math.min(c.startMs + need, ceiling, c.startMs + maxDur);
      if (newEnd > c.endMs) {
        c.endMs = newEnd;
        report.extended++;
      }
    }
    if (c.endMs - c.startMs < need) {
      const earliest = Math.max(prev ? prev.endMs + gap : 0, c.startMs - maxEarly);
      const newStart = Math.max(earliest, c.endMs - need);
      if (newStart < c.startMs) {
        c.startMs = newStart;
        report.extended++;
      }
    }
    if (c.endMs - c.startMs > maxDur) {
      c.endMs = c.startMs + maxDur;
      report.trimmed++;
    }
    if (c.endMs > ceiling) {
      c.endMs = Math.max(c.startMs + 1, ceiling);
      report.trimmed++;
    }
  }

  // 3b. Shot-change alignment (Netflix Timed Text Style Guide: Subtitle Timing Guidelines).
  // Netflix rules operate on a half-second window (12 frames at 24fps, 15 frames at 30fps / ~500ms).
  // - In-time: dialogue starting within half a second after a cut snaps to the cut.
  // - Out-time: dialogue ending within half a second before a cut extends to cut - 2 frames.
  // - Bleed: dialogue ending within half a second after a cut snaps back to cut - 2 frames.
  // - Crossing: if a subtitle crosses a cut, it must stay on screen for >= half a second on each side.
  const shotCuts = (opts.shotChangesMs || []).filter((s) => Number.isFinite(s) && s >= 0).sort((a, b) => a - b);
  const fps = opts.fps ?? 30;
  const halfSecondFrames = Math.round(fps * 0.5); // 15 frames at 30fps, 12 frames at 24fps
  const halfSecondMs = Math.round((halfSecondFrames / fps) * 1000); // ~500ms

  if (shotCuts.length > 0) {
    for (let k = 0; k < work.length; k++) {
      const c = work[k];
      const prev = k > 0 ? work[k - 1] : null;
      const next = k < work.length - 1 ? work[k + 1] : null;
      const earliest = prev ? prev.endMs + gap : 0;
      const latest = next ? next.startMs - gap : Number.POSITIVE_INFINITY;

      for (const cut of shotCuts) {
        // Cut is outside the half-second neighborhood of this cue
        if (cut < c.startMs - halfSecondMs || cut > c.endMs + halfSecondMs) continue;

        // In-Time Case 1: Dialogue starts within half a second after shot change -> snap to cut
        if (cut < c.startMs && c.startMs <= cut + halfSecondMs) {
          if (cut >= earliest) {
            c.startMs = cut;
            report.shotSnaps++;
          } else if (cut + gap >= earliest && cut + gap < c.startMs) {
            c.startMs = cut + gap;
            report.shotSnaps++;
          }
        }
        // In-Time Case 2: Dialogue starts within half a second before cut -> prevent perceptual flash, hold to cut
        else if (cut - halfSecondMs <= c.startMs && c.startMs < cut) {
          if (cut < c.endMs && (c.endMs - cut >= minDur || cut + minDur <= latest)) {
            c.startMs = cut;
            if (c.endMs - c.startMs < minDur) {
              c.endMs = Math.min(latest, c.startMs + minDur);
            }
            report.shotSnaps++;
          }
        }

        // Out-Time Case 1: Dialogue ends within half a second before shot change -> extend to cut - gap
        if (cut - halfSecondMs <= c.endMs && c.endMs < cut) {
          const targetEnd = cut - gap;
          if (c.endMs < targetEnd && targetEnd <= latest && targetEnd - c.startMs <= maxDur) {
            c.endMs = targetEnd;
            report.shotSnaps++;
          } else if (c.endMs > targetEnd && targetEnd >= c.startMs + minDur) {
            c.endMs = targetEnd;
            report.shotSnaps++;
          }
        }
        // Out-Time Case 2: Dialogue ends within half a second after shot change -> snap back to cut - gap
        else if (cut < c.endMs && c.endMs <= cut + halfSecondMs) {
          const targetEnd = cut - gap;
          if (targetEnd >= c.startMs + minDur && targetEnd < c.endMs) {
            c.endMs = targetEnd;
            report.shotSnaps++;
          }
        }

        // Shot Crossing Case: Subtitle spans across the shot cut
        // Netflix requires at least half a second (12 frames @ 24fps / 15 frames @ 30fps) on each side
        if (c.startMs < cut && c.endMs > cut) {
          const preCut = cut - c.startMs;
          const postCut = c.endMs - cut;
          if (preCut < halfSecondMs) {
            // Less than half a second before cut -> snap start to cut
            if (cut >= earliest) {
              c.startMs = cut;
              report.shotSnaps++;
            }
          } else if (postCut < halfSecondMs) {
            // Less than half a second after cut -> snap end back before cut
            const targetEnd = cut - gap;
            if (targetEnd >= c.startMs + minDur) {
              c.endMs = targetEnd;
              report.shotSnaps++;
            }
          }
        }
      }

      // Re-verify duration and gap bounds
      if (c.endMs - c.startMs > maxDur) {
        c.endMs = c.startMs + maxDur;
      }
      if (c.endMs > latest) {
        c.endMs = Math.max(c.startMs + 1, latest);
      }
    }
  }

  // 4. Lines, styling and the final check.
  const cues: LocalizedSubtitleCue[] = work.map((c, idx) => {
    let lines = c.dual ? formatDualSpeaker(c.dual[0], c.dual[1], p) : (breakLines(c.text, p) || [c.text]);
    if (c.isLyric) {
      report.lyrics++;
      if ((p.lyricsStyle || "italic") === "italic") lines = lines.map((l) => `<i>${l}</i>`) as any;
    }
    const text = lines.join("\n");
    const durationMs = c.endMs - c.startMs;
    const readable = getReadableCharCount(text);
    const charactersPerSecond = Number((readable / Math.max(0.001, durationMs / 1000)).toFixed(2));
    const charactersPerLine = Math.max(...lines.map((l) => getReadableCharCount(l)));
    const id = idx + 1;

    const issues: ConformIssue[] = [];
    if (durationMs < minDur) issues.push({ cueId: id, rule: "min_duration", detail: `${durationMs} ms < ${minDur} ms` });
    if (durationMs > maxDur) issues.push({ cueId: id, rule: "max_duration", detail: `${durationMs} ms > ${maxDur} ms` });
    if (charactersPerSecond > maxCps) issues.push({ cueId: id, rule: "reading_speed", detail: `${charactersPerSecond} > ${maxCps} CPS` });
    if (charactersPerLine > cpl) issues.push({ cueId: id, rule: "line_length", detail: `${charactersPerLine} > ${cpl} characters` });
    if (lines.length > p.maxLines) issues.push({ cueId: id, rule: "line_count", detail: `${lines.length} lines` });
    const nextCue = work[idx + 1];
    if (nextCue && c.endMs > nextCue.startMs) issues.push({ cueId: id, rule: "overlap", detail: `${c.endMs - nextCue.startMs} ms` });

    if (shotCuts.length > 0) {
      for (const cut of shotCuts) {
        if (cut - halfSecondMs <= c.startMs && c.startMs < cut) {
          issues.push({ cueId: id, rule: "shot_change", detail: `Starts ${cut - c.startMs} ms before cut at ${cut} ms (within half-second window)` });
        } else if (cut < c.endMs && c.endMs <= cut + halfSecondMs) {
          issues.push({ cueId: id, rule: "shot_change", detail: `Ends ${c.endMs - cut} ms after cut at ${cut} ms (within half-second window)` });
        }
      }
    }

    report.unresolved.push(...issues);

    const severe = issues.some((x) => x.rule === "line_count" || x.rule === "overlap" ||
      (x.rule === "reading_speed" && charactersPerSecond > maxCps * 1.25));

    const cue: LocalizedSubtitleCue = {
      id,
      languageCode: c.languageCode,
      text,
      startMs: c.startMs,
      endMs: c.endMs,
      durationMs,
      sourceWordStartIndex: c.sourceWordStartIndex,
      sourceWordEndIndex: c.sourceWordEndIndex,
      charactersPerSecond,
      charactersPerLine,
      alignmentConfidence: c.alignmentConfidence,
      validationStatus: severe ? "review" : (issues.length > 0 ? "warning" : "pass"),
      speaker: c.speaker,
      lines,
      isLyric: c.isLyric || undefined,
      isDualSpeaker: c.dual ? true : undefined,
    };
    return cue;
  });

  return { cues, report };
}
