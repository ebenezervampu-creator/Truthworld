/**
 * Security rules tests for aiDubbedAudio field protection (Task 5).
 *
 * Verifies that:
 * - an owner cannot create, change or delete aiDubbedAudio;
 * - an owner can still update allowed fields (title, description, audioTracks for their own upload);
 * - an admin can write aiDubbedAudio.
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc, deleteField } from "firebase/firestore";

const OWNER_UID = "owner_uid_123";
const OTHER_UID = "other_uid_456";
const ADMIN_UID = "admin_uid_789";
const VIDEO_ID = "video_test_001";

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
    // Seed admin profile
    await setDoc(doc(db, "users", ADMIN_UID), { role: "admin", isAdmin: true });
    // Seed initial video doc owned by OWNER_UID
    await setDoc(doc(db, "videos", VIDEO_ID), {
      ownerId: OWNER_UID,
      userId: OWNER_UID,
      title: "Original Title",
      description: "Original Description",
      visibility: "public",
      audioTracks: {
        en: "https://storage.googleapis.com/truthworld/en.mp3",
      },
      aiDubbedAudio: {
        hi: "https://storage.googleapis.com/truthworld/hi_ai.mp3",
      },
    });
  });
});

describe("aiDubbedAudio protection in firestore.rules", () => {
  it("blocks owner from creating/setting aiDubbedAudio directly on a video", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    const newVideoId = "new_video_002";
    await assertFails(
      setDoc(doc(db, "videos", newVideoId), {
        ownerId: OWNER_UID,
        userId: OWNER_UID,
        title: "New Video",
        aiDubbedAudio: {
          te: "https://storage.googleapis.com/fake/tampered.mp3",
        },
      })
    );
  });

  it("blocks owner from modifying aiDubbedAudio on their existing video", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      updateDoc(doc(db, "videos", VIDEO_ID), {
        "aiDubbedAudio.hi": "https://storage.googleapis.com/fake/tampered_hi.mp3",
      })
    );
  });

  it("blocks owner from deleting aiDubbedAudio field", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      updateDoc(doc(db, "videos", VIDEO_ID), {
        aiDubbedAudio: deleteField(),
      })
    );
  });

  it("blocks owner from adding a new language to aiDubbedAudio", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      updateDoc(doc(db, "videos", VIDEO_ID), {
        "aiDubbedAudio.mr": "https://storage.googleapis.com/fake/mr.mp3",
      })
    );
  });

  it("allows owner to update allowed fields (title, description, audioTracks for creator upload)", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "videos", VIDEO_ID), {
        title: "Updated Title By Owner",
        description: "Updated Description By Owner",
        "audioTracks.fr": "https://storage.googleapis.com/truthworld/fr_creator.mp3",
        "audioTrackSources.fr": "creator",
      })
    );
  });

  it("an owner set-merge with a literal field 'aiDubbedAudio.te' does not mutate protected aiDubbedAudio root map", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    // In Firestore, set with a literal string key 'aiDubbedAudio.te' writes a flat dotted field, not modifying root aiDubbedAudio map
    await setDoc(
      doc(db, "videos", VIDEO_ID),
      {
        "aiDubbedAudio.te": "https://storage.googleapis.com/fake/tampered.mp3",
      },
      { merge: true }
    );

    let snap: any;
    await env.withSecurityRulesDisabled(async (ctx) => {
      snap = await ctx.firestore().collection("videos").doc(VIDEO_ID).get();
    });
    const data = snap.data();
    expect(data?.aiDubbedAudio?.hi).toEqual("https://storage.googleapis.com/truthworld/hi_ai.mp3");
    expect(data?.aiDubbedAudio?.te).toBeUndefined();
  });

  it("allows admin to write/update aiDubbedAudio", async () => {
    const db = env.authenticatedContext(ADMIN_UID, { admin: true }).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "videos", VIDEO_ID), {
        "aiDubbedAudio.mr": "https://storage.googleapis.com/truthworld/mr_verified_ai.mp3",
      })
    );
  });
});
