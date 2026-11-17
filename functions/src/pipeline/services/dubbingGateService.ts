/**
 * 🛡️ LAYER 07 DUBBING & LOCALIZATION EPISTEMIC GATE
 *
 * Implements the mandatory compliance controller between Layer 06 (Credibility)
 * and Layer 07 (Dubbing & Localization).
 *
 * Regulatory Grounding:
 * - EU AI Act Article 50 (Synthetic Media Transparency): Mandates verifiable disclosures
 *   and safeguards against deceptive generation or localization of synthetic voice/video.
 * - Enforces the Pareto 95/5 rule: Routine benign content passes unrestricted, while
 *   high-severity contradictions in sensitive domains (Health, Geopolitics, Elections)
 *   are blocked from automated multilingual proliferation.
 */

export type DubbingPolicyAction =
  | "ALLOW_UNRESTRICTED"
  | "ALLOW_WITH_WATERMARK_AND_BANNER"
  | "BLOCK_LOCALIZATION";

export interface LocalizedDisclaimerRequirement {
  claimId: string;
  startMs: number;
  endMs: number;
  evidenceIds: string[];
  auditPackHash: string;
  suggestedNotice: string;
}

export interface Layer07DubbingGateDecision {
  videoId: string;
  action: DubbingPolicyAction;
  blockedClaimIds: string[];
  requiredLocalizedDisclaimers: LocalizedDisclaimerRequirement[];
  complianceNotes: string[];
  evaluatedAt: number;
}

export interface ClaimAssessmentForDubbing {
  claimId: string;
  domain: string;
  verdict: string;
  confidence: number;
  startMs: number;
  endMs: number;
  citedEvidenceIds: string[];
  auditPackHash: string;
}

export class DubbingGateService {
  private static readonly HIGH_RISK_DOMAINS = new Set([
    "HEALTH_MEDICAL",
    "GEOPOLITICS_WAR",
    "ELECTIONS_GOVERNANCE",
    "War",
    "Health",
    "Politics",
  ]);

  /**
   * Evaluates video claims against the Layer 06 -> 07 epistemic compliance gate.
   */
  static evaluateDubbingGate(
    videoId: string,
    assessments: ClaimAssessmentForDubbing[]
  ): Layer07DubbingGateDecision {
    const complianceNotes: string[] = [];

    // 1. High-severity contradictions in high-risk domains -> Hard block on localization
    const highSeverityContradictions = assessments.filter(
      (a) =>
        (a.verdict === "FALSE" ||
          a.verdict === "FACTUAL_CONTRADICTION" ||
          a.verdict === "false_claim") &&
        a.confidence >= 0.85 &&
        this.HIGH_RISK_DOMAINS.has(a.domain)
    );

    if (highSeverityContradictions.length > 0) {
      complianceNotes.push(
        `[EU_AI_ACT_ART50_BLOCK] Localization halted: ${highSeverityContradictions.length} high-severity contradiction(s) detected in high-risk domain(s).`
      );

      return {
        videoId,
        action: "BLOCK_LOCALIZATION",
        blockedClaimIds: highSeverityContradictions.map((c) => c.claimId),
        requiredLocalizedDisclaimers: [],
        complianceNotes,
        evaluatedAt: Date.now(),
      };
    }

    // 2. Moderate discrepancies / contested claims -> Allow with localized watermark/banner
    const moderateDiscrepancies = assessments.filter(
      (a) =>
        a.verdict === "MISLEADING" ||
        a.verdict === "DISPUTED" ||
        a.verdict === "disputed" ||
        a.verdict === "contested_interpretation"
    );

    if (moderateDiscrepancies.length > 0) {
      complianceNotes.push(
        `[EU_AI_ACT_ART50_DISCLOSE] Localization permitted with mandatory localized disclaimers and synthetic-media watermarks.`
      );

      return {
        videoId,
        action: "ALLOW_WITH_WATERMARK_AND_BANNER",
        blockedClaimIds: [],
        requiredLocalizedDisclaimers: moderateDiscrepancies.map((c) => ({
          claimId: c.claimId,
          startMs: c.startMs,
          endMs: c.endMs,
          evidenceIds: c.citedEvidenceIds,
          auditPackHash: c.auditPackHash,
          suggestedNotice:
            "Context Notice: Claim disputed by verified comparative records.",
        })),
        complianceNotes,
        evaluatedAt: Date.now(),
      };
    }

    // 3. Clean empirical records -> Allow unrestricted
    return {
      videoId,
      action: "ALLOW_UNRESTRICTED",
      blockedClaimIds: [],
      requiredLocalizedDisclaimers: [],
      complianceNotes: ["All verifiable claims concordance verified."],
      evaluatedAt: Date.now(),
    };
  }
}
