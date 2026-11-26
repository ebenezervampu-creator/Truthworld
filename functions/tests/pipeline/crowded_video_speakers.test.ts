/**
 * Crowded videos (10 / 20 / 30 speakers): AssemblyAI cap, voice reuse, profiling concurrency,
 * windowed diarization check.
 */
jest.mock("../../src/pipeline/utils/logger", () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() } }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexAI: jest.fn(), getVertexClient: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-utils", () => ({
  extractCandidateText: jest.fn(),
  normalizeToGcsUri: (u: string) => (u.startsWith("gs://") ? u : null),
}), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: { GEMINI_MODEL: "test-model" } }), { virtual: true });

import { assemblySpeakerOptions, capForDuration } from "../../src/pipeline/services/assembly-speaker-options";
import { minGapMs, rankReusableVoices } from "../../src/pipeline/services/voice-reuse";
import { mapWithConcurrency, withRetry } from "../../src/pipeline/services/concurrency";
import { DiarizationCheckService, WINDOW_TURNS } from "../../src/pipeline/services/diarization-check";

describe("assemblySpeakerOptions", () => {
  test("dubbing without a count raises only the cap, by length", () => {
    expect(assemblySpeakerOptions(60, undefined, true)).toEqual({ max_speakers_expected: 12 });
    expect(assemblySpeakerOptions(300, undefined, true)).toEqual({ max_speakers_expected: 20 });
    expect(assemblySpeakerOptions(1800, undefined, true)).toEqual({ max_speakers_expected: 30 });
    expect(capForDuration(undefined)).toBe(12);
  });

  test("never guesses a floor, so a one-person video can stay one voice", () => {
    for (const d of [30, 300, 3600]) {
      expect(assemblySpeakerOptions(d, undefined, true)?.min_speakers_expected).toBeUndefined();
    }
  });

  test("creator's count wins, with +2 headroom, capped at 30", () => {
    expect(assemblySpeakerOptions(300, { min: 20 }, true)).toEqual({ min_speakers_expected: 20, max_speakers_expected: 22 });
    expect(assemblySpeakerOptions(300, { min: 3, max: 5 }, true)).toEqual({ min_speakers_expected: 3, max_speakers_expected: 5 });
    expect(assemblySpeakerOptions(300, { min: 30 }, true)).toEqual({ min_speakers_expected: 30, max_speakers_expected: 30 });
    expect(assemblySpeakerOptions(300, { min: 5, max: 2 }, true)).toEqual({ min_speakers_expected: 5, max_speakers_expected: 5 });
  });

  test("subtitle-only jobs without a count keep AssemblyAI defaults", () => {
    expect(assemblySpeakerOptions(300, undefined, false)).toBeUndefined();
  });
});

describe("voice reuse", () => {
  // Three scenes: 0–60 s (A, B), 300–360 s (C, D), 900–960 s (E — needs a reused voice)
  const s = (speaker: string, startSec: number, endSec: number) => ({ speaker, start: startSec * 1000, end: endSec * 1000 });
  const turns = [s("A", 0, 10), s("B", 10, 20), s("A", 40, 50), s("C", 300, 310), s("D", 310, 320), s("E", 900, 910), s("E", 950, 955)];

  test("minGapMs measures the closest approach of two speakers", () => {
    expect(minGapMs([s("x", 0, 10)], [s("y", 15, 20)])).toBe(5000);
    expect(minGapMs([s("x", 0, 10)], [s("y", 5, 20)])).toBe(0);
  });

  test("reuses the voice whose owner speaks furthest from the new speaker", () => {
    const owners = new Map([["vA", ["A"]], ["vB", ["B"]], ["vC", ["C"]], ["vD", ["D"]]]);
    const ranked = rankReusableVoices("E", turns, owners, ["vA", "vB", "vC", "vD"]);
    // Gaps to E (starts 900 s): B ends 20 s → 880 s, A 50 s → 850 s, C 310 s → 590 s, D 320 s → 580 s.
    expect(ranked.map((r) => r.voiceId)).toEqual(["vB", "vA", "vC", "vD"]);
    expect(ranked[0].minGapMs).toBe(880000);
  });

  test("never offers a voice whose owner speaks at the same time", () => {
    const overlapping = [...turns, s("F", 905, 912)];
    const owners = new Map([["vE", ["E"]], ["vA", ["A"]]]);
    const ranked = rankReusableVoices("F", overlapping, owners, ["vE", "vA"]);
    expect(ranked[0].voiceId).toBe("vA");
    expect(ranked.find((r) => r.voiceId === "vE")!.minGapMs).toBe(0);
  });
});

describe("concurrency helpers", () => {
  test("mapWithConcurrency never runs more than the limit and keeps order", async () => {
    let inFlight = 0;
    let peak = 0;
    const out = await mapWithConcurrency(Array.from({ length: 30 }, (_, i) => i), 5, async (n) => {
      inFlight++;
      peak = Math.max(peak, inFlight);
      await new Promise((r) => setTimeout(r, 2));
      inFlight--;
      return n * 2;
    });
    expect(peak).toBeLessThanOrEqual(5);
    expect(out).toEqual(Array.from({ length: 30 }, (_, i) => i * 2));
  });

  test("withRetry retries once, then gives up", async () => {
    const flaky = jest.fn().mockRejectedValueOnce(new Error("429")).mockResolvedValue("ok");
    await expect(withRetry(flaky, 1, 1)).resolves.toBe("ok");
    const dead = jest.fn().mockRejectedValue(new Error("down"));
    await expect(withRetry(dead, 1, 1)).rejects.toThrow("down");
    expect(dead).toHaveBeenCalledTimes(2);
  });
});

describe("windowed diarization check — simulated 30-speaker video", () => {
  // 30 characters, 6 turns each, interleaved over 180 turns (≈ 3 windows of 80).
  // AssemblyAI (capped) merged them into 10 labels: character k → label L(k % 10).
  const turns = Array.from({ length: 180 }, (_, i) => {
    const character = i % 30;
    return { index: i, start: i * 4000, end: i * 4000 + 3000, speaker: `L${character % 10}`, text: `line ${i}` };
  });
  const characterOf = (i: number) => `C${(i % 30) + 1}`;

  function fakeGemini() {
    return jest.fn().mockImplementation(async ({ prompt }: { prompt: string }) => {
      const ids = [...prompt.matchAll(/^T(\d+) \|/gm)].map((m) => Number(m[1]));
      const chars = [...new Set(ids.map(characterOf))];
      return JSON.stringify({
        characters: chars.map((c) => ({ id: c, description: `person ${c}` })),
        turns: ids.map((i) => ({ id: `T${i}`, character: characterOf(i), confidence: 0.9 })),
      });
    });
  }

  test(`checks in windows of ${WINDOW_TURNS}, passing video offsets and the roster forward`, async () => {
    const generate = fakeGemini();
    await new DiarizationCheckService(generate).check("job", "gs://b/v.mp4", turns);
    expect(generate).toHaveBeenCalledTimes(Math.ceil(180 / WINDOW_TURNS));
    const second = generate.mock.calls[1][0];
    expect(second.startOffsetSec).toBeCloseTo((WINDOW_TURNS * 4000) / 1000 - 2, 5);
    expect(second.prompt).toMatch(/Characters already identified earlier/);
    expect(second.prompt).toContain("C1: person C1");
  });

  test("10 merged labels are split back into 30 distinct labels (one per character)", async () => {
    const r = await new DiarizationCheckService(fakeGemini()).check("job", "gs://b/v.mp4", turns);
    expect(r.applied).toBe(true);
    const labelOfCharacter = new Map<string, Set<string>>();
    for (const t of turns) {
      const c = characterOf(t.index);
      if (!labelOfCharacter.has(c)) labelOfCharacter.set(c, new Set());
      labelOfCharacter.get(c)!.add(r.labels.get(String(t.index))!);
    }
    for (const labels of labelOfCharacter.values()) expect(labels.size).toBe(1); // one voice per character
    expect(new Set(r.labels.values()).size).toBe(30);
  });

  test("a failed window keeps its turns on AssemblyAI labels; the rest are still corrected", async () => {
    const good = fakeGemini();
    const generate = jest.fn().mockImplementation(async (args) => {
      if (generate.mock.calls.length === 3) throw new Error("timeout");
      return good(args);
    });
    const r = await new DiarizationCheckService(generate).check("job", "gs://b/v.mp4", turns);
    expect(r.applied).toBe(true);
    const failedTurn = turns[2 * WINDOW_TURNS + 1];
    expect(r.labels.get(String(failedTurn.index))).toBe(failedTurn.speaker);
  });
});
