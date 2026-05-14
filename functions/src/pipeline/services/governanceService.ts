import * as admin from 'firebase-admin';
import { TrustAppeal, GovernanceAuditLog } from '../types';
import { logger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

/**
 * ⚖️ GOVERNANCE SERVICE (v4.0 Alpha)
 * 
 * Handles human-in-the-loop overrides, appeals, and system audit trails.
 * This ensures "Defense-Grade" accountability and transparency.
 */
export class GovernanceService {
  private db = admin.firestore();

  /**
   * Submit a trust score appeal
   */
  async submitAppeal(userId: string, jobId: string, reason: string, evidenceLinks?: string[]): Promise<string> {
    const appealId = `appeal_${uuidv4().substring(0, 8)}`;
    
    // Fetch original score
    const credDoc = await this.db.collection('factChecks').doc(jobId).get();
    if (!credDoc.exists) throw new Error("Job not found");
    const originalScore = credDoc.data()?.trustScore || 0;

    const appeal: TrustAppeal = {
      appealId,
      jobId,
      userId,
      reason,
      evidenceLinks,
      status: 'pending',
      originalScore,
      createdAt: Date.now()
    };

    await this.db.collection('appeals').doc(appealId).set(appeal);
    await this.db.collection('factChecks').doc(jobId).update({
      isAppealed: true,
      appealStatus: 'pending'
    });

    logger.info("[Governance] Appeal submitted", { appealId, jobId, userId });
    return appealId;
  }

  /**
   * Manually override a trust score (Admin/Reviewer)
   */
  async manualOverride(
    jobId: string, 
    reviewerId: string, 
    newScore: number, 
    rationale: string
  ): Promise<void> {
    const credRef = this.db.collection('factChecks').doc(jobId);
    
    await this.db.runTransaction(async (transaction) => {
      const snap = await transaction.get(credRef);
      if (!snap.exists) throw new Error("Job result not found");
      
      const previousValue = snap.data()?.trustScore;
      
      // Update result
      transaction.update(credRef, {
        trustScore: newScore,
        manualOverride: true,
        overriddenBy: reviewerId,
        overrideRationale: rationale,
        updatedAt: Date.now()
      });

      // Create Audit Log
      const logId = `log_${uuidv4().substring(0, 8)}`;
      const log: GovernanceAuditLog = {
        logId,
        targetId: jobId,
        action: 'manual_override',
        performerId: reviewerId,
        previousValue,
        newValue: newScore,
        rationale,
        timestamp: Date.now()
      };
      
      transaction.set(this.db.collection('governance_audit').doc(logId), log);
    });

    logger.warn("[Governance] Manual override executed", { jobId, reviewerId, newScore });
  }

  /**
   * Resolve an appeal
   */
  async resolveAppeal(
    appealId: string, 
    reviewerId: string, 
    status: 'resolved' | 'rejected', 
    note: string, 
    newScore?: number
  ): Promise<void> {
    const appealRef = this.db.collection('appeals').doc(appealId);
    
    await this.db.runTransaction(async (transaction) => {
      const snap = await transaction.get(appealRef);
      if (!snap.exists) throw new Error("Appeal not found");
      const appeal = snap.data() as TrustAppeal;

      // Update Appeal
      transaction.update(appealRef, {
        status,
        reviewerId,
        resolutionNote: note,
        newScore: newScore || appeal.originalScore,
        resolvedAt: Date.now()
      });

      // Update FactCheck
      transaction.update(this.db.collection('factChecks').doc(appeal.jobId), {
        appealStatus: status === 'resolved' ? 'resolved' : 'rejected',
        trustScore: newScore || appeal.originalScore,
        updatedAt: Date.now()
      });

      // Log Audit
      const logId = `log_${uuidv4().substring(0, 8)}`;
      transaction.set(this.db.collection('governance_audit').doc(logId), {
        logId,
        targetId: appeal.jobId,
        action: 'appeal_resolved',
        performerId: reviewerId,
        previousValue: appeal.originalScore,
        newValue: newScore || appeal.originalScore,
        rationale: note,
        timestamp: Date.now()
      });
    });

    logger.info("[Governance] Appeal resolved", { appealId, status });
  }
}

export const governanceService = new GovernanceService();
