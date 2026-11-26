import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import {
  isVideoId,
  assertVideoId,
  filterVideoIds,
  safeMergeExistingVideo,
  safeMergeExistingVideoSubdoc,
  filterExistingVideoIds,
} from "../../src/utils/videosCollectionGuard";

describe("Videos Collection Guard — Only Real User Uploads May Create Documents", () => {
  const VALID_UUID = "21082fbb-13f1-4a5b-871c-ef87b6907d33";
  const NON_VIDEO_IDS = [
    "tw_dubbing_stt_af_1795196400575",
    "sample_test_en_1795195653914",
    "real_test_telugu_1795267493288",
    "vid_1795195653914_abc123",
    "dubjob_1795195653914_abc123",
    "job_1795088574352_07d15143",
    "localdub_te_1795195653914",
    "",
    null,
    undefined,
  ];

  describe("UUID v4 validation", () => {
    it("accepts genuine UUID v4 video IDs and rejects all job/test/dubbing prefixes", () => {
      expect(isVideoId(VALID_UUID)).toBe(true);
      expect(() => assertVideoId(VALID_UUID)).not.toThrow();

      for (const badId of NON_VIDEO_IDS) {
        expect(isVideoId(badId as any)).toBe(false);
        expect(() => assertVideoId(badId as any)).toThrow();
      }

      const filtered = filterVideoIds([VALID_UUID, ...(NON_VIDEO_IDS.filter(Boolean) as string[])]);
      expect(filtered).toEqual([VALID_UUID]);
    });
  });

  describe("Non-creating Firestore merge helpers", () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    function mockFirestoreWithExistingIds(existingIds: Set<string>) {
      const txSetCalls: Array<{ path: string; data: any; options: any }> = [];

      const makeDocRef = (colPath: string, docId: string): any => ({
        id: docId,
        path: `${colPath}/${docId}`,
        get: jest.fn(async () => ({
          id: docId,
          exists: colPath === "videos" && existingIds.has(docId),
        })),
        set: jest.fn(async (data: any, options: any) => {
          txSetCalls.push({ path: `${colPath}/${docId}`, data, options });
        }),
        collection: (sub: string) => ({
          doc: (subId: string) => makeDocRef(`${colPath}/${docId}/${sub}`, subId),
        }),
      });

      const fakeDb: any = {
        collection: (name: string) => ({
          doc: (id: string) => makeDocRef(name, id),
        }),
        getAll: jest.fn(async (...refs: any[]) =>
          refs.map((r) => ({ id: r.id, exists: existingIds.has(r.id) }))
        ),
        runTransaction: jest.fn(async (fn: any) => {
          const tx = {
            get: async (ref: any) => ref.get(),
            set: (ref: any, data: any, options: any) => {
              txSetCalls.push({ path: ref.path, data, options });
            },
          };
          return fn(tx);
        }),
      };

      jest.spyOn(admin, "firestore").mockReturnValue(fakeDb);
      return { fakeDb, txSetCalls };
    }

    it("refuses to create a new videos doc when ID is non-UUID or does not exist", async () => {
      const { fakeDb, txSetCalls } = mockFirestoreWithExistingIds(new Set([VALID_UUID]));

      // 1. Non-UUID IDs never even touch Firestore
      for (const badId of ["tw_dubbing_stt_en_1795", "sample_test_en_1795", "vid_123_abc", "job_123"]) {
        const res = await safeMergeExistingVideo(badId, { status: "published" });
        expect(res).toBe(false);
      }
      expect(fakeDb.runTransaction).not.toHaveBeenCalled();

      // 2. Valid UUID that does not exist in `videos` must NOT be created
      const missingUuid = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
      const missingRes = await safeMergeExistingVideo(missingUuid, { status: "published" });
      expect(missingRes).toBe(false);
      expect(txSetCalls).toHaveLength(0);

      // 3. Existing UUID IS updated with { merge: true }
      const okRes = await safeMergeExistingVideo(VALID_UUID, { language: "en" });
      expect(okRes).toBe(true);
      expect(txSetCalls).toEqual([
        { path: `videos/${VALID_UUID}`, data: { language: "en" }, options: { merge: true } },
      ]);
    });

    it("refuses subcollection writes when parent videos doc does not exist (no phantom docs)", async () => {
      const { txSetCalls } = mockFirestoreWithExistingIds(new Set([VALID_UUID]));
      const missingUuid = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

      const badRes = await safeMergeExistingVideoSubdoc(
        "tw_dubbing_stt_te_1795",
        "media",
        "localization",
        { audioTracks: { te: "https://example.com/a.mp3" } }
      );
      expect(badRes).toBe(false);

      const missingParentRes = await safeMergeExistingVideoSubdoc(
        missingUuid,
        "media",
        "localization",
        { audioTracks: { te: "https://example.com/a.mp3" } }
      );
      expect(missingParentRes).toBe(false);
      expect(txSetCalls).toHaveLength(0);

      const okRes = await safeMergeExistingVideoSubdoc(
        VALID_UUID,
        "media",
        "localization",
        { audioTracks: { te: "https://example.com/a.mp3" } }
      );
      expect(okRes).toBe(true);
      expect(txSetCalls).toHaveLength(1);
      expect(txSetCalls[0].path).toBe(`videos/${VALID_UUID}/media/localization`);
    });

    it("filterExistingVideoIds keeps only valid UUIDs that exist in Firestore", async () => {
      mockFirestoreWithExistingIds(new Set([VALID_UUID]));
      const missingUuid = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

      const out = await filterExistingVideoIds([
        "tw_dubbing_stt_en_1795",
        missingUuid,
        VALID_UUID,
        VALID_UUID,
        "vid_123_abc",
      ]);
      expect(out).toEqual([VALID_UUID]);
    });
  });

  describe("Source scan: zero unguarded direct collection('videos').doc(...).set() in backend writers", () => {
    const rootSrc = path.resolve(__dirname, "../../src");
    const filesToCheck = [
      "dubbing/standaloneDubbing.ts",
      "pipeline/layers/05-transcription.ts",
      "pipeline/layers/06-credibility.ts",
      "pipeline/layers/07-dubbing.ts",
      "pipeline/layers/09-aggregation.ts",
      "pipeline/pipelineTriggers.ts",
      "pipeline/services/dubbingEditorService.ts",
      "pipeline/services/hlsPackager.ts",
      "pipeline/services/fastMultimodalTriageService.ts",
      "pipeline/services/sourceHealingService.ts",
      "seo/indexing/searchMetadata.ts",
      "publishing/videoPublishTrigger.ts",
    ];

    it.each(filesToCheck)("%s has no direct collection('videos').doc(...).set() calls", (relPath) => {
      const content = fs.readFileSync(path.join(rootSrc, relPath), "utf8");
      const directSetCalls = content.match(/\.collection\(["']videos["']\)\.doc\([^)]*\)\s*\.set\s*\(/g) || [];
      expect(directSetCalls).toEqual([]);
    });

    it("standaloneDubbing.ts does not synthesize vid_ documents in videos", () => {
      const content = fs.readFileSync(path.join(rootSrc, "dubbing/standaloneDubbing.ts"), "utf8");
      expect(content).not.toMatch(/`vid_\$\{Date\.now\(\)\}/);
    });
  });
});
