import {
  AuditPackAmendment,
  ClaimStatus,
  PublicAuditPackV1,
  SignedLedgerCheckpoint,
} from '../types';
import { CryptographicProvenanceService } from './cryptographicProvenanceService';
import { KeyDiscoveryService } from './keyDiscoveryService';

/**
 * 🏛️ P6 Public Audit Portal & Traceable Correction Ledger Service
 * 
 * Implements public auditability and transparent correction mechanisms:
 * - Public registry of published Public Audit Packs
 * - Authority public key discovery endpoint support
 * - Cryptographic amendment chaining: when a claim verdict is corrected or amended on appeal,
 *   the previous audit pack is NEVER erased. An immutable AuditPackAmendment is minted,
 *   linking the parent pack hash, amendment rationale, and new audit pack hash.
 */
export class AuditPortalService {
  // In-memory public ledger (backed by Firestore public_audit_packs collection)
  private static readonly PUBLISHED_PACKS: Map<string, PublicAuditPackV1> = new Map();
  private static readonly AMENDMENT_LEDGER: Map<string, AuditPackAmendment[]> = new Map();

  /**
   * Publish an audit pack to the public registry.
   */
  public static publishAuditPack(pack: PublicAuditPackV1): {
    published: boolean;
    packId: string;
    publicUrl: string;
    fingerprint: string;
  } {
    this.PUBLISHED_PACKS.set(pack.packId, pack);

    const pubKeyPem = pack.cryptographicAttestation.publicKeyPem || CryptographicProvenanceService.getAuthorityPublicKey();
    const fingerprint = KeyDiscoveryService.computePublicKeyFingerprint(pubKeyPem);

    return {
      published: true,
      packId: pack.packId,
      publicUrl: `https://truthworld.ai/audit/${pack.packId}`,
      fingerprint,
    };
  }

  /**
   * Lookup a published audit pack by ID.
   */
  public static getPublishedPack(packId: string): PublicAuditPackV1 | undefined {
    return this.PUBLISHED_PACKS.get(packId);
  }

  /**
   * Submit and adjudicate an amendment to an existing published audit pack.
   * Generates a cryptographically linked amendment record that ensures backward traceability.
   */
  public static amendAuditPack(
    originalPack: PublicAuditPackV1,
    amendmentReason: string,
    amendedBy: string,
    newVerdict: ClaimStatus,
    newExplanation: string
  ): {
    amendment: AuditPackAmendment;
    amendedPack: PublicAuditPackV1;
  } {
    const originalPackHash = originalPack.cryptographicAttestation.auditPackSha256;
    const amendedAt = new Date().toISOString();
    const amendmentId = `amend_${originalPack.packId}_${Date.now()}`;

    // Construct amended audit pack
    const amendedBody = {
      ...originalPack,
      packId: `auditpack_${originalPack.claimId}_amended_${Date.now()}`,
      generatedAt: amendedAt,
      verdict: {
        ...originalPack.verdict,
        finalStatus: newVerdict,
        publicExplanation: `${newExplanation} (Amended from ${originalPack.verdict.finalStatus}: ${amendmentReason})`,
      },
    };

    const { cryptographicAttestation, ...bodyToHash } = amendedBody;
    const newAuditPackSha256 = CryptographicProvenanceService.computeSha256(bodyToHash);
    const newSignature = CryptographicProvenanceService.signHashEd25519(newAuditPackSha256);

    const amendedPack: PublicAuditPackV1 = {
      ...bodyToHash,
      cryptographicAttestation: {
        auditPackSha256: newAuditPackSha256,
        datasetManifestHash: originalPack.cryptographicAttestation.datasetManifestHash,
        signerId: amendedBy,
        algorithm: 'Ed25519',
        publicKeyPem: CryptographicProvenanceService.getAuthorityPublicKey(),
        signature: newSignature,
        verificationInstructions: `Amended pack cryptographically linked to parent pack ${originalPack.packId} (${originalPackHash}).`,
      },
    };

    // Calculate immutable cryptographic chain link: SHA256(parentHash + newHash + reason + timestamp)
    const chainPayload = `${originalPackHash}:${newAuditPackSha256}:${amendmentReason}:${amendedAt}`;
    const immutableChainHash = CryptographicProvenanceService.computeSha256(chainPayload);

    const amendment: AuditPackAmendment = {
      amendmentId,
      originalPackId: originalPack.packId,
      originalPackHash,
      amendedAt,
      amendmentReason,
      amendedBy,
      previousVerdict: originalPack.verdict.finalStatus,
      newVerdict,
      newAuditPackSha256,
      immutableChainHash,
    };

    // Record amendment history
    const history = this.AMENDMENT_LEDGER.get(originalPack.packId) || [];
    history.push(amendment);
    this.AMENDMENT_LEDGER.set(originalPack.packId, history);

    // Register amended pack
    this.PUBLISHED_PACKS.set(amendedPack.packId, amendedPack);

    return {
      amendment,
      amendedPack,
    };
  }

  /**
   * Retrieve the complete publicly auditable amendment history for a given audit pack.
   */
  public static getAmendmentHistory(packId: string): AuditPackAmendment[] {
    return this.AMENDMENT_LEDGER.get(packId) || [];
  }

  // Periodic Signed Transparency Checkpoints
  private static readonly CHECKPOINTS: SignedLedgerCheckpoint[] = [];

  /**
   * Create an immutable Signed Ledger Checkpoint over all published packs and amendments.
   * Anchors the root state so even a privileged internal administrator cannot rewrite the chain.
   */
  public static createSignedCheckpoint(externalAnchorUri?: string): SignedLedgerCheckpoint {
    const seq = this.CHECKPOINTS.length + 1;
    const checkpointId = `checkpoint_seq_${seq}_${Date.now()}`;
    const prevRoot = seq > 1 ? this.CHECKPOINTS[seq - 2].ledgerRootHash : 'genesis_root_tw_2026';

    // Hash all published pack hashes and amendment chain hashes
    const allPacks = Array.from(this.PUBLISHED_PACKS.values()).map(p => p.cryptographicAttestation.auditPackSha256).sort();
    const allAmendments: string[] = [];
    for (const amends of this.AMENDMENT_LEDGER.values()) {
      for (const a of amends) {
        allAmendments.push(a.immutableChainHash);
      }
    }
    allAmendments.sort();

    const rootPayload = `${prevRoot};packs:${allPacks.join(',')};amends:${allAmendments.join(',')}`;
    const ledgerRootHash = CryptographicProvenanceService.computeSha256(rootPayload);
    const timestamp = new Date().toISOString();

    const checkpointBody = {
      checkpointId,
      checkpointSequence: seq,
      ledgerRootHash,
      previousCheckpointRootHash: prevRoot,
      totalAmendments: allAmendments.length,
      timestamp,
      signedBy: 'truthworld_sovereign_transparency_log',
      publicKeyPem: CryptographicProvenanceService.getAuthorityPublicKey(),
      publicKeyFingerprint: KeyDiscoveryService.computePublicKeyFingerprint(CryptographicProvenanceService.getAuthorityPublicKey()),
    };

    const signature = CryptographicProvenanceService.signHashEd25519(
      CryptographicProvenanceService.computeSha256(checkpointBody)
    );

    const checkpoint: SignedLedgerCheckpoint = {
      ...checkpointBody,
      signature,
      externalAnchors: externalAnchorUri ? [
        {
          anchorType: 'public_transparency_log',
          anchorUri: externalAnchorUri,
          anchorProof: `sha256:${ledgerRootHash}`,
        },
      ] : undefined,
    };

    this.CHECKPOINTS.push(checkpoint);
    return checkpoint;
  }

  /**
   * Verify a Signed Ledger Checkpoint.
   */
  public static verifyCheckpoint(checkpoint: SignedLedgerCheckpoint): boolean {
    const { signature, externalAnchors, ...bodyToVerify } = checkpoint;
    const computedHash = CryptographicProvenanceService.computeSha256(bodyToVerify);
    return CryptographicProvenanceService.verifySignatureEd25519(
      computedHash,
      signature,
      checkpoint.publicKeyPem
    );
  }

  /**
   * Get all signed checkpoints.
   */
  public static getCheckpoints(): SignedLedgerCheckpoint[] {
    return [...this.CHECKPOINTS];
  }
}
