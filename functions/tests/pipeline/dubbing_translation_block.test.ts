import * as admin from "firebase-admin";
import { testFirestore } from "../helpers/mockFirestore";
import { recordDubbingOrder } from "../../src/pipeline/services/refundService";
import {
  findBlockedTranslationLines,
  evaluatePreTtsDubbingDecision,
  findLongFormSkippedRefundLanguages,
} from "../../src/pipeline/services/translation-flags";
import { DubbingQualityGate, isBlockingViolation } from "../../src/pipeline/layers/quality-gate";
import { dubbingEngine } from "../../src/pipeline/layers/07-dubbing";
import { ttsService } from "../../src/pipeline/services/tts";

const db = () => admin.firestore();

describe("Phase 2 / R1 & R3: translation block gate & long-form refund path", () => {
  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.DUBBING_BLOCK_ON_TRANSLATION_ERRORS;
  });

  test("R1: findBlockedTranslationLines & evaluatePreTtsDubbingDecision drive pre-TTS stop and failed outcome", () => {
    const segs = [
      {
        originalText: "This is not safe.",
        translatedText: "ఇది సురక్షితం.",
        translationBlockReason: "polarity_flip" as const,
      },
      {
        originalText: "Hello.",
        translatedText: "నమస్కారం.",
      },
    ];

    const blocked = findBlockedTranslationLines(segs);
    expect(blocked).toEqual([
      {
        index: 0,
        reason: "polarity_flip",
        source: "This is not safe.",
        text: "ఇది సురక్షితం.",
      },
    ]);

    const decision = evaluatePreTtsDubbingDecision({
      generateDubbing: true,
      targetLang: "te",
      sourceLang: "en",
      isV4DubbingLanguage: true,
      blockedLines: blocked,
    });
    expect(decision.isDubbingSupportedForTarget).toBe(false);
    expect(decision.blockedByTranslation).toBe(true);
    expect(decision.initialDubOutcome).toBe("failed");

    const gate = DubbingQualityGate.evaluate({
      jobId: "job_block_real",
      targetLang: "te",
      totalSegments: segs.length,
      successfulSegments: segs.length,
      failedSegments: [],
      actualDurationSeconds: 0,
      expectedDurationSeconds: 5,
      isVoiceCloningRequested: false,
      isVoiceCloned: false,
      stemIsolationRequested: false,
      isStemPreserved: true,
      translationBlockedLines: blocked,
    });
    expect(gate.passed).toBe(false);
    expect(gate.violations.some(isBlockingViolation)).toBe(true);

    // Flag off restores unblocked dubbing
    process.env.DUBBING_BLOCK_ON_TRANSLATION_ERRORS = "false";
    const unblocked = findBlockedTranslationLines(segs);
    expect(unblocked).toHaveLength(0);
    const offDecision = evaluatePreTtsDubbingDecision({
      generateDubbing: true,
      targetLang: "te",
      sourceLang: "en",
      isV4DubbingLanguage: true,
      blockedLines: unblocked,
    });
    expect(offDecision.isDubbingSupportedForTarget).toBe(true);
    expect(offDecision.blockedByTranslation).toBe(false);
    expect(offDecision.initialDubOutcome).toBe("not_requested");
  });

  test("R3: findLongFormSkippedRefundLanguages identifies every ordered non-source language excluded from dubLanguages", () => {
    expect(findLongFormSkippedRefundLanguages(["en", "te", "hi"], ["hi"], "en")).toEqual(["te"]);
    expect(findLongFormSkippedRefundLanguages(["te", "hi"], [], "en")).toEqual(["te", "hi"]);
  });

  test("R3: dispatchLongFormReels stops a blocked language before TTS/reel dispatch and refunds its order fee", async () => {
    testFirestore.clear();
    await db().collection("channels").doc("ch_lf").set({ walletBalanceUSD: 50, walletBalance: 50 });
    await db().collection("video_jobs").doc("job_lf_block").set({
      videoId: "vid_lf",
      channelId: "ch_lf",
      currentDubbingOrderId: "order_lf",
      linkedVideoIds: ["vid_lf"],
    });
    await recordDubbingOrder({
      orderId: "order_lf",
      jobId: "job_lf_block",
      videoId: "vid_lf",
      channelId: "ch_lf",
      userId: "user_lf",
      paidUSD: 15,
      dubbingUSD: 15,
      subtitleUSD: 0,
      languages: ["te"],
      priceByLanguage: { te: 15 },
      createdAt: 1,
      source: "test",
    });

    const ttsSpy = jest.spyOn(ttsService, "synthesize");
    const publishSpy = jest.spyOn((dubbingEngine as any).distribution, "publish").mockResolvedValue(undefined);
    const markDoneSpy = jest.spyOn((dubbingEngine as any).distribution, "markEventCompleted").mockResolvedValue(undefined);
    const subSpy = jest.spyOn(dubbingEngine as any, "generateSubtitles");
    jest.spyOn(dubbingEngine as any, "resolveScreenContextForTranslation").mockImplementation(
      async (_j: any, _v: any, _d: any, segs: any) => ({ shotChangesMs: [2500], onScreenText: [], segments: segs })
    );
    jest.spyOn(dubbingEngine as any, "loadCastContext").mockResolvedValue({
      castList: [],
      relationships: [],
      speakerNames: {},
      castGenderByLabel: {},
    });
    jest.spyOn(dubbingEngine as any, "translateWithCache").mockResolvedValue([
      {
        index: 0,
        originalText: "This is not safe.",
        translatedText: "ఇది సురక్షితం.",
        subtitleText: "ఇది సురక్షితం.",
        language: "te",
        start: 0,
        end: 3000,
        targetDuration: 3000,
        speaker: "speaker_0",
        translationBlockReason: "polarity_flip",
      },
    ]);

    await (dubbingEngine as any).dispatchLongFormReels({
      jobId: "job_lf_block",
      userId: "user_lf",
      videoUrl: "",
      languagesToProcess: ["te"],
      segments: [{ index: 0, start: 0, end: 3000, duration: 3000, text: "This is not safe.", speaker: "speaker_0" }],
      sourceLang: "en",
      totalDurationMs: 600000,
      executionPlan: {
        generateDubbing: true,
        genLangSubs: true,
        dubbingMode: "matched",
        channelType: "standard",
      },
      speakerProfiles: [],
      acousticFingerprint: null,
      voiceMapping: { speaker_0: "voice_1" },
      creatorDNA: undefined,
      speakerGenderMapping: { speaker_0: "MALE" },
      mneStemUrl: null,
      isolatedVocalUrl: null,
      eventId: "evt_lf_1",
      words: [],
    });

    expect(ttsSpy).not.toHaveBeenCalled();
    expect(subSpy).not.toHaveBeenCalled();
    expect(publishSpy).not.toHaveBeenCalled();
    expect(markDoneSpy).toHaveBeenCalledWith("evt_lf_1");

    const jobSnap = await db().collection("video_jobs").doc("job_lf_block").get();
    expect(jobSnap.data()?.dubbingStatus?.te?.reason).toBe("translation_gate_blocked");

    const chSnap = await db().collection("channels").doc("ch_lf").get();
    expect(chSnap.data()?.walletBalanceUSD).toBe(65); // 50 + 15 refunded
  });

  test("R2 & R7: resolveScreenContextForTranslation handles timeout cleanly without mutating original segments", async () => {
    const screenMod = require("../../src/pipeline/services/screenContentAnalyzer");
    jest.spyOn(screenMod, "getScreenContent").mockResolvedValue({
      songIntervalsMs: [{ startMs: 0, endMs: 4000 }],
      onScreenText: [{ startMs: 1000, endMs: 3000, text: "SIGN", language: "en" }],
      shotChangesMs: [2200],
    });
    const origSegs = [{ index: 0, start: 0, end: 3000, duration: 3000, text: "La la la", speaker: "speaker_0" }];
    const ctx = await (dubbingEngine as any).resolveScreenContextForTranslation("job_sc", "gs://b/v.mp4", 10000, origSegs);
    expect(ctx.shotChangesMs).toEqual([2200]);
    expect(ctx.onScreenText).toHaveLength(1);
    expect(ctx.segments[0].isSong).toBe(true);
    expect((origSegs[0] as any).isSong).toBeUndefined();
  });
});
