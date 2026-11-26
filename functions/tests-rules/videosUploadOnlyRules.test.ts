/**
 * Security rules tests for hardening videos/{videoId} creation & preventing phantom parents.
 *
 * Verifies:
 * 1. Top-level videos/{videoId} create only permits real user video uploads:
 *    - strict UUID v4 videoId (even admins cannot create non-UUID docs)
 *    - id == videoId, ownerId == uid, userId == uid, non-empty title
 *    - status in ['uploading', 'draft', 'scheduled', 'published']
 *    - optional storage.videoPath == 'videos/' + videoId + '/original.mp4'
 *    - zeroed metrics & no spoofable server fields
 * 2. All writable subcollections under videos/{videoId} require the parent document to exist
 *    (even for admins), preventing phantom parent documents.
 * 3. Existing reads, updates, and deletes on videos/{videoId} remain backward-compatible.
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs } from "firebase/firestore";

const OWNER_UID = "upload_owner_123";
const OTHER_UID = "other_user_456";
const ADMIN_UID = "admin_user_789";

const VALID_UUID_1 = "11111111-2222-4333-8444-555555555555";
const VALID_UUID_2 = "aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee";
const PHANTOM_UUID = "99999999-8888-4777-a666-555555555555";
const EXISTING_LEGACY_ID = "legacy_existing_video_001";

let env: RulesTestEnvironment;

beforeAll(async () => {
  const root = path.resolve(__dirname, "../..");
  env = await initializeTestEnvironment({
    projectId: "demo-truthworld",
    firestore: { rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8") },
  });
});

afterAll(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "videos", EXISTING_LEGACY_ID), {
      id: EXISTING_LEGACY_ID,
      ownerId: OWNER_UID,
      userId: OWNER_UID,
      title: "Legacy Video",
      description: "Existing doc",
      visibility: "public",
      status: "published",
      likeCount: 0,
    });
  });
});

function validPipelineUploadPayload(videoId: string, uid: string) {
  return {
    id: videoId,
    ownerId: uid,
    userId: uid,
    channelId: uid,
    status: "uploading",
    title: "Uploading...",
    description: "Processing...",
    videoUrl: "",
    thumbnailUrl: "",
    likes: 0,
    likeCount: 0,
    dislikes: 0,
    dislikeCount: 0,
    views: 0,
    viewCount: 0,
    shareCount: 0,
    downloads: 0,
    reportCount: 0,
    isBlocked: false,
    visibility: "Public",
    tags: [],
    storage: { videoPath: `videos/${videoId}/original.mp4` },
  };
}

describe("videos/{videoId} create hardening (real user uploads only)", () => {
  it("allows valid initial upload from upload_pipeline_mixin", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(
      setDoc(doc(db, "videos", VALID_UUID_1), validPipelineUploadPayload(VALID_UUID_1, OWNER_UID))
    );
  });

  it("allows valid draft/submission fallback from upload_submission_mixin", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    for (const status of ["uploading", "draft", "scheduled", "published"]) {
      const id = status === "draft" ? VALID_UUID_1 : VALID_UUID_2;
      await env.withSecurityRulesDisabled(async (ctx) => {
        await deleteDoc(doc(ctx.firestore(), "videos", id));
      });
      await assertSucceeds(
        setDoc(doc(db, "videos", id), {
          id,
          ownerId: OWNER_UID,
          userId: OWNER_UID,
          title: `Submission ${status}`,
          description: "Valid description",
          status,
          likes: 0,
          likeCount: 0,
          dislikes: 0,
          dislikeCount: 0,
          views: 0,
          viewCount: 0,
          shareCount: 0,
        })
      );
    }
  });

  it("blocks non-UUID v4 document IDs even for admins", async () => {
    const ownerDb = env.authenticatedContext(OWNER_UID).firestore();
    const adminDb = env.authenticatedContext(ADMIN_UID, { admin: true, email_verified: true }).firestore();

    const badIds = [
      "job_12345",
      "vid_12345",
      "tw_dubbing_stt_abc",
      "sample_test_001",
      "real_test_001",
      "11111111-2222-1333-8444-555555555555", // UUID v1 (not v4)
      "11111111-2222-4333-0444-555555555555", // invalid variant nibble
    ];

    for (const badId of badIds) {
      await assertFails(setDoc(doc(ownerDb, "videos", badId), validPipelineUploadPayload(badId, OWNER_UID)));
      await assertFails(setDoc(doc(adminDb, "videos", badId), validPipelineUploadPayload(badId, ADMIN_UID)));
    }
  });

  it("blocks missing/mismatched id, ownerId, userId, or uploaderId", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();

    const base = validPipelineUploadPayload(VALID_UUID_1, OWNER_UID);
    const { id: _dropId, ...noId } = base;
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), noId));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, id: VALID_UUID_2 }));

    const { ownerId: _dropOwner, ...noOwner } = base;
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), noOwner));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, ownerId: OTHER_UID }));

    const { userId: _dropUser, ...noUser } = base;
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), noUser));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, userId: OTHER_UID }));

    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, uploaderId: OTHER_UID }));
  });

  it("blocks admin creating a video doc on behalf of another user or without valid title", async () => {
    const adminDb = env.authenticatedContext(ADMIN_UID, { admin: true, email_verified: true }).firestore();
    await assertFails(
      setDoc(doc(adminDb, "videos", VALID_UUID_1), {
        id: VALID_UUID_1,
        ownerId: OWNER_UID,
        userId: OWNER_UID,
        title: "Admin spoof",
        status: "uploading",
      })
    );
    await assertFails(
      setDoc(doc(adminDb, "videos", VALID_UUID_1), {
        ...validPipelineUploadPayload(VALID_UUID_1, ADMIN_UID),
        title: "",
      })
    );
  });

  it("blocks missing/empty/oversized title, invalid status, or spoofed storage path", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    const base = validPipelineUploadPayload(VALID_UUID_1, OWNER_UID);

    const { title: _dropTitle, ...noTitle } = base;
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), noTitle));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, title: "" }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, title: 123 }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, title: "a".repeat(501) }));

    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, status: "processed" }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, status: "completed" }));

    await assertFails(
      setDoc(doc(db, "videos", VALID_UUID_1), {
        ...base,
        storage: { videoPath: `videos/${VALID_UUID_2}/original.mp4` },
      })
    );
    await assertFails(
      setDoc(doc(db, "videos", VALID_UUID_1), {
        ...base,
        storage: {},
      })
    );
  });

  it("blocks non-zero metrics and spoofable server fields on create", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    const base = validPipelineUploadPayload(VALID_UUID_1, OWNER_UID);

    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, views: 10 }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, likeCount: 1 }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, credibilityScore: 99 }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, truthScore: 100 }));
    await assertFails(setDoc(doc(db, "videos", VALID_UUID_1), { ...base, isVerified: true }));
  });
});

describe("phantom parent prevention on videos/{videoId} subcollections", () => {
  it("blocks subcollection writes when parent video does not exist (both normal user and admin)", async () => {
    const userDb = env.authenticatedContext(OWNER_UID).firestore();
    const adminDb = env.authenticatedContext(ADMIN_UID, { admin: true, email_verified: true }).firestore();

    for (const [label, db, uid] of [
      ["user", userDb, OWNER_UID],
      ["admin", adminDb, ADMIN_UID],
    ] as const) {
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "media", "localization"), { audioTracks: {} }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "subtitles", "en"), { url: "https://x" }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "chapters", "ch1"), { title: "Intro" }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "audio_tracks", "hi"), { url: "https://x" }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "citations", "c1"), { url: "https://x" }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "language_requests", "hi"), { userId: uid }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "views", uid), { viewedAt: 1 }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "shards", "0"), { count: 1 }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comment_shards", "0"), { commentCount: 1 }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "likes", uid), { createdAt: 1 }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "dislikes", uid), { createdAt: 1 }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comments", "c1"), { userId: uid, text: `hi ${label}` }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comments", "c1", "replies", "r1"), { userId: uid, text: "r" }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comments", "c1", "likes", uid), { ok: true }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comments", "c1", "dislikes", uid), { ok: true }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comments", "c1", "replies", "r1", "likes", uid), { ok: true }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "comments", "c1", "replies", "r1", "dislikes", uid), { ok: true }));
      await assertFails(setDoc(doc(db, "videos", PHANTOM_UUID, "claim_comments", "cc1"), { userId: uid, text: "note" }));
    }
  });

  it("allows subcollection writes when parent video exists", async () => {
    const ownerDb = env.authenticatedContext(OWNER_UID).firestore();
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();

    await assertSucceeds(
      setDoc(doc(ownerDb, "videos", VALID_UUID_1), validPipelineUploadPayload(VALID_UUID_1, OWNER_UID))
    );

    await assertSucceeds(setDoc(doc(ownerDb, "videos", VALID_UUID_1, "media", "localization"), { audioTracks: {} }));
    await assertSucceeds(setDoc(doc(ownerDb, "videos", VALID_UUID_1, "subtitles", "en"), { url: "https://x" }));
    await assertSucceeds(setDoc(doc(ownerDb, "videos", VALID_UUID_1, "chapters", "ch1"), { title: "Intro" }));
    await assertSucceeds(setDoc(doc(ownerDb, "videos", VALID_UUID_1, "audio_tracks", "hi"), { url: "https://x" }));
    await assertSucceeds(setDoc(doc(ownerDb, "videos", VALID_UUID_1, "citations", "c1"), { url: "https://x" }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "language_requests", "hi"), { userId: OTHER_UID }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "views", OTHER_UID), { viewedAt: 1 }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "shards", "0"), { count: 1 }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comment_shards", "0"), { commentCount: 1 }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "likes", OTHER_UID), { createdAt: 1 }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "dislikes", OTHER_UID), { createdAt: 1 }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comments", "c1"), { userId: OTHER_UID, text: "hi" }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comments", "c1", "replies", "r1"), { userId: OTHER_UID, text: "r" }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comments", "c1", "likes", OTHER_UID), { ok: true }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comments", "c1", "dislikes", OTHER_UID), { ok: true }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comments", "c1", "replies", "r1", "likes", OTHER_UID), { ok: true }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "comments", "c1", "replies", "r1", "dislikes", OTHER_UID), { ok: true }));
    await assertSucceeds(setDoc(doc(otherDb, "videos", VALID_UUID_1, "claim_comments", "cc1"), { userId: OTHER_UID, text: "note" }));
  });
});

describe("backward compatibility on existing videos", () => {
  it("preserves get, list, update, and delete on existing videos", async () => {
    const anonDb = env.unauthenticatedContext().firestore();
    const ownerDb = env.authenticatedContext(OWNER_UID).firestore();
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();

    await assertSucceeds(getDoc(doc(anonDb, "videos", EXISTING_LEGACY_ID)));
    await assertSucceeds(getDocs(collection(anonDb, "videos")));
    await assertSucceeds(updateDoc(doc(ownerDb, "videos", EXISTING_LEGACY_ID), { title: "Updated Legacy" }));
    await assertSucceeds(updateDoc(doc(otherDb, "videos", EXISTING_LEGACY_ID), { likeCount: 1 }));
    await assertSucceeds(deleteDoc(doc(ownerDb, "videos", EXISTING_LEGACY_ID)));
  });
});
