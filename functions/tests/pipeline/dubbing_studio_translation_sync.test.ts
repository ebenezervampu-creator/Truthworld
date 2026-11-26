import { computeSyllableBudgetCompliance } from "../../src/pipeline/services/translation";
import { syllableBudgetForDuration } from "../../src/pipeline/services/speech-rate";
import { SubtitleGuardrails } from "../../src/pipeline/services/subtitleGuardrails";
import { conformCues } from "../../src/pipeline/services/netflixSubtitleConformer";
import { getSubtitleProfile } from "../../src/pipeline/services/subtitle_language_profiles";

describe("Dubbing Studio Translation, Subtitles & Timeline Sync", () => {
  test("computeSyllableBudgetCompliance aligns with unified speech-rate syllableBudgetForDuration", () => {
    const durationMs = 2000;
    const budget = syllableBudgetForDuration(durationMs, "en");
    expect(budget).toBeGreaterThanOrEqual(8);

    const shortLine = "Hello world today";
    expect(computeSyllableBudgetCompliance("Hello world today", shortLine, "en", "en", durationMs)).toBe(1.0);

    const veryLongLine =
      "This is an extraordinarily verbose sentence that clearly exceeds a two second spoken window by many syllables";
    const score = computeSyllableBudgetCompliance("Short line", veryLongLine, "en", "en", durationMs);
    expect(score).toBeLessThan(1.0);
    expect(score).toBeGreaterThanOrEqual(0.1);
  });

  test("short sub-1000ms segments are not treated as seconds", () => {
    // 600ms window should have a tight budget, not a 600-second budget
    const score = computeSyllableBudgetCompliance(
      "Yes",
      "This sentence is way too long for six hundred milliseconds",
      "en",
      "en",
      600
    );
    expect(score).toBeLessThan(0.5);
  });

  test("Dubbing Studio subtitle sync sanitization and Netflix conformance enforce min duration, 2-frame gap, and line wrapping", () => {
    const profile = getSubtitleProfile("te");
    const longSanitized = SubtitleGuardrails.sanitize(
      "ఇది చాలా పెద్ద వాక్యం మరియు దీనిని రెండు లైన్లలో సరిగ్గా విభజించి చూపించాలి లేకపోతే చదవడం కష్టం అవుతుంది",
      { targetLanguage: "te", sourceLanguage: "en" }
    );

    const { cues } = conformCues(
      [
        {
          id: 1,
          startMs: 1000,
          endMs: 1300, // too short (300ms) -> conformer extends to >= minDurationMs
          text: "సరే",
          sourceWordStartIndex: 0,
          sourceWordEndIndex: 0,
          alignmentConfidence: 1,
          languageCode: "te",
          charactersPerSecond: 10,
          charactersPerLine: 3,
          durationMs: 300,
          validationStatus: "pass",
        },
        {
          id: 2,
          startMs: 2500,
          endMs: 6500,
          text: longSanitized,
          sourceWordStartIndex: 1,
          sourceWordEndIndex: 1,
          alignmentConfidence: 1,
          languageCode: "te",
          charactersPerSecond: 15,
          charactersPerLine: longSanitized.length,
          durationMs: 4000,
          validationStatus: "pass",
        },
      ],
      { profile, fps: 30 }
    );

    expect(cues.length).toBeGreaterThanOrEqual(2);
    expect(cues[0].endMs - cues[0].startMs).toBeGreaterThanOrEqual(profile.minimumCueDurationMs);
    expect(cues[1].startMs - cues[0].endMs).toBeGreaterThanOrEqual(66);
    for (const cue of cues) {
      expect(cue.text.split("\n").length).toBeLessThanOrEqual(2);
    }
  });
});
