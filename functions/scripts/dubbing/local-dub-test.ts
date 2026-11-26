/**
 * Local end-to-end dub test: a short English clip → one target language, through the REAL pipeline
 * code in this folder (TranscriptionLayer.submitTranscription → DubbingEngine.runDubbingPipeline),
 * with real AssemblyAI, Gemini (Vertex AI), Google Translation, ElevenLabs and the Modal Demucs worker.
 *
 * Production is never touched:
 *   - Firestore: the local emulator only (refuses to start without FIRESTORE_EMULATOR_HOST, and checks
 *     the emulator answers).
 *   - Storage: the staging bucket only. Opening a production bucket throws.
 *   - Pub/Sub: messages are recorded to the output folder, never sent (no production function runs).
 *   - No wallet is charged (the order step is skipped; refunds, if any, land in the emulator).
 * Paid APIs ARE called: a 30 s Telugu dub costs roughly $0.05–0.10 (ElevenLabs ~500 characters,
 * AssemblyAI 30 s, a few Gemini calls, one Demucs run).
 *
 * Usage (two terminals, from functions/):
 *   1) npx firebase emulators:start --only firestore --project truthworld-1
 *   2) set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080            (PowerShell: $env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080")
 *      npx ts-node --transpile-only scripts/dubbing/local-dub-test.ts --bucket=truthworld-1-staging --target=te --seconds=30
 *
 * Options: --source=<video or audio file> (required), --start=<sec> (default 0),
 *          --keep-staging-files (otherwise this run's files are deleted from the staging bucket at the end),
 *          --clone: order a voice-clone dub (dubbingMode "voice_clone") with consent recorded, as when a
 *          creator ticks the consent box. The pipeline clones only a single-speaker video (07-dubbing.ts,
 *          A5); with more speakers it uses matched library voices. The clone is temporary and deleted
 *          from ElevenLabs when the job ends (saveAsCreatorProfile stays false).
 *          --clone=all: same, plus per-speaker cloning (DUBBING_CLONE_ALL_SPEAKERS=true): each speaker
 *          of a multi-speaker video, up to 10, is cloned from their own clean lines
 *          (speaker-clone-plan.ts); a speaker with under 10 s of clean speech keeps a matched voice.
 *          All clones are temporary and deleted when the job ends.
 *          Strict by default (DUBBING_CLONE_STRICT=true): no speaker gets a library voice. A speaker
 *          short of clean speech is cloned from shorter or overlapping lines, or a looped sample; if
 *          a speaker still cannot be cloned the dub stops with the reason. Set DUBBING_CLONE_STRICT=false
 *          to allow matched library voices for such speakers.
 *          --seconds=full: dub the whole source from --start (up to 1800 s). Over 8 minutes the
 *          pipeline splits the video into reels; this script runs those reel workers and the
 *          assembler in-process, as handleDubbingReel / handleAssembleDubbingReels do in production.
 *
 * Output: functions/local-dub-output/dub-test-<lang>-<time>/ — source clip, dubbed audio, the video with
 * the dubbed audio, background/dialogue stems, translation, and report.json / report.md.
 */

import * as fs from "fs";
import * as net from "net";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });
const envLocalPath = path.resolve(__dirname, "../../.env.local");
if (fs.existsSync(envLocalPath)) {
  dotenv.config({ path: envLocalPath, override: true });
}

const PRODUCTION_BUCKETS = new Set(["truthworld-1.firebasestorage.app", "truthworld-1.appspot.com"]);

function arg(name: string, fallback = ""): string {
  const hit = process.argv.slice(2).find((a) => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return fallback;
  return hit.includes("=") ? hit.slice(hit.indexOf("=") + 1).trim() : "true";
}

function fail(message: string): never {
  console.error(`\n❌ ${message}\n`);
  process.exit(1);
}

function canConnect(hostPort: string, timeoutMs = 2000): Promise<boolean> {
  const [host, portStr] = hostPort.split(":");
  return new Promise((resolve) => {
    const socket = net.connect({ host: host || "127.0.0.1", port: Number(portStr) });
    const done = (ok: boolean) => {
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeoutMs, () => done(false));
    socket.once("connect", () => done(true));
    socket.once("error", () => done(false));
  });
}

async function main(): Promise<void> {
  const bucketName = arg("bucket");
  const target = arg("target", "te").toLowerCase();
  // --seconds=full: the whole source from --start, up to MAX_TEST_SECONDS. Videos over 8 minutes take
  // the production long-form path (reel workers + assembler), which this script runs in-process.
  // The real length is measured after the cut.
  const MAX_TEST_SECONDS = 1800;
  const fullLength = arg("seconds") === "full";
  let seconds = fullLength ? MAX_TEST_SECONDS : Math.max(5, Math.min(MAX_TEST_SECONDS, Number(arg("seconds", "30")) || 30));
  const startSec = Math.max(0, Number(arg("start", "0")) || 0);
  const keepStagingFiles = arg("keep-staging-files") === "true";
  const cloneArg = arg("clone");
  const cloneAll = cloneArg === "all";
  const cloneVoice = cloneArg === "true" || cloneAll;
  if (cloneAll) {
    process.env.DUBBING_CLONE_ALL_SPEAKERS = "true";
    // Strict unless set otherwise: every speaker gets a clone or the dub stops (no library voices).
    if (process.env.DUBBING_CLONE_STRICT === undefined) process.env.DUBBING_CLONE_STRICT = "true";
  }
  // No default clip (2026-11-25, owner: old test clips deleted): the video must always be named.
  const source = arg("source") || "";

  console.log("================================================================================");
  console.log(`TruthWorld local dub test — English → ${target}, ${fullLength ? "full length" : `${seconds}s`}`);
  console.log("================================================================================");

  // ── Safety guards (before any pipeline code is loaded) ─────────────────────────────────────────
  if (!bucketName) fail('Give the staging bucket: --bucket="truthworld-1-staging"');
  if (PRODUCTION_BUCKETS.has(bucketName.toLowerCase())) fail(`Refusing to run on the production bucket '${bucketName}'.`);
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!emulatorHost) {
    fail(
      "FIRESTORE_EMULATOR_HOST is not set, so Firestore writes would go to PRODUCTION. Start the emulator\n" +
        "   (npx firebase emulators:start --only firestore --project truthworld-1) and set\n" +
        "   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 in this terminal."
    );
  }
  if (!(await canConnect(emulatorHost))) fail(`The Firestore emulator is not answering at ${emulatorHost}. Start it first.`);
  delete process.env.FIREBASE_STORAGE_EMULATOR_HOST; // stems must live in a real bucket the Modal worker can read
  delete process.env.ASSEMBLYAI_WEBHOOK_URL; // a webhook would point at production; the polling path is used
  process.env.PUBSUB_EMULATOR_HOST = "127.0.0.1:9"; // backstop: any publish that slips past the recorder fails locally
  if (!source) fail(`No video given. Pass --source="<path to an English video>".`);
  if (!fs.existsSync(source)) fail(`Video not found: ${source}`);
  if (!process.env.ELEVENLABS_API_KEY) fail("ELEVENLABS_API_KEY is missing from functions/.env (or .env.local).");
  if (!process.env.ASSEMBLYAI_API_KEY && !process.env.ASSEMBLYAI_KEY) fail("ASSEMBLYAI_API_KEY is missing from functions/.env (or .env.local).");
  if (!process.env.GOOGLE_TRANSLATION_API_KEY) {
    // Cloud Translation v3 uses ADC, but PIPELINE_CONFIG requires a fallback string if accessed
    process.env.GOOGLE_TRANSLATION_API_KEY = "adc-managed";
  }

  // ── Firebase Admin: Firestore → emulator, Storage → staging bucket only ────────────────────────
  const admin = require("firebase-admin");
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT_ID || "truthworld-1",
      storageBucket: bucketName,
    });
  }
  // Same Firestore setting as production (src/index.ts): fields set to undefined are dropped, not rejected.
  admin.firestore().settings({ ignoreUndefinedProperties: true });
  const storage = admin.storage();
  const originalBucket = storage.bucket.bind(storage);
  storage.bucket = (name?: string) => {
    if (name && PRODUCTION_BUCKETS.has(String(name).toLowerCase())) {
      throw new Error(`[local-dub-test] Blocked access to production bucket '${name}'`);
    }
    return originalBucket(name);
  };
  // With FIRESTORE_EMULATOR_HOST set, the client uses the emulator's host name without TLS.
  const fsSettings = (admin.firestore() as any)?._settings || {};
  const emulatorHostName = emulatorHost.split(":")[0];
  if (fsSettings.ssl !== false || String(fsSettings.servicePath || "") !== emulatorHostName) {
    fail(`Firestore client is not pointed at the emulator (servicePath=${fsSettings.servicePath}, ssl=${fsSettings.ssl}).`);
  }
  console.log(`[Safety] Firestore → emulator ${emulatorHost} | Storage → gs://${bucketName} only | Pub/Sub → recorded, not sent`);

  // Local credentials are a person's login, which cannot sign URLs (production signs with the Cloud
  // Functions service account). For read links in the staging bucket, hand out a Firebase download-token
  // URL instead: same effect for AssemblyAI / the Modal worker (anyone with the link can read the file).
  const { File } = require("@google-cloud/storage");
  const originalGetSignedUrl = File.prototype.getSignedUrl;
  File.prototype.getSignedUrl = async function (this: any, config: any, ...rest: any[]) {
    if (config?.action !== "read" || this.bucket?.name !== bucketName) {
      return originalGetSignedUrl.call(this, config, ...rest);
    }
    const [metadata] = await this.getMetadata();
    let token = String(metadata?.metadata?.firebaseStorageDownloadTokens || "").split(",")[0].trim();
    if (!token) {
      token = require("crypto").randomUUID();
      await this.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
    }
    return [`https://firebasestorage.googleapis.com/v0/b/${this.bucket.name}/o/${encodeURIComponent(this.name)}?alt=media&token=${token}`];
  };

  // ── Pipeline code (loaded only after the guards) ───────────────────────────────────────────────
  const { PIPELINE_CONFIG } = require("../../src/pipeline/config");
  (PIPELINE_CONFIG as any).VIDEO_BUCKET = bucketName; // config hard-codes the production bucket
  const { DistributionLayer } = require("../../src/pipeline/layers/04-distribution");
  const publishedEvents: Array<{ eventType: string; jobId: string; at: number }> = [];
  // Long videos: reel tasks and the assembly task are kept and run in this process after the main job.
  const reelTasks: any[] = [];
  const assemblyTasks: any[] = [];
  DistributionLayer.prototype.publish = async function (eventType: string, event: any): Promise<string> {
    publishedEvents.push({ eventType, jobId: event?.jobId, at: Date.now() });
    if (eventType === "dubbing-reel-requested") {
      reelTasks.push(event?.data);
      console.log(`[Pub/Sub kept, run locally] ${eventType} (reel ${Number(event?.data?.reelIndex) + 1}/${event?.data?.totalReels})`);
    } else if (eventType === "dubbing-reel-assemble") {
      assemblyTasks.push(event?.data);
      console.log(`[Pub/Sub kept, run locally] ${eventType}`);
    } else {
      console.log(`[Pub/Sub recorded, not sent] ${eventType}`);
    }
    return `local_${publishedEvents.length}`;
  };
  DistributionLayer.prototype.publishToDLQ = async function (event: any, reason: string): Promise<void> {
    publishedEvents.push({ eventType: `DLQ: ${reason}`, jobId: event?.jobId, at: Date.now() });
  };
  const { getFfmpegPath, execFileAsync, mediaService } = require("../../src/pipeline/services/media");
  const { TranscriptionLayer } = require("../../src/pipeline/layers/05-transcription");
  const { DubbingEngine } = require("../../src/pipeline/layers/07-dubbing");

  const ffmpeg = getFfmpegPath();
  if (!ffmpeg) fail("FFmpeg not found (ffmpeg-static).");
  const db = admin.firestore();
  const bucket = storage.bucket();

  const stamp = Date.now();
  const jobId = `localdub_${target}_${stamp}`;
  const userId = `local_test_user`;
  const outDir = path.resolve(__dirname, `../../local-dub-output/dub-test-${target}-${stamp}`);
  fs.mkdirSync(outDir, { recursive: true });
  // Everything printed during the run (including pipeline logs) is also saved to run-log.txt, so a
  // failed run leaves its error behind.
  const runLog = fs.createWriteStream(path.join(outDir, "run-log.txt"), { flags: "a" });
  for (const stream of [process.stdout, process.stderr]) {
    const write = stream.write.bind(stream) as (...a: any[]) => boolean;
    (stream as any).write = (chunk: any, ...rest: any[]) => {
      try { runLog.write(chunk); } catch { /* the log file must never stop the run */ }
      return write(chunk, ...rest);
    };
  }
  const timings: Record<string, number> = {};
  const report: Record<string, any> = { jobId, target, seconds, startSec, source, bucket: bucketName, outDir, voiceClone: cloneAll ? "all_speakers" : cloneVoice };

  try {
    // 1. Cut the clip (re-encoded so the cut is exact)
    const isAudioOnly = /\.(mp3|wav|m4a|aac|flac|ogg)$/i.test(source);
    const clipPath = path.join(outDir, isAudioOnly ? "source_clip.mp3" : "source_clip.mp4");
    let t = Date.now();
    await execFileAsync(
      ffmpeg,
      isAudioOnly
        ? ["-y", "-ss", String(startSec), "-t", String(seconds), "-i", source, "-c:a", "libmp3lame", "-b:a", "256k", clipPath]
        : ["-y", "-ss", String(startSec), "-t", String(seconds), "-i", source, "-c:v", "libx264", "-preset", "veryfast",
          "-crf", "20", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", clipPath],
      { maxBuffer: 50 * 1024 * 1024 }
    );
    timings.cutMs = Date.now() - t;
    if (fullLength) {
      // ffmpeg prints "Duration: hh:mm:ss.xx" for the cut clip (it exits non-zero with no output file).
      const probe = require("child_process").spawnSync(ffmpeg, ["-hide_banner", "-i", clipPath], { encoding: "utf8" });
      const m = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(String(probe.stderr || ""));
      if (!m) fail("Could not read the clip length for --seconds=full.");
      seconds = Math.round((Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3])) * 1000) / 1000;
      report.seconds = seconds;
      console.log(`  Full length: ${seconds}s`);
    }
    console.log(`[1/5] Clip cut: ${clipPath}`);

    // 2. Upload to staging with a download token (the Modal worker and AssemblyAI fetch it by URL)
    const objectPath = `local-dub-test/${jobId}/${path.basename(clipPath)}`;
    const token = require("crypto").randomUUID();
    await bucket.upload(clipPath, {
      destination: objectPath,
      metadata: {
        contentType: isAudioOnly ? "audio/mpeg" : "video/mp4",
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });
    const videoUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
    console.log(`[2/5] Uploaded: gs://${bucketName}/${objectPath}`);

    // 3. The same Firestore documents an upload + order create (in the emulator)
    const executionPlan: any = {
      jobId,
      videoId: jobId,
      languages: [target],
      primaryLanguage: "en",
      sourceLanguage: "en",
      enableCredibility: false,
      factCheckEnabled: false,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: true,
      genLangSubs: true,
      generateSubtitles: true,
      enableAuxiliary: true,
      enableDiarization: true,
      diarization: true,
      subtitleLanguages: [target],
      dubbingLanguages: [target],
      // --clone: test the creator voice-clone path; consent is recorded by whoever runs this test.
      dubbingMode: cloneVoice ? "voice_clone" : "standard",
      voiceCloneConsent: cloneVoice,
      saveAsCreatorProfile: false,
      dubbingTier: "audio_track",
      // Same as a Dubbing Studio order: the pipeline builds the downloadable dubbed MP4 per language.
      deliverDubbedVideo: !isAudioOnly,
      uncannyMitigation: "cadence_lock",
      isometryMode: "strict_syllable",
      cinemaGrade: false,
      stemIsolation: true,
      voiceGender: "auto",
      duration: seconds,
      durationSeconds: seconds,
      autoChapters: false,
      priorityMode: "standard",
      channelType: "standard",
      maxClaims: 0,
      priority: "normal",
      skipCache: false,
    };
    await db.collection("videos").doc(jobId).set({
      jobId,
      userId,
      channelId: userId,
      title: `Local dub test (${target})`,
      sourceLanguage: "en",
      originalLanguage: "en",
      language: "en",
      durationSeconds: seconds,
      videoUrl,
      status: "processing",
      createdAt: stamp,
    });
    await db.collection("channels").doc(userId).set({
      channelId: userId,
      userId,
      ownerId: userId,
      channelType: "standard",
      infraConfig: { currentMonthInfraCost: 0 },
      createdAt: stamp,
    }, { merge: true });
    await db.collection("video_jobs").doc(jobId).set({
      jobId,
      videoId: jobId,
      userId,
      channelId: userId,
      videoUrl,
      status: "processing",
      sourceLanguage: "en",
      primaryLanguage: "en",
      executionPlan,
      createdAt: stamp,
    });

    // 4. Transcription (real AssemblyAI, polling)
    t = Date.now();
    console.log(`[3/5] Transcribing with AssemblyAI...`);
    await new TranscriptionLayer().submitTranscription(jobId, userId, videoUrl, executionPlan, `local_trans_${stamp}`);
    timings.transcriptionMs = Date.now() - t;
    const transcript = (await db.collection("transcripts").doc(jobId).get()).data();
    if (!transcript?.utterances?.length) throw new Error("No transcript was stored — see the logs above.");
    report.transcript = {
      model: transcript.model || transcript.provider,
      language: transcript.language,
      utterances: transcript.utterances.length,
      speakers: Array.from(new Set(transcript.utterances.map((u: any) => u.speaker))).length,
      text: String(transcript.text || "").slice(0, 2000),
    };
    console.log(`  ${report.transcript.utterances} lines, ${report.transcript.speakers} speaker(s), model ${report.transcript.model}`);

    // 5. Dubbing (the same call handleDubbing makes)
    t = Date.now();
    console.log(`[4/5] Dubbing into ${target} (this takes a few minutes)...`);
    const engine = new DubbingEngine();
    await engine.runDubbingPipeline(jobId, userId, videoUrl, executionPlan, `local_dub_${stamp}`);
    // Long-form path (> 8 min): run every reel worker, then the assembler, as production does via Pub/Sub.
    if (reelTasks.length > 0) {
      report.reels = { total: reelTasks.length, workerMs: [] as number[] };
      for (const task of reelTasks) {
        const rt = Date.now();
        console.log(`[4b] Reel ${Number(task.reelIndex) + 1}/${task.totalReels}: voicing ${Math.round((task.endMs - task.startMs) / 1000)} s...`);
        await engine.processDubbingReel(task);
        report.reels.workerMs.push(Date.now() - rt);
      }
      if (assemblyTasks.length === 0) throw new Error("All reels ran but no assembly task was published — see [Dubbing:Reel] logs.");
      const at = Date.now();
      console.log(`[4c] Assembling ${reelTasks.length} reels...`);
      await engine.assembleDubbingReels(assemblyTasks[0]);
      report.reels.assemblyMs = Date.now() - at;
    }
    timings.dubbingMs = Date.now() - t;

    // 6. Collect results
    console.log(`[5/5] Collecting results...`);
    const result = (await db.collection("dubbing_results").doc(`${jobId}_${target}`).get()).data();
    const dubJob = (await db.collection("dubbing_jobs").doc(jobId).get()).data();
    const jobDoc = (await db.collection("video_jobs").doc(jobId).get()).data();
    report.dubbingJob = dubJob ? { status: dubJob.status, failedLanguages: dubJob.failedLanguages, error: dubJob.error } : null;
    report.stages = jobDoc?.stages ? Object.fromEntries(Object.entries(jobDoc.stages).filter(([k]) => /dub|subtitle|separation|transcription/.test(k))) : null;
    report.separation = jobDoc?.artifacts?.separation || null;
    // transcript.speakers is AssemblyAI's count; this is what the Gemini diarization check made of it.
    report.diarization = jobDoc?.artifacts?.diarization || null;
    report.result = result || null;
    // Per-speaker cloning (--clone=all): who was cloned, from how many seconds, and who was not and why.
    report.speakerClones = jobDoc?.artifacts?.speakerClones || null;
    try {
      const jcSnap = await db.collection("job_costs").doc(jobId).get();
      report.jobCost = jcSnap.exists ? jcSnap.data() : null;
    } catch (_) {
      report.jobCost = null;
    }
    report.deliveryCheck = jobDoc?.artifacts?.deliveryChecks?.[target] || null;
    report.economics = jobDoc?.economics?.[target] || null;

    const files: Record<string, string> = {};
    const grab = async (label: string, url: string | null | undefined, name: string) => {
      if (!url) return;
      const dest = path.join(outDir, name);
      try {
        await mediaService.downloadToStream(url, dest, bucket, 120000);
        files[label] = dest;
      } catch (e: any) {
        console.warn(`  Could not download ${label}: ${e?.message || e}`);
      }
    };
    if (result) {
      await grab("dubbedAudio", result.audioUrl, `dub_${target}.mp3`);
      await grab("background", result.stems?.mne, "background_stem.mp3");
      await grab("vocals", result.stems?.vocals, "vocals_stem.mp3");
      await grab("dubbedDialogueOnly", result.stems?.dialogue, `dialogue_${target}.mp3`);
      await grab("translation", result.translationUrl, `translation_${target}.json`);
    }
    // The pipeline's own dubbed MP4 (videos/{jobId}/{lang}-dubbed.mp4), as the Studio export offers it.
    if (result?.videoUrl && /-dubbed\.mp4/i.test(String(result.videoUrl))) {
      await grab("pipelineDubbedVideo", result.videoUrl, `video_with_${target}_dub.mp4`);
    }
    report.pipelineBuiltMp4 = Boolean(files.pipelineDubbedVideo);
    if (!files.pipelineDubbedVideo && files.dubbedAudio && !isAudioOnly) {
      const muxed = path.join(outDir, `video_with_${target}_dub_LOCAL.mp4`);
      await execFileAsync(ffmpeg, ["-y", "-i", clipPath, "-i", files.dubbedAudio, "-map", "0:v:0", "-map", "1:a:0",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", muxed]);
      files.videoWithDubLocal = muxed;
    }
    report.files = files;
    report.verdict = files.dubbedAudio ? "DUB_DELIVERED" : "NO_DUB_DELIVERED";
  } catch (err: any) {
    report.verdict = "ERROR";
    report.error = String(err?.stack || err?.message || err);
    console.error(`\n❌ Run stopped: ${err?.message || err}`);
  } finally {
    report.timingsSec = Object.fromEntries(Object.entries(timings).map(([k, v]) => [k.replace(/Ms$/, ""), Math.round(v / 100) / 10]));
    report.publishedEvents = publishedEvents;

    if (!keepStagingFiles) {
      try {
        const [stagingFiles] = await bucket.getFiles();
        const mine = stagingFiles.filter((f: any) => String(f.name).includes(jobId));
        for (const f of mine) await f.delete().catch(() => {});
        report.stagingFilesDeleted = mine.length;
      } catch (e: any) {
        report.stagingCleanupError = String(e?.message || e);
      }
    }

    fs.writeFileSync(path.join(outDir, "report.json"), JSON.stringify(report, null, 2), "utf8");
    try {
      const jobDocFinal = (await db.collection("video_jobs").doc(jobId).get()).data();
      const bgmReport = jobDocFinal?.artifacts?.bgmReport?.[target];
      if (bgmReport) {
        fs.writeFileSync(path.join(outDir, "bgm_report.json"), JSON.stringify(bgmReport, null, 2), "utf8");
      }
    } catch (_) {}
    const md = [
      `# Local dub test — English → ${target} (${seconds}s)`,
      ``,
      `- Verdict: **${report.verdict}**`,
      `- Pipeline built the dubbed MP4: ${report.pipelineBuiltMp4 ? "yes" : "NO"}`,
      `- Job: \`${jobId}\``,
      `- Dubbing job status: ${report.dubbingJob?.status ?? "n/a"}${report.dubbingJob?.error ? ` — ${report.dubbingJob.error}` : ""}`,
      `- Transcript (AssemblyAI): ${report.transcript ? `${report.transcript.utterances} lines, ${report.transcript.speakers} speaker(s), ${report.transcript.model}` : "n/a"}`,
      `- Diarization check: ${report.diarization ? `${report.diarization.speakersBefore} → ${report.diarization.speakersAfter} speaker(s), applied ${report.diarization.applied}, ${report.diarization.reason} (${report.diarization.model})` : "n/a (did not run)"}`,
      `- Separation: ${report.separation ? JSON.stringify(report.separation) : "n/a"}`,
      ...(report.speakerClones ? [`- Speaker clones: ${report.speakerClones.cloned?.length ?? 0} of ${report.speakerClones.speakers} cloned; skipped ${JSON.stringify(report.speakerClones.skipped)}; failed ${JSON.stringify(report.speakerClones.failed)}`] : []),
      `- Timings (s): ${JSON.stringify(report.timingsSec)}`,
      `- Pub/Sub messages recorded (not sent): ${publishedEvents.map((e) => e.eventType).join(", ") || "none"}`,
      ``,
      `## Files`,
      ...Object.entries(report.files || {}).map(([k, v]) => `- ${k}: ${v}`),
      ...(report.error ? ["", "## Error", "```", report.error, "```"] : []),
    ].join("\n");
    fs.writeFileSync(path.join(outDir, "report.md"), md, "utf8");
    console.log("\n" + md + "\n");
    console.log(`Output folder: ${outDir}`);
    await new Promise<void>((resolve) => runLog.end(() => resolve()));
    process.exit(report.verdict === "DUB_DELIVERED" ? 0 : 1);
  }
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
