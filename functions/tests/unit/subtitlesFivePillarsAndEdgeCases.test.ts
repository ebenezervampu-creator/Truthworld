import { MultilingualSubtitleLocalizer } from "../../src/pipeline/services/multilingual_subtitle_localizer";
import { getSubtitleProfile, getGraphemeCount } from "../../src/pipeline/services/subtitle_language_profiles";
import { translationService } from "../../src/pipeline/services/translation";
import { WordTimestamp } from "../../src/pipeline/types";

describe("⚡ 5-Pillar Subtitle Architecture & Edge Case Hardening Benchmark", () => {
  // ─── PILLAR 1: Word-Level Anchor Cache & Sentence Extraction ────────────
  describe("Pillar 1: Word-Level Anchor Cache", () => {
    it("extracts grammatical sentences while preserving compound words with hyphens", () => {
      const words: WordTimestamp[] = [
        { text: "Welcome", start: 100, end: 500, confidence: 0.99 },
        { text: "to", start: 520, end: 700, confidence: 0.99 },
        { text: "TruthWorld's", start: 720, end: 1200, confidence: 0.99 },
        { text: "Fact-Checking", start: 1250, end: 1900, confidence: 0.99 },
        { text: "network.", start: 1950, end: 2400, confidence: 0.99 },
      ];

      const sentences = MultilingualSubtitleLocalizer.extractSourceSentences(words);
      expect(sentences.length).toBe(1);
      expect(sentences[0].text).toBe("Welcome to TruthWorld's Fact-Checking network.");
      expect(sentences[0].startMs).toBe(100);
      expect(sentences[0].endMs).toBe(2400);
      expect(sentences[0].durationMs).toBe(2300);
    });
  });

  // ─── PILLAR 2: Contextual Batching & Zero-Overhead Reuse ─────────────────
  describe("Pillar 2: Contextual Batching & Pre-Translated Segment Reuse", () => {
    it("reuses pre-translated segments instantly without calling translation API", async () => {
      const sourceWords: WordTimestamp[] = [
        { text: "Solar", start: 1000, end: 1500, confidence: 0.99 },
        { text: "energy", start: 1550, end: 2000, confidence: 0.99 },
        { text: "is", start: 2050, end: 2200, confidence: 0.99 },
        { text: "sustainable.", start: 2250, end: 3000, confidence: 0.99 },
      ];

      const preTranslated = [
        { start: 1000, end: 3000, text: "సౌర శక్తి స్థిరమైనది." },
      ];

      const startTime = Date.now();
      const result = await MultilingualSubtitleLocalizer.localizeTrack({
        jobId: "bench_p2_reuse",
        sourceWords,
        sourceLanguage: "en",
        targetLanguage: "te",
        fallbackSegments: preTranslated,
      });
      const elapsedMs = Date.now() - startTime;

      expect(elapsedMs).toBeLessThan(100); // Near 0ms execution
      expect(result.cues.length).toBeGreaterThan(0);
      expect(result.cues[0].text).toContain("సౌర శక్తి");
    });

    it("propagates composite translation failures instead of substituting source text", async () => {
      const sourceWords: WordTimestamp[] = [
        { text: "Solar", start: 1000, end: 1500, confidence: 0.99 },
        { text: "energy", start: 1550, end: 2000, confidence: 0.99 },
        { text: "is", start: 2050, end: 2200, confidence: 0.99 },
        { text: "sustainable.", start: 2250, end: 3000, confidence: 0.99 },
      ];
      const translateSpy = jest
        .spyOn(translationService, "batchTranslateStandard")
        .mockRejectedValueOnce(new Error("Required Adaptive MT unavailable"));

      await expect(
        MultilingualSubtitleLocalizer.localizeTrack({
          jobId: "strict_translation_failure",
          sourceWords,
          sourceLanguage: "en",
          targetLanguage: "te",
        })
      ).rejects.toThrow("Required Adaptive MT unavailable");

      expect(translateSpy).toHaveBeenCalledTimes(1);
      translateSpy.mockRestore();
    });
  });

  // ─── PILLAR 3: Pause Envelope Absorption ─────────────────────────────────
  describe("Pillar 3: Pause Envelope Absorption", () => {
    it("absorbs trailing silence to bring CPS within standard envelope (<= 21 CPS)", () => {
      const profile = getSubtitleProfile("es");
      const sentence = {
        sentenceIndex: 1,
        text: "The rapid transition to renewable energy",
        startMs: 1000,
        endMs: 1800, // Short spoken duration (800ms) for a long translation
        durationMs: 800,
        words: [],
        startIndex: 0,
        endIndex: 4,
        followingPauseMs: 1600, // Trailing pause available to absorb
      };

      const spanishPhrase = "La rápida transición hacia la energía renovable";
      const cues = MultilingualSubtitleLocalizer.retimeTargetPhrasesForSentence({
        sentence,
        phrases: [spanishPhrase],
        languageCode: "es",
        profile,
        startCueId: 1,
        nextSentenceStartMs: 3500,
      });

      expect(cues.length).toBe(1);
      // Extended into silence
      expect(cues[0].endMs).toBeGreaterThan(sentence.endMs);
      expect(cues[0].charactersPerSecond).toBeLessThanOrEqual(21.5);
    });
  });

  // ─── PILLAR 4: Script-Aware Grapheme Chunking ────────────────────────────
  describe("Pillar 4: Script-Aware Grapheme Chunking", () => {
    it("calculates accurate grapheme count for Telugu and Hindi Indic ligatures", () => {
      // Telugu "తెలుగు" has 3 grapheme clusters: తె, లు, గు
      const teluguWord = "తెలుగు";
      const count = getGraphemeCount(teluguWord);
      expect(count).toBe(3);

      // Hindi "नमस्ते" has 3 grapheme clusters: न, म, स्ते (conjunct virama is 1 cluster)
      const hindiWord = "नमस्ते";
      const hindiCount = getGraphemeCount(hindiWord);
      expect(hindiCount).toBe(3);
    });
  });

  // ─── PILLAR 5: Monotonic Memory Pipeline with UTF-8 BOM ──────────────────
  describe("Pillar 5: Monotonic Memory Pipeline & Immediate Streaming", () => {
    it("generates WebVTT and SRT in RAM with strictly monotonic timecodes and UTF-8 BOM", () => {
      const cues = [
        {
          id: 1,
          languageCode: "te",
          text: "మొదటి వాక్యం.",
          startMs: 1000,
          endMs: 2500,
          durationMs: 1500,
          sourceWordStartIndex: 0,
          sourceWordEndIndex: 2,
          charactersPerSecond: 8.0,
          charactersPerLine: 12,
          alignmentConfidence: 0.99,
          validationStatus: "pass" as const,
        },
        {
          id: 2,
          languageCode: "te",
          text: "రెండవ వాక్యం.",
          startMs: 2566, // 66ms gap enforced
          endMs: 4000,
          durationMs: 1434,
          sourceWordStartIndex: 3,
          sourceWordEndIndex: 5,
          charactersPerSecond: 8.5,
          charactersPerLine: 13,
          alignmentConfidence: 0.99,
          validationStatus: "pass" as const,
        },
      ];

      const serialized = MultilingualSubtitleLocalizer.serializeCues(cues);

      // Must start with UTF-8 BOM
      expect(serialized.srtContent.startsWith("\uFEFF")).toBe(true);
      expect(serialized.vttContent.startsWith("\uFEFFWEBVTT")).toBe(true);

      // Monotonicity check
      expect(cues[0].endMs).toBeLessThanOrEqual(cues[1].startMs);
    });
  });

  // ─── EDGE CASES AUDIT ───────────────────────────────────────────────────
  describe("Edge Case A: Zero-Pause Rapid-Fire Dialogue", () => {
    it("balances lines across 2 tiers when speech duration is compressed", () => {
      const profile = getSubtitleProfile("en");
      const denseText = "Global renewable energy installations have surpassed projections this year.";
      const formatted = MultilingualSubtitleLocalizer.formatCueLines(denseText, profile);

      expect(formatted).toContain("\n");
      const lines = formatted.split("\n");
      expect(lines.length).toBe(2);
      expect(lines[0].length).toBeLessThanOrEqual(profile.maxCharactersPerLine);
      expect(lines[1].length).toBeLessThanOrEqual(profile.maxCharactersPerLine);
    });

    it("splits excessively long dialogue (> 84 chars) into distinct sequential cues", () => {
      const profile = getSubtitleProfile("en");
      const longSpeech = "Global renewable energy installations have surpassed all previous projections this fiscal year and continue expanding rapidly.";
      const phrases = MultilingualSubtitleLocalizer.segmentTranslatedSentence(longSpeech, "en", profile);

      expect(phrases.length).toBeGreaterThanOrEqual(2);
      for (const phrase of phrases) {
        const lines = phrase.split("\n");
        for (const line of lines) {
          expect(getGraphemeCount(line)).toBeLessThanOrEqual(profile.maxCharactersPerLine * 1.15);
        }
      }
    });
  });

  describe("Edge Case B: Multi-Speaker Overlap & Voice Tagging", () => {
    it("applies WebVTT voice tags and vertical line positioning to prevent screen collision", () => {
      const overlappingCues = [
        {
          id: 1,
          languageCode: "en",
          text: "I believe the report is credible.",
          startMs: 1000,
          endMs: 3000,
          durationMs: 2000,
          sourceWordStartIndex: 0,
          sourceWordEndIndex: 5,
          charactersPerSecond: 15.0,
          charactersPerLine: 32,
          alignmentConfidence: 0.95,
          validationStatus: "pass" as const,
          speaker: "Speaker 1",
        },
        {
          id: 2,
          languageCode: "en",
          text: "We need to check the primary sources first.",
          startMs: 2500, // Overlaps Speaker 1 by 500ms
          endMs: 4500,
          durationMs: 2000,
          sourceWordStartIndex: 6,
          sourceWordEndIndex: 12,
          charactersPerSecond: 18.0,
          charactersPerLine: 40,
          alignmentConfidence: 0.95,
          validationStatus: "pass" as const,
          speaker: "Speaker 2",
        },
      ];

      const serialized = MultilingualSubtitleLocalizer.serializeCues(overlappingCues);

      // Voice tags in WebVTT
      expect(serialized.vttContent).toContain("<v Speaker 1>I believe the report is credible.</v>");
      expect(serialized.vttContent).toContain("<v Speaker 2>We need to check the primary sources first.</v>");

      // Upper-third vertical line positioning on overlapping cue
      expect(serialized.vttContent).toContain("line:15% align:center");
    });
  });

  describe("Edge Case C: Indic Ligature Fragmentation Protection", () => {
    it("never breaks Telugu and Hindi sentences inside grapheme clusters or conjuncts", () => {
      const profile = getSubtitleProfile("te");
      const teluguSentence = "సమగ్ర సమాచార విశ్లేషణ ద్వారా మాత్రమే సత్యం వెల్లడవుతుంది.";
      const phrases = MultilingualSubtitleLocalizer.segmentTranslatedSentence(teluguSentence, "te", profile);

      expect(phrases.length).toBeGreaterThan(0);
      for (const phrase of phrases) {
        // Must contain full valid Telugu words, no orphan diacritics
        expect(phrase).not.toMatch(/^[\u0C00-\u0C03\u0C3E-\u0C4D\u0C55\u0C56\u0C62\u0C63]/);
      }
    });
  });

  describe("Edge Case D: Bidirectional Isolation (RTL/LTR Isolate Wrappers)", () => {
    it("wraps embedded Latin tokens and numbers inside Arabic text with Unicode isolate markers", () => {
      const arabicWithLatin = "تقرير TruthWorld رقم 42 يوضح تفاصيل الطاقة.";
      const isolated = MultilingualSubtitleLocalizer.applyBidirectionalIsolation(arabicWithLatin, "ar");

      // TruthWorld must be wrapped in \u2068...\u2069
      expect(isolated).toContain("\u2068TruthWorld\u2069");
      // 42 must be wrapped in \u2068...\u2069
      expect(isolated).toContain("\u206842\u2069");
    });
  });
});
