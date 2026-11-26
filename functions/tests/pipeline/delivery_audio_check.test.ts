/**
 * Delivery audio checks (delivery-audio-check.ts): source-voice bleed under the dub, and loudness.
 * Synthetic signals; the thresholds were also run on the real Joseph clip (2026-11-20):
 * that dub was flagged (10.8 s of 14.7 s of speech, worst r 0.27 vs chance ≈ 0.05) and an
 * unrelated control signal was not (worst r 0.06).
 */
import { detectSourceBleed, loudnessCorrection, DELIVERY_TARGET_LUFS } from "../../src/pipeline/services/delivery-audio-check";

const SR = 8000;

/** Deterministic speech-like signal: band-limited noise with a syllable-rate envelope. */
function speechLike(seconds: number, seed: number): Float32Array {
  let s = seed >>> 0;
  const rand = () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;
  const out = new Float32Array(seconds * SR);
  let y1 = 0, y2 = 0;
  for (let i = 0; i < out.length; i++) {
    const x = rand();
    const y = 0.6 * y1 - 0.3 * y2 + x; // gentle resonance
    y2 = y1; y1 = y;
    const env = 0.5 + 0.5 * Math.sin((2 * Math.PI * 4 * i) / SR + seed);
    out[i] = 0.2 * y * env;
  }
  return out;
}
const mix = (a: Float32Array, b: Float32Array, gb: number, lag = 0) => a.map((v, i) => v + gb * (i - lag >= 0 ? b[i - lag] : 0));
const speech = [{ startMs: 500, endMs: 6000 }, { startMs: 8000, endMs: 14000 }, { startMs: 16000, endMs: 19500 }];

describe("detectSourceBleed", () => {
  const source = speechLike(20, 7);
  const dubVoice = speechLike(20, 99);

  test("a clean dub (new recording) is not flagged", () => {
    const r = detectSourceBleed(dubVoice, source, SR, speech);
    expect(r.bleed).toBe(false);
    expect(r.worstR).toBeLessThan(0.08);
  });

  test("source voice 16 dB under the dub is flagged (the Joseph clip level)", () => {
    const delivered = mix(dubVoice, source, Math.pow(10, -16 / 20));
    const r = detectSourceBleed(delivered, source, SR, speech);
    expect(r.bleed).toBe(true);
    expect(r.flaggedMs / r.testedMs).toBeGreaterThan(0.8);
  });

  test("found through a small decode offset (3 ms)", () => {
    const delivered = mix(dubVoice, source, 0.2, 24);
    const r = detectSourceBleed(delivered, source, SR, speech);
    expect(r.bleed).toBe(true);
    expect(r.lagSamples).toBe(24);
  });

  test("original audio in the gaps between lines is allowed (background between lines)", () => {
    const gapOnly = new Float32Array(dubVoice);
    for (const [a, b] of [[0, 0.5], [6, 8], [14, 16]]) for (let i = a * SR; i < b * SR; i++) gapOnly[i] += source[i];
    expect(detectSourceBleed(gapOnly, source, SR, speech).bleed).toBe(false);
  });

  test("no speech windows → nothing tested, no verdict", () => {
    expect(detectSourceBleed(dubVoice, source, SR, [])).toMatchObject({ bleed: false, testedMs: 0 });
  });
});

describe("loudnessCorrection", () => {
  test("the Joseph clip (−34.1 LUFS) gets +20.1 dB; on-target and near-target tracks are untouched", () => {
    expect(loudnessCorrection(-34.1)).toEqual({ needed: true, gainDb: 20.1, outOfRange: false });
    expect(loudnessCorrection(-14.6)).toEqual({ needed: false, gainDb: 0, outOfRange: false });
    expect(loudnessCorrection(-12.5)).toEqual({ needed: false, gainDb: 0, outOfRange: false });
    expect(loudnessCorrection(-9)).toEqual({ needed: true, gainDb: -5, outOfRange: false });
  });
  test("silent, unmeasurable or absurdly quiet output is out of range, never blindly boosted", () => {
    expect(loudnessCorrection(null).outOfRange).toBe(true);
    expect(loudnessCorrection(-80).outOfRange).toBe(true);
    expect(loudnessCorrection(-50)).toEqual({ needed: true, gainDb: 30, outOfRange: true });
    expect(DELIVERY_TARGET_LUFS).toBe(-14);
  });
});
