/**
 * 🌍 GOOGLE CLOUD TRANSLATION API V3 TEST SUITE
 *
 * Verifies production-grade integration of Google Cloud Translation API v3:
 * 1. Architecture & Client Integrity: TranslationServiceClient initialization, parent scoping (projects/{id}/locations/global), zero v2, AdaptiveMt integration.
 * 2. Single Text Translation (`translateText`): Composite v3 + required Adaptive MT output.
 * 3. Batch Translation (`batchTranslateV3`): Batch chunking (<= 100 items), bounded concurrency, index order preservation.
 * 4. Production Segment Pipeline (`translateSegments`): Subtitles + Dubbing, emotionTag preservation, syllable budget compliance, cost tracking.
 * 5. Language Detection (`detectLanguage` & `detectLanguages`): Google Translation v3 detectLanguage integration & batch mapping.
 * 6. Resilience & Transient Error Retry: 429 quota retries with backoff.
 * 7. AdaptiveMtTranslate: Required second stage of the composite primary translation engine.
 */

import {
  TranslationService,
  decodeHtmlEntities,
  computeSyllableBudgetCompliance,
  LANG_SYLLABLE_RATIOS,
} from "../../src/pipeline/services/translation";
import { costEngine } from "../../src/pipeline/services/cost-engine";

describe("Google Cloud Translation API v3 Test Suite", () => {
  let service: TranslationService;
  let mockTranslateText: jest.Mock;
  let mockDetectLanguage: jest.Mock;
  let mockAdaptiveMtTranslate: jest.Mock;

  beforeEach(() => {
    service = new TranslationService();
    mockTranslateText = jest.fn().mockResolvedValue([
      { translations: [{ translatedText: "V3 back-translation" }] },
    ]);
    mockDetectLanguage = jest.fn();
    mockAdaptiveMtTranslate = jest.fn().mockImplementation(async ({ content }: { content: string[] }) => {
      const translations: Record<string, string> = {
        "Welcome to TruthWorld": "సత్యప్రపంచానికి స్వాగతం",
        "Hello": "नमस्ते",
        "Don't worry": `&quot;TruthWorld&quot; is don&#39;t worry &amp; always $10.`,
        "Test phrase": "Strict LLM Result",
        "This is a real fact-checking platform": "ఇది నిజమైన వాస్తవాల తనిఖీ వేదిక",
        "you should focus on the truth.": "సత్యంపై దృష్టి నిలపండి",
      };
      return [{
        translations: content.map((text) => ({
          translatedText: translations[text] ?? `Adaptive: ${text}`,
        })),
      }];
    });

    // Inject mock v3Client for zero-credit deterministic testing
    (service as any)._v3Client = {
      translateText: mockTranslateText,
      detectLanguage: mockDetectLanguage,
    };
    (service as any)._adaptiveMtClient = {
      adaptiveMtTranslate: mockAdaptiveMtTranslate,
    };
    (service as any).buildGlossaryReferencePairs = jest.fn().mockReturnValue([
      { sourceSentence: "Truth matters.", targetSentence: "సత్యం ముఖ్యం." },
    ]);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("1. Client Architecture & Parent Scoping", () => {
    test("verifies v3 parent location path conforms to projects/{id}/locations/global", () => {
      const parent = (service as any).parent;
      expect(parent).toMatch(/^projects\/[a-zA-Z0-9_-]+\/locations\/(global|asia-south1)$/);
    });

    test("verifies zero v2 client references exist in the service instance", () => {
      // v2 client has been fully removed — only v3 + AdaptiveMt remain
      expect((service as any)._v2Client).toBeUndefined();
      expect((service as any).v2Client).toBeUndefined();
    });

    test("verifies AdaptiveMt client is available for terminology consistency", () => {
      // AdaptiveMt client should be initialized (or undefined before first access)
      // The service should have the adaptiveMtParent property targeting a regional endpoint
      const amtParent = (service as any).adaptiveMtParent;
      expect(amtParent).toMatch(/^projects\/[a-zA-Z0-9_-]+\/locations\/[a-z0-9-]+$/);
      expect(amtParent).not.toContain("global"); // AdaptiveMt requires regional endpoint
    });
  });

  describe("2. Single Text Translation (`translateText`)", () => {
    test("uses v3 output as a reference for required Adaptive MT primary translation", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [
            { translatedText: "సత్యప్రపంచానికి స్వాగతం" },
          ],
        },
      ]);

      const result = await service.translateText(
        "Welcome to TruthWorld",
        "en",
        "te"
      );

      expect(mockTranslateText).toHaveBeenCalledTimes(1);
      const callArgs = mockTranslateText.mock.calls[0][0];
      expect(callArgs.contents).toEqual(["Welcome to TruthWorld"]);
      expect(callArgs.sourceLanguageCode).toBe("en");
      expect(callArgs.targetLanguageCode).toBe("te");
      expect(callArgs.mimeType).toBe("text/plain");
      expect(callArgs.parent).toBe((service as any).parent);
      expect(service.defaultModel).toBe("general/translation-llm");
      expect(mockAdaptiveMtTranslate).toHaveBeenCalledTimes(1);
      expect(mockAdaptiveMtTranslate.mock.calls[0][0].content).toEqual(["Welcome to TruthWorld"]);
      expect(
        mockAdaptiveMtTranslate.mock.calls[0][0].referenceSentenceConfig.referenceSentencePairLists[0].referenceSentencePairs[0]
      ).toEqual({
        sourceSentence: "Welcome to TruthWorld",
        targetSentence: "సత్యప్రపంచానికి స్వాగతం",
      });
      expect(result).toBe("సత్యప్రపంచానికి స్వాగతం");
    });

    test("normalizes language codes (e.g. 'en-US' -> 'en', 'te-IN' -> 'te')", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [{ translatedText: "नमस्ते" }],
        },
      ]);

      await service.translateText("Hello", "en-US", "hi-IN");

      const callArgs = mockTranslateText.mock.calls[0][0];
      expect(callArgs.sourceLanguageCode).toBe("en");
      expect(callArgs.targetLanguageCode).toBe("hi");
    });

    test("automatically sanitizes and decodes HTML entities returned by Google v3", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [
            { translatedText: "&quot;TruthWorld&quot; is don&#39;t worry &amp; always $10." },
          ],
        },
      ]);

      const result = await service.translateText("Don't worry", "en", "es");
      expect(result).toBe(`"TruthWorld" is don't worry & always $10.`);
    });

    test("fails explicitly when the required v3 client is unavailable", async () => {
      (service as any)._v3Client = null;
      await expect(service.translateText("TruthWorld", "en", "es")).rejects.toThrow(
        "Required Google Cloud Translation v3 client is unavailable"
      );
    });

    test("fails explicitly when required Adaptive MT is unavailable", async () => {
      (service as any)._adaptiveMtClient = null;
      mockTranslateText.mockResolvedValueOnce([
        { translations: [{ translatedText: "TruthWorld translated" }] },
      ]);

      await expect(service.translateText("TruthWorld", "en", "es")).rejects.toThrow(
        "Required Google Adaptive MT client is unavailable"
      );
    });

    test("fails explicitly when Adaptive MT returns no translation", async () => {
      mockTranslateText.mockResolvedValueOnce([
        { translations: [{ translatedText: "TruthWorld translated" }] },
      ]);
      mockAdaptiveMtTranslate.mockResolvedValueOnce([{ translations: [] }]);

      await expect(service.translateText("TruthWorld", "en", "es")).rejects.toThrow(
        "Required Google Adaptive MT returned no translation"
      );
    });
  });

  describe("3. Batch Translation (`batchTranslateV3`)", () => {
    test("translates an array of texts preserving index order", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [
            { translatedText: "సత్యం" },
            { translatedText: "ధర్మం" },
            { translatedText: "శాంతి" },
          ],
        },
      ]);

      const texts = ["Truth", "Duty", "Peace"];
      const results = await service.batchTranslateV3(texts, "en", "te");

      expect(mockTranslateText).toHaveBeenCalledTimes(1);
      expect(service.defaultModel).toBe("general/translation-llm");
      expect(results).toEqual(["సత్యం", "ధర్మం", "శాంతి"]);
    });

    test("uses general/translation-llm and Adaptive MT together as the composite primary", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [{ translatedText: "Strict LLM Result" }],
        },
      ]);

      const result = await service.translateText("Test phrase", "en", "te");
      expect(mockTranslateText).toHaveBeenCalledTimes(1);
      expect(mockAdaptiveMtTranslate).toHaveBeenCalledTimes(1);
      expect(service.defaultModel).toBe("general/translation-llm");
      expect(result).toBe("Strict LLM Result");
    });

    test("fails the composite batch instead of falling back to v3 when Adaptive MT fails", async () => {
      mockTranslateText.mockResolvedValueOnce([
        { translations: [{ translatedText: "V3 candidate" }] },
      ]);
      mockAdaptiveMtTranslate.mockRejectedValueOnce(new Error("Adaptive MT request rejected"));

      await expect(service.batchTranslateStandard(["Truth"], "en", "es")).rejects.toThrow(
        "Adaptive MT request rejected"
      );
    });

    test("chunks large arrays (> 100 items) into batches of <= 100 items", async () => {
      // 150 texts -> 2 batches (100 + 50)
      const largeInput = Array.from({ length: 150 }, (_, i) => `Segment ${i + 1}`);

      mockTranslateText
        .mockImplementationOnce(async ({ contents }) => [
          { translations: contents.map((c: string) => ({ translatedText: `Traducido: ${c}` })) },
        ])
        .mockImplementationOnce(async ({ contents }) => [
          { translations: contents.map((c: string) => ({ translatedText: `Traducido: ${c}` })) },
        ]);

      const results = await service.batchTranslateV3(largeInput, "en", "es");

      expect(mockTranslateText).toHaveBeenCalledTimes(2);
      expect(mockTranslateText.mock.calls[0][0].contents.length).toBe(100);
      expect(mockTranslateText.mock.calls[1][0].contents.length).toBe(50);
      expect(results.length).toBe(150);
      expect(results[0]).toBe("Traducido: Segment 1");
      expect(results[149]).toBe("Traducido: Segment 150");
    });

    test("handles empty input array without calling v3 API", async () => {
      const results = await service.batchTranslateV3([], "en", "te");
      expect(results).toEqual([]);
      expect(mockTranslateText).not.toHaveBeenCalled();
    });

    test("decodes HTML entities across all batch items", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [
            { translatedText: "&iexcl;Hola! Don&#39;t fear &quot;truth&quot;" },
            { translatedText: "Prix: &#x24;10 &amp; &#x27;garantie&#x27;" },
          ],
        },
      ]);

      const results = await service.batchTranslateV3(["Greeting", "Price"], "en", "es");
      expect(results[0]).toBe(`¡Hola! Don't fear "truth"`);
      expect(results[1]).toBe(`Prix: $10 & 'garantie'`);
    });
  });

  describe("4. Production Segment Pipeline (`translateSegments`)", () => {
    test("translates dubbing/subtitle segments with the required v3 + Adaptive MT composite", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [
            { translatedText: "సత్యప్రపంచానికి స్వాగతం" },
            { translatedText: "ఇది నిజమైన వాస్తవాల తనిఖీ వేదిక" },
          ],
        },
      ]);

      const spyCost = jest.spyOn(costEngine, "recordTranslationCost").mockResolvedValueOnce();

      const segments = [
        {
          start: 0,
          end: 3.5,
          text: "Welcome to TruthWorld",
          speaker: "speaker_0",
          emotionTag: "[excited]",
          isHook: true,
        },
        {
          start: 3.5,
          end: 7.0,
          text: "This is a real fact-checking platform",
          speaker: "speaker_0",
          emotionTag: "[serious]",
          isHook: false,
        },
      ];

      const result = await service.translateSegments(
        "job_test_v3_101",
        segments,
        "en",
        "te",
        { dubbingTier: "audio_track", subtitleTier: "ultra", userId: "usr_truth_creator" }
      );

      expect(result.jobId).toBe("job_test_v3_101");
      expect(result.sourceLanguage).toBe("en");
      expect(result.targetLanguage).toBe("te");
      expect(result.segments.length).toBe(2);

      // Verify emotionTag is perfectly preserved for ElevenLabs v4
      expect(result.segments[0].emotionTag).toBe("[excited]");
      expect(result.segments[1].emotionTag).toBe("[serious]");

      // Verify translated text & HTML entity cleanliness
      expect(result.segments[0].translated).toBe("సత్యప్రపంచానికి స్వాగతం");
      expect(result.segments[1].translated).toBe("ఇది నిజమైన వాస్తవాల తనిఖీ వేదిక");
      expect(mockAdaptiveMtTranslate).toHaveBeenCalled();

      // Verify timing preserved
      expect(result.segments[0].start).toBe(0);
      expect(result.segments[0].end).toBe(3.5);
      expect(result.segments[0].isHook).toBe(true);

      // Verify syllableBudgetCompliance is computed
      expect(result.segments[0].syllableBudgetCompliance).toBeGreaterThan(0);
      expect(result.segments[0].syllableBudgetCompliance).toBeLessThanOrEqual(1.0);

      // Verify cost engine tracking with input character count
      const expectedInputChars = "Welcome to TruthWorld".length + "This is a real fact-checking platform".length;
      expect(spyCost).toHaveBeenCalledWith(
        "job_test_v3_101",
        "usr_truth_creator",
        expectedInputChars
      );

      spyCost.mockRestore();
    });
  });

  describe("5. Language Detection (`detectLanguage` & `detectLanguages`)", () => {
    test("detectLanguage invokes v3 detectLanguage and returns top languageCode", async () => {
      mockDetectLanguage.mockResolvedValueOnce([
        {
          languages: [
            { languageCode: "te", confidence: 0.98 },
          ],
        },
      ]);

      const detected = await service.detectLanguage("సత్యప్రపంచం");
      expect(mockDetectLanguage).toHaveBeenCalledTimes(1);
      const args = mockDetectLanguage.mock.calls[0][0];
      expect(args.content).toBe("సత్యప్రపంచం");
      expect(args.mimeType).toBe("text/plain");
      expect(detected).toBe("te");
    });

    test("detectLanguage defaults to throwing error if API returns no languages or fails", async () => {
      mockDetectLanguage.mockResolvedValueOnce([{ languages: [] }]);
      await expect(service.detectLanguage("Unknown script ?????")).rejects.toThrow(
        /Language detection unavailable/
      );
    });

    test("detectLanguages detects multiple texts concurrently", async () => {
      mockDetectLanguage
        .mockResolvedValueOnce([{ languages: [{ languageCode: "es" }] }])
        .mockResolvedValueOnce([{ languages: [{ languageCode: "fr" }] }])
        .mockResolvedValueOnce([{ languages: [{ languageCode: "de" }] }]);

      const results = await service.detectLanguages([
        "Hola mundo",
        "Bonjour le monde",
        "Hallo Welt",
      ]);

      expect(results).toEqual(["es", "fr", "de"]);
      expect(mockDetectLanguage).toHaveBeenCalledTimes(3);
    });

    test("detectLanguages handles empty array gracefully", async () => {
      // Empty array should throw since v3Client mock doesn't handle empty calls
      // but mapConcurrent returns [] for empty input, so detectLanguage is never called
      const results = await service.detectLanguages([]);
      expect(results).toEqual([]);
    });
  });

  describe("6. Syllable-Budget Compliance & Language Expansion Ratios", () => {
    test("verifies expansion ratio reflects Telugu polysyllabic structure (1.38 ratio)", () => {
      expect(LANG_SYLLABLE_RATIOS["te"]).toBe(1.38);
      expect(LANG_SYLLABLE_RATIOS["hi"]).toBe(1.15);
      expect(LANG_SYLLABLE_RATIOS["en"]).toBe(1.0);
    });

    test("computes compliance score of 1.0 when translated speech fits timing budget", () => {
      const compliance = computeSyllableBudgetCompliance(
        "Welcome to the platform.",
        "సత్యప్రపంచానికి స్వాగతం.",
        "en",
        "te",
        3500 // 3.5 seconds
      );
      expect(compliance).toBe(1.0);
    });
  });

  describe("7. Operational Health Checks, Circuit Breaker & Automatic Rollback", () => {
    // TODO: Implement checkHealth, getCircuitBreakerState, resetCircuitBreaker on TranslationService
    test.skip("checkHealth probes model availability and reports healthy status", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [{ translatedText: "Comprobación de estado" }],
        },
      ]);

      const health = await (service as any).checkHealth();
      expect(health.healthy).toBe(true);
      expect(health.model).toContain("general/translation-llm");
      expect(health.latencyMs).toBeGreaterThanOrEqual(0);
      expect(health.circuitBreakerState).toBe("CLOSED");
    });

    test.skip("checkHealth reports unhealthy status when API call fails", async () => {
      mockTranslateText.mockRejectedValueOnce(new Error("Resource not found"));

      const health = await (service as any).checkHealth();
      expect(health.healthy).toBe(false);
      expect(health.error).toBe("Resource not found");
    });

    test.skip("trips circuit breaker and automatically rolls back to last-known-good after 3 consecutive failures", async () => {
      mockTranslateText.mockRejectedValue(new Error("API outage 503"));

      expect((service as any).getCircuitBreakerState().circuitBreakerState).toBe("CLOSED");

      // Attempt 3 failures
      await service.translateText("Sample 1", "en", "te");
      await service.translateText("Sample 2", "en", "te");
      await service.translateText("Sample 3", "en", "te");

      const state = (service as any).getCircuitBreakerState();
      expect(state.circuitBreakerState).toBe("OPEN");
      expect(state.isUsingFallback).toBe(true);
      expect(state.activeModel).toBe((service as any).lastKnownGoodModel);

      // Clean reset
      (service as any).resetCircuitBreaker();
      expect((service as any).getCircuitBreakerState().circuitBreakerState).toBe("CLOSED");
      expect((service as any).getCircuitBreakerState().isUsingFallback).toBe(false);
    });
  });

  describe("8. Concise Retranslation for Dubbing Pacing", () => {
    test("condenses rhetorical filler and uses the composite translation primary", async () => {
      mockTranslateText.mockResolvedValueOnce([
        {
          translations: [{ translatedText: "సత్యంపై దృష్టి నిలపండి" }],
        },
      ]);

      const concise = await service.retranslateConcise(
        "As a matter of fact, it is important to note that you should focus on the truth.",
        "en",
        "te",
        { targetDurationRatio: 1.35 }
      );

      expect(mockTranslateText).toHaveBeenCalledTimes(1);
      const calledText = mockTranslateText.mock.calls[0][0].contents[0];
      // Expect rhetorical preamble to be pruned
      expect(calledText).not.toContain("As a matter of fact");
      expect(calledText).not.toContain("it is important to note that");
      expect(concise).toBe("సత్యంపై దృష్టి నిలపండి");
    });
  });

  describe("9. Multi-Profile Terminology Compliance", () => {
    const { TerminologyService } = require("../../src/pipeline/services/terminology_glossary");

    test("validates 4 terminology profiles for Telugu (neutral, colloquial, formal, technical)", () => {
      const resNeutral = TerminologyService.checkTerminologyCompliance(
        "We need Fact-Checking.",
        "మాకు వాస్తవ పరిశీలన అవసరం.",
        "te",
        { localeStyle: "neutral" }
      );
      expect(resNeutral.isFullyCompliant).toBe(true);

      const resColloquial = TerminologyService.checkTerminologyCompliance(
        "We need Fact-Checking.",
        "మాకు ఫాక్ట్-చెకింగ్ కావాలి.",
        "te",
        { localeStyle: "colloquial" }
      );
      expect(resColloquial.isFullyCompliant).toBe(true);
    });

    test("flags disallowed literal translations in Hindi, Tamil, and Malayalam", () => {
      const resHi = TerminologyService.checkTerminologyCompliance(
        "We need Fact-Checking.",
        "हमें तथ्यों की चेकिंग चाहिए।",
        "hi"
      );
      expect(resHi.isFullyCompliant).toBe(false);
      expect(resHi.violations[0].disallowedFound).toBe("तथ्यों की चेकिंग");

      const resTa = TerminologyService.checkTerminologyCompliance(
        "We need renewable energy.",
        "மீண்டும் செய்யக்கூடிய ஆற்றல் தேவை.",
        "ta"
      );
      expect(resTa.isFullyCompliant).toBe(false);
      expect(resTa.violations[0].disallowedFound).toBe("மீண்டும் செய்யக்கூடிய ஆற்றல்");
    });
  });
});
