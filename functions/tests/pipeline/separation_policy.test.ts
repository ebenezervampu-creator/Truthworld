/**
 * Voice / background separation policy. See separation-policy.ts.
 */
import {
  decideSeparation,
  parseMeanVolumeDb,
  readSeparationSettings,
  selectExpression,
  separationCostUsd,
  speechGaps,
  DEFAULT_SEPARATION_SETTINGS,
} from "../../src/pipeline/services/separation-policy";

describe("speechGaps", () => {
  test("gaps between, before and after speech, shrunk at the edges; short pauses ignored", () => {
    const gaps = speechGaps(
      [{ start: 1000, end: 4000 }, { start: 4200, end: 9000 }, { start: 11000, end: 15000 }],
      20000
    );
    // 0–1000 → 100–900; 4000–4200 too short; 9000–11000 → 9100–10900; 15000–20000 → 15100–19900
    expect(gaps).toEqual([
      { start: 100, end: 900 },
      { start: 9100, end: 10900 },
      { start: 15100, end: 19900 },
    ]);
  });

  test("overlapping and unsorted segments are merged; bad spans ignored", () => {
    expect(speechGaps([{ start: 5000, end: 8000 }, { start: 1000, end: 6000 }, { start: 9, end: 9 }], 9000)).toEqual([
      { start: 100, end: 900 },
      { start: 8100, end: 8900 },
    ]);
  });

  test("at most 80 gaps, keeping the longest, in time order", () => {
    const spoken = Array.from({ length: 200 }, (_, i) => ({ start: i * 2000, end: i * 2000 + 1000 + (i % 3) * 100 }));
    const gaps = speechGaps(spoken, 400000);
    expect(gaps).toHaveLength(80);
    expect(gaps.map((g) => g.start)).toEqual([...gaps.map((g) => g.start)].sort((a, b) => a - b));
  });

  test("select expression in seconds", () => {
    expect(selectExpression([{ start: 100, end: 900 }, { start: 9100, end: 10900 }])).toBe(
      "between(t,0.100,0.900)+between(t,9.100,10.900)"
    );
  });
});

describe("decideSeparation", () => {
  test("quiet gaps far below the track → speech only ($0)", () => {
    expect(decideSeparation({ gapSeconds: 20, backgroundDb: -62, overallDb: -21 }).path).toBe("speech_only");
  });

  test("music under speech → Demucs", () => {
    const d = decideSeparation({ gapSeconds: 20, backgroundDb: -30, overallDb: -19 });
    expect(d).toMatchObject({ path: "demucs", reason: "background_present" });
  });

  test("quiet but close to the overall level (quiet recording) → Demucs, to be safe", () => {
    expect(decideSeparation({ gapSeconds: 20, backgroundDb: -50, overallDb: -40 }).reason).toBe("gaps_not_far_enough_below_speech");
  });

  test("too little gap time or no measurement → Demucs", () => {
    expect(decideSeparation({ gapSeconds: 1, backgroundDb: -70, overallDb: -20 }).reason).toBe("too_little_gap_time_to_measure");
    expect(decideSeparation({ gapSeconds: 10, backgroundDb: null, overallDb: -20 }).reason).toBe("measurement_unavailable");
  });

  test("thresholds come from env", () => {
    const s = readSeparationSettings({ SEPARATION_SPEECH_ONLY_MAX_GAP_DB: "-35", SEPARATION_MIN_GAP_SECONDS: "x" });
    expect(s).toEqual({ ...DEFAULT_SEPARATION_SETTINGS, speechOnlyMaxGapDb: -35 });
    expect(decideSeparation({ gapSeconds: 20, backgroundDb: -40, overallDb: -15 }, s).path).toBe("speech_only");
  });
});

describe("FFmpeg parsing", () => {
  test("mean volume", () => {
    expect(parseMeanVolumeDb("[Parsed_volumedetect_1 @ 0x] mean_volume: -42.3 dB\nmax_volume: -3.1 dB")).toBe(-42.3);
    expect(parseMeanVolumeDb("mean_volume: -inf dB")).toBe(-120);
    expect(parseMeanVolumeDb("no stats")).toBeNull();
  });
});

describe("cost", () => {
  test("10 minutes: speech only $0, Demucs about $0.05", () => {
    expect(separationCostUsd("speech_only", 600)).toBe(0);
    expect(separationCostUsd("demucs", 600)).toBe(0.05);
  });
});
