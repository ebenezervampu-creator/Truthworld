/**
 * 🏛 TN-10: INSTITUTIONAL REPUTATION REVERSAL & DYNAMIC TRUST GOVERNANCE
 *
 * Implements the auditor's key requirements:
 * 1. TN-10 (Epistemic Sovereignty): Primary reproducible technical telemetry decisively
 *    refutes and overrides a Tier-A institutional press release or unverified assertion.
 *    Pedigree is never proof.
 * 2. Formal Retraction Invalidation: When an institution or journal retracts an article,
 *    its evidentiary weight collapses to 0.0, and any payload using it as SUPPORTED is rejected.
 * 3. Authorized Provisional Downgrade: Multi-signatory ombudsman quorum can provisionally
 *    downgrade an institution, while crowdsourced brigading is strictly blocked.
 * 4. Cross-Lingual Framing Drift: Audits translation fidelity to prevent hyperbolic vernacular
 *    escalations (Hindi, Telugu) from inheriting a false stamp of validation.
 */

import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { sourceTrustService } from '../../src/pipeline/services/sourceTrustService';
import {
  EvidenceRegistryItem,
  ClaimDecompositionProposition,
  CredibilityAssessmentV2,
} from '../../src/pipeline/types';

describe('TruthWorld TN-10: Institutional Reputation Reversal & Dynamic Trust Governance', () => {
  beforeEach(() => {
    sourceTrustService.resetDynamicOverrides();
  });

  // ── TN-10: PRIMARY TELEMETRY DECISIVELY OVERRIDES TIER-A INSTITUTIONAL ASSERTION ──
  it('TN-10 [Institutional Reputation Reversal]: Prioritizes reproducible primary telemetry over Tier-A institutional authority', () => {
    const defaultScope = {
      establishes: 'Telemetry and trajectory metrics.',
      doesNotEstablish: 'Subsequent mission recovery plans.',
      limitations: 'Limited to orbital tracking arc.',
    };

    // 1. Tier-A Institutional Source (Official Space Agency Communique, NO raw telemetry)
    const institutionalEvidence: EvidenceRegistryItem = {
      sourceIdentity: {
        publisher: 'National Space Agency',
        url: 'https://isro.gov.in/mission-alpha-status',
        primaryArtifactId: null,
      },
      deterministicVerification: {
        fetchStatus: 'HTTP_200_OK',
        snapshotSha256: 'agency_communique_sha_1111111111111111111111111111111111111111111111111111111111111111',
        retrievedAtUtc: '2026-11-09T00:00:00Z',
        verifiedPassage: 'Mission Alpha successfully reached intended geostationary transfer orbit with all parameters nominal.',
        charStart: 0,
        charEnd: 101,
        exactMatchScore: 1.0,
        contextDistortionDetected: false,
      },
      independence: {
        lineageType: 'SUBJECT_SELF_REPORT',
        upstreamSourceId: null,
        independenceWeight: 0.8,
      },
      epistemicScope: defaultScope,
    };

    // 2. Independent Amateur/Outsider Tracking Network (Tier-E domain, BUT raw Doppler telemetry)
    const rawTelemetryEvidence: EvidenceRegistryItem = {
      sourceIdentity: {
        publisher: 'Independent Radio Astronomy Network',
        url: 'https://amateur-sat-trackers.org/doppler-alpha',
        primaryArtifactId: 'RAW_DOPPLER_RADAR_SENSOR_STREAM_01',
      },
      deterministicVerification: {
        fetchStatus: 'HTTP_200_OK',
        snapshotSha256: 'telemetry_stream_sha_2222222222222222222222222222222222222222222222222222222222222222',
        retrievedAtUtc: '2026-11-09T00:00:00Z',
        verifiedPassage: 'Doppler frequency shift confirms loss of signal and rapid orbital decay at T+42m into South Pacific Ocean.',
        charStart: 0,
        charEnd: 110,
        exactMatchScore: 1.0,
        contextDistortionDetected: false,
      },
      independence: {
        lineageType: 'PRIMARY_TECHNICAL_RECORD',
        upstreamSourceId: null,
        independenceWeight: 1.0,
      },
      epistemicScope: defaultScope,
    };

    // Execute conflict resolution between institutional prestige and physical telemetry
    const conflictResult = DeterministicVerifierService.resolveEvidentiaryConflict({
      institutionalEvidence,
      reproducibleTechnicalEvidence: rawTelemetryEvidence,
    });

    // Evidence Sovereignty Rule: Reproducible primary telemetry wins decisively
    expect(conflictResult.adjudicatedStatus).toBe('CONTRADICTED');
    expect(conflictResult.winningEvidenceId).toBe('RAW_DOPPLER_RADAR_SENSOR_STREAM_01');
    expect(conflictResult.precedenceReason).toContain('EVIDENCE_SOVEREIGNTY');

    // Display badge derivation must reflect FACTUAL_CONTRADICTION, refusing institutional halo bias
    const badge = DeterministicVerifierService.deriveDisplayBadge(
      'EMPIRICAL_OBSERVATION',
      conflictResult.adjudicatedStatus,
      'SOUND_INFERENCE'
    );
    expect(badge).toBe('FACTUAL_CONTRADICTION');
  });

  // ── FORMAL RETRACTION INVALIDATION ─────────────────────────────────────────
  it('Formal Retraction Invalidation: Formally retracted papers immediately lose trust and are rejected in validation', () => {
    // Register formal retraction of an article from a Tier-A journal (e.g. Lancet Surgisphere scenario)
    const retractedUrl = 'https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(20)31180-6/fulltext';
    sourceTrustService.registerFormalRetraction({
      targetUrlOrDoi: retractedUrl,
      sourceDomain: 'thelancet.com',
      retractingEntity: 'The Lancet Editors',
      reason: 'Authors unable to grant third-party independent audit access to raw hospital patient dataset.',
      retractedAtUtc: '2026-11-09T12:00:00Z',
      formalNoticeUrl: 'https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(20)31324-6/fulltext',
    });

    // Trust lookup for retracted URL must return 0.0 trust and isRetracted = true
    const rep = sourceTrustService.resolveSourceTrust(retractedUrl, 'medical');
    expect(rep.isRetracted).toBe(true);
    expect(rep.reputationScore).toBe(0.0);
    expect(rep.tier).toBe('E');

    // Attempting to submit a payload using retracted citation as SUPPORTED must be rejected by validateAssessmentV2
    const registry: Record<string, EvidenceRegistryItem> = {
      ev_retracted_paper: {
        sourceIdentity: {
          publisher: 'The Lancet',
          url: retractedUrl,
          primaryArtifactId: null,
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'lancet_sha_0000000000000000000000000000000000000000000000000000000000000000',
          retrievedAtUtc: '2026-11-09T00:00:00Z',
          verifiedPassage: 'Hospital observational cohort indicates adverse cardiovascular outcomes.',
          charStart: 0,
          charEnd: 70,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PEER_REVIEWED_RESEARCH',
          upstreamSourceId: null,
          independenceWeight: 0.9,
        },
        epistemicScope: {
          establishes: 'Hospital observation.',
          doesNotEstablish: 'Causality.',
          limitations: 'Retracted data.',
        },
        // Marked retracted
        ...({ isRetracted: true, retractionNotice: 'Authors unable to grant data audit access.' } as any),
      },
    };

    const payload: CredibilityAssessmentV2 = {
      assessmentId: 'test_retraction_audit_01',
      schemaVersion: '2.0.0',
      claimText: 'Observational trial proves adverse cardiovascular outcomes.',
      classification: {
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceStatus: 'SUPPORTED',
        reasoningValidity: 'SOUND_INFERENCE',
        displayBadge: 'VERIFIED_FACT',
      },
      claimDecomposition: [
        {
          propositionId: 'prop_med_1',
          role: 'CONCLUSION',
          text: 'Observational trial proves adverse cardiovascular outcomes.',
          propositionType: 'EMPIRICAL_OBSERVATION',
          assessment: 'SUPPORTED',
          supportingEvidenceIds: ['ev_retracted_paper'],
          contradictingEvidenceIds: [],
          independentPrimarySourceCount: 1,
        },
      ],
      evidenceRegistry: registry,
      reasoningAssessment: {
        premisesVerifiedAccurate: ['prop_med_1'],
        conclusionFollowsDeductively: true,
        conclusionFollowsInductively: true,
        evaluatedAlternativeExplanations: [],
      },
      uncertainty: {
        numericalConfidenceAvailable: false,
        calibrationModelVersion: null,
        qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE',
        conformalPredictionSet: ['VERIFIED_FACT'],
        disclosedGaps: [],
      },
      backendAuditFlags: {
        allReferencedCitationsDeterministicallyVerified: true,
        unverifiedEvidencePresent: false,
        closedWorldCitationCheckPassed: true,
      },
    };

    const validation = DeterministicVerifierService.validateAssessmentV2(payload);
    expect(validation.isValid).toBe(false);
    expect(validation.errors.some(e => e.includes('RETRACTED_EVIDENCE_REJECTION'))).toBe(true);
  });

  // ── AUTHORIZED PROVISIONAL DOWNGRADE VS UNAUTHORIZED BRIGADING ────────────
  it('Provisional Downgrade: Multi-signatory ombudsman quorum updates domain reputation; unauthorized attempts fail', () => {
    // 1. Unauthorized attempt (e.g. brigaded attempt) must throw
    expect(() => {
      sourceTrustService.applyAuthorizedProvisionalDowngrade({
        domain: 'compromised-journal.org',
        downgradedTier: 'D',
        reducedReputationScore: 0.35,
        reason: 'Community user reports claim fraud.',
        authorizedByQuorum: false, // Unauthorized!
        authorizedAtUtc: '2026-11-09T00:00:00Z',
      });
    }).toThrow(/Multi-signatory quorum authorization required/);

    // 2. Authorized ombudsman downgrade applies cleanly
    sourceTrustService.applyAuthorizedProvisionalDowngrade({
      domain: 'compromised-journal.org',
      downgradedTier: 'D',
      reducedReputationScore: 0.35,
      reason: 'Multi-signatory independent ombudsman audit confirmed paper-mill infiltration.',
      authorizedByQuorum: true, // Authorized by formal quorum
      authorizedAtUtc: '2026-11-09T00:00:00Z',
    });

    const rep = sourceTrustService.resolveSourceTrust('https://compromised-journal.org/article-99');
    expect(rep.isProvisionallyDowngraded).toBe(true);
    expect(rep.tier).toBe('D');
    expect(rep.reputationScore).toBe(0.35);
  });

  // ── TN-11: CROSS-LINGUAL FRAMING DRIFT AUDITING (HINDI & TELUGU) ───────────
  it('TN-11 [Cross-Lingual Framing Drift]: Detects hyperbolic vernacular distortion vs faithful translation', () => {
    const englishSource = 'National industrial output growth moderated to 1.2% in the second quarter.';

    // A. Faithful Hindi translation: preserves empirical boundaries
    const faithfulHindi = 'दूसरी तिमाही में राष्ट्रीय औद्योगिक उत्पादन की वृद्धि दर धीमी होकर 1.2% रह गई।';
    const faithfulAudit = DeterministicVerifierService.auditCrossLingualDrift({
      sourceClaimText: englishSource,
      translatedClaimText: faithfulHindi,
      targetLang: 'hi',
    });
    expect(faithfulAudit.hasFramingDrift).toBe(false);
    expect(faithfulAudit.driftType).toBe('NONE');

    // B. Hyperbolic Hindi translation: mutates into catastrophic collapse
    const hyperbolicHindi = 'दूसरी तिमाही में देश के उद्योग पूरी तरह तबाह और बर्बाद हो गए हैं!';
    const hyperbolicAuditHindi = DeterministicVerifierService.auditCrossLingualDrift({
      sourceClaimText: englishSource,
      translatedClaimText: hyperbolicHindi,
      targetLang: 'hi',
    });
    expect(hyperbolicAuditHindi.hasFramingDrift).toBe(true);
    expect(hyperbolicAuditHindi.driftType).toBe('HYPERBOLIC_ESCALATION');
    expect(hyperbolicAuditHindi.severityScore).toBeGreaterThanOrEqual(0.85);

    // C. Hyperbolic Telugu translation: mutates into catastrophic failure
    const hyperbolicTelugu = 'రెండో త్రైమాసికంలో దేశీయ పరిశ్రమలు పూర్తిగా సర్వనాశనం అయ్యాయి!';
    const hyperbolicAuditTelugu = DeterministicVerifierService.auditCrossLingualDrift({
      sourceClaimText: englishSource,
      translatedClaimText: hyperbolicTelugu,
      targetLang: 'te',
    });
    expect(hyperbolicAuditTelugu.hasFramingDrift).toBe(true);
    expect(hyperbolicAuditTelugu.driftType).toBe('HYPERBOLIC_ESCALATION');
    expect(hyperbolicAuditTelugu.severityScore).toBeGreaterThanOrEqual(0.85);
  });
});
