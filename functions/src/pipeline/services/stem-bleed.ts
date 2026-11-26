/**
 * Source-dialogue bleed in a background (M&E) stem, measured against the isolated voice.
 *
 * Why not "original level minus stem level" in the voice band: when music is loud under the speech,
 * the background is meant to be nearly as loud as the original there, so that drop stays small
 * (5 dB on the 3m15s Demucs benchmark, 23 Nov 2026) even when no voice is left in it. Every
 * music-heavy video then failed validation and lost its music under the dub.
 *
 * Leaked voice moves with the voice: same frequencies at the same moments. Music does not. Per
 * frequency bin we keep only the part of the background that is coherent with the isolated voice
 * (bias-corrected for the window length) and report how far below the voice it sits:
 *   leak  L = Σ_f max(0, (|S_bv(f)|² / S_vv(f) − S_bb(f) / N) / (1 − 1/N))
 *   suppression = 10·log10((S_vv + L) / L)      (250–3800 Hz, capped at 40 dB)
 * Checked on the benchmark stems: clean stem 18.5 dB; voice mixed back in at −16 / −10 / −6 dB
 * reads 13.8 / 10.1 / 5.8 dB at −20 / −13 / −6 dB (worst quartile of 12 windows). On synthetic
 * signals the reading is within ~1 dB of the true leak between 6 and 20 dB; the floor on a clean
 * 6 s window is ~22 dB.
 * Limits: an echo-like leak delayed by more than ~one frame (~30 ms) is not coherent within a frame
 * and reads as clean; voice the separator missed entirely (absent from the vocals stem) is invisible
 * here. Windows under ~1 s, and windows where the vocals are more than 6 dB under the background
 * (MIN_VOICE_OVER_BED_DB), return null.
 *
 * Pure — decoding happens in MediaService.validateMneStem.
 */

import { fft } from "./faithful-mix";

/** Analysis rate for the bleed check (covers the 250–3800 Hz voice band). */
export const BLEED_ANALYSIS_RATE = 8000;
/** Highest suppression reported; also the value for "no coherent voice found". */
export const MAX_BLEED_SUPPRESSION_DB = 40;
const FRAME = 256; // 32 ms at 8 kHz
const HOP = FRAME / 2;
/** ~1 s. Shorter windows have too few frames: the noise floor drops toward the pass line. */
const MIN_FRAMES = 61;
/** Below this mean voice power (dBFS) the window has no voice to compare against. */
const MIN_VOICE_DB = -60;
/**
 * Voice-band level of the vocals stem relative to the background below which a window is skipped.
 * There the "vocals" are mostly music the separator left in them (benchmark 2026-11-23: windows at
 * 2:12–2:35 with vocals 11–40 dB under the bed read 0–1 dB, as if fully bled), and any real leak
 * would be masked by the louder music anyway.
 */
export const MIN_VOICE_OVER_BED_DB = -6;

/**
 * How far (dB) the voice left in `bed` sits below the isolated `vocals` in the voice band.
 * Returns null when the window is too short or the vocals are silent (nothing to measure).
 * Both inputs must be time-aligned mono PCM at `sampleRate`.
 */
export function coherentVoiceSuppressionDb(
  bed: Float32Array,
  vocals: Float32Array,
  sampleRate: number = BLEED_ANALYSIS_RATE,
  bandHz: [number, number] = [250, 3800]
): number | null {
  const n = Math.min(bed.length, vocals.length);
  const frames = n >= FRAME ? Math.floor((n - FRAME) / HOP) + 1 : 0;
  if (frames < MIN_FRAMES) return null;

  let vocalPower = 0;
  for (let i = 0; i < n; i++) vocalPower += vocals[i] * vocals[i];
  if (10 * Math.log10(vocalPower / n + 1e-20) < MIN_VOICE_DB) return null;

  const kLo = Math.max(1, Math.ceil((bandHz[0] * FRAME) / sampleRate));
  const kHi = Math.min(FRAME / 2 - 1, Math.floor((bandHz[1] * FRAME) / sampleRate));
  if (kHi < kLo) return null;
  const bins = kHi - kLo + 1;

  const win = new Float64Array(FRAME);
  for (let i = 0; i < FRAME; i++) win[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / FRAME);

  const svv = new Float64Array(bins);
  const sbb = new Float64Array(bins);
  const sbvRe = new Float64Array(bins);
  const sbvIm = new Float64Array(bins);
  const bRe = new Float64Array(FRAME);
  const bIm = new Float64Array(FRAME);
  const vRe = new Float64Array(FRAME);
  const vIm = new Float64Array(FRAME);

  for (let f = 0; f < frames; f++) {
    const start = f * HOP;
    for (let i = 0; i < FRAME; i++) {
      bRe[i] = bed[start + i] * win[i];
      vRe[i] = vocals[start + i] * win[i];
      bIm[i] = 0;
      vIm[i] = 0;
    }
    fft(bRe, bIm);
    fft(vRe, vIm);
    for (let k = kLo; k <= kHi; k++) {
      const j = k - kLo;
      svv[j] += vRe[k] * vRe[k] + vIm[k] * vIm[k];
      sbb[j] += bRe[k] * bRe[k] + bIm[k] * bIm[k];
      // B · conj(V)
      sbvRe[j] += bRe[k] * vRe[k] + bIm[k] * vIm[k];
      sbvIm[j] += bIm[k] * vRe[k] - bRe[k] * vIm[k];
    }
  }

  let voiceBand = 0;
  let bedBand = 0;
  for (let j = 0; j < bins; j++) {
    voiceBand += svv[j];
    bedBand += sbb[j];
  }
  if (bedBand > 0 && 10 * Math.log10(voiceBand / bedBand + 1e-20) < MIN_VOICE_OVER_BED_DB) return null;

  let voice = 0;
  let leak = 0;
  for (let j = 0; j < bins; j++) {
    const vv = svv[j] / frames;
    const bb = sbb[j] / frames;
    const re = sbvRe[j] / frames;
    const im = sbvIm[j] / frames;
    voice += vv;
    // E[|S_bv|²/S_vv] ≈ C + (S_bb − C)/N for coherent power C over N frames; solve for C.
    if (vv > 0) leak += Math.max(0, ((re * re + im * im) / vv - bb / frames) / (1 - 1 / frames));
  }
  if (voice <= 0) return null;
  if (leak <= voice * 1e-4) return MAX_BLEED_SUPPRESSION_DB;
  return Math.min(MAX_BLEED_SUPPRESSION_DB, 10 * Math.log10((voice + leak) / leak));
}
