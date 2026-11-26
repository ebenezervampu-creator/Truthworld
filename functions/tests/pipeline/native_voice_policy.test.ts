/**
 * Native-voice policy: Indic dubs use only Indian voices, other languages only their own voices,
 * never American (or any foreign) presets; no native voice → no dub for that language.
 */
import { assignNativeVoices, type NativeCandidate } from "../../src/pipeline/services/language-voice-assignment";
import { nativeTier, nativeVoicesOnly, noNativeVoiceMessage, voiceLanguages } from "../../src/pipeline/services/voice-locale-policy";

const v = (voiceId: string, gender: "male" | "female", timbreTags: string[]) => ({ voiceId, gender, timbreTags });

// Real preset tag shapes from voice-matcher.ts
const antoniAmerican = v("antoni", "male", ["deep", "warm", "american"]);
const georgeBritish = v("george", "male", ["warm", "raspy", "narration", "british"]);
const srinuTelugu = v("srinu", "male", ["conversational", "creator", "indian", "telugu"]);
const avaniIndian = v("avani", "female", ["warm", "pleasant", "indian"]);
const libraryHindi = v("hiLib", "male", ["indian", "hindi", "lang:hi"]);
const librarySpanish = v("esLib", "female", ["castilian", "lang:es"]);

describe("nativeTier", () => {
  test("Telugu: Telugu voice is tier 2, other Indian voices tier 1, American/British never", () => {
    expect(nativeTier(srinuTelugu, "te")).toBe(2);
    expect(nativeTier(avaniIndian, "te")).toBe(1);
    expect(nativeTier(libraryHindi, "te-IN")).toBe(1);
    expect(nativeTier(antoniAmerican, "te")).toBe(0);
    expect(nativeTier(georgeBritish, "te")).toBe(0);
  });

  test("Hindi: Hindi library voice first, Telugu/Indian voices allowed, American never", () => {
    expect(nativeTier(libraryHindi, "hi")).toBe(2);
    expect(nativeTier(srinuTelugu, "hi")).toBe(1);
    expect(nativeTier(antoniAmerican, "hi")).toBe(0);
  });

  test("Spanish: only Spanish voices — no American, no Indian", () => {
    expect(nativeTier(librarySpanish, "es")).toBe(2);
    expect(nativeTier(antoniAmerican, "es")).toBe(0);
    expect(nativeTier(srinuTelugu, "es")).toBe(0);
  });

  test("English: any English accent is native", () => {
    expect(nativeTier(antoniAmerican, "en")).toBe(2);
    expect(nativeTier(georgeBritish, "en-GB")).toBe(2);
  });

  test("voiceLanguages reads accent words and lang: markers", () => {
    expect([...voiceLanguages(srinuTelugu)].sort()).toEqual(["indic", "te"]);
    expect([...voiceLanguages(librarySpanish)]).toEqual(["es"]);
  });
});

describe("assignNativeVoices", () => {
  const candidatesFor = (lang: string, voices: ReturnType<typeof v>[], library: string[] = []): NativeCandidate[] =>
    voices
      .map((x) => ({ ...x, tier: nativeTier(x, lang), fromLibrary: library.includes(x.voiceId) }))
      .filter((x): x is typeof x & { tier: 1 | 2 } => x.tier > 0);

  const all = [antoniAmerican, georgeBritish, srinuTelugu, avaniIndian, libraryHindi, librarySpanish,
    v("maddy", "male", ["indian", "telugu"]), v("sai", "male", ["indian", "telugu"])];

  test("Clip 2 in Telugu: guard, Joseph, prisoner all get Telugu voices — no American", () => {
    const speakers = ["guard", "joseph", "prisoner"].map((id) => ({ speakerId: id, gender: "male" as const, baseVoiceId: "antoni" }));
    const r = assignNativeVoices(speakers, candidatesFor("te", all, ["hiLib"]), () => 0);
    expect(r.unresolvedSpeakers).toEqual([]);
    expect(Object.values(r.mapping).sort()).toEqual(["maddy", "sai", "srinu"]);
    expect(Object.values(r.mapping)).not.toContain("antoni");
  });

  test("this-language voices are used before same-region ones", () => {
    const speakers = [{ speakerId: "a", gender: "male" as const, baseVoiceId: "antoni" }];
    const r = assignNativeVoices(speakers, candidatesFor("hi", all, ["hiLib"]), () => 0);
    expect(r.mapping.a).toBe("hiLib");
  });

  test("a female speaker in Spanish with only a Spanish female voice → gets it; a male speaker → unresolved (no dub)", () => {
    const speakers = [
      { speakerId: "w", gender: "female" as const, baseVoiceId: "rachel" },
      { speakerId: "m", gender: "male" as const, baseVoiceId: "antoni" },
    ];
    const r = assignNativeVoices(speakers, candidatesFor("es", all, ["esLib"]), () => 0);
    expect(r.mapping.w).toBe("esLib");
    expect(r.unresolvedSpeakers).toEqual(["m"]);
    expect(r.mapping.m).toBeUndefined();
  });

  test("more speakers than native voices → reuse only between people far apart, never overlapping", () => {
    const tel = candidatesFor("te", [srinuTelugu]);
    const speakers = [
      { speakerId: "a", gender: "male" as const, baseVoiceId: "x" },
      { speakerId: "b", gender: "male" as const, baseVoiceId: "x" },
      { speakerId: "c", gender: "male" as const, baseVoiceId: "x" },
    ];
    const turns = [
      { speaker: "a", start: 0, end: 10_000 },
      { speaker: "b", start: 600_000, end: 610_000 }, // ten minutes later
      { speaker: "c", start: 5_000, end: 8_000 }, // talks over a
    ];
    const r = assignNativeVoices(speakers, tel, () => 0, turns);
    expect(r.mapping.a).toBe("srinu");
    expect(r.mapping.b).toBe("srinu");
    expect(r.reusedSpeakers).toEqual(["b"]);
    // c overlaps a (and b's reuse is the same voice) → cannot share safely → unresolved, no dub
    expect(r.unresolvedSpeakers).toEqual(["c"]);
  });

  test("a creator's own clone is always kept", () => {
    const r = assignNativeVoices([{ speakerId: "me", gender: "male", baseVoiceId: "myClone", locked: true }], candidatesFor("te", all), () => 0);
    expect(r.mapping.me).toBe("myClone");
    expect(r.unresolvedSpeakers).toEqual([]);
  });

  test("library voices fall back to a native preset, never a foreign one", () => {
    const r = assignNativeVoices([{ speakerId: "a", gender: "male", baseVoiceId: "antoni" }], candidatesFor("hi", all, ["hiLib"]), () => 0);
    expect(r.mapping.a).toBe("hiLib");
    expect(["srinu", "maddy", "sai"]).toContain(r.fallbacks.hiLib);
  });
});

describe("policy switch and creator message", () => {
  const original = process.env.DUBBING_NATIVE_VOICES_ONLY;
  afterEach(() => {
    if (original === undefined) delete process.env.DUBBING_NATIVE_VOICES_ONLY;
    else process.env.DUBBING_NATIVE_VOICES_ONLY = original;
  });

  test("on by default; only an explicit false turns it off", () => {
    delete process.env.DUBBING_NATIVE_VOICES_ONLY;
    expect(nativeVoicesOnly()).toBe(true);
    process.env.DUBBING_NATIVE_VOICES_ONLY = "false";
    expect(nativeVoicesOnly()).toBe(false);
  });

  test("skipped-dub message names the language, mentions subtitles, no technical words", () => {
    const m = noNativeVoiceMessage("te");
    expect(m).toMatch(/Telugu audio track/);
    expect(m).toMatch(/Telugu subtitles are ready/);
    expect(m).not.toMatch(/error|elevenlabs|voice_id|catalog|api/i);
  });
});
