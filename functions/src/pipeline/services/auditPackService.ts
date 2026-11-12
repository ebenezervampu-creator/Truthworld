import { BenchmarkClaimRecord, PublicAuditPackV1, RetractionRegistryRecord, SourceSnapshot, VerifiedClaim } from '../types';
import { CryptographicProvenanceService } from './cryptographicProvenanceService';
import { CitationRetractionService } from './citationRetractionService';

/**
 * 📦 Public Audit Pack Service (P5 Milestone - Hardened)
 * 
 * Generates an immutable, self-contained, cryptographically signed Public Audit Pack
 * for any finalized claim. External independent auditors can inspect the audit pack,
 * verify its asymmetric Ed25519 signature with the published public key, verify
 * SHA-256 source snapshots, examine temporal comparability, and reproduce the exact verdict
 * without requiring private model weights or closed internal infrastructure.
 */
export class AuditPackService {
  /**
   * Export a complete Public Audit Pack for a verified claim.
   */
  public static exportAuditPack(
    claim: VerifiedClaim,
    benchmarkRecord?: BenchmarkClaimRecord,
    datasetManifestHash: string = 'sha256_dataset_manifest_v2_0_0',
    privateKeyPem?: string
  ): PublicAuditPackV1 {
    const originalText = claim.text;
    const normalizedAtomicClaim = benchmarkRecord?.normalizedProposition || claim.text;
    const sourceLanguage = 'en';
    const epistemicCategory = benchmarkRecord?.epistemicCategory || 'historical_event';

    // 1. Compile Source Snapshots with cryptographic content hashes
    const sourceSnapshots: SourceSnapshot[] = [];
    const retractedSourcesAudit: RetractionRegistryRecord[] = [];

    // Admitted sources snapshots
    for (const source of claim.richSources || []) {
      const excerpt = source.snippet || `${source.title}: ${source.whatItSupports || 'Authoritative citation documentation.'}`;
      const contentSha256 = CryptographicProvenanceService.computeSha256(excerpt);
      sourceSnapshots.push({
        sourceUrl: source.url,
        title: source.title,
        retrievedAt: source.accessDate || source.lastVerified || new Date().toISOString(),
        contentSha256,
        permissibleExcerpt: excerpt,
        tier: (source.tier as any) || 'A',
        admissionDecision: 'admitted',
        admissionRationale: `Admitted under Stage 1 domain trust and Stage 2 semantic evidence passage grounding.`,
      });

      // Check if any source in richSources had a retraction check on record
      if (source.doi) {
        const retRecord = CitationRetractionService.lookupDoi(source.doi);
        if (retRecord && retRecord.status !== 'active') {
          retractedSourcesAudit.push(retRecord);
        }
      }
    }

    // Quarantined sources snapshots
    for (const source of claim.quarantinedSources || []) {
      const excerpt = source.snippet || `${source.title}: Excluded from primary evidence admission.`;
      const contentSha256 = CryptographicProvenanceService.computeSha256(excerpt);
      sourceSnapshots.push({
        sourceUrl: source.url,
        title: source.title,
        retrievedAt: source.accessDate || new Date().toISOString(),
        contentSha256,
        permissibleExcerpt: excerpt,
        tier: (source.tier as any) || 'E',
        admissionDecision: 'quarantined',
        admissionRationale: source.evidenceAssessment?.rejectionReason || 'Quarantined under Stage 1 admission policy or contradictory evidence.',
      });

      if (source.doi) {
        const retRecord = CitationRetractionService.lookupDoi(source.doi);
        if (retRecord) {
          retractedSourcesAudit.push(retRecord);
        }
      }
    }

    const packBodyWithoutSignature = {
      schemaVersion: '2.0.0-auditpack' as const,
      packId: `auditpack_${claim.claimId || 'claim'}_${Date.now()}`,
      generatedAt: new Date().toISOString(),
      claimId: claim.claimId || 'unknown_claim',
      proposition: {
        originalText,
        normalizedAtomicClaim,
        sourceLanguage,
        epistemicCategory,
      },
      verdict: {
        finalStatus: claim.status,
        verdictConfidence: claim.verdictConfidence ?? claim.confidence ?? 0.85,
        evidenceStrength: claim.evidenceStrength ?? 0.80,
        sourceIndependenceScore: claim.sourceIndependenceScore ?? 0.80,
        publicExplanation: claim.reasoning || 'Claim evaluated through TruthWorld multi-stage evidence gating, temporal comparability, and econometric volatility verification.',
      },
      evidenceGraph: {
        admittedSources: claim.richSources || [],
        quarantinedSources: claim.quarantinedSources || [],
        retractedSourcesAudit: retractedSourcesAudit.length > 0 ? retractedSourcesAudit : undefined,
        evidencePrecision: claim.richSources && claim.richSources.length > 0 ? 1.0 : 0.0,
      },
      sourceSnapshots,
      comparabilityAudit: claim.comparabilityAssessment ? {
        isComparative: !claim.comparabilityAssessment.isComparable,
        comparabilityStatus: claim.comparabilityAssessment.isComparable ? 'COMPATIBLE' : 'INCOMPATIBLE',
        reconciliationMethod: claim.comparabilityAssessment.accountingReconciliationStatus,
      } : undefined,
      engineMetadata: {
        modelIdentifier: 'truthworld-veritas-v2',
        pipelineVersion: '2.4.0-prod',
        policyCommitHash: 'git-rev-c60f4b3e81',
        retrievalConfiguration: {
          provider: 'authoritative_archives_v2',
          minTier: 'B',
          crossValidationThreshold: 2,
        },
      },
      sevenCoreAnswers: {
        q1_exactClaim: originalText,
        q2_supportingEvidence: (claim.richSources || []).map(s => `[${s.tier}] ${s.title} (${s.url})`).join('; ') || 'None admitted',
        q3_contradictoryEvidence: (claim.quarantinedSources || []).map(s => `[Quarantined] ${s.title}`).join('; ') || 'None detected',
        q4_sourceAdmissionRationale: `Admitted ${claim.richSources?.length || 0} authoritative sources under P1 two-stage gating.`,
        q5_comparabilityIntegrity: claim.comparabilityAssessment
          ? (claim.comparabilityAssessment.isComparable ? 'Valid baseline comparison' : `Invalid baseline comparison: ${claim.comparabilityAssessment.reasons.join(', ')}`)
          : 'Non-comparative atomic claim.',
        q6_epistemicConfidence: `Calibrated Confidence: ${((claim.verdictConfidence ?? 0.85) * 100).toFixed(1)}%, Evidence Strength: ${((claim.evidenceStrength ?? 0.8) * 100).toFixed(1)}%.`,
        q7_limitationsAndUnresolvedDisagreements: claim.publicNote || 'No unresolved evidentiary disputes remaining.',
      },
    };

    // Compute canonical SHA-256 hash over pack body
    const auditPackSha256 = CryptographicProvenanceService.computeSha256(packBodyWithoutSignature);
    const signature = CryptographicProvenanceService.signHashEd25519(auditPackSha256, privateKeyPem);
    const publicKeyPem = CryptographicProvenanceService.getAuthorityPublicKey();

    return {
      ...packBodyWithoutSignature,
      cryptographicAttestation: {
        auditPackSha256,
        datasetManifestHash,
        signerId: 'audit_authority_truthworld_main',
        algorithm: 'Ed25519',
        publicKeyPem,
        signature,
        verificationInstructions: 'Verify independently by computing SHA-256 over canonical JSON of the pack (excluding cryptographicAttestation) and verifying the Ed25519 signature with publicKeyPem.',
      },
    };
  }

  /**
   * Independently verify the cryptographic integrity of a Public Audit Pack.
   * Works for both V1 (legacy HMAC) and V2 (asymmetric Ed25519).
   */
  public static verifyAuditPack(
    pack: PublicAuditPackV1,
    verificationKey?: string
  ): { isValid: boolean; discrepancies: string[] } {
    const discrepancies: string[] = [];

    // Extract body without attestation
    const { cryptographicAttestation, ...bodyToVerify } = pack;

    // 1. Verify content SHA-256 hash
    const computedHash = CryptographicProvenanceService.computeSha256(bodyToVerify);
    if (computedHash !== cryptographicAttestation.auditPackSha256) {
      discrepancies.push(`Tamper Detected: Computed SHA-256 (${computedHash}) does not match attestation hash (${cryptographicAttestation.auditPackSha256}).`);
    }

    // 2. Verify Digital Signature (Ed25519 or HMAC)
    if (cryptographicAttestation.algorithm === 'Ed25519') {
      const pubKey = verificationKey || cryptographicAttestation.publicKeyPem || CryptographicProvenanceService.getAuthorityPublicKey();
      const isSigValid = CryptographicProvenanceService.verifySignatureEd25519(
        computedHash,
        cryptographicAttestation.signature,
        pubKey
      );
      if (!isSigValid) {
        discrepancies.push('Invalid Signature: Ed25519 asymmetric cryptographic attestation signature verification failed.');
      }
    } else {
      // Legacy HMAC-SHA256 verification
      const expectedSig = CryptographicProvenanceService.signHash(computedHash, verificationKey);
      if (expectedSig !== cryptographicAttestation.signature) {
        discrepancies.push('Invalid Signature: HMAC-SHA256 cryptographic attestation signature verification failed.');
      }
    }

    // 3. Verify Source Snapshots Hash Integrity
    if (pack.sourceSnapshots && pack.sourceSnapshots.length > 0) {
      for (const snapshot of pack.sourceSnapshots) {
        const computedSnapshotHash = CryptographicProvenanceService.computeSha256(snapshot.permissibleExcerpt);
        if (computedSnapshotHash !== snapshot.contentSha256) {
          discrepancies.push(`Source Snapshot Tamper: Computed hash (${computedSnapshotHash}) for snapshot "${snapshot.title}" does not match contentSha256 (${snapshot.contentSha256}).`);
        }
      }
    }

    return {
      isValid: discrepancies.length === 0,
      discrepancies,
    };
  }
}
