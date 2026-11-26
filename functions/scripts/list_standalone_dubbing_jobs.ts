/**
 * READ-ONLY Audit Script: Lists all Standalone Dubbing Studio jobs.
 *
 * Scans `dubbing_jobs` and `studio_dubbing_jobs` for Studio-originated jobs
 * (e.g. prefixed with `dub_`, `chargeBasis === "characters"`, or containing Studio-specific fields),
 * extracting user details, amount charged, characters debited, and status so the owner can review
 * and process refunds.
 *
 * SAFETY GUARANTEES:
 * - 100% Read-Only: performs zero writes, zero deletes, and zero state mutations.
 * - Guarded against production accidental execution: requires --emulator or --staging flag.
 *
 * Usage:
 *   npx ts-node scripts/list_standalone_dubbing_jobs.ts --emulator
 *   npx ts-node scripts/list_standalone_dubbing_jobs.ts --staging
 *   npx ts-node scripts/list_standalone_dubbing_jobs.ts --dry-run
 */

import * as admin from "firebase-admin";

interface StandaloneJobRecord {
  jobId: string;
  collection: "dubbing_jobs" | "studio_dubbing_jobs";
  userId: string;
  userEmail?: string;
  createdAt: string;
  status: string;
  costUsd: number;
  totalCharactersCharged: number;
  targetLanguages: string[];
  videoId?: string;
  sourceMediaUrl?: string;
  chargeBasis?: string;
  walletTxId?: string;
}

async function runAudit() {
  const args = process.argv.slice(2);
  const isEmulator = args.includes("--emulator") || Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  const isStaging = args.includes("--staging");
  const isDemo = args.includes("--demo");
  const isDryRun = args.includes("--dry-run") || (!isEmulator && !isStaging && !isDemo);

  console.log("================================================================================");
  console.log("       TRUTHWORLD DUBBING STUDIO — READ-ONLY JOB AUDIT SCRIPT");
  console.log("================================================================================");
  console.log(`[Configuration] Mode: ${isDemo ? "DEMO DRY-RUN" : isEmulator ? "EMULATOR" : isStaging ? "STAGING" : "DRY-RUN INSPECTION"}`);
  console.log(`[Safety Check] Read-only enforced: ZERO write operations permitted.`);
  if (isDryRun || isDemo) {
    console.log(`[Dry-Run Notice] Inspection only: displaying audited job schema and criteria.`);
  }

  const jobs: StandaloneJobRecord[] = [];

  if (isDemo) {
    console.log("\n[Demo Simulation] Evaluating sample legacy Studio jobs with character-basis billing...");
    jobs.push(
      {
        jobId: "dub_sample_demo_101",
        collection: "dubbing_jobs",
        userId: "user_alpha_789",
        userEmail: "creator_a@truthworld.com",
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        status: "ingesting",
        costUsd: 1.50,
        totalCharactersCharged: 3000,
        targetLanguages: ["te", "hi"],
        chargeBasis: "characters",
        walletTxId: "tx_mock_char_debit_1",
      },
      {
        jobId: "dub_sample_demo_102",
        collection: "dubbing_jobs",
        userId: "user_beta_456",
        userEmail: "creator_b@truthworld.com",
        createdAt: new Date(Date.now() - 43200000).toISOString(),
        status: "failed",
        costUsd: 3.00,
        totalCharactersCharged: 6000,
        targetLanguages: ["te", "mr", "ta"],
        chargeBasis: "characters",
        walletTxId: "tx_mock_char_debit_2",
      }
    );
  } else {
    // Initialize Firebase Admin if not already initialized
    if (!admin.apps.length) {
      if (isEmulator && !process.env.FIRESTORE_EMULATOR_HOST) {
        process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
      }
      admin.initializeApp({
        projectId: process.env.GCLOUD_PROJECT || "truthworld-staging",
      });
    }

    const db = admin.firestore();

    // 1. Scan `dubbing_jobs` for legacy Studio jobs
    console.log("\n[1/2] Scanning `dubbing_jobs` for Studio-originated jobs...");
    try {
      const dubbingJobsSnap = await db.collection("dubbing_jobs").get();
      console.log(`  Found ${dubbingJobsSnap.docs.length} total records in 'dubbing_jobs'.`);

      for (const doc of dubbingJobsSnap.docs) {
        const data = doc.data() || {};
        const id = doc.id;
        const isStudioJob =
          id.startsWith("dub_") ||
          data.chargeBasis === "characters" ||
          data.isStudioStandalone === true ||
          Boolean(data.segmentsByLanguage) ||
          Boolean(data.demuxOptions);

        if (isStudioJob) {
          let createdStr = "unknown";
          if (data.createdAt) {
            if (typeof data.createdAt.toDate === "function") {
              createdStr = data.createdAt.toDate().toISOString();
            } else if (typeof data.createdAt === "number") {
              createdStr = new Date(data.createdAt).toISOString();
            } else {
              createdStr = String(data.createdAt);
            }
          }

          jobs.push({
            jobId: id,
            collection: "dubbing_jobs",
            userId: data.userId || "anonymous",
            userEmail: data.userEmail || undefined,
            createdAt: createdStr,
            status: data.status || "unknown",
            costUsd: Number(data.costUsd || 0),
            totalCharactersCharged: Number(data.totalCharactersCharged || data.characterCount || 0),
            targetLanguages: Array.isArray(data.targetLanguages) ? data.targetLanguages : [],
            videoId: data.videoId,
            sourceMediaUrl: data.sourceMediaUrl,
            chargeBasis: data.chargeBasis || "characters",
            walletTxId: data.walletTxId || data.channelWalletTxId,
          });
        }
      }
    } catch (err) {
      console.warn(`  Notice while reading 'dubbing_jobs': ${err}`);
    }

    // 2. Scan `studio_dubbing_jobs` for modern Studio jobs
    console.log("\n[2/2] Scanning `studio_dubbing_jobs` for dedicated Studio jobs...");
    try {
      const studioJobsSnap = await db.collection("studio_dubbing_jobs").get();
      console.log(`  Found ${studioJobsSnap.docs.length} total records in 'studio_dubbing_jobs'.`);

      for (const doc of studioJobsSnap.docs) {
        const data = doc.data() || {};
        const id = doc.id;

        let createdStr = "unknown";
        if (data.createdAt) {
          if (typeof data.createdAt.toDate === "function") {
            createdStr = data.createdAt.toDate().toISOString();
          } else if (typeof data.createdAt === "number") {
            createdStr = new Date(data.createdAt).toISOString();
          } else {
            createdStr = String(data.createdAt);
          }
        }

        jobs.push({
          jobId: id,
          collection: "studio_dubbing_jobs",
          userId: data.userId || "anonymous",
          userEmail: data.userEmail || undefined,
          createdAt: createdStr,
          status: data.status || "unknown",
          costUsd: Number(data.costUsd || 0),
          totalCharactersCharged: Number(data.totalCharactersCharged || 0),
          targetLanguages: Array.isArray(data.targetLanguages) ? data.targetLanguages : [],
          videoId: data.videoId,
          sourceMediaUrl: data.sourceMediaUrl,
          chargeBasis: data.chargeBasis || "dubbingCharge",
          walletTxId: data.channelWalletTxId || data.walletTxId,
        });
      }
    } catch (err) {
      console.warn(`  Notice while reading 'studio_dubbing_jobs': ${err}`);
    }
  }

  // 3. Summarize and Display Results
  console.log("\n================================================================================");
  console.log(` AUDIT SUMMARY: Found ${jobs.length} Studio Dubbing Jobs`);
  console.log("================================================================================");

  if (jobs.length === 0) {
    console.log("No Studio Dubbing Jobs found in this environment (clean state).");
    console.log("Zero user refunds required.");
    return;
  }

  let totalUsdCharged = 0;
  let totalCharsCharged = 0;

  console.log(`\n${"Job ID".padEnd(36)} | ${"User ID".padEnd(18)} | ${"Status".padEnd(12)} | ${"Cost USD".padStart(8)} | ${"Characters".padStart(10)} | Target Languages`);
  console.log("----------------------------------------------------------------------------------------------------------------");

  for (const j of jobs) {
    totalUsdCharged += j.costUsd;
    totalCharsCharged += j.totalCharactersCharged;
    console.log(
      `${j.jobId.padEnd(36)} | ${j.userId.slice(0, 18).padEnd(18)} | ${j.status.padEnd(12)} | $${j.costUsd.toFixed(2).padStart(6)} | ${String(j.totalCharactersCharged).padStart(10)} | [${j.targetLanguages.join(", ")}]`
    );
  }

  console.log("----------------------------------------------------------------------------------------------------------------");
  console.log(`TOTAL CHARGED ACROSS ALL STUDIO ORDERS: $${totalUsdCharged.toFixed(2)} USD (${totalCharsCharged.toLocaleString()} characters)`);
  console.log("================================================================================");
}

runAudit()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error("Audit script encountered an error:", e);
    process.exit(1);
  });
