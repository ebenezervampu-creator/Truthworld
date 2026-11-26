/**
 * Delivery audio checks — run on the finished dub before a viewer can hear it.
 *
 * Added 2026-11-20 after the Joseph clip shipped at −34 LUFS (target −14) with the original
 * English audible under every Telugu line (11–18 dB below the dub). Neither problem was caught,
 * because every earlier check looked at intermediate stems, not at what the viewer receives.
 *
 * 1. Loudness: the delivered track must sit within ±2 LU of the target, or it is corrected.
 * 2. Source bleed: during the original's spoken lines, the delivered track must not contain the
 *    original voice. Measured as the waveform correlation between the delivered audio and the
 *    reference (the isolated source voice, or the source audio), compared with the same
 *    correlation at deliberately wrong alignments. A dub voice is a new recording and never
 *    lines up sample-for-sample with the source; bleed always does.
 *
 * Pure functions only — decoding and FFmpeg live in MediaService.
 */

export const DELIVERY_TARGET_LUFS = -14;
export const DELIVERY_TOLERANCE_LU = 2;
/** Never boost more than this in one correction; beyond it the source of the problem must be found. */
export const MAX_CORRECTION_DB = 30;

export interface LoudnessCorrection {
  needed: boolean;
  gainDb: number;
  /** True when the level is so far off (or unmeasurable) that the dub must not ship uncorrected. */
  outOfRange: boolean;
}

export function loudnessCorrection(
  measuredLufs: number | null | undefined,
  target = DELIVERY_TARGET_LUFS,
  toleranceLu = DELIVERY_TOLERANCE_LU
): LoudnessCorrection {
  if (typeof measuredLufs !== "number" || !Number.isFinite(measuredLufs) || measuredLufs < -70) {
    // Silent or unmeasurable output: nothing sensible to boost.
    return { needed: false, gainDb: 0, outOfRange: true };
  }
  const delta = target - measuredLufs;
  if (Math.abs(delta) <= toleranceLu) return { needed: false, gainDb: 0, outOfRange: false };
  const gainDb = Number(Math.max(-MAX_CORRECTION_DB, Math.min(MAX_CORRECTION_DB, delta)).toFixed(1));
  return { needed: true, gainDb, outOfRange: Math.abs(delta) > MAX_CORRECTION_DB };
}

export interface SpeechWindow {
  startMs: number;
  endMs: number;
}

export interface BleedWindowResult {
  startMs: number;
  endMs: number;
  /** |correlation| between delivered and reference audio at the true alignment. */
  r: number;
  /** Largest |correlation| at wrong alignments: what chance alone produces for this window. */
  nullMax: number;
  flagged: boolean;
}

export interface BleedReport {
  bleed: boolean;
  lagSamples: number;
  testedMs: number;
  flaggedMs: number;
  worstR: number;
  windows: BleedWindowResult[];
}

export interface BleedOptions {
  /** Window is flagged when r ≥ minR and r ≥ nullRatio × nullMax. */
  minR?: number;
  nullRatio?: number;
  /** Bleed when flagged time ≥ this share of tested time, and at least minFlaggedMs. */
  minFlaggedShare?: number;
  minFlaggedMs?: number;
  /** Trimmed from both ends of every speech window (mix crossfades and padding live there). */
  edgeTrimMs?: number;
  /** Long windows are split into pieces of this length. */
  pieceMs?: number;
  /** Cap on pieces tested (sampled evenly) so long videos stay cheap. */
  maxPieces?: number;
  /** Alignment search range between the two decodes. */
  maxLagMs?: number;
}

const DEFAULTS: Required<BleedOptions> = {
  minR: 0.08,
  nullRatio: 2.5,
  minFlaggedShare: 0.2,
  minFlaggedMs: 2000,
  edgeTrimMs: 150,
  pieceMs: 4000,
  maxPieces: 150,
  maxLagMs: 25,
};

/** Wrong alignments used to measure the chance level (seconds). Far beyond any real offset. */
const NULL_SHIFTS_SEC = [0.31, 0.47, 0.73, 0.97, 1.21, 1.53, 1.87, 2.29];

function corrAt(a: Float32Array, b: Float32Array, start: number, end: number, shift: number): number {
  // Correlation of a[i] with b[i - shift] over i in [start, end)
  let sa = 0, sb = 0, saa = 0, sbb = 0, sab = 0, n = 0;
  for (let i = start; i < end; i++) {
    const j = i - shift;
    if (j < 0 || j >= b.length || i >= a.length) continue;
    const x = a[i], y = b[j];
    sa += x; sb += y; saa += x * x; sbb += y * y; sab += x * y; n++;
  }
  if (n < 64) return 0;
  const cov = sab - (sa * sb) / n;
  const va = saa - (sa * sa) / n;
  const vb = sbb - (sb * sb) / n;
  if (va <= 1e-12 || vb <= 1e-12) return 0;
  return cov / Math.sqrt(va * vb);
}

function speechPieces(windows: SpeechWindow[], sampleRate: number, totalSamples: number, o: Required<BleedOptions>) {
  const pieces: Array<{ s: number; e: number }> = [];
  for (const w of windows) {
    const s0 = Math.round(((w.startMs + o.edgeTrimMs) / 1000) * sampleRate);
    const e0 = Math.min(totalSamples, Math.round(((w.endMs - o.edgeTrimMs) / 1000) * sampleRate));
    const piece = Math.round((o.pieceMs / 1000) * sampleRate);
    const minLen = Math.round(0.6 * sampleRate);
    for (let s = s0; s < e0; s += piece) {
      const e = Math.min(e0, s + piece);
      if (e - s >= minLen) pieces.push({ s, e });
    }
  }
  if (pieces.length <= o.maxPieces) return pieces;
  const step = pieces.length / o.maxPieces;
  return Array.from({ length: o.maxPieces }, (_, k) => pieces[Math.floor(k * step)]);
}

/**
 * Does the delivered audio contain the reference (source) voice during the source's speech?
 * Both signals must be mono PCM at the same sample rate, starting at the video's t=0.
 */
export function detectSourceBleed(
  delivered: Float32Array,
  reference: Float32Array,
  sampleRate: number,
  speech: SpeechWindow[],
  options: BleedOptions = {}
): BleedReport {
  const o = { ...DEFAULTS, ...options };
  const pieces = speechPieces(speech, sampleRate, Math.min(delivered.length, reference.length), o);
  if (pieces.length === 0) {
    return { bleed: false, lagSamples: 0, testedMs: 0, flaggedMs: 0, worstR: 0, windows: [] };
  }

  // Alignment: search ±maxLag on up to 6 of the longest pieces, keep the lag with the highest mean |r|.
  const maxLag = Math.round((o.maxLagMs / 1000) * sampleRate);
  const probe = [...pieces].sort((p, q) => (q.e - q.s) - (p.e - p.s)).slice(0, 6);
  let lag = 0;
  let best = -1;
  for (let L = -maxLag; L <= maxLag; L++) {
    let sum = 0;
    for (const p of probe) sum += Math.abs(corrAt(delivered, reference, p.s, p.e, L));
    if (sum > best) { best = sum; lag = L; }
  }

  const windows: BleedWindowResult[] = [];
  let testedMs = 0, flaggedMs = 0, worstR = 0;
  for (const p of pieces) {
    const r = Math.abs(corrAt(delivered, reference, p.s, p.e, lag));
    let nullMax = 0;
    for (const sec of NULL_SHIFTS_SEC) {
      const shift = Math.round(sec * sampleRate);
      nullMax = Math.max(nullMax, Math.abs(corrAt(delivered, reference, p.s, p.e, lag + shift)), Math.abs(corrAt(delivered, reference, p.s, p.e, lag - shift)));
    }
    const flagged = r >= o.minR && r >= o.nullRatio * nullMax;
    const ms = ((p.e - p.s) / sampleRate) * 1000;
    testedMs += ms;
    if (flagged) flaggedMs += ms;
    worstR = Math.max(worstR, r);
    windows.push({ startMs: Math.round((p.s / sampleRate) * 1000), endMs: Math.round((p.e / sampleRate) * 1000), r: Number(r.toFixed(3)), nullMax: Number(nullMax.toFixed(3)), flagged });
  }

  const bleed = flaggedMs >= o.minFlaggedMs && flaggedMs >= o.minFlaggedShare * testedMs;
  return { bleed, lagSamples: lag, testedMs: Math.round(testedMs), flaggedMs: Math.round(flaggedMs), worstR: Number(worstR.toFixed(3)), windows };
}
