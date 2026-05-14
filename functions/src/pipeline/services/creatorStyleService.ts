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
   * Auto-learn DNA traits from a specific job's success (Future Phase)
   */
  async learnFromJob(userId: string, jobId: string): Promise<void> {
    // Placeholder for LLM-based feedback loop
    logger.info("[CreatorDNA] Learning cycle initiated", { userId, jobId });
  }
}

export const creatorStyleService = new CreatorStyleService();
