/**
 * Dubbing Studio order rules (src/dubbing/studio-order.ts) and their wiring in standaloneDubbing.ts.
 * Fixes from the 2026-11-24 Studio check: S2 refund on dispatch failure, S3 server-measured length,
 * S4 subtitle pricing, S5 credit purchase off, S7 regenerate off-by-one, and voice cloning only on
 * explicit selection with consent.
 */
import * as fs from "fs";
import * as path from "path";
import {
  decideStudioVoiceCloning,
  decideStudioDuration,
  studioCharge,
  studioSegmentIndex,
  channelSubtitleDiscountPercent,
  isDubbedVideoUrl,
  STUDIO_MAX_DURATION_SECONDS,
} from "../../src/dubbing/studio-order";
import { calculateSubtitleCost, getFlatDubbingPriceForTier } from "../../src/pipeline/services/cost-engine";

const SOURCE = fs.readFileSync(path.resolve(__dirname, "../../src/dubbing/standaloneDubbing.ts"), "utf8");
const createJobSource = SOURCE.slice(
  SOURCE.indexOf("export const createDubbingJob"),
  SOURCE.indexOf("export const updateDubbingTranscription")
);

describe("voice cloning: off unless selected with consent", () => {
  it("is standard voices when nothing is sent", () => {
    expect(decideStudioVoiceCloning({})).toEqual({
      ok: true,
      dubbingMode: "standard",
      voiceCloneConsent: false,
      saveAsCreatorProfile: false,
    });
  });

  it("is standard voices when cloning is off, even if consent is sent", () => {
    const d = decideStudioVoiceCloning({ voiceCloningEnabled: false, voiceCloneConsent: true, saveVoiceProfile: true });
    expect(d).toMatchObject({ ok: true, dubbingMode: "standard", voiceCloneConsent: false, saveAsCreatorProfile: false });
  });

  it("refuses cloning without consent", () => {
    const d = decideStudioVoiceCloning({ voiceCloningEnabled: true });
    expect(d.ok).toBe(false);
    if (!d.ok) expect(d.message).toMatch(/permission/);
  });

  it("only treats a real boolean true as consent", () => {
    expect(decideStudioVoiceCloning({ voiceCloningEnabled: true, voiceCloneConsent: "true" }).ok).toBe(false);
    expect(decideStudioVoiceCloning({ voiceCloningEnabled: "true", voiceCloneConsent: true })).toMatchObject({
      dubbingMode: "standard",
    });
  });

  it("clones with consent, and saves the voice only when asked", () => {
    expect(decideStudioVoiceCloning({ voiceCloningEnabled: true, voiceCloneConsent: true })).toEqual({
      ok: true,
      dubbingMode: "voice_clone",
      voiceCloneConsent: true,
      saveAsCreatorProfile: false,
    });
    expect(
      decideStudioVoiceCloning({ voiceCloningEnabled: true, voiceCloneConsent: true, saveVoiceProfile: true })
    ).toMatchObject({ saveAsCreatorProfile: true });
  });

  it("defaults cloning to off in createDubbingJob and decides before charging", () => {
    expect(createJobSource).toMatch(/voiceCloningEnabled = false,/);
    expect(createJobSource).not.toMatch(/voiceCloningEnabled = true/);
    expect(createJobSource.indexOf("decideStudioVoiceCloning(")).toBeLessThan(createJobSource.indexOf("runTransaction("));
    expect(createJobSource).toMatch(/dubbingMode: cloning\.dubbingMode/);
    expect(createJobSource).toMatch(/voiceCloneConsent: cloning\.voiceCloneConsent/);
  });
});

describe("billed length: measured by the server", () => {
  it("prefers the stored video length", () => {
    expect(decideStudioDuration(600, 5_000)).toEqual({ ok: true, seconds: 600 });
  });

  it("uses the measured length when nothing is stored, rounded up", () => {
    expect(decideStudioDuration(undefined, 3_600_400)).toEqual({ ok: true, seconds: 3601 });
  });

  it("refuses when the length can't be read (no more 120 s guess)", () => {
    const d = decideStudioDuration(0, 0);
    expect(d.ok).toBe(false);
  });

  it("refuses videos over 2 hours", () => {
    expect(decideStudioDuration(STUDIO_MAX_DURATION_SECONDS + 1, 0).ok).toBe(false);
    expect(decideStudioDuration(STUDIO_MAX_DURATION_SECONDS, 0).ok).toBe(true);
  });

  it("never prices from the app-sent durationSeconds", () => {
    expect(createJobSource).toMatch(/decideStudioDuration\(storedDurationSeconds, probedMs\)/);
    expect(createJobSource).not.toMatch(/Math\.max\(60, Number\(durationSeconds\)/);
    expect(createJobSource.indexOf("decideStudioDuration(")).toBeLessThan(createJobSource.indexOf("runTransaction("));
  });
});

describe("price: dubbing vs subtitles only", () => {
  const base = {
    targetLanguages: ["te", "hi"],
    durationSeconds: 600,
    channelData: {},
    isAdmin: false,
    dubbingDiscountPercent: 0,
    quote: null,
    characterPricing: false,
  };

  it("bills a dub at the dubbing price", () => {
    const c = studioCharge({ ...base, mode: "dubbing" });
    expect(c.kind).toBe("dubbing");
    expect(c.chargedUsd).toBeCloseTo(2 * getFlatDubbingPriceForTier(600, "audio_track"), 2);
    expect(c.subtitleUsd).toBe(0);
    expect(Object.keys(c.dubbingPriceByLanguage).sort()).toEqual(["hi", "te"]);
  });

  it("bills subtitles only at the subtitle price, not as a dub", () => {
    const c = studioCharge({ ...base, mode: "subtitles_only" });
    expect(c.kind).toBe("subtitles");
    expect(c.chargedUsd).toBe(calculateSubtitleCost(2, 600, "standard", 0, "ultra"));
    expect(c.dubbingUsd).toBe(0);
    expect(c.dubbingPriceByLanguage).toEqual({});
    expect(c.chargedUsd).toBeLessThan(studioCharge({ ...base, mode: "dubbing" }).chargedUsd);
  });

  it("applies admin-set subtitle discounts only", () => {
    expect(channelSubtitleDiscountPercent({ isSubtitlesFree: true }, false)).toBe(100);
    expect(channelSubtitleDiscountPercent({ subtitlesDiscountPercent: 25 }, false)).toBe(25);
    expect(channelSubtitleDiscountPercent({}, true)).toBe(100);
    expect(channelSubtitleDiscountPercent({ subtitlesDiscountPercent: "abc" }, false)).toBe(0);
    expect(studioCharge({ ...base, mode: "subtitles_only", channelData: { isSubtitlesFree: true } }).chargedUsd).toBe(0);
  });

  it("does not dub a subtitles-only order", () => {
    expect(createJobSource).toMatch(/dubbingLanguages: isSubtitlesOnly \? \[\] : targetLanguages/);
  });
});

describe("dispatch failure refunds the order", () => {
  it("refunds the whole order and tells the creator when Pub/Sub fails", () => {
    const catchBlock = createJobSource.slice(createJobSource.indexOf("} catch (pubSubErr) {"));
    expect(catchBlock).toMatch(/refundDubbingFeeOnFailure\(/);
    expect(catchBlock).toMatch(/orderId: effectiveTxId/);
    expect(catchBlock).toMatch(/throw new HttpsError\(\s*"unavailable"/);
    expect(catchBlock).not.toMatch(/pipeline will trigger via fallback/);
  });
});

describe("credit purchase is switched off", () => {
  it("takes no money", () => {
    const purchase = SOURCE.slice(SOURCE.indexOf("export const purchaseDubbingCreditsWithStudioWallet"));
    expect(purchase).not.toMatch(/runTransaction|walletBalanceUSD|withdrawnRevenueTotal/);
    expect(purchase).toMatch(/success: false/);
  });
});

describe("regenerate line: which line", () => {
  it("maps the app's 1-based seg_N ids to 0-based lines", () => {
    expect(studioSegmentIndex(undefined, "seg_1")).toBe(0);
    expect(studioSegmentIndex(undefined, "seg_12")).toBe(11);
    expect(studioSegmentIndex(undefined, "segment-3")).toBe(2);
  });

  it("uses an explicit 0-based index as is", () => {
    expect(studioSegmentIndex(0, "seg_5")).toBe(0);
    expect(studioSegmentIndex(4, undefined)).toBe(4);
  });

  it("refuses instead of guessing line 0", () => {
    expect(studioSegmentIndex(undefined, undefined)).toBeNull();
    expect(studioSegmentIndex(undefined, "seg_0")).toBeNull();
    expect(studioSegmentIndex(undefined, "abc")).toBeNull();
    expect(studioSegmentIndex(-1, "x")).toBeNull();
    expect(studioSegmentIndex(1.5, undefined)).toBeNull();
  });
});

describe("downloadable dubbed MP4 per language", () => {
  const original = "https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/uploads%2Fu1%2Fclip.mp4?alt=media&token=t";

  it("accepts the pipeline's dubbed MP4 in any URL form", () => {
    expect(isDubbedVideoUrl("gs://truthworld-1.firebasestorage.app/videos/vid_1/te-dubbed.mp4", original)).toBe(true);
    expect(
      isDubbedVideoUrl(
        "https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/vid_1/hi-dubbed.mp4?X-Goog-Signature=abc",
        original
      )
    ).toBe(true);
  });

  it("never offers the original upload as a dubbed video", () => {
    expect(isDubbedVideoUrl(original, original)).toBe(false);
    expect(isDubbedVideoUrl("gs://truthworld-1.firebasestorage.app/uploads/u1/clip.mp4", original)).toBe(false);
    expect(isDubbedVideoUrl("", original)).toBe(false);
    expect(isDubbedVideoUrl(undefined, original)).toBe(false);
  });

  it("asks the pipeline for an MP4 on Studio dub orders, not subtitle orders", () => {
    expect(createJobSource).toMatch(/deliverDubbedVideo: !isSubtitlesOnly/);
  });

  it("exports every language, not just the last one", () => {
    const exportSource = SOURCE.slice(SOURCE.indexOf("export const exportDubbingAssets"));
    expect(exportSource).toMatch(/dubbedVideoByLanguage: videoByLanguage/);
    expect(exportSource).toMatch(/dubbedAudioByLanguage: audioByLanguage/);
    expect(exportSource).toMatch(/videoByLanguage\[lang\] = pkg\.videoUrl/);
    expect(exportSource).not.toMatch(/masterAudioUrl = pkg\.audioUrl/);
  });

  it("builds the MP4 for the audio-track tier only when asked (both remux spots)", () => {
    const pipeline = fs.readFileSync(path.resolve(__dirname, "../../src/pipeline/layers/07-dubbing.ts"), "utf8");
    const gates = pipeline.match(/dubbingTier === "audio_track" && executionPlan\??\.deliverDubbedVideo !== true/g) || [];
    expect(gates.length).toBe(2);
  });
});
