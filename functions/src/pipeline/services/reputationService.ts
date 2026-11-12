/**
 * 🏆 REPUTATION SERVICE (The Trust Ledger)
 * 
 * Aggregates per-video Credibility Results into long-term Creator Reputation.
 * This turns verification data into a "Reputation Graph," which is the
 * core competitive moat of TruthWorld.
 */

import * as admin from 'firebase-admin';
import { CredibilityResult, CreatorReputation } from '../types';
import { logger } from '../utils/logger';

export class ReputationService {
  private get db() {
    return admin.firestore();
  }

  /**
   * Update a creator's reputation based on a new credibility report
   */
  async updateReputation(userId: string, channelId: string, report: CredibilityResult): Promise<void> {
    logger.info("[Reputation] Skipping update — claim ledger verification does not compute monolithic trust scores", { userId, channelId });
    return;
  }

  async getReputation(userId: string): Promise<CreatorReputation | null> {
    const doc = await this.db.collection('creator_reputation').doc(userId).get();
    return doc.exists ? (doc.data() as CreatorReputation) : null;
  }

  }

export const reputationService = new ReputationService();
