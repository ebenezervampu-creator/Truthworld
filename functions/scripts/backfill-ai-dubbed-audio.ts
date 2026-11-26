/**
 * One-off admin backfill script:
 * Fills `aiDubbedAudio` on `videos` documents from completed `dubbing_results`
 * whose `audioUrl` equals the current `audioTracks[lang]`.
 *
 * DRY RUN by default: prints all proposed changes without writing to Firestore.
 * Pass `--apply` to actually execute the writes.
 * Pass `--fixture=<path>` to run dry-run against a JSON test fixture without connecting to cloud services.
 *
 * Usage (from functions/):
 *   npx ts-node scripts/backfill-ai-dubbed-audio.ts                      # Dry-run on Firestore
 *   npx ts-node scripts/backfill-ai-dubbed-audio.ts --fixture=test.json  # Dry-run on fixture
 *   npx ts-node scripts/backfill-ai-dubbed-audio.ts --apply              # Write changes (ADMIN ONLY)
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

const APPLY = process.argv.includes("--apply");
const FIXTURE_ARG = process.argv.find((arg) => arg.startsWith("--fixture="));
const FIXTURE_PATH = FIXTURE_ARG ? FIXTURE_ARG.split("=")[1] : null;

interface DubbingResultRecord {
  id: string;
  jobId?: string;
  videoId?: string;
  linkedVideoIds?: string[];
  language?: string;
  audioUrl?: string;
  status?: string;
}

interface VideoRecord {
  id: string;
  jobId?: string;
  audioTracks?: Record<string, string>;
  audioTrackSources?: Record<string, string>;
  aiDubbedAudio?: Record<string, string>;
  dubbingLanguages?: string[];
}

interface FixtureData {
  videos: VideoRecord[];
  dubbing_results: DubbingResultRecord[];
}

function normalizeUrl(url: string, bucketName: string = "truthworld-prod.appspot.com"): string {
  if (!url) return "";
  if (url.startsWith("gs://")) {
    const rawPath = url.replace(`gs://${bucketName}/`, "");
    return `https://storage.googleapis.com/${bucketName}/${rawPath}`;
  }
  return url;
}

async function runWithFixture(fixturePath: string) {
  console.log(`[Backfill] Running in TEST FIXTURE mode using: ${fixturePath}`);
  console.log(`[Backfill] Mode: ${APPLY ? "APPLY (writes enabled)" : "DRY RUN (no writes)"}`);
  console.log("─".repeat(70));

  const content = fs.readFileSync(path.resolve(fixturePath), "utf8");
  const data: FixtureData = JSON.parse(content);

  let evaluatedVideos = 0;
  let matchingDubs = 0;
  let proposedUpdates = 0;

  for (const video of data.videos) {
    evaluatedVideos++;
    const vAudio = video.audioTracks || {};
    const vAiDubbed = video.aiDubbedAudio || {};
    const pendingUpdates: Record<string, string> = {};

    for (const [lang, trackUrl] of Object.entries(vAudio)) {
      // Find matching dubbing result
      const match = data.dubbing_results.find((d) => {
        const langMatches = d.language === lang;
        const videoMatches =
          d.videoId === video.id ||
          (d.linkedVideoIds && d.linkedVideoIds.includes(video.id)) ||
          d.jobId === video.jobId;
        const normAudio = normalizeUrl(d.audioUrl || "");
        const urlMatches = d.audioUrl === trackUrl || normAudio === trackUrl;
        return langMatches && videoMatches && urlMatches;
      });

      if (match) {
        matchingDubs++;
        if (!vAiDubbed[lang] || vAiDubbed[lang] !== trackUrl) {
          pendingUpdates[lang] = trackUrl;
        }
      }
    }

    if (Object.keys(pendingUpdates).length > 0) {
      proposedUpdates++;
      console.log(`[DRY RUN] Video ${video.id}:`);
      for (const [l, u] of Object.entries(pendingUpdates)) {
        console.log(`  + aiDubbedAudio.${l} = "${u}"`);
      }
    }
  }

  console.log("─".repeat(70));
  console.log(`[Backfill Summary]`);
  console.log(`  Total videos evaluated: ${evaluatedVideos}`);
  console.log(`  Matching completed dubbing results: ${matchingDubs}`);
  console.log(`  Videos requiring aiDubbedAudio backfill: ${proposedUpdates}`);
  console.log(`  Execution mode: ${APPLY ? "APPLIED" : "DRY RUN ONLY (no changes made)"}`);
}

async function runLiveFirestore() {
  console.log(`[Backfill] Running in LIVE FIRESTORE mode`);
  console.log(`[Backfill] Mode: ${APPLY ? "APPLY (writes enabled)" : "DRY RUN (no writes)"}`);
  console.log("─".repeat(70));

  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();
  const bucketName = admin.storage().bucket()?.name || "truthworld-prod.appspot.com";

  const dubbingSnaps = await db.collection("dubbing_results").get();
  console.log(`[Backfill] Found ${dubbingSnaps.size} dubbing_results docs`);

  const dubsByVideo = new Map<string, Array<{ language: string; audioUrl: string }>>();

  for (const doc of dubbingSnaps.docs) {
    const d = doc.data();
    const lang = d.language;
    const rawAudio = d.audioUrl;
    if (!lang || !rawAudio) continue;

    const normAudio = normalizeUrl(rawAudio, bucketName);
    const targetVideoIds: string[] = [];
    if (d.videoId) targetVideoIds.push(d.videoId);
    if (Array.isArray(d.linkedVideoIds)) {
      for (const vid of d.linkedVideoIds) {
        if (!targetVideoIds.includes(vid)) targetVideoIds.push(vid);
      }
    }

    if (targetVideoIds.length === 0 && d.jobId) {
      const jobSnap = await db.collection("video_jobs").doc(d.jobId).get();
      if (jobSnap.exists) {
        const jData = jobSnap.data();
        if (jData?.videoId) targetVideoIds.push(jData.videoId);
        if (Array.isArray(jData?.linkedVideoIds)) {
          for (const vid of jData.linkedVideoIds) {
            if (!targetVideoIds.includes(vid)) targetVideoIds.push(vid);
          }
        }
      }
    }

    for (const vid of targetVideoIds) {
      if (!dubsByVideo.has(vid)) dubsByVideo.set(vid, []);
      dubsByVideo.get(vid)!.push({ language: lang, audioUrl: normAudio });
    }
  }

  let evaluatedVideos = 0;
  let proposedUpdates = 0;

  for (const [vid, results] of dubsByVideo.entries()) {
    evaluatedVideos++;
    const vSnap = await db.collection("videos").doc(vid).get();
    if (!vSnap.exists) continue;
    const vData = vSnap.data() || {};
    const audioTracks = (vData.audioTracks || {}) as Record<string, string>;
    const aiDubbed = (vData.aiDubbedAudio || {}) as Record<string, string>;

    const updates: Record<string, string> = {};
    for (const r of results) {
      const currentTrack = audioTracks[r.language];
      if (currentTrack && (currentTrack === r.audioUrl || normalizeUrl(currentTrack, bucketName) === r.audioUrl)) {
        if (!aiDubbed[r.language] || aiDubbed[r.language] !== currentTrack) {
          updates[r.language] = currentTrack;
        }
      }
    }

    if (Object.keys(updates).length > 0) {
      proposedUpdates++;
      console.log(`[DRY RUN] Video ${vid}:`);
      for (const [l, u] of Object.entries(updates)) {
        console.log(`  + aiDubbedAudio.${l} = "${u}"`);
      }

      if (APPLY) {
        const docUpdates: Record<string, any> = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        for (const [l, u] of Object.entries(updates)) {
          docUpdates[`aiDubbedAudio.${l}`] = u;
        }
        await db.collection("videos").doc(vid).update(docUpdates);
        console.log(`  -> Applied update to videos/${vid}`);
      }
    }
  }

  console.log("─".repeat(70));
  console.log(`[Backfill Summary]`);
  console.log(`  Total videos with dubbing results evaluated: ${evaluatedVideos}`);
  console.log(`  Videos requiring aiDubbedAudio backfill: ${proposedUpdates}`);
  console.log(`  Execution mode: ${APPLY ? "APPLIED" : "DRY RUN ONLY (no changes made)"}`);
}

async function main() {
  if (FIXTURE_PATH) {
    await runWithFixture(FIXTURE_PATH);
  } else {
    await runLiveFirestore();
  }
}

main().catch((err) => {
  console.error("[Backfill Error]", err);
  process.exit(1);
});
