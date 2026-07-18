import * as admin from 'firebase-admin';
import { TrustAppeal, GovernanceAuditLog } from '../types';
import { logger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import { getAnalysisRepository, AnalysisRepository } from './analysisRepository.js';

/**
 * ⚖️ GOVERNANCE SERVICE (v4.0 Alpha)
 * 
 * Handles human-in-the-loop overrides, appeals, and system audit trails.
 * This ensures "Defense-Grade" accountability and transparency.
 */
export class GovernanceService {
  private get db() {
    return admin.firestore();
  }
  private analysisRepository: AnalysisRepository;

  constructor(analysisRepository?: AnalysisRepository) {
    this.analysisRepository = analysisRepository || getAnalysisRepository();
  }

  /**
   * Submit a trust score appeal
   */
  async submitAppeal(userId: string, jobId: string, reason: string, evidenceLinks?: string[]): Promise<string> {
    const appealId = `appeal_${uuidv4().substring(0, 8)}`;
    
    // Fetch original score from Storage via repository
    const factCheckData = await this.analysisRepository.loadAnalysis(jobId, "factChecks");
    if (!factCheckData) throw new Error("Job result not found in Storage");

    const originalScore = factCheckData.trustScore || 0;

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

    // Update appeal status and save a new immutable version in GCS
    factCheckData.isAppealed = true;
    factCheckData.appealStatus = 'pending';
    await this.analysisRepository.saveAnalysis(jobId, "factChecks", factCheckData);

    logger.info("[Governance] Appeal submitted and stored versioned in GCS", { appealId, jobId, userId });
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
    // Fetch original data via repository
    const factCheckData = await this.analysisRepository.loadAnalysis(jobId, "factChecks");
    if (!factCheckData) throw new Error("Job result not found in Storage");

    const previousValue = factCheckData.trustScore;

    // Update factCheckData
    factCheckData.trustScore = newScore;
    factCheckData.manualOverride = true;
    factCheckData.overriddenBy = reviewerId;
    factCheckData.overrideRationale = rationale;
    factCheckData.updatedAt = Date.now();

    // Save a new version in GCS
    await this.analysisRepository.saveAnalysis(jobId, "factChecks", factCheckData);

    // Sync to final_outputs in GCS as a new version if exists
    const outputData = await this.analysisRepository.loadAnalysis(jobId, "final_outputs");
    if (outputData) {
      outputData.trustScore = newScore;
      outputData.rating = newScore;
      outputData.updatedAt = Date.now();
      await this.analysisRepository.saveAnalysis(jobId, "final_outputs", outputData);
    }

    // Create Audit Log in Firestore
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
    
    await this.db.collection('governance_audit').doc(logId).set(log);

    logger.warn("[Governance] Manual override executed and saved versioned to GCS", { jobId, reviewerId, newScore });
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
    const snap = await appealRef.get();
    if (!snap.exists) throw new Error("Appeal not found");
    const appeal = snap.data() as TrustAppeal;

    const resolvedScore = newScore || appeal.originalScore;

    // Fetch and update GCS factcheck result as a new version
    const factCheckData = await this.analysisRepository.loadAnalysis(appeal.jobId, "factChecks");
    if (factCheckData) {
      factCheckData.appealStatus = status === 'resolved' ? 'resolved' : 'rejected';
      factCheckData.trustScore = resolvedScore;
      factCheckData.updatedAt = Date.now();
      await this.analysisRepository.saveAnalysis(appeal.jobId, "factChecks", factCheckData);
    }

    // Fetch and sync to final_outputs in GCS as a new version if exists
    const outputData = await this.analysisRepository.loadAnalysis(appeal.jobId, "final_outputs");
    if (outputData) {
      outputData.trustScore = resolvedScore;
      outputData.rating = resolvedScore;
      outputData.updatedAt = Date.now();
      await this.analysisRepository.saveAnalysis(appeal.jobId, "final_outputs", outputData);
    }

    // Update Appeal document in Firestore
    await appealRef.update({
      status,
      reviewerId,
      resolutionNote: note,
      newScore: resolvedScore,
      resolvedAt: Date.now()
    });

    // Log Audit in Firestore
    const logId = `log_${uuidv4().substring(0, 8)}`;
    await this.db.collection('governance_audit').doc(logId).set({
      logId,
      targetId: appeal.jobId,
      action: 'appeal_resolved',
      performerId: reviewerId,
      previousValue: appeal.originalScore,
      newValue: resolvedScore,
      rationale: note,
      timestamp: Date.now()
    });

    logger.info("[Governance] Appeal resolved and saved versioned to GCS", { appealId, status });
  }
}

export const governanceService = new GovernanceService();
