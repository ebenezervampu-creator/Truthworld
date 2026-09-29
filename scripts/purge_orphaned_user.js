/**
 * 🧹 PURGE ORPHANED USER SUBCOLLECTIONS SCRIPT
 *
 * Usage:
 *   node scripts/purge_orphaned_user.js <UID>
 *
 * Example:
 *   node scripts/purge_orphaned_user.js BA9Qphy87aOOwtlhOUq8tmpYfRa2
 */

const path = require("path");
// Require firebase-admin from functions directory
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));

const uid = process.argv[2];
if (!uid || uid.trim().length === 0) {
  console.error("❌ Error: Missing user UID argument.");
  console.error("Usage: node scripts/purge_orphaned_user.js <UID>");
  process.exit(1);
}

const targetUid = uid.trim();

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "truthworld-1",
  });
}

const db = admin.firestore();

const knownSubcollections = [
  "watch_history",
  "liked_videos",
  "likedVideos",
  "disliked_videos",
  "dislikedVideos",
  "watch_later",
  "playlists",
  "saved_playlists",
  "clips",
  "liked_clips",
  "feed_inbox",
  "savedTopics",
  "likedTopics",
  "liked_topic_comments",
  "liked_topic_replies",
  "comment_interactions",
  "reply_interactions",
  "savedCommunityPosts",
  "savedComments",
  "hiddenCommunityPosts",
  "mutedCommunityChannels",
  "reportedCommunityPosts",
  "subscriptions",
  "channelMemberships",
  "channel_memberships",
  "notifications_active",
  "notifications_archive",
  "saved_ads",
];

async function purgeOrphanedUser(userId) {
  console.log(`\n🧹 Starting deep subcollection purge for user UID: "${userId}"...`);
  const userRef = db.collection("users").doc(userId);

  // 1. Discover subcollections dynamically via listCollections
  try {
    const subcollections = await userRef.listCollections();
    console.log(`🔍 Found ${subcollections.length} dynamically listed subcollection(s).`);
    for (const col of subcollections) {
      console.log(`   Deleting dynamic subcollection: ${col.id}...`);
      await db.recursiveDelete(col);
      console.log(`   ✅ Purged subcollection: ${col.id}`);
    }
  } catch (err) {
    console.warn(`⚠️ Warning listing dynamic subcollections: ${err.message}`);
  }

  // 2. Explicitly recursive delete all known subcollections
  for (const colName of knownSubcollections) {
    try {
      const colRef = userRef.collection(colName);
      await db.recursiveDelete(colRef);
    } catch (err) {
      // ignore
    }
  }
  console.log(`✅ Checked and purged all known subcollections (including watch_history).`);

  // 3. Purge user cache if present
  try {
    const userCacheRef = db.collection("userCache").doc(userId);
    await db.recursiveDelete(userCacheRef);
    console.log(`✅ Purged userCache for ${userId}`);
  } catch (err) {
    // ignore
  }

  // 4. Purge parent document
  try {
    await db.recursiveDelete(userRef);
    console.log(`✅ Recursively deleted users/${userId} reference.`);
  } catch (err) {
    console.warn(`⚠️ Warning deleting userRef: ${err.message}`);
  }

  console.log(`\n🎉 Successfully purged all orphaned subcollections and data for user: ${userId}!\n`);
}

purgeOrphanedUser(targetUid)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Fatal error purging user subcollections:", err);
    process.exit(1);
  });
