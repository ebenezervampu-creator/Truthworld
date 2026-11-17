/**
 * 📊 SUBTITLE HUMAN CORRECTION RATE (HCR) TELEMETRY
 *
 * Tracks creator and editorial corrections made to machine-generated subtitles in Creator Studio.
 * Measures automated accuracy vs manual editing effort across languages and genres.
 *
 * Upgraded in Version 2.1:
 * - Multi-tier severity categorization (Tier 1: Stylistic to Tier 5: Critical Semantic).
 * - Pre-correction Critical Error Rate (CER) calculation for Gate G8.
 * - Severity-weighted HCR index.
 */

import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';

export type EditSeverityTier =
  | 'tier_1_stylistic'     // Line breaks, capitalization, trailing punctuation
  | 'tier_2_grammar'       // Postpositional markers, verb agreement, honorific register
  | 'tier_3_terminology'   // Domain glossary substitution (e.g. grid batteries)
  | 'tier_4_timing'        // Acoustic scrubbing / onset nudging (> 100ms)
  | 'tier_5_critical';     // Numbers, polarity reversal, entity hallucination, critical meaning

export interface CueEditDelta {
  cueId: number;
  originalText: string;
  editedText: string;
  originalStartMs: number;
  originalEndMs: number;
  editedStartMs: number;
  editedEndMs: number;
  hasTextChange: boolean;
  hasTimingChange: boolean;
  hasLineBreakChange: boolean;
  severityTier: EditSeverityTier;
  rationale?: string;
}

export interface SubtitleCorrectionSessionPayload {
  jobId: string;
  videoId?: string;
  languageCode: string;
  contentCategory: 'fact_checking_news' | 'multi_speaker_interview' | 'educational_lecture' | 'creator_reel' | 'general';
  reviewerId: string;
  reviewerRole: 'creator' | 'editorial_staff' | 'senior_linguist' | 'certified_translator';
  totalCues: number;
  cuesDelta: CueEditDelta[];
  videoDurationSeconds: number;
}

export interface SubtitleCorrectionReport {
  sessionId: string;
  jobId: string;
  languageCode: string;
  contentCategory: string;
  totalCues: number;
  editedCuesCount: number;
  humanCorrectionRate: number; // Raw proportion of cues edited (0.0 to 1.0)
  severityWeightedHcr: number; // Weighted by edit severity (0.0 to 1.0)
  criticalErrorRate: number;   // Proportion of cues with Tier 5 critical errors (Gate G8)
  tierBreakdown: {
    tier1Stylistic: number;
    tier2Grammar: number;
    tier3Terminology: number;
    tier4Timing: number;
    tier5Critical: number;
  };
  editingEffortMinutesPer10MinVideo: number;
  recordedAt: number;
}

export class SubtitleCorrectionTelemetryService {
  private static db() {
    return admin.firestore();
  }

  /**
   * Classifies the severity of an edit between original and corrected cue.
   */
  public static classifyEditSeverity(
    origText: string,
    editText: string,
    origStartMs: number,
    origEndMs: number,
    editStartMs: number,
    editEndMs: number
  ): EditSeverityTier {
    const normOrig = origText.trim();
    const normEdit = editText.trim();

    // Check for critical numerical or polarity alterations (Tier 5)
    const origNumbers = normOrig.match(/\d+(?:\.\d+)?%?/g) || [];
    const editNumbers = normEdit.match(/\d+(?:\.\d+)?%?/g) || [];
    if (origNumbers.join(',') !== editNumbers.join(',')) {
      return 'tier_5_critical';
    }

    const origNegation = /\b(not|no|never|neither|లేదు|కాదు|నహీ|మత్)\b/i.test(normOrig);
    const editNegation = /\b(not|no|never|neither|లేదు|కాదు|నహీ|మత్)\b/i.test(normEdit);
    if (origNegation !== editNegation) {
      return 'tier_5_critical';
    }

    // Check for timing shift > 250ms (Tier 4)
    if (Math.abs(origStartMs - editStartMs) > 250 || Math.abs(origEndMs - editEndMs) > 250) {
      return 'tier_4_timing';
    }

    // Check for pure line break / formatting adjustment (Tier 1)
    const stripWhitespace = (s: string) => s.replace(/\s+/g, ' ').trim();
    if (stripWhitespace(normOrig) === stripWhitespace(normEdit) && normOrig !== normEdit) {
      return 'tier_1_stylistic';
    }

    // Check for minor punctuation changes (Tier 1)
    const stripPunct = (s: string) => s.replace(/[.,/#!$%^&*;:{}=\-_`~()?!।|]/g, '').replace(/\s+/g, ' ').trim();
    if (stripPunct(normOrig) === stripPunct(normEdit)) {
      return 'tier_1_stylistic';
    }

    // Substantial textual rewrite: classify as grammar/register or terminology (Tier 2/3)
    return 'tier_2_grammar';
  }

  /**
   * Compares original generated cues against user/reviewer edited cues and computes HCR metrics.
   */
  public static calculateSessionDeltas(
    originalCues: Array<{ id: number; text: string; startMs: number; endMs: number }>,
    editedCues: Array<{ id: number; text: string; startMs: number; endMs: number }>
  ): {
    totalCues: number;
    editedCuesCount: number;
    humanCorrectionRate: number;
    severityWeightedHcr: number;
    criticalErrorRate: number;
    deltas: CueEditDelta[];
  } {
    const origMap = new Map(originalCues.map((c) => [c.id, c]));
    const deltas: CueEditDelta[] = [];
    let editedCount = 0;

    for (const edited of editedCues) {
      const orig = origMap.get(edited.id);
      if (!orig) continue;

      const normOrig = orig.text.trim();
      const normEdit = edited.text.trim();
      const hasTextChange = normOrig.replace(/\s+/g, ' ') !== normEdit.replace(/\s+/g, ' ');
      const hasLineBreakChange = normOrig !== normEdit && !hasTextChange;
      const hasTimingChange = Math.abs(orig.startMs - edited.startMs) > 33 || Math.abs(orig.endMs - edited.endMs) > 33;

      if (hasTextChange || hasTimingChange || hasLineBreakChange) {
        editedCount++;
        const severity = this.classifyEditSeverity(
          orig.text,
          edited.text,
          orig.startMs,
          orig.endMs,
          edited.startMs,
          edited.endMs
        );

        deltas.push({
          cueId: edited.id,
          originalText: orig.text,
          editedText: edited.text,
          originalStartMs: orig.startMs,
          originalEndMs: orig.endMs,
          editedStartMs: edited.startMs,
          editedEndMs: edited.endMs,
          hasTextChange,
          hasTimingChange,
          hasLineBreakChange,
          severityTier: severity,
        });
      }
    }

    const totalCues = originalCues.length;
    const rawHcr = totalCues > 0 ? Number((editedCount / totalCues).toFixed(4)) : 0;

    const tierCounts = {
      t1: deltas.filter((d) => d.severityTier === 'tier_1_stylistic').length,
      t2: deltas.filter((d) => d.severityTier === 'tier_2_grammar').length,
      t3: deltas.filter((d) => d.severityTier === 'tier_3_terminology').length,
      t4: deltas.filter((d) => d.severityTier === 'tier_4_timing').length,
      t5: deltas.filter((d) => d.severityTier === 'tier_5_critical').length,
    };

    // Severity weights: Tier 1 = 0.1, Tier 2 = 0.3, Tier 3 = 0.5, Tier 4 = 0.4, Tier 5 = 1.0
    const weightedPoints =
      tierCounts.t1 * 0.1 +
      tierCounts.t2 * 0.3 +
      tierCounts.t3 * 0.5 +
      tierCounts.t4 * 0.4 +
      tierCounts.t5 * 1.0;

    const weightedHcr = totalCues > 0 ? Number((weightedPoints / totalCues).toFixed(4)) : 0;
    const criticalErrorRate = totalCues > 0 ? Number((tierCounts.t5 / totalCues).toFixed(4)) : 0;

    return {
      totalCues,
      editedCuesCount: editedCount,
      humanCorrectionRate: rawHcr,
      severityWeightedHcr: weightedHcr,
      criticalErrorRate,
      deltas,
    };
  }

  /**
   * Records a correction session to Firestore for ongoing pipeline telemetry and calibration.
   */
  public static async recordCorrectionSession(
    payload: SubtitleCorrectionSessionPayload,
    editingDurationSeconds: number = 0
  ): Promise<SubtitleCorrectionReport> {
    const tierCounts = {
      tier1Stylistic: payload.cuesDelta.filter((d) => d.severityTier === 'tier_1_stylistic').length,
      tier2Grammar: payload.cuesDelta.filter((d) => d.severityTier === 'tier_2_grammar').length,
      tier3Terminology: payload.cuesDelta.filter((d) => d.severityTier === 'tier_3_terminology').length,
      tier4Timing: payload.cuesDelta.filter((d) => d.severityTier === 'tier_4_timing').length,
      tier5Critical: payload.cuesDelta.filter((d) => d.severityTier === 'tier_5_critical').length,
    };

    const editedCuesCount = payload.cuesDelta.length;
    const rawHcr = payload.totalCues > 0 ? Number((editedCuesCount / payload.totalCues).toFixed(4)) : 0;

    const weightedPoints =
      tierCounts.tier1Stylistic * 0.1 +
      tierCounts.tier2Grammar * 0.3 +
      tierCounts.tier3Terminology * 0.5 +
      tierCounts.tier4Timing * 0.4 +
      tierCounts.tier5Critical * 1.0;

    const weightedHcr = payload.totalCues > 0 ? Number((weightedPoints / payload.totalCues).toFixed(4)) : 0;
    const criticalErrorRate = payload.totalCues > 0 ? Number((tierCounts.tier5Critical / payload.totalCues).toFixed(4)) : 0;

    const videoDurMinutes = Math.max(0.1, payload.videoDurationSeconds / 60);
    const editingMinutes = editingDurationSeconds / 60;
    const editingEffortPer10Min = Number(((editingMinutes / videoDurMinutes) * 10).toFixed(2));

    const report: SubtitleCorrectionReport = {
      sessionId: `hcr_${payload.jobId}_${payload.languageCode}_${Date.now()}`,
      jobId: payload.jobId,
      languageCode: payload.languageCode,
      contentCategory: payload.contentCategory,
      totalCues: payload.totalCues,
      editedCuesCount,
      humanCorrectionRate: rawHcr,
      severityWeightedHcr: weightedHcr,
      criticalErrorRate,
      tierBreakdown: tierCounts,
      editingEffortMinutesPer10MinVideo: editingEffortPer10Min,
      recordedAt: Date.now(),
    };

    try {
      await this.db()
        .collection('subtitle_correction_telemetry')
        .doc(report.sessionId)
        .set({
          ...report,
          reviewerId: payload.reviewerId,
          reviewerRole: payload.reviewerRole,
          deltas: payload.cuesDelta,
        });

      logger.info('[SubtitleTelemetry] Recorded correction session', {
        jobId: payload.jobId,
        language: payload.languageCode,
        rawHcr,
        weightedHcr,
        criticalErrorRate,
        editedCuesCount,
        totalCues: payload.totalCues,
      });
    } catch (err) {
      logger.warn('[SubtitleTelemetry] Failed to persist correction session to Firestore', { err });
    }

    return report;
  }
}
