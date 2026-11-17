/**
 * 🧪 TEST: TruthWorld Expressive v4 Bus Pipeline Layer
 *
 * Verifies that:
 * 1. Sarcastic/energetic debate speech dynamically lowers stability and raises style exaggeration.
 * 2. Calm/liturgical/formal speech produces elevated stability and subtle style.
 * 3. Quiet/whispered dialogue (< -38 dBFS) injects [whispers] and sets breathy stability.
 * 4. High-energy explosive speech (> -15 dBFS with anger) injects [shouts] and elevates style.
 * 5. Creator overrides (stabilityOverride, styleOverride, similarityBoostOverride) are strictly preserved.
 * 6. Inline audio tags are sanitized and bracketed developer tokens are stripped.
 */

import { expressiveV4Bus } from "../../src/pipeline/services/expressiveV4Bus";

describe("TruthWorld Expressive v4 Bus Pipeline Integration", () => {
  test("1. Sarcastic / energetic debate speech dynamically lowers stability and raises style", () => {
    const payload = expressiveV4Bus.processSegment({
      jobId: "job_debate_1",
      language: "te",
      translatedText: "అల్లాహ్ ఎక్కడ చెప్పారో నాకు చూపించండి!",
      sourceText: "Show me where Allah says that!",
      telemetry: {
        energyDb: -16,
        pitchRangeSemitones: 15,
        deliveryStyle: "sarcastic argumentative",
        emotionalIntensity: {
          anger: 0.55,
          joy: 0.3,
          surprise: 0.6,
        },
      },
    });

    // Lower stability allows pitch volatility, sarcasm, and vocal strain
    expect(payload.voiceSettings.stability).toBeLessThanOrEqual(0.35);
    expect(payload.voiceSettings.stability).toBeGreaterThanOrEqual(0.20);

    // Style exaggeration pushes dynamic acting emphasis
    expect(payload.voiceSettings.style).toBeGreaterThanOrEqual(0.45);
    expect(payload.voiceSettings.style).toBeLessThanOrEqual(0.65);

    // Voice identity boost provides headroom
    expect(payload.voiceSettings.similarity_boost).toBeLessThanOrEqual(0.80);
    expect(payload.text).toContain("అల్లాహ్ ఎక్కడ చెప్పారో");
  });

  test("2. Calm / liturgical / formal speech produces elevated stability and low style", () => {
    const payload = expressiveV4Bus.processSegment({
      jobId: "job_calm_1",
      language: "te",
      translatedText: "4వ అధ్యాయం, 157వ వచనంలో ఇలా వ్రాయబడింది.",
      sourceText: "In chapter 4, verse 157, it is written as follows.",
      telemetry: {
        energyDb: -28,
        pitchRangeSemitones: 3.2,
        deliveryStyle: "matter-of-fact formal",
        emotionalIntensity: {
          anger: 0.05,
          joy: 0.1,
          surprise: 0.05,
        },
      },
    });

    // High stability keeps reading dignified and steady
    expect(payload.voiceSettings.stability).toBeGreaterThanOrEqual(0.70);
    // Low style prevents theatrical exaggeration
    expect(payload.voiceSettings.style).toBeLessThanOrEqual(0.15);
  });

  test("3. Quiet / whispered speech automatically injects [whispers] and sets breathy stability", () => {
    const payload = expressiveV4Bus.processSegment({
      jobId: "job_whisper_1",
      language: "te",
      translatedText: "ఇది ఎవరికీ చెప్పవద్దు.",
      sourceText: "Don't tell this to anyone.",
      telemetry: {
        energyDb: -42,
        voiceQuality: "breathy",
      },
    });

    expect(payload.emotionTag).toBe("whispers");
    expect(payload.text.startsWith("[whispers]")).toBe(true);
    expect(payload.voiceSettings.stability).toBeLessThanOrEqual(0.40);
  });

  test("4. High-energy explosive speech (> -15 dBFS with anger) injects [shouts] and elevates style", () => {
    const payload = expressiveV4Bus.processSegment({
      jobId: "job_shout_1",
      language: "te",
      translatedText: "ఆపండి! అది పూర్తిగా అబద్ధం!",
      sourceText: "Stop! That is completely false!",
      telemetry: {
        energyDb: -12.5,
        emotionalIntensity: {
          anger: 0.75,
        },
      },
    });

    expect(payload.emotionTag).toBe("shouts");
    expect(payload.text.startsWith("[shouts]")).toBe(true);
    expect(payload.voiceSettings.style).toBeGreaterThanOrEqual(0.45);
    expect(payload.voiceSettings.stability).toBeLessThanOrEqual(0.35);
  });

  test("5. Explicit creator overrides (stabilityOverride, styleOverride) are strictly respected", () => {
    const payload = expressiveV4Bus.processSegment({
      jobId: "job_override_1",
      language: "te",
      translatedText: "నా స్వంత ప్రాధాన్యత ప్రకారం చదవండి.",
      telemetry: {
        stabilityOverride: 0.82,
        styleOverride: 0.05,
        similarityBoostOverride: 0.91,
      },
    });

    expect(payload.voiceSettings.stability).toBe(0.82);
    expect(payload.voiceSettings.style).toBe(0.05);
    expect(payload.voiceSettings.similarity_boost).toBe(0.91);
  });

  test("6. Non-v4 bracketed noise annotations are stripped and never duplicated", () => {
    const payload = expressiveV4Bus.processSegment({
      jobId: "job_tags_1",
      language: "te",
      translatedText: "[music] [applause] [laughs] నిజంగానా? [laughs]",
      telemetry: {
        emotionTag: "laughs",
      },
    });

    expect(payload.text).not.toContain("[music]");
    expect(payload.text).not.toContain("[applause]");
    // Does not produce duplicate consecutive [laughs] [laughs]
    expect(payload.text).not.toContain("[laughs] [laughs]");
    expect(payload.text).toContain("[laughs] నిజంగానా?");
  });
});
