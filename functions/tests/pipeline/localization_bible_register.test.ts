process.env.DUBBING_MEANING_CHECK = "false";
import { GeminiDubbingEditor, type EditorSegment } from "../../src/pipeline/services/geminiDubbingEditor";
import { countSourceSyllables } from "../../src/pipeline/services/translation";

// 25 Nov run …4954895 (animated Joseph clip): the bible's rule "Religious content: ALWAYS formal"
// locked every pair to formal, so the demon taunting Joseph used polite forms, which were longer
// than the lines' time windows and were cut off mid-word.
describe("localization bible: register rules", () => {
  const lines: EditorSegment[] = [
    { id: "L1", speaker: "B_4", addressedTo: "B", source: "God didn't protect you.", draft: "", delivery: "shouting" },
    { id: "L2", speaker: "B_4", addressedTo: "B", source: "Do not serve him anymore.", draft: "" },
    { id: "L3", speaker: "B_2", addressedTo: "B", source: "Don't worry, Joseph.", draft: "" },
  ];

  async function capture(segments: EditorSegment[]) {
    const calls: Array<{ system: string; prompt: string }> = [];
    const editor = new GeminiDubbingEditor(async (req: any) => {
      calls.push({ system: req.system, prompt: req.prompt });
      return { text: JSON.stringify({ locked_registers: [{ from_speaker: "B_4", to_speaker: "B", formality: "informal" }] }), inputTokens: 0, outputTokens: 0 };
    });
    const bible = await editor.generateLocalizationBible(segments, {
      jobId: "j", sourceLanguage: "en", targetLanguage: "te", countSyllables: countSourceSyllables, inferBible: true,
    } as any);
    return { calls, bible };
  }

  it("no longer forces formal on every religious video; story characters are judged by the scene", async () => {
    const { calls } = await capture(lines);
    const system = calls[0].system;
    expect(system).not.toMatch(/ALWAYS 'formal'/);
    expect(system).toMatch(/Characters inside a story \(including religious and historical stories\)/);
    expect(system).toMatch(/never by the genre/);
    expect(system).toMatch(/Hostility, mockery, threats or contempt.*'informal'/);
    // A congregation or audience is still addressed formally.
    expect(system).toMatch(/congregation or AUDIENCE: 'formal' or 'deferential'/);
  });

  it("the rules stay language-neutral (no Telugu or Hindi script in the shared prompt)", async () => {
    const { calls } = await capture(lines);
    expect(calls[0].system).not.toMatch(/[ఀ-౿ऀ-ॿ]/);
  });

  it("sends each sampled line's delivery, so hostility is visible to Gemini", async () => {
    const { calls } = await capture(lines);
    const payload = JSON.parse(calls[0].prompt);
    expect(payload.lines[0].delivery).toBe("shouting");
    expect(payload.lines[1].delivery).toBeUndefined();
  });

  it("the informal lock Gemini returns is used", async () => {
    const { bible } = await capture(lines);
    expect(bible.lockedRegisters["B_4->B"]).toBe("informal");
  });
});
