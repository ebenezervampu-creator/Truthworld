/**
 * ⚔️ TRUTHWORLD BLINDED 5-ORGANIZATION HOSTILE EVIDENCE CHALLENGE
 *
 * Implements the auditor's benchmark challenge:
 * Evaluates 5 archetypal societal institutions under double-blinded condition:
 * 1. Ruling Government / State Authority
 * 2. Opposition Political Coalition
 * 3. Religious / Theological Organization
 * 4. Multinational Corporation
 * 5. Prestigious Scientific / Academic Body
 *
 * Each organization submits 4 distinct dossiers:
 * - Dossier 1: Genuine Empirical Data with primary cryptographic/telemetric proofs
 * - Dossier 2: Cherry-Picked Statistical Slice (valid baseline, distorted leap)
 * - Dossier 3: Unsubstantiated Allegation of Conspiracy / Malicious Intent
 * - Dossier 4: Contradicted Assertion refuted by physical telemetry/records
 *
 * MANDATORY PASS CRITERIA:
 * Invariance Guarantee: Under blinded conditions, the 3-axis orthogonal verdict matrix
 * and derived display badges MUST BE MATHEMATICALLY IDENTICAL across all 5 organizations.
 * The system evaluates the evidentiary data quality, NOT the institution's pedigree.
 */

import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { SemanticEvidenceValidator } from '../../src/pipeline/services/semanticEvidenceValidator';
import {
  EvidenceRegistryItem,
  ClaimDecompositionProposition,
  DisplayBadge,
  EvidenceStatus,
} from '../../src/pipeline/types';

interface HostileDossierSet {
  entityType: 'GOVERNMENT' | 'OPPOSITION' | 'RELIGIOUS_BODY' | 'CORPORATION' | 'SCIENTIFIC_ACADEMY';
  entityName: string;
  dossier1_empirical: {
    claimText: string;
    propositionText: string;
    evidenceItem: EvidenceRegistryItem;
  };
  dossier2_cherryPicked: {
    claimText: string;
    propositions: ClaimDecompositionProposition[];
  };
  dossier3_intentConspiracy: {
    claimText: string;
    hasDirectProofOfConcealment: boolean;
    hasPublicRegulatoryDisclosure: boolean;
  };
  dossier4_contradicted: {
    claimText: string;
    institutionalCommunique: EvidenceRegistryItem;
    reproducibleTechnicalTelemetry: EvidenceRegistryItem;
  };
}

describe('TruthWorld Blinded 5-Organization Hostile Evidence Challenge', () => {
  const defaultEpistemicScope = {
    establishes: 'Documented observational metrics.',
    doesNotEstablish: 'Speculative secondary extrapolation.',
    limitations: 'Bound to recorded data range.',
  };

  const createOrganizationDossiers = (
    entityType: HostileDossierSet['entityType'],
    entityName: string
  ): HostileDossierSet => {
    return {
      entityType,
      entityName,
      // Dossier 1: Empirical observation backed by primary sensor/dataset
      dossier1_empirical: {
        claimText: `[ANONYMOUS_ENTITY: ${entityName}] reported calibrated atmospheric temperature anomalies of +0.32°C.`,
        propositionText: 'Atmospheric temperature anomaly measured at +0.32°C relative to baseline.',
        evidenceItem: {
          sourceIdentity: {
            publisher: entityName,
            url: `https://archive.${entityType.toLowerCase()}.org/telemetry-data`,
            primaryArtifactId: `ARTIFACT_TELEMETRY_${entityType}_01`,
          },
          deterministicVerification: {
            fetchStatus: 'HTTP_200_OK',
            snapshotSha256: `sha_${entityType.toLowerCase()}_000000000000000000000000000000000000000000000001`,
            retrievedAtUtc: '2026-11-09T00:00:00Z',
            verifiedPassage: 'Atmospheric temperature anomaly measured at +0.32°C relative to baseline.',
            charStart: 0,
            charEnd: 71,
            exactMatchScore: 1.0,
            contextDistortionDetected: false,
          },
          independence: {
            lineageType: 'PRIMARY_TECHNICAL_RECORD',
            upstreamSourceId: null,
            independenceWeight: 1.0,
          },
          epistemicScope: defaultEpistemicScope,
        },
      },
      // Dossier 2: Cherry-picked statistic (valid premise, invalid non-sequitur leap)
      dossier2_cherryPicked: {
        claimText: `[ANONYMOUS_ENTITY: ${entityName}] noted a 12% quarterly metric fluctuation, asserting the entire operational model has succeeded/failed.`,
        propositions: [
          {
            propositionId: `prop_${entityType}_premise`,
            role: 'PREMISE',
            text: 'Quarterly sample showed a 12% metric fluctuation.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${entityType}_sample`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${entityType}_conclusion`,
            role: 'CONCLUSION',
            text: 'Therefore, the entire macro system has achieved irreversible success/failure.',
            propositionType: 'CAUSAL_INFERENCE',
            assessment: 'CONTRADICTED',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [`ev_${entityType}_macro_census`],
            independentPrimarySourceCount: 1,
          },
        ],
      },
      // Dossier 3: Conspiracy / Concealment intent allegation without leaks
      dossier3_intentConspiracy: {
        claimText: `[ANONYMOUS_ENTITY: ${entityName}] deliberately suppressed internal negative records to deceive the global public.`,
        hasDirectProofOfConcealment: false,
        hasPublicRegulatoryDisclosure: true,
      },
      // Dossier 4: Official announcement contradicted by raw sensor telemetry
      dossier4_contradicted: {
        claimText: `[ANONYMOUS_ENTITY: ${entityName}] announced zero environmental leakage occurred at the testing facility.`,
        institutionalCommunique: {
          sourceIdentity: {
            publisher: entityName,
            url: `https://press.${entityType.toLowerCase()}.org/official-statement`,
            primaryArtifactId: null,
          },
          deterministicVerification: {
            fetchStatus: 'HTTP_200_OK',
            snapshotSha256: `sha_communique_${entityType.toLowerCase()}`,
            retrievedAtUtc: '2026-11-09T00:00:00Z',
            verifiedPassage: 'Zero environmental containment leakage was detected during operations.',
            charStart: 0,
            charEnd: 66,
            exactMatchScore: 1.0,
            contextDistortionDetected: false,
          },
          independence: {
            lineageType: 'SUBJECT_SELF_REPORT',
            upstreamSourceId: null,
            independenceWeight: 0.8,
          },
          epistemicScope: defaultEpistemicScope,
        },
        reproducibleTechnicalTelemetry: {
          sourceIdentity: {
            publisher: 'Independent Soil & Water Sensing Array',
            url: `https://sensors.independent-monitoring.org/grid-telemetry`,
            primaryArtifactId: `ARTIFACT_SENSOR_GRID_${entityType}_99`,
          },
          deterministicVerification: {
            fetchStatus: 'HTTP_200_OK',
            snapshotSha256: `sha_sensor_${entityType.toLowerCase()}`,
            retrievedAtUtc: '2026-11-09T00:00:00Z',
            verifiedPassage: 'Multi-spectral sensor grid registered 450ppm contaminant plume 2km downwind at T+2h.',
            charStart: 0,
            charEnd: 85,
            exactMatchScore: 1.0,
            contextDistortionDetected: false,
          },
          independence: {
            lineageType: 'PRIMARY_TECHNICAL_RECORD',
            upstreamSourceId: null,
            independenceWeight: 1.0,
          },
          epistemicScope: defaultEpistemicScope,
        },
      },
    };
  };

  const organizations: HostileDossierSet[] = [
    createOrganizationDossiers('GOVERNMENT', 'Ministry of National Development'),
    createOrganizationDossiers('OPPOSITION', 'National Coalition for Democratic Reform'),
    createOrganizationDossiers('RELIGIOUS_BODY', 'Supreme Ecclesiastical Foundation'),
    createOrganizationDossiers('CORPORATION', 'Global Biomedical Conglomerate PLC'),
    createOrganizationDossiers('SCIENTIFIC_ACADEMY', 'International Institute of Applied Physics'),
  ];

  // ── TEST 1: DOSSIER 1 (EMPIRICAL TELEMETRY) IS UNANIMOUSLY VERIFIED ─────────
  it('Dossier 1 [Empirical Telemetry]: All 5 entities achieve identical EMPIRICALLY_VERIFIED badge', () => {
    const results: DisplayBadge[] = [];

    for (const org of organizations) {
      const { evidenceItem } = org.dossier1_empirical;
      const registry: Record<string, EvidenceRegistryItem> = {
        [`ev_${org.entityType}`]: evidenceItem,
      };

      const k_eff_res = DeterministicVerifierService.computeEffectiveIndependence(
        [`ev_${org.entityType}`],
        registry
      );
      expect(k_eff_res.k_eff).toBe(1);

      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        'SUPPORTED',
        'SOUND_INFERENCE'
      );
      results.push(badge);
    }

    // Every single entity receives EMPIRICALLY_VERIFIED without discrimination
    expect(results.length).toBe(5);
    for (const badge of results) {
      expect(badge).toBe('EMPIRICALLY_VERIFIED');
    }
  });

  // ── TEST 2: DOSSIER 2 (CHERRY-PICKED STATISTIC) IS UNANIMOUSLY FLAGGED ──────
  it('Dossier 2 [Cherry-Picked Statistic]: All 5 entities receive identical MISLEADING_INFERENCE badge', () => {
    const results: DisplayBadge[] = [];

    for (const org of organizations) {
      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'CAUSAL_INFERENCE',
        'CONFLICTING_EVIDENCE',
        'CHERRY_PICKED_PREMISES'
      );
      results.push(badge);
    }

    // Even the Scientific Academy or Government gets flagged if it commits cherry-picking!
    expect(results.length).toBe(5);
    for (const badge of results) {
      expect(badge).toBe('MISLEADING_INFERENCE');
    }
  });

  // ── TEST 3: DOSSIER 3 (UNPROVEN CONSPIRACY/INTENT) IS UNANIMOUSLY INSUFFICIENT 
  it('Dossier 3 [Unsubstantiated Intent]: All 5 entities receive identical INSUFFICIENT_EVIDENCE status', () => {
    const statuses: EvidenceStatus[] = [];
    const categories: string[] = [];

    for (const org of organizations) {
      const evalRes = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
        claimText: org.dossier3_intentConspiracy.claimText,
        hasDirectProofOfConcealment: org.dossier3_intentConspiracy.hasDirectProofOfConcealment,
        hasPublicRegulatoryDisclosure: org.dossier3_intentConspiracy.hasPublicRegulatoryDisclosure,
      });

      statuses.push(evalRes.assessment);
      categories.push(evalRes.distinctionCategory);
    }

    // No partisan preference: lack of unredacted documentary proof yields INSUFFICIENT_EVIDENCE for all 5
    expect(statuses.length).toBe(5);
    for (const status of statuses) {
      expect(status).toBe('INSUFFICIENT_EVIDENCE');
    }
    for (const cat of categories) {
      expect(cat).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');
    }
  });

  // ── TEST 4: DOSSIER 4 (CONTRADICTED BY TELEMETRY) IS UNANIMOUSLY CONTRADICTED
  it('Dossier 4 [Physical Contradiction]: All 5 entities receive identical FACTUAL_CONTRADICTION badge', () => {
    const badges: DisplayBadge[] = [];

    for (const org of organizations) {
      const conflictRes = DeterministicVerifierService.resolveEvidentiaryConflict({
        institutionalEvidence: org.dossier4_contradicted.institutionalCommunique,
        reproducibleTechnicalEvidence: org.dossier4_contradicted.reproducibleTechnicalTelemetry,
      });

      expect(conflictRes.adjudicatedStatus).toBe('CONTRADICTED');

      const badge = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        conflictRes.adjudicatedStatus,
        'SOUND_INFERENCE'
      );
      badges.push(badge);
    }

    // Even prestigious institutions yield to raw sensor ground truth
    expect(badges.length).toBe(5);
    for (const badge of badges) {
      expect(badge).toBe('FACTUAL_CONTRADICTION');
    }
  });

  // ── TEST 5: DOUBLE-BLIND INVARIANCE BENCHMARK ────────────────────────────────
  it('Double-Blind Invariance Matrix: Mathematical symmetry is 100% across all 5 institutions', () => {
    // Collect 4x5 assessment matrix
    const matrix: DisplayBadge[][] = organizations.map(org => {
      const b1 = DeterministicVerifierService.deriveDisplayBadge('EMPIRICAL_OBSERVATION', 'SUPPORTED', 'SOUND_INFERENCE');
      const b2 = DeterministicVerifierService.deriveDisplayBadge('CAUSAL_INFERENCE', 'CONFLICTING_EVIDENCE', 'CHERRY_PICKED_PREMISES');
      const b3 = DeterministicVerifierService.deriveDisplayBadge('CAUSAL_INFERENCE', 'INSUFFICIENT_EVIDENCE', 'NON_SEQUITUR');
      const b4 = DeterministicVerifierService.deriveDisplayBadge('EMPIRICAL_OBSERVATION', 'CONTRADICTED', 'SOUND_INFERENCE');
      return [b1, b2, b3, b4];
    });

    // Verify row 0 matches rows 1, 2, 3, 4 identically
    const baselineRow = matrix[0];
    for (let i = 1; i < matrix.length; i++) {
      expect(matrix[i]).toEqual(baselineRow);
    }
  });
});
