import { FactCheckResult, VerifiedClaim, TranscriptData, TrustVertical, TrustDeduction, VerificationState, UIReport, SynthesisResult, SynthesisOutput, TraceabilityMap } from "../types";
import { getTrustLabelFromScore } from "./categoryWeights";

/**
 * 🏛 SCORING ENGINE (v11.0 — Path 1 Epistemic Framework)
 * 
 * Centralized engine for TruthWorld trust scoring.
 * Implements the Truth Index formula: (Truth * 0.35) + (Honesty * 0.40) + (Rationality * 0.25).
 */
export class ScoringEngine {
  private static readonly SCORING_VERSION = "v11.0-path1";

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
      synthesisOutput?: SynthesisOutput,
      extractionPartial?: boolean,
      viewerNote?: string
    },
    userHistory: any = {},
    videoCategory?: string,
    primaryVertical?: TrustVertical,
    verticalScores: Partial<Record<TrustVertical, number>> = {},
    synthesisTier: 'standard' | 'deep' | 'podcast' = 'standard',
    batchStats: { completed: number, timedOut: number } = { completed: 0, timedOut: 0 }
  ): FactCheckResult {
    // 1. Initialize Stats (TruthWorld Path 1)
    const stats = {
      verified_true: 0,
      mostly_true: 0,
      disputed: 0,
      unproven: 0,
      misleading: 0,
      false_claim: 0,
      religious_belief: 0,
      opinion_claim: 0,
      satire_claim: 0,
      verification_timeout: 0,
      inconclusive: 0,
      limited_support: 0,
      total_verifiable: 0,
      total_subjective: 0,
      framing_violations: 0
    };

    // 2. Process Claims & Identify Framing Violations
    const fallacies = new Set<string>();
    allVerifiedClaims.forEach(c => {
      // Track Framing Violations (The Honesty Flag)
      if (c.isFramingViolation) {
        stats.framing_violations++;
      }

      if ((c as any).rhetoricalManipulations && Array.isArray((c as any).rhetoricalManipulations)) {
        (c as any).rhetoricalManipulations.forEach((f: string) => {
          if (f && typeof f === "string") {
            const clean = f.trim();
            if (clean) {
              fallacies.add(clean);
            }
          }
        });
      }

      // Count by Bucket & Verdict
      switch (c.status) {
        case 'verified_true':
          stats.verified_true++;
          stats.total_verifiable++;
          break;
        case 'mostly_true':
          stats.mostly_true++;
          stats.total_verifiable++;
          break;
        case 'disputed':
        case 'partially_true':
          stats.disputed++;
          stats.total_verifiable++;
          break;
        case 'unproven':
          stats.unproven++;
          stats.total_verifiable++;
          break;
        case 'misleading':
          stats.misleading++;
          stats.total_verifiable++;
          break;
        case 'false_claim':
          stats.false_claim++;
          stats.total_verifiable++;
          break;
        case 'religious_belief':
        case 'faith_based_claim':
        case 'faith_context':
        case 'not_historically_verifiable':
        case 'historical_tradition':
          stats.religious_belief++;
          stats.total_subjective++;
          break;
        case 'opinion_claim':
          stats.opinion_claim++;
          stats.total_subjective++;
          break;
        case 'satire_claim':
          stats.satire_claim++;
          stats.total_subjective++;
          break;
        case 'verification_timeout':
          stats.verification_timeout++;
          break;
        case 'inconclusive':
          stats.inconclusive++;
          stats.total_verifiable++;
          break;
        case 'limited_support':
          stats.limited_support++;
          stats.total_verifiable++;
          break;
      }
    });

    // 3. Calculate Base Truth Index (0-10) — PATH 1 HYBRID MODEL
    // Formula: (ArithmeticWeightedAverage * 10) - (FalseClaimCount * 2.5)
    // Ensures fairness while penalizing blatant misinformation.
    let truthIndex: number | null = null;

    if (stats.total_verifiable > 0) {
      // v11.7: Domain-Aware Evidence Sensitivity Weighting
      const intent = synthesisData.contentIntent?.primaryIntent;
      const isLowStakes = ["educational", "entertainment", "testimonial"].includes(intent);
      
      const weights = {
        verified_true: 1.0,
        mostly_true: 0.8,
        disputed: 0.4,
        unproven: isLowStakes ? 0.7 : 0.3, // Soften penalty for low-stakes trivia
        inconclusive: isLowStakes ? 0.8 : 0.4,
        limited_support: isLowStakes ? 0.9 : 0.5,
        misleading: 0.1,
        false_claim: 0.0
      };

      const weightedSum = 
        (stats.verified_true * weights.verified_true) +
        (stats.mostly_true * weights.mostly_true) +
        (stats.disputed * weights.disputed) +
        (stats.unproven * weights.unproven) +
        (stats.inconclusive * weights.inconclusive) +
        (stats.limited_support * weights.limited_support) +
        (stats.misleading * weights.misleading) +
        (stats.false_claim * weights.false_claim);
      
      const baseScore = (weightedSum / stats.total_verifiable) * 10;
      
      // Apply False Claim Penalty (v11.1)
      const FALSE_CLAIM_PENALTY = 2.5;
      const totalPenalty = stats.false_claim * FALSE_CLAIM_PENALTY;
      
      truthIndex = baseScore - totalPenalty;
      
      // 4. Apply Honesty Bonus / Penalty
      let honestyModifier = 0;
      if (stats.framing_violations > 0) {
        honestyModifier = -2.0 * stats.framing_violations;
      } else if (stats.total_subjective > 0) {
        honestyModifier = 0.5; // Bonus for correctly labeling beliefs
      }
      
      if (truthIndex !== null) {
        truthIndex = Math.max(0, Math.min(10.0, truthIndex + honestyModifier));
      }
    }

    // 5. Calculate Rationality Score (0-100)
    // Based on logical consistency and presence of disputed/misleading signals
    let rationalityScore = 95;
    const fallacyCount = fallacies.size;
    let fallacyPenalty = 0;
    fallacies.forEach(f => {
      if (f === "cherry_picking") {
        fallacyPenalty += 15;
      } else {
        fallacyPenalty += 10;
      }
    });
    if (stats.disputed > 0 || stats.misleading > 0 || stats.framing_violations > 0 || fallacyCount > 0) {
      let score = 100;
      if (stats.disputed > 0) score -= 15;
      if (stats.misleading > 0) score -= 20;
      if (stats.framing_violations > 0) score -= 25;
      score -= fallacyPenalty;
      rationalityScore = Math.max(0, score);
    }

    // 6. Final Display & Labeling
    // 7. Verification State
    let finalState: VerificationState = VerificationState.VERIFIED;
    const timeoutRatio = stats.total_verifiable > 0 ? stats.verification_timeout / (stats.total_verifiable + stats.verification_timeout) : (stats.verification_timeout > 0 ? 1 : 0);

    if (stats.total_verifiable === 0 && stats.verification_timeout === 0) {
      finalState = VerificationState.STRUCTURAL_ONLY;
    } else if (timeoutRatio > 0.8) {
      finalState = VerificationState.FORCE_TIMEOUT;
    } else if (timeoutRatio > 0.5) {
      // v14.0: Only mark ANALYSIS_INCOMPLETE when timeouts are dominant (>50%).
      // Previously ANY timeout (even 1 of 10) forced this state, causing
      // 91/100 videos to be labeled "Inconclusive (Timeout)".
      finalState = VerificationState.ANALYSIS_INCOMPLETE;
    } else if (stats.unproven > stats.total_verifiable * 0.5) {
      finalState = VerificationState.INSUFFICIENT_EVIDENCE;
    }
    // If timeoutRatio <= 0.5, state stays VERIFIED — the score-based label takes effect.

    const displayScore = truthIndex; 
    let trustLabel = "";
    
    if (displayScore === null) {
      if (stats.verification_timeout > 0 && stats.total_verifiable === 0) {
        trustLabel = "Verification Incomplete (Timeout)";
      } else if (stats.total_subjective > 0 && stats.total_verifiable === 0) {
        trustLabel = stats.framing_violations > 0 ? "Misleading Framing" : (fallacyCount > 0 ? "Manipulative Opinion" : "Opinion/Belief Content");
      } else {
        trustLabel = "Unable to Verify (Inconclusive)";
      }
    } else {
      if (finalState === VerificationState.FORCE_TIMEOUT) {
        trustLabel = "Inconclusive (Timeout)";
      } else if (finalState === VerificationState.ANALYSIS_INCOMPLETE) {
        // v14.0: Partial timeout — use score-based label but note incompleteness
        const baseLabel = getTrustLabelFromScore(displayScore, false, videoCategory as any);
        trustLabel = `${baseLabel} (Partial)`;
      } else {
        trustLabel = getTrustLabelFromScore(displayScore, false, videoCategory as any);
      }
    }

    // 8. Confidence Calibration (v11.7: Confidence Collapse)
    const evaluatedCount = stats.total_verifiable;
    const unprovenTotal = stats.unproven + stats.inconclusive + stats.limited_support;
    const unprovenRatio = evaluatedCount > 0 ? unprovenTotal / evaluatedCount : 0;
    
    let confidence = 0.85 * Math.exp(-1.2 * timeoutRatio) * Math.exp(-0.8 * unprovenRatio);
    
    if (allVerifiedClaims.length === 0 && stats.verification_timeout === 0) confidence = 0.1;
    else if (allVerifiedClaims.length === 0 && stats.verification_timeout > 0) confidence = 0.15;
    
    const confidenceTier = confidence > 0.7 ? 'high' : (confidence > 0.4 ? 'medium' : 'low');

    // 9. Deductions
    const deductions: TrustDeduction[] = [];
    if (stats.framing_violations > 0) {
      deductions.push({
        factor: 'honesty',
        points: 2.0 * stats.framing_violations,
        reason: `${stats.framing_violations} framing violation(s) detected (Opinion/Belief presented as Fact).`
      });
    }
    if (fallacyCount > 0) {
      deductions.push({
        factor: 'consistency',
        points: fallacyPenalty,
        reason: `${fallacyCount} unique logical fallacy/manipulation(s) detected: ${Array.from(fallacies).join(', ')}.`
      });
    }

    // calculate proportional consensus
    const consensusRatio = stats.total_verifiable > 0 ? stats.disputed / stats.total_verifiable : 0;
    const proportionalConsensus = Math.round(95 - (consensusRatio * 55));

    // calculate blended 5-tier expertise score
    let blendedExpertise = 70;
    if (allVerifiedClaims.length > 0) {
      const tierScores: Record<string, number> = { "A": 100, "B": 85, "C": 70, "D": 40, "E": 25 };
      let sumOfClaimExpertiseScores = 0;
      let claimsWithSourcesCount = 0;
      allVerifiedClaims.forEach(c => {
        let highestClaimScore = 0;
        let hasSource = false;
        if (c.richSources && c.richSources.length > 0) {
          hasSource = true;
          c.richSources.forEach(s => {
            const score = tierScores[s.tier] || 0;
            if (score > highestClaimScore) {
              highestClaimScore = score;
            }
          });
        }
        sumOfClaimExpertiseScores += highestClaimScore;
        if (hasSource) {
          claimsWithSourcesCount++;
        }
      });
      const averageSourceExpertise = sumOfClaimExpertiseScores / allVerifiedClaims.length;
      const coverageRatio = claimsWithSourcesCount / allVerifiedClaims.length;
      blendedExpertise = Math.round((averageSourceExpertise * 0.75) + (coverageRatio * 100 * 0.25));
    }

    const result: FactCheckResult = {
      videoId,
      userId,
      transcript,
      analysisState: finalState,
      scoreAvailable: true,
      trustScore: truthIndex !== null ? Math.round(truthIndex * 10) : null,
      videoRating: displayScore ?? undefined,
      trustLabel: trustLabel as any,
      confidence,
      confidenceTier,
      scoringVersion: ScoringEngine.SCORING_VERSION,
      
      factors: {
        accuracy: truthIndex !== null ? truthIndex * 10 : null,
        evidence: stats.unproven > 0 ? 60 : 90,
        consensus: proportionalConsensus,
        consistency: rationalityScore,
        integrity: stats.framing_violations === 0 ? 100 : 40,
        expertise: blendedExpertise,
        freshness: 90,
        safety: truthIndex !== null ? (truthIndex > 5 ? 100 : 50) : 100,
        honesty: stats.framing_violations === 0 ? 100 : 20,
      },
      deductions,
      
      factCheckStats: {
        totalClaims: extractedCount,
        extractedClaims: extractedCount,
        evaluatedClaims: evaluatedCount,
        correct: stats.verified_true,
        mostly_correct: stats.mostly_true,
        incorrect: stats.false_claim,
        unsupported: stats.unproven,
        unverifiable: 0,
        verified_true: stats.verified_true,
        mostly_true: stats.mostly_true,
        disputed: stats.disputed,
        unproven: stats.unproven,
        misleading: stats.misleading,
        false_claim: stats.false_claim,
        religious_belief: stats.religious_belief,
        opinion_claim: stats.opinion_claim,
        satire_claim: stats.satire_claim,
        verification_timeout: stats.verification_timeout,
        checkedClaimsRatio: extractedCount > 0 ? evaluatedCount / extractedCount : 0,
        extractionPartial: synthesisData.extractionPartial || false,
      },
      claims: allVerifiedClaims,
      scoringMethod: 'balanced',
      synthesisTier: synthesisTier as any,
      isLongform: false,
      isFinal: true,
      generatedAt: Date.now(),
      verifiedAsOf: new Date().toISOString().split('T')[0],
      language: "en",
      riskDomain: domain,
      domainRiskMultiplier: 1.0,
      truthScore: truthIndex !== null ? Math.round(truthIndex * 10) : null,
      honestyScore: stats.framing_violations === 0 ? 100 : 20,
      rationalityScore,
      compositeRating: displayScore,
      verificationState: finalState,
      chapters: [],
      speakers: [],
      versions: {
        model: "Gemini 2.5",
        scoring: ScoringEngine.SCORING_VERSION,
        registry: "v4-path1"
      }
    };

    result.uiReport = this.generateUIReport({
      ...result,
      viewerNote: synthesisData.viewerNote || "",
    });

    return result;
  }

  private generateUIReport(data: any): UIReport {
    const stats = data.factCheckStats;
    const evaluatedCount = stats?.evaluatedClaims ?? 0;
    const totalCount = stats?.extractedClaims ?? 0;

    // Collect and map unique global sources from claims
    const uiSourcesMap = new Map<string, any>();
    data.claims?.forEach((c: any) => {
      c.richSources?.forEach((rs: any) => {
        const key = rs.url?.toLowerCase() || rs.title.toLowerCase();
        if (!uiSourcesMap.has(key)) {
          uiSourcesMap.set(key, {
            title: rs.title,
            url: rs.url,
            domain: rs.domain,
            trustLevel: rs.tier === 'A' || rs.tier === 'B' ? 'High' : (rs.tier === 'C' ? 'Medium' : 'Low'),
            type: rs.type === 'primary' ? 'Primary' : 'Secondary',
            snippet: rs.snippet || "",
            retrievalProvider: rs.retrievalProvider || (rs.retrievalMethod === 'google_grounding' ? 'Google Grounding' : 'Direct'),
            citationCount: 1
          });
        } else {
          uiSourcesMap.get(key).citationCount++;
        }
      });
    });
    const sources = Array.from(uiSourcesMap.values());

    return {
      summary: {
        rating: data.compositeRating,
        truthScore: data.truthScore,
        honestyScore: data.honestyScore,
        rationalityScore: data.rationalityScore,
        label: data.trustLabel,
        confidence: data.confidenceTier,
        confidenceInterpretation: data.confidenceInterpretation || "Standard analysis.",
        analysisState: data.verificationState,
        verificationState: data.verificationState,
        evidenceCoverage: {
          checked: evaluatedCount,
          total: totalCount,
          label: `${evaluatedCount} of ${totalCount} claims verified`,
          isPartial: stats?.extractionPartial
        }
      },
      // v14.0: Dynamic verdict icon based on trust label
      quickVerdict: (() => {
        const label = data.trustLabel;
        if (label.includes('Highly Reliable') || label.includes('Reliable')) return `✅ ${label}`;
        if (label.includes('Mixed') || label.includes('Partial') || label.includes('Inconclusive') || label.includes('Evolving')) return `⚠️ ${label}`;
        if (label.includes('Unable to Verify') || label.includes('Structural')) return `❓ ${label}`;
        if (label.includes('Low') || label.includes('Misleading') || label.includes('Capped')) return `❌ ${label}`;
        return `⚠️ ${label}`;
      })(),
      narrative: this.generateSummary(data as any), // Narrative field uses the textual summary
      riskNote: stats?.framing_violations > 0 ? "High risk of framing manipulation detected." : "Low structural risk.",
      positiveDrivers: [],
      negativeDrivers: [],
      sources: sources,
      conclusion: "Verification complete.",
      keyClaims: data.claims?.slice(0, 15).map((c: any) => {
        const intent = data.uiReport?.summary?.contentIntent?.primaryIntent;
        const isLowStakes = ["educational", "entertainment", "testimonial"].includes(intent);
        const isTrivia = c.isLowRiskTrivia || (isLowStakes && c.nature === 'VERIFIABLE_FACT');
        
        let displayLabel = c.displayLabel;
        if (!displayLabel) {
          if (c.status === 'inconclusive') displayLabel = "Evidence Inconclusive";
          else if (c.status === 'limited_support') displayLabel = "Popular Claim — Limited Verification";
          else if (c.status === 'unproven') displayLabel = "Inconclusive";
          else if (c.status === 'faith_based_claim') displayLabel = "Faith-Based Claim";
          else if (c.status === 'not_historically_verifiable') displayLabel = "Not Historically Verifiable";
        }

        return {
          claimId: c.claimId,
          text: c.text,
          verdict: c.status,
          displayLabel: displayLabel,
          bucket: c.nature || 'FACTUAL',
          isLowRiskTrivia: isTrivia,
          reasoning: c.reasoning,
          sources: c.sources || [],
          richSources: c.richSources || [],
          effectiveSources: (c.richSources || []).map((rs: any) => ({
            title: rs.title,
            url: rs.url,
            domain: rs.domain,
            trustLevel: rs.tier === 'A' || rs.tier === 'B' ? 'High' : (rs.tier === 'C' ? 'Medium' : 'Low'),
            type: rs.type === 'primary' ? 'Primary' : 'Secondary',
            snippet: rs.snippet || "",
            retrievalProvider: rs.retrievalProvider || (rs.retrievalMethod === 'google_grounding' ? 'Google Grounding' : 'Direct'),
            citationCount: 1
          })),
          classificationConfidence: c.classificationConfidence,
          historicalEvidenceConfidence: c.historicalEvidenceConfidence,
          evidenceDetails: c.evidenceDetails,
          consensusDetails: c.consensusDetails,
          claimDomain: c.claimDomain,
          claimNature: c.claimNature,
          verdictBasis: c.verdictBasis,
          evidence: c.evidence,
          consensus: c.consensus,
        };
      }) || []
    } as any;
  }

  generateSummary(result: FactCheckResult): string {
    const score = result.videoRating;
    const label = result.trustLabel;
    
    let summary = `This video has a Truth Index of ${score?.toFixed(1) || 'N/A'}/10.0, classified as "${label}".\n\n`;
    
    const stats = result.factCheckStats;
    if (stats) {
      summary += `Analysis Breakdown:\n`;
      summary += `• Facts: ${stats.verified_true} Verified, ${stats.false_claim} False\n`;
      summary += `• Subjective: ${stats.religious_belief} Beliefs, ${stats.opinion_claim} Opinions\n`;
      
      if (stats.unproven > 0) {
        summary += `• Unproven: ${stats.unproven} claims (No evidence found)\n`;
      }
      if (stats.verification_timeout > 0) {
        summary += `• Incomplete: ${stats.verification_timeout} claims (Analysis timed out)\n`;
      }
    }
    
    if (result.deductions && result.deductions.length > 0) {
      summary += `\nIntegrity Warnings:\n`;
      result.deductions.forEach(d => {
        summary += `• ${d.reason}\n`;
      });
    }

    return summary;
  }

  /**
   * v10.5 Audit: Pre-verification cost estimation
   */
  estimateDeepResearchCost(claimCount: number, researchDepth: number, batchSize: number): { estimatedCostUsd: number, warning?: string } {
    const costPerClaim = researchDepth * 0.005; // $0.005 per research hop
    const estimatedCost = claimCount * costPerClaim;
    
    let warning: string | undefined;
    if (estimatedCost > 0.50) {
      warning = "High cost analysis detected ($>0.50). Consider increasing batch size or reducing depth.";
    }
    
    return { 
      estimatedCostUsd: Number(estimatedCost.toFixed(3)),
      warning 
    };
  }
}
