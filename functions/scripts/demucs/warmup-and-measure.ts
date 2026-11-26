/**
 * Demucs Worker Warm-up & Benchmarking Script
 *
 * Verifies live Modal Demucs v4 worker reachability, measures cold vs. warm latency,
 * evaluates stem durations and background loudness, and validates whether the faithful mix
 * accepts the resulting background stem as "clean" using the pipeline's authentic validation
 * grounded in real speech windows derived from the isolated vocals stem.
 *
 * Usage:
 *   npx ts-node scripts/demucs/warmup-and-measure.ts --bucket="<test-bucket>" [--project="<test-project>"] [--audio="<path-to-media>"]
 */

import * as fs from "fs";
import * as path from "path";
import * as dotenv from "dotenv";

// Load functions/.env
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

interface CmdArgs {
  audioPath: string;
  bucketName: string;
  projectId: string;
  coldWaitSec: number;
}

/**
 * Idle time before Call 1 so the Modal container scales down and Call 1 is a real cold start.
 * 35 s was not enough (2026-11-23: Call 1 41.4 s vs Call 2 41.0 s). 10 minutes is well past
 * Modal's default scale-down window; lower it only after checking the worker's scaledown setting.
 */
const DEFAULT_COLD_WAIT_SEC = 600;

function parseArgs(): CmdArgs {
  const args = process.argv.slice(2);
  let audioPath = "";
  let bucketName = "";
  let projectId = "";
  let coldWaitSec = 0;

  for (const arg of args) {
    if (arg.startsWith("--audio=")) {
      audioPath = arg.replace(/^--audio=/, "").trim();
    } else if (arg.startsWith("--bucket=")) {
      bucketName = arg.replace(/^--bucket=/, "").trim();
    } else if (arg.startsWith("--project=")) {
      projectId = arg.replace(/^--project=/, "").trim();
    } else if (arg === "--cold-wait-sec") {
      coldWaitSec = DEFAULT_COLD_WAIT_SEC;
    } else if (arg.startsWith("--cold-wait-sec=")) {
      coldWaitSec = parseInt(arg.replace(/^--cold-wait-sec=/, "").trim(), 10) || DEFAULT_COLD_WAIT_SEC;
    }
  }

  if (!bucketName && projectId) {
    bucketName = `${projectId}.firebasestorage.app`;
  }

  // Fallback audio candidate if omitted
  if (!audioPath) {
    const defaultLocal = path.resolve(__dirname, "../../local-dub-output/benchmark_3m15s_source.mp3");
    const defaultUploaded = path.resolve(
      "C:/Users/ebene/.gemini/antigravity/brain/b7188cce-0e0e-490a-b356-3a82d9c692cb/.user_uploaded/media_1795451655097_41a07b61.mp4"
    );
    if (fs.existsSync(defaultLocal)) {
      audioPath = defaultLocal;
    } else if (fs.existsSync(defaultUploaded)) {
      audioPath = defaultUploaded;
    }
  }

  return { audioPath, bucketName, projectId, coldWaitSec };
}

const FORBIDDEN_BUCKETS = new Set([
  "truthworld-1.firebasestorage.app",
  "truthworld-1.appspot.com",
]);

function isProductionStem(url: string): boolean {
  return (
    url.includes("truthworld-1.firebasestorage.app") ||
    url.includes("truthworld-1.appspot.com")
  );
}

const parsed = parseArgs();

console.log("================================================================================");
console.log("TruthWorld Demux Worker — Benchmark & Warm-up Measurement");
console.log("================================================================================");

if (!parsed.bucketName) {
  console.error("❌ Error: GCS bucket not specified.");
  console.error("Please specify a real non-production test/staging bucket via --bucket=\"<bucket-name>\".");
  process.exit(1);
}

if (FORBIDDEN_BUCKETS.has(parsed.bucketName.toLowerCase())) {
  console.error(`❌ SAFETY GUARD: Refusing to run on production bucket '${parsed.bucketName}'.`);
  console.error("The test script must never upload or persist test audio into production.");
  process.exit(1);
}

// ─── INITIALIZE FIREBASE-ADMIN WITH TEST BUCKET BEFORE ANY SRC/ IMPORTS ────────
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  const testProject = parsed.projectId || parsed.bucketName.split(".")[0] || "truthworld-test";
  admin.initializeApp({
    projectId: testProject,
    storageBucket: parsed.bucketName,
  });
  console.log(`[Init] Initialized Firebase Admin targeting test bucket '${parsed.bucketName}' (project: '${testProject}')`);
}

// Now safely import pipeline services (storage().bucket() will resolve to test bucket)
import { mediaService, getFfmpegPath, execFileAsync } from "../../src/pipeline/services/media";
import { canUseBedUnderDialogue } from "../../src/pipeline/services/faithful-mix";

async function probeAudioMetrics(ffmpegPath: string, filePath: string): Promise<{ durationSec: number; meanVolumeDb: number; maxVolumeDb: number }> {
  const { stdout, stderr } = await execFileAsync(
    ffmpegPath,
    [
      "-i", filePath,
      "-af", "volumedetect",
      "-f", "null",
      process.platform === "win32" ? "NUL" : "/dev/null",
    ],
    { maxBuffer: 10 * 1024 * 1024 }
  ).catch((e) => ({ stdout: e?.stdout || "", stderr: e?.stderr || "" }));

  const text = `${stdout || ""}\n${stderr || ""}`;
  let durationSec = 0;
  let meanVolumeDb = -120;
  let maxVolumeDb = 0;

  const durMatch = text.match(/Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2,3})/);
  if (durMatch) {
    durationSec = Number(durMatch[1]) * 3600 + Number(durMatch[2]) * 60 + Number(durMatch[3]) + Number((durMatch[4] + "00").slice(0, 3)) / 1000;
  }

  const meanMatch = text.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
  if (meanMatch) meanVolumeDb = Number(meanMatch[1]);

  const maxMatch = text.match(/max_volume:\s*(-?[\d.]+)\s*dB/);
  if (maxMatch) maxVolumeDb = Number(maxMatch[1]);

  return { durationSec, meanVolumeDb, maxVolumeDb };
}

async function measureVoiceBandEnergy(ffmpegPath: string, filePath: string, startSec: number, durSec: number): Promise<number | null> {
  const { stderr } = await execFileAsync(
    ffmpegPath,
    [
      "-ss", startSec.toFixed(3),
      "-t", durSec.toFixed(3),
      "-i", filePath,
      "-af", "highpass=f=250,lowpass=f=3800,volumedetect",
      "-f", "null",
      process.platform === "win32" ? "NUL" : "/dev/null",
    ],
    { maxBuffer: 5 * 1024 * 1024 }
  ).catch((e) => ({ stdout: "", stderr: e?.stderr || "" }));

  const m = `${stderr || ""}`.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
  return m ? Number(m[1]) : null;
}

/**
 * Derives real speech windows from the isolated vocals stem using FFmpeg silencedetect.
 * Non-silent spans are inverted, bridged (<0.4s), and kept if >=1.0s long.
 */
async function detectSpeechWindows(
  ffmpegPath: string,
  vocalsFilePath: string,
  totalDurSec: number
): Promise<Array<{ start: number; end: number }>> {
  const { stderr } = await execFileAsync(
    ffmpegPath,
    [
      "-i", vocalsFilePath,
      "-af", "silencedetect=noise=-35dB:d=0.4",
      "-f", "null",
      process.platform === "win32" ? "NUL" : "/dev/null",
    ],
    { maxBuffer: 10 * 1024 * 1024 }
  ).catch((e) => ({ stdout: "", stderr: e?.stderr || "" }));

  const lines = (stderr || "").split("\n");
  const silenceSpans: Array<{ start: number; end: number }> = [];
  let currentStart: number | null = null;

  for (const line of lines) {
    const startMatch = line.match(/silence_start:\s*(-?[\d.]+)/);
    if (startMatch) {
      currentStart = Math.max(0, parseFloat(startMatch[1]));
    }
    const endMatch = line.match(/silence_end:\s*(-?[\d.]+)/);
    if (endMatch) {
      const endSec = Math.min(totalDurSec, parseFloat(endMatch[1]));
      const startSec = currentStart !== null ? currentStart : 0;
      if (endSec > startSec) {
        silenceSpans.push({ start: startSec, end: endSec });
      }
      currentStart = null;
    }
  }

  if (currentStart !== null && currentStart < totalDurSec) {
    silenceSpans.push({ start: currentStart, end: totalDurSec });
  }

  // Invert silence spans over [0, totalDurSec] to obtain speech spans
  const speechSpansSec: Array<{ start: number; end: number }> = [];
  let cursor = 0;
  for (const s of silenceSpans.sort((a, b) => a.start - b.start)) {
    if (s.start > cursor) {
      speechSpansSec.push({ start: cursor, end: s.start });
    }
    cursor = Math.max(cursor, s.end);
  }
  if (totalDurSec > cursor) {
    speechSpansSec.push({ start: cursor, end: totalDurSec });
  }

  // Merge pauses < 0.4s and filter for stretches at least 1.0s long
  const merged: Array<{ start: number; end: number }> = [];
  for (const span of speechSpansSec) {
    const prev = merged[merged.length - 1];
    if (prev && span.start - prev.end < 0.4) {
      prev.end = Math.max(prev.end, span.end);
    } else {
      merged.push({ ...span });
    }
  }

  return merged
    .filter((s) => s.end - s.start >= 1.0)
    .map((s) => ({
      start: Math.round(s.start * 1000),
      end: Math.round(s.end * 1000),
    }));
}

function formatLatencyRatio(coldMs: number, warmMs: number): string {
  if (warmMs <= coldMs) {
    const factor = coldMs / Math.max(1, warmMs);
    const pctFaster = Math.round(((coldMs - warmMs) / coldMs) * 100);
    return `${factor.toFixed(2)}x faster (${pctFaster}% faster)`;
  } else {
    const ratio = warmMs / Math.max(1, coldMs);
    const pctSlower = Math.round(((warmMs - coldMs) / coldMs) * 100);
    return `Call 2 vs Call 1: ${ratio.toFixed(2)}x (${pctSlower}% slower)`;
  }
}

async function main() {
  const { audioPath, bucketName } = parsed;

  if (!audioPath || !fs.existsSync(audioPath)) {
    console.error(`❌ Error: Audio file not found at: ${audioPath}`);
    console.error(`Please provide a valid file via --audio="<path>"`);
    process.exit(1);
  }

  const ffmpegPath = getFfmpegPath();
  if (!ffmpegPath) {
    console.error("❌ Error: FFmpeg binary not found via getFfmpegPath()");
    process.exit(1);
  }

  const outDir = path.resolve(__dirname, "../../local-dub-output/demucs-check");
  fs.mkdirSync(outDir, { recursive: true });

  // 1. Extract broadcast audio from media file using pipeline FFmpeg helper
  const jobId = `warmup_check_${Date.now()}`;
  const extractedAudioPath = path.join(outDir, `${jobId}_extracted.mp3`);
  console.log(`[1/5] Extracting broadcast audio from source media...`);
  console.log(`  Source: ${audioPath}`);
  console.log(`  Target: ${extractedAudioPath}`);

  await execFileAsync(ffmpegPath, [
    "-y",
    "-i", audioPath,
    "-vn",
    "-ar", "44100",
    "-ac", "2",
    "-c:a", "libmp3lame",
    "-b:a", "256k",
    extractedAudioPath,
  ]);

  const srcMetrics = await probeAudioMetrics(ffmpegPath, extractedAudioPath);
  console.log(`  Extracted audio duration: ${srcMetrics.durationSec.toFixed(2)}s | Mean loudness: ${srcMetrics.meanVolumeDb.toFixed(1)} dBFS`);

  // 2. Upload audio to specified non-production GCS bucket
  console.log(`[2/5] Uploading extracted audio to non-production GCS bucket '${bucketName}'...`);
  const bucket = admin.storage().bucket(bucketName);
  const destinationPath = `test-audio/${jobId}.mp3`;
  const downloadToken = require("crypto").randomUUID();

  let signedAudioUrl = "";
  try {
    await bucket.upload(extractedAudioPath, {
      destination: destinationPath,
      metadata: {
        contentType: "audio/mpeg",
        metadata: {
          firebaseStorageDownloadTokens: downloadToken,
        },
      },
    });

    signedAudioUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(destinationPath)}?alt=media&token=${downloadToken}`;
    console.log(`  Upload successful: gs://${bucketName}/${destinationPath}`);
  } catch (uploadErr: any) {
    console.error(`❌ Failed to upload to GCS bucket '${bucketName}':`, uploadErr?.message || uploadErr);
    fs.unlinkSync(extractedAudioPath);
    process.exit(1);
  }

  const trackedArtifacts: string[] = [destinationPath];

  try {
    // 3. Separation Call 1 (Cold)
    const call1JobId = `${jobId}_call1`;
    let freshContainerMethod = "";
    if (parsed.coldWaitSec > 0) {
      console.log(`[Cold Start Preparation] Sleeping ${parsed.coldWaitSec}s before Call 1 (exceeding Modal worker scale-down window) to ensure container is cold...`);
      freshContainerMethod = `--cold-wait-sec (${parsed.coldWaitSec}s pre-call scale-down sleep)`;
      await new Promise((r) => setTimeout(r, parsed.coldWaitSec * 1000));
    } else {
      freshContainerMethod = "Direct invocation without pre-call sleep (--cold-wait-sec omitted)";
    }

    console.log(`[3/5] Executing Demux Separation Call 1 (Testing Cold Latency)...`);
    console.log(`  Fresh container strategy: ${freshContainerMethod}`);
    const t0Call1 = Date.now();
    const result1 = await mediaService.separateWithDemuxWorker(call1JobId, signedAudioUrl);
    const durationCall1Ms = Date.now() - t0Call1;

    if (!result1 || result1.degraded) {
      console.error(`❌ Call 1 failed or returned degraded status.`);
      process.exit(1);
    }

    // Safety verification: stems must point to test bucket, never production
    if (isProductionStem(result1.mneUrl) || (result1.vocalsUrl && isProductionStem(result1.vocalsUrl))) {
      console.error("❌ CRITICAL ABORT: Call 1 stems point to production bucket! MneUrl:", result1.mneUrl);
      process.exit(1);
    }
    trackedArtifacts.push(`audio/${call1JobId}/m_and_e.mp3`);
    if (result1.vocalsUrl) trackedArtifacts.push(`audio/${call1JobId}/vocals_demucs.mp3`);

    console.log(`  Call 1 (Cold) Completed in: ${(durationCall1Ms / 1000).toFixed(2)}s (${durationCall1Ms} ms)`);
    console.log(`  Engine: ${result1.engine} | Degraded: ${result1.degraded}`);
    console.log(`  Stems persisted in test bucket: ${result1.mneUrl}`);

    // 4. Separation Call 2 (Warm)
    const call2JobId = `${jobId}_call2`;
    console.log(`[4/5] Executing Demux Separation Call 2 (Testing Warm Latency)...`);
    const t0Call2 = Date.now();
    const result2 = await mediaService.separateWithDemuxWorker(call2JobId, signedAudioUrl);
    const durationCall2Ms = Date.now() - t0Call2;

    if (!result2 || result2.degraded) {
      console.error(`❌ Call 2 failed or returned degraded status.`);
      process.exit(1);
    }

    if (isProductionStem(result2.mneUrl) || (result2.vocalsUrl && isProductionStem(result2.vocalsUrl))) {
      console.error("❌ CRITICAL ABORT: Call 2 stems point to production bucket! MneUrl:", result2.mneUrl);
      process.exit(1);
    }
    trackedArtifacts.push(`audio/${call2JobId}/m_and_e.mp3`);
    if (result2.vocalsUrl) trackedArtifacts.push(`audio/${call2JobId}/vocals_demucs.mp3`);

    console.log(`  Call 2 (Warm) Completed in: ${(durationCall2Ms / 1000).toFixed(2)}s (${durationCall2Ms} ms)`);
    console.log(`  Latency comparison: ${formatLatencyRatio(durationCall1Ms, durationCall2Ms)}`);
    console.log(`  Stems persisted in test bucket: ${result2.mneUrl}`);

    // 5. Download Stems for Local Listening & Pipeline-Grade Validation
    console.log(`[5/5] Extracting speech windows from vocals stem and running pipeline validation...`);
    const localMnePath = path.join(outDir, `${jobId}_mne.mp3`);
    const localVocPath = path.join(outDir, `${jobId}_vocals.mp3`);

    await (mediaService as any).downloadToStream(result2.mneUrl, localMnePath, bucket, 120000);
    await (mediaService as any).downloadToStream(result2.vocalsUrl, localVocPath, bucket, 120000);

    const mneMetrics = await probeAudioMetrics(ffmpegPath, localMnePath);
    const vocMetrics = await probeAudioMetrics(ffmpegPath, localVocPath);

    // Extract speech windows from the isolated vocals stem (approximation of transcript segments)
    const speechWindows = await detectSpeechWindows(ffmpegPath, localVocPath, vocMetrics.durationSec);
    const totalSpeechMs = speechWindows.reduce((sum, w) => sum + (w.end - w.start), 0);
    const totalSpeechSec = totalSpeechMs / 1000;

    console.log(`  Derived speech windows: ${speechWindows.length} windows found (total speech length: ${totalSpeechSec.toFixed(2)}s)`);

    let passClean: boolean | null = null;
    let mneValidation: any = null;

    if (speechWindows.length < 3) {
      console.warn(`  ⚠️ Warning: Fewer than 3 speech windows found (${speechWindows.length} found). Cannot reliably evaluate voice bleed; omitting verdict.`);
    } else {
      // Call mediaService.validateMneStem with identical arguments to 07-dubbing.ts:827-832 & 3252-3258
      mneValidation = await mediaService.validateMneStem(
        call2JobId,
        result2.mneUrl,
        srcMetrics.durationSec,
        (result2.engine === "demucs_v4_neural" ? "neural_demixing" : (result2.engine || "neural_demixing")) as any,
        {
          spokenSegments: speechWindows,
          expectedSourceDegraded: result2.degraded,
          referenceAudioUrl: signedAudioUrl,
          vocalsUrl: result2.vocalsUrl,
        }
      );

      // Pass authentic validationStatus and source into canUseBedUnderDialogue (07-dubbing.ts:3281-3286)
      passClean = canUseBedUnderDialogue({
        bedUrl: result2.mneUrl,
        isolatedVocalUrl: result2.vocalsUrl,
        validationStatus: mneValidation.validationStatus,
        source: mneValidation.source,
      });
    }

    // Compute extra voice-band suppression numbers (informational, not used by the pipeline)
    const suppressions: number[] = [];
    for (const w of speechWindows.slice(0, 12)) {
      const origE = await measureVoiceBandEnergy(ffmpegPath, extractedAudioPath, w.start / 1000, (w.end - w.start) / 1000);
      const mneE = await measureVoiceBandEnergy(ffmpegPath, localMnePath, w.start / 1000, (w.end - w.start) / 1000);
      if (origE !== null && mneE !== null && origE > -60) {
        suppressions.push(origE - mneE);
      }
    }
    const sortedSup = [...suppressions].sort((a, b) => a - b);
    const informationalSuppression = sortedSup.length > 0
      ? `${sortedSup[Math.floor((sortedSup.length - 1) * 0.25)].toFixed(1)} dB`
      : "not measured";

    console.log("\n================================================================================");
    console.log("BENCHMARK & AUTHENTIC PIPELINE VALIDATION REPORT");
    console.log("================================================================================");
    console.log(`Source Media Duration    : ${srcMetrics.durationSec.toFixed(2)}s`);
    console.log(`Fresh Container Method   : ${freshContainerMethod}`);
    console.log(`Call 1 Latency (Cold)    : ${(durationCall1Ms / 1000).toFixed(2)}s`);
    console.log(`Call 2 Latency (Warm)    : ${(durationCall2Ms / 1000).toFixed(2)}s`);
    console.log(`Warm / Cold Latency Ratio: ${formatLatencyRatio(durationCall1Ms, durationCall2Ms)}`);
    console.log("--------------------------------------------------------------------------------");
    console.log(`M&E Stem Duration        : ${mneMetrics.durationSec.toFixed(2)}s`);
    console.log(`Vocals Stem Duration     : ${vocMetrics.durationSec.toFixed(2)}s`);
    console.log(`Background Stem Loudness : ${mneMetrics.meanVolumeDb.toFixed(1)} dBFS (Peak: ${mneMetrics.maxVolumeDb.toFixed(1)} dBFS)`);
    console.log("--------------------------------------------------------------------------------");
    console.log(`Speech Windows Evaluated : ${speechWindows.length} windows, ${totalSpeechSec.toFixed(2)}s total length`);
    console.log(`                           (speech windows derived from the vocals stem (approximation of transcript segments))`);

    if (speechWindows.length < 3 || !mneValidation) {
      console.log(`Pipeline Validation Status: OMITTED (< 3 speech windows found in vocals stem)`);
      console.log(`Faithful Mix Accept Clean: NO VERDICT (fewer than 3 speech windows found)`);
    } else {
      console.log(`Pipeline Validation Status: ${mneValidation.validationStatus.toUpperCase()} (source: ${mneValidation.source})`);
      console.log(`Pipeline Timeline Delta  : ${mneValidation.durationDeltaMs} ms`);
      console.log(`Pipeline Dialogue Bleed  : ${mneValidation.dialogueBleedDb !== undefined ? `${mneValidation.dialogueBleedDb} dBFS` : "none"}`);
      console.log(`Pipeline Vocal Suppr.    : ${mneValidation.vocalSuppressionDb !== undefined ? `${mneValidation.vocalSuppressionDb} dB` : "none"}`);
      console.log(`Pipeline Bleed Method    : ${mneValidation.bleedMethod ?? "none"}`);
      console.log(`Pipeline Issues Logged   : ${mneValidation.issues.length > 0 ? mneValidation.issues.join("; ") : "none"}`);
      console.log(`Informational Residue    : ${informationalSuppression} (informational, not used by the pipeline)`);
      console.log("--------------------------------------------------------------------------------");
      console.log(`Faithful Mix Accept Clean: ${passClean ? "TRUE (Clean Stem Accepted under dialogue)" : "FALSE (Degraded/Dropped under dialogue)"}`);
      console.log(`Deciding Numbers         : validationStatus=${mneValidation.validationStatus}, deltaMs=${mneValidation.durationDeltaMs}, suppressionDb=${mneValidation.vocalSuppressionDb ?? "n/a"}, bleedMethod=${mneValidation.bleedMethod ?? "n/a"}`);
    }
    console.log(`Stems Saved For Listening: ${localMnePath}`);
    console.log("================================================================================\n");

  } finally {
    // Clean up uploaded audio AND persisted stems from the test bucket
    console.log(`[Cleanup] Deleting temporary artifacts from test bucket '${bucketName}'...`);
    for (const art of trackedArtifacts) {
      try {
        await bucket.file(art).delete();
        console.log(`  Deleted: gs://${bucketName}/${art}`);
      } catch (delErr: any) {
        console.warn(`  Notice deleting gs://${bucketName}/${art}:`, delErr?.message || delErr);
      }
    }
    if (fs.existsSync(extractedAudioPath)) {
      fs.unlinkSync(extractedAudioPath);
    }
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
