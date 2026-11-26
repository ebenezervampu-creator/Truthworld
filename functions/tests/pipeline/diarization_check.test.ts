/**
 * Diarization check: correct AssemblyAI speaker labels before voices are assigned.
 * Regression case from Clip 2 (2026-11-19): 5 turns, 2 AssemblyAI labels, 3 characters.
 *   T0 guard (A) | T1 Joseph (B) | T2 Joseph (labelled A) | T3 Joseph (B) | T4 prisoner (labelled A)
 */
jest.mock("../../src/pipeline/utils/logger", () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() } }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexAI: jest.fn(), getVertexClient: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-utils", () => ({
  extractCandidateText: jest.fn(),
  normalizeToGcsUri: (u: string) => (u.startsWith("gs://") ? u : null),
}), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: { GEMINI_MODEL: "test-model" } }), { virtual: true });

import { reconcileDiarization, relabelByOverlap, summarizeDiarization } from "../../src/pipeline/services/diarization-reconcile";
import {
  buildDiarizationPrompt,
  DiarizationCheckService,
  diarizationModel,
  buildPlausibilityPrompt,
  parseDiarizationVerdicts,
  recheckTranscriptTurn,
} from "../../src/pipeline/services/diarization-check";

const clip2Turns = [
  { id: "0", label: "A", durationMs: 6550 }, // guard
  { id: "1", label: "B", durationMs: 1620 }, // Joseph
  { id: "2", label: "A", durationMs: 2170 }, // Joseph, mislabelled
  { id: "3", label: "B", durationMs: 2760 }, // Joseph
  { id: "4", label: "A", durationMs: 1010 }, // prisoner, mislabelled
];
const clip2Verdicts = [
  { id: "0", character: "C1", confidence: 0.95 }, // guard
  { id: "1", character: "C2", confidence: 0.9 },  // Joseph
  { id: "2", character: "C2", confidence: 0.92 },
  { id: "3", character: "C2", confidence: 0.93 },
  { id: "4", character: "C3", confidence: 0.88 }, // prisoner
];

describe("reconcileDiarization", () => {
  test("Clip 2: Joseph ends up on one label, the prisoner on his own, the guard keeps A", () => {
    const r = reconcileDiarization(clip2Turns, clip2Verdicts);
    expect(r.applied).toBe(true);
    expect([...r.labels.entries()]).toEqual([
      ["0", "A"],
      ["1", "B"],
      ["2", "B"],
      ["3", "B"],
      ["4", "A_2"],
    ]);
    expect(r.changes).toEqual([
      { id: "2", from: "A", to: "B", character: "C2" },
      { id: "4", from: "A", to: "A_2", character: "C3" },
    ]);
    expect(new Set(r.labels.values()).size).toBe(3);
  });

  test("merges two labels that are the same person", () => {
    const turns = [
      { id: "0", label: "A", durationMs: 3000 },
      { id: "1", label: "B", durationMs: 2000 },
      { id: "2", label: "C", durationMs: 2500 },
      { id: "3", label: "B", durationMs: 1000 },
    ];
    const verdicts = [
      { id: "0", character: "C1", confidence: 0.9 },
      { id: "1", character: "C2", confidence: 0.9 },
      { id: "2", character: "C2", confidence: 0.9 },
      { id: "3", character: "C2", confidence: 0.9 },
    ];
    const r = reconcileDiarization(turns, verdicts);
    expect(r.applied).toBe(true);
    expect(r.labels.get("2")).toBe("B"); // C folded into B (B has 3 s, C 2.5 s)
    expect(new Set(r.labels.values())).toEqual(new Set(["A", "B"]));
  });

  test("low-confidence turns keep AssemblyAI's label", () => {
    const verdicts = clip2Verdicts.map((v) => (v.id === "4" ? { ...v, confidence: 0.4 } : v));
    const r = reconcileDiarization(clip2Turns, verdicts);
    expect(r.labels.get("4")).toBe("A");
    expect(r.labels.get("2")).toBe("B");
  });

  test("too few confident verdicts → nothing changes", () => {
    const r = reconcileDiarization(clip2Turns, clip2Verdicts.slice(0, 2));
    expect(r.applied).toBe(false);
    expect(r.changes).toEqual([]);
    expect(r.labels.get("2")).toBe("A");
  });

  test("never collapses several AssemblyAI speakers into one voice", () => {
    const allSame = clip2Verdicts.map((v) => ({ ...v, character: "C1" }));
    const r = reconcileDiarization(clip2Turns, allSame);
    expect(r.applied).toBe(false);
    expect(r.reason).toMatch(/collapse/);
  });

  test("labels that already match → not applied, no changes", () => {
    const turns = [
      { id: "0", label: "A", durationMs: 2000 },
      { id: "1", label: "B", durationMs: 2000 },
    ];
    const r = reconcileDiarization(turns, [
      { id: "0", character: "C1", confidence: 0.9 },
      { id: "1", character: "C2", confidence: 0.9 },
    ]);
    expect(r.applied).toBe(false);
    expect(r.changes).toEqual([]);
  });

  test("unknown turn ids and empty characters are ignored", () => {
    const r = reconcileDiarization(clip2Turns, [
      ...clip2Verdicts,
      { id: "99", character: "C9", confidence: 1 },
      { id: "0", character: "", confidence: 1 },
    ]);
    expect(r.labels.has("99")).toBe(false);
    expect(r.labels.get("0")).toBe("A");
  });
});

describe("relabelByOverlap", () => {
  test("utterances take the corrected label of the segment they overlap most", () => {
    const utterances = [
      { start: 2180, end: 8730, speaker: "A", text: "guard" },
      { start: 12980, end: 15150, speaker: "A", text: "joseph" },
      { start: 28640, end: 29650, speaker: "A", text: "prisoner" },
      { start: 40000, end: 41000, speaker: "A", text: "no segment" },
    ];
    const segments = [
      { start: 2180, end: 8730, speaker: "A" },
      { start: 12980, end: 15150, speaker: "B" },
      { start: 28640, end: 29650, speaker: "A_2" },
    ];
    expect(relabelByOverlap(utterances, segments).map((u) => u.speaker)).toEqual(["A", "B", "A_2", "A"]);
  });
});

describe("DiarizationCheckService", () => {
  const turns = [
    { index: 0, start: 2180, end: 8730, speaker: "A", text: "Pharaoh is angry with his baker and cupbearer." },
    { index: 1, start: 8730, end: 10350, speaker: "B", text: "I'll do as you say." },
    { index: 2, start: 12980, end: 15150, speaker: "A", text: "Don't worry, we'll take good care of you here." },
    { index: 3, start: 25880, end: 28640, speaker: "B", text: "What's wrong? Why do you look sad today?" },
    { index: 4, start: 28640, end: 29650, speaker: "A", text: "We've had a dream." },
  ];
  const geminiReply = JSON.stringify({
    characters: [{ id: "C1", description: "guard" }, { id: "C2", description: "Joseph" }, { id: "C3", description: "prisoner" }],
    turns: clip2Verdicts.map((v) => ({ id: `T${v.id}`, character: v.character, confidence: v.confidence })),
  });

  test("end to end with a fake Gemini: Clip 2 is corrected to 3 voices", async () => {
    const generate = jest.fn().mockResolvedValue("```json\n" + geminiReply + "\n```");
    const r = await new DiarizationCheckService(generate).check("job", "gs://bucket/clip2.mp4", turns);
    expect(generate).toHaveBeenCalledTimes(1);
    expect(generate.mock.calls[0][0].videoUri).toBe("gs://bucket/clip2.mp4");
    expect(r.applied).toBe(true);
    expect(r.labels.get("2")).toBe("B");
    expect(r.labels.get("4")).toBe("A_2");
  });

  test("Gemini failure or unreadable video keeps AssemblyAI labels and never throws", async () => {
    const failing = new DiarizationCheckService(jest.fn().mockRejectedValue(new Error("quota")));
    const r1 = await failing.check("job", "gs://bucket/clip2.mp4", turns);
    expect(r1.applied).toBe(false);
    expect(r1.labels.get("2")).toBe("A");

    const notGcs = new DiarizationCheckService(jest.fn());
    const r2 = await notGcs.check("job", "https://example.com/clip.mp4", turns);
    expect(r2.applied).toBe(false);
    expect(r2.reason).toMatch(/Cloud Storage/);
  });

  test("garbage replies parse to no verdicts", () => {
    expect(parseDiarizationVerdicts("no json here")).toEqual([]);
    expect(parseDiarizationVerdicts("{bad json")).toEqual([]);
    expect(parseDiarizationVerdicts('{"turns":"nope"}')).toEqual([]);
  });

  test("prompt lists every turn with its time and current label, and asks Gemini to ignore the labels", () => {
    const prompt = buildDiarizationPrompt(turns);
    expect(prompt).toContain("T2 | 00:13.0–00:15.2 | label A |");
    expect(prompt).toMatch(/Do not trust the existing labels/);
  });
});

describe("diarization summary (what the check did, stored on the job)", () => {
  // Minute 1–2 of the test video (24 Nov, 11:49 run): AssemblyAI gave every line one label.
  const allA = ["A", "A", "A", "A", "A", "A"];

  it("a split of one AssemblyAI speaker into three is reported as 1 → 3", () => {
    const turns = allA.map((label, i) => ({ id: String(i), label, durationMs: 2000 }));
    const verdicts = [
      { id: "0", character: "C1", confidence: 0.9 }, // father
      { id: "1", character: "C2", confidence: 0.9 }, // son
      { id: "2", character: "C1", confidence: 0.9 },
      { id: "3", character: "C3", confidence: 0.85 }, // antagonist
      { id: "4", character: "C3", confidence: 0.9 },
      { id: "5", character: "C1", confidence: 0.9 },
    ];
    const result = reconcileDiarization(turns, verdicts);
    const summary = summarizeDiarization(allA, result);
    expect(summary).toEqual({ speakersBefore: 1, speakersAfter: 3, applied: true, reason: result.reason, changedTurns: 3 });
  });

  it("an unsure Gemini answer leaves AssemblyAI's count and says why", () => {
    const turns = allA.map((label, i) => ({ id: String(i), label, durationMs: 2000 }));
    const verdicts = allA.map((_, i) => ({ id: String(i), character: i % 2 ? "C2" : "C1", confidence: 0.4 }));
    const summary = summarizeDiarization(allA, reconcileDiarization(turns, verdicts));
    expect(summary.speakersBefore).toBe(1);
    expect(summary.speakersAfter).toBe(1);
    expect(summary.applied).toBe(false);
    expect(summary.reason).toMatch(/only 0\/6 turns identified/);
    expect(summary.changedTurns).toBe(0);
  });

  it("reads labels from a cached (JSON) result as well as from a Map", () => {
    const cached = { applied: true, reason: "2 turn(s) relabelled", labels: { "0": "A", "1": "A_2", "2": "B" }, changes: [{}, {}] };
    expect(summarizeDiarization(["A", "A", "B"], cached)).toEqual({ speakersBefore: 2, speakersAfter: 3, applied: true, reason: "2 turn(s) relabelled", changedTurns: 2 });
  });

  it("the model can be overridden with GEMINI_MODEL_DIARIZATION; the default is unchanged", () => {
    const before = process.env.GEMINI_MODEL_DIARIZATION;
    delete process.env.GEMINI_MODEL_DIARIZATION;
    expect(diarizationModel()).toBe("test-model");
    process.env.GEMINI_MODEL_DIARIZATION = "gemini-3.8-flash";
    expect(diarizationModel()).toBe("gemini-3.8-flash");
    if (before === undefined) delete process.env.GEMINI_MODEL_DIARIZATION;
    else process.env.GEMINI_MODEL_DIARIZATION = before;
  });
});

describe("Transcript plausibility check (class A)", () => {
  test("a line flagged by the check is re-transcribed only when Gemini returns high confidence; numbers in a line are never changed", async () => {
    const turn = { index: 0, start: 0, end: 2000, speaker: "A", text: "Every time you walk into school" };

    // Case 1: High confidence, no numbers changed -> accepted
    const genHighConf = jest.fn().mockResolvedValue(
      JSON.stringify({ correctedText: "Every time you walk him to school", confidence: 0.92, reason: "Acoustic correction" })
    );
    const res1 = await recheckTranscriptTurn("gs://bucket/vid.mp4", "video/mp4", turn, undefined, undefined, {
      generateFn: genHighConf,
    });
    expect(res1.accepted).toBe(true);
    expect(res1.correctedText).toBe("Every time you walk him to school");

    // Case 2: Low confidence (< 0.85) -> rejected
    const genLowConf = jest.fn().mockResolvedValue(
      JSON.stringify({ correctedText: "Every time you walk him to school", confidence: 0.70, reason: "Unsure" })
    );
    const res2 = await recheckTranscriptTurn("gs://bucket/vid.mp4", "video/mp4", turn, undefined, undefined, {
      generateFn: genLowConf,
    });
    expect(res2.accepted).toBe(false);
    expect(res2.reason).toBe("confidence below threshold");

    // Case 3: Numbers changed -> rejected!
    const turnWithNumbers = { index: 1, start: 2000, end: 4000, speaker: "A", text: "He has 5 cars" };
    const genChangedNums = jest.fn().mockResolvedValue(
      JSON.stringify({ correctedText: "He has 6 cars", confidence: 0.95, reason: "Heard six" })
    );
    const res3 = await recheckTranscriptTurn("gs://bucket/vid.mp4", "video/mp4", turnWithNumbers, undefined, undefined, {
      generateFn: genChangedNums,
    });
    expect(res3.accepted).toBe(false);
    expect(res3.reason).toBe("numbers changed");
  });
});

describe("Transcript recheck inside the diarization check (2026-11-24: dedicated plausibility pass)", () => {
  const turns = [
    { index: 0, start: 0, end: 2000, speaker: "A", text: "Why does it feel so wrong to lie to him?" },
    { index: 1, start: 2000, end: 4000, speaker: "B", text: "Every time you walk into school," },
    { index: 2, start: 4000, end: 6000, speaker: "B", text: "Or kiss him goodnight?" },
  ];
  const diarizationReply = JSON.stringify({
    characters: [{ id: "C1", description: "man" }, { id: "C2", description: "woman" }],
    turns: [
      { id: "T0", character: "C1", confidence: 0.9 },
      { id: "T1", character: "C2", confidence: 0.9 },
      { id: "T2", character: "C2", confidence: 0.9 },
    ],
  });

  test("the plausibility prompt lists every turn and asks only for misheard words", () => {
    const p = buildPlausibilityPrompt(turns);
    expect(p).toContain('T1 | 00:02');
    expect(p).toContain("walk into school");
    expect(p).toContain('"flagged_turns"');
  });

  test("recheck on: a turn flagged by the dedicated pass is re-heard and corrected even when labels are unchanged", async () => {
    const before = process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK;
    process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK = "true";
    try {
      const generate = jest.fn()
        .mockResolvedValueOnce(diarizationReply) // diarization (flags nothing)
        .mockResolvedValueOnce(JSON.stringify({ flagged_turns: [{ id: "T1", reason: "into vs him to" }] })) // plausibility pass
        .mockResolvedValueOnce(JSON.stringify({ correctedText: "Every time you walk him to school,", confidence: 0.93 })); // recheck
      const r = await new DiarizationCheckService(generate).check("job", "gs://bucket/clip.mp4", turns.map((t) => ({ ...t })));
      expect(generate).toHaveBeenCalledTimes(3);
      expect(r.applied).toBe(false);
      const corrections = r.textCorrections as Map<string, string>;
      expect(corrections.get("1")).toBe("Every time you walk him to school,");
    } finally {
      if (before === undefined) delete process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK;
      else process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK = before;
    }
  });

  test("recheck off: one Gemini call, no corrections", async () => {
    const before = process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK;
    delete process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK;
    try {
      const generate = jest.fn().mockResolvedValue(diarizationReply);
      const r = await new DiarizationCheckService(generate).check("job", "gs://bucket/clip.mp4", turns.map((t) => ({ ...t })));
      expect(generate).toHaveBeenCalledTimes(1);
      expect(r.textCorrections && (r.textCorrections as Map<string, string>).size).toBeFalsy();
    } finally {
      if (before !== undefined) process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK = before;
    }
  });
});
