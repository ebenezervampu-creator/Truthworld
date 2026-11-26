/**
 * Speed work (quality-neutral): step cache, upload-time preparation policy, and the source-level
 * guarantees that the reordered steps still feed the same inputs to the same services.
 */
import * as fs from "fs";
import * as path from "path";
import {
  cachedStep,
  contentHash,
  decodeCached,
  encodeCached,
  hasFallbackSpeakerProfile,
  isAcousticOnlyProsody,
  isDefaultFingerprint,
  isFailedDiarization,
  stableStringify,
  stepCacheKey,
  stepCachePath,
  StepCacheStore,
} from "../../src/pipeline/services/dubbing-step-cache";
import { prewarmDecision, readPrewarmMode } from "../../src/pipeline/services/dubbing-prewarm-policy";
import { mapWithConcurrency } from "../../src/pipeline/services/concurrency";

function memoryStore(): StepCacheStore & { data: Map<string, string>; reads: number; writes: number } {
  const data = new Map<string, string>();
  const s = {
    data,
    reads: 0,
    writes: 0,
    async read(p: string) { s.reads++; return data.get(p) ?? null; },
    async write(p: string, body: string) { s.writes++; data.set(p, body); },
  };
  return s;
}

describe("step cache", () => {
  const prev = process.env.DUBBING_STEP_CACHE;
  afterEach(() => { if (prev === undefined) delete process.env.DUBBING_STEP_CACHE; else process.env.DUBBING_STEP_CACHE = prev; });

  test("same inputs hash the same regardless of key order; different inputs differ", () => {
    expect(stableStringify({ b: 1, a: [1, { d: 2, c: 3 }] })).toBe(stableStringify({ a: [1, { c: 3, d: 2 }], b: 1 }));
    expect(stepCacheKey("speakers", { a: 1, b: 2 })).toBe(stepCacheKey("speakers", { b: 2, a: 1 }));
    expect(stepCacheKey("speakers", { a: 1 })).not.toBe(stepCacheKey("speakers", { a: 2 }));
    expect(stepCacheKey("speakers", { a: 1 })).not.toBe(stepCacheKey("prosody", { a: 1 }));
    expect(stepCachePath("job1", "prosody", "abc")).toBe("dubbing_prep/job1/prosody_abc.json");
    expect(contentHash([{ x: 1 }])).toHaveLength(16);
  });

  test("Maps survive the round trip (diarization labels, prosody cues)", () => {
    const value = {
      applied: true,
      labels: new Map([["0", "A"], ["1", "B"]]),
      characterLabels: new Map([["joseph", "B"]]),
      cues: new Map([[3, { emotionTag: "[whispers]", emotionalIntensity: { anger: 0.1 } }]]),
    };
    const back = decodeCached<typeof value>(encodeCached(value));
    expect(back.labels).toBeInstanceOf(Map);
    expect(back.labels.get("1")).toBe("B");
    expect(back.characterLabels.get("joseph")).toBe("B");
    expect(back.cues.get(3)).toEqual({ emotionTag: "[whispers]", emotionalIntensity: { anger: 0.1 } });
  });

  test("second run with the same inputs reuses the stored result without computing", async () => {
    const store = memoryStore();
    let calls = 0;
    const compute = async () => { calls++; return { profiles: [{ speakerId: "A", archetype: "mentor" }] }; };
    const first = await cachedStep("job1", "speakers", { u: "h1" }, compute, { store });
    const second = await cachedStep("job1", "speakers", { u: "h1" }, compute, { store });
    expect(first.hit).toBe(false);
    expect(second.hit).toBe(true);
    expect(second.value).toEqual(first.value);
    expect(calls).toBe(1);
    // Changed input (e.g. a cast list added at order time) → computed again.
    const third = await cachedStep("job1", "speakers", { u: "h2" }, compute, { store });
    expect(third.hit).toBe(false);
    expect(calls).toBe(2);
  });

  test("degraded results are not stored, so the next run retries exactly as before", async () => {
    const store = memoryStore();
    let calls = 0;
    const compute = async () => { calls++; return { applied: false, reason: "Gemini call failed" }; };
    await cachedStep("job1", "diarization", { t: 1 }, compute, { store, isDegraded: isFailedDiarization });
    await cachedStep("job1", "diarization", { t: 1 }, compute, { store, isDegraded: isFailedDiarization });
    expect(calls).toBe(2);
    expect(store.writes).toBe(0);
  });

  test("cache storage failures never fail the step", async () => {
    const broken: StepCacheStore = {
      read: async () => { throw new Error("storage down"); },
      write: async () => { throw new Error("storage down"); },
    };
    const r = await cachedStep("job1", "fingerprint", { a: 1 }, async () => ({ micStyle: "x" }), { store: broken });
    expect(r).toEqual({ value: { micStyle: "x" }, hit: false });
  });

  test("DUBBING_STEP_CACHE=false computes every time and touches no storage", async () => {
    process.env.DUBBING_STEP_CACHE = "false";
    const store = memoryStore();
    let calls = 0;
    await cachedStep("job1", "prosody", { a: 1 }, async () => ++calls, { store });
    await cachedStep("job1", "prosody", { a: 1 }, async () => ++calls, { store });
    expect(calls).toBe(2);
    expect(store.reads + store.writes).toBe(0);
  });

  test("degraded detectors match the services' fallback values", () => {
    expect(isDefaultFingerprint({
      micStyle: "warm-broadcast", roomTone: "dry-studio", compression: "transparent", energy: "moderate",
      pacingStyle: "steady-educational", pitchBand: "mid", pitchSemitones: 0.0, speakingRate: 1.0,
    })).toBe(true);
    expect(isDefaultFingerprint({
      micStyle: "lavalier", roomTone: "dry-studio", compression: "transparent", energy: "moderate",
      pacingStyle: "steady-educational", pitchBand: "mid", pitchSemitones: 0.0, speakingRate: 1.0,
    })).toBe(false);

    expect(isFailedDiarization({ reason: "Gemini call failed" })).toBe(true);
    expect(isFailedDiarization({ reason: "video is not in Cloud Storage; Gemini cannot read it" })).toBe(true);
    expect(isFailedDiarization({ reason: "only 3/10 turns identified with confidence >= 0.8" })).toBe(false);

    const heuristic = { speakerId: "A", gender: "male", style: "neutral", pitchBand: "mid", energy: "moderate", ageTone: "adult", role: "host", wordCount: 5, segments: 2 };
    expect(hasFallbackSpeakerProfile([heuristic])).toBe(true);
    expect(hasFallbackSpeakerProfile([{ ...heuristic, archetype: "mentor" }])).toBe(false);
    expect(hasFallbackSpeakerProfile([])).toBe(true);

    expect(isAcousticOnlyProsody(new Map([[0, { energyDb: -20 }]]), 1)).toBe(true);
    expect(isAcousticOnlyProsody(new Map([[0, { energyDb: -20, emotionalIntensity: { anger: 0 } }]]), 1)).toBe(false);
    expect(isAcousticOnlyProsody(new Map(), 0)).toBe(false);
  });
});

describe("upload-time preparation policy", () => {
  const prev = process.env.DUBBING_PREWARM;
  afterEach(() => { if (prev === undefined) delete process.env.DUBBING_PREWARM; else process.env.DUBBING_PREWARM = prev; });

  const base = { dubbingRequested: false, sourceLanguageSupported: true, durationSeconds: 120 };

  test("defaults to creators who have ordered dubbing before", () => {
    delete process.env.DUBBING_PREWARM;
    expect(readPrewarmMode()).toBe("previous_dubbers");
    process.env.DUBBING_PREWARM = "nonsense";
    expect(readPrewarmMode()).toBe("previous_dubbers");
    process.env.DUBBING_PREWARM = "off";
    expect(readPrewarmMode()).toBe("off");
  });

  test("decisions", () => {
    expect(prewarmDecision(base, "off", true).prewarm).toBe(false);
    expect(prewarmDecision({ ...base, dubbingRequested: true }, "all", true).prewarm).toBe(false);
    expect(prewarmDecision({ ...base, sourceLanguageSupported: false }, "all", true).prewarm).toBe(false);
    expect(prewarmDecision({ ...base, durationSeconds: 3 * 3600 }, "all", true).prewarm).toBe(false);
    expect(prewarmDecision(base, "all", null).prewarm).toBe(true);
    expect(prewarmDecision(base, "previous_dubbers", true).prewarm).toBe(true);
    expect(prewarmDecision(base, "previous_dubbers", false).prewarm).toBe(false);
  });
});

describe("parallel steps keep results in input order", () => {
  test("mapWithConcurrency returns results in input order even when later items finish first", async () => {
    const delays = [40, 5, 25, 1, 10];
    let inFlight = 0;
    let maxInFlight = 0;
    const out = await mapWithConcurrency(delays, 3, async (d, i) => {
      inFlight++;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((r) => setTimeout(r, d));
      inFlight--;
      return i;
    });
    expect(out).toEqual([0, 1, 2, 3, 4]);
    expect(maxInFlight).toBe(3);
  });
});

describe("pipeline wiring (source checks)", () => {
  const src = fs.readFileSync(path.join(__dirname, "../../src/pipeline/layers/07-dubbing.ts"), "utf8");

  test("separation starts before the diarization check and is awaited before emotion transfer", () => {
    const sepStart = src.indexOf("this.runSeparationChain(jobId, userId, videoUrl, executionPlan, segments");
    const diar = src.indexOf("await this.runDiarizationCheck(jobId, videoUrl, executionPlan, segments, transcript)");
    const profiling = src.indexOf("speakerProfiles = await this.runSpeakerProfiling(");
    const awaitSep = src.indexOf("const chain = await separationChain!;");
    const emotion = src.indexOf("// 1.6a3. Emotion transfer");
    expect(sepStart).toBeGreaterThan(0);
    expect(sepStart).toBeLessThan(diar);
    expect(diar).toBeLessThan(profiling);
    expect(profiling).toBeLessThan(awaitSep);
    expect(awaitSep).toBeLessThan(emotion);
  });

  test("voices are still assigned one speaker at a time, after all speakers are measured", () => {
    const measured = src.indexOf("const measuredProfiles = await mapWithConcurrency(speakerProfiles");
    const loop = src.indexOf("for (let profileIndex = 0; profileIndex < speakerProfiles.length; profileIndex++)");
    const select = src.indexOf("voiceMatcher.selectNearestVoice(", loop);
    expect(measured).toBeGreaterThan(0);
    expect(measured).toBeLessThan(loop);
    expect(select).toBeGreaterThan(loop);
  });

  test("subtitles are awaited after TTS and before every early return of the voiced branch", () => {
    const tts = src.indexOf("const ttsResult = await this.parallelTTSWithCache(");
    const settle = src.indexOf("await settleSubtitles();", tts);
    expect(settle).toBeGreaterThan(tts);
    expect(src).toMatch(/await subtitleTask;\s+await this\.propagateAudioTrack/);
    expect(src).toMatch(/await subtitleTask;\s+return null as any;/);
    expect(src).toMatch(/finally \{[\s\S]{0,300}await settleSubtitles\(\);/);
    expect(src).toContain("if (subtitleTaskError !== null) throw subtitleTaskError;");
  });

  test("pre-TTS shortening applies results in line order", () => {
    expect(src).toContain("mapWithConcurrency(preTtsCandidates, PRE_TTS_RETRANSLATE_CONCURRENCY");
    expect(src).toMatch(/preTtsCandidates\.forEach\(\(\{ i \}, k\) =>/);
  });
});
