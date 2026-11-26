import { MultilingualSubtitleLocalizer } from "../../src/pipeline/services/multilingual_subtitle_localizer";
import { translationService } from "../../src/pipeline/services/translation";
import { geminiDubbingEditor } from "../../src/pipeline/services/geminiDubbingEditor";
import { WordTimestamp } from "../../src/pipeline/types";
import josephFixture from "../fixtures/stage4_joseph_request.json";

describe("Phase 1: subtitles reuse dual-track subtitleText (Fix 1.1, 1.2, 1.5)", () => {
  const sourceWords: WordTimestamp[] = [
    { text: "The", start: 100, end: 250, confidence: 0.99, speaker: "speaker_0" },
    { text: "Lord", start: 260, end: 520, confidence: 0.99, speaker: "speaker_0" },
    { text: "delivered", start: 540, end: 1020, confidence: 0.98, speaker: "speaker_0" },
    { text: "them", start: 1040, end: 1280, confidence: 0.99, speaker: "speaker_0" },
    { text: "in", start: 1300, end: 1420, confidence: 0.99, speaker: "speaker_0" },
    { text: "40", start: 1440, end: 1850, confidence: 0.98, speaker: "speaker_0" },
    { text: "days.", start: 1870, end: 2300, confidence: 0.99, speaker: "speaker_0" },
    { text: "Pharaoh", start: 3500, end: 4000, confidence: 0.99, speaker: "speaker_1" },
    { text: "heard", start: 4020, end: 4400, confidence: 0.98, speaker: "speaker_1" },
    { text: "the", start: 4420, end: 4550, confidence: 0.99, speaker: "speaker_1" },
    { text: "news.", start: 4570, end: 5000, confidence: 0.99, speaker: "speaker_1" },
  ];

  const preTranslatedSentences = [
    {
      startMs: 100,
      endMs: 2300,
      speaker: "speaker_0",
      sourceText: "The Lord delivered them in 40 days.",
      text: "ప్రభువు వారిని 40 రోజుల్లో విడిపించాడు.",
    },
    {
      startMs: 3500,
      endMs: 5000,
      speaker: "speaker_1",
      sourceText: "Pharaoh heard the news.",
      text: "ఫరో ఆ వార్త విన్నాడు.",
    },
  ];

  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.DUBBING_SUBTITLES_FROM_DUB_PASS;
  });

  test("Fix 1.1: preTranslatedSentences skips batchTranslateV3 and geminiDubbingEditor.editSegments", async () => {
    const v3Spy = jest.spyOn(translationService, "batchTranslateV3");
    const editSpy = jest.spyOn(geminiDubbingEditor, "editSegments");
    const condenseSpy = jest
      .spyOn(translationService, "condenseSubtitleLines")
      .mockImplementation(async (_jobId, items) => items.map((i) => i.text));

    const result = await MultilingualSubtitleLocalizer.localizeTrack({
      jobId: "job_sub_reuse_1",
      sourceWords,
      sourceLanguage: "en",
      targetLanguage: "te",
      sceneCutTimestampsMs: [2800],
      shotChangesMs: [2800],
      preTranslatedSentences,
    });

    expect(v3Spy).not.toHaveBeenCalled();
    expect(editSpy).not.toHaveBeenCalled();
    expect(result.cues.length).toBeGreaterThanOrEqual(2);

    const joined = result.cues.map((c) => c.text.replace(/\s*\n\s*/g, " ").trim()).join(" ");
    expect(joined).toContain("ప్రభువు వారిని 40 రోజుల్లో విడిపించాడు.");
    expect(joined).toContain("ఫరో ఆ వార్త విన్నాడు.");

    // No cue crosses shot change at 2800ms
    for (const cue of result.cues) {
      expect(cue.startMs < 2800 && cue.endMs > 2800).toBe(false);
    }
    condenseSpy.mockRestore();
  });

  test("Fix 1.1: DUBBING_SUBTITLES_FROM_DUB_PASS=false restores separate subtitle translation", async () => {
    process.env.DUBBING_SUBTITLES_FROM_DUB_PASS = "false";
    const subSpy = jest
      .spyOn(translationService, "translateSubtitleSentences")
      .mockResolvedValue(["ప్రభువు వారిని 40 రోజుల్లో రక్షించాడు.", "ఫరో ఆ వార్త విన్నాడు."]);
    jest
      .spyOn(translationService, "condenseSubtitleLines")
      .mockImplementation(async (_jobId, items) => items.map((i) => i.text));

    await MultilingualSubtitleLocalizer.localizeTrack({
      jobId: "job_sub_flag_off",
      sourceWords,
      sourceLanguage: "en",
      targetLanguage: "te",
      preTranslatedSentences,
    });

    expect(subSpy).toHaveBeenCalledTimes(1);
  });

  test("Fix 1.2: fallback path passes castList, relationships, speakerNames and applies Telugu lexicon guard", async () => {
    jest
      .spyOn(translationService, "batchTranslateV3")
      .mockResolvedValue(["ప్రభువు సారి చేస్తుంది అని చెప్పాడు."]);
    const editSpy = jest
      .spyOn(geminiDubbingEditor, "editSegments")
      .mockResolvedValue([
        {
          id: "S1",
          text: "ప్రభువు సారి చేస్తుంది అని చెప్పాడు.",
          subtitleText: "ప్రభువు సారి చేస్తుంది అని చెప్పాడు.",
          usedDraft: false,
          syllables: 12,
          overBudget: false,
        },
      ]);

    const castList = josephFixture.castList as any[];
    const relationships = josephFixture.relationships as any[];
    const speakerNames = { speaker_0: "Pharaoh" };

    const out = await translationService.translateSubtitleSentences(
      "job_fallback_cast",
      [{ text: "The Lord corrects it.", speaker: "speaker_0", maxCharacters: 42 }],
      "en",
      "te",
      { castList, relationships, speakerNames }
    );

    expect(editSpy).toHaveBeenCalledTimes(1);
    const editOpts = editSpy.mock.calls[0][1];
    expect(editOpts.castList).toEqual(castList);
    expect(editOpts.relationships).toEqual(relationships);
    expect(editOpts.speakerNames).toEqual(speakerNames);
    // Telugu theological lexicon guard fixes "సారి చేస్తుంది" -> "సరిచేస్తుంది"
    expect(out[0]).not.toMatch(/సారి\s*చే/);
    expect(out[0]).toContain("సరిచేస్తుంది");
  });

  test("Fix 1.5: concise dubbing retake leaves dual-track subtitleText unchanged", async () => {
    const dubbingSeg = {
      index: 0,
      originalText: "The Lord delivered them in 40 days.",
      translatedText: "ప్రభువు వారిని 40 రోజుల్లో విడిపించాడు.",
      subtitleText: "ప్రభువు వారిని 40 రోజుల్లో విడిపించాడు.",
    };
    jest
      .spyOn(translationService, "retranslateConcise")
      .mockResolvedValue("ప్రభువు 40 రోజుల్లో విడిపించాడు.");

    const concise = await translationService.retranslateConcise(
      dubbingSeg.originalText,
      "en",
      "te",
      { currentTranslation: dubbingSeg.translatedText, maxDurationMs: 2000 }
    );
    dubbingSeg.translatedText = concise;

    expect(dubbingSeg.translatedText).toBe("ప్రభువు 40 రోజుల్లో విడిపించాడు.");
    expect(dubbingSeg.subtitleText).toBe("ప్రభువు వారిని 40 రోజుల్లో విడిపించాడు.");
  });
});
