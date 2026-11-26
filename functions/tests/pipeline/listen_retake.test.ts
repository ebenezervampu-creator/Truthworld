/**
 * Listen-and-retake (listen-retake.ts, DUBBING_LISTEN_RETAKE). Fake Gemini and fake TTS; no network.
 */
import {
  buildListenPrompt,
  LISTEN,
  listenRetakeEnabled,
  newTakeIsBetter,
  parseListenVerdict,
  retakeSettings,
  runListenAndRetake,
  selectRetakes,
  takeFitsTiming,
  type ListenDeps,
  type ListenLine,
  type ListenVerdict,
} from "../../src/pipeline/services/listen-retake";

const v = (index: number, score: number, faults: string[] = [], sourceDelivery?: string): ListenVerdict => ({
  index,
  score,
  faults: faults.map((type) => ({ type: type as any })),
  ...(sourceDelivery ? { sourceDelivery } : {}),
});

describe("parseListenVerdict", () => {
  test("reads score, known faults and source delivery; drops unknown fault types", () => {
    const raw = '```json\n{"score": 2, "faults": [{"type":"breathy_onset","detail":"first word"},{"type":"bad_vibes"}], "source_delivery":"teasing"}\n```';
    expect(parseListenVerdict(raw, 3)).toEqual({
      index: 3,
      score: 2,
      faults: [{ type: "breathy_onset", detail: "first word" }],
      sourceDelivery: "teasing",
    });
  });
  test("clamps the score to 1..5 and accepts plain-string faults", () => {
    expect(parseListenVerdict('{"score": 9, "faults": ["garbled"]}', 0)?.score).toBe(5);
    expect(parseListenVerdict('{"score": 9, "faults": ["garbled"]}', 0)?.faults).toEqual([{ type: "garbled" }]);
  });
  test("unreadable reply → null (the line keeps its take)", () => {
    expect(parseListenVerdict("not json", 0)).toBeNull();
    expect(parseListenVerdict('{"faults": []}', 0)).toBeNull();
  });
});

describe("selectRetakes", () => {
  test("fixable faults or very low scores, worst first; clipped_ending alone is not a retake", () => {
    const picked = selectRetakes([v(0, 5), v(1, 3, ["breathy_onset"]), v(2, 4, ["clipped_ending"]), v(3, 2), v(4, 1, ["garbled"])], 20);
    expect(picked).toEqual([4, 3, 1]);
  });
  test("capped at maxRetakeShare of the lines", () => {
    const many = Array.from({ length: 12 }, (_, i) => v(i, 2, ["flat_delivery"]));
    expect(selectRetakes(many, 12)).toHaveLength(Math.floor(12 * LISTEN.maxRetakeShare));
  });
});

describe("retakeSettings", () => {
  test("breath faults remove a breathy tag and raise stability to at least 0.55", () => {
    expect(retakeSettings([{ type: "unwanted_whisper" }], { stability: 0.34, style: 0.1, emotionTag: "whispers" })).toEqual({ stability: 0.55, style: 0.1 });
  });
  test("wrong emotion takes the original's strong delivery as tag", () => {
    expect(retakeSettings([{ type: "wrong_emotion" }], { stability: 0.55, style: 0.1 }, "crying")).toEqual({ stability: 0.55, style: 0.25, emotionTag: "crying" });
  });
  test("flat delivery: more style, a little less stability; bounded", () => {
    expect(retakeSettings([{ type: "flat_delivery" }], { stability: 0.32, style: 0.55 })).toEqual({ stability: 0.3, style: 0.6 });
  });
  test("overacted: less style, more stability, strong tag dropped", () => {
    expect(retakeSettings([{ type: "overacted" }], { stability: 0.4, style: 0.3, emotionTag: "shouting" })).toEqual({ stability: 0.5, style: 0.1 });
  });
});

describe("newTakeIsBetter / takeFitsTiming", () => {
  test("higher score wins; equal score needs fewer fixable faults; a failed listen keeps the old take", () => {
    expect(newTakeIsBetter(v(0, 2, ["breathy_onset"]), v(0, 4))).toBe(true);
    expect(newTakeIsBetter(v(0, 3, ["breathy_onset"]), v(0, 3))).toBe(true);
    expect(newTakeIsBetter(v(0, 3), v(0, 3))).toBe(false);
    expect(newTakeIsBetter(v(0, 3), v(0, 2))).toBe(false);
    expect(newTakeIsBetter(v(0, 2), null)).toBe(false);
  });
  test("a new take more than 10% longer than both the old take and the window is rejected", () => {
    const line = { startMs: 0, endMs: 2000, durationMs: 1800 } as ListenLine;
    expect(takeFitsTiming(line, { url: "x", durationMs: 2200 })).toBe(true);
    expect(takeFitsTiming(line, { url: "x", durationMs: 2300 })).toBe(false);
  });
});

describe("prompt and flag", () => {
  test("prompt asks about performance, not wording, and strips audio tags from the dubbed text", () => {
    const p = buildListenPrompt({ sourceText: "Uh-oh.", dubText: "[whispers] అయ్యో.", targetLanguage: "Telugu" });
    expect(p).toContain("Do not judge the translation");
    expect(p).toContain("అయ్యో.");
    expect(p).not.toContain("[whispers]");
  });
  test("off unless DUBBING_LISTEN_RETAKE=true", () => {
    expect(listenRetakeEnabled({})).toBe(false);
    expect(listenRetakeEnabled({ DUBBING_LISTEN_RETAKE: "true" })).toBe(true);
  });
});

describe("runListenAndRetake (fakes)", () => {
  const line = (index: number): ListenLine => ({
    index,
    sourceText: `line ${index}`,
    dubText: `[whispers] పంక్తి ${index}`,
    dubUrl: `gs://b/take_${index}.mp3`,
    startMs: index * 3000,
    endMs: index * 3000 + 2000,
    durationMs: 1900,
    base: { stability: 0.34, style: 0.1, emotionTag: "whispers" },
  });

  function deps(replies: Record<string, string>, budget = 10000): { d: ListenDeps; kept: number[]; synthSettings: any[] } {
    const kept: number[] = [];
    const synthSettings: any[] = [];
    const d: ListenDeps = {
      // The fake reply depends on which take is being judged (old take_N or new retake_N).
      generate: async ({ dubWavBase64 }) => replies[Buffer.from(dubWavBase64, "base64").toString()] ?? '{"score":5,"faults":[]}',
      sourceWav: async () => Buffer.from("src"),
      dubWav: async (url) => Buffer.from(url.replace(/^.*\//, "").replace(".mp3", "")),
      resynthesize: async (l, settings) => {
        synthSettings.push(settings);
        return { url: `gs://b/retake_${l.index}.mp3`, durationMs: 1950 };
      },
      tryConsumeBudget: (chars) => (budget -= chars) >= 0,
      keep: async (l) => {
        kept.push(l.index);
      },
      log: () => undefined,
    };
    return { d, kept, synthSettings };
  }

  test("a breathy line is re-voiced without the whisper tag and kept when judged better", async () => {
    const { d, kept, synthSettings } = deps({
      take_1: '{"score":2,"faults":[{"type":"breathy_onset"}]}',
      retake_1: '{"score":4,"faults":[]}',
    });
    const s = await runListenAndRetake([line(0), line(1), line(2), line(3)], "te", d);
    expect(s.listened).toBe(4);
    expect(s.retakesTried).toBe(1);
    expect(s.retakesKept).toBe(1);
    expect(kept).toEqual([1]);
    expect(synthSettings[0]).toEqual({ stability: 0.55, style: 0.1 });
  });

  test("a retake judged no better is discarded", async () => {
    const { d, kept } = deps({
      take_1: '{"score":2,"faults":[{"type":"garbled"}]}',
      retake_1: '{"score":2,"faults":[{"type":"garbled"}]}',
    });
    const s = await runListenAndRetake([line(0), line(1), line(2), line(3)], "te", d);
    expect(s.retakesTried).toBe(1);
    expect(s.retakesKept).toBe(0);
    expect(kept).toEqual([]);
  });

  test("no budget left → no paid retake", async () => {
    const { d } = deps({ take_1: '{"score":1,"faults":[{"type":"garbled"}]}' }, 0);
    const s = await runListenAndRetake([line(0), line(1), line(2), line(3)], "te", d);
    expect(s.refusedForBudget).toBe(1);
    expect(s.retakesTried).toBe(0);
  });

  test("unreadable Gemini replies change nothing", async () => {
    const { d, kept } = deps({ take_0: "???", take_1: "???" });
    const s = await runListenAndRetake([line(0), line(1)], "te", d);
    expect(s.unreadable).toBe(2);
    expect(s.retakesTried).toBe(0);
    expect(kept).toEqual([]);
  });
});
