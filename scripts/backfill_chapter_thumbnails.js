/**
 * 📸 BACKFILL DISCRETE CHAPTER THUMBNAILS
 *
 * Usage:
 *   node scripts/backfill_chapter_thumbnails.js [videoId]
 *
 * If videoId is provided, extracts and updates discrete chapter thumbnails for that specific video.
 * If omitted, scans the 'videos' collection for any video with chapters lacking distinct thumbnails
 * and generates high-quality 640x360 qHD thumbnails at representative keyframe offsets.
 */

const path = require("path");
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "truthworld-1",
    databaseURL: "https://truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "truthworld-1.firebasestorage.app",
  });
}

const { generateHighQualityChapterThumbnailsForVideo } = require(path.join(__dirname, "../functions/lib/resolution/resolution.js"));

async function main() {
  const targetVideoId = process.argv[2]?.trim();
  const db = admin.firestore();

  if (targetVideoId) {
    console.log(`[Backfill] Processing specified video: ${targetVideoId}...`);
    try {
      const updated = await generateHighQualityChapterThumbnailsForVideo(targetVideoId);
      console.log(`✅ Success! Updated ${updated.length} chapters with discrete thumbnails for video ${targetVideoId}`);
    } catch (err) {
      console.error(`❌ Error backfilling video ${targetVideoId}:`, err);
    }
    return;
  }

  console.log("[Backfill] Scanning 'videos' collection for videos needing chapter thumbnails...");
  const snap = await db.collection("videos").get();
  console.log(`[Backfill] Found ${snap.docs.length} total videos.`);

  let processedCount = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const chapters = Array.isArray(data.chapters) ? data.chapters : (Array.isArray(data.autoChapters) ? data.autoChapters : []);
    if (chapters.length === 0) continue;

    // Check if any chapter is missing a thumbnail or has the video's main thumbnail
    const videoThumb = data.thumbnailUrl || "";
    const needsBackfill = chapters.some((ch, idx) => {
      if (!ch.thumbnailUrl || ch.thumbnailUrl.trim() === "") return true;
      if (idx > 0 && ch.thumbnailUrl === videoThumb) return true;
      return false;
    });

    if (needsBackfill) {
      console.log(`[Backfill] Video ${doc.id} ("${data.title || "Untitled"}") needs chapter thumbnails. Generating...`);
      try {
        const updated = await generateHighQualityChapterThumbnailsForVideo(doc.id);
        console.log(`  -> Video ${doc.id}: ${updated.length} chapters updated.`);
        processedCount++;
      } catch (err) {
        console.warn(`  -> Failed for video ${doc.id}:`, err?.message || err);
      }
    }
  }

  console.log(`🎉 Backfill complete! Processed ${processedCount} videos.`);
}

main().catch(err => {
  console.error("Fatal error:", err);
  process.exit(1);
});
