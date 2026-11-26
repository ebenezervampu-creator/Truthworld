import * as admin from 'firebase-admin';
import { SpeakerBreakdown } from '../types';
import { logger } from '../utils/logger';

export interface SpeakerReputation {
  speakerId: string;        // spk_uuid
  factualAccuracy: number;  // 0-1
  correctionRate: number;   // 0-1
  toxicityDrift: number;    // -1 to 1
  lifetimeClaims: number;
  accurateCount: number;
  incorrectCount: number;
  correctionCount: number;
  lastSeen: number;
  history: Array<{
    jobId: string;
    score: number;
    timestamp: number;
  }>;
}

/**
 * 📈 SPEAKER REPUTATION SERVICE (v7)
 * 
 * Tracks long-term credibility metrics for identifiable speakers.
 */
export class SpeakerReputationService {
  private get db() {
    return admin.firestore();
  }

  /**
   * Update speaker reputation after a video is processed.
   */
  async updateReputation(jobId: string, speakerId: string, metrics: SpeakerBreakdown, stats: any): Promise<void> {
    if (speakerId.startsWith("temp_") || speakerId.startsWith("err_")) return;

    const repRef = this.db.collection('speaker_reputation').doc(speakerId);
    
    await this.db.runTransaction(async (transaction) => {
      const doc = await transaction.get(repRef);
      const now = Date.now();
      const currentScore = metrics.trustIndex ?? 50;

      let rep: SpeakerReputation;

      if (!doc.exists) {
        rep = {
          speakerId,
          factualAccuracy: currentScore / 100,
          correctionRate: 0,
          toxicityDrift: 0,
          lifetimeClaims: metrics.claimCount,
          accurateCount: stats.correct || 0,
          incorrectCount: stats.incorrect || 0,
          correctionCount: 0,
          lastSeen: now,
          history: [{ jobId, score: currentScore, timestamp: now }]
        };
      } else {
        const data = doc.data() as SpeakerReputation;

        rep = {
          ...data,
          factualAccuracy: (data.accurateCount + (stats.correct || 0)) / (data.lifetimeClaims + metrics.claimCount || 1),
          lifetimeClaims: data.lifetimeClaims + metrics.claimCount,
          accurateCount: data.accurateCount + (stats.correct || 0),
          incorrectCount: data.incorrectCount + (stats.incorrect || 0),
          lastSeen: now,
          history: [{ jobId, score: currentScore, timestamp: now }, ...data.history].slice(0, 10)
        };
      }

      transaction.set(repRef, rep);
    });

    logger.info("[SpeakerReputation] Updated speaker trust", { speakerId, jobId, score: metrics.trustIndex });
  }

  async getReputation(speakerId: string): Promise<SpeakerReputation | null> {
    const doc = await this.db.collection('speaker_reputation').doc(speakerId).get();
    return doc.exists ? (doc.data() as SpeakerReputation) : null;
  }
}

export const speakerReputationService = new SpeakerReputationService();
