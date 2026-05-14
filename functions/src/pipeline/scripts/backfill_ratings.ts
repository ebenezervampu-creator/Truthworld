import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Phase 3 Backfill Script
 * 
 * Migrates `trustIndex` to `videoRating` in the `videos` collection.
 * Migrates `reputation.avgTrustIndex` to `reputation.channelRating` in the `channels` collection.
 */
async function backfillRatings() {
  console.log("🚀 Starting Backfill: trustIndex -> videoRating & channelRating");

  let processedVideos = 0;
  let updatedVideos = 0;
  let processedChannels = 0;
  let updatedChannels = 0;

  try {
    // 1. Backfill Videos
    console.log("⏳ Processing 'videos' collection...");
    const videosSnap = await db.collection("videos").get();
    
    const videoBatches = [];
    let currentVideoBatch = db.batch();
    let videoOpsInBatch = 0;

    for (const doc of videosSnap.docs) {
      processedVideos++;
      const data = doc.data();

      // If it doesn't have videoRating but has trustScore/trustIndex
      if (data.videoRating === undefined && (data.trustIndex !== undefined || data.trustScore !== undefined)) {
        const rating = data.trustIndex ?? data.trustScore;
        currentVideoBatch.update(doc.ref, { videoRating: rating });
        updatedVideos++;
        videoOpsInBatch++;

        if (videoOpsInBatch === 500) {
          videoBatches.push(currentVideoBatch.commit());
          currentVideoBatch = db.batch();
          videoOpsInBatch = 0;
        }
      }
    }
    
    if (videoOpsInBatch > 0) {
      videoBatches.push(currentVideoBatch.commit());
    }

    await Promise.all(videoBatches);
    console.log(`✅ Videos backfilled. Processed: ${processedVideos}, Updated: ${updatedVideos}`);

    // 2. Backfill Channels
    console.log("⏳ Processing 'channels' collection...");
    const channelsSnap = await db.collection("channels").get();
    
    const channelBatches = [];
    let currentChannelBatch = db.batch();
    let channelOpsInBatch = 0;

    for (const doc of channelsSnap.docs) {
      processedChannels++;
      const data = doc.data();

      const rep = data.reputation || {};
      const stats = data.stats || {};

      let needsUpdate = false;
      const updateData: any = {};

      if (rep.channelRating === undefined && rep.avgTrustIndex !== undefined) {
        updateData["reputation.channelRating"] = rep.avgTrustIndex;
        needsUpdate = true;
      }

      if (stats.channelRating === undefined && stats.avgTrustIndex !== undefined) {
        updateData["stats.channelRating"] = stats.avgTrustIndex;
        needsUpdate = true;
      }

      if (needsUpdate) {
        currentChannelBatch.update(doc.ref, updateData);
        updatedChannels++;
        channelOpsInBatch++;

        if (channelOpsInBatch === 500) {
          channelBatches.push(currentChannelBatch.commit());
          currentChannelBatch = db.batch();
          channelOpsInBatch = 0;
        }
      }
    }

    if (channelOpsInBatch > 0) {
      channelBatches.push(currentChannelBatch.commit());
    }

    await Promise.all(channelBatches);
    console.log(`✅ Channels backfilled. Processed: ${processedChannels}, Updated: ${updatedChannels}`);

    console.log("🎉 Backfill completed successfully!");
  } catch (error) {
    console.error("❌ Error during backfill:", error);
  }
}

// Execute if run directly
if (require.main === module) {
  backfillRatings().then(() => process.exit(0)).catch(() => process.exit(1));
}
