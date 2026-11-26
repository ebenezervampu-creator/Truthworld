/**
 * Gemini dubbing editor (hybrid translation step 2) and scripture-citation guard.
 * Zero-credit: Gemini is replaced by an injected fake generate function.
 */

// These tests count and inspect the editor's own Gemini calls; the meaning check (one extra call,
// on by default) has its own tests in tests/pipeline/dubbing_meaning_check.test.ts.
process.env.DUBBING_MEANING_CHECK = "false";

import {
  GeminiDubbingEditor,
  EditorSegment,
  EditorOptions,
  syllableBudgetForDuration,
  permissibleWindowMs,
  bigramSimilarity,
  checkEditedLine,
  parseEditorReply,
  parseEditorReplyDetailed,
} from "../../src/pipeline/services/geminiDubbingEditor";
import {
  countSourceSyllables,
  normalizeScriptureCitationsForTts,
} from "../../src/pipeline/services/translation";
import {
  RollingHonorificCache,
  resolveRegisterDirective,
  computeCastHash,
  parseCastRelationships,
  CharacterRelationship,
  CastMember,
} from "../../src/pipeline/services/cast-list";

const baseOpts: EditorOptions = {
  jobId: "job_editor_test",
  sourceLanguage: "en",
  targetLanguage: "te",
  countSyllables: countSourceSyllables,
};

function fakeGenerate(replyFor: (lines: any[]) => any) {
  const calls: Array<{ system: string; prompt: any }> = [];
  const fn = async ({ system, prompt }: { model: string; system: string; prompt: string }) => {
    const parsed = JSON.parse(prompt);
    calls.push({ system, prompt: parsed });
    return { text: JSON.stringify(replyFor(parsed.lines)), inputTokens: 0, outputTokens: 0 };
  };
  return { fn, calls };
}

describe("Gemini dubbing editor", () => {
  describe("budget helpers", () => {
    test("syllable budget scales with time and language speed", () => {
      expect(syllableBudgetForDuration(2000, "en")).toBe(10); // 2 s x 4.8 x 1.1
      expect(syllableBudgetForDuration(2000, "te")).toBe(10); // 2 s x 4.8 x 1.1 (te measured 4.85 syl/s, 2026-11-24)
      expect(syllableBudgetForDuration(2000, "ta")).toBe(14); // 2 s x 6.5 x 1.1
      expect(syllableBudgetForDuration(50, "en")).toBe(2);    // floor
    });

    test("time window borrows from the pause after a line but never crosses the next line", () => {
      // 2 s line, next line starts 1 s later: may use 750 ms of the 1 s pause.
      expect(permissibleWindowMs(0, 2000, 3000)).toBe(2750);
      // Next line starts 50 ms later: stop 120 ms before it, even inside the line's own window.
      expect(permissibleWindowMs(0, 2000, 2050)).toBe(1930);
      // Pause capped at 1.5 s of borrowing.
      expect(permissibleWindowMs(0, 2000, 10000)).toBe(3500);
    });

    test("bigram similarity is 1 for identical text and low for unrelated text", () => {
      expect(bigramSimilarity("సత్యం ముఖ్యం", "సత్యం ముఖ్యం")).toBe(1);
      expect(bigramSimilarity("the meeting is at noon", "completely different words here")).toBeLessThan(0.3);
    });
  });

  describe("line checks", () => {
    const seg: EditorSegment = {
      id: "L1",
      source: "Prices rose 12% in 2024.",
      draft: "2024లో ధరలు 12% పెరిగాయి.",
    };

    test("accepts a faithful edit", () => {
      expect(checkEditedLine(seg, "2024లో ధరలు 12% పెరిగాయి", { targetLanguage: "te" }).ok).toBe(true);
    });

    test("rejects an edit that drops a number the draft kept", () => {
      const r = checkEditedLine(seg, "2024లో ధరలు బాగా పెరిగాయి.", { targetLanguage: "te" });
      expect(r).toEqual({ ok: false, reason: "number_mismatch" });
    });

    test("rejects empty text, label leaks and glossary regressions", () => {
      expect(checkEditedLine(seg, "  ", { targetLanguage: "te" }).reason).toBe("empty");
      expect(checkEditedLine(seg, "Translation: 2024లో ధరలు 12% పెరిగాయి", { targetLanguage: "te" }).reason).toBe("label_leak");
      const r = checkEditedLine(seg, "2024లో ధరలు 12% పెరిగాయి", {
        targetLanguage: "te",
        countGlossaryViolations: (_s, t) => (t.endsWith(".") ? 0 : 1),
      });
      expect(r.reason).toBe("glossary_regression");
    });

    test("rejects a rewrite that shares almost nothing with the draft", () => {
      const r = checkEditedLine(
        { id: "L1", source: "We met in Delhi.", draft: "మేము ఢిల్లీలో కలిశాము." },
        "వాతావరణం చాలా బాగుంది",
        { targetLanguage: "te" }
      );
      expect(r.reason).toBe("drift");
    });
  });

  describe("reply parsing", () => {
    test("parses the lines object and fenced JSON", () => {
      const map = parseEditorReply('```json\n{"lines":[{"id":"L1","text":"a"},{"id":"L2","text":"b"}]}\n```');
      expect(Array.from(map.entries())).toEqual([["L1", "a"], ["L2", "b"]]);
    });

    test("throws on repeated ids", () => {
      expect(() => parseEditorReply('{"lines":[{"id":"L1","text":"a"},{"id":"L1","text":"b"}]}')).toThrow();
    });
  });

  describe("editSegments", () => {
    const segments: EditorSegment[] = [
      { id: "L1", source: "This vaccine was tested", draft: "ఈ టీకాను పరీక్షించారు", speaker: "speaker_0", maxSyllables: 20 },
      { id: "L2", source: "on 4,000 people.", draft: "4,000 మందిపై.", speaker: "speaker_0", maxSyllables: 20 },
    ];

    test("returns edited lines in order and sends context, budget and draft to Gemini", async () => {
      const { fn, calls } = fakeGenerate((lines) => ({
        lines: lines.map((l: any) => ({ id: l.id, text: l.id === "L1" ? "ఈ టీకాను పరీక్షించారు," : l.draft })),
      }));
      const editor = new GeminiDubbingEditor(fn);
      const out = await editor.editSegments(segments, baseOpts);

      expect(out.map((r) => r.text)).toEqual(["ఈ టీకాను పరీక్షించారు,", "4,000 మందిపై."]);
      expect(out[0].usedDraft).toBe(false);
      expect(calls).toHaveLength(1);
      expect(calls[0].prompt.lines[0]).toMatchObject({ id: "L1", max_syllables: 20, draft: "ఈ టీకాను పరీక్షించారు" });
      expect(calls[0].system).toContain("Telugu");
      expect(calls[0].system).toContain("Never merge, split, drop or add lines");
    });

    test("keeps drafts when Gemini drops a line, after one retry", async () => {
      const { fn, calls } = fakeGenerate((lines) => ({ lines: lines.slice(0, 1).map((l: any) => ({ id: l.id, text: l.draft })) }));
      const editor = new GeminiDubbingEditor(fn);
      const out = await editor.editSegments(segments, baseOpts);
      expect(calls).toHaveLength(2);
      expect(out.every((r) => r.usedDraft && r.reason === "chunk_failed")).toBe(true);
      expect(out.map((r) => r.text)).toEqual(segments.map((s) => s.draft));
    });

    test("keeps the draft for a single line whose number changed, uses the edit for the rest", async () => {
      const { fn } = fakeGenerate((lines) => ({
        lines: lines.map((l: any) => ({ id: l.id, text: l.id === "L2" ? "400 మందిపై." : "ఈ టీకాను పరీక్షించారు," })),
      }));
      const out = await new GeminiDubbingEditor(fn).editSegments(segments, baseOpts);
      expect(out[0]).toMatchObject({ usedDraft: false, text: "ఈ టీకాను పరీక్షించారు," });
      expect(out[1]).toMatchObject({ usedDraft: true, reason: "number_mismatch", text: "4,000 మందిపై." });
    });

    test("runs a tighten pass only for lines far over budget", async () => {
      const long: EditorSegment[] = [{
        id: "L1",
        source: "Basically, what I really want to say is that the truth matters",
        draft: "నిజానికి, నేను నిజంగా చెప్పాలనుకుంటున్నది ఏమిటంటే సత్యం ముఖ్యం",
        maxSyllables: 8,
      }];
      let call = 0;
      const fn = async ({ prompt }: any) => {
        call++;
        const parsed = JSON.parse(prompt);
        const text = parsed.task.startsWith("Each line is too long")
          ? "నేను చెప్పాలనుకుంటున్నది సత్యం ముఖ్యం"
          : parsed.lines[0].draft;
        return { text: JSON.stringify({ lines: [{ id: "L1", text }] }), inputTokens: 0, outputTokens: 0 };
      };
      const out = await new GeminiDubbingEditor(fn).editSegments(long, baseOpts);
      expect(call).toBe(2);
      expect(out[0].text).toBe("నేను చెప్పాలనుకుంటున్నది సత్యం ముఖ్యం");
      expect(out[0].syllables).toBeLessThan(countSourceSyllables(long[0].draft, "te"));
    });

    test("splits long inputs into chunks with neighbouring context", async () => {
      const many: EditorSegment[] = Array.from({ length: 30 }, (_, i) => ({
        id: `L${i + 1}`, source: `Line ${i + 1}`, draft: `పంక్తి ${i + 1}`,
      }));
      const { fn, calls } = fakeGenerate((lines) => ({ lines: lines.map((l: any) => ({ id: l.id, text: l.draft })) }));
      const out = await new GeminiDubbingEditor(fn).editSegments(many, { ...baseOpts, chunkSize: 25, concurrency: 1 });
      expect(out).toHaveLength(30);
      expect(calls).toHaveLength(2);
      expect(calls[1].prompt.context_before.map((c: any) => c.source)).toEqual(["Line 22", "Line 23", "Line 24", "Line 25"]);
      expect(calls[0].prompt.context_after.map((c: any) => c.source)).toEqual(["Line 26", "Line 27", "Line 28"]);
    });
  });
});

describe("Scripture citation guard", () => {
  test("leaves times, scores and ratios alone in every language", () => {
    expect(normalizeScriptureCitationsForTts("The match ended 2:1 at 5:45 pm", "en")).toBe("The match ended 2:1 at 5:45 pm");
    expect(normalizeScriptureCitationsForTts("मीटिंग 10:30 बजे है, स्क्रीन 16:9 है", "hi")).toBe("मीटिंग 10:30 बजे है, स्क्रीन 16:9 है");
    expect(normalizeScriptureCitationsForTts("సమావేశం 10:30కి", "te")).toBe("సమావేశం 10:30కి");
  });

  test("converts citations that name the scripture, keeping the book name", () => {
    expect(normalizeScriptureCitationsForTts("Quran 4:157 says", "en")).toBe("Quran chapter 4, verse 157 says");
    expect(normalizeScriptureCitationsForTts("बाइबल 3:16", "hi")).toBe("बाइबल अध्याय 3, पद 16");
    expect(normalizeScriptureCitationsForTts("क़ुरआन 4:157", "hi")).toBe("क़ुरआन सूरह 4, आयत 157");
    expect(normalizeScriptureCitationsForTts("ఖురాన్ 4:157 లో", "te")).toBe("ఖురాన్ 4వ అధ్యాయం, 157వ వచనం లో");
    expect(normalizeScriptureCitationsForTts("Chapter 4:157", "en")).toBe("chapter 4, verse 157");
  });

  test("completes Telugu chapter phrasing without doubling the verse word", () => {
    expect(normalizeScriptureCitationsForTts("4వ అధ్యాయం, 157 లో", "te")).toBe("4వ అధ్యాయం, 157వ వచనంలో");
    expect(normalizeScriptureCitationsForTts("4వ అధ్యాయం, 157వ వచనంలో", "te")).toBe("4వ అధ్యాయం, 157వ వచనంలో");
  });
});

describe("Stage 4: Honorifics, Cast Relationships & Dual-Track", () => {
  describe("Honorific pronoun normalization in line checks", () => {
    test("accepts legitimate Telugu honorific promotion without triggering drift", () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "Come here please.",
        draft: "నువ్వు రా",
      };
      const result = checkEditedLine(seg, "మీరు రండి", { targetLanguage: "te" });
      expect(result.ok).toBe(true);
    });

    test("accepts legitimate Hindi honorific promotion without triggering drift", () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "Please sit down.",
        draft: "तुम बैठो",
      };
      const result = checkEditedLine(seg, "आप बैठिए", { targetLanguage: "hi" });
      expect(result.ok).toBe(true);
    });

    test("still rejects genuine drift on short lines", () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "Come here.",
        draft: "నువ్వు రా",
      };
      const result = checkEditedLine(seg, "సూర్యుడు ఉదయిస్తున్నాడు", { targetLanguage: "te" });
      expect(result.ok).toBe(false);
      expect(result.reason).toBe("drift");
    });
  });

  describe("RollingHonorificCache & cast relationships", () => {
    test("seeds from relationships and locks register against subsequent flips", () => {
      const cache = new RollingHonorificCache();
      const relationships: CharacterRelationship[] = [
        { fromSpeaker: "speaker_0", toSpeaker: "speaker_1", formality: "formal", relationship: "younger_elder" },
        { fromSpeaker: "speaker_1", toSpeaker: "speaker_0", formality: "informal", relationship: "elder_younger" },
      ];
      cache.seedFromRelationships(relationships);

      expect(cache.getLock("speaker_0", "speaker_1")?.formality).toBe("formal");
      expect(cache.getLock("speaker_1", "speaker_0")?.formality).toBe("informal");

      // Attempted flip across dialogue turns is ignored because already locked
      cache.recordIfUnset("speaker_0", "speaker_1", "informal", "నువ్వు", "L2");
      expect(cache.getLock("speaker_0", "speaker_1")?.formality).toBe("formal");

      const promptBlock = cache.toPromptBlock();
      expect(promptBlock).toContain("speaker_0->speaker_1: LOCKED to FORMAL");
      expect(promptBlock).toContain("speaker_1->speaker_0: LOCKED to INFORMAL");
    });

    test("resolveRegisterDirective produces accurate directives for Telugu, Hindi, Spanish", () => {
      const teFormal = resolveRegisterDirective("te", {
        fromSpeaker: "speaker_0",
        toSpeaker: "speaker_1",
        formality: "formal",
        relationship: "younger_elder",
      });
      expect(teFormal).toContain("FORMAL");
      expect(teFormal).toContain("మీరు");
      expect(teFormal).toContain("-ండి");

      const teInformal = resolveRegisterDirective("te", {
        fromSpeaker: "speaker_1",
        toSpeaker: "speaker_0",
        formality: "informal",
        relationship: "elder_younger",
      });
      expect(teInformal).toContain("INFORMAL");
      expect(teInformal).toContain("నువ్వు");
      expect(teInformal).toContain("-వు");

      const hiFormal = resolveRegisterDirective("hi", {
        fromSpeaker: "speaker_0",
        toSpeaker: "speaker_1",
        formality: "formal",
      });
      expect(hiFormal).toContain("FORMAL");
      expect(hiFormal).toContain("आप");
      expect(hiFormal).toContain("-इए");

      const esFormal = resolveRegisterDirective("es", {
        fromSpeaker: "speaker_0",
        toSpeaker: "speaker_1",
        formality: "formal",
      });
      expect(esFormal).toContain("usted");
    });

    test("computeCastHash produces deterministic and sensitive hashes", () => {
      const cast: CastMember[] = [
        { name: "Pastor", gender: "male" },
        { name: "Host", gender: "female" },
      ];
      const rels: CharacterRelationship[] = [
        { fromSpeaker: "Host", toSpeaker: "Pastor", formality: "formal" },
      ];

      const hash1 = computeCastHash(cast, rels, "stage4_v2");
      const hash2 = computeCastHash(cast, rels, "stage4_v2");
      expect(hash1).toBe(hash2);
      expect(hash1).toHaveLength(16);

      // Changing relationship alters hash
      const relsModified: CharacterRelationship[] = [
        { fromSpeaker: "Host", toSpeaker: "Pastor", formality: "informal" },
      ];
      const hashModified = computeCastHash(cast, relsModified, "stage4_v2");
      expect(hashModified).not.toBe(hash1);

      // Version bump alters hash
      const hashV3 = computeCastHash(cast, rels, "stage4_v3");
      expect(hashV3).not.toBe(hash1);
    });
  });

  describe("Chained chunk context passing (User Catch #2)", () => {
    test("passes finalized edited lines from Chunk N-1 into context_before for Chunk N", async () => {
      const segments: EditorSegment[] = [
        { id: "L1", source: "Hello elder brother.", draft: "నమస్కారం అన్నయ్య.", speaker: "speaker_0" },
        { id: "L2", source: "Please come inside.", draft: "లోపలికి రా.", speaker: "speaker_0" },
      ];

      const calls: any[] = [];
      const fn = async ({ prompt }: any) => {
        const parsed = JSON.parse(prompt);
        calls.push(parsed);
        const editedLine = parsed.lines[0].id === "L1"
          ? { id: "L1", text: "నమస్కారం అన్నయ్య గారూ,", subtitle_text: "నమస్కారం అన్నయ్య గారూ," }
          : { id: "L2", text: "దయచేసి లోపలికి రండి.", subtitle_text: "దయచేసి లోపలికి రండి." };
        return {
          text: JSON.stringify({ lines: [editedLine] }),
          inputTokens: 0,
          outputTokens: 0,
        };
      };

      const editor = new GeminiDubbingEditor(fn);
      // Run with chunkSize: 1 so each segment is its own chunk
      const out = await editor.editSegments(segments, {
        ...baseOpts,
        chunkSize: 1,
        enableDualTrack: true,
      });

      expect(out).toHaveLength(2);
      expect(calls).toHaveLength(2);

      // Verify Chunk 2 received finalized edited line from Chunk 1 in context_before
      const chunk2ContextBefore = calls[1].context_before;
      expect(chunk2ContextBefore).toHaveLength(1);
      expect(chunk2ContextBefore[0].id).toBe("L1");
      expect(chunk2ContextBefore[0].source).toBe("Hello elder brother.");
      // MUST contain finalized target text, not raw draft
      expect(chunk2ContextBefore[0].finalized_target_text).toBe("నమస్కారం అన్నయ్య గారూ,");
    });
  });

  describe("Dual-Track Dub & Subtitle Output (User Catch #3)", () => {
    test("parseEditorReplyDetailed extracts both spoken dubText and written subtitleText", () => {
      const rawJson = JSON.stringify({
        lines: [
          {
            id: "L1",
            text: "యోహాను మూడవ అధ్యాయం పదహారవ వచనం వినండి",
            subtitle_text: "యోహాను 3:16",
            applied_register: "FORMAL",
          },
        ],
      });

      const detailed = parseEditorReplyDetailed(rawJson);
      expect(detailed.size).toBe(1);
      const l1 = detailed.get("L1");
      expect(l1?.text).toBe("యోహాను మూడవ అధ్యాయం పదహారవ వచనం వినండి");
      expect(l1?.subtitleText).toBe("యోహాను 3:16");
      expect(l1?.appliedRegister).toBe("FORMAL");
    });

    test("editSegments propagates dual-track subtitleText when enableDualTrack is true", async () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "John 3:16 is our guiding message.",
        draft: "యోహాను 3:16 మా మార్గదర్శక సందేశం.",
      };

      const fn = async () => ({
        text: JSON.stringify({
          lines: [
            {
              id: "L1",
              text: "యోహాను 3:16 మన మార్గదర్శక సందేశం అండి.",
              subtitle_text: "యోహాను 3:16 మన మార్గదర్శక సందేశం.",
              applied_register: "FORMAL",
            },
          ],
        }),
        inputTokens: 0,
        outputTokens: 0,
      });

      const editor = new GeminiDubbingEditor(fn);
      const out = await editor.editSegments([seg], { ...baseOpts, enableDualTrack: true });

      expect(out).toHaveLength(1);
      expect(out[0].text).toBe("యోహాను 3:16 మన మార్గదర్శక సందేశం అండి.");
      expect(out[0].subtitleText).toBe("యోహాను 3:16 మన మార్గదర్శక సందేశం.");
      expect(out[0].appliedRegister).toBe("FORMAL");
    });
  });

  describe("Pass 4A (LocalizationBible) & Pass 4B (Scene-Parallel Chunking & Transcreation)", () => {
    test("Gotcha #1: allows culturally natural transcreation with low bigram similarity when self-tagged transcreationMode", () => {
      const idiomSeg: EditorSegment = {
        id: "L1",
        source: "Break a leg!",
        draft: "ఒక కాలు విరగ్గొట్టుకోండి!", // Literal MT draft (nonsense)
      };

      // Native transcreation: "విజయోస్తు!" (all the best / victory be yours) shares 0% bigrams with literal draft
      const nativeTranscreation = "విజయోస్తు!";

      // Without transcreationMode: rejected as drift
      const rejected = checkEditedLine(idiomSeg, nativeTranscreation, { targetLanguage: "te" });
      expect(rejected.ok).toBe(false);
      expect(rejected.reason).toBe("drift");

      // With transcreationMode: true -> passes
      const accepted = checkEditedLine(
        idiomSeg,
        nativeTranscreation,
        { targetLanguage: "te" },
        { transcreationMode: true, idiomReason: "Idiomatic wish for good performance transcreated to Telugu equivalent" }
      );
      expect(accepted.ok).toBe(true);
    });

    test("Gotcha #1: strictly rejects transcreation if numbers or dates are altered or dropped", () => {
      const numIdiomSeg: EditorSegment = {
        id: "L1",
        source: "We hit 3 birds with that stone.",
        draft: "మేము ఆ దెబ్బకు 3 పిట్టలను కొట్టాము.",
      };

      // Transcreation that changes the number 3 to 2
      const badTranscreation = "మేము ఆ దెబ్బకు 2 పిట్టలను కొట్టాము.";

      const check = checkEditedLine(
        numIdiomSeg,
        badTranscreation,
        { targetLanguage: "te" },
        { transcreationMode: true, idiomReason: "Proverb adaptation" }
      );
      expect(check.ok).toBe(false);
      expect(check.reason).toBe("number_mismatch");
    });

    test("Pass 4A: generateLocalizationBible locks registers from speaker dialogue samples", async () => {
      const multiSpeaker: EditorSegment[] = [
        { id: "L1", speaker: "speaker_0", addressedTo: "speaker_1", source: "Hello Doctor.", draft: "నమస్కారం డాక్టర్." },
        { id: "L2", speaker: "speaker_1", addressedTo: "speaker_0", source: "Please sit down.", draft: "దయచేసి కూర్చోండి." },
      ];

      const fn = async () => ({
        text: JSON.stringify({
          locked_registers: [
            { from_speaker: "speaker_0", to_speaker: "speaker_1", formality: "deferential" },
            { from_speaker: "speaker_1", to_speaker: "speaker_0", formality: "formal" },
          ],
          key_terminology: [
            { term: "Doctor", target_preferred: "డాక్టర్ గారు" },
          ],
        }),
        inputTokens: 0,
        outputTokens: 0,
      });

      const editor = new GeminiDubbingEditor(fn);
      const bible = await editor.generateLocalizationBible(multiSpeaker, { ...baseOpts, inferBible: true });

      expect(bible.lockedRegisters["speaker_0->speaker_1"]).toBe("deferential");
      expect(bible.lockedRegisters["speaker_1->speaker_0"]).toBe("formal");
      expect(bible.keyTerminology?.["Doctor"]).toBe("డాక్టర్ గారు");
    });

    test("Gotcha #2: scene-parallel chunking passes pure source lines (no raw MT drafts) in context_before", async () => {
      const many: EditorSegment[] = Array.from({ length: 4 }, (_, i) => ({
        id: `L${i + 1}`,
        speaker: `speaker_${i % 2}`,
        source: `Source sentence ${i + 1}`,
        draft: `కలుషిత ముసాయిదా ${i + 1}`, // Raw MT draft with potentially bad pronouns
      }));

      const calls: any[] = [];
      const fn = async ({ prompt }: any) => {
        const parsed = JSON.parse(prompt);
        calls.push(parsed);
        return {
          text: JSON.stringify({
            lines: parsed.lines.map((l: any) => ({
              id: l.id,
              text: `అనువదించిన వాక్యం ${l.id}`,
              subtitle_text: `అనువదించిన వాక్యం ${l.id}`,
            })),
          }),
          inputTokens: 0,
          outputTokens: 0,
        };
      };

      const editor = new GeminiDubbingEditor(fn);
      // Run with chunkSize: 2 and concurrency: 2
      const out = await editor.editSegments(many, {
        ...baseOpts,
        chunkSize: 2,
        concurrency: 2,
        inferBible: false, // Skip pre-pass LLM call for unit test simplicity
      });

      expect(out).toHaveLength(4);
      // Verify Chunk 2 received pure source lines in context_before, WITHOUT raw MT drafts
      const chunk2Call = calls.find((c) => c.lines.some((l: any) => l.id === "L3"));
      expect(chunk2Call).toBeDefined();
      expect(chunk2Call.context_before.length).toBeGreaterThan(0);
      for (const ctx of chunk2Call.context_before) {
        expect(ctx.source).toMatch(/^Source sentence/);
        // Pure source line constraint: finalized_target_text must NOT contain raw MT draft!
        expect(ctx.finalized_target_text).toBeUndefined();
      }
    });

    test("Fix 1.3: rejects bad subtitleText that drops a number and falls back to checked spoken text", async () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "Prices rose 12% in 2024.",
        draft: "2024లో ధరలు 12% పెరిగాయి.",
      };
      const { fn } = fakeGenerate(() => ({
        lines: [
          {
            id: "L1",
            text: "2024లో ధరలు 12% పెరిగాయి.",
            subtitle_text: "ధరలు పెరిగాయి.", // drops 2024 and 12%
          },
        ],
      }));
      const editor = new GeminiDubbingEditor(fn);
      const [out] = await editor.editSegments([seg], { ...baseOpts, inferBible: false });
      expect(out.text).toBe("2024లో ధరలు 12% పెరిగాయి.");
      expect(out.subtitleText).toBe("2024లో ధరలు 12% పెరిగాయి.");
      expect(out.subtitleRejectReason).toBe("number_mismatch");
    });

    test("Fix 1.3: when both spoken text and subtitleText fail checkEditedLine, both fall back to draft", async () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "Prices rose 12% in 2024.",
        draft: "2024లో ధరలు 12% పెరిగాయి.",
      };
      const { fn } = fakeGenerate(() => ({
        lines: [
          {
            id: "L1",
            text: "ధరలు పెరిగాయి.", // drops numbers
            subtitle_text: "ధరలు పెరిగాయి.", // also drops numbers
          },
        ],
      }));
      const editor = new GeminiDubbingEditor(fn);
      const [out] = await editor.editSegments([seg], { ...baseOpts, inferBible: false });
      expect(out.usedDraft).toBe(true);
      expect(out.text).toBe(seg.draft);
      expect(out.subtitleText).toBe(seg.draft);
      expect(out.subtitleRejectReason).toBe("number_mismatch");
    });

    test("Fix 2.5: Hindi->Telugu edit equal to Hindi source is rejected as untranslated, while Telugu->Telugu condense is accepted", () => {
      const hiToTeSeg: EditorSegment = {
        id: "L1",
        source: "प्रभु ने उन्हें छुड़ाया।",
        draft: "ప్రభువు వారిని విడిపించాడు.",
      };
      const rejected = checkEditedLine(hiToTeSeg, "प्रभु ने उन्हें छुड़ाया।", {
        sourceLanguage: "hi",
        targetLanguage: "te",
      });
      expect(rejected).toEqual({ ok: false, reason: "untranslated" });

      const teCondenseSeg: EditorSegment = {
        id: "C1",
        source: "ప్రభువు వారిని విడిపించాడు.",
        draft: "ప్రభువు వారిని విడిపించాడు.",
      };
      const accepted = checkEditedLine(teCondenseSeg, "ప్రభువు వారిని విడిపించాడు.", {
        sourceLanguage: "te",
        targetLanguage: "te",
      });
      expect(accepted.ok).toBe(true);
    });

    test("Fix 3.5: over-budget draft with rejected edit triggers constrained tighten call and marks overBudgetAfterEdit if still over", async () => {
      const seg: EditorSegment = {
        id: "L1",
        source: "Prices rose 12% in 2024.",
        draft: "2024లో ధరలు 12% చాలా ఎక్కువగా పెరిగిపోయాయి అని చెప్పారు.", // 20+ syllables
        maxSyllables: 10, // TIGHTEN_TRIGGER = 11.5
      };

      let callCount = 0;
      const editor = new GeminiDubbingEditor(async () => {
        callCount++;
        if (callCount <= 2) {
          // Initial edit & first tighten drop the number -> rejected
          return {
            text: JSON.stringify({ lines: [{ id: "L1", text: "ధరలు పెరిగాయి." }] }),
            inputTokens: 0,
            outputTokens: 0,
          };
        }
        // Constrained call also drops number -> rejected -> stays overBudgetAfterEdit
        return {
          text: JSON.stringify({ lines: [{ id: "L1", text: "ధరలు బాగా పెరిగాయి." }] }),
          inputTokens: 0,
          outputTokens: 0,
        };
      });

      const [out] = await editor.editSegments([seg], { ...baseOpts, inferBible: false });
      expect(callCount).toBe(3); // edit + tighten + constrained fallback
      expect(out.text).toBe(seg.draft);
      expect(out.overBudgetAfterEdit).toBe(true);
    });
  });
});
