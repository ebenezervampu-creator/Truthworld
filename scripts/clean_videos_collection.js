/**
 * 🧹 PURGE PHANTOM, DUPLICATE & ORPHANED VIDEO DOCUMENTS
 *
 * TruthWorld Database Sanitation Script
 *
 * Usage:
 *   node scripts/clean_videos_collection.js [--execute]
 *
 * By default runs in DRY-RUN mode. Pass `--execute` to perform the actual deletions.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { OAuth2Client } = require(path.join(process.cwd(), 'functions/node_modules/google-auth-library'));
const { Firestore } = require(path.join(process.cwd(), 'functions/node_modules/@google-cloud/firestore'));

const p = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
if (!fs.existsSync(p)) {
  console.error('❌ Error: firebase-tools.json not found in configstore.');
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(p, 'utf8'));
const client = new OAuth2Client();
client.setCredentials(data.tokens);
const firestore = new Firestore({ projectId: 'truthworld-1', authClient: client });

const isExecute = process.argv.includes('--execute');

// The 3 authentic videos that belong in Truthworld
const LEGITIMATE_VIDEO_IDS = [
  '1f2a001f-c96b-4313-8737-003d1b2f11d4', // Zomato’s Big Transformation
  'b7df4415-6851-417f-9113-6d16ecf4fa12', // Are Eggs Vegetarian or Non-Vegetarian?
  '7f8cffa5-aa1e-4eb8-9319-319076726c6e'  // Pellichupullo AI Gola (Mana Comedy)
];

// Stale / deleted / phantom video IDs to purge from search and hashes
const STALE_OR_DELETED_VIDEO_IDS = [
  '1e75b6e5-6977-4483-bed3-d3ab3135e163', // Phantom doc (media subcollection only)
  '64fed08b-c921-40d4-8c3c-be954b1835dd', // Phantom doc (media, shards, views subcollections)
  '3c9cc726-7316-40a8-8d5e-253d00170034', // Trashed / deletion_pending doc
  '097e6c27-a49d-43c7-b282-f7cad38cb872', // Ghost empty entry
  '316da5f9-67cc-4264-869a-13d0a12d6a91', // Duplicate search record
  '4f2caccd-4d72-4f25-bae2-0e94f2516982', // Duplicate search record
];

async function main() {
  console.log(`\n======================================================`);
  console.log(`🧹 TruthWorld Video Collection Purge & Sanitize Tool`);
  console.log(`   Mode: ${isExecute ? '🚀 EXECUTE (LIVE)' : '🔍 DRY-RUN (PREVIEW)'}`);
  console.log(`======================================================\n`);

  // 1. Inspect all document references in 'videos' collection
  const videoRefs = await firestore.collection('videos').listDocuments();
  console.log(`📊 Total document references currently in 'videos': ${videoRefs.length}\n`);

  const toKeep = [];
  const toPurge = [];

  for (const ref of videoRefs) {
    const snap = await ref.get();
    const subcols = await ref.listCollections();
    const subcolNames = subcols.map(c => c.id);

    if (LEGITIMATE_VIDEO_IDS.includes(ref.id)) {
      toKeep.push({
        id: ref.id,
        title: snap.data()?.title,
        status: snap.data()?.status,
        subcollections: subcolNames
      });
    } else {
      toPurge.push({
        ref,
        id: ref.id,
        exists: snap.exists,
        title: snap.data()?.title,
        status: snap.data()?.status,
        subcollections: subcolNames
      });
    }
  }

  console.log(`✅ Legitimate Videos to PRESERVE (${toKeep.length}):`);
  toKeep.forEach(v => {
    console.log(`   • [${v.id}] "${v.title}" (status: ${v.status}, subcols: [${v.subcollections.join(', ')}])`);
  });

  console.log(`\n❌ Stale / Phantom / Non-video documents to PURGE (${toPurge.length}):`);
  toPurge.forEach(v => {
    console.log(`   • [${v.id}] exists=${v.exists}, title="${v.title || '(none)'}", status=${v.status || '(none)'}, subcols=[${v.subcollections.join(', ')}]`);
  });

  if (isExecute) {
    console.log(`\n🔥 Starting Recursive Deletion of stale / phantom documents...`);
    for (const item of toPurge) {
      console.log(`   Purging videos/${item.id} (and all descendant subcollections)...`);
      await firestore.recursiveDelete(item.ref);
      console.log(`   ✅ Purged videos/${item.id}`);
    }

    // 2. Clean up video_search collection
    console.log(`\n🔍 Sanitizing video_search collection...`);
    const searchDocs = await firestore.collection('video_search').listDocuments();
    for (const sRef of searchDocs) {
      if (!LEGITIMATE_VIDEO_IDS.includes(sRef.id)) {
        console.log(`   Deleting orphaned search record: video_search/${sRef.id}`);
        await sRef.delete();
      }
    }

    // 3. Clean up video_hashes
    console.log(`\n🔑 Sanitizing video_hashes collection...`);
    const hashDocs = await firestore.collection('video_hashes').get();
    for (const hDoc of hashDocs.docs) {
      const hData = hDoc.data();
      const jobId = hData.jobId || '';
      const isStale = STALE_OR_DELETED_VIDEO_IDS.some(sid => jobId.includes(sid));
      if (isStale) {
        console.log(`   Deleting orphaned video hash: ${hDoc.id} (jobId: ${jobId})`);
        await hDoc.ref.delete();
      }
    }

    // 4. Clean up resolution_jobs & transcripts for purged videos
    console.log(`\n🧹 Sanitizing ancillary pipeline jobs...`);
    for (const sid of STALE_OR_DELETED_VIDEO_IDS) {
      await firestore.collection('resolution_jobs').doc(sid).delete().catch(() => {});
      await firestore.collection('transcripts').doc(sid).delete().catch(() => {});
      await firestore.collection('cost_metrics').doc(sid).delete().catch(() => {});
      await firestore.collection('credibility_drafts').doc(sid).delete().catch(() => {});
      await firestore.collection('video_jobs').doc(sid).delete().catch(() => {});
      await firestore.collection('video_jobs_0').doc(sid).delete().catch(() => {});
    }

    // 5. Reconcile Channel Counts
    console.log(`\n📊 Reconciling channel videoCount...`);
    const channels = await firestore.collection('channels').get();
    for (const cDoc of channels.docs) {
      const cId = cDoc.id;
      const vSnap = await firestore.collection('videos').where('channelId', '==', cId).get();
      let realCount = 0;
      vSnap.forEach(v => {
        const d = v.data();
        if (d.status !== 'deleted' && d.status !== 'deletion_pending') {
          realCount++;
        }
      });
      await cDoc.ref.update({
        videoCount: realCount
      });
      console.log(`   Channel ${cDoc.data()?.name || cId}: videoCount updated to ${realCount}`);
    }

    // 6. Verification
    console.log(`\n======================================================`);
    console.log(`🏁 VERIFICATION OF VIDEOS COLLECTION`);
    console.log(`======================================================`);

    const finalRefs = await firestore.collection('videos').listDocuments();
    console.log(`Total documents remaining in 'videos': ${finalRefs.length}`);

    let hasPhantom = false;
    for (const ref of finalRefs) {
      const snap = await ref.get();
      console.log(`   • ${ref.id} | exists=${snap.exists} | title="${snap.data()?.title}"`);
      if (!snap.exists) {
        hasPhantom = true;
      }
    }

    if (finalRefs.length === 3 && !hasPhantom) {
      console.log(`\n🎉 SUCCESS! 'videos' collection now contains EXACTLY 3 authentic videos with ZERO phantom documents!\n`);
    } else {
      console.warn(`\n⚠️ Warning: Final document count (${finalRefs.length}) or phantom document present (${hasPhantom})\n`);
    }
  } else {
    console.log(`\n💡 To execute this cleanup, run: node scripts/clean_videos_collection.js --execute\n`);
  }
}

main().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
