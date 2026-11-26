/**
 * Per-language library voices: catalog builder, per-language assignment, withdrawn-voice fallback,
 * matcher acceptance rules and paginated account voice listing.
 */
jest.mock("../../src/pipeline/utils/logger", () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() } }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-client", () => ({ getVertexAI: jest.fn(), getVertexClient: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/utils/ai-utils", () => ({ extractCandidateText: jest.fn() }), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: {} }), { virtual: true });
jest.mock("../../src/pipeline/services/media", () => ({ extractMedianPitchHz: jest.fn() }), { virtual: true });

import { ElevenLabsVoiceMatcher, isTwLibraryVoice, twLibraryLanguage } from "../../src/pipeline/services/voice-matcher";
import { assignLanguageVoices } from "../../src/pipeline/services/language-voice-assignment";
import { libraryVoicesFor, libraryVoiceToCandidate, loadLibraryCatalog } from "../../src/pipeline/services/library-voice-catalog";
import { getVoiceFallback, isVoiceUnavailableError, registerVoiceFallbacks } from "../../src/pipeline/services/voice-fallbacks";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const builder = require("../../scripts/build_voice_catalog.js");

const lib = (over: Record<string, unknown>) => ({
  public_owner_id: "owner",
  voice_id: "v",
  name: "Voice",
  gender: "female",
  age: "young",
  language: "te",
  rate: null,
  fiat_rate: null,
  live_moderation_enabled: false,
  notice_period: 0,
  usage_character_count_1y: 0,
  verified_languages: [],
  ...over,
});

describe("build_voice_catalog.js", () => {
  test("covers the dubbing languages on the eleven_v4 list by default, 5 per gender, with child age support", () => {
    const args = builder.parseArgs([]);
    expect(args.languages).toHaveLength(84);
    expect(args.languages).toEqual(expect.arrayContaining(["te", "hi", "fil", "ar", "ja"]));
    expect(args.languages).not.toContain("tl");
    expect(args.perGender).toBe(5);
    expect(builder.parseArgs(["--languages", "te,hi", "--per-gender=8"])).toMatchObject({ languages: ["te", "hi"], perGender: 8 });
    expect(builder.parseArgs(["--languages", "te,hi", "--per-gender", "25"])).toMatchObject({ languages: ["te", "hi"], perGender: 25 });
    expect(builder.AGES).toContain("child");
  });

  test("skips custom-priced, live-moderated, wrong-gender and wrong-language voices", () => {
    const candidates = [
      lib({ voice_id: "ok", name: "Ok" }),
      lib({ voice_id: "pricey", name: "Pricey", rate: 2 }),
      lib({ voice_id: "fiat", name: "Fiat", fiat_rate: 0.3 }),
      lib({ voice_id: "mod", name: "Mod", live_moderation_enabled: true }),
      lib({ voice_id: "man", name: "Man", gender: "male" }),
      lib({ voice_id: "hindi", name: "Hindi", language: "hi" }),
    ];
    expect(builder.selectVoices(candidates, "te", "female", 10).map((v: any) => v.voice_id)).toEqual(["ok"]);
  });

  test("verified first, spread across ages", () => {
    const candidates = [
      lib({ voice_id: "y1", name: "Y1", age: "young", usage_character_count_1y: 900 }),
      lib({ voice_id: "y2", name: "Y2", age: "young", usage_character_count_1y: 800 }),
      lib({ voice_id: "m1", name: "M1", age: "middle_aged", notice_period: 90 }),
      lib({ voice_id: "o1", name: "O1", age: "old", verified_languages: [{ language: "te", model_id: "x" }] }),
    ];
    expect(new Set(builder.selectVoices(candidates, "te", "female", 3).map((v: any) => v.voice_id))).toEqual(new Set(["y1", "m1", "o1"]));
  });

  test("catalog entries have the shape the pipeline reads", () => {
    const e = builder.toCatalogEntry(lib({ voice_id: "x", public_owner_id: "p", name: "Lakshmi", notice_period: 30, preview_url: "u" }), "te");
    expect(e).toEqual({
      voiceId: "x", publicOwnerId: "p", name: "Lakshmi", gender: "female", age: "young", accent: undefined,
      verifiedForLanguage: false, noticePeriodDays: 30, previewUrl: "u",
    });
  });

  test("the old add-to-account script no longer adds voices", () => {
    const src = require("fs").readFileSync(require("path").join(__dirname, "../../scripts/add_library_voices.js"), "utf8");
    expect(src).not.toMatch(/voices\/add/);
  });
});

describe("assignLanguageVoices", () => {
  const speakers = [
    { speakerId: "J", gender: "male" as const, baseVoiceId: "presetM1" },
    { speakerId: "G", gender: "male" as const, baseVoiceId: "presetM2" },
    { speakerId: "W", gender: "female" as const, baseVoiceId: "presetF1" },
    { speakerId: "C", gender: "male" as const, baseVoiceId: "creatorClone", locked: true },
  ];
  const teMale = [{ voiceId: "teM1", gender: "male" as const }];
  const teFemale = [{ voiceId: "teF1", gender: "female" as const }, { voiceId: "teF2", gender: "female" as const }];

  test("main speakers get native voices, unique within the language; extra speakers keep presets", () => {
    const r = assignLanguageVoices(speakers, [...teMale, ...teFemale], () => 0);
    expect(r.mapping).toEqual({ J: "teM1", G: "presetM2", W: "teF1", C: "creatorClone" });
    expect(r.nativeSpeakers).toEqual(["J", "W"]);
    expect(new Set(Object.values(r.mapping)).size).toBe(4);
  });

  test("records the preset fallback for every native voice", () => {
    const r = assignLanguageVoices(speakers, [...teMale, ...teFemale], () => 0);
    expect(r.fallbacks).toEqual({ teM1: "presetM1", teF1: "presetF1" });
  });

  test("a creator's own clone is never replaced", () => {
    const r = assignLanguageVoices([speakers[3]], [{ voiceId: "teM9", gender: "male" as const }], () => 0);
    expect(r.mapping.C).toBe("creatorClone");
  });

  test("picks the nearest native voice by the matcher's distance", () => {
    const r = assignLanguageVoices([speakers[2]], teFemale, (_s, v) => (v.voiceId === "teF2" ? 0.1 : 0.9));
    expect(r.mapping.W).toBe("teF2");
  });

  test("no catalog voices → everyone keeps the preset voice", () => {
    const r = assignLanguageVoices(speakers, [], () => 0);
    expect(r.mapping).toEqual({ J: "presetM1", G: "presetM2", W: "presetF1", C: "creatorClone" });
    expect(r.fallbacks).toEqual({});
  });
});

describe("library catalog file", () => {
  test("catalog file parses and provides valid language entries", () => {
    const catalog = loadLibraryCatalog();
    expect(typeof catalog.languages).toBe("object");
    expect(catalog.version).toBe(1);
    if (Object.keys(catalog.languages).length === 0) {
      expect(libraryVoicesFor(catalog, "te-IN")).toEqual([]);
    } else {
      expect(catalog.languages.te?.length).toBeGreaterThan(0);
      expect(libraryVoicesFor(catalog, "te-IN").length).toBeGreaterThan(0);
    }
  });

  test("lookup normalises region codes and Tagalog", () => {
    const catalog = { version: 1, generatedAt: null, languages: { te: [{ voiceId: "a" } as any], fil: [{ voiceId: "b" } as any] } };
    expect(libraryVoicesFor(catalog, "te-IN")[0].voiceId).toBe("a");
    expect(libraryVoicesFor(catalog, "tl")[0].voiceId).toBe("b");
  });

  test("library voices become matcher candidates", () => {
    const c = libraryVoiceToCandidate(
      { voiceId: "x", publicOwnerId: "p", name: "Lakshmi", gender: "female", age: "middle_aged", accent: "indian", verifiedForLanguage: true, noticePeriodDays: 0 },
      "te"
    );
    expect(c).toMatchObject({ voiceId: "x", gender: "female", ageBucket: "middle_aged", indicVerified: true });
    expect(c.timbreTags).toEqual(["indian", "telugu", "lang:te"]);
  });
});

describe("withdrawn library voice fallback", () => {
  test("registers per job and looks up by voice", () => {
    registerVoiceFallbacks("job1", { teM1: "presetM1" });
    expect(getVoiceFallback("job1", "teM1")).toBe("presetM1");
    expect(getVoiceFallback("job2", "teM1")).toBeUndefined();
    expect(getVoiceFallback("job1", "presetM1")).toBeUndefined();
  });

  test("recognises voice-not-found errors but not other failures", () => {
    expect(isVoiceUnavailableError(404, '{"detail":{"status":"voice_not_found"}}')).toBe(true);
    expect(isVoiceUnavailableError(400, "voice_not_available")).toBe(true);
    expect(isVoiceUnavailableError(429, "rate_limit")).toBe(false);
    expect(isVoiceUnavailableError(401, "quota_exceeded")).toBe(false);
  });
});

describe("voice matcher account voices", () => {
  const realFetch = global.fetch;
  afterEach(() => {
    global.fetch = realFetch;
  });

  test("name helpers", () => {
    expect(isTwLibraryVoice("TW Library · te · Lakshmi")).toBe(true);
    expect(twLibraryLanguage("TW Library · te · Lakshmi")).toBe("te");
  });

  test("pages through GET /v2/voices and still never uses creator clones", async () => {
    const page1 = { voices: [{ voice_id: "a", name: "A", category: "premade", labels: { gender: "male" } }], has_more: true, next_page_token: "t2" };
    const page2 = {
      voices: [
        { voice_id: "lib1", name: "TW Library · te · Lakshmi", category: "professional", labels: { gender: "female" } },
        { voice_id: "clone1", name: "Creator clone", category: "cloned", labels: { gender: "male" } },
      ],
      has_more: false,
      next_page_token: null,
    };
    const fetchMock = jest.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => page1 })
      .mockResolvedValueOnce({ ok: true, json: async () => page2 });
    global.fetch = fetchMock as any;
    const ids = (await new ElevenLabsVoiceMatcher().getVoiceCatalog("key")).map((c) => c.voiceId);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[0][0])).toContain("/v2/voices?page_size=100");
    expect(String(fetchMock.mock.calls[1][0])).toContain("next_page_token=t2");
    expect(ids).toEqual(expect.arrayContaining(["a", "lib1"]));
    expect(ids).not.toContain("clone1");
  });
});
