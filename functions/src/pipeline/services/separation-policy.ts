/**
 * Voice / background separation policy (dependency-free, unit-tested).
 *
 *  - Speech-only videos (talking head, podcast, lecture): the gaps between words are near-silent,
 *    so there is no background to keep. No separation; the dub is mixed on its own. $0.
 *  - Videos with music or effects under the speech: Demucs on the self-hosted GPU worker
 *    (DEMUX_SERVICE_URL), giving a clean background track and a vocal stem.
 *
 * The choice is measured with FFmpeg on the original audio: loudness in the gaps between spoken
 * segments (word timestamps) versus the whole track. Thresholds are settings so they can be tuned
 * from logged measurements ([Separation] Decision).
 */

export type SeparationPath = "speech_only" | "demucs";

export interface TimedSpan {
  start: number; // ms
  end: number; // ms
}

export interface SeparationSettings {
  /** Gaps quieter than this (mean dBFS) count as silence. */
  speechOnlyMaxGapDb: number;
  /** ...and at least this far below the track's overall level. */
  speechOnlyMinMarginDb: number;
  /** Need this much measured gap time to call a video speech-only; otherwise separate. */
  minGapSeconds: number;
}

export const DEFAULT_SEPARATION_SETTINGS: SeparationSettings = {
  speechOnlyMaxGapDb: -45,
  speechOnlyMinMarginDb: 20,
  minGapSeconds: 3,
};

/**
 * Demucs on a GPU, per minute of audio: about $0.05 per 10 minutes. Estimate carried over from the
 * earlier hosted-Demucs pricing; replace with the self-hosted worker's measured cost.
 */
export const DEMUCS_USD_PER_MINUTE = 0.005;

/** Gaps shorter than this are pauses inside speech, too short to measure a background. */
const MIN_GAP_MS = 400;
/** Stay clear of word edges (breaths, reverb tails). */
const EDGE_MARGIN_MS = 100;
/** Bound the FFmpeg select expression. */
const MAX_GAPS = 80;

function num(raw: string | undefined, fallback: number): number {
  const n = Number(raw);
  return raw !== undefined && raw !== "" && Number.isFinite(n) ? n : fallback;
}

export function readSeparationSettings(env: Record<string, string | undefined> = process.env): SeparationSettings {
  const d = DEFAULT_SEPARATION_SETTINGS;
  return {
    speechOnlyMaxGapDb: num(env.SEPARATION_SPEECH_ONLY_MAX_GAP_DB, d.speechOnlyMaxGapDb),
    speechOnlyMinMarginDb: num(env.SEPARATION_SPEECH_ONLY_MIN_MARGIN_DB, d.speechOnlyMinMarginDb),
    minGapSeconds: num(env.SEPARATION_MIN_GAP_SECONDS, d.minGapSeconds),
  };
}

/**
 * Non-speech stretches of the track (ms), from the spoken segments: between segments, before the
 * first and after the last, shrunk by EDGE_MARGIN_MS each side. Longest first, at most MAX_GAPS,
 * returned in time order.
 */
export function speechGaps(spoken: TimedSpan[], durationMs: number): TimedSpan[] {
  const total = Math.max(0, durationMs);
  const spans = spoken
    .filter((s) => Number.isFinite(s.start) && Number.isFinite(s.end) && s.end > s.start)
    .map((s) => ({ start: Math.max(0, s.start), end: Math.min(total || s.end, s.end) }))
    .sort((a, b) => a.start - b.start);
  const gaps: TimedSpan[] = [];
  let cursor = 0;
  for (const s of spans) {
    if (s.start > cursor) gaps.push({ start: cursor, end: s.start });
    cursor = Math.max(cursor, s.end);
  }
  if (total > cursor) gaps.push({ start: cursor, end: total });
  return gaps
    .map((g) => ({ start: g.start + EDGE_MARGIN_MS, end: g.end - EDGE_MARGIN_MS }))
    .filter((g) => g.end - g.start >= MIN_GAP_MS)
    .sort((a, b) => b.end - b.start - (a.end - a.start))
    .slice(0, MAX_GAPS)
    .sort((a, b) => a.start - b.start);
}

/** FFmpeg `aselect` expression keeping only the given spans (seconds). */
export function selectExpression(spans: TimedSpan[]): string {
  return spans.map((s) => `between(t,${(s.start / 1000).toFixed(3)},${(s.end / 1000).toFixed(3)})`).join("+");
}

/** Parses `mean_volume: -42.3 dB` from FFmpeg volumedetect output. */
export function parseMeanVolumeDb(ffmpegStderr: string): number | null {
  const m = /mean_volume:\s*(-?(?:\d+(?:\.\d+)?|inf))\s*dB/i.exec(ffmpegStderr || "");
  if (!m) return null;
  if (m[1].toLowerCase().includes("inf")) return -120;
  const v = Number(m[1]);
  return Number.isFinite(v) ? v : null;
}

export interface SeparationDecision {
  path: SeparationPath;
  reason: string;
  gapSeconds: number;
  backgroundDb: number | null;
  overallDb: number | null;
}

/** Speech-only only when there is enough gap time AND the gaps are quiet, absolutely and relatively. */
export function decideSeparation(
  input: { gapSeconds: number; backgroundDb: number | null; overallDb: number | null },
  s: SeparationSettings = DEFAULT_SEPARATION_SETTINGS
): SeparationDecision {
  const base = { gapSeconds: input.gapSeconds, backgroundDb: input.backgroundDb, overallDb: input.overallDb };
  if (input.gapSeconds < s.minGapSeconds) {
    return { path: "demucs", reason: "too_little_gap_time_to_measure", ...base };
  }
  if (input.backgroundDb === null || input.overallDb === null) {
    return { path: "demucs", reason: "measurement_unavailable", ...base };
  }
  const quiet = input.backgroundDb <= s.speechOnlyMaxGapDb;
  const margin = input.overallDb - input.backgroundDb;
  if (quiet && margin >= s.speechOnlyMinMarginDb) {
    return { path: "speech_only", reason: "quiet_gaps", ...base };
  }
  return { path: "demucs", reason: quiet ? "gaps_not_far_enough_below_speech" : "background_present", ...base };
}

export function separationCostUsd(path: SeparationPath, durationSec: number): number {
  if (path === "speech_only") return 0;
  const minutes = Math.max(0, durationSec) / 60;
  return Math.round(minutes * DEMUCS_USD_PER_MINUTE * 10000) / 10000;
}
