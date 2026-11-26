/**
 * Resolution service access rules (audit 2026-11-20, findings C1 and C4).
 *
 * C1: only the video's own source upload, by its owner or an admin, may start
 *     the resolution pipeline (blocks replacing another creator's video).
 * C4: private / draft videos' resolution status and stream URLs are visible
 *     only to the owner and admins, and internal fields never leave the backend.
 */

import * as fs from "fs";
import * as path from "path";
import {
  evaluateUploadOwnership,
  isSourceUploadPath,
  canViewResolution,
  toPublicVariants,
  getVideoOwnerId,
  isPrivateVisibility,
} from "../../src/resolution/resolutionAccess";

const VIDEO_ID = "3f2b8c1e-9a4d-4e7b-8c21-5d6e7f8a9b0c";
const OWNER = "owner_uid";
const ATTACKER = "attacker_uid";

const ownedVideo = (extra: Record<string, any> = {}) => ({
  id: VIDEO_ID,
  ownerId: OWNER,
  userId: OWNER,
  visibility: "public",
  storage: { videoPath: `videos/${VIDEO_ID}/original.mp4` },
  ...extra,
});

describe("C1: evaluateUploadOwnership", () => {
  it("allows the owner's source upload and returns the verified owner", () => {
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/original.mp4`,
      videoId: VIDEO_ID,
      uploaderId: OWNER,
      videoData: ownedVideo(),
      uploaderIsAdmin: false,
    });
    expect(decision).toEqual({ allowed: true, ownerId: OWNER });
  });

  it("rejects a new file uploaded under someone else's video id (the hijack)", () => {
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/original.mp4`,
      videoId: VIDEO_ID,
      uploaderId: ATTACKER,
      videoData: ownedVideo(),
      uploaderIsAdmin: false,
    });
    expect(decision.allowed).toBe(false);
    expect(decision.reason).toBe("uploader_not_owner");
  });

  it("rejects an attacker's extra file even with a plausible name", () => {
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/x.mp4`,
      videoId: VIDEO_ID,
      uploaderId: ATTACKER,
      videoData: ownedVideo(),
      uploaderIsAdmin: false,
    });
    expect(decision.allowed).toBe(false);
  });

  it("rejects uploads with no uploaderId metadata", () => {
    for (const uploaderId of [undefined, null, "", "   "]) {
      const decision = evaluateUploadOwnership({
        filePath: `videos/${VIDEO_ID}/original.mp4`,
        videoId: VIDEO_ID,
        uploaderId,
        videoData: ownedVideo(),
        uploaderIsAdmin: false,
      });
      expect(decision).toEqual({ allowed: false, reason: "uploader_missing" });
    }
  });

  it("ignores spoofable userId / ownerId metadata: only uploaderId counts", () => {
    // The old trigger trusted metadata.userId; the caller now passes uploaderId only.
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/original.mp4`,
      videoId: VIDEO_ID,
      uploaderId: ATTACKER,
      videoData: ownedVideo(),
      uploaderIsAdmin: false,
    });
    expect(decision.allowed).toBe(false);
  });

  it("rejects uploads for a video with no Firestore doc", () => {
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/original.mp4`,
      videoId: VIDEO_ID,
      uploaderId: OWNER,
      videoData: null,
      uploaderIsAdmin: false,
    });
    expect(decision).toEqual({ allowed: false, reason: "video_doc_missing" });
  });

  it("rejects when the video doc has no owner field", () => {
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/original.mp4`,
      videoId: VIDEO_ID,
      uploaderId: OWNER,
      videoData: { visibility: "public" },
      uploaderIsAdmin: false,
    });
    expect(decision).toEqual({ allowed: false, reason: "owner_missing" });
  });

  it("lets an admin re-upload the source file and keeps the real owner", () => {
    const decision = evaluateUploadOwnership({
      filePath: `videos/${VIDEO_ID}/original.mp4`,
      videoId: VIDEO_ID,
      uploaderId: "admin_uid",
      videoData: ownedVideo(),
      uploaderIsAdmin: true,
    });
    expect(decision).toEqual({ allowed: true, ownerId: OWNER });
  });

  it("does not start the pipeline for the owner's non-source files", () => {
    // voice_sample.mp3 (upload flow) and <lang>-dubbed.mp4 (media.ts) live under
    // videos/{id}/ too and used to restart the whole resolution job.
    for (const file of ["voice_sample.mp3", "te-dubbed.mp4", "720p.mp4", "original.mp4.bak"]) {
      const decision = evaluateUploadOwnership({
        filePath: `videos/${VIDEO_ID}/${file}`,
        videoId: VIDEO_ID,
        uploaderId: OWNER,
        videoData: ownedVideo(),
        uploaderIsAdmin: false,
      });
      expect(decision).toEqual({ allowed: false, reason: "not_source_file" });
    }
  });
});

describe("C1: isSourceUploadPath", () => {
  it("uses storage.videoPath when the doc has one", () => {
    const data = ownedVideo({ storage: { videoPath: `videos/${VIDEO_ID}/master.mov` } });
    expect(isSourceUploadPath(`videos/${VIDEO_ID}/master.mov`, VIDEO_ID, data)).toBe(true);
    expect(isSourceUploadPath(`videos/${VIDEO_ID}/original.mp4`, VIDEO_ID, data)).toBe(false);
  });

  it("falls back to original.<ext> when storage.videoPath is missing", () => {
    const data = { ownerId: OWNER };
    expect(isSourceUploadPath(`videos/${VIDEO_ID}/original.mp4`, VIDEO_ID, data)).toBe(true);
    expect(isSourceUploadPath(`videos/${VIDEO_ID}/original.MOV`, VIDEO_ID, data)).toBe(true);
    expect(isSourceUploadPath(`videos/${VIDEO_ID}/clip.mp4`, VIDEO_ID, data)).toBe(false);
  });

  it("ignores a storage.videoPath that points at another video", () => {
    const data = { ownerId: OWNER, storage: { videoPath: "videos/other-video/original.mp4" } };
    expect(isSourceUploadPath("videos/other-video/original.mp4", VIDEO_ID, data)).toBe(false);
    expect(isSourceUploadPath(`videos/${VIDEO_ID}/original.mp4`, VIDEO_ID, data)).toBe(true);
  });
});

describe("C4: canViewResolution", () => {
  it("lets anyone see public and unlisted videos", () => {
    expect(canViewResolution({ videoData: ownedVideo({ visibility: "public" }) })).toBe(true);
    expect(canViewResolution({ videoData: ownedVideo({ visibility: "unlisted" }) })).toBe(true);
    expect(canViewResolution({ videoData: ownedVideo({ visibility: undefined }) })).toBe(true);
  });

  it("hides private and draft videos from anonymous users and strangers", () => {
    for (const visibility of ["private", "Private", "draft", "private_draft", "PRIVATE"]) {
      const videoData = ownedVideo({ visibility });
      expect(canViewResolution({ videoData })).toBe(false);
      expect(canViewResolution({ videoData, requesterUid: ATTACKER })).toBe(false);
    }
  });

  it("shows private videos to the owner and to admins", () => {
    const videoData = ownedVideo({ visibility: "private" });
    expect(canViewResolution({ videoData, requesterUid: OWNER })).toBe(true);
    expect(canViewResolution({ videoData, requesterUid: "admin_uid", requesterIsAdmin: true })).toBe(true);
  });

  it("denies non-admins when the video doc is missing", () => {
    expect(canViewResolution({ videoData: null, requesterUid: OWNER })).toBe(false);
    expect(canViewResolution({ videoData: null, requesterIsAdmin: true })).toBe(true);
  });
});

describe("C4: toPublicVariants", () => {
  it("drops storage paths and raw error text but keeps playback fields", () => {
    const result = toPublicVariants({
      "720p": {
        label: "720p",
        height: 720,
        width: 1280,
        bitrateKbps: 2500,
        audioBitrateKbps: 192,
        fps: 30,
        status: "completed",
        downloadUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/resolutions%2Fv%2F720p.mp4?alt=media&token=t",
        outputPath: "resolutions/v/720p.mp4",
        error: "ffmpeg exited with code 1: /tmp/res_v_abc/original.mp4: Invalid data",
        processedAt: 1,
      },
    });
    expect(result["720p"]).toEqual({
      label: "720p",
      height: 720,
      width: 1280,
      bitrateKbps: 2500,
      audioBitrateKbps: 192,
      fps: 30,
      status: "completed",
      downloadUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/resolutions%2Fv%2F720p.mp4?alt=media&token=t",
      processedAt: 1,
    });
  });

  it("handles missing or malformed variants", () => {
    expect(toPublicVariants(undefined)).toEqual({});
    expect(toPublicVariants({ bad: null, "144p": "x" } as any)).toEqual({});
  });
});

describe("helpers", () => {
  it("getVideoOwnerId prefers ownerId, then userId, then uploaderId", () => {
    expect(getVideoOwnerId({ ownerId: "a", userId: "b" })).toBe("a");
    expect(getVideoOwnerId({ userId: "b", uploaderId: "c" })).toBe("b");
    expect(getVideoOwnerId({ uploaderId: "c" })).toBe("c");
    expect(getVideoOwnerId({ ownerId: "" })).toBe("");
    expect(getVideoOwnerId(null)).toBe("");
  });

  it("isPrivateVisibility matches the Firestore rules list", () => {
    expect(isPrivateVisibility("private_draft")).toBe(true);
    expect(isPrivateVisibility("unlisted")).toBe(false);
    expect(isPrivateVisibility(null)).toBe(false);
  });
});

describe("Wiring in resolution.ts and the rules files", () => {
  const root = path.resolve(__dirname, "../..");
  const resolutionSrc = fs.readFileSync(path.join(root, "src/resolution/resolution.ts"), "utf8");
  const firestoreRules = fs.readFileSync(path.join(root, "../firestore.rules"), "utf8");
  const storageRules = fs.readFileSync(path.join(root, "../storage.rules"), "utf8");

  it("the upload trigger runs the ownership gate and no longer trusts metadata.userId", () => {
    expect(resolutionSrc).toContain("evaluateUploadOwnership({");
    expect(resolutionSrc).not.toContain('storageMetadata.userId || storageMetadata.ownerId || "system_automated"');
  });

  it("the public status endpoint checks access and no longer reconciles", () => {
    const start = resolutionSrc.indexOf("export const getVideoResolutionStatus");
    const end = resolutionSrc.indexOf("export const getResolutionProfiles");
    const endpoint = resolutionSrc.slice(start, end);
    expect(endpoint).toContain("canViewResolution(");
    expect(endpoint).toContain("toPublicVariants(");
    expect(endpoint).not.toContain("await reconcileResolutionJob(");
  });

  it("resolution_jobs can't be listed or read by anyone for private videos", () => {
    const block = firestoreRules.slice(firestoreRules.indexOf("match /resolution_jobs/{jobId}"));
    const body = block.slice(0, block.indexOf("\n    }"));
    expect(body).not.toMatch(/allow read:\s*if true/);
    expect(body).toContain("allow list: if isAdmin()");
  });

  it("storage ties videos/{videoId} writes and resolutions/ reads to the Firestore video", () => {
    expect(storageRules).toContain("isFirestoreVideoOwner(videoId)");
    const res = storageRules.slice(storageRules.indexOf("match /resolutions/{videoId}/{allPaths=**}"));
    expect(res.slice(0, res.indexOf("\n    }"))).not.toMatch(/allow read:\s*if true/);
  });
});
