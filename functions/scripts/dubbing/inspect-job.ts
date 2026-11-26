/**
 * Prints what the pipeline knew about a stretch of a local test job (Firestore emulator only):
 * transcript words and lines, the reel metadata's word timings and line windows, and the dub
 * sync report. Read-only. Added 2026-11-25 to diagnose "Dubbed speech missing … at 10.6s".
 *
 *   $env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
 *   npx ts-node --transpile-only scripts/dubbing/inspect-job.ts --job=localdub_te_1795595969946 --from=5 --to=30
 */
import * as admin from "firebase-admin";

function arg(name: string, fallback = ""): string {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

async function main(): Promise<void> {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.error("Set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 first (read-only, emulator only).");
    process.exit(1);
  }
  const jobId = arg("job");
  const fromMs = Number(arg("from", "0")) * 1000;
  const toMs = Number(arg("to", "30")) * 1000;
  if (!jobId) {
    console.error("Pass --job=<jobId>");
    process.exit(1);
  }
  admin.initializeApp({ projectId: "truthworld-1" });
  const db = admin.firestore();
  const inRange = (s: number, e: number) => e >= fromMs && s <= toMs;
  const sec = (ms: number) => (ms / 1000).toFixed(2);

  const transcript = (await db.collection("transcripts").doc(jobId).get()).data() || {};
  const words: any[] = Array.isArray(transcript.words) ? transcript.words : [];
  const utterances: any[] = Array.isArray(transcript.utterances) ? transcript.utterances : [];
  console.log(`\n== Transcript: ${words.length} words, ${utterances.length} lines (showing ${sec(fromMs)}–${sec(toMs)} s)`);
  console.log("-- Lines (speaker, start–end, first/last word times, text):");
  for (const u of utterances) {
    if (!inRange(u.start, u.end)) continue;
    const uw: any[] = Array.isArray(u.words) ? u.words : [];
    const fw = uw[0];
    const lw = uw[uw.length - 1];
    console.log(`  ${u.speaker}  ${sec(u.start)}–${sec(u.end)}  words ${fw ? sec(fw.start) : "?"}…${lw ? sec(lw.end) : "?"}  "${String(u.text || "").slice(0, 120)}"`);
  }
  console.log("-- Words:");
  for (const w of words) {
    if (inRange(w.start, w.end)) console.log(`  ${sec(w.start)}–${sec(w.end)}  ${w.speaker ?? ""}  ${w.text}`);
  }

  const meta = (await db.collection("video_jobs").doc(jobId).collection("reel_orchestration").doc("meta").get()).data();
  if (meta) {
    const flat: number[] = Array.isArray(meta.wordSpans) ? meta.wordSpans : [];
    console.log(`\n== Reel meta: wordSpans ${flat.length / 2} words; old 'words' field: ${Array.isArray(meta.words) ? meta.words.length : "absent"}`);
    for (let i = 0; i + 1 < flat.length; i += 2) {
      if (inRange(flat[i], flat[i + 1])) console.log(`  word ${sec(flat[i])}–${sec(flat[i + 1])}`);
    }
    console.log("-- Line windows used by the assembler (meta.segments):");
    for (const s of meta.segments || []) {
      if (inRange(s.start, s.end)) console.log(`  ${s.speaker}  ${sec(s.start)}–${sec(s.end)}`);
    }
  } else {
    console.log("\n== No reel metadata (short video path).");
  }

  const job = (await db.collection("video_jobs").doc(jobId).get()).data() || {};
  const mix = job?.artifacts?.faithfulMix || {};
  for (const [lang, rep] of Object.entries<any>(mix)) {
    console.log(`\n== Sync report (${lang}): ${JSON.stringify(rep?.syncReport || null)}`);
  }
}

main().catch((err) => {
  console.error(err?.message || err);
  process.exit(1);
});
