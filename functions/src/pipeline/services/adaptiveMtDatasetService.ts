/**
 * 🧠 Adaptive MT Continuous Translation Memory Service (Option 3)
 *
 * Implements safe, quarantined Translation Memory (TM) synchronization
 * from DAW Studio creator line edits to regional Google Cloud Adaptive MT datasets
 * and live Firestore reference pools.
 *
 * Epistemic Guardrail:
 * Gated strictly behind:
 *   numericalParityPassed === true &&
 *   terminologyComplianceRate === 1.0 &&
 *   !reviewRecommended
 *
 * Noisy, non-compliant, or factually drifted edits are quarantined and
 * never pollute the shared translation memory dataset.
 */

import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { PIPELINE_CONFIG } from "../config";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { logger } from "../utils/logger";

const db = () => admin.firestore();

export interface IngestTranslationMemoryParams {
  jobId: string;
  sourceText: string;
  editedText: string;
  sourceLang: string;
  targetLang: string;
  numericalParityPassed: boolean;
  terminologyComplianceRate: number;
  reviewRecommended?: boolean;
  segmentIndex?: number;
}

export interface IngestionResult {
  ingested: boolean;
  reason?: string;
  pairId?: string;
}

export class AdaptiveMtDatasetService {
  private static _instance: AdaptiveMtDatasetService | null = null;

  public static getInstance(): AdaptiveMtDatasetService {
    if (!this._instance) {
      this._instance = new AdaptiveMtDatasetService();
    }
    return this._instance;
  }

  /**
   * Generates a deterministic hash for a source-target sentence pair.
   */
  public static hashPair(source: string, target: string): string {
    return crypto
      .createHash("sha256")
      .update(`${source.trim()}:::${target.trim()}`)
      .digest("hex")
      .slice(0, 24);
  }

  /**
   * Generates the regional Google Cloud Adaptive MT dataset resource path.
   */
  public static getDatasetResourceName(
    projectId: string,
    sourceLang: string,
    targetLang: string
  ): string {
    const src = normalizeLanguageCode(sourceLang);
    const tgt = normalizeLanguageCode(targetLang);
    const location = PIPELINE_CONFIG.ADAPTIVE_MT_LOCATION || "us-central1";

    if (PIPELINE_CONFIG.ADAPTIVE_MT_DATASET) {
      return PIPELINE_CONFIG.ADAPTIVE_MT_DATASET;
    }

    return `projects/${projectId}/locations/${location}/adaptiveMtDatasets/truthworld_tm_${src}_${tgt}`;
  }

  /**
   * Ingests a creator-approved line edit into the quarantined Translation Memory pool.
   */
  public async ingestCreatorCorrection(
    params: IngestTranslationMemoryParams
  ): Promise<IngestionResult> {
    const src = normalizeLanguageCode(params.sourceLang);
    const tgt = normalizeLanguageCode(params.targetLang);
    const cleanSource = params.sourceText.trim();
    const cleanTarget = params.editedText.trim();

    // ─── Guardrail 1: Quarantined Gating Criteria ─────────────────────────
    if (!params.numericalParityPassed) {
      logger.warn("[AdaptiveMtDataset] Ingestion quarantined: Numerical parity failed", {
        jobId: params.jobId,
        segmentIndex: params.segmentIndex,
      });
      return {
        ingested: false,
        reason: "Quarantined: Numerical entity or scale parity check failed",
      };
    }

    if ((params.terminologyComplianceRate ?? 1.0) < 1.0) {
      logger.warn("[AdaptiveMtDataset] Ingestion quarantined: Terminology compliance rate < 1.0", {
        jobId: params.jobId,
        segmentIndex: params.segmentIndex,
        rate: params.terminologyComplianceRate,
      });
      return {
        ingested: false,
        reason: `Quarantined: Terminology compliance rate ${params.terminologyComplianceRate} < 1.0`,
      };
    }

    if (params.reviewRecommended) {
      logger.warn("[AdaptiveMtDataset] Ingestion quarantined: Flagged for creator review", {
        jobId: params.jobId,
        segmentIndex: params.segmentIndex,
      });
      return {
        ingested: false,
        reason: "Quarantined: Segment is flagged for review or polarity ambiguity",
      };
    }

    if (cleanSource.length < 3 || cleanTarget.length < 3) {
      return {
        ingested: false,
        reason: "Quarantined: Segment text too short for translation memory",
      };
    }

    // ─── Persist to Firestore Quarantined Memory Pool ─────────────────────
    const pairId = AdaptiveMtDatasetService.hashPair(cleanSource, cleanTarget);
    const langPairKey = `${src}_${tgt}`;

    try {
      const pairRef = db()
        .collection("translation_memory")
        .doc(langPairKey)
        .collection("pairs")
        .doc(pairId);

      await pairRef.set(
        {
          pairId,
          sourceText: cleanSource,
          targetText: cleanTarget,
          sourceLang: src,
          targetLang: tgt,
          jobId: params.jobId,
          segmentIndex: params.segmentIndex,
          verifiedAt: Date.now(),
          numericalParityPassed: true,
          terminologyComplianceRate: params.terminologyComplianceRate,
          syncedToGcp: false,
        },
        { merge: true }
      );

      logger.info("[AdaptiveMtDataset] ✅ Validated creator pair ingested into Translation Memory", {
        langPairKey,
        pairId,
        source: cleanSource.slice(0, 40),
        target: cleanTarget.slice(0, 40),
      });

      return {
        ingested: true,
        pairId,
      };
    } catch (err) {
      logger.error("[AdaptiveMtDataset] Error saving translation memory pair", err);
      return {
        ingested: false,
        reason: (err as any)?.message || "Failed to persist to translation memory",
      };
    }
  }

  /**
   * Retrieves high-confidence, verified Translation Memory pairs for live injection
   * into AdaptiveMtTranslate reference pairs.
   */
  public async getRecentVerifiedPairs(
    sourceLang: string,
    targetLang: string,
    limitCount: number = 5
  ): Promise<Array<{ sourceSentence: string; targetSentence: string }>> {
    const src = normalizeLanguageCode(sourceLang);
    const tgt = normalizeLanguageCode(targetLang);
    const langPairKey = `${src}_${tgt}`;

    try {
      const snap = await db()
        .collection("translation_memory")
        .doc(langPairKey)
        .collection("pairs")
        .orderBy("verifiedAt", "desc")
        .limit(limitCount)
        .get();

      if (snap.empty) return [];

      return snap.docs.map((doc: any) => {
        const d = doc.data();
        return {
          sourceSentence: d.sourceText,
          targetSentence: d.targetText,
        };
      });
    } catch (err) {
      logger.warn("[AdaptiveMtDataset] Error retrieving recent verified pairs:", err);
      return [];
    }
  }
}

export const adaptiveMtDatasetService = AdaptiveMtDatasetService.getInstance();
