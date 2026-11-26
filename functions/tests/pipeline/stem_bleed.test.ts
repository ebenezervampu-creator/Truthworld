/**
 * Source-dialogue bleed measured against the isolated voice (stem-bleed.ts).
 *
 * Regression for the 23 Nov 2026 Demucs benchmark: a clean stem of a music-heavy clip failed
 * validateMneStem at 5.2 dB because the old measure (original minus stem level in the voice band)
 * counts loud music as bleed. Signals here are synthetic and seeded, so the test runs anywhere.
 */
import { coherentVoiceSuppressionDb, BLEED_ANALYSIS_RATE } from "../../src/pipeline/services/stem-bleed";

const SR = BLEED_ANALYSIS_RATE;
const SECONDS = 6;
const N = SR * SECONDS;

function prng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Syllable-like envelope: ~4 syllables/s with short pauses. */
function syllableEnvelope(): Float32Array {
  const env = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    const t = i / SR;
    const s = Math.sin(2 * Math.PI * 4 * t + 0.7 * Math.sin(2 * Math.PI * 0.9 * t));
    env[i] = Math.max(0, s) * (Math.sin(2 * Math.PI * 0.35 * t) > -0.6 ? 1 : 0.05);
  }
  return env;
}

/** Voiced speech stand-in: gliding pitch with harmonics to 3.5 kHz, plus a little noise. */
function makeVoice(env: Float32Array): Float32Array {
  const rnd = prng(7);
  const out = new Float32Array(N);
  let phase = 0;
  for (let i = 0; i < N; i++) {
    const t = i / SR;
    const f0 = 140 + 35 * Math.sin(2 * Math.PI * 0.6 * t);
    phase += (2 * Math.PI * f0) / SR;
    let v = 0;
    for (let h = 1; h * f0 < 3500; h++) v += Math.sin(h * phase) / h;
    out[i] = 0.12 * env[i] * (v + 0.3 * (rnd() - 0.5));
  }
  return out;
}

/** Music stand-in: sustained chord + noise, louder than the voice, ducked a little under speech. */
function makeMusic(env: Float32Array): Float32Array {
  const rnd = prng(11);
  const notes = [220, 277.2, 329.6, 440, 554.4, 659.3, 880, 1108.7];
  const out = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    const t = i / SR;
    let m = 0;
    for (const f of notes) m += Math.sin(2 * Math.PI * f * t + f) * (1 + 0.3 * Math.sin(2 * Math.PI * 0.5 * t));
    out[i] = (0.05 * m + 0.08 * (rnd() - 0.5)) * (1 - 0.3 * env[i]);
  }
  return out;
}

const env = syllableEnvelope();
const voice = makeVoice(env);
/** Music scaled so the voice sits ~3 dB above it in the speech band, as in the real benchmark windows (+2 to +6 dB). */
const music = (() => {
  const raw = makeMusic(env);
  const band = (x: Float32Array) => {
    // crude speech-band power: first difference removes the lows, enough for setting a level
    let p = 0;
    for (let i = 1; i < x.length; i++) p += (x[i] - x[i - 1]) ** 2;
    return p;
  };
  const g = Math.sqrt(band(voice) / band(raw) / Math.pow(10, 3 / 10));
  return raw.map((x) => x * g);
})();

function plus(a: Float32Array, b: Float32Array, gainDb: number): Float32Array {
  const g = Math.pow(10, gainDb / 20);
  return a.map((x, i) => x + g * b[i]);
}

/** The old validateMneStem measure: original minus stem level, both 250–3800 Hz (approximated broadband here). */
function levelDropDb(original: Float32Array, stem: Float32Array): number {
  const p = (x: Float32Array) => x.reduce((s, v) => s + v * v, 0) / x.length;
  return 10 * Math.log10(p(original) / p(stem));
}

describe("coherentVoiceSuppressionDb", () => {
  const original = plus(music, voice, 0);

  it("passes a clean stem under loud music that the old level-drop measure fails", () => {
    expect(levelDropDb(original, music)).toBeLessThan(10); // old measure: "failed"
    const db = coherentVoiceSuppressionDb(music, voice);
    expect(db).not.toBeNull();
    expect(db as number).toBeGreaterThanOrEqual(16); // MNE_MIN_SUPPRESSION_PASS_DB
  });

  /** What an ideal meter reads for voice left in at gainDb: 10·log10(1 + 1/g²). */
  const ideal = (gainDb: number) => 10 * Math.log10(1 + Math.pow(10, -gainDb / 10));

  it("fails a stem with the voice left in at -6 dB", () => {
    const db = coherentVoiceSuppressionDb(plus(music, voice, -6), voice) as number;
    expect(db).toBeLessThan(10); // MNE_MIN_SUPPRESSION_FAIL_DB
    expect(Math.abs(db - ideal(-6))).toBeLessThan(1.5);
  });

  it("marks a stem with the voice left in at -13 dB as not clean (between the fail and pass lines)", () => {
    const db = coherentVoiceSuppressionDb(plus(music, voice, -13), voice) as number;
    expect(db).toBeGreaterThanOrEqual(10);
    expect(db).toBeLessThan(16);
    expect(Math.abs(db - ideal(-13))).toBeLessThan(1.5);
  });

  it("passes a stem with only a faint -24 dB trace of voice", () => {
    const db = coherentVoiceSuppressionDb(plus(music, voice, -24), voice) as number;
    expect(db).toBeGreaterThanOrEqual(16); // reads ~21: the floor of a 6 s window is ~22 dB
  });

  it("reads a stem that is all voice as fully bled", () => {
    const db = coherentVoiceSuppressionDb(voice, voice);
    expect(db as number).toBeLessThan(4);
  });

  it("skips a window where the 'vocals' are only music left in by the separator", () => {
    // Benchmark 2026-11-23: such windows read 0–1 dB ("fully bled") although no one was speaking.
    const residue = music.map((x) => x * Math.pow(10, -15 / 20));
    expect(coherentVoiceSuppressionDb(music, residue)).toBeNull();
  });

  it("skips a window where the voice is far below the music, but measures one where it is not", () => {
    expect(coherentVoiceSuppressionDb(music, voice.map((x) => x * 0.25))).toBeNull(); // voice ~12 dB lower
    expect(coherentVoiceSuppressionDb(music, voice)).not.toBeNull();
  });

  it("returns null when there is nothing to measure", () => {
    expect(coherentVoiceSuppressionDb(music, new Float32Array(N))).toBeNull(); // silent vocals
    const short = Math.round(0.8 * SR); // under ~1 s the noise floor nears the pass line
    expect(coherentVoiceSuppressionDb(music.subarray(0, short), voice.subarray(0, short))).toBeNull();
  });
});
