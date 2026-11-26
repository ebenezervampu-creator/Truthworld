import * as admin from "firebase-admin";
import { getTypesenseAdminClient, isTypesenseConfigured } from "./typesenseClient";
import { initializeCollections } from "./initCollections";
import {
  mapVideoToTypesense,
  mapChannelToTypesense,
  mapTopicToTypesense,
  TypesenseVideoDoc,
  TypesenseChannelDoc,
  TypesenseTopicDoc,
} from "./typesenseMappers";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export async function backfillTypesense(): Promise<{
  channelsCount: number;
  topicsCount: number;
  videosCount: number;
}> {
  if (!isTypesenseConfigured()) {
    throw new Error("Typesense search cluster is not configured in this environment.");
  }
  console.log("🚀 Starting Typesense Backfill from Firestore...");
  await initializeCollections();

  const client = getTypesenseAdminClient();

  // 1. Backfill Channels
  console.log("📂 Fetching channels from Firestore...");
  const channelSnap = await db.collection("channels").get();
  const channelDocs: TypesenseChannelDoc[] = [];

  for (const doc of channelSnap.docs) {
    const mapped = mapChannelToTypesense(doc.id, doc.data());
    if (mapped) {
      channelDocs.push(mapped);
    }
  }

  if (channelDocs.length > 0) {
    console.log(`📤 Importing ${channelDocs.length} channels to Typesense...`);
    const res = await client.collections("channels").documents().import(channelDocs, { action: "upsert" });
    const successCount = res.filter((r) => r.success).length;
    console.log(`✅ Channels backfilled: ${successCount} / ${channelDocs.length}`);
  } else {
    console.log("ℹ️ No channels to index.");
  }

  // 2. Backfill Topics
  console.log("📂 Fetching topics from Firestore...");
  const topicSnap = await db.collection("topics").get();
  const topicDocs: TypesenseTopicDoc[] = [];

  for (const doc of topicSnap.docs) {
    const mapped = mapTopicToTypesense(doc.id, doc.data());
    if (mapped) {
      topicDocs.push(mapped);
    }
  }

  if (topicDocs.length > 0) {
    console.log(`📤 Importing ${topicDocs.length} topics to Typesense...`);
    const res = await client.collections("topics").documents().import(topicDocs, { action: "upsert" });
    const successCount = res.filter((r) => r.success).length;
    console.log(`✅ Topics backfilled: ${successCount} / ${topicDocs.length}`);
  } else {
    console.log("ℹ️ No topics to index.");
  }

  // 3. Backfill Videos (Batched in chunks of 100)
  console.log("📂 Fetching videos from Firestore...");
  const videoSnap = await db.collection("videos").get();
  const videoDocs: TypesenseVideoDoc[] = [];

  for (const doc of videoSnap.docs) {
    const mapped = mapVideoToTypesense(doc.id, doc.data());
    if (mapped) {
      videoDocs.push(mapped);
    }
  }

  if (videoDocs.length > 0) {
    console.log(`📤 Importing ${videoDocs.length} videos to Typesense in batches...`);
    const BATCH_SIZE = 100;
    let totalSuccess = 0;

    for (let i = 0; i < videoDocs.length; i += BATCH_SIZE) {
      const batch = videoDocs.slice(i, i + BATCH_SIZE);
      const res = await client.collections("videos").documents().import(batch, { action: "upsert" });
      const batchSuccess = res.filter((r) => r.success).length;
      totalSuccess += batchSuccess;
      console.log(`  - Imported batch ${Math.floor(i / BATCH_SIZE) + 1} (${batchSuccess}/${batch.length})`);
    }

    console.log(`✅ Videos backfilled: ${totalSuccess} / ${videoDocs.length}`);
  } else {
    console.log("ℹ️ No videos to index.");
  }

  console.log("🎉 Typesense backfill complete!");
  return {
    channelsCount: channelDocs.length,
    topicsCount: topicDocs.length,
    videosCount: videoDocs.length,
  };
}

import { onCall, HttpsError } from "firebase-functions/v2/https";

/**
 * Callable Cloud Function to trigger backfill from Admin portal or Cloud Console.
 */
export const triggerTypesenseBackfill = onCall(
  {
    region: "asia-south1",
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Super Admin authentication required.");
    }

    if (!isTypesenseConfigured()) {
      throw new HttpsError(
        "failed-precondition",
        "Typesense search cluster is not configured in this environment."
      );
    }
    try {
      const result = await backfillTypesense();
      return { success: true, ...result };
    } catch (err: any) {
      throw new HttpsError("internal", err?.message || "Backfill failed");
    }
  }
);

if (require.main === module) {
  backfillTypesense()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Fatal backfill error:", err);
      process.exit(1);
    });
}
