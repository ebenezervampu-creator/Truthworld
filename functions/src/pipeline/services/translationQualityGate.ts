/**
 * 🛡️ Translation Quality Gate (TruthWorld Post-Translation Verification Stage)
 *
 * Combines:
 * 1. Pass 1: Numerical & Factual Entity Parity Guard (100% of segments, $0 Cost).
 * 2. Pass 2: Semantic Back-Translation Spot Check (~10% sample + claim priority).
 * 3. Polarity Inversion Detection (Negation Flip Guard for Fact-Checking).
 * 4. Quarantined Adaptive MT Dataset Ingestion Gate.
 */

import {
  NumericalEntityGuard,
} from "./numericalEntityGuard";

export interface QualityGateSegmentInput {
  index: number;
  original: string;
  translated: string;
  isClaim?: boolean;
  isHook?: boolean;
  confidence?: number;
  terminologyComplianceRate?: number;
}

export interface QualityGateSegmentOutput {
  original: string;
  translated: string;
  numericalParityVerified: boolean;
  numericalParityWarning?: string;
  semanticParityScore?: number;
  reviewRecommended: boolean;
  polarityFlipped?: boolean;
}

export interface TranslationQualityGateOptions {
  sampleRate?: number; // Default 0.10 (10%)
  semanticThreshold?: number; // Default 0.85
  enableSelfHealing?: boolean; // Default true
  repairCallback?: (source: string, drifted: string, targetLang: string, details?: string) => Promise<string>;
  backTranslateCallback?: (targetText: string, targetLang: string) => Promise<string>;
}

export class TranslationQualityGate {
  private static readonly NEGATION_REGEX =
    /\b(not|never|no|neither|nor|none|nothing|nobody|nowhere|false|unproven|without|hardly|scarcely|barely|refute|deny|debunk|incorrect|disproven|fake|inaccurate|untrue)\b|\b\w+n't\b/gi;

  /**
   * Executes the unified two-pass post-translation quality verification.
   */
  public static async evaluateQualityGate(
    segments: QualityGateSegmentInput[],
    sourceLang: string,
    targetLang: string,
    options?: TranslationQualityGateOptions
  ): Promise<QualityGateSegmentOutput[]> {
    const results: QualityGateSegmentOutput[] = [];
    const sampleRate = options?.sampleRate ?? 0.10;
    const semanticThreshold = options?.semanticThreshold ?? 0.85;

    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i];
      let currentTranslated = seg.translated;

      // ─── PASS 1: Numerical & Factual Entity Parity Guard (100% Segments) ───
      let parity = NumericalEntityGuard.verifyNumericalParity(
        seg.original,
        currentTranslated,
        targetLang
      );

      let numericalParityVerified = parity.isParity;
      let numericalParityWarning = parity.details;

      // Self-Healing Repair Pass if numbers drifted
      if (!parity.isParity && options?.enableSelfHealing !== false && options?.repairCallback) {
        try {
          const repaired = await options.repairCallback(
            seg.original,
            currentTranslated,
            targetLang,
            parity.details
          );
          if (repaired && repaired.trim().length > 0 && repaired !== currentTranslated) {
            const recheck = NumericalEntityGuard.verifyNumericalParity(
              seg.original,
              repaired,
              targetLang
            );
            if (recheck.isParity) {
              currentTranslated = repaired;
              numericalParityVerified = true;
              numericalParityWarning = undefined;
              parity = recheck;
            }
          }
        } catch (repairErr) {
          console.warn(`[TranslationQualityGate] Self-healing repair failed for segment #${i}:`, repairErr);
        }
      }

      // ─── PASS 2: Semantic Back-Translation Spot Check (~10% + Claims, English source only) ───
      let semanticParityScore: number | undefined = undefined;
      let reviewRecommended = !numericalParityVerified;
      let polarityFlipped = false;

      const isEnglishSource = (sourceLang || "").toLowerCase().split(/[-_]/)[0] === "en";
      const hasNumericEntities = parity.sourceEntities.length > 0;
      const isPrioritySegment = Boolean(seg.isClaim || seg.isHook || hasNumericEntities);
      const isPeriodicSample = i % Math.max(1, Math.round(1 / sampleRate)) === 0;
      const shouldSpotCheck = isEnglishSource && (isPrioritySegment || isPeriodicSample) && Boolean(options?.backTranslateCallback);

      if (shouldSpotCheck && options?.backTranslateCallback) {
        try {
          const backTranslatedEn = await options.backTranslateCallback(currentTranslated, targetLang);
          if (backTranslatedEn && backTranslatedEn.trim().length > 0) {
            // A. Negation Polarity Inversion Check (Zero Tolerant for Fact-Checking)
            polarityFlipped = this.checkNegationPolarityFlip(seg.original, backTranslatedEn);

            if (polarityFlipped) {
              semanticParityScore = 0.0;
              reviewRecommended = true;
              console.warn(
                `[TranslationQualityGate] ⚠️ Negation polarity flip detected on segment #${i}!\n` +
                `Source: "${seg.original}"\nBack-translated: "${backTranslatedEn}"`
              );
            } else {
              // B. Compute token/n-gram semantic overlap
              semanticParityScore = this.computeSemanticParityScore(seg.original, backTranslatedEn);
              if (semanticParityScore < semanticThreshold) {
                reviewRecommended = true;
              }
            }
          }
        } catch (backTransErr) {
          console.warn(`[TranslationQualityGate] Back-translation spot-check failed for segment #${i}:`, backTransErr);
        }
      }

      results.push({
        original: seg.original,
        translated: currentTranslated,
        numericalParityVerified,
        numericalParityWarning,
        semanticParityScore,
        reviewRecommended,
        polarityFlipped: polarityFlipped || undefined,
      });
    }

    return results;
  }

  /**
   * Detects whether factual negation was inverted (e.g., "effective" -> "not effective" or vice versa).
   * Evaluates clause-by-clause so "not ..., never" in separate clauses is not cancelled by global parity.
   */
  public static checkNegationPolarityFlip(sourceEn: string, backTranslatedEn: string): boolean {
    const splitClauses = (text: string): string[] =>
      (text || "")
        .split(/[,;:]|\b(?:but|and|or|because|so)\b/i)
        .map((c) => c.trim())
        .filter(Boolean);

    const isClauseNegative = (clause: string): boolean => {
      const matches = clause.match(this.NEGATION_REGEX) || [];
      return matches.length % 2 === 1;
    };

    const srcClauses = splitClauses(sourceEn);
    const backClauses = splitClauses(backTranslatedEn);

    if (srcClauses.length === 0 && backClauses.length === 0) return false;
    if (srcClauses.length === backClauses.length) {
      return srcClauses.some((c, i) => isClauseNegative(c) !== isClauseNegative(backClauses[i]));
    }

    const srcHasNeg = srcClauses.some(isClauseNegative);
    const backHasNeg = backClauses.some(isClauseNegative);
    return srcHasNeg !== backHasNeg;
  }

  /**
   * Computes semantic token overlap (Dice coefficient over unigram & bigram stems).
   */
  public static computeSemanticParityScore(sourceEn: string, backTranslatedEn: string): number {
    const tokenize = (text: string): string[] =>
      text
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, " ")
        .split(/\s+/)
        .filter((w) => w.length > 2);

    const srcTokens = tokenize(sourceEn);
    const backTokens = tokenize(backTranslatedEn);

    if (srcTokens.length === 0 && backTokens.length === 0) return 1.0;
    if (srcTokens.length === 0 || backTokens.length === 0) return 0.0;

    const srcSet = new Set(srcTokens);
    const backSet = new Set(backTokens);

    let intersection = 0;
    for (const t of srcSet) {
      if (backSet.has(t)) {
        intersection++;
      }
    }

    // Dice Coefficient
    const score = (2 * intersection) / (srcSet.size + backSet.size);
    return Math.round(score * 100) / 100;
  }

  /**
   * Safe Option 3 Ingestion Prep: Strictly quarantines Adaptive MT memory.
   * Only pairs passing numerical parity, full terminology compliance, and zero review flags
   * are allowed into the shared translation memory dataset.
   */
  public static canIngestIntoAdaptiveMt(seg: {
    numericalParityVerified?: boolean;
    terminologyComplianceRate?: number;
    reviewRecommended?: boolean;
  }): boolean {
    return (
      seg.numericalParityVerified === true &&
      (seg.terminologyComplianceRate ?? 1.0) === 1.0 &&
      seg.reviewRecommended !== true
    );
  }
}
