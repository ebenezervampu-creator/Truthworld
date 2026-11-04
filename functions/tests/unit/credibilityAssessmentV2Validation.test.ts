import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { CredibilityAssessmentV2 } from '../../src/pipeline/types';

describe('Unit: Credibility Assessment V2 & Deterministic Verification Engine', () => {
  // Canonical Apollo 11 V2 fixture matching Section 9 contract
  const validApolloV2Assessment: CredibilityAssessmentV2 = {
    assessmentId: 'asmt_01HV9Z8K2M',
    schemaVersion: '2.0.0',
    videoContext: {
      videoId: 'vid_99281',
      startTimeMs: 14200,
      endTimeMs: 28500,
      asrMinTokenConfidence: 0.94,
      speakerStance: 'SPEAKER_ASSERTS',
      modalityEvaluated: ['AUDIO_TRANSCRIPT', 'KEYFRAME_OCR', 'VISUAL_INSPECTION'],
    },
    claimText: 'Apollo 11 photographs contain no visible stars, proving the Moon landing was filmed in a studio.',
    classification: {
      propositionType: 'CAUSAL_INFERENCE',
      evidenceStatus: 'CONTRADICTED',
      reasoningValidity: 'NON_SEQUITUR',
      displayBadge: 'MISLEADING_INFERENCE',
    },
    claimDecomposition: [
      {
        propositionId: 'prop_1',
        role: 'PREMISE',
        text: 'Apollo 11 lunar surface photographs do not show visible stars in the background.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_001'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_2',
        role: 'CONCLUSION',
        text: 'The absence of visible stars establishes that the Moon landing was filmed in a Hollywood studio.',
        propositionType: 'CAUSAL_INFERENCE',
        assessment: 'CONTRADICTED',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_001', 'ev_002'],
        independentPrimarySourceCount: 2,
      },
    ],
    evidenceRegistry: {
      ev_001: {
        sourceIdentity: {
          publisher: 'NASA History Division / Apollo Lunar Surface Journal',
          url: 'https://www.nasa.gov/history/alsj/a11/a11Photog.html',
          primaryArtifactId: 'NASA-ALSJ-A11-PHOTO-SPEC',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          retrievedAtUtc: '2026-11-02T16:40:12Z',
          verifiedPassage:
            'The Hasselblad cameras were set to daytime exposure speeds (1/250th sec at f/11) to capture brightly sunlit lunar objects; faint starlight cannot register at this exposure.',
          charStart: 4120,
          charEnd: 4294,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PRIMARY_TECHNICAL_RECORD',
          upstreamSourceId: null,
          independenceWeight: 1.0,
        },
        epistemicScope: {
          establishes:
            'Daytime shutter and aperture settings prevent faint stars from appearing on film while photographing sunlit foreground objects.',
          doesNotEstablish: 'Independent physical telemetry of the spacecraft trajectory.',
          limitations: 'Technical documentation of photographic parameters only.',
        },
      },
      ev_002: {
        sourceIdentity: {
          publisher: 'Journal of the Optical Society of America',
          url: 'https://opg.optica.org/josa/abstract.cfm?uri=josa-59-11-1440',
          primaryArtifactId: 'JOSA-1969-LUNAR-OPTICS',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0',
          retrievedAtUtc: '2026-11-02T16:42:00Z',
          verifiedPassage:
            'Dynamic range analysis confirms that photographic emulsions cannot simultaneously register direct solar reflection on regolith and magnitude 6 stars.',
          charStart: 850,
          charEnd: 1010,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PEER_REVIEWED_RESEARCH',
          upstreamSourceId: null,
          independenceWeight: 1.0,
        },
        epistemicScope: {
          establishes: 'Physical impossibility of capturing dim starlight alongside high-albedo sunlit regolith on film.',
          doesNotEstablish: 'Astronaut identity or launch provenance.',
          limitations: 'Laboratory and emulsion model limits.',
        },
      },
    },
    reasoningAssessment: {
      premisesVerifiedAccurate: ['prop_1'],
      conclusionFollowsDeductively: false,
      conclusionFollowsInductively: false,
      evaluatedAlternativeExplanations: [
        {
          explanation:
            'Daytime photographic exposure settings on the sunlit lunar surface underexpose dim background stars.',
          supportingEvidenceIds: ['ev_001'],
        },
      ],
    },
    backendAuditFlags: {
      allReferencedCitationsDeterministicallyVerified: true,
      unverifiedEvidencePresent: false,
      closedWorldCitationCheckPassed: true,
    },
    uncertainty: {
      numericalConfidenceAvailable: false,
      calibrationModelVersion: null,
      qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE',
      conformalPredictionSet: ['MISLEADING_INFERENCE'],
      disclosedGaps: [],
    },
  };

  describe('Contract Schema & Validation Rules', () => {
    it('validates canonical V2 Apollo 11 contract successfully', () => {
      const result = DeterministicVerifierService.validateAssessmentV2(validApolloV2Assessment);
      expect(result.isValid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it('Rule 1 (Referential Integrity): rejects reference to non-existent evidence ID', () => {
      const corrupted: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      corrupted.claimDecomposition[0].supportingEvidenceIds.push('ev_phantom_999');

      const result = DeterministicVerifierService.validateAssessmentV2(corrupted);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('[REFERENTIAL_INTEGRITY]'))).toBe(true);
      expect(result.errors.some(e => e.includes('ev_phantom_999'))).toBe(true);
    });

    it('Rule 2 (Non-Empty Grounding): rejects SUPPORTED proposition with exactMatchScore < 0.95', () => {
      const corrupted: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      corrupted.evidenceRegistry['ev_001'].deterministicVerification.exactMatchScore = 0.82;

      const result = DeterministicVerifierService.validateAssessmentV2(corrupted);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('[NON_EMPTY_GROUNDING]'))).toBe(true);
      expect(result.errors.some(e => e.includes('exactMatchScore < 0.95'))).toBe(true);
    });

    it('Rule 2 (Non-Empty Grounding): rejects SUPPORTED proposition with empty evidence IDs', () => {
      const corrupted: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      corrupted.claimDecomposition[0].supportingEvidenceIds = [];

      const result = DeterministicVerifierService.validateAssessmentV2(corrupted);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('zero supportingEvidenceIds'))).toBe(true);
    });

    it('Rule 3 (Computed Audit Flags): rejects payload claiming allCitationsVerified=true when match score fails', () => {
      const corrupted: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      corrupted.evidenceRegistry['ev_001'].deterministicVerification.exactMatchScore = 0.70;
      // Self-reporting true in backendAuditFlags while evidence is unverified
      corrupted.backendAuditFlags.allReferencedCitationsDeterministicallyVerified = true;

      const result = DeterministicVerifierService.validateAssessmentV2(corrupted);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('[AUDIT_FLAG_TAMPER]'))).toBe(true);
    });

    it('Rule 4 (Independence Floor): rejects HIGH_EVIDENCE_CONCORDANCE if independence weight is under floor', () => {
      const corrupted: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      // Reduce independence weights
      corrupted.evidenceRegistry['ev_001'].independence.independenceWeight = 0.2;
      corrupted.evidenceRegistry['ev_002'].independence.independenceWeight = 0.3;

      const result = DeterministicVerifierService.validateAssessmentV2(corrupted);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('[INDEPENDENCE_FLOOR]'))).toBe(true);
    });

    it('Rule 5 (Theological & Opinion Guardrail): rejects THEOLOGICAL_DOCTRINE marked as SUPPORTED or CONTRADICTED', () => {
      const faithAssessment: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      faithAssessment.classification.propositionType = 'THEOLOGICAL_DOCTRINE';
      faithAssessment.classification.evidenceStatus = 'SUPPORTED'; // Violation! Must be NOT_EMPIRICALLY_TESTABLE

      const result = DeterministicVerifierService.validateAssessmentV2(faithAssessment);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('[THEOLOGICAL_OPINION_GUARDRAIL]'))).toBe(true);
    });

    it('Rule 5 (Theological & Opinion Guardrail): accepts THEOLOGICAL_DOCTRINE marked NOT_EMPIRICALLY_TESTABLE', () => {
      const faithAssessment: CredibilityAssessmentV2 = JSON.parse(JSON.stringify(validApolloV2Assessment));
      faithAssessment.classification.propositionType = 'THEOLOGICAL_DOCTRINE';
      faithAssessment.classification.evidenceStatus = 'NOT_EMPIRICALLY_TESTABLE';
      faithAssessment.classification.displayBadge = 'FAITH_DOCTRINE';
      faithAssessment.claimDecomposition[0].propositionType = 'THEOLOGICAL_DOCTRINE';
      faithAssessment.claimDecomposition[0].assessment = 'NOT_EMPIRICALLY_TESTABLE';
      faithAssessment.claimDecomposition[0].supportingEvidenceIds = [];

      const result = DeterministicVerifierService.validateAssessmentV2(faithAssessment);
      expect(result.isValid).toBe(true);
    });
  });

  describe('Deterministic Exact Span Alignment Engine', () => {
    const rawCorpus =
      'NASA Apollo 11 Lunar Surface Journal: The Hasselblad cameras were set to daytime exposure speeds (1/250th sec at f/11) to capture brightly sunlit lunar objects; faint starlight cannot register at this exposure.';

    it('identifies verbatim passage match with score 1.0 and exact offsets', () => {
      const passage =
        'The Hasselblad cameras were set to daytime exposure speeds (1/250th sec at f/11) to capture brightly sunlit lunar objects; faint starlight cannot register at this exposure.';
      const alignment = DeterministicVerifierService.computeExactSpanAlignment(rawCorpus, passage);

      expect(alignment.exactMatchScore).toBe(1.0);
      expect(alignment.charStart).toBe(38);
      expect(alignment.charEnd).toBe(38 + passage.length);
      expect(rawCorpus.substring(alignment.charStart, alignment.charEnd)).toBe(passage);
    });

    it('detects case-insensitive match with score 0.99', () => {
      const passage = 'THE HASSELBLAD CAMERAS WERE SET TO DAYTIME EXPOSURE SPEEDS';
      const alignment = DeterministicVerifierService.computeExactSpanAlignment(rawCorpus, passage);

      expect(alignment.exactMatchScore).toBe(0.99);
      expect(alignment.charStart).toBe(38);
    });

    it('detects whitespace-normalized match with score 0.97', () => {
      const passage = 'The   Hasselblad cameras   were set to daytime  exposure speeds';
      const alignment = DeterministicVerifierService.computeExactSpanAlignment(rawCorpus, passage);

      expect(alignment.exactMatchScore).toBe(0.97);
      expect(alignment.charStart).toBeGreaterThanOrEqual(0);
    });

    it('computes low score for hallucinated / nonexistent passage', () => {
      const fakePassage = 'Stanley Kubrick officially directed the lunar descent in Stage 5 of Elstree Studios in London.';
      const alignment = DeterministicVerifierService.computeExactSpanAlignment(rawCorpus, fakePassage);

      expect(alignment.exactMatchScore).toBeLessThan(0.4);
      expect(alignment.charStart).toBe(-1);
    });
  });

  describe('Deterministic 3-Axis DisplayBadge Derivation Table', () => {
    it('derives FAITH_DOCTRINE for THEOLOGICAL_DOCTRINE regardless of evidenceStatus', () => {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'THEOLOGICAL_DOCTRINE',
        'NOT_EMPIRICALLY_TESTABLE',
        'NOT_APPLICABLE'
      );
      expect(badge).toBe('FAITH_DOCTRINE');
    });

    it('derives NORMATIVE_VALUE_JUDGMENT for NORMATIVE_OPINION', () => {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'NORMATIVE_OPINION',
        'NOT_EMPIRICALLY_TESTABLE',
        'NOT_APPLICABLE'
      );
      expect(badge).toBe('NORMATIVE_VALUE_JUDGMENT');
    });

    it('derives UNVERIFIED_PREDICTION for FUTURE_PREDICTION', () => {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'FUTURE_PREDICTION',
        'INSUFFICIENT_EVIDENCE',
        'NOT_APPLICABLE'
      );
      expect(badge).toBe('UNVERIFIED_PREDICTION');
    });

    it('derives MISLEADING_INFERENCE when premises are observable but inference is NON_SEQUITUR', () => {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'CAUSAL_INFERENCE',
        'SUPPORTED',
        'NON_SEQUITUR'
      );
      expect(badge).toBe('MISLEADING_INFERENCE');
    });

    it('derives EMPIRICALLY_VERIFIED for empirical observations supported by evidence', () => {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        'SUPPORTED',
        'SOUND_INFERENCE'
      );
      expect(badge).toBe('EMPIRICALLY_VERIFIED');
    });

    it('derives FACTUAL_CONTRADICTION when evidenceStatus is CONTRADICTED', () => {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        'CONTRADICTED',
        'SOUND_INFERENCE'
      );
      expect(badge).toBe('FACTUAL_CONTRADICTION');
    });
  });

  describe('Effective Independence (k_eff) & Syndication Discounting', () => {
    it('discounts syndicated derivatives sharing upstream source ID', () => {
      const registry: Record<string, any> = {
        ev_01: {
          independence: {
            lineageType: 'PRIMARY_TECHNICAL_RECORD',
            upstreamSourceId: 'AP_WIRE_901',
            independenceWeight: 0.5,
          },
        },
        ev_02: {
          independence: {
            lineageType: 'SYNDICATED_DERIVATIVE',
            upstreamSourceId: 'AP_WIRE_901', // Duplicate wire reprint
            independenceWeight: 0.0,
          },
        },
        ev_03: {
          independence: {
            lineageType: 'SYNDICATED_DERIVATIVE',
            upstreamSourceId: 'AP_WIRE_901', // Duplicate wire reprint
            independenceWeight: 0.0,
          },
        },
        ev_04: {
          independence: {
            lineageType: 'PEER_REVIEWED_RESEARCH',
            upstreamSourceId: null, // Distinct primary source
            independenceWeight: 1.0,
          },
        },
      };

      const { k_eff, totalWeight } = DeterministicVerifierService.computeEffectiveIndependence(
        ['ev_01', 'ev_02', 'ev_03', 'ev_04'],
        registry
      );

      // 3 AP wire re-prints count as 1 upstream source + 1 peer-reviewed research = 2 independent sources
      expect(k_eff).toBe(2);
      expect(totalWeight).toBe(1.5);
    });
  });
});
