/**
 * Netflix-style subtitles: conformer rules, hybrid faithful translation, condensation,
 * lyrics and forced narratives. Zero-credit: translation calls are mocked.
 */

import {
  conformCues,
  breakLines,
  splitTextInTwo,
  formatDualSpeaker,
} from "../../src/pipeline/services/netflixSubtitleConformer";
import { getSubtitleProfile, getReadableCharCount } from "../../src/pipeline/services/subtitle_language_profiles";
import { LocalizedSubtitleCue, SubtitleReadabilityValidator } from "../../src/pipeline/services/subtitle_readability_validator";
import { MultilingualSubtitleLocalizer } from "../../src/pipeline/services/multilingual_subtitle_localizer";
import { translationService } from "../../src/pipeline/services/translation";
import { parseScreenContent } from "../../src/pipeline/services/screenContentAnalyzer";
import { WordTimestamp } from "../../src/pipeline/types";

const en = getSubtitleProfile("en");

function cue(id: number, startMs: number, endMs: number, text: string, speaker = "A"): LocalizedSubtitleCue {
  return {
    id, languageCode: "en", text, startMs, endMs, durationMs: endMs - startMs,
    sourceWordStartIndex: 0, sourceWordEndIndex: 0, charactersPerSecond: 0, charactersPerLine: 0,
    alignmentConfidence: 1, validationStatus: "pass", speaker,
  };
}

describe("Netflix profile values", () => {
  test("maximum duration is 7 s for every language", () => {
    for (const lang of ["en", "es", "te", "hi", "ja", "zh", "ar", "sw"]) {
      expect(getSubtitleProfile(lang).maximumCueDurationMs).toBe(7000);
    }
  });

  test("language conventions for dual speakers and lyrics", () => {
    expect(getSubtitleProfile("en").dualSpeakerStyle ?? "dash").toBe("dash");
    expect(getSubtitleProfile("pt").dualSpeakerStyle).toBe("dash_space");
    expect(getSubtitleProfile("nl").dualSpeakerStyle).toBe("dash_second_only");
    expect(getSubtitleProfile("zh").lyricsStyle).toBe("plain");
  });

  test("readable characters ignore tags and line breaks", () => {
    expect(getReadableCharCount("<i>Hello</i>\n<i>there</i>")).toBe("Hello there".length);
    expect(getReadableCharCount("{\\an8}Exit")).toBe(4);
  });
});

describe("Line breaking", () => {
  test("one line when it fits", () => {
    expect(breakLines("I'll see you tomorrow.", en)).toEqual(["I'll see you tomorrow."]);
  });

  test("never ends the first line on a weak word and stays within 42 characters", () => {
    const lines = breakLines("We drove all the way to the old house on the hill last night", en)!;
    expect(lines).toHaveLength(2);
    for (const l of lines) expect(l.length).toBeLessThanOrEqual(42);
    const lastWord = lines[0].split(" ").pop()!.toLowerCase();
    expect(["the", "to", "on", "a", "of"]).not.toContain(lastWord);
  });

  test("Japanese word-boundary line breaking preserves words and respects 13 CPL", () => {
    const ja = getSubtitleProfile("ja");
    expect(ja.maxCharactersPerLine).toBe(13);
    expect(ja.minimumCueDurationMs).toBe(500);
    // 16 full-width characters: "視聴者の皆様に真実をお届けします"
    const lines = breakLines("視聴者の皆様に真実をお届けします", ja)!;
    expect(lines).toHaveLength(2);
    for (const l of lines) {
      expect(getReadableCharCount(l)).toBeLessThanOrEqual(13);
    }
  });

  test("Thai word-boundary line breaking preserves words and respects 39 CPL", () => {
    const th = getSubtitleProfile("th");
    expect(th.maxCharactersPerLine).toBe(39);
    const text = "การตรวจสอบข้อเท็จจริงด้วยปัญญาประดิษฐ์ช่วยให้ผู้ชมได้รับข้อมูลที่ถูกต้องแม่นยำ";
    const lines = breakLines(text, th)!;
    expect(lines.length).toBeLessThanOrEqual(2);
    for (const l of lines) {
      expect(getReadableCharCount(l)).toBeLessThanOrEqual(39);
    }
  });

  test("prefers breaking after punctuation", () => {
    const lines = breakLines("If you are right about this, then we have a serious problem", en)!;
    expect(lines[0].endsWith(",")).toBe(true);
  });

  test("keeps a number with its unit", () => {
    const lines = breakLines("The government said prices rose by 12 percent in only one year", en)!;
    expect(lines.join("|")).not.toMatch(/12\|percent/);
  });

  test("returns null when the text needs more than two lines", () => {
    const long = "This sentence is far too long to fit into only two subtitle lines of forty-two characters each at all.";
    expect(breakLines(long, en)).toBeNull();
    const parts = splitTextInTwo(long, en)!;
    expect(parts.join(" ")).toBe(long);
  });

  test("dual speaker hyphen styles", () => {
    expect(formatDualSpeaker("Are you coming?", "In a minute.", en)).toEqual(["-Are you coming?", "-In a minute."]);
    expect(formatDualSpeaker("Boa sorte.", "Obrigada.", getSubtitleProfile("pt"))).toEqual(["- Boa sorte.", "- Obrigada."]);
    expect(formatDualSpeaker("Kom je?", "Zo.", getSubtitleProfile("nl"))).toEqual(["Kom je?", "-Zo."]);
  });
});

describe("conformCues", () => {
  test("merges two short lines from different speakers into one dual-speaker subtitle", () => {
    const { cues, report } = conformCues(
      [cue(1, 1000, 1400, "Are you coming?", "A"), cue(2, 1500, 1900, "In a minute.", "B")],
      { profile: en }
    );
    expect(cues).toHaveLength(1);
    expect(cues[0].text).toBe("-Are you coming?\n-In a minute.");
    expect(cues[0].isDualSpeaker).toBe(true);
    expect(cues[0].durationMs).toBeGreaterThanOrEqual(833);
    expect(report.dualSpeaker).toBe(1);
  });

  test("merges short lines from the same speaker", () => {
    const { cues } = conformCues([cue(1, 1000, 1300, "Yes."), cue(2, 1400, 1800, "I know.")], { profile: en });
    expect(cues).toHaveLength(1);
    expect(cues[0].text).toBe("Yes. I know.");
  });

  test("extends a short subtitle into the following silence, keeping a 2-frame gap", () => {
    const { cues } = conformCues(
      [cue(1, 1000, 1300, "Stop right there and listen to me now."), cue(2, 4000, 6000, "Why should I listen to you?")],
      { profile: en, mergeGapMs: 0 }
    );
    expect(cues[0].durationMs).toBeGreaterThanOrEqual(833);
    expect(cues[0].charactersPerSecond).toBeLessThanOrEqual(en.maxReadingSpeedCps);
    expect(cues[1].startMs - cues[0].endMs).toBeGreaterThanOrEqual(66);
  });

  test("never lets a subtitle overlap the next one", () => {
    const { cues } = conformCues(
      [cue(1, 1000, 3000, "First line of dialogue here."), cue(2, 2500, 4500, "Second line starts early.", "B")],
      { profile: en, mergeGapMs: 0 }
    );
    expect(cues[1].startMs - cues[0].endMs).toBeGreaterThanOrEqual(66);
  });

  test("splits text that cannot fit in two lines into two timed subtitles", () => {
    const long = "This sentence is far too long to fit into only two subtitle lines of forty-two characters each at all.";
    const { cues, report } = conformCues([cue(1, 1000, 8000, long)], { profile: en });
    expect(cues.length).toBeGreaterThanOrEqual(2);
    expect(report.split).toBeGreaterThanOrEqual(1);
    for (const c of cues) {
      expect(c.lines!.length).toBeLessThanOrEqual(2);
      for (const l of c.lines!) expect(getReadableCharCount(l)).toBeLessThanOrEqual(42);
      expect(c.durationMs).toBeLessThanOrEqual(7000);
    }
    expect(cues.map((c) => c.lines!.join(" ")).join(" ")).toBe(long);
  });

  test("caps a subtitle at 7 seconds", () => {
    const { cues } = conformCues([cue(1, 0, 12000, "Hello.")], { profile: en });
    expect(cues[0].durationMs).toBe(7000);
  });

  test("styles sung lines as lyrics: italics, or plain for Chinese", () => {
    const songs = [{ startMs: 0, endMs: 10000 }];
    const it1 = conformCues([cue(1, 1000, 3000, "Tonight we dance until the sun")], { profile: en, songIntervalsMs: songs });
    expect(it1.cues[0].text).toBe("<i>Tonight we dance until the sun</i>");
    expect(it1.cues[0].isLyric).toBe(true);
    const zh = conformCues([{ ...cue(1, 1000, 3000, "今晚我们跳舞"), languageCode: "zh" }], { profile: getSubtitleProfile("zh"), songIntervalsMs: songs });
    expect(zh.cues[0].text).toBe("今晚我们跳舞");
  });

  test("does not merge a lyric with dialogue", () => {
    const { cues } = conformCues(
      [cue(1, 1000, 1400, "La la la"), cue(2, 1500, 1900, "Hey!", "B")],
      { profile: en, songIntervalsMs: [{ startMs: 900, endMs: 1450 }] }
    );
    expect(cues).toHaveLength(2);
  });

  test("reports reading speed it could not fix by timing alone", () => {
    const fast = "This is a very long sentence spoken extremely quickly by the narrator";
    const { report } = conformCues(
      [cue(1, 1000, 2000, fast), cue(2, 2100, 3000, "Next.", "B")],
      { profile: en, mergeGapMs: 0 }
    );
    expect(report.unresolved.some((u) => u.rule === "reading_speed")).toBe(true);
  });
});

describe("Validator with forced narratives", () => {
  test("on-screen text may overlap dialogue without an overlap error", () => {
    const dialogue = cue(1, 1000, 3000, "Look at the sign.");
    const fn: LocalizedSubtitleCue = { ...cue(2, 1500, 3500, "EXIT"), isForcedNarrative: true };
    const report = SubtitleReadabilityValidator.validateTrack([dialogue, fn], "en", en);
    expect(report.hasOverlaps).toBe(false);
  });
});

describe("parseScreenContent", () => {
  test("parses songs and on-screen text, drops tiny songs and empty text", () => {
    const res = parseScreenContent(JSON.stringify({
      songs: [{ start_seconds: 10, end_seconds: 40 }, { start_seconds: 50, end_seconds: 50.5 }],
      on_screen_text: [
        { start_seconds: 2, end_seconds: 5, text: "  Mumbai,\n 1993 ", language: "en" },
        { start_seconds: 6, end_seconds: 7, text: "", language: "en" },
      ],
    }), 60000);
    expect(res.songIntervalsMs).toEqual([{ startMs: 10000, endMs: 40000 }]);
    expect(res.onScreenText).toEqual([{ startMs: 2000, endMs: 5000, text: "Mumbai, 1993", language: "en" }]);
  });
});

describe("Localizer (hybrid mode)", () => {
  const words: WordTimestamp[] = [
    { text: "Where", start: 1000, end: 1200, confidence: 0.99, speaker: "A" },
    { text: "are", start: 1250, end: 1400, confidence: 0.99, speaker: "A" },
    { text: "you?", start: 1450, end: 1700, confidence: 0.99, speaker: "A" },
    { text: "Here.", start: 1800, end: 2100, confidence: 0.99, speaker: "B" },
    { text: "The", start: 4000, end: 4200, confidence: 0.99, speaker: "A" },
    { text: "price", start: 4250, end: 4600, confidence: 0.99, speaker: "A" },
    { text: "rose", start: 4650, end: 4900, confidence: 0.99, speaker: "A" },
    { text: "12%", start: 4950, end: 5400, confidence: 0.99, speaker: "A" },
    { text: "this", start: 5450, end: 5600, confidence: 0.99, speaker: "A" },
    { text: "year.", start: 5650, end: 6000, confidence: 0.99, speaker: "A" },
  ];

  beforeEach(() => { delete process.env.DUBBING_TRANSLATION_MODE; });
  afterEach(() => jest.restoreAllMocks());

  test("translates sentences faithfully (not the dub text), conforms, and adds forced narratives", async () => {
    const subSpy = jest.spyOn(translationService, "translateSubtitleSentences").mockImplementation(async (_job, sentences) =>
      sentences.map((s) => ({ "Where are you?": "Dónde estás?", "Here.": "Aquí.", "The price rose 12% this year.": "El precio subió un 12 % este año." } as Record<string, string>)[s.text] || s.text)
    );
    const v3Spy = jest.spyOn(translationService, "batchTranslateV3").mockResolvedValue(["SALIDA"]);

    const result = await MultilingualSubtitleLocalizer.localizeTrack({
      jobId: "netflix_hybrid_1",
      sourceWords: words,
      sourceLanguage: "en",
      targetLanguage: "es",
      // Dub text exists but must NOT be used for subtitles in hybrid mode.
      fallbackSegments: [{ start: 1000, end: 2100, text: "DUB TEXT" }, { start: 4000, end: 6000, text: "DUB TEXT" }],
      onScreenText: [{ startMs: 2500, endMs: 3500, text: "EXIT", language: "en" }],
    });

    expect(subSpy).toHaveBeenCalledTimes(1);
    const sentArg = subSpy.mock.calls[0][1];
    expect(sentArg.every((s) => typeof s.maxCharacters === "number" && s.maxCharacters! > 0)).toBe(true);
    expect(result.srtContent).not.toContain("DUB TEXT");

    const dual = result.cues.find((c) => c.isDualSpeaker);
    expect(dual?.text).toBe("-Dónde estás?\n-Aquí.");

    const fn = result.cues.find((c) => c.isForcedNarrative)!;
    expect(fn.text).toBe("SALIDA");
    expect(v3Spy).toHaveBeenCalledWith(["EXIT"], "en", "es");
    expect(result.vttContent).toContain("line:10% align:center\nSALIDA");
    expect(result.srtContent).toContain("{\\an8}SALIDA");
    expect(result.vttContent).not.toContain("<v A>-Dónde");
    expect(result.cues.map((c) => c.id)).toEqual(result.cues.map((_, i) => i + 1));

    // Stays in sync: the second sentence's subtitle starts with its speech (4.0 s), not later.
    const price = result.cues.find((c) => c.text.includes("precio"))!;
    expect(Math.abs(price.startMs - 4000)).toBeLessThanOrEqual(250);
  });

  test("a fast sentence never pushes later subtitles out of sync", async () => {
    const w: WordTimestamp[] = [
      { text: "Absolutely", start: 1000, end: 1200, confidence: 1, speaker: "A" },
      { text: "wrong.", start: 1200, end: 1800, confidence: 1, speaker: "A" },
      { text: "No.", start: 1900, end: 2400, confidence: 1, speaker: "B" },
      { text: "Later", start: 3000, end: 3400, confidence: 1, speaker: "A" },
      { text: "line.", start: 3400, end: 3900, confidence: 1, speaker: "A" },
    ];
    jest.spyOn(translationService, "translateSubtitleSentences").mockImplementation(async (_j, s) =>
      s.map((x) => (x.text.startsWith("Absolutely")
        ? "Absolutamente todo lo que alguna vez creímos estaba completamente equivocado."
        : x.text === "No." ? "No." : "Línea posterior.")));
    jest.spyOn(translationService, "condenseSubtitleLines").mockImplementation(async (_j, items) => items.map((i) => i.text));
    const r = await MultilingualSubtitleLocalizer.localizeTrack({ jobId: "sync", sourceWords: w, sourceLanguage: "en", targetLanguage: "es" });
    const later = r.cues.find((c) => c.text.includes("posterior"))!;
    expect(Math.abs(later.startMs - 3000)).toBeLessThanOrEqual(250);
  });

  test("condenses a subtitle that is still too fast after timing fixes", async () => {
    const fastWords: WordTimestamp[] = [
      { text: "Absolutely", start: 1000, end: 1150, confidence: 1, speaker: "A" },
      { text: "everything", start: 1150, end: 1300, confidence: 1, speaker: "A" },
      { text: "we", start: 1300, end: 1350, confidence: 1, speaker: "A" },
      { text: "ever", start: 1350, end: 1450, confidence: 1, speaker: "A" },
      { text: "believed", start: 1450, end: 1600, confidence: 1, speaker: "A" },
      { text: "was", start: 1600, end: 1650, confidence: 1, speaker: "A" },
      { text: "wrong.", start: 1650, end: 1800, confidence: 1, speaker: "A" },
      { text: "No.", start: 1850, end: 2600, confidence: 1, speaker: "B" },
    ];
    jest.spyOn(translationService, "translateSubtitleSentences").mockImplementation(async (_j, s) =>
      s.map((x) => (x.text.startsWith("Absolutely") ? "Absolutamente todo lo que alguna vez creímos estaba completamente equivocado." : "No."))
    );
    const condenseSpy = jest.spyOn(translationService, "condenseSubtitleLines").mockImplementation(async (_j, items) =>
      items.map(() => "Todo lo que creímos era falso.")
    );

    const result = await MultilingualSubtitleLocalizer.localizeTrack({
      jobId: "netflix_condense", sourceWords: fastWords, sourceLanguage: "en", targetLanguage: "es",
    });
    expect(condenseSpy).toHaveBeenCalled();
    const items = condenseSpy.mock.calls[0][1];
    expect(items[0].maxCharacters).toBeGreaterThan(0);
    expect(result.cues.some((c) => c.text.includes("Todo lo que creímos era falso."))).toBe(true);
  });
});

describe("Shot change conformance and Netflix rule scoring", () => {
  test("snaps cue start to shot change when speech starts within half a second after cut", () => {
    // 30fps -> half second = 15 frames = 500ms
    // Cut at 2000ms. Speech starts at 2200ms (within 500ms after cut).
    const input = [cue(1, 2200, 4000, "Dialogue begins within half second after cut.")];
    const shotChanges = [2000];
    const { cues, report } = conformCues(input, { profile: en, shotChangesMs: shotChanges, fps: 30 });
    expect(cues[0].startMs).toBe(2000);
    expect(report.shotSnaps).toBeGreaterThanOrEqual(1);
  });

  test("snaps cue start to cut when speech starts within half a second before cut (flash prevention)", () => {
    // Cut at 3000ms. Speech starts at 2750ms (250ms before cut).
    const input = [cue(1, 2750, 5000, "Dialogue begins slightly before cut.")];
    const shotChanges = [3000];
    const { cues, report } = conformCues(input, { profile: en, shotChangesMs: shotChanges, fps: 30 });
    expect(cues[0].startMs).toBe(3000);
    expect(report.shotSnaps).toBeGreaterThanOrEqual(1);
  });

  test("extends cue end to cut - 2 frames when cue ends within half a second before cut", () => {
    // Cut at 4000ms. Cue ends at 3700ms (300ms before cut).
    // Minimum gap = 2 frames = 67ms at 30fps. Expected end = 4000 - 67 = 3933ms.
    const input = [cue(1, 2000, 3700, "Dialogue ends within half a second before cut.")];
    const shotChanges = [4000];
    const { cues, report } = conformCues(input, { profile: en, shotChangesMs: shotChanges, fps: 30 });
    expect(cues[0].endMs).toBe(3933);
    expect(report.shotSnaps).toBeGreaterThanOrEqual(1);
  });

  test("snaps cue end back to cut - 2 frames when cue bleeds within half a second past cut", () => {
    // Cut at 4000ms. Cue ends at 4200ms (200ms after cut).
    const input = [cue(1, 2000, 4200, "Dialogue slightly bleeds across cut.")];
    const shotChanges = [4000];
    const { cues, report } = conformCues(input, { profile: en, shotChangesMs: shotChanges, fps: 30 });
    expect(cues[0].endMs).toBe(3933);
    expect(report.shotSnaps).toBeGreaterThanOrEqual(1);
  });

  test("snaps start to cut when cue crosses cut but has under half a second before cut", () => {
    // Cut at 3000ms. Cue starts at 2800ms (200ms before cut) and ends at 5000ms (2000ms after cut).
    const input = [cue(1, 2800, 5000, "Crossing cue with short lead-in before cut.")];
    const shotChanges = [3000];
    const { cues, report } = conformCues(input, { profile: en, shotChangesMs: shotChanges, fps: 30 });
    expect(cues[0].startMs).toBe(3000);
    expect(report.shotSnaps).toBeGreaterThanOrEqual(1);
  });

  test("scores track against Netflix rules with high compliance on conformed cues", () => {
    const input = [
      cue(1, 1000, 3000, "Clean first subtitle."),
      cue(2, 3100, 5000, "Clean second subtitle."),
      cue(3, 5100, 7000, "Clean third subtitle."),
    ];
    const { cues } = conformCues(input, { profile: en, shotChangesMs: [500], fps: 30 });
    const scorecard = SubtitleReadabilityValidator.scoreTrackAgainstNetflixRules(cues, "en", [500], 30);
    expect(scorecard.totalCues).toBe(3);
    expect(scorecard.passedCues).toBe(3);
    expect(scorecard.complianceRate).toBe(1.0);
    expect(scorecard.rulePassRates.readingSpeed).toBe(1.0);
    expect(scorecard.rulePassRates.lineLength).toBe(1.0);
    expect(scorecard.rulePassRates.minDuration).toBe(1.0);
    expect(scorecard.rulePassRates.maxDuration).toBe(1.0);
    expect(scorecard.rulePassRates.interCueGap).toBe(1.0);
    expect(scorecard.rulePassRates.noOverlap).toBe(1.0);
    expect(scorecard.rulePassRates.shotChangeAlignment).toBe(1.0);
  });
});
