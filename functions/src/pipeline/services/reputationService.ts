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
    if (report.trustScore === null) {
      logger.info("[Reputation] Skipping update — no score available for this report", { userId, channelId });
      return;
    }
    const repRef = this.db.collection('creator_reputation').doc(userId);
    
    const month = new Date().toISOString().slice(0, 7); // YYYY-MM
    const reportScore = report.trustScore;
    
    await this.db.runTransaction(async (transaction) => {
      const doc = await transaction.get(repRef);
      const now = Date.now();

      let rep: CreatorReputation;

      if (!doc.exists) {
        // First time initialization
        rep = {
          userId,
          channelId,
          channelRating: reportScore,
          trustScore: reportScore,
          trustLevel: this.calculateTrustLevel(reportScore),
          lifetimeClaims: report.factCheckStats.totalClaims,
          accurateCount: report.factCheckStats.correct,
          nuanceCount: report.factCheckStats.unverifiable, 
          incorrectCount: report.factCheckStats.incorrect,
          accuracyRate: report.factCheckStats.correct / (report.factCheckStats.totalClaims || 1),
          nuanceRate: report.factCheckStats.unverifiable / (report.factCheckStats.totalClaims || 1),
          correctionRate: 0,
          drift: 0,
          trend: 'stable',
          domainScores: {},
          history: [{ month, avgScore: reportScore, videoCount: 1 }],
          lastScores: [reportScore],
          metadataReliability: (report as any).metadataReliability || {
            speakerAccuracy: 1,
            languageAccuracy: 1,
            formatAccuracy: 1,
            overall: 1
          },
          updatedAt: now
        };
      } else {
        const data = doc.data() as CreatorReputation;
        
        const newLifetimeClaims = data.lifetimeClaims + report.factCheckStats.totalClaims;
        const newAccurateCount = data.accurateCount + report.factCheckStats.correct;
        const newIncorrectCount = data.incorrectCount + report.factCheckStats.incorrect;
        const newNuanceCount = data.nuanceCount + report.factCheckStats.unverifiable;
        
        // Rolling average trust score (Legacy)
        // const totalVideos = (data.history.reduce((sum, h) => sum + h.videoCount, 0)) + 1;
        // const newTrustScore = Math.round(((data.trustScore * (totalVideos - 1)) + reportScore) / totalVideos);

        // EWMA: Exponentially Weighted Moving Average (v4.0 Decay Model)
        // newScore = (oldScore * (1 - alpha)) + (currentScore * alpha)
        // alpha = 0.3 means recent videos have ~30% weight, allowing faster recovery.
        const alpha = 0.3;
        const newTrustScore = Math.round((data.trustScore * (1 - alpha)) + (reportScore * alpha));

        // Trajectory & Trend Signal (v4.0)
        const lastScores = [reportScore, ...(data.lastScores || [])].slice(0, 5);
        let trendSignal = 0;
        let trend: CreatorReputation['trend'] = 'stable';

        if (lastScores.length >= 2) {
          const currentAvg = lastScores.slice(0, 3).reduce((a, b) => (a || 0) + (b || 0), 0) / Math.min(3, lastScores.length);
          const previousAvg = lastScores.slice(1, 4).reduce((a, b) => (a || 0) + (b || 0), 0) / Math.min(3, Math.max(1, lastScores.length - 1));
          trendSignal = Math.round(currentAvg - previousAvg);
          
          if (trendSignal >= 5) trend = 'improving';
          else if (trendSignal <= -5) trend = 'deteriorating';
        }

        // Update history
        const history = [...data.history];
        const monthIdx = history.findIndex(h => h.month === month);
        if (monthIdx >= 0) {
          history[monthIdx].avgScore = Math.round((history[monthIdx].avgScore * 0.7) + (reportScore * 0.3)); // EWMA for monthly as well
          history[monthIdx].videoCount += 1;
        } else {
          history.push({ month, avgScore: reportScore, videoCount: 1 });
        }

        rep = {
          ...data,
          trustScore: newTrustScore,
          trustLevel: this.calculateTrustLevel(newTrustScore),
          lifetimeClaims: newLifetimeClaims,
          accurateCount: newAccurateCount,
          incorrectCount: newIncorrectCount,
          nuanceCount: newNuanceCount,
          accuracyRate: newAccurateCount / (newLifetimeClaims || 1),
          nuanceRate: newNuanceCount / (newLifetimeClaims || 1),
          drift: trendSignal, // Internal key remains 'drift' for now to match types
          trend,
          lastScores,
          history: history.slice(-12), // Keep last 12 months
          metadataReliability: this.blendMetadataReliability(data.metadataReliability, (report as any).metadataReliability),
          updatedAt: now
        };
      }

      transaction.set(repRef, rep);
    });

    logger.info("[Reputation] Updated creator trust ledger", { userId, channelId, score: reportScore });
  }

  private calculateTrustLevel(score: number): CreatorReputation['trustLevel'] {
    if (score >= 90) return 'elite';
    if (score >= 75) return 'high';
    if (score >= 50) return 'developing';
    if (score >= 30) return 'risk';
    return 'critical';
  }

  /**
   * Get a creator's reputation profile
   */
  async getReputation(userId: string): Promise<CreatorReputation | null> {
    const doc = await this.db.collection('creator_reputation').doc(userId).get();
    return doc.exists ? (doc.data() as CreatorReputation) : null;
  }

  private blendMetadataReliability(old: any, current: any): any {
    if (!current) return old || { speakerAccuracy: 1, languageAccuracy: 1, formatAccuracy: 1, overall: 1 };
    if (!old) return current;

    const alpha = 0.2; // 20% weight to new metadata
    const blend = (o: number, n: number) => (o * (1 - alpha)) + (n * alpha);

    const speakerAccuracy = blend(old.speakerAccuracy || 1, current.speakerAccuracy || 1);
    const languageAccuracy = blend(old.languageAccuracy || 1, current.languageAccuracy || 1);
    const formatAccuracy = blend(old.formatAccuracy || 1, current.formatAccuracy || 1);

    return {
      speakerAccuracy,
      languageAccuracy,
      formatAccuracy,
      overall: (speakerAccuracy + languageAccuracy + formatAccuracy) / 3
    };
  }
}

export const reputationService = new ReputationService();
