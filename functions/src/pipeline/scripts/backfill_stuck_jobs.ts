/**
 * 🛠️ BACKFILL: STUCK JOBS RECOVERY
 * 
 * Target: Jobs in 'accepted' or 'processing' where all stages are terminal.
 * Mode: Dry-run by default. Use --apply to execute.
 */

// @ts-nocheck

import * as admin from "firebase-admin";
import { JobData, ExecutionPlan } from "../types";
import * as fs from "fs";
import * as path from "path";

// Initialize for local script execution
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface BackfillStats {
  scanned: number;
  recoverable: number;
  alreadyCompleted: number;
  missingStages: number;
  repaired: number;
  errors: number;
}

async function runBackfill(options: { 
  dryRun: boolean; 
  limit: number; 
  lookbackDays: number;
  batchSize: number;
}) {
  const runId = `backfill_${Date.now()}`;
  console.log(`\n🚀 Starting Backfill [${runId}]`);
  console.log(`   Mode: ${options.dryRun ? "DRY-RUN (No Writes)" : "APPLY (Mutation Mode)"}`);
  console.log(`   Lookback: ${options.lookbackDays} days`);
  console.log(`   Limit: ${options.limit}\n`);

  const stats: BackfillStats = {
    scanned: 0,
    recoverable: 0,
    alreadyCompleted: 0,
    missingStages: 0,
    repaired: 0,
    errors: 0
  };

  const startTime = Date.now();
  const lookbackMs = options.lookbackDays * 24 * 60 * 60 * 1000;
  const cutoffTime = Date.now() - lookbackMs;
  const bufferTime = Date.now() - (10 * 60 * 1000); // 10 mins ago

  const jobLogs: any[] = [];

  try {
    let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
    let totalProcessed = 0;

    const targetStatuses = ["accepted", "processing"];

    for (const statusFilter of targetStatuses) {
      console.log(`   Scanning for status: ${statusFilter}...`);
      lastDoc = null;

      while (totalProcessed < options.limit) {
        let query = db.collection("video_jobs")
          .where("status", "==", statusFilter)
          .limit(options.batchSize);

        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) break;

        for (const doc of snapshot.docs) {
          if (totalProcessed >= options.limit) break;
          
          const job = doc.data() as JobData;

          // 🛡️ Age Gate: Skip jobs created in the last 10 minutes (likely still processing)
          if (job.createdAt > bufferTime) {
            continue;
          }

          stats.scanned++;
          totalProcessed++;

          // 2. Evaluate Truth Table
          const { ready, reason } = evaluateTruthTable(job);

          if (ready) {
            stats.recoverable++;
            console.log(`   [RECOVERABLE] ${job.jobId} - ${reason}`);

            if (!options.dryRun) {
              try {
                await repairJob(doc.ref, job);
                stats.repaired++;
              } catch (err) {
                console.error(`   [ERROR] Failed to repair ${job.jobId}:`, err);
                stats.errors++;
              }
            }
            
            jobLogs.push({
              jobId: job.jobId,
              oldStatus: job.status,
              repaired: !options.dryRun,
              reason
            });
          } else {
            console.log(`   [SKIPPED] ${job.jobId} - ${reason}`);
            stats.missingStages++;
          }
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.docs.length < options.batchSize) break;
        if (!options.dryRun) await new Promise(resolve => setTimeout(resolve, 250));
      }
    }

    // Write Report
    const report = {
      runId,
      timestamp: new Date().toISOString(),
      durationMs: Date.now() - startTime,
      options,
      stats,
      logs: jobLogs
    };

    const reportDir = path.join(process.cwd(), "backfill_reports");
    if (!fs.existsSync(reportDir)) fs.mkdirSync(reportDir);
    fs.writeFileSync(
      path.join(reportDir, `${runId}.json`), 
      JSON.stringify(report, null, 2)
    );

    console.log(`\n✅ Backfill Finished`);
    console.table(stats);
    console.log(`📝 Report saved: backfill_reports/${runId}.json\n`);

  } catch (err) {
    console.error("❌ Backfill Crashed:", err);
  }
}

function evaluateTruthTable(job: JobData): { ready: boolean; reason: string } {
  const stages = job.stages || {};
  let plan = job.executionPlan;

  // 🛡️ Intelligent Inference for Legacy Jobs
  if (!plan) {
    console.log(`   [INFER] Inferring plan for legacy job ${job.jobId}`);
    plan = {
      enablePath1: !!stages.credibility,
      enablePath2: !!stages.dubbing,
      enableTruthEngine: !!stages.credibility,
      enableReachEngine: !!stages.dubbing,
    } as any;
  }

  const isDone = (s: any) => s?.status === "completed" || s?.status === "skipped";

  const transcriptionDone = isDone(stages.transcription);
  
  // Support both legacy Path 1/2 and new Truth/Reach names
  const truthEngineRequired = plan.enablePath1 || (plan as any).enableTruthEngine;
  const truthEngineDone = !truthEngineRequired || isDone(stages.credibility);

  const reachEngineRequired = plan.enablePath2 || (plan as any).enableReachEngine;
  const reachEngineDone = !reachEngineRequired || isDone(stages.dubbing);

  if (transcriptionDone && truthEngineDone && reachEngineDone) {
    // Final check: if they are required but missing from stages map, they aren't done
    if (truthEngineRequired && !stages.credibility) return { ready: false, reason: "TruthEngine required but missing from stages" };
    if (reachEngineRequired && !stages.dubbing) return { ready: false, reason: "ReachEngine required but missing from stages" };
    
    return { ready: true, reason: "All required stages terminal (Inferred/Actual)" };
  }

  const missing = [];
  if (!transcriptionDone) missing.push("transcription");
  if (truthEngineRequired && !truthEngineDone) missing.push("truthEngine/credibility");
  if (reachEngineRequired && !reachEngineDone) missing.push("reachEngine/dubbing");

  return { ready: false, reason: `Waiting for: ${missing.join(", ")}` };
}

async function repairJob(jobRef: admin.firestore.DocumentReference, job: JobData) {
  return db.runTransaction(async (transaction) => {
    // 1. Update Job Status
    transaction.update(jobRef, {
      status: "completed",
      completedAt: Date.now(),
      completionSource: "backfill_script",
      recovered: true,
      updatedAt: Date.now(),
      version: admin.firestore.FieldValue.increment(1)
    });

    // 2. Propagate to Linked Videos
    const linkedVideoIds = job.linkedVideoIds || [];
    if (job.videoId && !linkedVideoIds.includes(job.videoId)) {
      linkedVideoIds.push(job.videoId);
    }

    for (const vid of linkedVideoIds) {
      const vRef = db.collection("videos").doc(vid);
      transaction.update(vRef, {
        status: "ready",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        recoveredFromJob: job.jobId
      });
    }
  });
}

// CLI Execution Entry
const args = process.argv.slice(2);
const isApply = args.includes("--apply");
const limitArg = args.find(a => a.startsWith("--limit="))?.split("=")[1];
const lookbackArg = args.find(a => a.startsWith("--lookback="))?.split("=")[1];

runBackfill({
  dryRun: !isApply,
  limit: limitArg ? parseInt(limitArg) : 100,
  lookbackDays: lookbackArg ? parseInt(lookbackArg) : 7,
  batchSize: 50
});
