/**
 * Emulator tests for the resolution access rules (audit C1 / C4).
 *
 * Not part of `npm test` (jest only picks up tests/**). Run with the Firestore
 * and Storage emulators:
 *
 *   cd functions
 *   npm i -D @firebase/rules-unit-testing firebase
 *   firebase emulators:exec --only firestore,storage --project demo-truthworld \
 *     "npx jest --rootDir . --testMatch '<rootDir>/tests-rules/**' --setupFilesAfterEnv= --runInBand"
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, collection, getDocs } from "firebase/firestore";
import { ref, uploadBytes, getBytes } from "firebase/storage";

const OWNER = "owner_uid";
const ATTACKER = "attacker_uid";
const PUBLIC_ID = "public-video-0001";
const PRIVATE_ID = "private-video-0001";

let env: RulesTestEnvironment;

beforeAll(async () => {
  const root = path.resolve(__dirname, "../..");
  env = await initializeTestEnvironment({
    projectId: "demo-truthworld",
    firestore: { rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8") },
    storage: { rules: fs.readFileSync(path.join(root, "storage.rules"), "utf8") },
  });
});

afterAll(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "videos", PUBLIC_ID), { ownerId: OWNER, userId: OWNER, visibility: "public" });
    await setDoc(doc(db, "videos", PRIVATE_ID), { ownerId: OWNER, userId: OWNER, visibility: "private" });
    await setDoc(doc(db, "resolution_jobs", PUBLIC_ID), { videoId: PUBLIC_ID, userId: OWNER, variants: {} });
    await setDoc(doc(db, "resolution_jobs", PRIVATE_ID), { videoId: PRIVATE_ID, userId: OWNER, variants: {} });
    const storage = ctx.storage();
    const bytes = new Uint8Array([0, 0, 0, 24]);
    await uploadBytes(ref(storage, `resolutions/${PUBLIC_ID}/720p.mp4`), bytes, { contentType: "video/mp4" });
    await uploadBytes(ref(storage, `resolutions/${PRIVATE_ID}/720p.mp4`), bytes, { contentType: "video/mp4" });
  });
});

const videoUpload = (uid: string) => ({
  contentType: "video/mp4",
  customMetadata: { uploaderId: uid },
});

describe("C1: Storage writes under videos/{videoId}", () => {
  it("lets the owner upload the source file", async () => {
    const storage = env.authenticatedContext(OWNER).storage();
    await assertSucceeds(
      uploadBytes(ref(storage, `videos/${PUBLIC_ID}/original.mp4`), new Uint8Array([1]), videoUpload(OWNER))
    );
  });

  it("blocks another user from adding a file under the owner's video", async () => {
    const storage = env.authenticatedContext(ATTACKER).storage();
    await assertFails(
      uploadBytes(ref(storage, `videos/${PUBLIC_ID}/x.mp4`), new Uint8Array([1]), videoUpload(ATTACKER))
    );
  });

  it("blocks uploads for a video id with no Firestore doc", async () => {
    const storage = env.authenticatedContext(ATTACKER).storage();
    await assertFails(
      uploadBytes(ref(storage, "videos/no-such-video/original.mp4"), new Uint8Array([1]), videoUpload(ATTACKER))
    );
  });

  it("blocks another user's chapter images under the owner's video", async () => {
    const storage = env.authenticatedContext(ATTACKER).storage();
    await assertFails(
      uploadBytes(ref(storage, `videos/${PUBLIC_ID}/chapters/c1.jpg`), new Uint8Array([1]), {
        contentType: "image/jpeg",
        customMetadata: { uploaderId: ATTACKER },
      })
    );
  });
});

describe("C4: resolution_jobs in Firestore", () => {
  it("anyone can read the job of a public video", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "resolution_jobs", PUBLIC_ID)));
  });

  it("strangers can't read the job of a private video", async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "resolution_jobs", PRIVATE_ID)));
    await assertFails(getDoc(doc(env.authenticatedContext(ATTACKER).firestore(), "resolution_jobs", PRIVATE_ID)));
  });

  it("the owner can read the job of their private video", async () => {
    await assertSucceeds(getDoc(doc(env.authenticatedContext(OWNER).firestore(), "resolution_jobs", PRIVATE_ID)));
  });

  it("non-admins can't list resolution_jobs", async () => {
    await assertFails(getDocs(collection(env.authenticatedContext(ATTACKER).firestore(), "resolution_jobs")));
  });

  it("admins can list resolution_jobs", async () => {
    const adminDb = env.authenticatedContext("admin_uid", { admin: true, email_verified: true }).firestore();
    await assertSucceeds(getDocs(collection(adminDb, "resolution_jobs")));
  });
});

describe("C4: resolutions/ in Storage", () => {
  it("anyone can stream a public video's transcode", async () => {
    const storage = env.unauthenticatedContext().storage();
    await assertSucceeds(getBytes(ref(storage, `resolutions/${PUBLIC_ID}/720p.mp4`)));
  });

  it("strangers can't read a private video's transcode", async () => {
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), `resolutions/${PRIVATE_ID}/720p.mp4`)));
    await assertFails(getBytes(ref(env.authenticatedContext(ATTACKER).storage(), `resolutions/${PRIVATE_ID}/720p.mp4`)));
  });

  it("the owner can read their private video's transcode", async () => {
    await assertSucceeds(getBytes(ref(env.authenticatedContext(OWNER).storage(), `resolutions/${PRIVATE_ID}/720p.mp4`)));
  });
});
