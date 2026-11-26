/**
 * Security rules for studio_dubbing_jobs (Dubbing Studio, 2026-11-24).
 *
 * createDubbingJob writes studio_dubbing_jobs/{id}; the Studio screen streams that document. Without a
 * rule the collection fell to the default deny and the screen could not load its own job.
 * Verifies: the owner can read; another user cannot; an admin can; nobody writes from the client.
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from "firebase/firestore";

const OWNER_UID = "studio_owner_123";
const OTHER_UID = "studio_other_456";
const ADMIN_UID = "studio_admin_789";
const JOB_ID = "dub_vid_test_1795460000000";

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
    await setDoc(doc(db, "users", ADMIN_UID), { role: "admin", isAdmin: true });
    await setDoc(doc(db, "studio_dubbing_jobs", JOB_ID), {
      id: JOB_ID,
      userId: OWNER_UID,
      status: "processing",
      progressPercent: 10,
      targetLanguages: ["te"],
      costUsd: 0.3,
    });
  });
});

describe("studio_dubbing_jobs rules", () => {
  it("lets the owner read their Studio job", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, "studio_dubbing_jobs", JOB_ID)));
  });

  it("does not let another user read it", async () => {
    const db = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(getDoc(doc(db, "studio_dubbing_jobs", JOB_ID)));
  });

  it("does not let a signed-out visitor read it", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "studio_dubbing_jobs", JOB_ID)));
  });

  it("lets an admin read it", async () => {
    const db = env.authenticatedContext(ADMIN_UID, { admin: true, role: "admin" }).firestore();
    await assertSucceeds(getDoc(doc(db, "studio_dubbing_jobs", JOB_ID)));
  });

  it("blocks every client write, including the owner's", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(updateDoc(doc(db, "studio_dubbing_jobs", JOB_ID), { status: "completed", costUsd: 0 }));
    await assertFails(setDoc(doc(db, "studio_dubbing_jobs", "dub_new_job"), { userId: OWNER_UID, status: "completed" }));
    await assertFails(deleteDoc(doc(db, "studio_dubbing_jobs", JOB_ID)));
  });
});
