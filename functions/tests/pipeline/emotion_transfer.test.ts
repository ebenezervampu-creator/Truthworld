/**
 * Emotion transfer (emotion-transfer.ts) and the stability floor for intense lines (dubbing-guards.ts).
 * Line values below were measured from the real Joseph clip (2026-11-20, film mix with music) with
 * measureLineAcoustics; the dub of that clip read all three emotional moments as calm speech.
 */
import {
  intenseStability,
  isIntenseDeliveryTag,
  measureLineAcoustics,
  MIN_INTENSE_STABILITY,
  planDelivery,
  type LineAcoustics,
  type LineEmotionHints,
} from "../../src/pipeline/services/emotion-transfer";
import { applyDubbingStabilityFloor, MIN_DUBBING_STABILITY } from "../../src/pipeline/services/dubbing-guards";

const joseph: LineAcoustics[] = [
  { index: 0, startMs: 340, endMs: 2510, speaker: "A", gender: "male", f0Hz: 123.2, voicedRmsDb: -18.5 }, // Wise Men, calm
  { index: 1, startMs: 4780, endMs: 8140, speaker: "B_3", gender: "male", f0Hz: 222.2, voicedRmsDb: -19.1 }, // Pharaoh roars
  { index: 2, startMs: 11620, endMs: 12780, speaker: "B_2", gender: "male", f0Hz: 218.5, voicedRmsDb: -21 }, // Cupbearer
  { index: 3, startMs: 12840, endMs: 14800, speaker: "B_2", gender: "male", f0Hz: 188.1, voicedRmsDb: -22 },
  { index: 4, startMs: 14800, endMs: 16560, speaker: "B_2", gender: "male", f0Hz: 305.5, voicedRmsDb: -21.4 }, // cries
  { index: 5, startMs: 18340, endMs: 20100, speaker: "B", gender: "male", f0Hz: null, voicedRmsDb: -18.3 }, // demon
  { index: 6, startMs: 20100, endMs: 22000, speaker: "B", gender: "male", f0Hz: null, voicedRmsDb: -15.3 },
  { index: 7, startMs: 22000, endMs: 23600, speaker: "B", gender: "male", f0Hz: 67.1, voicedRmsDb: -14.8 },
  { index: 8, startMs: 23600, endMs: 25379, speaker: "B", gender: "male", f0Hz: null, voicedRmsDb: -16.4 },
];

describe("planDelivery on the Joseph clip", () => {
  test("from the audio alone: the three emotional moments are intense, calm lines are untouched", () => {
    const plan = planDelivery(joseph);
    expect(plan.get(0)!.tag).toBeUndefined(); // Wise Men
    expect(plan.get(1)!.tag).toBe("intense"); // Pharaoh, +10.7 st
    expect(plan.get(1)!.pitchRiseSemitones).toBeCloseTo(10.7, 1);
    expect(plan.get(2)!.tag).toBeUndefined(); // "Don't worry, Joseph."
    expect(plan.get(3)!.tag).toBeUndefined();
    expect(plan.get(4)!.tag).toBe("intense"); // the cry, +12.3 st over his normal voice
    for (const i of [5, 6, 7, 8]) expect(isIntenseDeliveryTag(plan.get(i)!.tag)).toBe(true); // the whole rant
  });

  test("with Gemini's emotion hints: Pharaoh shouts, the cupbearer cries, the demon stays intense", () => {
    const hints = new Map<number, LineEmotionHints>([
      [1, { anger: 0.85, tag: "angry" }],
      [4, { sadness: 0.8, tag: "sorrowful" }],
      [6, { anger: 0.9, tag: "shouts" }],
    ]);
    const plan = planDelivery(joseph, hints);
    expect(plan.get(1)!.tag).toBe("shouting");
    expect(plan.get(4)!.tag).toBe("crying");
    expect(plan.get(6)!.tag).toBe("shouting");
    expect(plan.get(0)!.tag).toBeUndefined();
  });

  test("a character's baseline is never a raised voice (someone who shouts every line is still flagged)", () => {
    const shouter: LineAcoustics[] = [0, 1, 2, 3].map((i) => ({ index: i, startMs: i * 5000, endMs: i * 5000 + 2000, speaker: "S", gender: "male", f0Hz: 260, voicedRmsDb: -12 }));
    const calm: LineAcoustics[] = [4, 5, 6].map((i) => ({ index: i, startMs: i * 5000, endMs: i * 5000 + 2000, speaker: "T", gender: "male", f0Hz: 118, voicedRmsDb: -20 }));
    const plan = planDelivery([...shouter, ...calm]);
    for (const i of [0, 1, 2, 3]) expect(isIntenseDeliveryTag(plan.get(i)!.tag)).toBe(true);
    for (const i of [4, 5, 6]) expect(plan.get(i)!.tag).toBeUndefined();
  });

  test("an ordinary conversation produces no tags", () => {
    const talk: LineAcoustics[] = Array.from({ length: 10 }, (_, i) => ({
      index: i, startMs: i * 3000, endMs: i * 3000 + 2500, speaker: i % 2 ? "F" : "M",
      gender: i % 2 ? ("female" as const) : ("male" as const), f0Hz: i % 2 ? 205 + (i % 3) * 8 : 115 + (i % 3) * 6, voicedRmsDb: -20 - (i % 3),
    }));
    expect([...planDelivery(talk).values()].every((d) => !d.tag)).toBe(true);
  });
});

describe("stability", () => {
  test("intense lines get 0.40 → 0.30, never below the intense floor", () => {
    expect(intenseStability(0)).toBe(0.4);
    expect(intenseStability(1)).toBe(0.3);
    expect(intenseStability(5)).toBe(MIN_INTENSE_STABILITY);
  });
  test("the 0.5 floor still holds for every non-intense non-English line; intense tags relax it to 0.3", () => {
    expect(applyDubbingStabilityFloor(0.3, "te")).toBe(MIN_DUBBING_STABILITY);
    expect(applyDubbingStabilityFloor(0.3, "te", "sad")).toBe(MIN_DUBBING_STABILITY);
    expect(applyDubbingStabilityFloor(0.32, "te", "shouting")).toBe(0.32);
    expect(applyDubbingStabilityFloor(0.2, "hi", "crying")).toBe(MIN_INTENSE_STABILITY);
    expect(applyDubbingStabilityFloor(0.2, "en", "shouting")).toBe(0.2);
  });
});

describe("measureLineAcoustics", () => {
  test("finds the pitch of a voiced tone up in the scream range, and its loudness", () => {
    const sr = 8000;
    const x = new Float32Array(sr * 2);
    for (let i = 0; i < x.length; i++) {
      const t = i / sr;
      x[i] = 0.3 * Math.sin(2 * Math.PI * 520 * t) + 0.15 * Math.sin(2 * Math.PI * 1040 * t);
    }
    const m = measureLineAcoustics(x, sr, 0, 2000);
    expect(m.f0Hz).toBeGreaterThan(500);
    expect(m.f0Hz).toBeLessThan(540);
    expect(m.voicedRmsDb).toBeGreaterThan(-15);
    expect(m.voicedRmsDb).toBeLessThan(-10);
  });
  test("too short to judge → nothing measured", () => {
    expect(measureLineAcoustics(new Float32Array(8000), 8000, 0, 100)).toEqual({ f0Hz: null, voicedRmsDb: null, voicedShare: null });
  });
});

describe("measureLineAcoustics voiced share (2026-11-24: missing pitch is not 'unvoiced')", () => {
  const sr = 8000;
  test("energetic but aperiodic audio (noise) → a measured low voiced share, no pitch", () => {
    let seed = 7;
    const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648) * 2 - 1;
    const x = new Float32Array(sr * 2);
    for (let i = 0; i < x.length; i++) x[i] = 0.2 * rnd();
    const m = measureLineAcoustics(x, sr, 0, 2000);
    expect(m.f0Hz).toBeNull();
    expect(typeof m.voicedShare).toBe("number");
    expect(m.voicedShare as number).toBeLessThan(0.2);
  });
  test("a steady voiced tone → pitch and a high voiced share", () => {
    const x = new Float32Array(sr * 2);
    for (let i = 0; i < x.length; i++) x[i] = 0.3 * Math.sin((2 * Math.PI * 140 * i) / sr);
    const m = measureLineAcoustics(x, sr, 0, 2000);
    expect(m.f0Hz).toBeGreaterThan(130);
    expect(m.voicedShare as number).toBeGreaterThanOrEqual(0.2);
  });
  test("silence → not measurable (null), never 0", () => {
    const m = measureLineAcoustics(new Float32Array(sr * 2), sr, 0, 2000);
    expect(m.f0Hz).toBeNull();
    expect(m.voicedShare).toBeNull();
  });
});
