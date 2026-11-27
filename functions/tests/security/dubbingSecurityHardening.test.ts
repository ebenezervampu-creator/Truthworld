import * as fs from "fs";
import * as path from "path";

const mockManifestUpdate = jest.fn();
const mockManifestData: Record<string, any> = {
  jobId: "dubjob_sec_1",
  language: "te",
  sourceLanguage: "en",
  totalDurationMs: 15000,
  regenerationCount: 0,
  retranslationCount: 0,
  remasterCount: 0,
  segmentRegenerationCounts: {},
  segments: [
    {
      index: 0,
      speaker: "speaker_0",
      startMs: 0,
      endMs: 3000,
      originalText: "Hello world",
      translatedText: "హలో వరల్డ్",
    },
  ],
};

jest.mock("firebase-admin", () => {
  const docSnap = (exists: boolean, data?: any) => ({
    exists,
    data: () => data,
  });

  const makeDocRef = (col: string, id: string): any => ({
    id,
    path: `${col}/${id}`,
    get: jest.fn(async () => {
      if (col === "video_jobs") {
        return docSnap(true, {
          jobId: id,
          userId: "user_1",
          sourceLanguage: "en",
          executionPlan: { dubbingMode: "standard" },
        });
      }
      if (col.endsWith("dubbing_manifests")) {
        return docSnap(true, mockManifestData);
      }
      return docSnap(false);
    }),
    update: jest.fn(async (patch: Record<string, any>) => {
      mockManifestUpdate(patch);
      Object.assign(mockManifestData, patch);
    }),
    collection: (sub: string) => makeCollectionRef(`${col}/${id}/${sub}`),
  });

  const makeCollectionRef = (col: string) => ({
    doc: (id: string) => makeDocRef(col, id),
  });

  const firestoreFn: any = () => ({
    collection: (name: string) => makeCollectionRef(name),
    runTransaction: async (fn: (tx: any) => Promise<any>) => {
      const tx = {
        get: async (ref: any) => ref.get(),
        update: (ref: any, patch: any) => {
          mockManifestUpdate(patch);
          for (const [k, v] of Object.entries(patch)) {
            if (k.startsWith("segmentRegenerationCounts.")) {
              const segKey = k.split(".")[1];
              mockManifestData.segmentRegenerationCounts = {
                ...(mockManifestData.segmentRegenerationCounts || {}),
                [segKey]: v,
              };
            } else {
              mockManifestData[k] = v;
            }
          }
        },
      };
      return fn(tx);
    },
  });

  return {
    apps: [{}],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
    storage: () => ({ bucket: () => ({ name: "truthworld-1.firebasestorage.app" }) }),
  };
});

import { dubbingEditorService } from "../../src/pipeline/services/dubbingEditorService";

describe("Dubbing Studio Security & Anti-Abuse Hardening", () => {
  beforeEach(() => {
    mockManifestUpdate.mockClear();
    mockManifestData.regenerationCount = 0;
    mockManifestData.retranslationCount = 0;
    mockManifestData.remasterCount = 0;
    mockManifestData.segmentRegenerationCounts = {};
  });

  it("rejects oversized editedText (> 3x originalText, min 120 chars) in updateSegmentAndResynthesize", async () => {
    await expect(
      dubbingEditorService.updateSegmentAndResynthesize({
        jobId: "dubjob_sec_1",
        language: "te",
        segmentIndex: 0,
        uid: "user_1",
        isAdmin: false,
        editedText: "A".repeat(121),
      })
    ).rejects.toThrow(/too long/i);
  });

  it("enforces per-segment regeneration cap (5) and per-manifest cap (50)", async () => {
    mockManifestData.segmentRegenerationCounts = { "0": 5 };
    await expect(
      dubbingEditorService.updateSegmentAndResynthesize({
        jobId: "dubjob_sec_1",
        language: "te",
        segmentIndex: 0,
        uid: "user_1",
        isAdmin: false,
        editedText: "Hi",
      })
    ).rejects.toThrow(/Maximum regenerations \(5\)/i);

    mockManifestData.segmentRegenerationCounts = { "0": 0 };
    mockManifestData.regenerationCount = 50;
    await expect(
      dubbingEditorService.updateSegmentAndResynthesize({
        jobId: "dubjob_sec_1",
        language: "te",
        segmentIndex: 0,
        uid: "user_1",
        isAdmin: false,
        editedText: "Hi",
      })
    ).rejects.toThrow(/Maximum line regenerations \(50\)/i);
  });

  it("enforces retranslation cap (50) and remaster cap (10)", async () => {
    mockManifestData.retranslationCount = 50;
    await expect(
      dubbingEditorService.retranslateSegment({
        jobId: "dubjob_sec_1",
        language: "te",
        segmentIndex: 0,
        uid: "user_1",
        isAdmin: false,
      })
    ).rejects.toThrow(/Maximum AI retranslations \(50\)/i);

    mockManifestData.remasterCount = 10;
    await expect(
      dubbingEditorService.remasterTrack({
        jobId: "dubjob_sec_1",
        language: "te",
        uid: "user_1",
        isAdmin: false,
      })
    ).rejects.toThrow(/Maximum audio remasters \(10\)/i);
  });

  it("verifies path ownership, atomic approveForTTS, and generateDubbedVideo guards in source", () => {
    const standaloneSrc = fs.readFileSync(
      path.resolve(__dirname, "../../src/dubbing/standaloneDubbing.ts"),
      "utf8"
    );
    const triggersSrc = fs.readFileSync(
      path.resolve(__dirname, "../../src/pipeline/pipelineTriggers.ts"),
      "utf8"
    );

    expect(standaloneSrc).toContain("info.filePath.startsWith(`dubbing_uploads/${uid}/`)");
    expect(standaloneSrc).toContain('liveData.status !== "awaiting_transcription_review"');
    expect(triggersSrc).toContain("dubbing_video_mux_limits");
    expect(triggersSrc).toContain("isPrivateOrDraft && !isOwner && !isAdmin");
  });
});
