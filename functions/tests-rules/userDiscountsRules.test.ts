/**
 * Security rules tests for users/{userId} dubbing and subtitle discount fields.
 *
 * Verifies that non-admin users cannot self-assign free dubbing or subtitle
 * discount fields on create or update, while normal profile updates succeed
 * and admins can still manage discount fields.
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";

const USER_UID = "discount_user_123";
const NEW_USER_UID = "discount_new_user_456";
const ADMIN_UID = "discount_admin_789";

let env: RulesTestEnvironment;

beforeAll(async () => {
  const root = path.resolve(__dirname, "../..");
  env = await initializeTestEnvironment({
    projectId: "demo-truthworld",
    firestore: {
      rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8"),
    },
  });
});

afterAll(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", ADMIN_UID), {
      role: "admin",
      isAdmin: true,
    });
    await setDoc(doc(db, "users", USER_UID), {
      uid: USER_UID,
      displayName: "Regular User",
      role: "user",
    });
  });
});

describe("users/{userId} dubbing & subtitle discount rules", () => {
  it("allows a non-admin user to create their profile without discount fields", async () => {
    const db = env.authenticatedContext(NEW_USER_UID).firestore();
    await assertSucceeds(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "New User",
      })
    );
  });

  it("allows a non-admin user to create their profile with default non-discounted values", async () => {
    const db = env.authenticatedContext(NEW_USER_UID).firestore();
    await assertSucceeds(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "New User",
        isDubbingFree: false,
        dubbingDiscountType: null,
        dubbingDiscountPercent: 0,
        isSubtitlesFree: false,
        subtitlesDiscountType: null,
        subtitlesDiscountPercent: 0,
      })
    );
  });

  it("blocks a non-admin user from creating their profile with free dubbing or discount fields", async () => {
    const db = env.authenticatedContext(NEW_USER_UID).firestore();

    await assertFails(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "Abuser",
        isDubbingFree: true,
      })
    );

    await assertFails(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "Abuser",
        dubbingDiscountType: "free",
      })
    );

    await assertFails(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "Abuser",
        dubbingDiscountPercent: 100,
      })
    );

    await assertFails(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "Abuser",
        isSubtitlesFree: true,
      })
    );

    await assertFails(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "Abuser",
        subtitlesDiscountType: "free",
      })
    );

    await assertFails(
      setDoc(doc(db, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "Abuser",
        subtitlesDiscountPercent: 100,
      })
    );
  });

  it("blocks a non-admin user from updating their profile with dubbing or subtitle discount fields", async () => {
    const db = env.authenticatedContext(USER_UID).firestore();

    await assertFails(
      updateDoc(doc(db, "users", USER_UID), {
        isDubbingFree: true,
      })
    );

    await assertFails(
      updateDoc(doc(db, "users", USER_UID), {
        dubbingDiscountType: "free",
      })
    );

    await assertFails(
      updateDoc(doc(db, "users", USER_UID), {
        dubbingDiscountPercent: 100,
      })
    );

    await assertFails(
      updateDoc(doc(db, "users", USER_UID), {
        isSubtitlesFree: true,
      })
    );

    await assertFails(
      updateDoc(doc(db, "users", USER_UID), {
        subtitlesDiscountType: "free",
      })
    );

    await assertFails(
      updateDoc(doc(db, "users", USER_UID), {
        subtitlesDiscountPercent: 100,
      })
    );
  });

  it("allows a non-admin user to perform normal profile updates", async () => {
    const db = env.authenticatedContext(USER_UID).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users", USER_UID), {
        displayName: "Updated Display Name",
      })
    );
  });

  it("allows an admin to set dubbing and subtitle discount fields on create and update", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();

    await assertSucceeds(
      setDoc(doc(adminDb, "users", NEW_USER_UID), {
        uid: NEW_USER_UID,
        displayName: "VIP Creator",
        isDubbingFree: true,
        dubbingDiscountType: "free",
        dubbingDiscountPercent: 100,
        isSubtitlesFree: true,
        subtitlesDiscountType: "free",
        subtitlesDiscountPercent: 100,
      })
    );

    await assertSucceeds(
      updateDoc(doc(adminDb, "users", USER_UID), {
        isDubbingFree: true,
        dubbingDiscountType: "free",
        dubbingDiscountPercent: 100,
        isSubtitlesFree: true,
        subtitlesDiscountType: "free",
        subtitlesDiscountPercent: 100,
      })
    );
  });
});
