/**
 * Meaning check on spoken dub lines and the faithful-source rule (geminiDubbingEditor.ts, 2026-11-24).
 * Cases from the te test (version_4.mp4, reviewer 7.0/10):
 *   00:13 "Why does it feel so wrong to lie to him?" voiced as వాడికి అబద్ధం ఎందుకింత తప్పనిపిస్తోంది?
 *         ("telling" dropped — the feeling moves to the boy)
 *   00:33 "Or kiss him goodnight?" voiced as లేదా వాడికి గుడ్ నైట్ ముద్దిస్తే? ("if" instead of "whenever")
 * Zero-credit: Gemini is a fake generate function.
 */
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexClient: jest.fn(), getVertexAI: jest.fn() }), { virtual: true });

import {
  buildMeaningPrompt,
  buildMeaningSystem,
  faithfulSourceEnabled,
  FAITHFUL_SOURCE_RULE,
  GeminiDubbingEditor,
  MEANING_CHECK,
  meaningCheckEnabled,
  meaningFixLimit,
  parseMeaningReply,
  resolveMeaning,
  type EditorOptions,
  type EditorSegment,
} from "../../src/pipeline/services/geminiDubbingEditor";
import { countSourceSyllables } from "../../src/pipeline/services/translation";

const opts: EditorOptions = { jobId: "job_meaning", sourceLanguage: "en", targetLanguage: "te", countSyllables: countSourceSyllables };

const L013: EditorSegment = {
  id: "L1",
  source: "Why does it feel so wrong to lie to him?",
  draft: "వాడికి అబద్ధం చెప్పడం ఎందుకంత తప్పనిపిస్తోంది?",
  // 12820–15150 ms = 2.33 s → floor(2.33 × 4.8 × 1.1) = 12, the budget this line really had.
  maxSyllables: 12,
};
const DROPPED = "వాడికి అబద్ధం ఎందుకింత తప్పనిపిస్తోంది?";
const FIXED = "వాడికి అబద్ధం చెప్పడం ఎందుకింత తప్పనిపిస్తోంది?";

describe("flags", () => {
  test("meaning check and faithful-source rule are on unless set to false", () => {
    expect(meaningCheckEnabled({})).toBe(true);
    expect(meaningCheckEnabled({ DUBBING_MEANING_CHECK: "false" })).toBe(false);
    expect(faithfulSourceEnabled({})).toBe(true);
    expect(faithfulSourceEnabled({ DUBBING_FAITHFUL_SOURCE: "false" })).toBe(false);
  });
});

describe("parseMeaningReply", () => {
  test("reads verdicts, skips malformed entries", () => {
    const m = parseMeaningReply(
      '```json\n{"lines":[{"id":"L1","keeps_meaning":false,"problem":"telling dropped","fixed":"x","subtitle_keeps_meaning":true},{"id":"L2","keeps_meaning":true},{"id":"L3"}]}\n```'
    );
    expect(m.get("L1")).toEqual({ id: "L1", keepsMeaning: false, subtitleKeepsMeaning: true, problem: "telling dropped", fixed: "x" });
    expect(m.get("L2")?.keepsMeaning).toBe(true);
    expect(m.has("L3")).toBe(false);
  });
  test("unreadable reply → no verdicts (lines stay as they are)", () => {
    expect(parseMeaningReply("not json").size).toBe(0);
  });
});

describe("resolveMeaning", () => {
  test("a line that keeps its meaning is untouched", () => {
    expect(resolveMeaning(L013, { text: DROPPED }, { id: "L1", keepsMeaning: true }, opts)).toEqual({ text: DROPPED, action: "kept" });
  });

  test("00:13: the faithful fix (19 syllables; budget 12; voiced line 16) replaces the spoken line", () => {
    const r = resolveMeaning(L013, { text: DROPPED }, { id: "L1", keepsMeaning: false, problem: "telling dropped", fixed: FIXED }, opts);
    expect(r).toEqual({ text: FIXED, action: "fixed" });
  });

  test("a fix far over its limit falls back to the subtitle when Gemini says the subtitle keeps the meaning", () => {
    const tight = { ...L013, maxSyllables: 8 };
    const r = resolveMeaning(
      tight,
      { text: DROPPED, subtitleText: FIXED },
      { id: "L1", keepsMeaning: false, fixed: FIXED + " " + FIXED, subtitleKeepsMeaning: true },
      { ...opts, countSyllables: (t: string) => (t === FIXED ? 10 : t === DROPPED ? 9 : 100) }
    );
    expect(r).toEqual({ text: FIXED, action: "subtitle" });
  });

  test("nothing usable → unchanged, reported as unresolved", () => {
    const r = resolveMeaning(L013, { text: DROPPED, subtitleText: DROPPED }, { id: "L1", keepsMeaning: false, subtitleKeepsMeaning: false }, opts);
    expect(r).toEqual({ text: DROPPED, action: "unresolved" });
  });

  test("a fix that changes a number is rejected by the usual validator", () => {
    const seg: EditorSegment = { id: "L9", source: "It was tested on 4,000 people.", draft: "దీన్ని 4,000 మందిపై పరీక్షించారు.", maxSyllables: 30 };
    const r = resolveMeaning(seg, { text: "దీన్ని పరీక్షించారు." }, { id: "L9", keepsMeaning: false, fixed: "దీన్ని 5,000 మందిపై పరీక్షించారు." }, opts);
    expect(r.action).toBe("unresolved");
  });

  test("fix limit: the larger of budget × 1.3 and the current line + 25% (at least +3)", () => {
    expect(meaningFixLimit(12, 16)).toBe(20);
    expect(meaningFixLimit(20, 8)).toBe(26);
    expect(meaningFixLimit(10, 4)).toBe(13);
    expect(meaningFixLimit(undefined, 16)).toBeUndefined();
    expect(MEANING_CHECK.maxOverBudget).toBe(1.3);
  });
});

describe("prompts", () => {
  test("meaning prompt carries the previous line, so a continuation ('Or…') can be judged", () => {
    const p = JSON.parse(
      buildMeaningPrompt([
        { id: "L2", source: "Or kiss him goodnight?", spoken: "లేదా వాడికి గుడ్ నైట్ ముద్దిస్తే?", previousSource: "Every time you walk into school,", previousSpoken: "మీరు స్కూల్లోకి వెళ్లిన ప్రతిసారీ," },
      ])
    );
    expect(p.lines[0]).toMatchObject({ id: "L2", previous_source: "Every time you walk into school,", spoken: "లేదా వాడికి గుడ్ నైట్ ముద్దిస్తే?" });
  });

  test("meaning system names the meaning changes to look for and protects odd-but-clear sources", () => {
    const s = buildMeaningSystem(opts);
    expect(s).toContain("who does what to whom");
    expect(s).toContain("every time / whenever");
    expect(s).toContain("never treat an odd but clear source as an error");
    expect(s).not.toContain("\\n");
  });

  test("the faithful-source rule reaches the dubbing prompt, and is removed by its flag", async () => {
    const systems: string[] = [];
    const fake = async ({ system, prompt }: any) => {
      systems.push(system);
      const lines = JSON.parse(prompt).lines;
      return { text: JSON.stringify({ lines: lines.map((l: any) => ({ id: l.id, text: l.draft, keeps_meaning: true })) }), inputTokens: 0, outputTokens: 0 };
    };
    const seg: EditorSegment = { id: "L1", source: "Every time you walk into school,", draft: "మీరు స్కూల్లోకి వెళ్లిన ప్రతిసారీ,", maxSyllables: 20 };
    await new GeminiDubbingEditor(fake as any).editSegments([seg], opts);
    expect(systems[0]).toContain(FAITHFUL_SOURCE_RULE.trim());
    const prev = process.env.DUBBING_FAITHFUL_SOURCE;
    process.env.DUBBING_FAITHFUL_SOURCE = "false";
    try {
      systems.length = 0;
      await new GeminiDubbingEditor(fake as any).editSegments([seg], opts);
      expect(systems[0]).not.toContain("Faithful to what was said");
    } finally {
      if (prev === undefined) delete process.env.DUBBING_FAITHFUL_SOURCE;
      else process.env.DUBBING_FAITHFUL_SOURCE = prev;
    }
  });
});

describe("editSegments with the meaning check (fake Gemini)", () => {
  const segs: EditorSegment[] = [
    L013,
    { id: "L2", source: "How's he ever gonna know who we are unless we tell him?", draft: "చెబితే తప్ప మనం ఎవరో వాడికెలా తెలుస్తుంది?", maxSyllables: 20 },
  ];

  /** Editor call voices L1 without "telling"; the meaning call (identified by its schema) flags it. */
  function fake(meaning: (prompt: any) => any) {
    const calls: Array<{ kind: string; prompt: any }> = [];
    const fn = async ({ prompt, schema }: any) => {
      const p = JSON.parse(prompt);
      if (schema) {
        calls.push({ kind: "meaning", prompt: p });
        return { text: JSON.stringify(meaning(p)), inputTokens: 0, outputTokens: 0 };
      }
      calls.push({ kind: "edit", prompt: p });
      return {
        text: JSON.stringify({ lines: p.lines.map((l: any) => ({ id: l.id, text: l.id === "L1" ? DROPPED : l.draft })) }),
        inputTokens: 0,
        outputTokens: 0,
      };
    };
    return { fn, calls };
  }

  test("00:13 is fixed after the edit; the other line is left alone; one meaning call, last", async () => {
    const { fn, calls } = fake((p) => ({
      lines: p.lines.map((l: any) =>
        l.id === "L1" ? { id: "L1", keeps_meaning: false, problem: "telling dropped", fixed: FIXED } : { id: l.id, keeps_meaning: true }
      ),
    }));
    const out = await new GeminiDubbingEditor(fn as any).editSegments(segs, opts);
    expect(out[0].text).toBe(FIXED);
    expect(out[1].text).toBe(segs[1].draft);
    // The editor's own tighten pass may run first (L1 is over 1.15× its budget); the meaning check
    // runs once, last, on what would otherwise be spoken.
    const kinds = calls.map((c) => c.kind);
    expect(kinds.filter((k) => k === "meaning")).toHaveLength(1);
    expect(kinds[kinds.length - 1]).toBe("meaning");
    expect(calls[calls.length - 1].prompt.lines[0]).toMatchObject({ id: "L1", source: L013.source, spoken: DROPPED });
  });

  test("a failed meaning call leaves the edited lines unchanged", async () => {
    const { fn } = fake(() => {
      throw new Error("vertex down");
    });
    const out = await new GeminiDubbingEditor(fn as any).editSegments(segs, opts);
    expect(out[0].text).toBe(DROPPED);
  });

  test("off by flag: no meaning call", async () => {
    const prev = process.env.DUBBING_MEANING_CHECK;
    process.env.DUBBING_MEANING_CHECK = "false";
    try {
      const { fn, calls } = fake(() => ({ lines: [] }));
      await new GeminiDubbingEditor(fn as any).editSegments(segs, opts);
      expect(calls.some((c) => c.kind === "meaning")).toBe(false);
    } finally {
      if (prev === undefined) delete process.env.DUBBING_MEANING_CHECK;
      else process.env.DUBBING_MEANING_CHECK = prev;
    }
  });

  test("subtitle editing (purpose: subtitle) is meaning-checked across languages and skipped for same-language condense", async () => {
    const { fn, calls } = fake(() => ({ lines: [] }));
    await new GeminiDubbingEditor(fn as any).editSegments(
      segs.map((s) => ({ ...s, maxSyllables: undefined, maxCharacters: 60 })),
      { ...opts, purpose: "subtitle" }
    );
    expect(calls.some((c) => c.kind === "meaning")).toBe(true);

    calls.length = 0;
    await new GeminiDubbingEditor(fn as any).editSegments(
      segs.map((s) => ({ ...s, maxSyllables: undefined, maxCharacters: 60 })),
      { ...opts, sourceLanguage: "te", targetLanguage: "te", purpose: "subtitle" }
    );
    expect(calls.some((c) => c.kind === "meaning")).toBe(false);
  });
});
