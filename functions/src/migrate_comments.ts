import * as admin from "firebase-admin";

// Initialize Firebase Admin with default credentials
admin.initializeApp();
const db = admin.firestore();

async function runMigration() {
  console.log("🚀 Starting comment replyCount backfill migration...");
  const videosSnapshot = await db.collection("videos").get();
  console.log(`📹 Found ${videosSnapshot.size} videos.`);

  let commentsUpdated = 0;

  for (const videoDoc of videosSnapshot.docs) {
    const videoId = videoDoc.id;
    const commentsSnapshot = await db
      .collection("videos")
      .doc(videoId)
      .collection("comments")
      .get();

    if (commentsSnapshot.size > 0) {
      console.log(`  💬 Processing ${commentsSnapshot.size} comments for video: ${videoId}...`);
    }

    for (const commentDoc of commentsSnapshot.docs) {
      const commentId = commentDoc.id;
      const repliesSnapshot = await db
        .collection("videos")
        .doc(videoId)
        .collection("comments")
        .doc(commentId)
        .collection("replies")
        .get();

      const replyCount = repliesSnapshot.size;

      await commentDoc.ref.update({
        replyCount: replyCount
      });
      commentsUpdated++;
    }
  }

  console.log(`\n✅ Backfill migration completed successfully!`);
  console.log(`📝 Total comments backfilled: ${commentsUpdated}\n`);
}

runMigration().catch(err => {
  console.error("❌ Migration failed:", err);
  process.exit(1);
});
