/**
 * Expressive voice mode ("version B", DUBBING_EXPRESSIVE=true; expressive-mode.ts).
 * Normal mode must be exactly as before; expressive mode lowers the floor, caps each speaker's
 * baseline and widens the per-line range.
 */
import { EXPRESSIVE, expressiveModeEnabled, expressiveStabilityFloor } from "../../src/pipeline/services/expressive-mode";
import { applyDubbingStabilityFloor, MIN_DUBBING_STABILITY } from "../../src/pipeline/services/dubbing-guards";
import { lockVoiceSettingsPerSpeaker, MAX_STABILITY_DEVIATION } from "../../src/pipeline/services/speaker-voice-lock";
import { MIN_INTENSE_STABILITY } from "../../src/pipeline/services/emotion-transfer";

const withEnv = (vars: Record<string, string | undefined>, fn: () => void) => {
  const prev: Record<string, string | undefined> = {};
  for (const k of Object.keys(vars)) {
    prev[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    fn();
  } finally {
    for (const k of Object.keys(prev)) {
      if (prev[k] === undefined) delete process.env[k];
      else process.env[k] = prev[k];
    }
  }
};

// The te run (dub-test-te-1795516992008) locked speaker A at 0.57 and B at 0.55.
const lines = [
  { speaker: "A", stabilityOverride: 0.57 },
  { speaker: "A", stabilityOverride: 0.3 },
  { speaker: "A", stabilityOverride: 0.75 },
  { speaker: "B", stabilityOverride: 0.55 },
];

describe("flag", () => {
  test("off unless DUBBING_EXPRESSIVE=true; floor override clamped to 0.3–0.5", () => {
    expect(expressiveModeEnabled({})).toBe(false);
    expect(expressiveModeEnabled({ DUBBING_EXPRESSIVE: "true" })).toBe(true);
    expect(expressiveStabilityFloor({})).toBe(EXPRESSIVE.stabilityFloor);
    expect(expressiveStabilityFloor({ DUBBING_EXPRESSIVE_STABILITY_FLOOR: "0.1" })).toBe(0.3);
    expect(expressiveStabilityFloor({ DUBBING_EXPRESSIVE_STABILITY_FLOOR: "0.9" })).toBe(0.5);
    expect(expressiveStabilityFloor({ DUBBING_EXPRESSIVE_STABILITY_FLOOR: "0.42" })).toBe(0.42);
  });
});

describe("stability floor", () => {
  test("normal mode unchanged: Telugu floored at 0.5, English untouched", () => {
    withEnv({ DUBBING_EXPRESSIVE: undefined }, () => {
      expect(applyDubbingStabilityFloor(0.35, "te")).toBe(MIN_DUBBING_STABILITY);
      expect(applyDubbingStabilityFloor(0.35, "en")).toBe(0.35);
    });
  });
  test("expressive: Telugu floored at 0.38, never below the intense floor for intense lines", () => {
    withEnv({ DUBBING_EXPRESSIVE: "true", DUBBING_EXPRESSIVE_STABILITY_FLOOR: undefined }, () => {
      expect(applyDubbingStabilityFloor(0.2, "te")).toBe(0.38);
      expect(applyDubbingStabilityFloor(0.45, "te")).toBe(0.45);
      expect(applyDubbingStabilityFloor(0.2, "te", "crying")).toBe(MIN_INTENSE_STABILITY);
    });
  });
});

describe("per-speaker lock", () => {
  test("normal mode unchanged: baseline = median, ±0.05", () => {
    withEnv({ DUBBING_EXPRESSIVE: undefined }, () => {
      const { segments, baselines } = lockVoiceSettingsPerSpeaker(lines);
      expect(baselines.get("A")!.stability).toBe(0.57);
      expect(segments.map((s) => s.stabilityOverride)).toEqual([0.57, 0.52, 0.62, 0.55]);
      expect(MAX_STABILITY_DEVIATION).toBe(0.05);
    });
  });
  test("expressive: baseline capped at 0.42, lines may move ±0.15", () => {
    const { segments, baselines } = lockVoiceSettingsPerSpeaker(lines, { expressive: true });
    expect(baselines.get("A")!.stability).toBe(EXPRESSIVE.baselineCap);
    expect(baselines.get("B")!.stability).toBe(EXPRESSIVE.baselineCap);
    // A: 0.57 stays, 0.3 stays (the TTS floor later lifts it to 0.38), 0.75 → 0.57; B: 0.55 is within 0.42 ± 0.15.
    expect(segments.map((s) => s.stabilityOverride)).toEqual([0.57, 0.3, 0.57, 0.55]);
  });
  test("expressive keeps similarity locked per speaker (same voice on every line)", () => {
    const { segments } = lockVoiceSettingsPerSpeaker(
      [
        { speaker: "A", stabilityOverride: 0.4, similarityBoostOverride: 0.8 },
        { speaker: "A", stabilityOverride: 0.5, similarityBoostOverride: 0.9 },
      ],
      { expressive: true }
    );
    expect(new Set(segments.map((s) => s.similarityBoostOverride)).size).toBe(1);
  });
});
