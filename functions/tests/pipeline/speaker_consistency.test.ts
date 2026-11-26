/**
 * One voice per speaker, for every upcoming video:
 *  - voice settings locked per speaker (no per-line identity drift),
 *  - profiling built from several clean turns of the speaker,
 *  - the whole-recording profiler told which turns to listen to.
 */
import {
  DEFAULT_CLONE_STABILITY,
  DEFAULT_SIMILARITY,
  DEFAULT_STABILITY,
  lockVoiceSettingsPerSpeaker,
  MAX_STABILITY_DEVIATION,
} from "../../src/pipeline/services/speaker-voice-lock";
import {
  describeSpeakerTurns,
  MAX_SECONDS_PER_TURN,
  MAX_TOTAL_SECONDS,
  MAX_TURNS,
  selectProfilingTurns,
} from "../../src/pipeline/services/speaker-turn-sampler";

describe("lockVoiceSettingsPerSpeaker", () => {
  // Per-line values as Gemini prosody returns them: wide swings for the same person.
  const lines = [
    { speaker: "A", text: "a1", stabilityOverride: 0.25, similarityBoostOverride: 0.95 },
    { speaker: "B", text: "b1", stabilityOverride: 0.70, similarityBoostOverride: 0.80 },
    { speaker: "A", text: "a2", stabilityOverride: 0.75, similarityBoostOverride: 0.75 },
    { speaker: "A", text: "a3", stabilityOverride: 0.50, similarityBoostOverride: 0.85 },
    { speaker: "B", text: "b2", stabilityOverride: 0.30, similarityBoostOverride: 0.90 },
  ];

  test("every line of a speaker gets the same similarity boost", () => {
    const { segments } = lockVoiceSettingsPerSpeaker(lines);
    const simA = new Set(segments.filter((s) => s.speaker === "A").map((s) => s.similarityBoostOverride));
    const simB = new Set(segments.filter((s) => s.speaker === "B").map((s) => s.similarityBoostOverride));
    expect(simA.size).toBe(1);
    expect(simB.size).toBe(1);
  });

  test("stability stays within ±0.05 of the speaker's median", () => {
    const { segments, baselines } = lockVoiceSettingsPerSpeaker(lines);
    expect(baselines.get("A")!.stability).toBe(0.5);
    for (const s of segments.filter((x) => x.speaker === "A")) {
      expect(Math.abs(s.stabilityOverride! - 0.5)).toBeLessThanOrEqual(MAX_STABILITY_DEVIATION + 1e-9);
    }
    // 0.25 → 0.45, 0.75 → 0.55, 0.50 stays
    expect(segments.map((s) => s.stabilityOverride)).toEqual([0.45, 0.55, 0.55, 0.5, 0.45]);
  });

  test("speakers are locked independently", () => {
    const { baselines } = lockVoiceSettingsPerSpeaker(lines);
    expect(baselines.get("A")!.similarityBoost).toBe(0.85); // median of 0.95, 0.75, 0.85
    expect(baselines.get("B")!.stability).toBe(0.5); // median of 0.70 and 0.30
    expect(baselines.get("B")!.similarityBoost).toBe(0.85);
  });

  test("lines without Gemini values get explicit defaults, so the bus cannot vary them by emotion", () => {
    const { segments } = lockVoiceSettingsPerSpeaker([{ speaker: "X" }, { speaker: "X" }]);
    for (const s of segments) {
      expect(s.stabilityOverride).toBe(DEFAULT_STABILITY);
      expect(s.similarityBoostOverride).toBe(DEFAULT_SIMILARITY);
    }
    const clone = lockVoiceSettingsPerSpeaker([{ speaker: "X" }], { preferVoiceCloning: true });
    expect(clone.segments[0].stabilityOverride).toBe(DEFAULT_CLONE_STABILITY);
  });

  test("lines with no speaker share the speaker_0 baseline, matching voiceMapping", () => {
    const { baselines } = lockVoiceSettingsPerSpeaker([{ stabilityOverride: 0.6 }, { speaker: "speaker_0", stabilityOverride: 0.4 }]);
    expect([...baselines.keys()]).toEqual(["speaker_0"]);
  });

  test("other fields and order are preserved, input is not mutated", () => {
    const input = [{ speaker: "A", text: "keep", emotionTag: "sad", stabilityOverride: 0.2 }];
    const { segments } = lockVoiceSettingsPerSpeaker(input);
    expect(segments[0]).toMatchObject({ speaker: "A", text: "keep", emotionTag: "sad" });
    expect(input[0].stabilityOverride).toBe(0.2);
  });
});

describe("selectProfilingTurns", () => {
  // Dialogue like a typical scene: guard, then Joseph three times, prisoners in between.
  const turns = [
    { speaker: "G", startSec: 2.4, endSec: 7.8 },
    { speaker: "J", startSec: 8.64, endSec: 9.92 },
    { speaker: "J", startSec: 12.96, endSec: 15.12 },
    { speaker: "P", startSec: 20.0, endSec: 21.0 },
    { speaker: "J", startSec: 25.76, endSec: 28.4 },
    { speaker: "P", startSec: 28.8, endSec: 29.7 },
  ];

  test("uses several turns of the speaker, in time order", () => {
    const picked = selectProfilingTurns(turns, "J");
    expect(picked.map((t) => t.startSec)).toEqual([8.64, 12.96, 25.76]);
    const total = picked.reduce((s, t) => s + t.durationSec, 0);
    expect(total).toBeGreaterThan(5.5); // the old single slice gave Joseph ~2.6 s
  });

  test("caps turns, per-turn and total length", () => {
    const long = Array.from({ length: 6 }, (_, i) => ({ speaker: "N", startSec: i * 20, endSec: i * 20 + 15 }));
    const picked = selectProfilingTurns(long, "N");
    expect(picked.length).toBeLessThanOrEqual(MAX_TURNS);
    for (const t of picked) expect(t.durationSec).toBeLessThanOrEqual(MAX_SECONDS_PER_TURN);
    expect(picked.reduce((s, t) => s + t.durationSec, 0)).toBeLessThanOrEqual(MAX_TOTAL_SECONDS + 1e-9);
  });

  test("prefers turns that do not overlap another speaker", () => {
    const withCrossTalk = [
      { speaker: "A", startSec: 0, endSec: 6 },    // longest, but B talks over it
      { speaker: "B", startSec: 3, endSec: 4 },
      { speaker: "A", startSec: 10, endSec: 12 },
      { speaker: "A", startSec: 20, endSec: 21.5 },
      { speaker: "A", startSec: 30, endSec: 31 },
    ];
    const picked = selectProfilingTurns(withCrossTalk, "A");
    expect(picked.map((t) => t.startSec)).toEqual([10, 20, 30]);
  });

  test("falls back to overlapping or short turns when nothing else exists", () => {
    expect(selectProfilingTurns([{ speaker: "A", startSec: 0, endSec: 0.5 }], "A")).toEqual([{ startSec: 0, durationSec: 0.5 }]);
    expect(selectProfilingTurns(turns, "nobody")).toEqual([]);
  });
});

describe("describeSpeakerTurns", () => {
  test("gives Gemini the speaker's time ranges in mm:ss (AssemblyAI milliseconds)", () => {
    const utterances = [
      { speaker: "A", start: 2400, end: 7800, text: "" },
      { speaker: "B", start: 8640, end: 9920, text: "" },
      { speaker: "B", start: 72960, end: 75120, text: "" },
    ];
    expect(describeSpeakerTurns(utterances, "B")).toBe("00:08.6–00:09.9, 01:13.0–01:15.1");
    expect(describeSpeakerTurns(utterances, "A")).toBe("00:02.4–00:07.8");
    expect(describeSpeakerTurns(utterances, "Z")).toBe("");
  });
});
