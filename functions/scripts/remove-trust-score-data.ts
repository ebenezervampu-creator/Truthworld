/**
 * One-off cleanup: deletes the stored data of the removed trust-score features from Firestore.
 *
 * The app no longer writes or reads any of these fields. Old documents still carry them,
 * and older app versions still installed on phones could keep showing them, so run this
 * after the new app version is live.
 *
 * DRY RUN by default: it only counts what it would delete. Pass --apply to delete.
 *
 * Usage (from functions/, with Application Default Credentials for the project):
 *   npx ts-node scripts/remove-trust-score-data.ts            # dry run, prints counts
 *   npx ts-node scripts/remove-trust-score-data.ts --apply    # deletes
 *
 * What it removes:
 *   videos/*                        trust label / index, provisional score + label, score factors
 *   videos/{id}/media/credibility   the same score fields on the credibility subdocument
 *   video_jobs/*                    outputs.trustLabel
 *   channels/*                      reputation map, stats.avgTrustIndex, stats.channelRating
 *   comments/*                      userTrustIndex, authorRankScore
 *   users/*                         trustScore, creatorTrustVersion, factors
 *   userTrust/*                     score (strike and approval counts are kept)
 *   credibility_jobs/*              reputationUpdated
 *   creator_reputation, speaker_reputation   whole collections
 */
import * as admin from "firebase-admin";

const APPLY = process.argv.includes("--apply");
const PAGE = 500;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "truthworld-1" });
}
const db = admin.firestore();
const del = admin.firestore.FieldValue.delete();

/** Field paths to delete, per collection (or collection group). */
const FIELD_TARGETS: Array<{ label: string; query: () => FirebaseFirestore.Query; fields: string[] }> = [
  {
    label: "videos",
    query: () => db.collection("videos"),
    fields: [
      "trustLabel", "trustIndex", "provisionalScore", "provisionalLabel", "scoringFactors", "deductions",
      "harmCapApplied", "harmCapReason", "categoryWeightProfile", "intentToMisleadScore", "hardeningMetadata",
      "verticalScores", "compositeRating", "honestRating",
    ],
  },
  {
    label: "videos/*/media/credibility",
    query: () => db.collectionGroup("media"),
    fields: [
      "trustLabel", "scoringFactors", "deductions", "harmCapApplied", "harmCapReason",
      "categoryWeightProfile", "intentToMisleadScore", "hardeningMetadata",
    ],
  },
  { label: "video_jobs", query: () => db.collection("video_jobs"), fields: ["outputs.trustLabel"] },
  { label: "channels", query: () => db.collection("channels"), fields: ["reputation", "stats.avgTrustIndex", "stats.channelRating"] },
  { label: "comments", query: () => db.collection("comments"), fields: ["userTrustIndex", "authorRankScore"] },
  { label: "users", query: () => db.collection("users"), fields: ["trustScore", "creatorTrustVersion", "factors"] },
  { label: "userTrust", query: () => db.collection("userTrust"), fields: ["score"] },
  { label: "credibility_jobs", query: () => db.collection("credibility_jobs"), fields: ["reputationUpdated"] },
];

const DELETED_COLLECTIONS = ["creator_reputation", "speaker_reputation"];

function hasPath(data: FirebaseFirestore.DocumentData, path: string): boolean {
  let cur: any = data;
  for (const part of path.split(".")) {
    if (cur === null || typeof cur !== "object" || !(part in cur)) return false;
    cur = cur[part];
  }
  return true;
}

async function cleanFields(target: (typeof FIELD_TARGETS)[number], writer: FirebaseFirestore.BulkWriter): Promise<number> {
  let touched = 0;
  let scanned = 0;
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  const isMediaGroup = target.label.startsWith("videos/*/media");

  for (;;) {
    let q = target.query()
      .orderBy(admin.firestore.FieldPath.documentId())
      .select(...target.fields)
      .limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned++;
      if (isMediaGroup && doc.id !== "credibility") continue;
      const present = target.fields.filter((f) => hasPath(doc.data(), f));
      if (present.length === 0) continue;
      touched++;
      if (APPLY) {
        const update: Record<string, FirebaseFirestore.FieldValue> = {};
        for (const f of present) update[f] = del;
        writer.update(doc.ref, update);
      }
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }
  console.log(`${target.label}: scanned ${scanned}, ${APPLY ? "cleaned" : "would clean"} ${touched}`);
  return touched;
}

async function dropCollection(name: string, writer: FirebaseFirestore.BulkWriter): Promise<number> {
  let count = 0;
  for (;;) {
    const snap = await db.collection(name).select().limit(PAGE).get();
    if (snap.empty) break;
    count += snap.size;
    if (!APPLY) {
      // Dry run: count the rest without deleting.
      const total = await db.collection(name).count().get();
      count = total.data().count;
      break;
    }
    for (const doc of snap.docs) writer.delete(doc.ref);
    await writer.flush();
  }
  console.log(`${name}: ${APPLY ? "deleted" : "would delete"} ${count} documents`);
  return count;
}

async function run() {
  console.log(APPLY ? "APPLY mode: deleting trust-score data." : "DRY RUN: nothing will be deleted. Re-run with --apply to delete.");
  const writer = db.bulkWriter();
  writer.onWriteError((err) => {
    console.error(`Write failed for ${err.documentRef.path}: ${err.message}`);
    return err.failedAttempts < 3;
  });

  for (const target of FIELD_TARGETS) {
    await cleanFields(target, writer);
    await writer.flush();
  }
  for (const name of DELETED_COLLECTIONS) {
    await dropCollection(name, writer);
  }
  await writer.close();
  console.log("Done.");
}

run().catch((err) => {
  console.error("Cleanup failed:", err);
  process.exit(1);
});
