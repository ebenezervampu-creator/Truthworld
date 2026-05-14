import * as admin from "firebase-admin";

/**
 * 🛠️ MIGRATION: BACKFILL CANONICAL TRUTH
 * 
 * Logic:
 * 1. Iterate over central 'video_jobs' (index).
 * 2. For docs missing a 'version' field (legacy):
 *    a. Extract 'shard' and 'jobId'.
 *    b. Fetch full document from 'video_jobs_shard_X'.
 *    c. Write full document to central 'video_jobs' with version: 1.
 *    d. This automatically triggers 'syncJobToShard' for replication.
 */
async function backfillCanonicalTruth() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  
  const db = admin.firestore();
  const indexDocs = await db.collection("video_jobs").get();
  
  console.log(`[Migration] Found ${indexDocs.size} jobs to verify.`);
  
  let migrated = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of indexDocs.docs) {
    const jobId = doc.id;
    const data = doc.data();

    if (data.version) {
      skipped++;
      continue;
    }

    try {
      const shard = data.shard || "0";
      const fullDoc = await db.collection(`video_jobs_${shard}`).doc(jobId).get();
      
      if (!fullDoc.exists) {
        console.warn(`[Migration] No shard doc found for legacy job ${jobId} (shard ${shard})`);
        failed++;
        continue;
      }

      const fullData = fullDoc.data();
      
      // Establish canonical truth in central collection
      await db.collection("video_jobs").doc(jobId).set({
        ...fullData,
        version: 1, // Set initial version
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Migration] Successfully migrated ${jobId} to canonical truth.`);
      migrated++;
    } catch (err) {
      console.error(`[Migration] Failed to migrate ${jobId}:`, err);
      failed++;
    }
  }

  console.log(`\n[Migration] COMPLETED`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Migrated: ${migrated}`);
  console.log(`Skipped:  ${skipped} (already canonical)`);
  console.log(`Failed:   ${failed}`);
}

backfillCanonicalTruth().catch(console.error);
