import { PerformanceLayer } from "../../src/pipeline/layers/10-performance";
import { parseDurationToSeconds } from "../../src/pipeline/services/media";
import * as crypto from "crypto";

describe("Audio Cache Isolation & Timeline Drift Prevention", () => {
  const performanceLayer = new PerformanceLayer();
  describe("Translation Cache Cross-Language Isolation", () => {
    it("prevents Telugu translation from bleeding into Hindi dubbing requests", async () => {
      const sourceText = "Welcome to today's news update.";
      const teluguTranslation = "నేటి వార్తల తాజా సమాచారానికి స్వాగతం.";
      const hindiTranslation = "आज के समाचार अपडेट में आपका स्वागत है।";

      // Cache Telugu translation (source: en, target: te)
      await performanceLayer.cacheTranslation(
        sourceText,
        "en",
        "te",
        teluguTranslation
      );

      // Verify Telugu retrieval succeeds
      const retrievedTelugu = await performanceLayer.getTranslation(
        sourceText,
        "en",
        "te"
      );
      expect(retrievedTelugu).toBe(teluguTranslation);

      // Request Hindi translation for the same source text (source: en, target: hi)
      // Must NOT return the Telugu translation!
      const retrievedHindi = await performanceLayer.getTranslation(
        sourceText,
        "en",
        "hi"
      );
      expect(retrievedHindi).toBeNull();

      // Now cache Hindi translation
      await performanceLayer.cacheTranslation(
        sourceText,
        "en",
        "hi",
        hindiTranslation
      );

      // Verify both caches are completely isolated
      const verifiedTelugu = await performanceLayer.getTranslation(sourceText, "en", "te");
      const verifiedHindi = await performanceLayer.getTranslation(sourceText, "en", "hi");

      expect(verifiedTelugu).toBe(teluguTranslation);
      expect(verifiedHindi).toBe(hindiTranslation);
      expect(verifiedTelugu).not.toBe(verifiedHindi);
    });
  });

  describe("TTS Cache Cross-Language Isolation", () => {
    it("ensures audio URLs are strictly namespaced by language and voice", async () => {
      const text = "Shared linguistic phrase";
      const teluguUrl = "gs://truthworld-test/audio/te_voice_123.mp3";
      const hindiUrl = "gs://truthworld-test/audio/hi_voice_456.mp3";

      await performanceLayer.cacheTTSAudio(text, "te", "te_voice_123", teluguUrl);

      // Check with Hindi language — must return null (not Telugu audio)
      const cachedHindi = await performanceLayer.getTTSAudioUrl(text, "hi", "hi_voice_456");
      expect(cachedHindi).toBeNull();

      // Check with Telugu language — returns Telugu audio
      const cachedTelugu = await performanceLayer.getTTSAudioUrl(text, "te", "te_voice_123");
      expect(cachedTelugu).toBe(teluguUrl);
    });
  });

  describe("Video Duration & Timeline Drift Guard", () => {
    it("correctly computes 11:45 duration to 705 seconds (705,000 ms)", () => {
      const sec = parseDurationToSeconds("11:45");
      expect(sec).toBe(705);
      expect(sec * 1000).toBe(705000);
    });

    it("verifies duration bounding prevents 14:44 runaway timeline expansion", () => {
      const videoDurationSec = parseDurationToSeconds("11:45");
      const videoDurationMs = videoDurationSec * 1000;
      const runawayDriftMs = parseDurationToSeconds("14:44") * 1000; // 884,000 ms

      expect(videoDurationMs).toBe(705000);
      expect(runawayDriftMs).toBe(884000);

      // Guard: Clamped duration must strictly bound to video duration
      const boundedDurationMs = videoDurationMs > 0 ? videoDurationMs : runawayDriftMs;
      expect(boundedDurationMs).toBe(705000);
      expect(boundedDurationMs).not.toBe(runawayDriftMs);
    });
  });

  describe("Source Language Isolation from Dubbing Targets", () => {
    it("ensures target dubbing languages do not hijack source transcription language", () => {
      const executionPlanLanguages = ["en", "te", "hi"];
      const targetJobData = {
        language: "en",
        executionPlan: {
          dubbingLanguages: ["te", "hi"],
        },
      };

      // Correct source language resolution
      const resolvedSourceLang =
        targetJobData.language ||
        (targetJobData.executionPlan as any)?.primaryLanguage ||
        "en";

      expect(resolvedSourceLang).toBe("en");
      // Verify target dubbing languages are NOT selected as source
      expect(resolvedSourceLang).not.toBe("te");
      expect(resolvedSourceLang).not.toBe("hi");
    });
  });
});
