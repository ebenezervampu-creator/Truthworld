import { sourceTrustService } from '../../src/pipeline/services/sourceTrustService';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { EvidenceRole, RichSource } from '../../src/pipeline/types';

describe('P7.1 Epistemic Invariants & Evidence Precedence Test Suite', () => {
  let verificationService: ClaimVerificationService;

  beforeEach(() => {
    verificationService = new ClaimVerificationService('mock-api-key');
    sourceTrustService.resetDynamicOverrides();
  });

  describe('1. Domain-Role Precedence Matrices (M_domain)', () => {
    it('1.1 Legal domain: PRIMARY_RECORD outranks INVESTIGATIVE_REPORTING and OFFICIAL_ASSERTION', () => {
      const primaryMult = sourceTrustService.getDomainRoleMultiplier('legal', EvidenceRole.PRIMARY_RECORD);
      const investigativeMult = sourceTrustService.getDomainRoleMultiplier('legal', EvidenceRole.INVESTIGATIVE_REPORTING);
      const officialMult = sourceTrustService.getDomainRoleMultiplier('legal', EvidenceRole.OFFICIAL_ASSERTION);
      const secondaryMult = sourceTrustService.getDomainRoleMultiplier('legal', EvidenceRole.SECONDARY_COMMENTARY);

      expect(primaryMult).toBe(1.0);
      expect(investigativeMult).toBe(0.75);
      expect(officialMult).toBe(0.40);
      expect(secondaryMult).toBe(0.30);
      expect(primaryMult).toBeGreaterThan(investigativeMult);
      expect(investigativeMult).toBeGreaterThan(officialMult);
      expect(officialMult).toBeGreaterThan(secondaryMult);
    });

    it('1.2 Health/Medical domain: EXPERT_SYNTHESIS outranks PRIMARY_RECORD and OFFICIAL_ASSERTION', () => {
      const synthesisMult = sourceTrustService.getDomainRoleMultiplier('health', EvidenceRole.EXPERT_SYNTHESIS);
      const primaryMult = sourceTrustService.getDomainRoleMultiplier('health', EvidenceRole.PRIMARY_RECORD);
      const officialMult = sourceTrustService.getDomainRoleMultiplier('health', EvidenceRole.OFFICIAL_ASSERTION);
      const investigativeMult = sourceTrustService.getDomainRoleMultiplier('health', EvidenceRole.INVESTIGATIVE_REPORTING);

      expect(synthesisMult).toBe(1.0);
      expect(primaryMult).toBe(0.90);
      expect(officialMult).toBe(0.60);
      expect(investigativeMult).toBe(0.50);
      expect(synthesisMult).toBeGreaterThan(primaryMult);
      expect(primaryMult).toBeGreaterThan(officialMult);
    });

    it('1.3 Breaking News domain: INVESTIGATIVE_REPORTING outranks EXPERT_SYNTHESIS (stale post-event)', () => {
      const investigativeMult = sourceTrustService.getDomainRoleMultiplier('breaking_news', EvidenceRole.INVESTIGATIVE_REPORTING);
      const officialMult = sourceTrustService.getDomainRoleMultiplier('breaking_news', EvidenceRole.OFFICIAL_ASSERTION);
      const synthesisMult = sourceTrustService.getDomainRoleMultiplier('breaking_news', EvidenceRole.EXPERT_SYNTHESIS);

      expect(investigativeMult).toBe(1.0);
      expect(officialMult).toBe(0.85);
      expect(synthesisMult).toBe(0.40);
      expect(investigativeMult).toBeGreaterThan(officialMult);
      expect(officialMult).toBeGreaterThan(synthesisMult);
    });

    it('1.4 Economics/Finance domain: PRIMARY_RECORD outranks OFFICIAL_ASSERTION', () => {
      const primaryMult = sourceTrustService.getDomainRoleMultiplier('finance', EvidenceRole.PRIMARY_RECORD);
      const officialMult = sourceTrustService.getDomainRoleMultiplier('finance', EvidenceRole.OFFICIAL_ASSERTION);

      expect(primaryMult).toBe(1.0);
      expect(officialMult).toBe(0.60);
      expect(primaryMult).toBeGreaterThan(officialMult);
    });
  });

  describe('2. Evidentiary Capacity (C_s >= 0) Calculation', () => {
    it('2.1 Capacity is strictly non-negative and correctly scaled', () => {
      const cap = sourceTrustService.calculateEvidentiaryCapacity({
        baseReliability: 1.0,
        domainContext: 'legal',
        role: EvidenceRole.PRIMARY_RECORD,
        relevance: 0.95,
        independenceFactor: 1.0,
      });

      expect(cap).toBeGreaterThanOrEqual(0.0);
      expect(cap).toBeLessThanOrEqual(1.0);
      expect(cap).toBe(0.95);
    });

    it('2.2 Syndicated/dependent sources are scaled down by independence factor', () => {
      const independentCap = sourceTrustService.calculateEvidentiaryCapacity({
        baseReliability: 0.9,
        domainContext: 'general',
        role: EvidenceRole.INVESTIGATIVE_REPORTING,
        relevance: 1.0,
        independenceFactor: 1.0,
      });

      const syndicatedCap = sourceTrustService.calculateEvidentiaryCapacity({
        baseReliability: 0.9,
        domainContext: 'general',
        role: EvidenceRole.INVESTIGATIVE_REPORTING,
        relevance: 1.0,
        independenceFactor: 0.5,
      });

      expect(syndicatedCap).toBeLessThan(independentCap);
      expect(syndicatedCap).toBe(Math.round(independentCap * 0.5 * 1000) / 1000);
    });

    it('2.3 Edge case inputs never produce negative capacity', () => {
      const zeroCap = sourceTrustService.calculateEvidentiaryCapacity({
        baseReliability: 0.0,
        domainContext: 'unknown',
        relevance: 0.0,
      });
      expect(zeroCap).toBe(0.0);
    });
  });

  describe('3. Strict Epistemic Invariants & Dual-Mass Aggregation', () => {
    it('3.1 Invariant Guard: Claim proposed as false_claim without affirmative contradiction is strictly overruled to unproven', () => {
      // Model proposed false_claim, but zero contradictory sources found (only 1 low-capacity weak mention)
      const sources = [
        {
          evidentiaryCapacity: 0.3,
          stance: 'SUPPORTS' as const,
          tier: 'C' as const,
          role: EvidenceRole.SECONDARY_COMMENTARY,
        },
      ];

      const res = sourceTrustService.evaluateDualMassInvariants(sources, 'false_claim');
      expect(res.invariantVerdict).toBe('unproven');
      expect(res.isOverridden).toBe(true);
      expect(res.reason).toMatch(/P7.1 Invariant Overrule/i);
    });

    it('3.2 Absence of evidence: Total mass below threshold defaults to unproven (epistemic null state)', () => {
      // Very weak evidence found on both sides (mass < 0.8)
      const sources = [
        {
          evidentiaryCapacity: 0.2,
          stance: 'SUPPORTS' as const,
          tier: 'D' as const,
        },
        {
          evidentiaryCapacity: 0.2,
          stance: 'CONTRADICTS' as const,
          tier: 'D' as const,
        },
      ];

      const res = sourceTrustService.evaluateDualMassInvariants(sources, 'unverified');
      expect(res.invariantVerdict).toBe('unproven');
      expect(res.supportMass).toBe(0.2);
      expect(res.contradictMass).toBe(0.2);
    });

    it('3.3 Legitimate false_claim: Contradiction mass >= 1.5 with Tier-A evidence correctly confirms false_claim', () => {
      const sources = [
        {
          evidentiaryCapacity: 0.95,
          stance: 'CONTRADICTS' as const,
          tier: 'A' as const,
          role: EvidenceRole.PRIMARY_RECORD,
        },
        {
          evidentiaryCapacity: 0.85,
          stance: 'CONTRADICTS' as const,
          tier: 'A' as const,
          role: EvidenceRole.INVESTIGATIVE_REPORTING,
        },
      ];

      const res = sourceTrustService.evaluateDualMassInvariants(sources, 'false_claim');
      expect(res.invariantVerdict).toBe('false_claim');
      expect(res.isOverridden).toBe(false);
      expect(res.contradictMass).toBe(1.8);
      expect(res.highestTierContradict).toBe('A');
    });

    it('3.4 Legitimate verified_true: Support mass >= 1.5 with Tier-A evidence correctly confirms verified_true', () => {
      const sources = [
        {
          evidentiaryCapacity: 0.95,
          stance: 'SUPPORTS' as const,
          tier: 'A' as const,
          role: EvidenceRole.PRIMARY_RECORD,
        },
        {
          evidentiaryCapacity: 0.80,
          stance: 'SUPPORTS' as const,
          tier: 'B' as const,
          role: EvidenceRole.INDEPENDENT_CORROBORATION,
        },
      ];

      const res = sourceTrustService.evaluateDualMassInvariants(sources, 'verified_true');
      expect(res.invariantVerdict).toBe('verified_true');
      expect(res.isOverridden).toBe(false);
      expect(res.supportMass).toBe(1.75);
      expect(res.contradictMass).toBe(0.0);
    });

    it('3.5 Disputed invariant: Significant mass on both sides (>= 1.0 each) correctly yields disputed', () => {
      const sources = [
        {
          evidentiaryCapacity: 0.85,
          stance: 'SUPPORTS' as const,
          tier: 'A' as const,
        },
        {
          evidentiaryCapacity: 0.50,
          stance: 'SUPPORTS' as const,
          tier: 'B' as const,
        },
        {
          evidentiaryCapacity: 0.85,
          stance: 'CONTRADICTS' as const,
          tier: 'A' as const,
        },
        {
          evidentiaryCapacity: 0.50,
          stance: 'CONTRADICTS' as const,
          tier: 'B' as const,
        },
      ];

      const res = sourceTrustService.evaluateDualMassInvariants(sources, 'mostly_true');
      expect(res.invariantVerdict).toBe('disputed');
      expect(res.isOverridden).toBe(true);
      expect(res.supportMass).toBe(1.35);
      expect(res.contradictMass).toBe(1.35);
    });
  });

  describe('4. Integration with ClaimVerificationService', () => {
    it('4.1 evaluateDocumentEvidence attaches EvidenceRole, stance, and evidentiaryCapacity to candidate', () => {
      const candidate: RichSource = {
        title: 'Supreme Court Docket Judgment 2024',
        url: 'https://main.sci.gov.in/judgment/2024/order.pdf',
        domain: 'sci.gov.in',
        tier: 'A',
        snippet: 'Supreme Court dismissed petition in criminal appeal 402/2024 regarding election bribery.',
      };

      const assessment = verificationService.evaluateDocumentEvidence(
        candidate,
        'Supreme court dismissed criminal appeal 402/2024 regarding election bribery in 2024',
        'Legal'
      );

      expect(assessment.admissionStatus).toBe('admitted');
      expect(candidate.evidenceRole).toBe(EvidenceRole.PRIMARY_RECORD);
      expect(candidate.stance).toBe('SUPPORTS');
      expect(candidate.evidentiaryCapacity).toBeGreaterThan(0.7);
      expect(candidate.sourceTier).toBe('A');
      expect(candidate.calculationVersion).toBe('CALC-2026.1');
    });

    it('4.2 Medical meta-analysis receives EXPERT_SYNTHESIS role and high health capacity', () => {
      const candidate: RichSource = {
        title: 'The Lancet Meta-Analysis on Vaccine Efficacy',
        url: 'https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(23)00123/fulltext',
        domain: 'thelancet.com',
        journalName: 'The Lancet',
        tier: 'A',
        snippet: 'Systematic review and meta-analysis of 42 randomized trials demonstrating 94% efficacy.',
      };

      const assessment = verificationService.evaluateDocumentEvidence(
        candidate,
        'Randomized trials demonstrated 94% vaccine efficacy across 42 studies',
        'Health'
      );

      expect(assessment.admissionStatus).toBe('admitted');
      expect(candidate.evidenceRole).toBe(EvidenceRole.EXPERT_SYNTHESIS);
      expect(candidate.stance).toBe('SUPPORTS');
      expect(candidate.evidentiaryCapacity).toBeGreaterThanOrEqual(0.9);
    });
  });
});
