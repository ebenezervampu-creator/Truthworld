import * as fs from "fs";
import * as path from "path";
import { computeStudioJobUpdate } from "../../src/dubbing/studio-job-sync";
import { refundDubbingFeeOnFailure, DUBBING_ORDERS } from "../../src/pipeline/services/refundService";
import { isVideoId } from "../../src/utils/videosCollectionGuard";

const mockDocs = new Map<string, Record<string, any>>();

jest.mock("firebase-admin", () => {
  const FieldValue = {
    serverTimestamp: jest.fn(() => "SERVER_TS"),
    increment: jest.fn((n: number) => ({ __inc: n })),
    arrayUnion: jest.fn((...items: any[]) => ({ __union: items })),
  };

  const makeDocRef = (col: string, id: string): any => {
    const key = `${col}/${id}`;
    return {
      id,
      path: key,
      get: jest.fn(async () => ({
        exists: mockDocs.has(key),
        id,
        data: () => (mockDocs.has(key) ? { ...mockDocs.get(key) } : undefined),
      })),
      set: jest.fn(async (data: any, opts?: { merge?: boolean }) => {
        if (opts?.merge && mockDocs.has(key)) {
          mockDocs.set(key, { ...mockDocs.get(key), ...data });
        } else {
          mockDocs.set(key, { ...data });
        }
      }),
      create: jest.fn(async (data: any) => {
        if (mockDocs.has(key)) throw new Error("Already exists");
        mockDocs.set(key, { ...data });
      }),
      update: jest.fn(async (data: any) => {
        const cur = mockDocs.get(key) || {};
        mockDocs.set(key, { ...cur, ...data });
      }),
    };
  };

  const firestoreFn: any = jest.fn(() => ({
    collection: jest.fn((col: string) => ({
      doc: jest.fn((id: string) => makeDocRef(col, id)),
    })),
    runTransaction: jest.fn(async (cb: (tx: any) => Promise<any>) => {
      const tx = {
        get: jest.fn((ref: any) => ref.get()),
        set: jest.fn((ref: any, data: any, opts?: any) => ref.set(data, opts)),
        update: jest.fn((ref: any, data: any) => ref.update(data)),
      };
      return await cb(tx);
    }),
  }));

  firestoreFn.FieldValue = FieldValue;

  return {
    apps: [{}],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
    storage: jest.fn(() => ({ bucket: () => ({ name: "truthworld-1.firebasestorage.app" }) })),
  };
});

describe("Dubbing Studio Controls & Personal USD Wallet", () => {
  beforeEach(() => {
    mockDocs.clear();
  });

  it("refunds failed languages to personal dubbing_wallets/{uid}.balanceUsd when walletSource is personal", async () => {
    const uid = "user_personal_1";
    const jobId = "dubjob_test_1";
    const orderId = "ord_personal_1";

    mockDocs.set(`dubbing_wallets/${uid}`, {
      userId: uid,
      balanceUsd: 4.0,
      transactions: [],
    });
    mockDocs.set(`video_jobs/${jobId}`, {
      jobId,
      userId: uid,
      currentDubbingOrderId: orderId,
    });
    mockDocs.set(`${DUBBING_ORDERS}/${orderId}`, {
      orderId,
      jobId,
      videoId: jobId,
      userId: uid,
      channelId: "",
      walletSource: "personal",
      paidUSD: 1.2,
      dubbingUSD: 1.2,
      subtitleUSD: 0,
      languages: ["te", "hi"],
      priceByLanguage: { te: 0.6, hi: 0.6 },
      refundedByLanguage: {},
      refundedUSD: 0,
      createdAt: Date.now(),
      source: "DubbingStudio",
    });

    const res = await refundDubbingFeeOnFailure({
      jobId,
      userId: uid,
      failedLanguages: ["hi"],
      totalLanguages: ["te", "hi"],
      reason: "TTS provider timeout",
      orderId,
    });

    expect(res.refunded).toBe(true);
    expect(res.refundAmountUSD).toBe(0.6);

    const updatedWallet = mockDocs.get(`dubbing_wallets/${uid}`);
    expect(updatedWallet?.balanceUsd).toBe(4.6);
    expect(Array.isArray(updatedWallet?.transactions)).toBe(true);
    expect(updatedWallet?.transactions[0]?.type).toBe("refund");
    expect(updatedWallet?.transactions[0]?.amountUsd).toBe(0.6);
  });

  it("computeStudioJobUpdate preserves awaiting_transcription_review and syncs pending review segments", () => {
    const patch = computeStudioJobUpdate(
      {
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "awaiting_transcription_review", progress: 45 },
        },
        pendingReviewSegmentsByLanguage: {
          te: [
            {
              id: "seg_1",
              speakerId: "speaker_1",
              startTimeMs: 0,
              endTimeMs: 2500,
              originalText: "Hello world",
              translatedText: "హలో వరల్డ్",
              targetLanguage: "te",
              status: "pending",
              speedMultiplier: 1.0,
            },
          ],
        },
      },
      {
        mode: "dubbing",
        targetLanguages: ["te"],
        progressPercent: 35,
      }
    );

    expect(patch.status).toBe("awaiting_transcription_review");
    expect(patch.progressPercent).toBeGreaterThanOrEqual(45);
    expect(patch.segmentsByLanguage?.te).toHaveLength(1);
    expect(patch.segmentsByLanguage?.te[0].translatedText).toBe("హలో వరల్డ్");
  });

  it("studio-publisher creates only RFC-4122 UUID v4 documents in videos", async () => {
    const { publishCompletedStudioJobToTruthworld } = require("../../src/dubbing/studio-publisher");
    const uid = "creator_1";
    const channelId = "chan_1";
    const pipelineJobId = "dubjob_pub_1";
    const studioJobId = "dub_pub_1";

    mockDocs.set(`channels/${channelId}`, {
      id: channelId,
      ownerId: uid,
      name: "Truth Channel",
      image: "https://cdn.example.com/avatar.png",
    });
    mockDocs.set(`video_jobs/${pipelineJobId}`, { jobId: pipelineJobId, userId: uid });
    mockDocs.set(`studio_dubbing_jobs/${studioJobId}`, { id: studioJobId, userId: uid });

    const createdVideoId = await publishCompletedStudioJobToTruthworld({
      pipelineJobId,
      studioJobId,
      userId: uid,
      channelId,
      title: "My Dubbed Video",
      durationSeconds: 95,
      sourceLanguage: "en",
      sourceMediaUrl: "https://storage.googleapis.com/truthworld-1.firebasestorage.app/dubbing_uploads/creator_1/src.mp4",
      dubbedPaths: {
        te: "gs://truthworld-1.firebasestorage.app/videos/dubjob_pub_1/te-dubbed.mp4",
      },
      audioPaths: {
        te: "gs://truthworld-1.firebasestorage.app/audio/dubjob_pub_1/te/master.mp3",
      },
      subtitlePaths: {
        te: "gs://truthworld-1.firebasestorage.app/subtitles/dubjob_pub_1/te.srt",
      },
    });

    expect(createdVideoId).toBeTruthy();
    expect(isVideoId(createdVideoId)).toBe(true);
    const savedVideo = mockDocs.get(`videos/${createdVideoId}`);
    expect(savedVideo?.id).toBe(createdVideoId);
    expect(savedVideo?.channelId).toBe(channelId);
    expect(savedVideo?.source).toBe("dubbing_studio");
    expect(mockDocs.get(`studio_dubbing_jobs/${studioJobId}`)?.videoId).toBe(createdVideoId);
  });

  it("declares required secrets and standalone wiring across standaloneDubbing, cashfreeFunctions, and pipelineTriggers", () => {
    const standaloneSrc = fs.readFileSync(
      path.resolve(__dirname, "../../src/dubbing/standaloneDubbing.ts"),
      "utf8"
    );
    const cashfreeSrc = fs.readFileSync(
      path.resolve(__dirname, "../../src/economy/cashfreeFunctions.ts"),
      "utf8"
    );
    const triggersSrc = fs.readFileSync(
      path.resolve(__dirname, "../../src/pipeline/pipelineTriggers.ts"),
      "utf8"
    );

    expect(cashfreeSrc).toContain('"dubbing_wallet_topup"');
    expect(cashfreeSrc).toContain("dubbing_wallet_transactions");
    expect(standaloneSrc).toMatch(/export const regenerateDubbingSegment[\s\S]*?secrets:\s*\["ELEVENLABS_API_KEY"\]/);
    expect(standaloneSrc).toMatch(/export const exportDubbingAssets[\s\S]*?secrets:\s*\["ELEVENLABS_API_KEY",\s*"DEMUX_WORKER_TOKEN"\]/);
    expect(triggersSrc).toMatch(/export const retranslateDubbingSegment[\s\S]*?secrets:\s*\["GOOGLE_TRANSLATION_API_KEY"\]/);
    expect(triggersSrc).toMatch(/export const getDubbingExportPackage[\s\S]*?secrets:\s*\["ELEVENLABS_API_KEY",\s*"DEMUX_WORKER_TOKEN"\]/);
    expect(standaloneSrc).toContain("twoStageReviewEnabled:");
    expect(standaloneSrc).toContain("speakerOverrides");
    expect(standaloneSrc).toContain("demuxOptions: sanitizedDemuxOptions");
    expect(standaloneSrc).toContain("consumedByJobId");
  });
});
