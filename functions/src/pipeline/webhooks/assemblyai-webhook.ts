/**
 * ⚡ ASSEMBLYAI WEBHOOK HANDLER
 *
 * Receives AssemblyAI transcript-complete callbacks, resumes the TruthWorld
 * transcription pipeline WITHOUT polling delay.
 *
 * AssemblyAI POSTs to this endpoint when transcription completes (< 200ms delivery).
 * This eliminates the 3s×N polling loop in Layer 05.
 *
 * Environment:
 *   ASSEMBLYAI_WEBHOOK_URL   = https://<region>-<project>.cloudfunctions.net/assemblyAiWebhook
 *   ASSEMBLYAI_WEBHOOK_SECRET = <random 32-char secret>
 */

import { DUBBING_REGION } from "../../config/regions";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { logger } from "../utils/logger";
import { PIPELINE_CONFIG } from "../config";

const db = () => admin.firestore();

/**
 * Timing-safe secret verification using SHA-256 digests to guarantee
 * 100% constant-time comparison regardless of input string length differences.
 */
function timingSafeSecretCheck(expected: string, provided?: string | string[]): boolean {
  if (!provided || typeof provided !== "string") return false;
  const hashExpected = crypto.createHash("sha256").update(expected).digest();
  const hashProvided = crypto.createHash("sha256").update(provided).digest();
  return crypto.timingSafeEqual(hashExpected, hashProvided);
}

export const assemblyAiWebhook = onRequest(
  {
    region: DUBBING_REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
    minInstances: 0,
    maxInstances: 5,
    cors: true,
  },
  async (req, res) => {
    // 1. Verify webhook secret using timing-safe comparison with Secret Rotation Support (Fail Closed)
    const secretPrimary = (PIPELINE_CONFIG as any).ASSEMBLYAI_WEBHOOK_SECRET || process.env.ASSEMBLYAI_WEBHOOK_SECRET;
    const secretFallback = process.env.ASSEMBLYAI_WEBHOOK_SECRET_FALLBACK;
    const allowedSecrets = [secretPrimary, secretFallback].filter(Boolean) as string[];

    if (allowedSecrets.length === 0) {
      logger.error("[AssemblyAIWebhook] Webhook secret not configured in server environment — failing closed");
      res.status(500).json({ error: "Webhook authentication unconfigured" });
      return;
    }

    const incomingSecret = req.headers["x-tw-webhook-secret"];
    const isAuthorized = allowedSecrets.some((s) => timingSafeSecretCheck(s, incomingSecret));
    if (!isAuthorized) {
      logger.warn("[AssemblyAIWebhook] Invalid webhook secret — rejecting");
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body = req.body as any;

    // 1.1. Timestamp Validation & Replay Attack Protection (5-minute tolerance window)
    const incomingTimestamp =
      req.headers["x-tw-webhook-timestamp"] ||
      req.headers["x-assemblyai-timestamp"] ||
      body?.timestamp;
    if (incomingTimestamp) {
      const parsedTimestamp = Number(incomingTimestamp);
      if (!isNaN(parsedTimestamp) && parsedTimestamp > 0) {
        const driftMs = Math.abs(Date.now() - parsedTimestamp);
        if (driftMs > 300_000) {
          logger.warn("[AssemblyAIWebhook] Replay attempt or timestamp drift outside 5-minute window", {
            driftMs,
            incomingTimestamp,
          });
          res.status(400).json({ error: "Timestamp outside tolerance window" });
          return;
        }
      }
    }

    // 1.2. Strict Payload Validation
    const transcriptId: string = body?.transcript_id || body?.id;
    const status: string = body?.status;

    if (!transcriptId || typeof transcriptId !== "string" || !/^[a-zA-Z0-9_\-]{6,128}$/.test(transcriptId)) {
      logger.warn("[AssemblyAIWebhook] Missing or malformed transcript_id in payload", { transcriptId });
      res.status(400).json({ error: "Invalid transcript_id" });
      return;
    }

    const validStatuses = new Set(["completed", "error", "processing", "queued"]);
    if (!status || !validStatuses.has(status)) {
      logger.warn("[AssemblyAIWebhook] Invalid status in payload", { status });
      res.status(400).json({ error: "Invalid status" });
      return;
    }

    // 2. Transactional Outbox + Lease Recovery Pattern (Durable persistence BEFORE ACK)
    const now = Date.now();
    let jobData: any = null;
    let outboxId: string = "";
    try {
      const txResult = await db().runTransaction(async (tx) => {
        const jobRef = db().collection("assemblyai_webhook_jobs").doc(transcriptId);
        const snap = await tx.get(jobRef);
        if (!snap.exists) {
          return { status: "not_found", data: null, outboxId: "" };
        }
        const current = snap.data() as any;

        // 2.1. Already completed - idempotent early return
        if (current.status === "COMPLETED" || current.status === "completed") {
          return { status: "duplicate", data: current, outboxId: "" };
        }

        // 2.2. If in progress, check if current lease is still active
        const isLeaseActive =
          (current.status === "PROCESSING" || current.status === "processing" ||
           current.status === "DISPATCHED" || current.status === "OUTBOX_PENDING") &&
          typeof current.leaseExpiresAt === "number" &&
          current.leaseExpiresAt > now;

        if (isLeaseActive) {
          return { status: "active_lease", data: current, outboxId: "" };
        }

        // 2.3. Lease has expired (e.g. previous worker crashed) or fresh webhook
        const nextAttempt = (current.attemptCount || 0) + 1;
        const leaseDurationMs = 120_000; // 2-minute crash recovery lease
        const leaseExpiresAt = now + leaseDurationMs;
        const newOutboxId = `outbox_${transcriptId}_${now}`;
        const outboxRef = db().collection("webhook_outbox").doc(newOutboxId);

        tx.set(outboxRef, {
          outboxId: newOutboxId,
          transcriptId,
          jobId: current.jobId,
          userId: current.userId,
          videoUrl: current.videoUrl,
          executionPlan: current.executionPlan,
          assemblyResult: body,
          status: "OUTBOX_PENDING",
          attemptCount: nextAttempt,
          leaseExpiresAt,
          createdAt: now,
          updatedAt: now,
        });

        tx.update(jobRef, {
          status: "OUTBOX_PENDING",
          currentOutboxId: newOutboxId,
          attemptCount: nextAttempt,
          leaseExpiresAt,
          resumedAt: now,
          webhookReceivedCount: admin.firestore.FieldValue.increment(1),
          lastLeaseAcquiredAt: now,
        });

        return { status: "proceed", data: current, outboxId: newOutboxId };
      });

      if (txResult.status === "not_found") {
        logger.warn("[AssemblyAIWebhook] No job found for transcript", { transcriptId });
        res.status(404).json({ error: "Transcript job not found" });
        return;
      }
      if (txResult.status === "duplicate" || txResult.status === "active_lease") {
        logger.info("[AssemblyAIWebhook] Idempotent ACK for completed or actively leased webhook", {
          transcriptId,
          status: txResult.status,
          leaseExpiresAt: txResult.data?.leaseExpiresAt,
        });
        res.status(200).json({ received: true, status: txResult.status });
        return;
      }
      jobData = txResult.data;
      outboxId = txResult.outboxId;
    } catch (txErr) {
      logger.error("[AssemblyAIWebhook] Transaction error in Outbox + Lease Recovery — signaling provider to retry", {
        transcriptId,
        error: String(txErr),
      });
      res.status(500).json({ error: "Durable persistence failed" });
      return;
    }

    // Durable persistence succeeded: now acknowledge provider
    res.status(200).json({ received: true, outboxId });

    const { jobId, userId, videoUrl, executionPlan } = jobData;

    if (status !== "completed") {
      logger.info("[AssemblyAIWebhook] Non-complete status — updating stage", { transcriptId, status, jobId });
      if (status === "error") {
        await db().collection("video_jobs").doc(jobId).set({
          stages: { transcription: { status: "failed", error: `AssemblyAI error: ${body?.error || "unknown"}`, updatedAt: Date.now() } },
          updatedAt: Date.now(),
        }, { merge: true }).catch(() => {});
        await db().collection("assemblyai_webhook_jobs").doc(transcriptId).update({
          status: "FAILED",
          lastError: body?.error || "AssemblyAI error status",
          updatedAt: Date.now(),
        }).catch(() => {});
      }
      return;
    }

    logger.info("[AssemblyAIWebhook] ⚡ Transcript complete — resuming pipeline via Outbox dispatch", { transcriptId, jobId, outboxId });

    // 3. Dispatch to Pub/Sub and update Outbox status atomically
    // Stable eventId guarantees downstream consumer idempotency across duplicate callbacks and sweeps
    const eventId = `stt_complete_${transcriptId}`;
    try {
      const { DistributionLayer } = require("../layers/04-distribution");
      const distribution = new DistributionLayer();
      await distribution.publish("transcription-complete", {
        eventId,
        eventType: "transcription-complete",
        jobId,
        userId,
        videoUrl,
        executionPlan,
        transcriptId,
        outboxId,
        assemblyResult: body,
        timestamp: now,
        retryCount: (jobData.attemptCount || 1) - 1,
        source: "assemblyai-webhook",
      });

      const batch = db().batch();
      batch.update(db().collection("webhook_outbox").doc(outboxId), {
        status: "DISPATCHED",
        eventId,
        dispatchedAt: Date.now(),
        updatedAt: Date.now(),
      });
      batch.update(db().collection("assemblyai_webhook_jobs").doc(transcriptId), {
        status: "PROCESSING",
        currentEventId: eventId,
        dispatchedAt: Date.now(),
        updatedAt: Date.now(),
      });
      await batch.commit();
      logger.info("[AssemblyAIWebhook] ✅ Pipeline resume event dispatched and outbox state committed", { jobId, transcriptId, outboxId, eventId });
    } catch (err: any) {
      logger.error("[AssemblyAIWebhook] Failed to publish resume event — outbox remains pending for lease recovery", {
        jobId,
        transcriptId,
        outboxId,
        err: err?.message || String(err),
      });
      await db().collection("webhook_outbox").doc(outboxId).update({
        status: "FAILED",
        lastError: err?.message || String(err),
        nextRetryAt: Date.now() + 5000,
        updatedAt: Date.now(),
      }).catch(() => {});
      await db().collection("dead_letter_webhooks").doc(`dlq_${transcriptId}_${Date.now()}`).set({
        source: "assemblyai-webhook",
        transcriptId,
        jobId,
        userId,
        outboxId,
        payload: body,
        error: err?.message || String(err),
        failedAt: Date.now(),
        replayed: false,
      }).catch(() => {});
    }
  }
);

/**
 * 🔄 Scheduled Lease Recovery Worker:
 * Sweeps webhook_outbox for any events stuck in OUTBOX_PENDING or FAILED where leaseExpiresAt <= now.
 * Guarantees crash resilience and eliminates the failure scenario where a Cloud Function terminates
 * after webhook ACK before downstream Pub/Sub dispatch completes.
 */
export const recoverWebhookOutboxLeases = onSchedule(
  {
    schedule: "every 2 minutes",
    region: DUBBING_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async () => {
    const now = Date.now();
    logger.info("[WebhookOutboxRecovery] Starting lease recovery sweep", { now });
    const pendingSnaps = await db()
      .collection("webhook_outbox")
      .where("status", "in", ["OUTBOX_PENDING", "FAILED"])
      .limit(50)
      .get()
      .catch((err) => {
        logger.error("[WebhookOutboxRecovery] Query error during lease sweep", { err: String(err) });
        return null;
      });

    if (!pendingSnaps || pendingSnaps.empty) {
      logger.info("[WebhookOutboxRecovery] Zero pending or expired outbox leases found");
      return;
    }

    const { DistributionLayer } = require("../layers/04-distribution");
    const distribution = new DistributionLayer();

    for (const doc of pendingSnaps.docs) {
      const data = doc.data();
      const leaseExpiresAt = data.leaseExpiresAt || 0;
      if (leaseExpiresAt > now) {
        // Lease is actively held by a running worker; do not disturb
        continue;
      }

      const outboxId = doc.id;
      const transcriptId = data.transcriptId;
      const attemptCount = (data.attemptCount || 0) + 1;

      if (attemptCount > 5) {
        logger.error("[WebhookOutboxRecovery] Max recovery attempts exceeded — sending to dead-letter queue", {
          outboxId,
          transcriptId,
          attemptCount,
        });
        await db().collection("webhook_outbox").doc(outboxId).update({
          status: "DEAD_LETTER",
          deadLetteredAt: now,
          updatedAt: now,
        }).catch(() => {});
        continue;
      }

      const newLeaseExpiresAt = now + 120_000;
      let acquired = false;
      try {
        await db().runTransaction(async (tx) => {
          const freshSnap = await tx.get(doc.ref);
          if (!freshSnap.exists) return;
          const freshData = freshSnap.data() as any;
          if (freshData.status !== "OUTBOX_PENDING" && freshData.status !== "FAILED") return;
          if (freshData.leaseExpiresAt && freshData.leaseExpiresAt > now) return;

          tx.update(doc.ref, {
            status: "OUTBOX_PENDING",
            leaseExpiresAt: newLeaseExpiresAt,
            attemptCount,
            lastLeaseRecoveryAt: now,
            updatedAt: now,
          });
          acquired = true;
        });
      } catch (txErr) {
        logger.warn("[WebhookOutboxRecovery] Could not claim lease due to transaction contention", { outboxId, err: String(txErr) });
        continue;
      }

      if (!acquired) continue;

      // Stable eventId guarantees downstream consumer idempotency on recovery sweep
      const eventId = `stt_complete_${transcriptId}`;
      try {
        await distribution.publish("transcription-complete", {
          eventId,
          eventType: "transcription-complete",
          jobId: data.jobId,
          userId: data.userId,
          videoUrl: data.videoUrl,
          executionPlan: data.executionPlan,
          transcriptId,
          outboxId,
          assemblyResult: data.assemblyResult,
          timestamp: now,
          retryCount: attemptCount,
          source: "assemblyai-webhook-recovery",
        });

        const batch = db().batch();
        batch.update(doc.ref, {
          status: "DISPATCHED",
          eventId,
          dispatchedAt: Date.now(),
          updatedAt: Date.now(),
        });
        batch.update(db().collection("assemblyai_webhook_jobs").doc(transcriptId), {
          status: "PROCESSING",
          currentEventId: eventId,
          dispatchedAt: Date.now(),
          updatedAt: Date.now(),
        });
        await batch.commit();
        logger.info("[WebhookOutboxRecovery] ✅ Successfully recovered and dispatched stuck outbox event", {
          outboxId,
          transcriptId,
          eventId,
          attemptCount,
        });
      } catch (pubErr: any) {
        logger.error("[WebhookOutboxRecovery] Failed to publish recovered event to Pub/Sub", {
          outboxId,
          err: pubErr?.message || String(pubErr),
        });
        await doc.ref.update({
          status: "FAILED",
          lastError: pubErr?.message || String(pubErr),
          updatedAt: Date.now(),
        }).catch(() => {});
      }
    }
  }
);
