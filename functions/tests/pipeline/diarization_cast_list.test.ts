/**
 * Cast list, cross-window character anchors, and the turn limit for long videos.
 * See cast-list.ts and diarization-check.ts.
 */
jest.mock("../../src/pipeline/utils/logger", () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() } }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexAI: jest.fn(), getVertexClient: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-utils", () => ({
  extractCandidateText: jest.fn(),
  normalizeToGcsUri: (u: string) => (u.startsWith("gs://") ? u : null),
}), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: { GEMINI_MODEL: "test-model" } }), { virtual: true });

import { assemblySpeakerOptions } from "../../src/pipeline/services/assembly-speaker-options";
import { castRoster, parseCastList, parseExpectedSpeakers, speakerHintFor, MAX_CAST } from "../../src/pipeline/services/cast-list";
import {
  buildDiarizationPrompt,
  DiarizationCheckService,
  MAX_REFERENCE_CLIPS,
  MAX_TURNS,
  MAX_TURNS_CEILING,
  maxTurnsForJob,
  pickReferences,
  recordAnchors,
  WINDOW_TURNS,
  type CheckTurn,
} from "../../src/pipeline/services/diarization-check";

const josephCast = [
  { name: "Wise Men", gender: "male", description: "group of robed advisers" },
  { name: "Pharaoh", gender: "male", description: "king, gold headdress, deep voice", appearsAtSec: 4.8 },
  { name: "Cupbearer", gender: "male", description: "young servant" },
  { name: "Guard", gender: "male", description: "armoured soldier, harsh voice" },
];

describe("parseCastList", () => {
  test("keeps valid entries and cleans them", () => {
    const cast = parseCastList([
      { name: "  Pharaoh  ", gender: "MALE", description: "king", appearsAtSec: "4.84" },
      { name: "pharaoh" },                       // duplicate name
      { name: "", gender: "female" },            // no name
      null,
      "Guard",                                   // not an object
      { name: "Guard", gender: "robot", appearsAtSec: -3 },
    ]);
    expect(cast).toEqual([
      { name: "Pharaoh", gender: "male", description: "king", appearsAtSec: 4.8 },
      { name: "Guard" },
    ]);
  });

  test("non-lists and oversized lists are bounded", () => {
    expect(parseCastList(undefined)).toEqual([]);
    expect(parseCastList({ name: "x" })).toEqual([]);
    const many = Array.from({ length: MAX_CAST + 20 }, (_, i) => ({ name: `P${i}` }));
    expect(parseCastList(many)).toHaveLength(MAX_CAST);
  });
});

describe("speaker count from the creator or the cast list", () => {
  test("parseExpectedSpeakers accepts a number or {min,max}", () => {
    expect(parseExpectedSpeakers(4)).toEqual({ min: 4, max: 4 });
    expect(parseExpectedSpeakers("3")).toEqual({ min: 3, max: 3 });
    expect(parseExpectedSpeakers({ min: 4, max: 2 })).toEqual({ min: 4, max: 4 });
    expect(parseExpectedSpeakers({ max: 6 })).toEqual({ max: 6 });
    expect(parseExpectedSpeakers(0)).toBeUndefined();
    expect(parseExpectedSpeakers("abc")).toBeUndefined();
    expect(parseExpectedSpeakers({})).toBeUndefined();
  });

  test("Joseph clip: a 4-person cast sends AssemblyAI a floor of 4 (was: only a cap of 12)", () => {
    const cast = parseCastList(josephCast);
    expect(assemblySpeakerOptions(25.4, speakerHintFor(undefined, cast), true)).toEqual({
      min_speakers_expected: 4,
      max_speakers_expected: 6,
    });
    // Without a cast or a count, unchanged behaviour: cap only, no floor.
    expect(assemblySpeakerOptions(25.4, speakerHintFor(undefined, []), true)).toEqual({ max_speakers_expected: 12 });
  });

  test("an explicit count wins over the cast list", () => {
    const cast = parseCastList(josephCast);
    expect(speakerHintFor({ min: 2, max: 3 }, cast)).toEqual({ min: 2, max: 3 });
  });
});

describe("prompt with a cast list", () => {
  const turns: CheckTurn[] = [{ index: 0, start: 340, end: 2510, speaker: "A", text: "but we cannot interpret your dreams." }];

  test("cast ids C1..Cn are listed, and new people start after them", () => {
    const roster = castRoster(parseCastList(josephCast)).map((c) => ({ id: c.id, description: c.description }));
    const prompt = buildDiarizationPrompt(turns, roster, { fromCast: roster.length });
    expect(prompt).toContain("Cast list from the creator");
    expect(prompt).toContain("C2: Pharaoh — male — king, gold headdress, deep voice");
    expect(prompt).toContain("starting at C5");
    expect(prompt).not.toContain("Characters already identified earlier");
  });

  test("without a cast the prompt is unchanged in substance", () => {
    expect(buildDiarizationPrompt(turns)).not.toMatch(/Cast list|Reference clips|reference clips/);
  });
});

describe("anchors and reference clips", () => {
  test("first confident turn of at least 0.8 s becomes the anchor, capped at 4 s", () => {
    const anchors = new Map<string, { startMs: number; endMs: number }>();
    const talk = new Map<string, number>();
    const turnByIndex = new Map([
      ["0", { start: 1000, end: 1500 }],   // too short
      ["1", { start: 2000, end: 9000 }],   // long, capped
      ["2", { start: 10000, end: 12000 }], // low confidence
    ]);
    recordAnchors(
      [
        { id: "0", character: "C1", confidence: 0.95 },
        { id: "1", character: "C1", confidence: 0.9 },
        { id: "2", character: "C2", confidence: 0.6 },
      ],
      turnByIndex,
      anchors,
      talk
    );
    expect(anchors.get("C1")).toEqual({ startMs: 2000, endMs: 6000 });
    expect(anchors.has("C2")).toBe(false);
    expect(talk.get("C1")).toBe(7500);
  });

  test("clips inside the window are not repeated; most-heard first; bounded", () => {
    const anchors = new Map<string, { startMs: number; endMs: number }>();
    const talk = new Map<string, number>();
    for (let i = 1; i <= MAX_REFERENCE_CLIPS + 3; i++) {
      anchors.set(`C${i}`, { startMs: i * 10_000, endMs: i * 10_000 + 3000 });
      talk.set(`C${i}`, i);
    }
    anchors.set("C99", { startMs: 500_000, endMs: 503_000 }); // inside the window
    talk.set("C99", 1e9);
    const refs = pickReferences(anchors, talk, new Map([["C11", "Pharaoh"]]), [], 490, 600);
    expect(refs).toHaveLength(MAX_REFERENCE_CLIPS);
    expect(refs.map((r) => r.id)).not.toContain("C99");
    expect(refs[0]).toEqual({ id: "C11", label: "Pharaoh", startOffsetSec: 110, endOffsetSec: 113 });
  });
});

describe("DiarizationCheckService on a long video", () => {
  // 2 windows: turns 0..79 (0–400 s) and 80..159 (400–800 s), alternating A/B labels.
  const longTurns: CheckTurn[] = Array.from({ length: WINDOW_TURNS * 2 }, (_, i) => ({
    index: i,
    start: i * 5000,
    end: i * 5000 + 4000,
    speaker: i % 2 === 0 ? "A" : "B",
    text: `line ${i}`,
  }));
  const reply = (win: CheckTurn[]) =>
    JSON.stringify({
      characters: [{ id: "C5", description: "unlisted shopkeeper" }],
      turns: win.map((t) => ({ id: `T${t.index}`, character: t.index % 2 === 0 ? "C2" : "C5", confidence: 0.95 })),
    });

  test("cast seeds the roster; window 2 is shown reference clips found in window 1", async () => {
    const generate = jest.fn().mockImplementation(async ({ prompt }: { prompt: string }) => {
      const ids = [...prompt.matchAll(/^T(\d+) \|/gm)].map((m) => Number(m[1]));
      return reply(longTurns.filter((t) => ids.includes(t.index)));
    });
    const cast = parseCastList(josephCast.map(({ appearsAtSec: _drop, ...rest }) => rest));
    const r = await new DiarizationCheckService(generate).check("job", "gs://b/film.mp4", longTurns, { cast });

    expect(generate).toHaveBeenCalledTimes(2);
    const first = generate.mock.calls[0][0];
    expect(first.prompt).toContain("C2: Pharaoh");
    expect(first.references).toBeUndefined(); // nothing anchored yet, no cast timestamps

    const second = generate.mock.calls[1][0];
    expect(second.references.map((x: any) => x.id).sort()).toEqual(["C2", "C5"]);
    expect(second.references.find((x: any) => x.id === "C2")).toMatchObject({ label: "Pharaoh", startOffsetSec: 0, endOffsetSec: 4 });
    expect(second.prompt).toMatch(/reference clips, in this order: .*C2 \(Pharaoh\) at 00:00.0/);
    expect(second.prompt).toContain("C5: unlisted shopkeeper"); // discovered, kept for later windows
    expect(r.labels.size).toBe(longTurns.length);
  });

  test("a cast timestamp is a reference clip from the first window on", async () => {
    const generate = jest.fn().mockResolvedValue(reply([]));
    const turns = longTurns.map((t) => ({ ...t, start: t.start + 60_000, end: t.end + 60_000 })); // video starts at 60 s
    await new DiarizationCheckService(generate).check("job", "gs://b/film.mp4", turns, { cast: parseCastList(josephCast) });
    expect(generate.mock.calls[0][0].references).toEqual([{ id: "C2", label: "Pharaoh", startOffsetSec: 4.8, endOffsetSec: 8.8 }]);
  });

  test("turn limit: default stops at MAX_TURNS; long-form jobs check further", async () => {
    const many: CheckTurn[] = Array.from({ length: MAX_TURNS + 200 }, (_, i) => ({
      index: i, start: i * 3000, end: i * 3000 + 2000, speaker: "A", text: "x",
    }));
    const g1 = jest.fn().mockResolvedValue("{}");
    await new DiarizationCheckService(g1).check("job", "gs://b/f.mp4", many);
    expect(g1).toHaveBeenCalledTimes(Math.ceil(MAX_TURNS / WINDOW_TURNS));

    const g2 = jest.fn().mockResolvedValue("{}");
    await new DiarizationCheckService(g2).check("job", "gs://b/f.mp4", many, { maxTurns: maxTurnsForJob({ durationSec: 7200 }) });
    expect(g2).toHaveBeenCalledTimes(Math.ceil(many.length / WINDOW_TURNS));
  });

  test("maxTurnsForJob", () => {
    expect(maxTurnsForJob({ durationSec: 600 })).toBe(MAX_TURNS);
    expect(maxTurnsForJob({ durationSec: 1800 })).toBe(MAX_TURNS_CEILING);
    expect(maxTurnsForJob({ cinemaGrade: true })).toBe(MAX_TURNS_CEILING);
    expect(maxTurnsForJob({ isReelJob: true, durationSec: 900 })).toBe(MAX_TURNS_CEILING);
    expect(maxTurnsForJob({})).toBe(MAX_TURNS);
  });
});
