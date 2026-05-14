import { FactCheckResult, VerifiedClaim, TranscriptData, InstitutionalTrustFactors, TrustVertical, TrustDeduction, AnalysisFailureReason, EvidenceLevel, VerificationState, ErrorState, UIReport, SynthesisResult, SynthesisOutput, TraceabilityMap, RepairSuggestion, ConsistencyIssue } from "../types";
import { getTrustLabelFromScore, computeCategoryAwareScore, mapUploadCategory } from "./categoryWeights";

/**
 * 🏛 SCORING ENGINE (v10.0 — Institutional Hardening)
 * 
 * Centralised engine for institutional trust scores, clinical reporting,
 * and evidence-bounded synthesis (v10.0).
 */
export class ScoringEngine {
  private static readonly SCORING_VERSION = "v11.0";

  /**
   * Calculate Trust Index from verified claims using Path 1 Epistemic Framework.
   * 
   * Internal Scale: 0–100 for all dimensions.
   * Public Display: 0–10.0 derived from compositeRating.
   * 
   * Composite Formula: (Truth * 0.35) + (Honesty * 0.40) + (Rationality * 0.25)
   */
  calculateInstitutionalTrustScore(
    videoId: string,
    userId: string,
    transcript: TranscriptData,
    allVerifiedClaims: VerifiedClaim[],
    extractedCount: number,
    scoringMethod: "strict" | "balanced" = "balanced",
    cautionLevel: "low" | "medium" | "high" = "medium",
    domain: string = "General",
    synthesisData: Partial<SynthesisResult> & { 
      extractionError?: string, 
      isLaunchNews?: boolean, 
      launchGrounded?: boolean,
      contentIntent?: any,
      speakerPriors?: any,
      speakerIdentities?: any,
      traceabilityMap?: TraceabilityMap,
      synthesisOutput?: SynthesisOutput
    },
    userHistory: any = {},
    videoCategory?: string,
    primaryVertical?: TrustVertical,
    verticalScores: Partial<Record<TrustVertical, number>> = {},
    synthesisTier: 'standard' | 'deep' | 'podcast' = 'standard',
    batchStats: { completed: number, timedOut: number } = { completed: 0, timedOut: 0 }
  ): FactCheckResult {
    const detectedVerticalScores = verticalScores && Object.keys(verticalScores).length > 0 ? verticalScores : this.detectVerticalScores(domain);
    const detectedPrimaryVertical = primaryVertical || (Object.entries(detectedVerticalScores).sort((a,b) => b[1] - a[1])[0][0] as TrustVertical);

    // v5.2: AI Capacity / Error Override
    if (synthesisData.extractionError) {
      return this.generateErrorResult(videoId, userId, transcript, synthesisData.extractionError, domain, scoringMethod);
    }

    // v8.2: Pre-Scoring Gate (Empty Content)
    if (extractedCount === 0) {
      const isLowInfo = synthesisData.contentIntent?.primaryIntent === 'editorial' || 
                        synthesisData.contentIntent?.primaryIntent === 'commentary' ||
                        domain === 'Politics' || domain === 'News';
      
      return this.generateEmptyResult(
        videoId, 
        userId, 
        transcript, 
        domain, 
        scoringMethod, 
        isLowInfo ? VerificationState.STRUCTURAL_ONLY : VerificationState.STRUCTURAL_ONLY // v10.0 Migration
      );
    }

    // 1. Accuracy Score - Refined: Faith-Based & Severity
    const stats = { 
      correct: 0, mostly_correct: 0, incorrect: 0, unsupported: 0, unverifiable: 0, ignored: 0, mixed: 0, faith: 0
    };

    const severityWeights: Record<string, number> = { low: 0.5, medium: 1.0, high: 2.0, extreme: 4.0 };
    let weightedTruthSum = 0;
    let totalSeveritySum = 0;

    allVerifiedClaims.forEach(c => {
      // HONESTY: Ignore opinions, satire, and unverified anecdotal content for accuracy scoring
      const subjectiveStatuses = ['opinion', 'anecdotal_experience', 'satire', 'value_judgment', 'preference_statement'];
      if (subjectiveStatuses.includes(c.status)) {
        stats.ignored++;
        return;
      }

      const severity = c.severity || 'medium';
      const sWeight = severityWeights[severity];
      totalSeveritySum += sWeight;

      if (c.status === 'faith_based' || c.status === 'faith_context') {
        stats.faith++;
        weightedTruthSum += 0.5 * sWeight;
      } else if (c.status === 'correct' || c.status === 'tradition_linked') {
        stats.correct++;
        weightedTruthSum += 1.0 * sWeight;
      } else if (c.status === 'mostly_correct') {
        stats.mostly_correct++;
        weightedTruthSum += 0.7 * sWeight;
      } else if (c.status === 'needs_context' || c.status === 'outdated') {
        stats.mixed++;
        weightedTruthSum += 0.4 * sWeight;
      } else if (c.status === 'unsupported' || c.status === 'unverifiable') {
        stats.unsupported++;
        weightedTruthSum += 0.2 * sWeight;
      } else if (c.status === 'incorrect') {
        stats.incorrect++;
        weightedTruthSum += 0;
      } else if (c.status === 'speculation' || c.status === 'developing_story') {
        // v5.2: Neutral handling for developing/speculative claims
        stats.ignored++;
        weightedTruthSum += 1.0 * sWeight;
      } else {
        // Fallback for any other status: ignore rather than penalizing
        stats.ignored++;
      }
    });

    const evaluatedCount = allVerifiedClaims.length;
    let accuracyScore: number | null = null;
    if (evaluatedCount > 0) {
      accuracyScore = (weightedTruthSum / (totalSeveritySum || 1)) * 100;
    }

    // 2. Evidence Quality Score
    const tierWeights: Record<string, number> = { 'A': 1.0, 'B': 0.85, 'C': 0.70, 'D': 0.20 };
    const evidenceSum = allVerifiedClaims.reduce((acc, c) => {
      if (c.evidenceLevel === 'INSUFFICIENT' || c.evidenceLevel === 'CONTRADICTED') return acc;
      const bestTier = c.richSources?.reduce((best, s) => Math.max(best, tierWeights[s.tier] || 0), 0) || 0;
      return acc + (bestTier * (c.importance || 0.5));
    }, 0);
    const evidenceScore = (evaluatedCount > 0) ? (evidenceSum / evaluatedCount) * 100 : null;

    // 2b. Consensus Score
    let consensusSum = 0;
    if (synthesisData.consensusFactor !== undefined) {
      consensusSum = synthesisData.consensusFactor * 100;
    } else {
      allVerifiedClaims.forEach(c => {
        const sourceCount = c.richSources?.length || 0;
        consensusSum += Math.min(1.0, sourceCount / 3);
      });
      consensusSum = (consensusSum / (evaluatedCount || 1)) * 100;
    }
    const consensusScore = evaluatedCount > 0 ? consensusSum : 80; // Neutral default

    // 3. Consistency Score — v11.0: with traceable contradiction reasoning
    let consistencyScore: number;
    const consistencyIssues: ConsistencyIssue[] = [];

    if (synthesisData.consistencyFactor !== undefined) {
      consistencyScore = synthesisData.consistencyFactor * 100;
      // If consistency is low, identify specific claim contradictions for transparency
      if (consistencyScore < 70) {
        const scorableClaims = allVerifiedClaims.filter(c => 
          !['opinion', 'anecdotal_experience', 'satire', 'value_judgment', 'preference_statement'].includes(c.status)
        );
        for (let i = 0; i < scorableClaims.length; i++) {
          for (let j = i + 1; j < scorableClaims.length; j++) {
            const ci = scorableClaims[i], cj = scorableClaims[j];
            // Flag pairs where one is correct and other is incorrect
            if (ci.status === 'correct' && cj.status === 'incorrect') {
              consistencyIssues.push({ claim1: ci.text, claim2: cj.text, type: 'mixed_accuracy', severity: 'medium' });
            } else if (ci.status === 'incorrect' && cj.status === 'correct') {
              consistencyIssues.push({ claim1: cj.text, claim2: ci.text, type: 'mixed_accuracy', severity: 'medium' });
            }
            // Flag pairs with conflicting evidence levels (one STRONG, other CONTRADICTED)
            if (ci.evidenceLevel === 'STRONG' && cj.evidenceLevel === 'CONTRADICTED') {
              consistencyIssues.push({ claim1: ci.text, claim2: cj.text, type: 'contradiction', severity: 'high' });
            } else if (ci.evidenceLevel === 'CONTRADICTED' && cj.evidenceLevel === 'STRONG') {
              consistencyIssues.push({ claim1: cj.text, claim2: ci.text, type: 'contradiction', severity: 'high' });
            }
          }
        }
      }
    } else {
      consistencyScore = 85; // neutral default when no synthesis data
    }

    // 4. Integrity Score
    const rawManip = synthesisData.manipulationScore !== undefined ? synthesisData.manipulationScore : 0.0;
    const integrityScore = (1 - rawManip) * 100;

    // 5. Expertise Score (v7: Blended Creator + Speaker Reputation)
    let expertiseScore = (userHistory.reputation || 0.5) * 100;
    
    if (synthesisData.speakerPriors && Object.keys(synthesisData.speakerPriors).length > 0) {
      const priorScores = Object.values(synthesisData.speakerPriors).map((p: any) => p.trustScore || 50);
      const avgSpeakerRep = priorScores.reduce((a, b) => a + b, 0) / priorScores.length;
      
      // Weight: 90% Creator, 10% Speaker Average
      expertiseScore = (expertiseScore * 0.9) + (avgSpeakerRep * 0.1);
    }

    // v8.6: Pre-map category for evergreen detection
    const initialMappedCategory = mapUploadCategory(videoCategory);

    // 6. Freshness Score (v5.0: Launch News boost)
    let freshnessSum = 0;
    const now = Date.now();
    const halfLifeDays = 365 * 2;

    // v5.0: If launch news was detected AND grounding confirmed it, boost freshness
    if (synthesisData.isLaunchNews && synthesisData.launchGrounded) {
      freshnessSum = Math.max(evaluatedCount, 1) * 0.95; // Very fresh, confirmed launch
    } else if (synthesisData.isLaunchNews) {
      // Launch detected but not confirmed — moderate boost
      freshnessSum = Math.max(evaluatedCount, 1) * 0.80;
    } else {
      allVerifiedClaims.forEach(c => {
        if (c.trueAsOf) {
          const ageInDays = (now - new Date(c.trueAsOf).getTime()) / (1000 * 60 * 60 * 24);
          freshnessSum += Math.exp(-ageInDays / halfLifeDays);
        } else {
          freshnessSum += 0.9;
        }
      });
    }
    const evergreenCategories = ['science_trivia', 'entertainment', 'culture', 'history'];
    const isEvergreen = evergreenCategories.includes(initialMappedCategory || "");
    const freshnessScore = (evaluatedCount > 0) ? (freshnessSum / evaluatedCount) * 100 : (isEvergreen ? 95 : 90);

    // 7. Safety Score (v8.5 Calibration)
    // Baseline is 100. Only deduct if actual harm/incorrectness is found.
    const incorrectHighSeverity = allVerifiedClaims.filter(c => c.status === 'incorrect' && (c.severity === 'high' || c.severity === 'extreme')).length;
    let safetyScore = 100;
    if (incorrectHighSeverity > 0) {
      const DOMAIN_RISK: Record<string, number> = {
        Health: 0.6, Finance: 0.7, Politics: 0.8, Technology: 0.9, General: 1.0, Science: 0.9
      };
      const domainMultiplier = DOMAIN_RISK[domain] || 1.0;
      safetyScore = domainMultiplier * 100;
    }

    // 8. Dimensional Scoring (v8.5 Path 1)
    
    // rationality = (consistency * 0.35 + integrity * 0.30 + uncertaintyDisclosure * 0.20 + manipulationResistance * 0.15)
    const uncertaintyDisclosure = (stats.ignored / (evaluatedCount || 1)) * 100;
    const manipulationResistance = (1 - rawManip) * 100;
    const rationalityScoreInternal = (consistencyScore * 0.35) + (integrityScore * 0.30) + (uncertaintyDisclosure * 0.20) + (manipulationResistance * 0.15);

    // v8.8: truthScoreInternal is now dynamically calculated below to prevent composite inflation
    let truthScoreInternal: number | null = null;

    const factors: InstitutionalTrustFactors = {
      accuracy: accuracyScore, // v8.8: null when unverified
      evidence: evidenceScore, // v8.8: null when unverified
      consensus: consensusScore,
      consistency: consistencyScore,
      integrity: integrityScore,
      expertise: expertiseScore,
      freshness: freshnessScore,
      safety: safetyScore,
      honesty: 0, // Updated via categoryResult below
    };

    const primaryIntent = synthesisData.contentIntent?.primaryIntent || 'factual';

    // v8.1 Stable: Category-Aware Epistemic Scoring & Hardening
    const categoryResult = computeCategoryAwareScore(
      {
        accuracy: accuracyScore ?? 100, // Weighted sum requires a baseline
        evidence: evidenceScore ?? 90,
        consensus: consensusScore,
        consistency: consistencyScore,
        integrity: integrityScore,
        expertise: expertiseScore,
        freshness: freshnessScore,
        safety: safetyScore,
      },
      allVerifiedClaims.map(c => {
        const framingAnalysis = this.analyzeFraming(c.text, primaryIntent);
        return {
          status: c.status,
          severity: c.severity,
          claimNature: c.nature || (c.ontology as any) || 'FACTUAL',
          framingStyle: c.framing || framingAnalysis.style,
          evidenceLevel: c.evidenceLevel || EvidenceLevel.NONE,
          honestyWashingRisk: c.honestyWashingRisk || framingAnalysis.isHonestyWashed || false,
          text: c.text,
          claimType: c.claimType || 'unclear',
          assertiveness: c.assertiveness || (framingAnalysis.style.toLowerCase() as any) || 'moderate',
          claimStrength: c.claimStrength || (framingAnalysis.style.toLowerCase() as any) || 'moderate'
        };
      }),
      videoCategory,
      detectedPrimaryVertical,
      consensusScore,
      primaryIntent
    );

    const mappedCategory = categoryResult.profile.category;
    factors.freshness = freshnessScore;

    // v8.8: Dynamic Composite Reweighting
    const honestyScoreInternal = categoryResult.honestyBreakdown.score; // 0-100 scale (v8.8 synchronized)
    factors.honesty = honestyScoreInternal;
    (factors as any).intentToMislead = categoryResult.intentToMisleadScore;
    (factors as any).rationality = rationalityScoreInternal;

    const evaluatedClaimsCount = allVerifiedClaims.filter(c => 
      c.status !== 'opinion' && c.status !== 'anecdotal_experience' && 
      c.status !== 'value_judgment' && c.status !== 'preference_statement' &&
      c.status !== 'satire' && c.status !== 'speculation' && c.status !== 'developing_story'
    ).length;

    let compositeRatingInternal: number;
    if (evaluatedClaimsCount === 0) {
      // v8.8: Structural-only composite (Honesty + Rationality)
      // Ratio 0.40 : 0.25 => 0.62 : 0.38
      compositeRatingInternal = (honestyScoreInternal * 0.62) + (rationalityScoreInternal * 0.38);
      truthScoreInternal = null;
    } else {
      truthScoreInternal = ((accuracyScore ?? 100) * 0.7) + ((evidenceScore ?? 90) * 0.3);
      // v10.0 Fix: Use categoryResult.finalScore as the source of truth for composite rating
      compositeRatingInternal = categoryResult.finalScore;
    }

    const rawScoreBeforeCap = evaluatedClaimsCount === 0
      ? compositeRatingInternal  // v8.8: Use the structural composite as the "raw" score
      : categoryResult.finalScore; // v10.0 Fix: Use finalScore (which includes deductions) to ensure parity



    // Hard Cap: If any claim is CONTRADICTED, cap composite at 30
    const hasContradicted = allVerifiedClaims.some(c => c.evidenceLevel === 'CONTRADICTED');
    if (hasContradicted) {
      compositeRatingInternal = Math.min(compositeRatingInternal, 30);
    }

    // State Guards: null composite for Satire/Faith/LowInfo
    const isSubjectiveOnly = (synthesisData.contentIntent?.primaryIntent === 'editorial' || synthesisData.contentIntent?.primaryIntent === 'commentary') && stats.correct === 0 && stats.incorrect === 0;
    const shouldSuspendScoring = synthesisData.isLaunchNews && !synthesisData.launchGrounded;

    const finalTrustScore = Math.round(compositeRatingInternal);
    const displayScore: number | null = (isSubjectiveOnly || shouldSuspendScoring) ? null : Math.round(compositeRatingInternal) / 10;
    const contentIntent = synthesisData.contentIntent;

    const harmCapApplied = categoryResult.harmCap.applied;
    const harmCapReason = categoryResult.harmCap.reason;

    // v5.3: Multi-Speaker Dynamics (Rebuttals, Neutrality, Overlap)
    let speakerDynamicsNotes: string[] = [];
    let finalTrustScoreAdjusted = finalTrustScore;
    if (synthesisData.pipelineMode === "multi" || synthesisData.pipelineMode === "debate") {
      const speakerDynamics = this.calculateMultiSpeakerDynamics(allVerifiedClaims, synthesisData);
      finalTrustScoreAdjusted += speakerDynamics.scoreImpact;
      speakerDynamicsNotes = speakerDynamics.notes || [];
    }

    // v4.1: Repeat Offender Modifier
    const repeatOffenderModifier = Math.max(0.7, 1 - (userHistory.misinfoStrikes * 0.1));
    finalTrustScoreAdjusted *= repeatOffenderModifier;
    
    // v8.2: State-Aware Label Mapping (Strict)
    // v8.5: Use versioned label mapping
    const scoreForLabel = displayScore ?? (finalTrustScoreAdjusted / 10);
    let trustLabel: string = getTrustLabelFromScore(scoreForLabel, harmCapApplied, mappedCategory);

    if (contentIntent && contentIntent.primaryIntent === 'promotional') {
      if (scoreForLabel >= 7.5) trustLabel = "Reliable Promotion";
      else if (scoreForLabel >= 5.5) trustLabel = "Promotional \u2013 Verify Independently";
      else trustLabel = "Misleading Promotion";
    } else if (contentIntent && contentIntent.primaryIntent === 'editorial') {
      if (scoreForLabel >= 7.5) trustLabel = "Well-Supported Opinion";
      else if (scoreForLabel >= 5.5) trustLabel = "Editorial \u2013 Mixed Support";
      else trustLabel = "Poorly Supported Opinion";
    } else if (contentIntent && contentIntent.primaryIntent === 'commentary') {
      if (scoreForLabel >= 7.5) trustLabel = "In-Depth Legal/Political Inquiry";
      else if (scoreForLabel >= 6.0) trustLabel = "Commentary \u2013 Mixed Detail";
      else trustLabel = "Poorly Supported Commentary";
    } else if (contentIntent && contentIntent.primaryIntent === 'testimonial') {
      if (scoreForLabel >= 6.5) trustLabel = "Trusted Testimonial";
      else trustLabel = "Testimonial \u2013 Unverified";
    } else if (contentIntent && contentIntent.primaryIntent === 'entertainment') {
      if (scoreForLabel >= 8.0) trustLabel = "High Quality Entertainment";
      else if (scoreForLabel >= 6.0) trustLabel = "Lighthearted Content";
      else trustLabel = "Low Reliability Entertainment";
    }

    // v8.2: Final Analysis State Check (v10.0 Verification Machine)
    let finalState: VerificationState;

    if (evaluatedClaimsCount === 0 && extractedCount === 0) {
      finalState = VerificationState.STRUCTURAL_ONLY;
    } else if (evaluatedClaimsCount === 0 && extractedCount > 0) {
      finalState = VerificationState.INSUFFICIENT_EVIDENCE;
    } else if (allVerifiedClaims.length < extractedCount * 0.5) {
      finalState = VerificationState.PARTIALLY_VERIFIED;
    } else {
      finalState = VerificationState.VERIFIED;
    }

    const claimConfidence = Math.min(1.0, (allVerifiedClaims.length / 10));
    const evidenceConfidence = evidenceScore !== null ? evidenceScore / 100 : 0; 
    let confidence = (claimConfidence * 0.6) + (evidenceConfidence * 0.4);
    
    if (finalState === VerificationState.STRUCTURAL_ONLY) {
      confidence = Math.max(0.15, confidence); // v10.0: floor for clean structural analyses
    } else if (finalState === VerificationState.INSUFFICIENT_EVIDENCE) {
      confidence = Math.max(0.10, confidence); // v10.0: claims found, just unverifiable
    }

    const confidenceCalibrated = confidence;
    const confidenceTier = confidenceCalibrated > 0.8 ? 'high' : confidenceCalibrated > 0.5 ? 'medium' : 'low';

    // 11. Creator Repair Path & Confidence Notes (v5.0: Signal Coherence)
    const diagnostics: string[] = [];
    const confidenceNotes: string[] = [];
    if (speakerDynamicsNotes.length > 0) confidenceNotes.push(...speakerDynamicsNotes);

    const evaluatedClaims = evaluatedClaimsCount;

    if (evaluatedClaims === 0) {
      if (synthesisData.extractionError === 'AI_CAPACITY_EXCEEDED') {
        confidenceNotes.push("The AI provider is currently at capacity. Analysis is incomplete.");
      } else {
        confidenceNotes.push("No factual claims were verified — score reflects structural analysis only.");
      }
      if (extractedCount > 0 && !synthesisData.extractionError) {
        confidenceNotes.push(`${extractedCount} claims were extracted but routed as non-factual or filtered.`);
      }
      confidenceNotes.push("Seek independent verification before relying on this content.");
    } else {
      if (factors.accuracy !== null && factors.accuracy < 70) confidenceNotes.push("Significant factual discrepancies detected in key claims.");
      if (factors.evidence !== null && factors.evidence < 60) confidenceNotes.push("Limited independently verifiable source evidence.");
      if (factors.consensus < 60) confidenceNotes.push("Weak corroboration from mainstream academic or news consensus.");
      if (confidenceNotes.length === 0) confidenceNotes.push("High evidence density and source agreement.");
    }
    
    if (factors.evidence !== null && factors.evidence < 60 && evaluatedClaims > 0) diagnostics.push("Critical: Missing authoritative source citations.");
    if (factors.evidence !== null && factors.evidence < 60 && evaluatedClaims === 0) diagnostics.push("Critical: No claims reached the verification engine.");
    if (factors.integrity < 60 && primaryIntent !== 'entertainment') diagnostics.push("Note: Manipulation signals detected (framing/rage-bait).");
    if (factors.integrity < 40 && primaryIntent === 'entertainment') diagnostics.push("Note: Highly sensationalist framing detected.");

    // 12. Human Review Triggers (v4.1.1)
    const reviewTrigger = this.shouldTriggerHumanReview(displayScore ?? 0, detectedPrimaryVertical, accuracyScore ?? 100, confidence);

    // 14. v5.1: Calculate Detailed Deductions (Transparency for Creators)
    const deductions: TrustDeduction[] = [];
    const finalWeights = categoryResult.profile.weights;
    const baseComposite = categoryResult.rawWeightedScore;

    Object.entries(factors).forEach(([key, score]) => {
      if (score === null) return; // v8.8: Skip unverified factors to prevent false deductions
      const factorKey = key as keyof InstitutionalTrustFactors;
      const weight = finalWeights[factorKey] || 0;
      // v10.0 Correction (BUG #4): Deduction math must use / 10000 for integer weights (e.g. 10) 
      // to match the expected 0.08 scale (8% of 1.0 points off a 10.0 rating)
      let pointsLost = ((100 - score) * weight) / 10000; 

      // v8.6: Deduction Cap System
      // Prevent single-factor alarmism from crashing the score.
      const isCritical = (factorKey === 'accuracy' || factorKey === 'safety') && score < 40;
      if (!isCritical && pointsLost > 40) {
        pointsLost = 40; // Cap at 4.0 points (40% of a maxed weight)
      }

      if (pointsLost >= 0.1) { // Only record significant deductions
        deductions.push({
          factor: factorKey,
          points: Number(pointsLost.toFixed(1)),
          reason: this.getDeductionReason(factorKey, score, stats, allVerifiedClaims, primaryIntent)
        });
      }
    });

    // Add intent/reputation deductions if any
    if (repeatOffenderModifier < 1.0) {
      const reputationLoss = (baseComposite * (1 - repeatOffenderModifier)) / 1000;
      deductions.push({
        factor: 'reputation',
        points: Number(reputationLoss.toFixed(1)),
        reason: "Points deducted due to past misinformation strikes on this account."
      });
    }

    // Sort deductions by impact
    deductions.sort((a, b) => b.points - a.points);

    // v8.8: Downstream null-safe checks for accuracy/evidence
    if (factors.accuracy !== null && factors.accuracy < 70) {
       // Logic for accuracy-specific signals if needed
    }

    // 15. Checked claims ratio for transparency
    const checkedClaimsRatio = extractedCount > 0 ? evaluatedClaims / extractedCount : 0;

    // v10.6: Reanalysis flag — set when >30% of claims timed out
    const timedOutCount = allVerifiedClaims.filter(
      c => c.timedOutAt ||
           (c.status === 'unsupported' && c.reasoning?.includes('timed out'))
    ).length;
    const reanalysisAvailable = extractedCount > 0 &&
      (timedOutCount / extractedCount) > 0.30;

    // v11.0: Generate Creator Repair Path — actionable, claim-specific suggestions
    const repairSuggestions = this.generateCreatorRepairPath(allVerifiedClaims, evaluatedClaims, extractedCount);

    return {
      videoId,
      userId,
      transcript,
      analysisState: finalState,
      scoreAvailable: true,
      trustScore: Math.round(compositeRatingInternal), // 0-100 scale
      videoRating: displayScore ?? 0, // 0-10.0 scale
      trustLabel: trustLabel as any,
      confidence: synthesisData.extractionError ? 0.1 : confidenceCalibrated,
      confidenceTier: synthesisData.extractionError ? 'low' : confidenceTier,
      confidenceNotes: confidenceNotes.slice(0, 3),
      scoringVersion: ScoringEngine.SCORING_VERSION,
      
      factors,
      deductions,
      vertical: primaryVertical,
      verticalScores,
      contentIntent: contentIntent || undefined,
      reviewTriggered: reviewTrigger.triggered,
      reviewReason: reviewTrigger.reason,
      factCheckStats: {
        totalClaims: extractedCount,
        extractedClaims: extractedCount,
        evaluatedClaims,
        correct: stats.correct,
        mostly_correct: stats.mostly_correct,
        incorrect: stats.incorrect,
        unsupported: stats.unsupported,
        unverifiable: stats.unverifiable,
        faith: stats.faith,
        ignored: extractedCount - allVerifiedClaims.length,
        checkedClaimsRatio,
      },
      diagnostics,
      chapters: [],
      speakers: [],
      speakerIdentities: synthesisData.speakerIdentities || {},
      claims: allVerifiedClaims,
      scoringMethod: 'balanced' as const,
      isLongform: false,
      isFinal: true,
      generatedAt: Date.now(),
      verifiedAsOf: new Date().toISOString().split('T')[0],
      language: "en",
      riskDomain: detectedPrimaryVertical,
      domainRiskMultiplier: 1.0,
      versions: { model: "Gemini 2.5 Multi-Model", scoring: ScoringEngine.SCORING_VERSION, registry: "v3-blended" },
      
      // v8.5 Path 1 Public Scores
      truthScore: truthScoreInternal !== null ? Math.round(truthScoreInternal) : null,
      honestyScore: Math.round(honestyScoreInternal),
      rationalityScore: Math.round(rationalityScoreInternal),
      compositeRating: displayScore,

      // v10.0 Institutional Enhancements
      structuralReliabilityScore: evaluatedClaims === 0 ? compositeRatingInternal : null,
      verificationState: finalState,
      synthesisOutput: synthesisData.synthesisOutput,
      traceabilityMap: synthesisData.traceabilityMap as any,

      // v8.0/v8.1 Category-Aware Fields
      videoCategory,
      categoryWeightProfile: categoryResult.profile.weights as any,
      honestyBreakdown: categoryResult.honestyBreakdown,
      contextualFlags: categoryResult.contextualFlags,
      harmCapApplied,
      harmCapReason,
      rawScoreBeforeCap,
      penaltyApplied: categoryResult.penaltyApplied,
      
      // v8.1 Hardening Fields
      hardeningMetadata: categoryResult.hardeningMetadata,
      intentToMisleadScore: categoryResult.intentToMisleadScore,
      effectiveCategory: categoryResult.effectiveCategory,

      // v10.6: Verification Quality Signal
      reanalysisAvailable,

      // v11.0: Production Hardening
      repairSuggestions,
      consistencyIssues,

      uiReport: this.generateUIReport({
        truthScore: (evaluatedClaims > 0 && truthScoreInternal !== null) ? Math.round(truthScoreInternal!) : null,
        honestyScore: (evaluatedClaims > 0 || synthesisData.consistencyFactor !== undefined) ? Math.round(honestyScoreInternal) : null,
        rationalityScore: rationalityScoreInternal !== null ? Math.round(rationalityScoreInternal) : null,
        compositeRating: displayScore,
        trustLabel: trustLabel as any,
        analysisState: finalState,
        verificationState: finalState,
        deductions,
        confidenceNotes,
        claims: allVerifiedClaims,
        viewerNote: synthesisData.viewerNote || "",
        confidenceTier,
        harmCapApplied,
        manipulationScore: synthesisData.manipulationScore,
        weights: finalWeights,
        factCheckStats: {
          extractedClaims: extractedCount,
          evaluatedClaims,
          correct: stats.correct,
          incorrect: stats.incorrect
        },
        synthesisOutput: synthesisData.synthesisOutput
      }),
      synthesisTier,
      deepResearchMetrics: (synthesisTier === 'deep' || synthesisTier === 'podcast') ? {
        claimsAttempted: evaluatedClaims,
        claimsGrounded: allVerifiedClaims.filter(c => c.isGrounded).length,
        totalSourcesFound: allVerifiedClaims.reduce((acc, c) => acc + (c.richSources?.length || 0), 0),
        uniqueDomainsFound: new Set(allVerifiedClaims.flatMap(c => c.richSources?.map(s => {
          try { return new URL(s.url).hostname.replace('www.', ''); } catch(e) { return 'registry'; }
        }) || [])).size,
        tierASourceCount: allVerifiedClaims.reduce((acc, c) => acc + (c.richSources?.filter(s => s.tier === 'A').length || 0), 0),
        tierBSourceCount: allVerifiedClaims.reduce((acc, c) => acc + (c.richSources?.filter(s => s.tier === 'B').length || 0), 0),
        batchesCompleted: batchStats.completed,
        batchesTimedOut: batchStats.timedOut,
        estimatedCostUsd: this.estimateDeepResearchCost(evaluatedClaims).estimatedCostUsd
      } : undefined
    } as FactCheckResult;
  }

  /**
   * v4.3: Get intent-specific weight overrides
   * Supplements LLM by identifying specific linguistic markers for framing.
   */
  private analyzeFraming(text: string, primaryIntent?: string): { style: string; isHonestyWashed: boolean } {
    const lowText = text.toLowerCase();
    
    const absoluteMarkers = [/\bproven\b/, /\bguaranteed\b/, /\bobvious fact\b/, /\bwithout question\b/, /\balways\b/, /\bnever\b/];
    const hedgedMarkers = [/\bmay\b/, /\bmight\b/, /\bpossibly\b/, /\bcould\b/, /\bevidence suggests\b/, /\bsome say\b/, /\bpotentially\b/];
    const manipulativeMarkers = [/\bcrazy\b/, /\bstunning\b/, /\boutrageous\b/, /\bcorrupt\b/, /\bwoke\b/, /\bdangerous\b/];

    let style = "ASSERTIVE";
    
    // v8.5: Distinguish between hype and manipulation
    const isHype = manipulativeMarkers.some(m => m.test(lowText)) && 
                  (lowText.includes('crazy') || lowText.includes('stunning') || lowText.includes('amazing'));
    
    if (manipulativeMarkers.some(m => m.test(lowText))) {
      if (primaryIntent === 'entertainment' && isHype) {
        style = "ASSERTIVE"; // Soften hype in entertainment
      } else {
        style = "MANIPULATIVE";
      }
    } else if (absoluteMarkers.some(m => m.test(lowText))) {
      style = "ABSOLUTE";
    } else if (hedgedMarkers.some(m => m.test(lowText))) {
      style = "HEDGED";
    }

    // Honesty washing signal: opinion framing + factual sounding claim
    const isHonestyWashed = (lowText.startsWith("in my opinion") || lowText.startsWith("i believe")) && absoluteMarkers.some(m => m.test(lowText));

    return { style, isHonestyWashed };
  }

  /**
   * 🎭 v5.3: Multi-Speaker Dynamics Engine
   * Calculates the impact of speaker interactions on the overall trust score.
   */
  private calculateMultiSpeakerDynamics(claims: VerifiedClaim[], data: any): { scoreImpact: number; notes: string[] } {
    let scoreImpact = 0;
    const notes: string[] = [];
    const mode = data.pipelineMode;

    // 1. Rebuttal Presence (Positive Signal)
    const rebuttals = claims.filter(c => c.text.toLowerCase().includes("rebutted") || c.text.toLowerCase().includes("corrected"));
    if (rebuttals.length > 0) {
      scoreImpact += Math.min(rebuttals.length * 0.5, 2.0);
      notes.push(`Detected ${rebuttals.length} instances of internal factual correction.`);
    }

    // 2. Host Neutrality (Strategic Boost)
    if (mode === "debate" || mode === "multi") {
      const hostClaims = claims.filter(c => c.speaker?.toLowerCase().includes("host") || c.speaker?.toLowerCase().includes("interviewer"));
      const hostAccuracy = hostClaims.length > 0 
        ? hostClaims.filter(c => c.status === "correct").length / hostClaims.length 
        : 1.0;
      
      if (hostAccuracy > 0.9) {
        scoreImpact += 1.5;
        notes.push("Host demonstrated high neutrality and factual framing.");
      }
    }

    // 3. Overlap / Crosstalk Penalty (Negative Confidence Signal)
    if (data.manipulationSignals?.some((s: string) => s.toLowerCase().includes("interruption") || s.toLowerCase().includes("crosstalk"))) {
      scoreImpact -= 1.0;
      notes.push("Frequent crosstalk/interruption detected; reducing dialogue clarity score.");
    }

    return { scoreImpact, notes };
  }

  private detectVerticalScores(domain: string): Record<TrustVertical, number> {
    const d = domain.toLowerCase();
    const scores: Record<TrustVertical, number> = {
      general: 0.1, finance: 0, health: 0, religion: 0, history: 0, politics: 0
    };

    if (d.includes('finance') || d.includes('invest')) scores.finance = 0.9;
    if (d.includes('health') || d.includes('med')) scores.health = 0.9;
    if (d.includes('religion') || d.includes('faith')) scores.religion = 0.9;
    if (d.includes('history') || d.includes('archaeo')) scores.history = 0.9;
    if (d.includes('politics') || d.includes('elect')) scores.politics = 0.9;
    
    // Default to general if nothing else is strong
    if (Object.values(scores).reduce((a,b) => a+b) < 0.2) scores.general = 0.9;

    return scores;
  }

  private shouldTriggerHumanReview(score: number | null, vertical: TrustVertical, accuracy: number, confidence: number): { triggered: boolean, reason?: string } {
    if (vertical === 'health' && accuracy < 50) return { triggered: true, reason: "High-risk Health content with critical accuracy failure." };
    if (vertical === 'finance' && (score || 0) < 40) return { triggered: true, reason: "Critical Finance reliability failure." };
    if (confidence < 0.3 && (score || 0) > 70) return { triggered: true, reason: "Anomalous high score with extremely low system confidence." };
    // Virality/Appeal triggers are handled at the layer level
    return { triggered: false };
  }

  private getDeductionReason(
    factor: keyof InstitutionalTrustFactors, 
    score: number, 
    stats: any, 
    claims: VerifiedClaim[] = [],
    primaryIntent: string = 'factual'
  ): string {
    const evaluatedCount = stats.evaluatedClaims || 0;
    
    switch (factor) {
      case 'accuracy':
        if (evaluatedCount === 0) return "No claims reached verification; accuracy metrics unavailable.";
        const failedClaims = claims.filter(c => c.status === 'incorrect').slice(0, 2).map(c => `"${c.text.substring(0, 30)}..."`).join(', ');
        return `Factual discrepancies detected in claims like: ${failedClaims || 'unverified statements'}.`;
      case 'evidence':
        if (evaluatedCount === 0) return "No factual claims were verified to support evidence strength.";
        return "Lack of authoritative, checkable source citations or direct evidence.";
      case 'consensus':
        if (evaluatedCount === 0) return "Factual consensus cannot be determined without verified claims.";
        return "Claims contradict established academic, scientific, or institutional consensus.";
      case 'consistency':
        return "Significant internal contradictions or shifts in narrative logic.";
      case 'integrity':
        if (primaryIntent === 'entertainment') return "Use of sensationalist hype or emotional framing.";
        const manipClaims = claims.filter(c => (c as any).framing === 'MANIPULATIVE').slice(0, 2).map(c => `"${c.text.substring(0, 30)}..."`).join(', ');
        return `Presence of manipulation signals or emotional bias in claims like: ${manipClaims || 'narrative segments'}.`;
      case 'expertise':
        return "Lack of specialized knowledge, credentials, or primary-source authority.";
      case 'honesty':
        if (evaluatedCount === 0) return "Casual presentation style with low verifiable density.";
        return "Implicit bias or assertiveness-reality mismatch detected in narrative framing.";
      case 'freshness':
        const isEvergreen = ['science_trivia', 'entertainment', 'culture', 'history'].includes(primaryIntent);
        if (isEvergreen) return "Contextually stable information, though verified timestamp is not current.";
        return "Information is outdated or superseded by more recent verified data.";
      case 'safety':
        const dangerousClaims = claims.filter(c => c.status === 'incorrect' && (c.severity === 'high' || c.severity === 'extreme'));
        if (dangerousClaims.length > 0) {
          return `Content contains potentially harmful misinformation regarding: ${dangerousClaims[0].text.substring(0, 40)}...`;
        }
        return `General domain risk for ${primaryIntent} content without specific verified safety evidence.`;
      case 'rationality':
        return "Logical consistency or epistemic framing issues detected in narrative structure.";
      case 'intentToMislead':
        return "Strategic manipulation patterns detected \u2014 content may be designed to mislead.";
      case 'reputation':
        return "Points deducted due to past misinformation strikes on this account.";
      default:
        return `Reliability signal detected for factor: ${factor}.`;
    }
  }

  /**
   * Generate human-readable summary (v4.1.1 Stable Names)
   */
  generateSummary(result: FactCheckResult): string {
    const score = result.trustScore;
    const date = result.verifiedAsOf || new Date().toISOString().split('T')[0];

    let summary = `\n📊 RELIABILITY: ⭐ ${score !== null ? score : 'N/A'}/100\n`;
    summary += `Verdict:   ${result.trustLabel}\n`;
    summary += `Evidence:  ${(result.factors && result.factors.evidence !== null) ? Math.round(result.factors.evidence) : 'N/A'}% (Evidence Strength)\n`;
    summary += `Momentum:  ${(result as any).trendSignal || 'Stable'} (Trend Signal)\n`;
    summary += `Consensus: Current as of ${date}\n`;
    
    summary += `\n🔍 WHY THIS SCORE?\n`;
    if (result.confidenceNotes && result.confidenceNotes.length > 0) {
      result.confidenceNotes.forEach((note: string) => summary += `  • ${note}\n`);
    } else {
      summary += `  • High evidence quality and source agreement.\n`;
    }

    if (result.deductions && result.deductions.length > 0) {
      const currentRating = result.videoRating ?? (result.trustScore !== null ? result.trustScore / 10 : 0);
      const totalLost = (10 - currentRating).toFixed(1);
      summary += `\n📉 RATING DEDUCTIONS (-${totalLost} points total):\n`;
      result.deductions.slice(0, 4).forEach(d => {
        summary += `  • -${d.points} pts: ${d.reason}\n`;
      });
    }

    summary += `\n💡 REPAIR PATH:\n`;
    if (result.diagnostics && result.diagnostics.length > 0) {
      result.diagnostics.forEach((tip: string) => summary += `  • ${tip}\n`);
    } else {
      summary += `  • Maintain current evidence standards.\n`;
    }

    if (result.reviewTriggered) {
      summary += `\n⚖️ GOVERNANCE: System has flagged this for human audit (${result.reviewReason})\n`;
    }

    return summary;
  }

  getRatingCategory(
    score: number
  ): "excellent" | "good" | "mixed" | "poor" {
    if (score >= 90) return "excellent";
    if (score >= 75) return "good";
    if (score >= 60) return "mixed";
    return "poor";
  }

  calculateConfidenceInterval(
    result: FactCheckResult,
    confidenceLevel: number = 0.95
  ): { lower: number; upper: number; margin: number } {
    const stats = result.factCheckStats;
    const evaluatedCount = stats.evaluatedClaims;

    const p = (result.trustScore ?? 0) / 100;
    const z = 1.96;

    if (evaluatedCount < 2) {
      return { lower: 0, upper: 100, margin: 50 };
    }

    const margin = (z * Math.sqrt((p * (1 - p)) / evaluatedCount)) * 100;
    const lower = Math.max(0, (result.trustScore ?? 0) - margin);
    const upper = Math.min(100, (result.trustScore ?? 0) + margin);

    return { 
      lower: Math.round(lower * 10) / 10, 
      upper: Math.round(upper * 10) / 10, 
      margin: Math.round(margin * 10) / 10 
    };
  }

  private generateErrorResult(videoId: string, userId: string, transcript: TranscriptData, error: string, domain: string, scoringMethod: string): FactCheckResult {
    let failureReason: AnalysisFailureReason = "UNKNOWN_ERROR";
    let viewerNote = "An unexpected error occurred during analysis.";

    if (error === 'AI_CAPACITY_EXCEEDED') {
      failureReason = "AI_CAPACITY";
      viewerNote = "The AI provider is currently at capacity. Analysis is incomplete.";
    } else if (error.includes('TIMEOUT')) {
      failureReason = "TIMEOUT";
      viewerNote = "The analysis timed out. Please try again later.";
    }

    return {
      videoId: videoId,
      userId: userId,
      transcript: transcript,
      analysisState: ErrorState.FAILED,
      scoreAvailable: false,
      analysisFailureReason: failureReason,
      viewerNote,
      trustScore: null,
      trustLabel: "Analysis Unavailable",
      confidence: 0.1,
      confidenceTier: 'low',
      scoringVersion: ScoringEngine.SCORING_VERSION,
      factors: null,
      chapters: [],
      speakers: [],
      claims: [],
      factCheckStats: { totalClaims: 0, extractedClaims: 0, evaluatedClaims: 0, correct: 0, incorrect: 0, unsupported: 0, mostly_correct: 0, unverifiable: 0, ignored: 0, faith: 0, checkedClaimsRatio: 0 },
      vertical: (domain?.toLowerCase() as any) || 'general',
      verticalScores: { general: 0, politics: 0, health: 0, finance: 0, history: 0, religion: 0 },
      diagnostics: [`Error: ${error}`],
      sourceLedger: {},
      generatedAt: Date.now(),
      verifiedAsOf: new Date().toISOString().split('T')[0],
      language: transcript.language,
      riskDomain: domain.toLowerCase(),
      domainRiskMultiplier: 1,
      scoringMethod: scoringMethod as any,
      isLongform: false,
      isFinal: true,
      synthesisTier: 'standard',
      deductions: [],
      versions: {
        model: "Gemini 2.5 Multi-Model",
        scoring: ScoringEngine.SCORING_VERSION,
        registry: "v3-blended"
      },
      uiReport: this.generateUIReport({
        truthScore: null,
        honestyScore: null,
        rationalityScore: null,
        compositeRating: null,
        trustLabel: "Analysis Unavailable",
        analysisState: ErrorState.FAILED,
        deductions: [],
        confidenceNotes: [viewerNote],
        claims: [],
        viewerNote,
        confidenceTier: 'low'
      })
    };
  }

  private generateEmptyResult(
    videoId: string, 
    userId: string, 
    transcript: TranscriptData, 
    domain: string, 
    scoringMethod: string,
    state: VerificationState = VerificationState.STRUCTURAL_ONLY
  ): FactCheckResult {
    const label = state === VerificationState.STRUCTURAL_ONLY ? "No Verifiable Claims" : "Not Applicable";
    const note = state === VerificationState.STRUCTURAL_ONLY 
      ? "No factual claims were identified in this content."
      : "This content type does not require factual verification.";

    return {
      videoId: videoId,
      userId: userId,
      scoringVersion: ScoringEngine.SCORING_VERSION,
      transcript,
      analysisState: state,
      scoreAvailable: false,
      trustScore: null,
      trustLabel: label as any,
      confidence: 1.0,
      confidenceTier: 'high',
      confidenceNotes: [note, "This content appears to be purely subjective, creative, or promotional."],
      factors: null,
      chapters: [],
      speakers: [],
      claims: [],
      factCheckStats: { totalClaims: 0, extractedClaims: 0, evaluatedClaims: 0, correct: 0, incorrect: 0, unsupported: 0, mostly_correct: 0, unverifiable: 0, ignored: 0, faith: 0, checkedClaimsRatio: 0 },
      vertical: (domain?.toLowerCase() as any) || 'general',
      verticalScores: { general: 1.0, politics: 0, health: 0, finance: 0, history: 0, religion: 0 },
      diagnostics: [note],
      sourceLedger: {},
      generatedAt: Date.now(),
      verifiedAsOf: new Date().toISOString().split('T')[0],
      language: transcript.language,
      riskDomain: domain.toLowerCase(),
      domainRiskMultiplier: 1,
      scoringMethod: scoringMethod as any,
      isLongform: false,
      isFinal: true,
      synthesisTier: 'standard',
      deductions: [],
      versions: {
        model: "Gemini 2.5 Multi-Model",
        scoring: ScoringEngine.SCORING_VERSION,
        registry: "v3-blended"
      },
      uiReport: this.generateUIReport({
        truthScore: null,
        honestyScore: null,
        rationalityScore: null,
        compositeRating: null,
        trustLabel: label as any,
        analysisState: state as any,
        deductions: [],
        confidenceNotes: [note],
        claims: [],
        viewerNote: note,
        confidenceTier: 'high'
      })
    };
  }

  private generateUIReport(data: {
    truthScore: number | null;
    honestyScore: number | null;
    rationalityScore: number | null;
    compositeRating: number | null;
    trustLabel: string;
    analysisState: VerificationState | ErrorState;
    verificationState?: VerificationState;
    deductions: TrustDeduction[];
    confidenceNotes: string[];
    claims: VerifiedClaim[];
    viewerNote: string;
    confidenceTier: 'high' | 'medium' | 'low';
    harmCapApplied?: boolean;
    manipulationScore?: number;
    weights?: InstitutionalTrustFactors;
    factCheckStats?: any;
    synthesisOutput?: SynthesisOutput; // v10.0
  }): UIReport {
    const { 
      truthScore, honestyScore, rationalityScore, compositeRating, 
      trustLabel, analysisState, verificationState, deductions, confidenceNotes, 
      claims, viewerNote, confidenceTier, harmCapApplied, manipulationScore,
      factCheckStats, synthesisOutput, weights
    } = data;

    const actualState = verificationState || (analysisState as any);

    // 1. Evidence Coverage Metrics (v10.0)
    const evidenceCoverage = (actualState === VerificationState.STRUCTURAL_ONLY)
      ? null
      : {
          checked: factCheckStats?.evaluatedClaims ?? 0,
          total: factCheckStats?.extractedClaims ?? 0,
          label: `${factCheckStats?.evaluatedClaims ?? 0} of ${factCheckStats?.extractedClaims ?? 0} claims verified`
        };

    // v10.0: Unified Clinical Narrative Synthesis
    let narrative = synthesisOutput?.narrative || "";
    if (narrative === "" && claims.length > 0) {
      const verificationOpener = this.getVerificationOpener(actualState);
      narrative = `${verificationOpener} ${this.generateNarrativeConclusion(trustLabel, analysisState)}`;
      
      // v10.0 Fix: Sentence-grounding for deductions in narrative (ISSUE #7)
      if (deductions.length > 0) {
        const issue = deductions[0].reason.toLowerCase();
        // Remove trailing period from reason if present to prevent double periods
        const cleanIssue = issue.endsWith('.') ? issue.slice(0, -1) : issue;
        narrative += ` However, the analysis detected ${cleanIssue}.`;
      }
    }

    // v10.0 Fix: Rationality score display decoupling (BUG #2)
    const rationalityScoreValue = rationalityScore !== null ? rationalityScore : null;
    const rationalityContributed = (weights?.rationality ?? 0) > 0;

    // v10.0 Fix: Hardened positive driver filtering (BUG #3)
    const positiveDrivers = this.filterPositiveDrivers(confidenceNotes, actualState);

    // v10.0 Fix: State-aware conclusion label (ISSUE #8)
    const conclusionLabel = (actualState === VerificationState.INSUFFICIENT_EVIDENCE || actualState === VerificationState.STRUCTURAL_ONLY)
      ? "Unverified — Structural Analysis Only"
      : trustLabel;

    return {
      summary: {
        rating: compositeRating,
        truthScore: truthScore !== null ? Number((truthScore / 10).toFixed(1)) : null,
        honestyScore: honestyScore !== null ? Number((honestyScore / 10).toFixed(1)) : null,
        rationalityScore: rationalityScoreValue,
        rationalityContributedToComposite: rationalityContributed, // v10.0
        label: conclusionLabel,
        confidence: confidenceTier,
        analysisState: analysisState,
        verificationState: actualState,
        confidenceInterpretation: this.getConfidenceInterpretation(confidenceTier),
        evidenceCoverage
      },
      quickVerdict: `${this.getVerdictEmoji(actualState)} ${conclusionLabel}`,
      narrative: this.generateDeepResearchNarrative(narrative, claims, actualState, viewerNote),
      riskNote: harmCapApplied ? "⚠️ Critical safety warnings detected." : 
                (manipulationScore && manipulationScore > 0.6) ? "⚠️ High manipulation signals detected." : 
                "No harmful content detected",
      positiveDrivers: positiveDrivers.map(text => ({ text, impact: 'medium' })),
      negativeDrivers: deductions.slice(0, 2).map(d => ({ text: d.reason, impact: 'high' })),
      sources: this.aggregateInstitutionalSources(claims),
      claimResults: this.populateClaimResults(claims),
      conclusion: viewerNote || "Analysis complete.",
      disclaimer: "Institutional-grade evidence-bounded synthesis.",
      reviewRequestEnabled: true
    };
  }

  private getConfidenceInterpretation(tier: string): string {
    if (tier === 'high') return "High confidence — results are strongly supported by institutional data.";
    if (tier === 'medium') return "Moderate confidence — some uncertainty remains in claim verification.";
    return "Low confidence — limited data available; treat results cautiously.";
  }

  private getVerdictEmoji(state: VerificationState | ErrorState): string {
    if (state === VerificationState.VERIFIED) return "✅";
    if (state === VerificationState.PARTIALLY_VERIFIED) return "⚖️";
    if (state === VerificationState.STRUCTURAL_ONLY) return "📄";
    if (state === VerificationState.INSUFFICIENT_EVIDENCE) return "❓";
    return "⚠️";
  }

  private getVerificationOpener(state: VerificationState | ErrorState): string {
    const openers: Record<string, string> = {
      [VerificationState.VERIFIED]: "Verification complete.",
      [VerificationState.PARTIALLY_VERIFIED]: "Partial verification.",
      [VerificationState.STRUCTURAL_ONLY]: "No factual claims detected.",
      [VerificationState.INSUFFICIENT_EVIDENCE]: "Claims found but evidence unavailable.",
    };
    return openers[state as string] ?? "";
  }

  private generateNarrativeConclusion(label: string, state: VerificationState | ErrorState): string {
    if (state === VerificationState.VERIFIED) return "The content is well-supported by institutional evidence.";
    if (state === VerificationState.PARTIALLY_VERIFIED) return "The content contains some verified claims mixed with unverified assertions.";
    return "The assessment is based on structural honesty signals and consistency.";
  }

  /**
   * 🛡 v10.0: Shared driver filtering utility (BUG #3)
   */
  private filterPositiveDrivers(notes: string[], state: VerificationState | ErrorState): string[] {
    if (state === VerificationState.INSUFFICIENT_EVIDENCE || state === VerificationState.STRUCTURAL_ONLY) {
      return []; // Do not invent positive signals for unverified content
    }

    return notes.filter(n => {
      const lower = n.toLowerCase();
      return !lower.includes("limited") && 
             !lower.includes("structural") &&
             !lower.includes("filtered") &&
             !lower.includes("seek") &&
             !lower.includes("no factual claims") &&
             !lower.includes("routed as non-factual") &&
             !lower.includes("unconfirmed");
    });
  }

  /**
   * v10.5: Estimate Deep Research Cost & Latency
   */
  public estimateDeepResearchCost(
    claimCount: number,
    parallelBatches: number = 3,
    batchSize: number = 10
  ): {
    estimatedTokens: number;
    estimatedCostUsd: number;
    estimatedLatencyMs: number;
    warning?: string;
  } {
    const tokensPerClaim = 3000; // avg for Pro model with grounding
    const costPerMillionTokens = 3.50; // Gemini 2.5 Pro pricing
    const latencyPerBatch = 30000; // ms per batch (aligned with timeout)
    
    const totalTokens = claimCount * tokensPerClaim;
    const totalCost = (totalTokens / 1_000_000) * costPerMillionTokens;
    
    // v10.5 Audit: Account for parallel waves
    const totalBatches = Math.ceil(claimCount / batchSize);
    const parallelWaves = Math.ceil(totalBatches / parallelBatches);
    const totalLatency = parallelWaves * latencyPerBatch;
    
    return {
      estimatedTokens: totalTokens,
      estimatedCostUsd: parseFloat(totalCost.toFixed(4)),
      estimatedLatencyMs: totalLatency,
      warning: totalCost > 0.50 ? `High cost job: $${totalCost.toFixed(2)} estimated` : undefined,
    };
  }

  /**
   * v10.6: Map claim status to distinct public-facing labels.
   * Separates "Evidence Not Found" (timeout/search failure) from
   * "Insufficient Evidence" (genuine inability to verify).
   */
  private getClaimPublicLabel(claim: VerifiedClaim): string {
    if (claim.status === 'unsupported' && claim.publicNote?.includes('timed out')) {
      return 'Evidence Not Found';
    }
    if (claim.status === 'unsupported') {
      return 'Evidence Not Found';
    }
    if (claim.status === 'unverifiable') {
      return 'Insufficient Evidence';
    }
    if (claim.status === 'correct') return 'Verified';
    if (claim.status === 'mostly_correct') return 'Mostly Verified';
    if (claim.status === 'incorrect') return 'Contradicted by Evidence';
    if (claim.status === 'needs_context') return 'Requires Context';
    if (claim.status === 'outdated') return 'Outdated Information';
    if (claim.status === 'opinion') return 'Opinion';
    if (claim.status === 'faith_based' || claim.status === 'faith_context') return 'Faith-Based';
    return 'Not Verified';
  }

  /**
   * v10.6: Populate granular claim results for UI
   * Uses getClaimPublicLabel to produce distinct user-facing labels.
   */
  private populateClaimResults(claims: VerifiedClaim[]): any[] {
    return claims
      .filter(c => c.status !== 'opinion' && c.status !== 'satire' && c.status !== 'unverified')
      .map(c => ({
        claimId: c.claimId,
        text: c.text,
        status: c.status,
        evidenceLevel: c.evidenceLevel || 'NONE',
        publicNote: c.publicNote || this.getClaimPublicLabel(c),
        publicLabel: this.getClaimPublicLabel(c), // v10.6: distinct UI label
        sources: (c.richSources ?? []).map(s => ({
          title: s.title,
          url: s.url,
          domain: s.url ? new URL(s.url).hostname.replace('www.', '') : 'registry',
          tier: s.tier || 'C',
          snippet: s.snippet ?? '',
          publishedAt: s.publishedAt,
        })),
        sourceConsensus: (c as any).sourceConsensus || 'no_data',
        recommendedAction: (c as any).recommendedAction || '',
      }));
  }

  /**
   * v10.5: Aggregate unique sources across all claims
   */
  private aggregateInstitutionalSources(claims: VerifiedClaim[]): any[] {
    const allSources = claims.flatMap(c => c.richSources ?? []);
    const uniqueSources = Array.from(new Map(allSources.map(s => [s.url, s])).values());
    
    return uniqueSources
      .sort((a, b) => {
        const tierOrder: Record<string, number> = { A: 0, B: 1, C: 2, D: 3 };
        return (tierOrder[a.tier || 'C'] ?? 3) - (tierOrder[b.tier || 'C'] ?? 3);
      })
      .slice(0, 20)
      .map(s => ({
        title: s.title,
        url: s.url,
        trustLevel: s.tier === 'A' || s.tier === 'B' ? 'High' : 'Medium',
        type: s.tier === 'A' ? 'Primary' : 'Secondary'
      }));
  }

  /**
   * v10.5: Enhance narrative with source references
   */
  private generateDeepResearchNarrative(baseNarrative: string, claims: VerifiedClaim[], state: VerificationState | ErrorState, viewerNote?: string): string {
    if ((state !== VerificationState.VERIFIED && state !== VerificationState.PARTIALLY_VERIFIED) || claims.length === 0) {
      return baseNarrative;
    }

    const verifiedCount = claims.filter(c => c.status === 'correct' || c.status === 'mostly_correct').length;
    const incorrectCount = claims.filter(c => c.status === 'incorrect').length;
    
    const topDomains = claims
      .flatMap(c => c.richSources ?? [])
      .filter(s => s.tier === 'A' || s.tier === 'B')
      .slice(0, 3)
      .map(s => {
        try { return new URL(s.url).hostname.replace('www.', ''); } catch(e) { return null; }
      })
      .filter(d => d !== null);

    const dedupedDomains = Array.from(new Set(topDomains)).join(', ');

    let enhanced = `${baseNarrative} `;
    enhanced += `${verifiedCount} of ${claims.length} claims were verified against global institutional sources. `;
    
    if (incorrectCount > 0) {
      enhanced += `${incorrectCount} claim(s) were contradicted by verified evidence. `;
    }
    
    if (dedupedDomains) {
      enhanced += `Key sources include: ${dedupedDomains}. `;
    }
    
    if (viewerNote) enhanced += `\n\n${viewerNote}`;
    
    return enhanced;
  }
  /**
   * v11.0: Generate Creator Repair Path — actionable, claim-specific improvement suggestions.
   * Each suggestion tells the creator exactly what to fix and estimates the score impact.
   * 
   * Categories handled:
   * - Science, Education, History: emphasize citation and source quality
   * - News, Politics: emphasize freshness and multiple source confirmation
   * - Health, Finance: emphasize authoritative sources and qualification language
   * - Podcast, Interview: emphasize speaker attribution and context
   * - Entertainment, Culture: lighter touch, focus on factual accuracy only
   * - Religion: suggest qualification language for empirical claims within faith context
   */
  private generateCreatorRepairPath(
    claims: VerifiedClaim[],
    evaluatedClaims: number,
    extractedCount: number
  ): RepairSuggestion[] {
    const suggestions: RepairSuggestion[] = [];
    if (evaluatedClaims === 0) return suggestions;

    // 1. Flag specific incorrect claims with evidence-backed correction guidance
    claims.filter(c => c.status === 'incorrect').forEach(c => {
      const pointsGain = Math.round(15 / Math.max(evaluatedClaims, 1));
      suggestions.push({
        claimId: c.claimId,
        type: 'factual_error',
        severity: c.severity === 'extreme' || c.severity === 'high' ? 'high' : 'medium',
        currentText: c.text,
        suggestion: c.reasoning
          ? `This claim contradicts available evidence: ${c.reasoning.substring(0, 200)}. Consider correcting or removing it.`
          : 'This claim contradicts available evidence. Add a correction or qualify with source attribution.',
        impactEstimate: `Fixing would improve Accuracy by ~${pointsGain} points`,
      });
    });

    // 2. Flag outdated claims
    claims.filter(c => c.status === 'outdated' || c.status === 'needs_context').forEach(c => {
      suggestions.push({
        claimId: c.claimId,
        type: 'outdated_info',
        severity: 'medium',
        currentText: c.text,
        suggestion: c.status === 'outdated'
          ? `This information may be outdated. ${c.freshness ? `Last verified: ${c.freshness}.` : ''} Consider updating with current data.`
          : `This claim needs additional context to be fully accurate. ${c.reasoning?.substring(0, 150) || 'Add qualifying statements.'}`,
        impactEstimate: `Would improve Freshness and Accuracy scores`,
      });
    });

    // 3. Flag verified claims with no sources — opportunity to strengthen evidence score
    claims.filter(c => 
      (c.status === 'correct' || c.status === 'mostly_correct') && 
      (!c.richSources || c.richSources.length === 0)
    ).forEach(c => {
      const pointsGain = Math.round(10 / Math.max(evaluatedClaims, 1));
      suggestions.push({
        claimId: c.claimId,
        type: 'missing_source',
        severity: 'low',
        currentText: c.text,
        suggestion: 'This claim is correct but has no cited sources. Adding a reference would strengthen your Evidence score.',
        impactEstimate: `Would improve Evidence by ~${pointsGain} points`,
      });
    });

    // 4. Flag timed-out / unsupported claims that may recover with re-analysis
    claims.filter(c => 
      c.status === 'unsupported' && 
      (c.timedOutAt || c.publicNote?.includes('timed out') || c.publicNote?.includes('Evidence not found'))
    ).forEach(c => {
      suggestions.push({
        claimId: c.claimId,
        type: 'verification_timeout',
        severity: 'info',
        currentText: c.text,
        suggestion: 'Verification timed out for this claim. Try re-analyzing — the claim may verify successfully with a fresh attempt.',
        impactEstimate: 'Re-analysis may recover this claim and improve overall score',
      });
    });

    // 5. Flag strong/absolute assertions that lack hedging when evidence is weak
    claims.filter(c => 
      c.claimStrength === 'absolute' && 
      (c.evidenceLevel === 'WEAK' || c.evidenceLevel === 'NONE')
    ).forEach(c => {
      suggestions.push({
        claimId: c.claimId,
        type: 'hedging_needed',
        severity: 'low',
        currentText: c.text,
        suggestion: 'This claim uses absolute language but has limited evidence. Consider qualifying with "research suggests" or "according to [source]".',
        impactEstimate: 'Would improve Honesty score',
      });
    });

    // Sort: highest severity first, then by type priority
    const severityOrder: Record<string, number> = { high: 0, medium: 1, low: 2, info: 3 };
    suggestions.sort((a, b) => (severityOrder[a.severity] ?? 3) - (severityOrder[b.severity] ?? 3));

    // Cap at 15 suggestions to avoid overwhelming creators
    return suggestions.slice(0, 15);
  }

}
