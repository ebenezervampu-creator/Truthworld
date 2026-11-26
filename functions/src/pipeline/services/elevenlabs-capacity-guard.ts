/**
 * Pre-charge ElevenLabs capacity guard & throttled admin alerting.
 *
 * Called before charging a dubbing order (triggerVideoAIFeatures, createDubbingJob).
 * - Compares estimated TTS characters and clones needed against remaining capacity.
 * - If short, refuses BEFORE charging with a friendly message and alerts admins.
 * - If GET /v1/user/subscription fails (e.g. 401 missing user_read), alerts admins at most once
 *   per hour and states what the order does (proceeds without pre-charge capacity block).
 */

import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { ttsService, describeElevenLabsError } from "./tts";
import {
  estimateOrderRequirements,
  evaluateOrderCapacity,
  orderCapacityUnavailableMessage,
  type OrderCapacityResult,
} from "./voice-capacity";

const SUBSCRIPTION_ALERT_THROTTLE_MS = 60 * 60 * 1000; // 1 hour

export interface OrderCapacityCheckInput {
  videoId?: string;
  userId: string;
  durationSec: number;
  sourceChars?: number;
  sourceLang: string;
  targetLanguages: string[];
  clonesNeeded?: number;
}

export interface OrderCapacityCheckOutcome {
  allowed: boolean;
  message?: string;
  capacity?: OrderCapacityResult;
  subscriptionFailed?: boolean;
}

async function alertAdminsThrottled(docId: string, payload: Record<string, unknown>, throttleMs: number): Promise<void> {
  try {
    const ref = admin.firestore().collection("admin_alerts").doc(docId);
    const now = Date.now();
    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const last = Number(snap.data()?.lastAlertedAt || 0);
      if (throttleMs > 0 && last > 0 && now - last < throttleMs) {
        return;
      }
      tx.set(
        ref,
        {
          ...payload,
          lastAlertedAt: now,
          updatedAt: now,
        },
        { merge: true }
      );
    });
  } catch (alertErr) {
    logger.warn("[ElevenLabs:Capacity] Failed to write admin_alerts doc", { docId, err: String(alertErr) });
  }
}

export async function checkOrderCapacityAndAlert(
  input: OrderCapacityCheckInput,
  deps?: {
    getSubscription?: () => Promise<Record<string, unknown>>;
    alertFn?: (docId: string, payload: Record<string, unknown>, throttleMs: number) => Promise<void>;
  }
): Promise<OrderCapacityCheckOutcome> {
  const needed = estimateOrderRequirements({
    durationSec: input.durationSec,
    sourceChars: input.sourceChars,
    sourceLang: input.sourceLang,
    targetLanguages: input.targetLanguages,
    clonesNeeded: input.clonesNeeded ?? 0,
  });

  const getSub = deps?.getSubscription ?? (() => ttsService.getRawSubscription());
  const writeAlert = deps?.alertFn ?? alertAdminsThrottled;

  let subscription: Record<string, unknown>;
  try {
    subscription = await getSub();
  } catch (err: any) {
    const errSummary = describeElevenLabsError(err);
    const orderAction = "Order proceeded without pre-charge capacity block because ElevenLabs subscription telemetry failed.";
    logger.error("[ElevenLabs:Capacity] Subscription check failed — proceeding with order", {
      videoId: input.videoId || null,
      userId: input.userId,
      needed,
      err: errSummary,
      orderAction,
    });
    await writeAlert(
      "elevenlabs_subscription_error",
      {
        type: "elevenlabs_subscription_error",
        severity: "warning",
        error: errSummary,
        orderAction,
        sampleVideoId: input.videoId || null,
        sampleUserId: input.userId,
      },
      SUBSCRIPTION_ALERT_THROTTLE_MS
    );
    return { allowed: true, subscriptionFailed: true };
  }

  const capacity = evaluateOrderCapacity(subscription, needed);
  logger.info("[ElevenLabs:Capacity]", {
    remainingChars: capacity.remainingChars,
    slotsFree: capacity.slotsFree,
    opsLeft: capacity.opsLeft,
    needed: capacity.needed,
  });

  if (!capacity.ok) {
    logger.error("[ElevenLabs:Capacity] Order refused before charging — insufficient capacity", {
      videoId: input.videoId || null,
      userId: input.userId,
      reason: capacity.reason,
      remainingChars: capacity.remainingChars,
      slotsFree: capacity.slotsFree,
      opsLeft: capacity.opsLeft,
      needed: capacity.needed,
    });
    await writeAlert(
      `elevenlabs_capacity_short_${Date.now()}`,
      {
        type: "elevenlabs_capacity_short",
        severity: "high",
        reason: capacity.reason,
        remainingChars: capacity.remainingChars,
        slotsFree: capacity.slotsFree,
        opsLeft: capacity.opsLeft,
        needed: capacity.needed,
        videoId: input.videoId || null,
        userId: input.userId,
        orderAction: "Order refused before charging.",
      },
      0
    );
    return {
      allowed: false,
      message: orderCapacityUnavailableMessage(),
      capacity,
    };
  }

  return { allowed: true, capacity };
}
