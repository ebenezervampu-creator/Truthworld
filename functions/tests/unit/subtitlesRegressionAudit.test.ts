import { SubtitleGuardrails } from "../../src/pipeline/services/subtitleGuardrails";
import { MultilingualSubtitleLocalizer } from "../../src/pipeline/services/multilingual_subtitle_localizer";
import { getSubtitleProfile, getGraphemeCount } from "../../src/pipeline/services/subtitle_language_profiles";
import { WordTimestamp } from "../../src/pipeline/types";

describe("🛡️ Subtitle Post-Translation Guardrails & Regression Audit", () => {
  // ─── TEST 1: Cross-Script Unicode Bleed Defense ──────────────────────────
  describe("Unicode Script Isolation & Dravidian Leak Prevention", () => {
    it("detects and replaces stray Malayalam (U+0D00-U+0D7F) glyphs in Telugu output", () => {
      const contaminatedTelugu = "గ్రామీణ ప్రాంతాల్లోని പഴയ వ్యవస్థను ఆధునీకరించడం.";
      const sanitized = SubtitleGuardrails.sanitizeCrossScriptBleed(contaminatedTelugu, "te");

      // Verify Malayalam characters are completely eradicated
      const malayalamRegex = /[\u0D00-\u0D7F]/;
      expect(malayalamRegex.test(sanitized)).toBe(false);

      // Verify clean Telugu replacement
      expect(sanitized).toContain("పాత");
      expect(sanitized).toBe("గ్రామీణ ప్రాంతాల్లోని పాత వ్యవస్థను ఆధునీకరించడం.");
    });

    it("strips foreign Dravidian glyphs (Kannada U+0C80-U+0CFF) in Telugu output", () => {
      const mixedText = "ఇది ఒక ಹೊಸ ఆలోచన.";
      const sanitized = SubtitleGuardrails.sanitizeCrossScriptBleed(mixedText, "te");

      const kannadaRegex = /[\u0C80-\u0CFF]/;
      expect(kannadaRegex.test(sanitized)).toBe(false);
      expect(sanitized).toContain("కొత్త");
    });
  });

  // ─── TEST 2: Numerical & Currency Token Integrity ────────────────────────
  describe("Numerical & Currency Re-Fusion Guardrails", () => {
    it("re-fuses split lakh-crore currency figures without loss of precision", () => {
      const splitCurrency = "1.2 లక్షల కోట్లు, కేవలం మొదటి 50 రోజుల్లోనే 28 లక్షల కోట్ల రూపాయలు";
      const repaired = SubtitleGuardrails.repairSplitNumericsAndCurrency(splitCurrency);

      expect(repaired).toContain("రూ. 1.28 లక్షల కోట్ల రూపాయలు");
      expect(repaired).not.toContain("1.2 లక్షల కోట్లు,");
    });

    it("re-fuses broken comma-separated numbers and percentages", () => {
      const input = "మొత్తం ₹60, 000 కోట్ల నకిలీ నోట్లు, మరియు 99. 3% రికవరీ.";
      const repaired = SubtitleGuardrails.repairSplitNumericsAndCurrency(input);

      expect(repaired).toContain("రూ. 60,000 కోట్ల");
      expect(repaired).toContain("99.3%");
    });

    it("fuses phonetically expanded decimals to standard numeral percentage", () => {
      const rawDecimal = "సున్నా పాయింట్ జీరో రెండు ఐదు శాతం";
      const repaired = SubtitleGuardrails.repairSplitNumericsAndCurrency(rawDecimal);

      expect(repaired).toBe("0.025%");
    });
  });

  // ─── TEST 3: RTL Bidirectional Isolation ─────────────────────────────────
  describe("Bidirectional (RTL) First Strong Isolation", () => {
    it("wraps Latin identifiers and numbers inside Arabic/Urdu with U+2068 and U+2069", () => {
      const rtlWithLatin = "تقرير خاص عن Operation Green Leaf في عام 2016.";
      const isolated = SubtitleGuardrails.applyBidirectionalIsolation(rtlWithLatin, "ar");

      expect(isolated).toContain("\u2068Operation\u2069");
      expect(isolated).toContain("\u2068Green\u2069");
      expect(isolated).toContain("\u2068Leaf\u2069");
      expect(isolated).toContain("\u20682016\u2069");
    });
  });

  // ─── TEST 4: Full Pipeline End-to-End Regression Verification ────────────
  describe("Full Pipeline Localizer Integration & Standard Compliance", () => {
    it("enforces grapheme boundaries, monotonic gaps (>=66ms), and UTF-8 BOM headers", async () => {
      const sourceWords: WordTimestamp[] = [
        { text: "The", start: 1000, end: 1200, confidence: 0.99 },
        { text: "cost", start: 1250, end: 1500, confidence: 0.99 },
        { text: "was", start: 1550, end: 1700, confidence: 0.99 },
        { text: "estimated", start: 1750, end: 2300, confidence: 0.99 },
        { text: "at", start: 2350, end: 2500, confidence: 0.99 },
        { text: "1.28", start: 2550, end: 3000, confidence: 0.99 },
        { text: "lakh", start: 3050, end: 3300, confidence: 0.99 },
        { text: "crore.", start: 3350, end: 3900, confidence: 0.99 },
        { text: "Old", start: 4500, end: 4800, confidence: 0.99 },
        { text: "currency", start: 4850, end: 5300, confidence: 0.99 },
        { text: "returned", start: 5350, end: 5800, confidence: 0.99 },
        { text: "at", start: 5850, end: 6000, confidence: 0.99 },
        { text: "99.3%.", start: 6050, end: 6600, confidence: 0.99 },
      ];

      // Feed pre-translated segments contaminated with Malayalam bleed and split numerics
      const fallbackSegments = [
        {
          start: 1000,
          end: 3900,
          text: "మొదటి 50 రోజుల్లోనే ఆర్థిక నష్టం 1.2 లక్షల కోట్లు, 28 లక్షల కోట్ల రూపాయలుగా అంచనా వేయబడింది.",
        },
        {
          start: 4500,
          end: 6600,
          text: "బ్యాంకింగ్ వ్యవస్థకు తిరిగి వచ్చిన പഴയ కరెన్సీ 99. 3% గా ఉంది.",
        },
      ];

      const result = await MultilingualSubtitleLocalizer.localizeTrack({
        jobId: "audit_regression_01",
        sourceWords,
        sourceLanguage: "en",
        targetLanguage: "te",
        fallbackSegments,
      });

      // 1. Verify UTF-8 BOM (\uFEFF)
      expect(result.vttContent.startsWith("\uFEFFWEBVTT")).toBe(true);
      expect(result.srtContent.startsWith("\uFEFF1\r\n") || result.srtContent.startsWith("\uFEFF1\n")).toBe(true);

      // 2. Verify Cross-Script Bleed is sanitized in both Cues and VTT/SRT
      const malayalamRegex = /[\u0D00-\u0D7F]/;
      expect(malayalamRegex.test(result.vttContent)).toBe(false);
      expect(malayalamRegex.test(result.srtContent)).toBe(false);
      expect(result.vttContent).toContain("పాత కరెన్సీ");

      // 3. Verify Numeric Re-Fusion in output
      expect(result.vttContent).toMatch(/రూ\.\s*1\.28[\s\n]+లక్షల\s*కోట్ల/);
      expect(result.vttContent).toContain("99.3%");

      // 4. Verify Monotonicity and Inter-cue gaps (>= 66ms)
      for (let i = 0; i < result.cues.length - 1; i++) {
        const currentCue = result.cues[i];
        const nextCue = result.cues[i + 1];
        expect(nextCue.startMs).toBeGreaterThanOrEqual(currentCue.endMs + 66);
      }

      // 5. Verify Indic Grapheme limits (<= maxCharactersPerLine according to Telugu profile)
      const teProfile = getSubtitleProfile("te");
      for (const cue of result.cues) {
        const lines = cue.text.split("\n");
        for (const line of lines) {
          const graphemes = getGraphemeCount(line);
          expect(graphemes).toBeLessThanOrEqual(teProfile.maxCharactersPerLine);
        }
      }
    });
  });
});
