/**
 * Voice selection without cloning: the chosen native voice must be the one that sounds closest to
 * the original speaker (measured pitch, age, timbre), not just the first voice of the right language.
 */
jest.mock("../../src/pipeline/utils/logger", () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() } }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexAI: jest.fn(), getVertexClient: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-utils", () => ({ extractCandidateText: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: {} }), { virtual: true });
jest.mock("../../src/pipeline/services/media", () => ({ extractPitch: jest.fn(), extractMedianPitchHz: jest.fn() }), { virtual: true });

import { ElevenLabsVoiceMatcher, type DiarizedSpeakerProfile, type ElevenLabsVoiceCandidate } from "../../src/pipeline/services/voice-matcher";
import { assignNativeVoices, EXACT_LANGUAGE_PREFERENCE, type NativeCandidate } from "../../src/pipeline/services/language-voice-assignment";
import { libraryVoiceToCandidate, nameDescriptors } from "../../src/pipeline/services/library-voice-catalog";
import { clearVoiceAcousticsMemory, VOICE_ACOUSTICS_METHOD, withMeasuredPitch, type VoiceAcoustics, type VoiceAcousticsDeps } from "../../src/pipeline/services/voice-acoustics";

const matcher = new ElevenLabsVoiceMatcher();

const speaker = (over: Partial<DiarizedSpeakerProfile> = {}): DiarizedSpeakerProfile => ({
  speakerId: "A",
  estimatedAge: 40,
  ageBucket: "middle_aged",
  gender: "male",
  medianPitchHz: 100,
  timbreTags: ["deep", "calm"],
  confidence: 0.9,
  ...over,
});

const voice = (over: Partial<ElevenLabsVoiceCandidate> & { voiceId: string }): ElevenLabsVoiceCandidate => ({
  name: over.voiceId,
  gender: "male",
  ageBucket: "middle_aged",
  representativeAge: 42,
  typicalPitchHz: 118,
  timbreTags: [],
  indicVerified: true,
  ...over,
});

type Cand = NativeCandidate & ElevenLabsVoiceCandidate;
const native = (over: Partial<Cand> & { voiceId: string; tier: 1 | 2 }): Cand => ({ ...voice(over), ...over }) as Cand;

describe("scoreCandidate — measured pitch decides between otherwise equal voices", () => {
  it("prefers the voice whose measured pitch is closest to the speaker", () => {
    const deep = voice({ voiceId: "deep", typicalPitchHz: 98, pitchMeasured: true });
    const high = voice({ voiceId: "high", typicalPitchHz: 150, pitchMeasured: true });
    expect(matcher.scoreCandidate(speaker(), deep)).toBeLessThan(matcher.scoreCandidate(speaker(), high));
  });

  it("does not let a gender-default pitch (unmeasured) win or lose the match", () => {
    const a = voice({ voiceId: "a", typicalPitchHz: 118, pitchMeasured: false });
    const b = voice({ voiceId: "b", typicalPitchHz: 205, pitchMeasured: false });
    expect(matcher.scoreCandidate(speaker(), a)).toBeCloseTo(matcher.scoreCandidate(speaker(), b));
  });

  it("treats an unmeasurable speaker pitch as unknown, not as 120 Hz", () => {
    const s = speaker({ medianPitchHz: 0 });
    const a = voice({ voiceId: "a", typicalPitchHz: 95, pitchMeasured: true });
    const b = voice({ voiceId: "b", typicalPitchHz: 140, pitchMeasured: true });
    expect(matcher.scoreCandidate(s, a)).toBeCloseTo(matcher.scoreCandidate(s, b));
  });

  it("judges 'deep' relative to gender — a 190 Hz woman's voice is not penalised as light", () => {
    const s = speaker({ gender: "female", medianPitchHz: 185, vocalWeight: "deep", timbreTags: [] });
    const richFemale = voice({ voiceId: "f", gender: "female", typicalPitchHz: 178, pitchMeasured: true });
    const brightFemale = voice({ voiceId: "g", gender: "female", typicalPitchHz: 245, pitchMeasured: true });
    expect(matcher.scoreCandidate(s, richFemale)).toBeLessThan(matcher.scoreCandidate(s, brightFemale));
    // No vocal-weight penalty for the rich female voice (old rule penalised anything above 115 Hz).
    const noWeight = matcher.scoreCandidate({ ...s, vocalWeight: undefined }, richFemale);
    expect(matcher.scoreCandidate(s, richFemale)).toBeCloseTo(noWeight);
  });
});

describe("assignNativeVoices — closest native voice, not first native voice", () => {
  const profiles: Record<string, DiarizedSpeakerProfile> = {
    joseph: speaker({ speakerId: "joseph", medianPitchHz: 98, estimatedAge: 45, timbreTags: ["deep", "calm"] }),
    guard: speaker({ speakerId: "guard", medianPitchHz: 135, estimatedAge: 30, ageBucket: "young", timbreTags: ["energetic"] }),
  };
  const dist = (s: { speakerId: string }, v: Cand) => matcher.scoreCandidate(profiles[s.speakerId], v);
  const spk = (id: string) => ({ speakerId: id, gender: "male" as const, baseVoiceId: `base_${id}` });

  it("picks a close Indian voice over a clearly worse exact-language voice", () => {
    const pool = [
      native({ voiceId: "te_bright", tier: 2, typicalPitchHz: 150, pitchMeasured: true, ageBucket: "young", representativeAge: 25 }),
      native({ voiceId: "hi_deep", tier: 1, typicalPitchHz: 99, pitchMeasured: true, representativeAge: 45, timbreTags: ["deep", "calm"] }),
    ];
    const r = assignNativeVoices([spk("joseph")], pool, dist);
    expect(r.mapping.joseph).toBe("hi_deep");
    expect(r.matchDistance.joseph).toBeLessThan(0.15);
  });

  it("keeps the exact-language voice when the two are nearly as close", () => {
    const pool = [
      native({ voiceId: "hi_deep", tier: 1, typicalPitchHz: 99, pitchMeasured: true, representativeAge: 45 }),
      native({ voiceId: "te_deep", tier: 2, typicalPitchHz: 101, pitchMeasured: true, representativeAge: 45 }),
    ];
    const gap = dist({ speakerId: "joseph" }, pool[1]) - dist({ speakerId: "joseph" }, pool[0]);
    expect(gap).toBeGreaterThan(0);
    expect(gap).toBeLessThan(EXACT_LANGUAGE_PREFERENCE);
    expect(assignNativeVoices([spk("joseph")], pool, dist).mapping.joseph).toBe("te_deep");
  });

  it("lets the speaker who talks most choose first", () => {
    // One voice fits both best; the main character (more speaking time) must get it,
    // even though the minor speaker is listed first.
    const pool = [
      native({ voiceId: "te_close", tier: 2, typicalPitchHz: 110, pitchMeasured: true, representativeAge: 38 }),
      native({ voiceId: "te_far", tier: 2, typicalPitchHz: 170, pitchMeasured: true, representativeAge: 25, ageBucket: "young" }),
    ];
    const turns = [
      { speaker: "guard", start: 0, end: 2 },
      { speaker: "joseph", start: 3, end: 40 },
    ];
    const both: Record<string, DiarizedSpeakerProfile> = { ...profiles, guard: speaker({ speakerId: "guard", medianPitchHz: 112, estimatedAge: 38, timbreTags: [] }) };
    const d = (s: { speakerId: string }, v: Cand) => matcher.scoreCandidate(both[s.speakerId], v);
    const r = assignNativeVoices([spk("guard"), spk("joseph")], pool, d, turns);
    expect(r.mapping.joseph).toBe("te_close");
    expect(r.mapping.guard).toBe("te_far");
  });

  it("still never uses a foreign voice: no native voice → unresolved", () => {
    const r = assignNativeVoices([spk("joseph")], [], dist);
    expect(r.unresolvedSpeakers).toEqual(["joseph"]);
  });
});

describe("library catalog voices carry what matching needs", () => {
  it("marks pitch as unmeasured, keeps the preview link, and uses descriptive words as timbre tags", () => {
    const c = libraryVoiceToCandidate(
      {
        voiceId: "v1",
        publicOwnerId: "o",
        name: "Seeta - Rich Telugu Story Narrator",
        gender: "female",
        age: "middle_aged",
        accent: "standard",
        verifiedForLanguage: true,
        noticePeriodDays: 730,
        previewUrl: "https://example.invalid/p.mp3",
        descriptive: "warm",
      },
      "te"
    );
    expect(c.pitchMeasured).toBe(false);
    expect(c.previewUrl).toBe("https://example.invalid/p.mp3");
    expect(c.timbreTags).toEqual(expect.arrayContaining(["rich", "story", "narrator", "warm", "lang:te", "telugu", "indian"]));
    expect(c.timbreTags).not.toContain("standard");
  });

  it("reads descriptors only from the part after the separator", () => {
    expect(nameDescriptors("Madhavi - Clear & Natural Conversation")).toEqual(["clear", "natural", "conversation"]);
    expect(nameDescriptors("Srinu")).toEqual([]);
  });
});

describe("withMeasuredPitch — measure each voice once, never fail the job", () => {
  beforeEach(() => clearVoiceAcousticsMemory());

  const fakeDeps = (overrides: Partial<VoiceAcousticsDeps> = {}) => {
    const store: Record<string, VoiceAcoustics> = {};
    const deps: VoiceAcousticsDeps & { store: typeof store; measurePreview: jest.Mock } = {
      store,
      measurePreview: jest.fn(async (url: string) => (url.includes("bad") ? null : { medianHz: url.includes("deep") ? 96 : 140, spreadSemitones: 3, voicedFrames: 200, voicedRatio: 0.8 })),
      cacheGet: jest.fn(async (ids: string[]) => Object.fromEntries(ids.filter((id) => store[id]).map((id) => [id, store[id]]))),
      cacheSet: jest.fn(async (id: string, v: VoiceAcoustics) => {
        store[id] = v;
      }),
      ...overrides,
    } as any;
    return deps;
  };

  const cands = [
    voice({ voiceId: "a", previewUrl: "https://x/deep.mp3", pitchMeasured: false }),
    voice({ voiceId: "b", previewUrl: "https://x/mid.mp3", pitchMeasured: false }),
    voice({ voiceId: "c", previewUrl: "https://x/bad.mp3", pitchMeasured: false }),
    voice({ voiceId: "d", pitchMeasured: false }),
    voice({ voiceId: "e", typicalPitchHz: 104 }),
  ];

  it("replaces gender defaults with measured pitch and leaves unmeasurable voices marked unmeasured", async () => {
    const deps = fakeDeps();
    const { candidates, summary } = await withMeasuredPitch(cands, deps);
    const byId = Object.fromEntries(candidates.map((c) => [c.voiceId, c]));
    expect(byId.a).toMatchObject({ typicalPitchHz: 96, pitchMeasured: true });
    expect(byId.b).toMatchObject({ typicalPitchHz: 140, pitchMeasured: true });
    expect(byId.c.pitchMeasured).toBe(false);
    expect(byId.d.pitchMeasured).toBe(false);
    expect(byId.e).toMatchObject({ typicalPitchHz: 104 });
    expect(summary).toEqual({ measured: 2, fromCache: 0, failed: 1, skipped: 2, failureReasons: { "no pitch": 1 } });
    expect(deps.store.a).toMatchObject({ pitchHz: 96, method: VOICE_ACOUSTICS_METHOD });
  });

  it("uses the Firestore cache on a new instance and re-measures when the preview changed", async () => {
    const deps = fakeDeps();
    await withMeasuredPitch(cands, deps);
    clearVoiceAcousticsMemory();
    deps.measurePreview.mockClear();
    const changed = cands.map((c) => (c.voiceId === "b" ? { ...c, previewUrl: "https://x/deep_v2.mp3" } : c));
    const { summary } = await withMeasuredPitch(changed, deps);
    expect(summary.fromCache).toBe(1); // a
    expect(deps.measurePreview).toHaveBeenCalledWith("https://x/deep_v2.mp3");
    expect(deps.measurePreview).not.toHaveBeenCalledWith("https://x/deep.mp3");
  });

  it("survives cache and network failures", async () => {
    const deps = fakeDeps({
      cacheGet: jest.fn(async () => {
        throw new Error("firestore down");
      }),
      measurePreview: jest.fn(async () => {
        throw new Error("network");
      }),
    });
    const { candidates, summary } = await withMeasuredPitch(cands, deps);
    expect(candidates.every((c) => c.pitchMeasured !== true)).toBe(true);
    expect(summary.failed).toBe(3);
    // The reason is reported, not swallowed (24 Nov: 0 of 40 voices measured and no reason logged).
    expect(summary.failureReasons).toEqual({ "error: network": 3 });
  });

  it("reports no failure reasons when every voice is measured", async () => {
    const deps = fakeDeps();
    const { summary } = await withMeasuredPitch(cands.filter((c) => c.voiceId !== "c"), deps);
    expect(summary.failed).toBe(0);
    expect(summary.failureReasons).toBeUndefined();
  });
});
