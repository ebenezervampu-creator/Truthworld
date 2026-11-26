/**
 * Fundamental-frequency (F0) estimation for voice matching (dependency-free, unit-tested).
 *
 * YIN (de Cheveigné & Kawahara, 2002) over short frames of mono PCM. Only voiced frames count:
 * frames that are too quiet, or whose best period is not clearly periodic, are skipped. The result
 * is the median F0 of the voiced frames, so pauses, breaths and background noise do not pull it.
 *
 * Used for BOTH sides of the match — the original speaker's turns and each candidate voice's
 * preview — so the two numbers are measured the same way and can be compared directly.
 */

export interface PitchEstimate {
  /** Median F0 of voiced frames, Hz. */
  medianHz: number;
  /** Spread of F0 across voiced frames (interquartile range, semitones) — how melodic the delivery is. */
  spreadSemitones: number;
  /** Voiced frames used. */
  voicedFrames: number;
  /** Voiced frames / frames with enough energy. */
  voicedRatio: number;
}

export interface PitchOptions {
  minHz?: number;
  maxHz?: number;
  frameMs?: number;
  hopMs?: number;
  /** YIN aperiodicity threshold; lower = stricter. */
  threshold?: number;
  /** Frames quieter than this fraction of the loudest frame's RMS are skipped. */
  relativeSilence?: number;
}

/** Fewer voiced frames than this → no reliable estimate (about 0.3 s of voiced speech at 10 ms hop). */
export const MIN_VOICED_FRAMES = 30;

const quantile = (sorted: number[], q: number): number => {
  if (sorted.length === 0) return 0;
  const pos = (sorted.length - 1) * q;
  const lo = Math.floor(pos);
  const hi = Math.ceil(pos);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
};

/** F0 of one frame, or 0 when the frame is not clearly periodic. */
function yinFrame(frame: Float32Array, sampleRate: number, minLag: number, maxLag: number, threshold: number, diff: Float64Array): number {
  const w = frame.length - maxLag;
  if (w <= 0) return 0;
  diff[0] = 0;
  for (let tau = 1; tau <= maxLag; tau++) {
    let sum = 0;
    for (let i = 0; i < w; i++) {
      const d = frame[i] - frame[i + tau];
      sum += d * d;
    }
    diff[tau] = sum;
  }
  // Cumulative mean normalized difference.
  let running = 0;
  diff[0] = 1;
  for (let tau = 1; tau <= maxLag; tau++) {
    running += diff[tau];
    diff[tau] = running > 0 ? (diff[tau] * tau) / running : 1;
  }
  let tauEst = -1;
  for (let tau = minLag; tau <= maxLag; tau++) {
    if (diff[tau] < threshold) {
      while (tau + 1 <= maxLag && diff[tau + 1] < diff[tau]) tau++;
      tauEst = tau;
      break;
    }
  }
  if (tauEst < 0) return 0;
  // Parabolic interpolation around the minimum for sub-sample accuracy.
  let better = tauEst;
  if (tauEst > 1 && tauEst < maxLag) {
    const s0 = diff[tauEst - 1];
    const s1 = diff[tauEst];
    const s2 = diff[tauEst + 1];
    const denom = s0 + s2 - 2 * s1;
    if (denom !== 0) better = tauEst + (s0 - s2) / (2 * denom);
  }
  return sampleRate / better;
}

/** Frame-level voicing of a stretch of audio: the F0 of each voiced frame and how many frames had energy. */
export interface VoicingFrames {
  /** F0 (Hz) of each frame YIN found clearly periodic, unsorted. */
  f0s: number[];
  /** Frames loud enough to be judged (not silence). */
  energeticFrames: number;
}

/**
 * Runs YIN over every frame with energy. Null only when there is nothing to judge (too short or
 * silent) — unlike estimatePitch, a stretch with energy but few periodic frames still returns its
 * counts, so callers can tell "unvoiced" from "not measurable".
 */
export function analyseVoicing(samples: Float32Array, sampleRate: number, options: PitchOptions = {}): VoicingFrames | null {
  const minHz = options.minHz ?? 60;
  const maxHz = options.maxHz ?? 450;
  const frameLen = Math.round(((options.frameMs ?? 40) / 1000) * sampleRate);
  const hop = Math.max(1, Math.round(((options.hopMs ?? 10) / 1000) * sampleRate));
  const threshold = options.threshold ?? 0.15;
  const relativeSilence = options.relativeSilence ?? 0.1;
  const minLag = Math.max(2, Math.floor(sampleRate / maxHz));
  const maxLag = Math.ceil(sampleRate / minHz);
  const size = frameLen + maxLag;
  if (samples.length < size) return null;

  const starts: number[] = [];
  const rms: number[] = [];
  for (let s = 0; s + size <= samples.length; s += hop) {
    let e = 0;
    for (let i = s; i < s + frameLen; i++) e += samples[i] * samples[i];
    starts.push(s);
    rms.push(Math.sqrt(e / frameLen));
  }
  const loudest = Math.max(...rms);
  if (!(loudest > 1e-4)) return null;

  const diff = new Float64Array(maxLag + 1);
  const f0s: number[] = [];
  let energeticFrames = 0;
  for (let k = 0; k < starts.length; k++) {
    if (rms[k] < loudest * relativeSilence) continue;
    energeticFrames++;
    const f = yinFrame(samples.subarray(starts[k], starts[k] + size), sampleRate, minLag, maxLag, threshold, diff);
    if (f >= minHz && f <= maxHz) f0s.push(f);
  }
  return { f0s, energeticFrames };
}

/** Median F0 of the voiced frames, or null when there is too little voiced speech to judge. */
export function estimatePitch(samples: Float32Array, sampleRate: number, options: PitchOptions = {}): PitchEstimate | null {
  const voicing = analyseVoicing(samples, sampleRate, options);
  if (!voicing) return null;
  const { energeticFrames } = voicing;
  const f0s = [...voicing.f0s];
  if (f0s.length < MIN_VOICED_FRAMES) return null;
  f0s.sort((a, b) => a - b);
  const median = quantile(f0s, 0.5);
  const q1 = quantile(f0s, 0.25);
  const q3 = quantile(f0s, 0.75);
  return {
    medianHz: Math.round(median * 10) / 10,
    spreadSemitones: Math.round(12 * Math.log2(q3 / q1) * 100) / 100,
    voicedFrames: f0s.length,
    voicedRatio: energeticFrames > 0 ? Math.round((f0s.length / energeticFrames) * 100) / 100 : 0,
  };
}

/** Little-endian 32-bit float PCM (ffmpeg `-f f32le`) → samples. */
export function f32leToSamples(buf: Buffer): Float32Array {
  const n = Math.floor(buf.length / 4);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = buf.readFloatLE(i * 4);
  return out;
}

/**
 * Pitch distance on a perceptual (semitone) scale, 0 … 1. 12 semitones (one octave) apart = 1.
 * Hz differences mislead: 20 Hz is a big gap for a deep male voice and a small one for a high female voice.
 */
export function pitchDistanceSemitones(aHz: number, bHz: number): number {
  if (!(aHz > 0) || !(bHz > 0)) return 0.5;
  return Math.min(1, Math.abs(12 * Math.log2(aHz / bHz)) / 12);
}
