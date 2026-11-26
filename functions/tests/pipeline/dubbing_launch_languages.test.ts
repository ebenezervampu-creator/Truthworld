/**
 * Dubbing v1.0 launch scope (2026-11-23): English source → Telugu, Hindi, Marathi, Tamil, Malayalam.
 *
 * Covers the launch-language rule shared by the quote, the order and the worker; the per-language
 * prompt guidance for the launch languages; and the honorific normalizer used by the editor's
 * drift check. Zero-credit: Gemini is replaced by an injected fake.
 */
import * as fs from "fs";
import * as path from "path";
import {
  checkDubbingRequest,
  dubbingLanguageMessage,
  dubbingLanguagesForClient,
  dubbingTargetLanguages,
  isDubbingSourceLanguage,
  isLaunchDubbingPair,
  launchUnsupportedNotice,
} from "../../src/pipeline/services/dubbing-launch-languages";
import {
  GeminiDubbingEditor,
  checkEditedLine,
  languageGuidance,
  normalizeHonorificsForBigram,
  type EditorOptions,
  type EditorSegment,
} from "../../src/pipeline/services/geminiDubbingEditor";
import { countSourceSyllables } from "../../src/pipeline/services/translation";

const LAUNCH_TARGETS = ["te", "hi", "mr", "ta", "ml"];

function withEnv(vars: Record<string, string | undefined>, fn: () => void) {
  const saved: Record<string, string | undefined> = {};
  for (const k of Object.keys(vars)) {
    saved[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    fn();
  } finally {
    for (const k of Object.keys(saved)) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

describe("Launch languages", () => {
  const clean = { DUBBING_SOURCE_LANGUAGES: undefined, DUBBING_TARGET_LANGUAGES: undefined };

  test("defaults: English source, five Indian targets", () => {
    withEnv(clean, () => {
      expect(dubbingLanguagesForClient()).toEqual({ sourceLanguages: ["en"], targetLanguages: LAUNCH_TARGETS });
      for (const t of LAUNCH_TARGETS) expect(isLaunchDubbingPair("en", t)).toBe(true);
      expect(isLaunchDubbingPair("en-US", "hi-IN")).toBe(true);
    });
  });

  test("refuses other targets, other sources and same-language pairs", () => {
    withEnv(clean, () => {
      for (const t of ["kn", "bn", "es", "fr", "ja", "am", "zu"]) expect(isLaunchDubbingPair("en", t)).toBe(false);
      for (const s of ["hi", "te", "ta", "es", ""]) expect(isDubbingSourceLanguage(s)).toBe(false);
      expect(isLaunchDubbingPair("hi", "te")).toBe(false);
      expect(isLaunchDubbingPair("en", "en")).toBe(false);
    });
  });

  test("checkDubbingRequest splits what can and can't be dubbed", () => {
    withEnv(clean, () => {
      expect(checkDubbingRequest("en", ["te", "mr"])).toEqual({ ok: true, sourceSupported: true, dubbableTargets: ["te", "mr"], unsupportedTargets: [] });
      expect(checkDubbingRequest("en", ["ta", "kn"])).toMatchObject({ ok: false, dubbableTargets: ["ta"], unsupportedTargets: ["kn"] });
      expect(checkDubbingRequest("te", ["hi"])).toMatchObject({ ok: false, sourceSupported: false, unsupportedTargets: ["hi"] });
    });
  });

  test("settings widen or lift the limit without a code change", () => {
    withEnv({ DUBBING_SOURCE_LANGUAGES: "en,hi", DUBBING_TARGET_LANGUAGES: "te, kn" }, () => {
      expect(isLaunchDubbingPair("hi", "kn")).toBe(true);
      expect(isLaunchDubbingPair("en", "ta")).toBe(false);
    });
    withEnv({ DUBBING_SOURCE_LANGUAGES: "all", DUBBING_TARGET_LANGUAGES: "all" }, () => {
      expect(dubbingTargetLanguages()).toBeNull();
      expect(isLaunchDubbingPair("es", "ja")).toBe(true);
      expect(dubbingLanguagesForClient()).toEqual({ sourceLanguages: "all", targetLanguages: "all" });
    });
    withEnv({ DUBBING_TARGET_LANGUAGES: " , " }, () => {
      expect(Array.from(dubbingTargetLanguages() || [])).toEqual(LAUNCH_TARGETS);
    });
  });

  test("creator messages are friendly and name languages, never codes or errors", () => {
    withEnv(clean, () => {
      const target = dubbingLanguageMessage(checkDubbingRequest("en", ["kn", "es"]));
      expect(target).toContain("Telugu, Hindi, Marathi, Tamil and Malayalam");
      expect(target).toContain("Kannada");
      const source = dubbingLanguageMessage(checkDubbingRequest("te", ["hi"]));
      expect(source).toContain("videos in English");
      const notice = launchUnsupportedNotice("te", "hi");
      expect(notice).toContain("refunded");
      expect(notice).toContain("Hindi subtitles are ready");
      for (const m of [target, source, notice]) {
        expect(m).not.toMatch(/error|exception|\bkn\b|\bes\b|undefined/i);
      }
    });
  });
});

describe("Per-language editor guidance", () => {
  test("Telugu keeps its existing wording (address rules for Telugu + Hindi, Telugu spoken examples)", () => {
    const g = languageGuidance("te");
    expect(g.audience).toBe("Telugu: మీరు / మిమ్మల్ని / మీకు with -ండి; Hindi: आप with -इए / हैं");
    expect(g.subtitleAddress).toBe(
      "In Telugu, use మీరు / మిమ్మల్ని / మీకు for elders, professionals, and audience; reserve నువ్వు for children or intimate peers. In Hindi, use आप for elders/audience and तुम for peers."
    );
    expect(g.singleAddress).toHaveLength(2);
    expect(g.spoken).toContain("'నువ్వేం' instead of 'నువ్వు ఏమి'");
  });

  test("Hindi gets its own spoken examples", () => {
    const g = languageGuidance("hi");
    expect(g.spoken).toContain("'मदद' instead of 'सहायता'");
    expect(g.spoken).not.toContain("నువ్వేం");
  });

  test.each([
    ["mr", "तुम्ही", "करतोय"],
    ["ta", "நீங்கள்", "இருக்கு"],
    ["ml", "നിങ്ങൾ", "എന്താ"],
  ])("%s gets its own address and spoken rules, without Telugu or Hindi examples", (lang, pronoun, spokenWord) => {
    const g = languageGuidance(lang);
    const all = [g.audience, g.subtitleAddress, ...g.singleAddress, g.spoken].join("\n");
    expect(all).toContain(pronoun);
    expect(g.spoken).toContain(spokenWord);
    expect(all).not.toMatch(/[ఀ-౿]/); // no Telugu script
    expect(all).not.toContain("In Hindi");
  });

  test("Marathi is told not to slip into Hindi", () => {
    expect(languageGuidance("mr").spoken).toContain("Never mix in Hindi");
  });

  test("the system prompt sent to Gemini carries the target language's rules", async () => {
    const systems: string[] = [];
    const fn = async ({ system, prompt }: { model: string; system: string; prompt: string }) => {
      systems.push(system);
      const lines = JSON.parse(prompt).lines;
      return { text: JSON.stringify({ lines: lines.map((l: any) => ({ id: l.id, text: l.draft })) }), inputTokens: 0, outputTokens: 0 };
    };
    const editor = new GeminiDubbingEditor(fn);
    const seg: EditorSegment[] = [{ id: "L1", source: "Where are you going?", draft: "நீங்கள் எங்கே போகிறீர்கள்?", speaker: "speaker_0", maxSyllables: 30 }];
    const opts: EditorOptions = { jobId: "launch_ta", sourceLanguage: "en", targetLanguage: "ta", countSyllables: countSourceSyllables };
    await editor.editSegments(seg, opts);
    expect(systems[0]).toContain("In Tamil: Use நீங்கள்");
    expect(systems[0]).toContain("'இருக்கு' instead of 'இருக்கிறது'");
    expect(systems[0]).toContain("ALWAYS use respectful/plural forms (Tamil:");
    expect(systems[0]).not.toContain("In Telugu:");
  });

  test.each([
    ["hi", "मिस्र, प्रभु, परमेश्वर की इच्छा, राज्य"],
    ["mr", "मिसर, प्रभू, देवाची इच्छा, राज्य"],
    ["ta", "எகிப்து, ஆண்டவர், தேவசித்தம், ராஜ்யம்"],
    ["ml", "ഈജിപ്ത്, കർത്താവ്, ദൈവഹിതം, രാജ്യം"],
  ])("%s system prompt contains proper-noun examples and not Telugu Aiguptiyula", async (lang, examples) => {
    const systems: string[] = [];
    const fn = async ({ system, prompt }: { model: string; system: string; prompt: string }) => {
      systems.push(system);
      const lines = JSON.parse(prompt).lines;
      return { text: JSON.stringify({ lines: lines.map((l: any) => ({ id: l.id, text: l.draft })) }), inputTokens: 0, outputTokens: 0 };
    };
    const editor = new GeminiDubbingEditor(fn);
    const seg: EditorSegment[] = [{ id: "L1", source: "Test source", draft: "Test draft", speaker: "speaker_0", maxSyllables: 30 }];
    const opts: EditorOptions = { jobId: `test_${lang}`, sourceLanguage: "en", targetLanguage: lang, countSyllables: countSourceSyllables };
    await editor.editSegments(seg, opts);
    expect(systems[0]).toContain(examples);
    expect(systems[0]).not.toContain("Aiguptiyula");
  });

  test("Telugu system prompt still contains e.g. in Telugu: Aiguptiyula, Prabhuva, Chittam, Raajyam", async () => {
    const systems: string[] = [];
    const fn = async ({ system, prompt }: { model: string; system: string; prompt: string }) => {
      systems.push(system);
      const lines = JSON.parse(prompt).lines;
      return { text: JSON.stringify({ lines: lines.map((l: any) => ({ id: l.id, text: l.draft })) }), inputTokens: 0, outputTokens: 0 };
    };
    const editor = new GeminiDubbingEditor(fn);
    const seg: EditorSegment[] = [{ id: "L1", source: "Test source", draft: "Test draft", speaker: "speaker_0", maxSyllables: 30 }];
    const opts: EditorOptions = { jobId: "test_te", sourceLanguage: "en", targetLanguage: "te", countSyllables: countSourceSyllables };
    await editor.editSegments(seg, opts);
    expect(systems[0]).toContain("e.g. in Telugu: Aiguptiyula, Prabhuva, Chittam, Raajyam");
  });
});

describe("Honorific normalizer (editor drift check)", () => {
  test("Hindi: longer forms win and ordinary words are left alone", () => {
    // Previously आपको became "__YOU__को" and आज ("today") became "__COME__ज".
    expect(normalizeHonorificsForBigram("आपको यह पसंद है? आज आओ", "hi")).toBe("__YOU_DAT__ यह पसंद है? आज __COME__");
    expect(normalizeHonorificsForBigram("तुम्हारा घर", "hi")).toBe("__YOUR__ घर");
  });

  test("Telugu is unchanged", () => {
    expect(normalizeHonorificsForBigram("నువ్వు రా", "te")).toBe("__YOU__ __COME__");
  });

  test("Marathi neuter and oblique pronoun normalization", () => {
    expect(normalizeHonorificsForBigram("तुमचं नाव काय?", "mr")).toBe("__YOUR__ नाव काय?");
    expect(normalizeHonorificsForBigram("तुझ्या घरी चल", "mr")).toBe("__YOUR__ घरी चल");
  });

  test("Marathi informal to polite correction is accepted without drift", () => {
    const seg: EditorSegment = { id: "L1", source: "What is your name?", draft: "तुझं नाव काय?" };
    expect(checkEditedLine(seg, "तुमचं नाव काय?", { targetLanguage: "mr" }).ok).toBe(true);
  });

  test.each([
    ["mr", "तुम्ही काय करताय? तुला माहीत आहे", "__YOU__ काय करताय? __YOU_DAT__ माहीत आहे"],
    ["ta", "நீங்க எங்கே போறீங்க? உனக்கு தெரியுமா", "__YOU__ எங்கே போறீங்க? __YOU_DAT__ தெரியுமா"],
    ["ml", "നിങ്ങൾ എവിടെ പോകുന്നു? നിനക്ക് അറിയാമോ", "__YOU__ എവിടെ പോകുന്നു? __YOU_DAT__ അറിയാമോ"],
  ])("%s pronouns are normalized as whole words", (lang, input, expected) => {
    expect(normalizeHonorificsForBigram(input, lang)).toBe(expected);
  });

  test.each([
    ["mr", "तू इकडे ये", "तुम्ही इकडे या"],
    ["ta", "நீ இங்கே வா", "நீங்கள் இங்கே வாருங்கள்"],
    ["ml", "നീ ഇവിടെ വാ", "നിങ്ങൾ ഇവിടെ വരൂ"],
  ])("%s: an informal → polite correction is not rejected as drift", (lang, draft, edited) => {
    const seg: EditorSegment = { id: "L1", source: "Come here.", draft };
    expect(checkEditedLine(seg, edited, { targetLanguage: lang }).ok).toBe(true);
  });

  test("a genuinely different Tamil line is still rejected", () => {
    const seg: EditorSegment = { id: "L1", source: "Come here.", draft: "நீ இங்கே வா" };
    expect(checkEditedLine(seg, "இன்று வானிலை மிகவும் நன்றாக இருக்கிறது", { targetLanguage: "ta" }).reason).toBe("drift");
  });
});

describe("Wiring", () => {
  const src = (p: string) => fs.readFileSync(path.join(__dirname, "../../src/pipeline", p), "utf8");

  test("the order refuses an unavailable language before anything is priced or charged", () => {
    const s = src("pipelineTriggers.ts");
    const trigger = s.slice(s.indexOf("export const triggerVideoAIFeatures"), s.indexOf("export const getDubbingQuote"));
    const check = trigger.indexOf("checkDubbingRequest(resolvedPrimaryLang, nonPrimaryTargetLanguages)");
    expect(check).toBeGreaterThan(0);
    expect(check).toBeLessThan(trigger.indexOf("dubbingCharge("));
    expect(check).toBeLessThan(trigger.indexOf("walletBalanceUSD") > 0 ? trigger.indexOf("walletBalanceUSD") : Infinity);
    expect(trigger).toContain('code: "dubbing_language_unavailable"');
  });

  test("in a mixed order, only launch languages are dubbed and charged as dubs; the rest are billed as subtitles", () => {
    const s = src("pipelineTriggers.ts");
    const trigger = s.slice(s.indexOf("export const triggerVideoAIFeatures"), s.indexOf("export const getDubbingQuote"));
    expect(trigger).toContain("const splitForSubtitles = wantSubtitles && langCheck.dubbableTargets.length > 0;");
    expect(trigger).toMatch(/dubbingCharge\(\{\s*targetLanguages: dubbingTargetLanguages,/);
    expect(trigger).not.toMatch(/dubbingCharge\(\{\s*targetLanguages: nonPrimaryTargetLanguages,/);
    expect(trigger).toContain("const subLangsToBill = wantDubbing ? subtitleOnlyTargetLanguages : nonPrimaryTargetLanguages;");
    expect(trigger).toContain("const billedDubbingLanguages = (wantDubbing && dubbingCost > 0) ? dubbingTargetLanguages : [];");
    // The worker's dubbing list never gains a language that wasn't priced as a dub.
    expect(trigger).toContain("validatedTargetLanguages.filter((l) => l === resolvedPrimaryLang || dubbingLanguageSet.has(l))");
  });

  test("the quote uses the same rule", () => {
    const s = src("pipelineTriggers.ts");
    const quote = s.slice(s.indexOf("export const getDubbingQuote"));
    expect(quote.indexOf("checkDubbingRequest(fallbackSourceLanguage, targetLanguages)")).toBeGreaterThan(0);
    expect(quote.indexOf('status: "language_unavailable"')).toBeLessThan(quote.indexOf("dubbingCharge("));
  });

  test("the worker skips and refunds pairs outside the launch list on both paths", () => {
    const s = src("layers/07-dubbing.ts");
    expect(s).toContain("const isV4DubbingLanguage = V4_PREMIUM_80_LANGUAGES.has(targetLang) && isLaunchPair;");
    expect(s).toContain("if (!V4_PREMIUM_80_LANGUAGES.has(targetLang) || !isLaunchPair) {");
    expect(s).toContain("!isDubbingSourceLanguage(sourceLang)"); // upload-time preparation
    expect(src("layers/05-transcription.ts")).toContain("isDubbingSourceLanguage(normalizeLanguageCode(sourceLang))");
  });

  test("the Dubbing Studio refuses an unavailable language before the wallet transaction", () => {
    const s = fs.readFileSync(path.join(__dirname, "../../src/dubbing/standaloneDubbing.ts"), "utf8");
    const create = s.slice(s.indexOf("export const createDubbingJob"));
    const check = create.indexOf("checkDubbingRequest(sourceLanguage, targetLanguages)");
    expect(check).toBeGreaterThan(0);
    expect(check).toBeLessThan(create.indexOf("runTransaction"));
  });
});
