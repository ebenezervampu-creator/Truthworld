/**
 * Evidence Freshness Sweep — body of the daily scheduled job (see pipelineTriggers.ts).
 * Kept here so its queue behaviour is unit-testable.
 *
 * Queue rules:
 *  - Reports are taken oldest `lastEvidenceCheckAt` first.
 *  - Only a FULLY completed check moves a report to the back of the queue.
 *  - A report whose model re-reading was cut short by the AI budget keeps its timestamp
 *    (front of the queue tomorrow); its claims carry `pendingEvidenceRecheck`.
 *  - A failed report keeps its place; after 3 consecutive failures it is moved back and
 *    flagged for review so one broken report cannot block the rest.
 *  - The run stops as soon as the AI budget is spent.
 */
import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import type { VideoHealingSummary } from "./sourceHealingService";

export interface EvidenceFreshnessSweepResult {
  videosChecked: number;
  videosDeferred: number;
  verdictsChanged: number;
  modelRechecks: number;
}

export async function runEvidenceFreshnessSweep(deps: {
  firestore?: admin.firestore.Firestore;
  healing?: { auditAndHealVideoReport(videoId: string, options?: { repairWithRetrieval?: boolean; maxModelRechecks?: number }): Promise<VideoHealingSummary> };
  maxVideos?: number;
  maxModelRechecks?: number;
} = {}): Promise<EvidenceFreshnessSweepResult> {
    const MAX_VIDEOS = deps.maxVideos ?? 20;
    const MAX_MODEL_RECHECKS = deps.maxModelRechecks ?? 60;
    const TIME_BUDGET_MS = 480_000;
    const started = Date.now();
    const sourceHealingService = deps.healing ?? (await import("./sourceHealingService.js")).sourceHealingService;

    const snap = await (deps.firestore ?? admin.firestore())
      .collection("credibility_quality_audits")
      .orderBy("lastEvidenceCheckAt", "asc")
      .limit(MAX_VIDEOS * 2)
      .get();

    const seen = new Set<string>();
    let modelRechecks = 0;
    let verdictsChanged = 0;
    let videosChecked = 0;
    let videosDeferred = 0;
    const MAX_CONSECUTIVE_FAILURES = 3;
    for (const doc of snap.docs) {
      if (videosChecked >= MAX_VIDEOS || Date.now() - started > TIME_BUDGET_MS) break;
      // Once the AI budget is spent, stop: checking more reports now would remove/repair
      // sources without re-reading them, then mark them fresh and push them to the back.
      if (modelRechecks >= MAX_MODEL_RECHECKS) break;
      const videoId = String(doc.get("videoId") || "");
      if (!videoId || seen.has(videoId)) continue;
      seen.add(videoId);
      try {
        const summary = await sourceHealingService.auditAndHealVideoReport(videoId, {
          repairWithRetrieval: true,
          maxModelRechecks: Math.min(10, MAX_MODEL_RECHECKS - modelRechecks),
        });
        videosChecked++;
        modelRechecks += summary.modelRechecks ?? 0;
        verdictsChanged += summary.verdictsChanged ?? 0;
        const incomplete = (summary.modelRechecksSkipped ?? 0) > 0;
        if (incomplete) videosDeferred++;
        await doc.ref.set({
          // Only a fully completed check moves the report to the back of the queue. A report
          // whose re-reading was cut short by the budget keeps its old timestamp, so it is
          // first in line tomorrow (its claims are also flagged pendingEvidenceRecheck).
          ...(incomplete ? {} : { lastEvidenceCheckAt: Date.now() }),
          evidenceSweepFailures: 0,
          lastEvidenceSweep: {
            at: Date.now(),
            completed: !incomplete,
            brokenUrlsRemoved: summary.brokenUrlsRemoved,
            urlsRepaired: summary.urlsRepaired,
            verdictsChanged: summary.verdictsChanged ?? 0,
            modelRechecks: summary.modelRechecks ?? 0,
            modelRechecksSkipped: summary.modelRechecksSkipped ?? 0,
          },
        }, { merge: true });
      } catch (err: any) {
        // A failed report keeps its place at the front of the queue. After repeated
        // failures it is moved back (and flagged) so one broken report cannot block all others.
        const failures = Number(doc.get("evidenceSweepFailures") || 0) + 1;
        logger.warn("[EvidenceFreshnessSweep] Video re-check failed; will retry next run", {
          videoId, failures, error: err?.message || String(err),
        });
        await doc.ref.set({
          evidenceSweepFailures: failures,
          lastEvidenceSweepError: { at: Date.now(), message: String(err?.message || err).slice(0, 500) },
          ...(failures >= MAX_CONSECUTIVE_FAILURES ? { lastEvidenceCheckAt: Date.now(), reviewStatus: "pending" } : {}),
        }, { merge: true }).catch(() => {});
      }
    }

    logger.info("[EvidenceFreshnessSweep] Completed", {
      event: "TRUTHWORLD_EVIDENCE_FRESHNESS",
      videosChecked,
      videosDeferred,
      verdictsChanged,
      modelRechecks,
      elapsedMs: Date.now() - started,
    });

  return { videosChecked, videosDeferred, verdictsChanged, modelRechecks };
}
