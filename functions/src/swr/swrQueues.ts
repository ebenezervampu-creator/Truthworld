/**
 * ⚡ SWR CACHE REFRESH TASK HANDLERS (Cloud Tasks)
 *
 * Tiered priority queues for refreshing AI claims cache in the background.
 */

import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { PIPELINE_CONFIG } from "../pipeline/config";
import { logger } from "../pipeline/utils/logger";

const runSWRTask = async (event: any) => {
  try {
    const payload = event.data;
    if (!payload || !payload.jobId || !payload.claimIds || !payload.cacheKeys) {
      logger.error("[SWR Task] Invalid payload", { payload });
      return;
    }
    const geminiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
    const { CredibilityEngine } = require("../pipeline/layers/06-credibility");
    const engine = new CredibilityEngine(geminiKey);
    await engine.refreshCacheForClaims(payload);
  } catch (error) {
    logger.error("[SWR Task] Execution failed", { error: String(error) });
    throw error;
  }
};

export const refreshHighQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
    rateLimits: { maxConcurrentDispatches: 10 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

export const refreshMediumQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 2, minBackoffSeconds: 30 },
    rateLimits: { maxConcurrentDispatches: 5 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

export const refreshLowQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 1, minBackoffSeconds: 60 },
    rateLimits: { maxConcurrentDispatches: 2 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

export const refreshBackgroundQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 1, minBackoffSeconds: 120 },
    rateLimits: { maxConcurrentDispatches: 1 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);
