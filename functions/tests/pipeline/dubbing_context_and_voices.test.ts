/**
 * Follow-ups to the Clip 2 regression:
 *  - a line re-edited on its own (concise retranslation) still sees the conversation around it,
 *    so plural "you" (మీరు / మిమ్మల్ని) is not lost;
 *  - the voice matcher has no mistyped preset IDs.
 */
// These tests count and inspect the editor's own Gemini calls; the meaning check (one extra call,
// on by default) has its own tests in tests/pipeline/dubbing_meaning_check.test.ts.
process.env.DUBBING_MEANING_CHECK = "false";

jest.mock("@google/genai", () => ({ Type: { OBJECT: "OBJECT", ARRAY: "ARRAY", STRING: "STRING" } }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexClient: jest.fn(), getVertexAI: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-utils", () => ({ extractCandidateText: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/logger", () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() } }), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: {} }), { virtual: true });
jest.mock("../../src/pipeline/services/media", () => ({ extractMedianPitchHz: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/services/numericalEntityGuard", () => ({
  NumericalEntityGuard: { verifyNumericalParity: () => ({ isValid: true, passed: true, missing: [], mismatches: [] }) },
}), { virtual: true });
jest.mock("../../src/pipeline/services/subtitle_language_profiles", () => ({ getReadableCharCount: (t: string) => t.length }), { virtual: true });

import { GeminiDubbingEditor } from "../../src/pipeline/services/geminiDubbingEditor";
import { ElevenLabsVoiceMatcher } from "../../src/pipeline/services/voice-matcher";

describe("concise re-edit keeps conversation context", () => {
  test("outside context lines reach Gemini as context and are not edited", async () => {
    const prompts: string[] = [];
    const editor = new GeminiDubbingEditor(async ({ prompt }) => {
      prompts.push(prompt);
      return { text: JSON.stringify({ lines: [{ id: "L1", text: "చింతించకండి. మిమ్మల్ని జాగ్రత్తగా చూసుకుంటాం." }] }), inputTokens: 1, outputTokens: 1 };
    });

    const results = await editor.editSegments(
      [{ id: "L1", source: "Don't worry. We'll take good care of you here.", draft: "చింతించకండి. మేము ఇక్కడ మిమ్మల్ని జాగ్రత్తగా చూసుకుంటాం.", speaker: "B", maxSyllables: 40 }],
      {
        jobId: "t",
        sourceLanguage: "en",
        targetLanguage: "te",
        countSyllables: (t) => t.length,
        outsideContext: {
          before: [{ id: "B0", source: "You are to take charge of the baker and the cupbearer.", draft: "", speaker: "A" }],
          after: [{ id: "A0", source: "We had a dream.", draft: "", speaker: "C" }],
        },
      }
    );

    expect(results).toHaveLength(1);
    const payload = JSON.parse(prompts[0]);
    // Context lines carry their id (chained chunk context, see gemini_dubbing_editor.test.ts).
    expect(payload.context_before).toEqual([{ id: "B0", speaker: "A", source: "You are to take charge of the baker and the cupbearer." }]);
    expect(payload.context_after).toEqual([{ speaker: "C", source: "We had a dream." }]);
    expect(payload.lines.map((l: any) => l.id)).toEqual(["L1"]);
  });

  test("the system prompt tells Gemini to resolve plural 'you' from context", async () => {
    let system = "";
    const editor = new GeminiDubbingEditor(async (args) => {
      system = args.system;
      return { text: JSON.stringify({ lines: [{ id: "L1", text: "x" }] }), inputTokens: 1, outputTokens: 1 };
    });
    await editor.editSegments([{ id: "L1", source: "s", draft: "d" }], {
      jobId: "t", sourceLanguage: "en", targetLanguage: "te", countSyllables: (t) => t.length,
    });
    expect(system).toMatch(/conceals both grammatical number and social status/);
    expect(system).toMatch(/మిమ్మల్ని/);
  });
});

describe("voice matcher catalog has no mistyped presets", () => {
  test("the one-character-off Indian presets are gone and Roger is labelled as Roger", () => {
    const m = new ElevenLabsVoiceMatcher();
    expect(m.VERIFIED_PRESET_CALIBRATIONS["z9fAnlkpzviPz146aGWb"]).toBeUndefined();
    expect(m.VERIFIED_PRESET_CALIBRATIONS["EXAVITQu4vr4xnSDxMaK"]).toBeUndefined();
    expect(m.VERIFIED_PRESET_CALIBRATIONS["CwhRBWXzGAHq8TQ4Fs17"]?.name).toBe("Roger");
  });

  test("no two presets differ only in their last character (copy-edit typos)", () => {
    const ids = Object.keys(new ElevenLabsVoiceMatcher().VERIFIED_PRESET_CALIBRATIONS);
    const prefixes = new Map<string, string>();
    const clashes: string[] = [];
    for (const id of ids) {
      const prefix = id.slice(0, -1);
      if (prefixes.has(prefix)) clashes.push(`${prefixes.get(prefix)} / ${id}`);
      prefixes.set(prefix, id);
    }
    expect(clashes).toEqual([]);
  });
});
