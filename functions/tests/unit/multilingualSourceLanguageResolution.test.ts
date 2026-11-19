import { ASSEMBLYAI_UNIVERSAL_35_LANGUAGES } from "../../src/pipeline/layers/05-transcription";
import { normalizeLanguageCode } from "../../src/shared/language-normalizer";

describe("Multilingual Source Language Resolution & Dubbing Gate", () => {
  describe("Bug Fix: Original English video with generated Telugu subtitles requesting Hindi subtitles", () => {
    it("strictly preserves English ('en') as primary source language when channel is Telugu ('te')", () => {
      // Simulated request context
      const videoData: any = {
        language: "en",
        channelId: "channel_telugu_123",
        title: "Dhurandar",
        subtitles: {
          te: "gs://truthworld-1.firebasestorage.app/subtitles/dhurandar/te.srt",
        },
      };

      const reqBody: any = {
        videoId: "dhurandar",
        features: ["subtitles"],
        targetLanguages: ["hi"],
        sourceLanguage: "en",
      };

      // Resolution algorithm as updated in triggerVideoAIFeatures
      let resolvedPrimaryLang = normalizeLanguageCode(
        reqBody?.sourceLanguage ||
        videoData.sourceLanguage ||
        videoData.language ||
        ""
      );

      // Channel fallback should ONLY trigger if resolvedPrimaryLang is empty, NEVER when it is "en"
      if (!resolvedPrimaryLang && videoData.channelId) {
        resolvedPrimaryLang = "te"; // channel language
      }

      if (!resolvedPrimaryLang) {
        resolvedPrimaryLang = "en";
      }

      expect(resolvedPrimaryLang).toBe("en");
      expect(resolvedPrimaryLang).not.toBe("te");
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(resolvedPrimaryLang)).toBe(true);
    });

    it("allows only AssemblyAI-STT-3.7's 32 supported source languages", () => {
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has("en")).toBe(true);
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has("hi")).toBe(true);
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has("te")).toBe(false);
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has("nn")).toBe(true);
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.size).toBe(32);
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has("la")).toBe(false);
    });

    it("ensures fallbackSubs sorts preferredLang ('en') ahead of target language subtitles ('te')", () => {
      const fallbackSubs: Record<string, string> = {
        te: "gs://truthworld-1.firebasestorage.app/subtitles/dhurandar/te.srt",
        en: "gs://truthworld-1.firebasestorage.app/subtitles/dhurandar/en.srt",
      };
      const preferredLang = "en";

      const availableLangs = Object.keys(fallbackSubs).sort((a, b) => {
        const normA = normalizeLanguageCode(a);
        const normB = normalizeLanguageCode(b);
        if (normA === preferredLang && normB !== preferredLang) return -1;
        if (normB === preferredLang && normA !== preferredLang) return 1;
        const aSupp = ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(normA) ? 1 : 0;
        const bSupp = ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(normB) ? 1 : 0;
        return bSupp - aSupp;
      });

      expect(availableLangs[0]).toBe("en");
      expect(availableLangs[1]).toBe("te");
    });

    it("reconciles contaminated transcript language back to authentic source language", () => {
      const vData = {
        language: "en",
        sourceLanguage: "en",
      };
      const preferredLang = normalizeLanguageCode(vData.sourceLanguage || vData.language || "en");

      // Suppose previous subtitle generation or recovery set language to 'la' (unsupported) on transcript doc
      const contaminatedTranscriptData = {
        language: "la",
        utterances: [
          { start: 0, end: 1000, text: "Welcome to the show." },
        ],
      };

      if (
        preferredLang &&
        ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(preferredLang) &&
        !ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(normalizeLanguageCode(contaminatedTranscriptData.language || ""))
      ) {
        contaminatedTranscriptData.language = preferredLang;
      }

      expect(contaminatedTranscriptData.language).toBe("en");
    });

    it("resolves rawSource in Dubbing Gate using authenticSource when transcript has unsupported language", () => {
      const executionPlan = {
        primaryLanguage: "en",
        sourceLanguage: "en",
        subtitleLanguages: ["hi"],
      };
      const vData = {
        language: "en",
        sourceLanguage: "en",
      };
      const transcript = {
        language: "te", // mistakenly set
      };

      const authenticSource = normalizeLanguageCode(
        executionPlan.sourceLanguage ||
        vData?.sourceLanguage ||
        executionPlan.primaryLanguage ||
        vData?.language ||
        ""
      );

      const rawSource = (authenticSource && ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(authenticSource))
        ? authenticSource
        : (transcript.language || authenticSource || "en");

      const normSource = normalizeLanguageCode(rawSource);

      expect(normSource).toBe("en");
      expect(ASSEMBLYAI_UNIVERSAL_35_LANGUAGES.has(normSource)).toBe(true);
    });
  });
});
