/**
 * Security rules tests for Dubbing Studio & Pipeline Output collections:
 * - dubbing_wallets/{userId}
 * - dubbing_wallet_transactions/{txId}
 * - dubbing_orders/{orderId}
 * - job_outputs/{jobId}
 * - dubbing_results/{resultId}
 * - subtitle_results/{resultId}
 * - video_jobs/{jobId}/dubbing_manifests/{lang}
 *
 * Verifies: owner read, cross-user fail, unauthenticated fail, admin read,
 * and client create/update/delete fail.
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

const OWNER_UID = "dub_owner_123";
const OTHER_UID = "dub_other_456";
const ADMIN_UID = "dub_admin_789";

const JOB_ID = "job_dub_test_1795460000000";
const VIDEO_ID = "11111111-1111-4111-8111-111111111111";
const JOB_VIA_VIDEO_ID = "job_dub_video_1795460000001";
const ORDER_ID = "order_dub_123";
const TX_ID = "tx_dub_123";
const DUB_RESULT_USER_ID = "dub_res_user_123";
const DUB_RESULT_JOB_ID = "dub_res_job_456";
const SUB_RESULT_USER_ID = "sub_res_user_123";
const SUB_RESULT_JOB_ID = "sub_res_job_456";
const LANG = "te";

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

    await setDoc(doc(db, "users", ADMIN_UID), { role: "admin", isAdmin: true });

    await setDoc(doc(db, "videos", VIDEO_ID), {
      id: VIDEO_ID,
      ownerId: OWNER_UID,
      userId: OWNER_UID,
      title: "Test Video",
    });

    await setDoc(doc(db, "video_jobs", JOB_ID), {
      jobId: JOB_ID,
      userId: OWNER_UID,
      status: "completed",
    });

    await setDoc(doc(db, "video_jobs", JOB_VIA_VIDEO_ID), {
      jobId: JOB_VIA_VIDEO_ID,
      videoId: VIDEO_ID,
      status: "completed",
    });

    await setDoc(doc(db, "dubbing_wallets", OWNER_UID), {
      userId: OWNER_UID,
      balanceUsd: 25,
      updatedAt: 1795460000000,
    });

    await setDoc(doc(db, "dubbing_wallet_transactions", TX_ID), {
      id: TX_ID,
      userId: OWNER_UID,
      amountUsd: 10,
      type: "credit",
      createdAt: 1795460000000,
    });

    await setDoc(doc(db, "dubbing_orders", ORDER_ID), {
      id: ORDER_ID,
      userId: OWNER_UID,
      amountUsd: 20,
      status: "paid",
      createdAt: 1795460000000,
    });

    await setDoc(doc(db, "job_outputs", JOB_ID), {
      jobId: JOB_ID,
      status: "completed",
      outputUrl: "https://cdn.example.com/out.mp4",
    });

    await setDoc(doc(db, "job_outputs", JOB_VIA_VIDEO_ID), {
      jobId: JOB_VIA_VIDEO_ID,
      status: "completed",
      outputUrl: "https://cdn.example.com/out2.mp4",
    });

    await setDoc(doc(db, "dubbing_results", DUB_RESULT_USER_ID), {
      id: DUB_RESULT_USER_ID,
      userId: OWNER_UID,
      language: LANG,
      audioUrl: "https://cdn.example.com/dub.mp3",
    });

    await setDoc(doc(db, "dubbing_results", DUB_RESULT_JOB_ID), {
      id: DUB_RESULT_JOB_ID,
      jobId: JOB_ID,
      language: LANG,
      audioUrl: "https://cdn.example.com/dub-job.mp3",
    });

    await setDoc(doc(db, "subtitle_results", SUB_RESULT_USER_ID), {
      id: SUB_RESULT_USER_ID,
      userId: OWNER_UID,
      language: LANG,
      subtitleUrl: "https://cdn.example.com/sub.vtt",
    });

    await setDoc(doc(db, "subtitle_results", SUB_RESULT_JOB_ID), {
      id: SUB_RESULT_JOB_ID,
      jobId: JOB_ID,
      language: LANG,
      subtitleUrl: "https://cdn.example.com/sub-job.vtt",
    });

    await setDoc(doc(db, "video_jobs", JOB_ID, "dubbing_manifests", LANG), {
      jobId: JOB_ID,
      language: LANG,
      masterAudioUrl: "https://cdn.example.com/master.mp3",
      segments: [],
      updatedAt: 1795460000000,
    });
  });
});

describe("dubbing_wallets rules", () => {
  it("lets the owner read their wallet", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, "dubbing_wallets", OWNER_UID)));
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(getDoc(doc(otherDb, "dubbing_wallets", OWNER_UID)));

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauthDb, "dubbing_wallets", OWNER_UID)));
  });

  it("lets an admin read", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(getDoc(doc(adminDb, "dubbing_wallets", OWNER_UID)));
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "dubbing_wallets", "new_wallet"), {
        userId: OWNER_UID,
        balanceUsd: 1000,
      })
    );
    await assertFails(
      updateDoc(doc(db, "dubbing_wallets", OWNER_UID), { balanceUsd: 9999 })
    );
    await assertFails(deleteDoc(doc(db, "dubbing_wallets", OWNER_UID)));
  });
});

describe("dubbing_wallet_transactions rules", () => {
  it("lets the owner read their transaction", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, "dubbing_wallet_transactions", TX_ID)));
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(
      getDoc(doc(otherDb, "dubbing_wallet_transactions", TX_ID))
    );

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(unauthDb, "dubbing_wallet_transactions", TX_ID))
    );
  });

  it("lets an admin read", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(
      getDoc(doc(adminDb, "dubbing_wallet_transactions", TX_ID))
    );
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "dubbing_wallet_transactions", "tx_new"), {
        userId: OWNER_UID,
        amountUsd: 100,
      })
    );
    await assertFails(
      updateDoc(doc(db, "dubbing_wallet_transactions", TX_ID), {
        amountUsd: 500,
      })
    );
    await assertFails(deleteDoc(doc(db, "dubbing_wallet_transactions", TX_ID)));
  });
});

describe("dubbing_orders rules", () => {
  it("lets the owner read their order", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, "dubbing_orders", ORDER_ID)));
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(getDoc(doc(otherDb, "dubbing_orders", ORDER_ID)));

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauthDb, "dubbing_orders", ORDER_ID)));
  });

  it("lets an admin read", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(getDoc(doc(adminDb, "dubbing_orders", ORDER_ID)));
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "dubbing_orders", "order_new"), {
        userId: OWNER_UID,
        status: "paid",
      })
    );
    await assertFails(
      updateDoc(doc(db, "dubbing_orders", ORDER_ID), { status: "refunded" })
    );
    await assertFails(deleteDoc(doc(db, "dubbing_orders", ORDER_ID)));
  });
});

describe("job_outputs rules", () => {
  it("lets the job owner read directly and via associated video", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, "job_outputs", JOB_ID)));
    await assertSucceeds(getDoc(doc(db, "job_outputs", JOB_VIA_VIDEO_ID)));
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(getDoc(doc(otherDb, "job_outputs", JOB_ID)));
    await assertFails(getDoc(doc(otherDb, "job_outputs", JOB_VIA_VIDEO_ID)));

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauthDb, "job_outputs", JOB_ID)));
  });

  it("lets an admin read", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(getDoc(doc(adminDb, "job_outputs", JOB_ID)));
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "job_outputs", "job_new"), {
        jobId: "job_new",
        status: "completed",
      })
    );
    await assertFails(
      updateDoc(doc(db, "job_outputs", JOB_ID), { status: "tampered" })
    );
    await assertFails(deleteDoc(doc(db, "job_outputs", JOB_ID)));
  });
});

describe("dubbing_results rules", () => {
  it("lets the owner read via userId or jobId", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, "dubbing_results", DUB_RESULT_USER_ID)));
    await assertSucceeds(getDoc(doc(db, "dubbing_results", DUB_RESULT_JOB_ID)));
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(
      getDoc(doc(otherDb, "dubbing_results", DUB_RESULT_USER_ID))
    );
    await assertFails(
      getDoc(doc(otherDb, "dubbing_results", DUB_RESULT_JOB_ID))
    );

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(unauthDb, "dubbing_results", DUB_RESULT_USER_ID))
    );
  });

  it("lets an admin read", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(
      getDoc(doc(adminDb, "dubbing_results", DUB_RESULT_USER_ID))
    );
    await assertSucceeds(
      getDoc(doc(adminDb, "dubbing_results", DUB_RESULT_JOB_ID))
    );
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "dubbing_results", "dub_res_new"), {
        userId: OWNER_UID,
        language: LANG,
      })
    );
    await assertFails(
      updateDoc(doc(db, "dubbing_results", DUB_RESULT_USER_ID), {
        audioUrl: "https://evil.example.com/a.mp3",
      })
    );
    await assertFails(
      deleteDoc(doc(db, "dubbing_results", DUB_RESULT_USER_ID))
    );
  });
});

describe("subtitle_results rules", () => {
  it("lets the owner read via userId or jobId", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(
      getDoc(doc(db, "subtitle_results", SUB_RESULT_USER_ID))
    );
    await assertSucceeds(getDoc(doc(db, "subtitle_results", SUB_RESULT_JOB_ID)));
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(
      getDoc(doc(otherDb, "subtitle_results", SUB_RESULT_USER_ID))
    );
    await assertFails(
      getDoc(doc(otherDb, "subtitle_results", SUB_RESULT_JOB_ID))
    );

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(unauthDb, "subtitle_results", SUB_RESULT_USER_ID))
    );
  });

  it("lets an admin read", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(
      getDoc(doc(adminDb, "subtitle_results", SUB_RESULT_USER_ID))
    );
    await assertSucceeds(
      getDoc(doc(adminDb, "subtitle_results", SUB_RESULT_JOB_ID))
    );
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "subtitle_results", "sub_res_new"), {
        userId: OWNER_UID,
        language: LANG,
      })
    );
    await assertFails(
      updateDoc(doc(db, "subtitle_results", SUB_RESULT_USER_ID), {
        subtitleUrl: "https://evil.example.com/s.vtt",
      })
    );
    await assertFails(
      deleteDoc(doc(db, "subtitle_results", SUB_RESULT_USER_ID))
    );
  });
});

describe("video_jobs/{jobId}/dubbing_manifests/{lang} rules", () => {
  it("lets the job owner read the manifest", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(
      getDoc(doc(db, "video_jobs", JOB_ID, "dubbing_manifests", LANG))
    );
  });

  it("blocks another user and unauthenticated visitors from reading", async () => {
    const otherDb = env.authenticatedContext(OTHER_UID).firestore();
    await assertFails(
      getDoc(doc(otherDb, "video_jobs", JOB_ID, "dubbing_manifests", LANG))
    );

    const unauthDb = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(unauthDb, "video_jobs", JOB_ID, "dubbing_manifests", LANG))
    );
  });

  it("lets an admin read the manifest", async () => {
    const adminDb = env
      .authenticatedContext(ADMIN_UID, { admin: true, role: "admin" })
      .firestore();
    await assertSucceeds(
      getDoc(doc(adminDb, "video_jobs", JOB_ID, "dubbing_manifests", LANG))
    );
  });

  it("blocks client create, update, and delete", async () => {
    const db = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, "video_jobs", JOB_ID, "dubbing_manifests", "hi"), {
        jobId: JOB_ID,
        language: "hi",
      })
    );
    await assertFails(
      updateDoc(doc(db, "video_jobs", JOB_ID, "dubbing_manifests", LANG), {
        masterAudioUrl: "https://evil.example.com/m.mp3",
      })
    );
    await assertFails(
      deleteDoc(doc(db, "video_jobs", JOB_ID, "dubbing_manifests", LANG))
    );
  });
});
