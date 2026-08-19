import { FactCheckResult, VerifiedClaim, TranscriptData, TrustVertical, VerificationState, UIReport, SynthesisResult, SynthesisOutput, TraceabilityMap } from "../types";
// v12.0: getTrustLabelFromScore no longer used — scoring removed
// import { getTrustLabelFromScore } from "./categoryWeights";

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
      switch (c.status as string) {
        case 'verified_true':
        case 'correct':
          stats.verified_true++;
          stats.total_verifiable++;
          break;
        case 'mostly_true':
        case 'mostly_correct':
        case 'outdated':
          stats.mostly_true++;
          stats.total_verifiable++;
          break;
        case 'disputed':
        case 'partially_true':
        case 'contested_interpretation':
          stats.disputed++;
          stats.total_verifiable++;
          break;
        case 'unproven':
        case 'unsupported':
          stats.unproven++;
          stats.total_verifiable++;
          break;
        case 'misleading':
        case 'needs_context':
          stats.misleading++;
          stats.total_verifiable++;
          break;
        case 'false_claim':
        case 'verified_false':
        case 'incorrect':
        case 'historical_consensus_denial':
        case 'incorrect_citation':
          stats.false_claim++;
          stats.total_verifiable++;
          break;
        case 'religious_belief':
        case 'faith_based_claim':
        case 'faith_context':
        case 'not_historically_verifiable':
        case 'historical_tradition':
        case 'doctrinal_unverifiable':
          stats.religious_belief++;
          stats.total_subjective++;
          break;
        case 'opinion_claim':
        case 'opinion':
        case 'anecdotal_experience':
        case 'value_judgment':
        case 'preference_statement':
        case 'unverifiable_personal_claim':
          stats.opinion_claim++;
          stats.total_subjective++;
          break;
        case 'satire_claim':
        case 'satire':
          stats.satire_claim++;
          stats.total_subjective++;
          break;
        case 'verification_timeout':
          stats.verification_timeout++;
          break;
        case 'inconclusive':
        case 'unverifiable':
          stats.inconclusive++;
          stats.total_verifiable++;
          break;
        case 'limited_support':
          stats.limited_support++;
          stats.total_verifiable++;
          break;
      }
    });

    // 3. Remove Scoring (Deprecating Truth Index)
    
    // Calculate Verification State
    let finalState: VerificationState = VerificationState.VERIFIED;
    const timeoutRatio = stats.total_verifiable > 0 ? stats.verification_timeout / (stats.total_verifiable + stats.verification_timeout) : (stats.verification_timeout > 0 ? 1 : 0);

    if (stats.total_verifiable === 0 && stats.verification_timeout === 0) {
      finalState = VerificationState.STRUCTURAL_ONLY;
    } else if (timeoutRatio > 0.8) {
      finalState = VerificationState.FORCE_TIMEOUT;
    } else if (timeoutRatio > 0.5) {
      finalState = VerificationState.ANALYSIS_INCOMPLETE;
    } else if (stats.unproven > stats.total_verifiable * 0.5) {
      finalState = VerificationState.INSUFFICIENT_EVIDENCE;
    }

    const evaluatedCount = stats.total_verifiable;

    const result: FactCheckResult = {
      videoId,
      userId,
      transcript,
      analysisState: finalState,
      scoreAvailable: false,
      trustScore: null,
      trustLabel: 'Not Scored' as any,
      confidence: 0,
      confidenceTier: 'low',
      scoringVersion: ScoringEngine.SCORING_VERSION,
      
      factors: null,
      deductions: [],
      
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
      honestyScore: null,
      rationalityScore: null,
      compositeRating: undefined,
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
        rating: null,
        honestyScore: null,
        rationalityScore: null,
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
      quickVerdict: "Credibility Analysis Complete",
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
            sourceType: rs.sourceType || 'website',
            author: rs.author,
            bookTitle: rs.bookTitle,
            chapter: rs.chapter,
            pageNumbers: rs.pageNumbers,
            volume: rs.volume,
            journalName: rs.journalName,
            yearPublished: rs.yearPublished,
            isbn: rs.isbn,
            doi: rs.doi,
            directUrl: rs.directUrl || rs.url,
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
    let summary = 'This video has been analyzed by the credibility system.\n\n';
    
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
