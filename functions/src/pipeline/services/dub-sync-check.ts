/**
 * Delivery checks that compare the dub with the ORIGINAL (2026-11-24).
 *
 * Every earlier check compared the dub with our own plan (line timings, segment counts), so a plan
 * that was itself wrong passed "All quality gates": on 24 Nov a Telugu dub shipped lines 7–9 s early,
 * then one with a line missing, and an earlier one cast two men as women. These checks measure the
 * audio itself and block delivery when:
 *   - the original speaks a line inside the dialogue and the dub says nothing near it
 *     ("Dubbed speech missing"),
 *   - a speaker's dubbed voice is clearly the other gender from their original voice
 *     ("Voice gender mismatch").
 * They also stop a subtitle track that covers too few of the lines from being saved.
 * Pure functions (unit-tested); media.ts and 07-dubbing.ts feed them the decoded audio.
 */

export interface MsSpan {
  startMs: number;
  endMs: number;
}

export const DUB_SYNC = {
  /** Original speech shorter than this is not checked (breaths, "uh"). */
  minSourceSpeechMs: 500,
  /** The dub may start this much before the original line… */
  lookBeforeMs: 500,
  /** …and run this far past it (dubbed lines are often longer). */
  lookAfterMs: 1500,
  /** Dubbed speech needed near an original line: this much, or half the line if shorter. */
  minCoverMs: 300,
  /** Dialogue extent: line windows padded by this… */
  extentPadMs: 1000,
  /** …and merged across gaps up to this, so a mistimed line still sits inside the dialogue. */
  extentMergeGapMs: 4000,
  /**
   * A dubbed line that finishes (or starts) early can leave a short stretch of its own original speech
   * with no dub near it. Up to this long, inside a line that WAS dubbed, it is a timing warning, not
   * missing speech (24 Nov, 10.3 s: "We made a choice… that we knew was right" — Telugu says the
   * whole sentence by 9.4 s, the English finishes at 11.3 s after a pause).
   */
  maxEarlyFinishMs: 2500,
  /** …and only when the line's dubbed speech is at least this share of its original speech. */
  minLineDubRatio: 0.4,
  /**
   * With word timings: original voice that overlaps no transcribed word (± this guard) is reported as
   * `untranscribed` (warning), not missing. There is no text to dub there — a gasp, a shout, a sound
   * the separator kept in the voice track. 25 Nov film run …2722813: 0.76 s at 10.6 s inside an
   * AssemblyAI line whose first word starts at 22.98 s blocked a 12-minute film.
   */
  wordGuardMs: 250,
} as const;

function mergeSpans(spans: MsSpan[], gapMs: number): MsSpan[] {
  const sorted = spans.filter((s) => s.endMs > s.startMs).sort((a, b) => a.startMs - b.startMs);
  const out: MsSpan[] = [];
  for (const s of sorted) {
    const last = out[out.length - 1];
    if (last && s.startMs - last.endMs <= gapMs) last.endMs = Math.max(last.endMs, s.endMs);
    else out.push({ ...s });
  }
  return out;
}

/** Where the transcript says there is dialogue: line windows, padded and merged. */
export function dialogueExtents(lines: MsSpan[], padMs: number = DUB_SYNC.extentPadMs, mergeGapMs: number = DUB_SYNC.extentMergeGapMs): MsSpan[] {
  return mergeSpans(
    lines.map((l) => ({ startMs: Math.max(0, l.startMs - padMs), endMs: l.endMs + padMs })),
    mergeGapMs
  );
}

function overlapMs(a: MsSpan, b: MsSpan): number {
  return Math.max(0, Math.min(a.endMs, b.endMs) - Math.max(a.startMs, b.startMs));
}

export interface MissingDubLine {
  startMs: number;
  endMs: number;
}

/**
 * Original speech (inside the dialogue extents) with no dubbed speech near it. Speech outside the
 * extents (songs, speech after the transcript ends) is not checked.
 */
export function findMissingDubSpeech(params: {
  sourceSpeech: MsSpan[];
  dubSpeech: MsSpan[];
  extents: MsSpan[];
}): MissingDubLine[] {
  return checkDubSpeech(params).missing;
}

/**
 * Like findMissingDubSpeech, but with the dubbed line windows (`lines`) it tells a line that was
 * dubbed but finishes early apart from a line with no dub: original speech with no dub near it, inside
 * a line window whose dubbed speech is at least minLineDubRatio of that window's original speech, and
 * no longer than maxEarlyFinishMs, is reported in `earlyFinish` (a warning), not in `missing`.
 * Without `lines` the result is the same as findMissingDubSpeech.
 */
export function checkDubSpeech(params: {
  sourceSpeech: MsSpan[];
  dubSpeech: MsSpan[];
  extents: MsSpan[];
  lines?: MsSpan[];
  /** Transcribed word timings. When given, voice with no word in it is `untranscribed`, not missing. */
  words?: MsSpan[];
}): { missing: MissingDubLine[]; earlyFinish: MissingDubLine[]; untranscribed: MissingDubLine[] } {
  const missing: MissingDubLine[] = [];
  const earlyFinish: MissingDubLine[] = [];
  const untranscribed: MissingDubLine[] = [];
  const words = (params.words ?? []).filter((w) => w.endMs > w.startMs);
  const hasWord = (s: MsSpan) =>
    words.some((w) => w.startMs < s.endMs + DUB_SYNC.wordGuardMs && w.endMs > s.startMs - DUB_SYNC.wordGuardMs);
  const total = (spans: MsSpan[], within: MsSpan) => spans.reduce((sum, d) => sum + overlapMs(d, within), 0);
  for (const s of params.sourceSpeech) {
    const len = s.endMs - s.startMs;
    if (len < DUB_SYNC.minSourceSpeechMs) continue;
    const inside = params.extents.some((e) => overlapMs(e, s) >= len * 0.5);
    if (!inside) continue;
    const window = { startMs: s.startMs - DUB_SYNC.lookBeforeMs, endMs: s.endMs + DUB_SYNC.lookAfterMs };
    const covered = total(params.dubSpeech, window);
    if (covered >= Math.min(DUB_SYNC.minCoverMs, len * 0.5)) continue;
    const line = (params.lines ?? []).find((l) => overlapMs(l, s) >= len * 0.5);
    if (line && len <= DUB_SYNC.maxEarlyFinishMs) {
      const lineDub = total(params.dubSpeech, line);
      const lineSource = total(params.sourceSpeech, line);
      if (lineDub >= DUB_SYNC.minCoverMs && lineDub >= lineSource * DUB_SYNC.minLineDubRatio) {
        earlyFinish.push({ startMs: s.startMs, endMs: s.endMs });
        continue;
      }
    }
    if (words.length > 0 && !hasWord(s)) {
      untranscribed.push({ startMs: s.startMs, endMs: s.endMs });
      continue;
    }
    missing.push({ startMs: s.startMs, endMs: s.endMs });
  }
  return { missing, earlyFinish, untranscribed };
}

/**
 * A clearly male original against a clearly female dub (or the reverse). The original's reading must be
 * reliable (enough voiced frames, steady pitch): whispered or creaky speech reads far too low, and a
 * correct dub of a soft-spoken woman must never be blocked. Unmeasured → no finding.
 */
export const GENDER_CHECK = { maleMaxHz: 135, femaleMinHz: 200, minVoicedFrames: 100, maxSpreadSemitones: 3.5 } as const;

export interface PitchReading {
  medianHz: number;
  voicedFrames?: number;
  spreadSemitones?: number;
}

export function voiceGenderMismatch(original: PitchReading | null | undefined, dubHz: number | null | undefined): boolean {
  if (!original || !(original.medianHz > 0)) return false;
  const d = typeof dubHz === "number" && dubHz > 0 ? dubHz : 0;
  if (!d) return false;
  const reliable =
    (original.voicedFrames ?? 0) >= GENDER_CHECK.minVoicedFrames &&
    typeof original.spreadSemitones === "number" && original.spreadSemitones <= GENDER_CHECK.maxSpreadSemitones;
  if (!reliable) return false;
  const o = original.medianHz;
  return (o <= GENDER_CHECK.maleMaxHz && d >= GENDER_CHECK.femaleMinHz) || (o >= GENDER_CHECK.femaleMinHz && d <= GENDER_CHECK.maleMaxHz);
}

export interface DubSyncReport {
  checked: boolean;
  missing: MissingDubLine[];
  /** Original speech inside a dubbed line that the dub finished before (warning only; see checkDubSpeech). */
  earlyFinish?: MissingDubLine[];
  /** Original voice with no transcribed word in it (warning only; see DUB_SYNC.wordGuardMs). */
  untranscribed?: MissingDubLine[];
  genderMismatches: Array<{ speaker: string; originalHz: number; dubHz: number }>;
}

/** Quality-gate violations for a report ("Dubbed speech missing", "Voice gender mismatch"). */
export function syncViolations(report: DubSyncReport | null | undefined): string[] {
  if (!report || !report.checked) return [];
  const out: string[] = [];
  if (report.missing.length > 0) {
    const at = report.missing.slice(0, 5).map((m) => `${(m.startMs / 1000).toFixed(1)}s`).join(", ");
    out.push(`Dubbed speech missing: ${report.missing.length} original line(s) have no dubbed speech near them (at ${at})`);
  }
  for (const g of report.genderMismatches) {
    out.push(`Voice gender mismatch: speaker ${g.speaker} speaks at ${Math.round(g.originalHz)} Hz in the original but ${Math.round(g.dubHz)} Hz in the dub`);
  }
  return out;
}

/**
 * Share of the dubbed lines (with text) that a subtitle track covers in time. A track built from a
 * partial word list covered 2 of 11 lines on 24 Nov; such a track must not be saved.
 */
export function subtitleLineCoverage(cues: MsSpan[], lines: Array<MsSpan & { text?: string }>): number {
  const withText = lines.filter((l) => l.endMs > l.startMs && (l.text ?? "x").trim().length > 0);
  if (withText.length === 0) return 1;
  const covered = withText.filter((l) => cues.some((c) => overlapMs(c, l) > 0)).length;
  return covered / withText.length;
}

export const MIN_SUBTITLE_LINE_COVERAGE = 0.8;
