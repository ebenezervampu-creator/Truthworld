import * as admin from "firebase-admin";
import { CreatorDNA } from "../types";
import { logger } from "../utils/logger";

const db = () => admin.firestore();

/**
 * 👤 CREATOR STYLE SERVICE
 * 
 * Manages persistent style "DNA" for creators to ensure 
 * consistent localization across all their content.
 */
export class CreatorStyleService {
  /**
   * Get persistent DNA for a creator
   */
  async getCreatorDNA(userId: string): Promise<CreatorDNA | null> {
    try {
      const doc = await db().collection("creator_dna").doc(userId).get();
      if (!doc.exists) return null;
      return doc.data() as CreatorDNA;
    } catch (err) {
      logger.error("[CreatorDNA] Failed to fetch DNA", { userId, err });
      return null;
    }
  }

  /**
   * Save or update creator DNA
   */
  async updateCreatorDNA(userId: string, dna: Partial<CreatorDNA>): Promise<void> {
    await db().collection("creator_dna").doc(userId).set(dna, { merge: true });
    logger.info("[CreatorDNA] Updated DNA", { userId });
  }

  /**
   * Auto-learn DNA traits from a specific job's success
   */
  async learnFromJob(userId: string, jobId: string): Promise<void> {
    try {
      logger.info("[CreatorDNA] Learning cycle initiated", { userId, jobId });
      const jobDoc = await db().collection("pipeline_jobs").doc(jobId).get();
      if (!jobDoc.exists) return;

      const jobData = jobDoc.data() || {};
      const config = jobData.config || {};
      const acoustic = jobData.acousticFingerprint || {};

      const updates: Partial<CreatorDNA> = {};

      if (acoustic.tempo === "fast" || acoustic.energy === "high") {
        updates.vibe = "energetic";
      } else if (acoustic.pitchBand === "deep") {
        updates.vibe = "authoritative";
      }

      if (config.slangHandling === "preserve") {
        updates.slangTolerance = "high";
      } else if (config.slangHandling === "formalize") {
        updates.slangTolerance = "low";
      }

      if (config.terminology === "technical") {
        updates.vocabPreference = "tech_heavy";
      } else if (config.terminology === "academic") {
        updates.vocabPreference = "academic";
      }

      if (Object.keys(updates).length > 0) {
        await this.updateCreatorDNA(userId, updates);
        logger.info("[CreatorDNA] Auto-learned DNA traits from job", { userId, jobId, updates });
      }
    } catch (err) {
      logger.error("[CreatorDNA] Error learning from job", { userId, jobId, err });
    }
  }
}

export const creatorStyleService = new CreatorStyleService();
