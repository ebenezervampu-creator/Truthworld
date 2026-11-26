process.env.DUBBING_MEANING_CHECK = "false";

import { GeminiDubbingEditor, EditorSegment } from "../../src/pipeline/services/geminiDubbingEditor";
import { translationService } from "../../src/pipeline/services/translation";
import { countSourceSyllables } from "../../src/pipeline/services/speech-rate";
import { LocalizationBible } from "../../src/pipeline/services/cast-list";

describe("Phase 4: editor context (creatorDNA, isSong, visualSceneNotes, bible reuse)", () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test("Fix 4.1: system instruction includes creatorDNA (customInstructions capped at 500 chars) and reels platform note, and nothing extra when omitted", async () => {
    const systems: string[] = [];
    const editor = new GeminiDubbingEditor(async ({ system, prompt }) => {
      systems.push(system);
      const parsed = JSON.parse(prompt);
      return {
        text: JSON.stringify({ lines: parsed.lines.map((l: any) => ({ id: l.id, text: l.draft })) }),
        inputTokens: 0,
        outputTokens: 0,
      };
    });

    const seg: EditorSegment = { id: "L1", source: "Hello world.", draft: "నమస్కారం." };
    const longNote = "A".repeat(650);

    await editor.editSegments([seg], {
      jobId: "job_dna_1",
      sourceLanguage: "en",
      targetLanguage: "te",
      inferBible: false,
      countSyllables: countSourceSyllables,
      targetPlatform: "reels",
      creatorDNA: {
        vibe: "energetic",
        slangTolerance: "medium",
        vocabPreference: "simple",
        customInstructions: longNote,
      },
    });

    expect(systems[0]).toContain("Creator vibe: energetic.");
    expect(systems[0]).toContain("Slang tolerance: medium.");
    expect(systems[0]).toContain("Vocabulary preference: simple.");
    expect(systems[0]).toContain("This is a short vertical video; keep lines punchy.");
    expect(systems[0]).toContain("A".repeat(500));
    expect(systems[0]).not.toContain("A".repeat(501));

    await editor.editSegments([seg], {
      jobId: "job_dna_2",
      sourceLanguage: "en",
      targetLanguage: "te",
      inferBible: false,
      countSyllables: countSourceSyllables,
    });

    expect(systems[1]).not.toContain("Creator style:");
    expect(systems[1]).not.toContain("short vertical video");
  });

  test("Fix 4.2: isSong segment gets no syllable budget, [SUNG] prompt marker, and skips tighten pass", async () => {
    const prompts: any[] = [];
    const editor = new GeminiDubbingEditor(async ({ prompt }) => {
      const parsed = JSON.parse(prompt);
      prompts.push(parsed);
      return {
        text: JSON.stringify({ lines: parsed.lines.map((l: any) => ({ id: l.id, text: l.draft })) }),
        inputTokens: 0,
        outputTokens: 0,
      };
    });

    const songSeg: EditorSegment = {
      id: "L1",
      source: "Sing a song of sixpence, a pocket full of rye.",
      draft: "ఆరు పైసల పాట పాడండి, జేబు నిండా ధాన్యం ఉంది అని పాడండి.",
      maxSyllables: 6, // would trigger tighten if not isSong
      isSong: true,
    };

    const [out] = await editor.editSegments([songSeg], {
      jobId: "job_song",
      sourceLanguage: "en",
      targetLanguage: "te",
      inferBible: false,
      countSyllables: countSourceSyllables,
    });

    expect(prompts).toHaveLength(1); // no tighten pass
    expect(prompts[0].lines[0].is_song).toBe(true);
    expect(prompts[0].lines[0].song_rule).toContain("[SUNG]");
    expect(prompts[0].lines[0].max_syllables).toBeUndefined();
    expect(out.maxSyllables).toBeUndefined();
  });

  test("Fix 4.3: visualSceneNotes are built from onScreenText (capped at 30 notes / 2000 chars) and passed to editor", async () => {
    const editSpy = jest
      .spyOn(require("../../src/pipeline/services/geminiDubbingEditor").geminiDubbingEditor, "editSegments")
      .mockResolvedValue([{ id: "L1", text: "ఇది 50% తగ్గింపు.", subtitleText: "ఇది 50% తగ్గింపు.", usedDraft: false, syllables: 7, overBudget: false }]);

    const onScreenText = Array.from({ length: 35 }, (_, i) => ({
      startMs: (i + 1) * 5000,
      endMs: (i + 1) * 5000 + 2000,
      text: `SALE 50% OFF #${i + 1}`,
      language: "en",
    }));

    await (translationService as any).applyContextualDubbingEdit(
      "job_ost",
      [{ start: 0, end: 3000, text: "Look at the sale!" }],
      ["ఆ సేల్ చూడండి!"],
      "en",
      "te",
      undefined,
      { onScreenText }
    );

    expect(editSpy).toHaveBeenCalledTimes(1);
    const opts = editSpy.mock.calls[0][1] as any;
    expect(opts.visualSceneNotes).toBeDefined();
    expect(opts.visualSceneNotes.length).toBeLessThanOrEqual(30);
    expect(opts.visualSceneNotes[0]).toBe('00:05 on screen: "SALE 50% OFF #1"');
    const totalChars = opts.visualSceneNotes.reduce((s: number, n: string) => s + n.length, 0);
    expect(totalChars).toBeLessThanOrEqual(2000);
  });

  test("Fix 4.4: retranslateConcise reuses bible with inferBible: false (0 bible Gemini calls) and keeps register", async () => {
    const bible: LocalizationBible = {
      lockedRegisters: { "speaker_0->speaker_1": "informal" },
      keyTerminology: {},
      visualSceneNotes: [],
      version: "stage4_v2",
    };

    const bibleSpy = jest.spyOn(
      require("../../src/pipeline/services/geminiDubbingEditor").geminiDubbingEditor,
      "generateLocalizationBible"
    );
    const editSpy = jest
      .spyOn(require("../../src/pipeline/services/geminiDubbingEditor").geminiDubbingEditor, "editSegments")
      .mockResolvedValue([
        { id: "L1", text: "నువ్వు రా.", usedDraft: false, syllables: 4, overBudget: false },
      ]);

    const res = await translationService.retranslateConcise(
      "Come here right now.",
      "en",
      "te",
      {
        currentTranslation: "నువ్వు వెంటనే ఇక్కడికి రావాలి అని చెప్తున్నాను.",
        maxDurationMs: 1200,
        speaker: "speaker_0",
        addressedTo: "speaker_1",
        bible,
        castList: [{ name: "Guard", gender: "male" }, { name: "Joseph", gender: "male" }] as any,
      }
    );

    expect(bibleSpy).not.toHaveBeenCalled();
    expect(editSpy).toHaveBeenCalledTimes(1);
    const callOpts = editSpy.mock.calls[0][1] as any;
    expect(callOpts.inferBible).toBe(false);
    expect(callOpts.bible).toEqual(bible);
    expect(callOpts.honorificCache.getLock("speaker_0", "speaker_1")?.formality).toBe("informal");
    expect(res).toBe("నువ్వు రా.");
  });
});
