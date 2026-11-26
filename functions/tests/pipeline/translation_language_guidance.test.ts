/**
 * Translation prompt guidance per target language (24 Nov 2026).
 *
 * Regression: a language without a reviewed LANGUAGE_GUIDES entry (kn, bn, gu, es, fr, …) was sent the
 * Telugu and Hindi address rules and Telugu examples ("In Telugu, use మీరు…", "Prabhuva"). It now gets
 * a language-neutral rule naming its own language. Reviewed languages (te, hi, mr, ta, ml) are unchanged.
 * Also: glossary terms carry their sense, so "Lord" in a superhero film is not forced to the religious term.
 */
import {
  GeminiDubbingEditor,
  configuredSyllablesPerSecond,
  languageGuidance,
  languageName,
  type EditorOptions,
  type EditorSegment,
} from "../../src/pipeline/services/geminiDubbingEditor";
import { countSourceSyllables } from "../../src/pipeline/services/translation";

const TELUGU_SCRIPT = /[ఀ-౿]/;
const DEVANAGARI = /[ऀ-ॿ]/;

function capture() {
  const calls: Array<{ system: string; prompt: any }> = [];
  const fn = async ({ system, prompt }: { model: string; system: string; prompt: string }) => {
    const parsed = JSON.parse(prompt);
    calls.push({ system, prompt: parsed });
    return { text: JSON.stringify({ lines: (parsed.lines || []).map((l: any) => ({ id: l.id, text: l.draft })) }), inputTokens: 0, outputTokens: 0 };
  };
  return { fn, calls };
}

describe("language guidance for languages without a reviewed guide", () => {
  test.each(["kn", "bn", "gu", "es", "fr", "sv"])("%s gets no Telugu or Hindi rules or examples", (lang) => {
    const g = JSON.stringify(languageGuidance(lang));
    expect(g).not.toMatch(TELUGU_SCRIPT);
    expect(g).not.toMatch(DEVANAGARI);
    expect(g).not.toMatch(/Telugu|Hindi|Prabhuva/);
    expect(g).toContain(languageName(lang));
  });

  test("reviewed languages keep their own guidance", () => {
    expect(JSON.stringify(languageGuidance("te"))).toContain("మీరు");
    expect(JSON.stringify(languageGuidance("hi"))).toContain("आप");
    expect(JSON.stringify(languageGuidance("ta"))).toContain("நீங்கள்");
    expect(JSON.stringify(languageGuidance("ml"))).toContain("നിങ്ങൾ");
  });

  test("language names come from ICU for codes outside the table, never a bare code", () => {
    expect(languageName("te")).toBe("Telugu");
    expect(languageName("sv")).toBe("Swedish");
    expect(languageName("pl-PL")).toBe("Polish");
  });

  test("the Kannada dubbing prompt sent to Gemini contains no Telugu or Hindi", async () => {
    const { fn, calls } = capture();
    const opts: EditorOptions = { jobId: "j", sourceLanguage: "en", targetLanguage: "kn", countSyllables: countSourceSyllables };
    const segments: EditorSegment[] = [
      { id: "L1", source: "Are you coming with us?", draft: "ನೀವು ನಮ್ಮ ಜೊತೆ ಬರುತ್ತೀರಾ?", speaker: "A", maxSyllables: 20 },
      { id: "L2", source: "Yes, I am.", draft: "ಹೌದು, ಬರುತ್ತೇನೆ.", speaker: "B", maxSyllables: 20 },
    ];
    await new GeminiDubbingEditor(fn).editSegments(segments, opts);
    expect(calls.length).toBeGreaterThan(0);
    for (const c of calls) {
      expect(c.system).not.toMatch(TELUGU_SCRIPT);
      expect(c.system).not.toMatch(/In Telugu|In Hindi/);
    }
    expect(calls.some((c) => c.system.includes("Kannada"))).toBe(true);
  });
});

describe("glossary terms carry their sense", () => {
  test("the sense reaches Gemini, and the rule applies the term only in that sense", async () => {
    const { fn, calls } = capture();
    const opts: EditorOptions = {
      jobId: "j",
      sourceLanguage: "en",
      targetLanguage: "te",
      countSyllables: countSourceSyllables,
      glossary: [{ source: "Lord", target: "ప్రభువు", sense: "religion (God, scripture, faith)" }],
    };
    const segments: EditorSegment[] = [
      { id: "L1", source: "The Lord of Thunder has returned.", draft: "ఉరుముల ప్రభువు తిరిగి వచ్చాడు.", speaker: "A", maxSyllables: 30 },
      { id: "L2", source: "Run.", draft: "పరుగెత్తు.", speaker: "A", maxSyllables: 10 },
    ];
    await new GeminiDubbingEditor(fn).editSegments(segments, opts);
    const edit = calls.find((c) => Array.isArray(c.prompt.glossary) && c.prompt.glossary.length > 0);
    expect(edit?.prompt.glossary[0]).toEqual({ source: "Lord", target: "ప్రభువు", sense: "religion (God, scripture, faith)" });
    expect(edit?.system).toMatch(/in the glossary's sense/);
  });
});

describe("speaking rate used for the syllable budget", () => {
  test("is exposed for the measured-rate log", () => {
    expect(configuredSyllablesPerSecond("te")).toBe(4.8);
    expect(configuredSyllablesPerSecond("ta-IN")).toBe(6.5);
    expect(configuredSyllablesPerSecond("xx")).toBe(5.2);
  });
});

describe("third-person reference register (class B)", () => {
  test("te includes third-person rule and Telugu examples, kn gets neutral rule and no Telugu script", () => {
    const teGuide = languageGuidance("te");
    expect(teGuide.thirdPerson).toContain("When a speaker talks ABOUT someone");
    expect(teGuide.thirdPerson).toContain("వాడు / వాడికి / వాణ్ణి");
    expect(teGuide.thirdPerson).toContain("అది / దానికి");
    expect(teGuide.thirdPerson).toContain("అతను / ఆయన");

    const knGuide = languageGuidance("kn");
    expect(knGuide.thirdPerson).toContain("When a speaker talks ABOUT someone");
    expect(knGuide.thirdPerson).not.toMatch(TELUGU_SCRIPT);
  });
});

describe("delivery and emotion in editor prompt (class C)", () => {
  test("prompt includes each line's delivery when given, and is unchanged when it isn't", async () => {
    const { fn: fn1, calls: calls1 } = capture();
    const opts: EditorOptions = { jobId: "j", sourceLanguage: "en", targetLanguage: "te", countSyllables: countSourceSyllables };

    const withDelivery: EditorSegment[] = [
      { id: "L1", source: "Uh-oh.", draft: "అయ్యో!", speaker: "A", delivery: "playful", maxSyllables: 5 },
      { id: "L2", source: "I knew it.", draft: "నాకు తెలుసు.", speaker: "B", maxSyllables: 10 },
    ];
    await new GeminiDubbingEditor(fn1).editSegments(withDelivery, opts);
    const editCall1 = calls1.find((c) => c.prompt.lines && c.prompt.lines[0]?.draft);
    expect(editCall1?.prompt.lines[0].delivery).toBe("playful");
    expect(editCall1?.prompt.lines[1]).not.toHaveProperty("delivery");
    expect(editCall1?.system).toContain("Choose interjections, exclamations and sentence-final particles to match the line's delivery");

    const { fn: fn2, calls: calls2 } = capture();
    const withoutDelivery: EditorSegment[] = [
      { id: "L1", source: "Uh-oh.", draft: "అయ్యో!", speaker: "A", maxSyllables: 5 },
      { id: "L2", source: "I knew it.", draft: "నాకు తెలుసు.", speaker: "B", maxSyllables: 10 },
    ];
    await new GeminiDubbingEditor(fn2).editSegments(withoutDelivery, opts);
    const editCall2 = calls2.find((c) => c.prompt.lines && c.prompt.lines[0]?.draft);
    expect(editCall2?.prompt.lines[0]).not.toHaveProperty("delivery");
    expect(editCall2?.prompt.lines[1]).not.toHaveProperty("delivery");
  });
});

describe("Rule 12 literal-phrasing and redundant-marker clauses (classes D, E)", () => {
  test("includes literal phrasing, redundant markers, spoken style, and budget priority", async () => {
    const { fn, calls } = capture();
    const opts: EditorOptions = { jobId: "j", sourceLanguage: "en", targetLanguage: "te", countSyllables: countSourceSyllables };
    const segments: EditorSegment[] = [
      { id: "L1", source: "Hello", draft: "హలో", speaker: "A", maxSyllables: 5 },
    ];
    await new GeminiDubbingEditor(fn).editSegments(segments, opts);
    const system = calls[0].system;
    expect(system).toContain("Do not copy English word order, compounds or constructions literally");
    expect(system).toContain("do not stack redundant markers that say the same thing twice");
    expect(system).toContain("prefer the shorter spoken form a native film/YouTube dialogue writer would use");
    expect(system).toContain("if natural phrasing and the syllable budget conflict, the budget wins");
    expect(system).toContain("STRICTLY PRESERVE EVERY OBJECT AND PRONOUN from SOURCE");
  });
});

describe("Pronoun/referent preservation and cross-line continuation rules", () => {
  test("rules strictly prohibit dropping source pronouns/objects and standalone conversion of continuing clauses", async () => {
    const { fn, calls } = capture();
    const opts: EditorOptions = { jobId: "j", sourceLanguage: "en", targetLanguage: "te", countSyllables: countSourceSyllables };
    const segments: EditorSegment[] = [
      { id: "L1", source: "How's he ever gonna know who we are unless we tell him?", draft: "చెబితే తప్ప మనం ఎవరో తనకెలా తెలుస్తుంది?", speaker: "A", maxSyllables: 15 },
      { id: "L2", source: "Or kiss him goodnight?", draft: "లేదా గుడ్ నైట్ ముద్దు పెట్టినప్పుడా?", speaker: "B", maxSyllables: 10 },
    ];
    await new GeminiDubbingEditor(fn).editSegments(segments, opts);
    const system = calls.find((c) => c.prompt.lines && c.prompt.lines[0]?.draft)?.system;
    expect(system).toBeDefined();
    // Rule 3 pronoun preservation
    expect(system).toContain("Pronoun & Referent Preservation (CRITICAL): NEVER drop third-person pronouns or objects present in SOURCE");
    // Rule 8 cross-line continuation
    expect(system).toContain("Cross-Line Syntactic Continuation: When a line continues a preceding condition or clause");
    expect(system).toContain("NEVER convert a continuing clause into an independent standalone question");
    // Telugu spoken examples
    expect(system).toContain("లేదా వాడికి గుడ్ నైట్ చెప్పి ముద్దు పెట్టినప్పుడల్లా?");
    expect(system).toContain("మనం చెప్పకపోతే మనమెవరో వాడికి ఎలా తెలుస్తుంది?");
  });
});

describe("Guard test: no source-English to target-word mapping table", () => {
  test("src/ contains no hardcoded mappings for English interjections like 'Uh-oh' or target words", () => {
    const fs = require("fs");
    const path = require("path");
    const srcDir = path.resolve(__dirname, "../../src");

    function scanDir(dir: string): string[] {
      const results: string[] = [];
      const list = fs.readdirSync(dir);
      for (const file of list) {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat && stat.isDirectory()) {
          results.push(...scanDir(fullPath));
        } else if (file.endsWith(".ts")) {
          results.push(fullPath);
        }
      }
      return results;
    }

    const tsFiles = scanDir(srcDir);
    for (const file of tsFiles) {
      const content = fs.readFileSync(file, "utf8");
      // Remove comments
      const stripped = content.replace(/\/\*[\s\S]*?\*\/|\/\/.*/g, "");
      // Guard: no dictionary or mapping table mapping "Uh-oh" to target words
      expect(stripped).not.toMatch(/["']Uh-oh["']\s*:\s*["']/i);
      expect(stripped).not.toMatch(/case\s+["']Uh-oh["']/i);
    }
  });
});
