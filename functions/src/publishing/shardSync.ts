/**
 * 🔄 SHARD SYNCHRONIZATION TRIGGER
 *
 * Event-Driven Replication: Syncs Canonical Truth (video_jobs) to Shards (UI Replicas)
 *
 * ✅ ON-WRITE: Covers Create, Update, and Delete lifecycles.
 * ✅ LOOP-FREE: Only triggers on the central collection.
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "../pipeline/utils/logger";

export const syncJobToShard = onDocumentWritten(
  {
    document: "video_jobs/{jobId}",
    region: "asia-south1",
    retry: true,
    memory: "256MiB",
    maxInstances: 2,
  },
  async (event: any) => {
    const jobId = event.params.jobId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    const db = admin.firestore();

    // 1. Deletion Sync
    if (!afterData) {
      if (beforeData) {
        const shard = beforeData.shard || "0";
        logger.info("[Sync] Deleting shard replica", { jobId, shard });
        await db.collection(`video_jobs_${shard}`).doc(jobId).delete();
      }
      return;
    }

    // 2. Upsert Sync (Create/Update)
    const shard = afterData.shard || "0";
    const version = afterData.version || 0;

    // Skip if version hasn't changed (reliable field-level check)
    if (beforeData) {
      const beforeVersion = beforeData.version || 0;
      const beforeUpdatedAt = beforeData.updatedAt || 0;
      const afterUpdatedAt = afterData.updatedAt || 0;
      if (beforeVersion === version && beforeUpdatedAt === afterUpdatedAt) {
        return;
      }
    }

    logger.debug("[Sync] Replicating to shard", { jobId, shard, version });

    const replicaData = {
      ...afterData,
      replicaSyncedAt: Date.now(),
      replicatedFromVersion: version,
    };

    await db.collection(`video_jobs_${shard}`).doc(jobId).set(replicaData, { merge: true });
  }
);
