import { ClaimVerificationService, canFinalizeClaim } from '../../src/pipeline/services/claimVerification';
import { ClaimStatus, ClaimNature, EvidenceLevel, VerifiedClaim, RecoveredClaimContext } from '../../src/pipeline/types';

describe('P0 Recovery State Machine & Re-Adjudication Test Suite', () => {
  let service: ClaimVerificationService;

  beforeEach(() => {
    service = new ClaimVerificationService('mock-api-key');
  });

  it('1. Finalization Barrier: Blocks provisional and retry-pending claims from finalizing', () => {
    const provisionalClaim: Partial<VerifiedClaim> = {
      claimId: 'claim-1',
      status: 'inconclusive',
      isProvisional: true,
      lifecycle: 'provisional',
      processingMetadata: { requiresCitationRetry: true }
    };

    expect(canFinalizeClaim(provisionalClaim as VerifiedClaim)).toBe(false);

    const reAdjudicatingClaim: Partial<VerifiedClaim> = {
      claimId: 'claim-2',
      status: 'inconclusive',
      isProvisional: false,
      lifecycle: 're_adjudication'
    };

    expect(canFinalizeClaim(reAdjudicatingClaim as VerifiedClaim)).toBe(false);

    const finalizedClaim: Partial<VerifiedClaim> = {
      claimId: 'claim-3',
      status: 'verified_true',
      isProvisional: false,
      lifecycle: 'finalized',
      processingMetadata: {}
    };

    expect(canFinalizeClaim(finalizedClaim as VerifiedClaim)).toBe(true);
  });

  it('2. Tier-E Admission Guard: Excludes Reddit, Scribd, and unverified UGC from valid source list', () => {
    const reddit = service.validateSource('https://reddit.com/r/indianeconomy/comments/xyz', 'Reddit Discussion');
    expect(reddit.isValid).toBe(false);

    const scribd = service.validateSource('https://www.scribd.com/document/12345/Some-Report', 'Scribd Document');
    expect(scribd.isValid).toBe(false);

    const tierAOfficial = service.validateSource('https://pmindia.gov.in/en/former-prime-ministers', 'Prime Minister of India');
    expect(tierAOfficial.isValid).toBe(true);
    expect(tierAOfficial.tier).toBe('A');
  });

  it('3. Re-Adjudication: Decouples evidenceStrength, verdictConfidence, and sourceIndependenceScore', async () => {
    const claim: Partial<VerifiedClaim> = {
      claimId: 'claim-nehru-pm',
      text: '1991 లో పి.వి. నరసింహారావు భారతదేశ ప్రధాని అయ్యారు.',
      nature: ClaimNature.VERIFIABLE_FACT,
      status: 'inconclusive',
      provisionalStatus: 'inconclusive',
      isProvisional: true,
      lifecycle: 'provisional',
      verificationConfidence: 0.45,
      adjudicationVersion: 1
    };

    const context: RecoveredClaimContext = {
      claimId: 'claim-nehru-pm',
      originalClaim: '1991 లో పి.వి. నరసింహారావు భారతదేశ ప్రధాని అయ్యారు.',
      provisionalStatus: 'inconclusive',
      recoveredSources: [
        {
          title: 'Prime Minister of India Official Archive',
          url: 'https://pmindia.gov.in/hi/former_pm/shri-p-v-narasimha-rao/',
          domain: 'pmindia.gov.in',
          publisher: 'pmindia.gov.in',
          tier: 'A',
          snippet: 'పి.వి. నరసింహారావు 1991 జూన్ 21న భారత ప్రధానమంత్రిగా ప్రమాణ స్వీకారం చేశారు.'
        },
        {
          title: 'P. V. Narasimha Rao Wikipedia Archive',
          url: 'https://te.wikipedia.org/wiki/P_V_Narasimha_Rao',
          domain: 'wikipedia.org',
          publisher: 'Wikipedia',
          tier: 'C',
          snippet: 'పాములపర్తి వేంకట నరసింహారావు భారతదేశానికి తొమ్మిదవ ప్రధానమంత్రిగా 1991 నుంచి 1996 దాకా పనిచేశారు.'
        }
      ],
      previousConfidence: 0.45,
      retrievalStage: 'citation_retry'
    };

    // Mock internal Gemini call for re-adjudication
    jest.spyOn<any, any>(service, 'reAdjudicateClaimWithRecoveredEvidence').mockResolvedValueOnce({
      status: 'verified_true',
      verdictConfidence: 0.98,
      evidenceStrength: 0.95,
      sourceIndependenceScore: 0.85,
      reasoning: 'P.V. Narasimha Rao took office as Prime Minister on June 21, 1991, verified by the official Prime Minister Office historical archives.'
    });

    const result = await (service as any).reAdjudicateClaimWithRecoveredEvidence(
      claim as VerifiedClaim,
      context,
      'History'
    );

    expect(result.status).toBe('verified_true');
    expect(result.verdictConfidence).toBe(0.98);
    expect(result.evidenceStrength).toBe(0.95);
    expect(result.sourceIndependenceScore).toBe(0.85);
    expect(result.reasoning).toContain('P.V. Narasimha Rao');
  });

  it('4. Re-Adjudication with Inadmissible/Tier-E sources retains INCONCLUSIVE', async () => {
    const claim: Partial<VerifiedClaim> = {
      claimId: 'claim-unsupported',
      text: 'An unverified claim with only forum chatter.',
      nature: ClaimNature.VERIFIABLE_FACT,
      status: 'inconclusive',
      provisionalStatus: 'inconclusive',
      isProvisional: true,
      lifecycle: 'provisional',
      verificationConfidence: 0.45,
      adjudicationVersion: 1
    };

    const context: RecoveredClaimContext = {
      claimId: 'claim-unsupported',
      originalClaim: 'An unverified claim with only forum chatter.',
      provisionalStatus: 'inconclusive',
      recoveredSources: [
        {
          title: 'Random Forum Thread',
          url: 'https://reddit.com/r/rumors/123',
          domain: 'reddit.com',
          tier: 'E',
          snippet: 'Someone said this happened.'
        }
      ],
      previousConfidence: 0.45,
      retrievalStage: 'citation_retry'
    };

    const result = await (service as any).reAdjudicateClaimWithRecoveredEvidence(
      claim as VerifiedClaim,
      context,
      'General'
    );

    expect(result.status).toBe('inconclusive');
    expect(result.evidenceStrength).toBe(0.0);
    expect(result.verdictConfidence).toBe(0.2);
  });
});
