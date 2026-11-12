import * as crypto from 'crypto';
import { AuthorityKeyRecord, WellKnownKeySet } from '../types';
import { CryptographicProvenanceService } from './cryptographicProvenanceService';

/**
 * 🔑 Sovereign Authority Public-Key Discovery & Authenticity Service
 * 
 * Resolves Public-Key Authenticity for independent external auditors:
 * - Computes canonical SHA-256 fingerprints over public keys
 * - Serves RFC-compliant /.well-known/truthworld-keys.json key sets
 * - Enforces key rotation, historical verification key preservation, and revocation registries
 * - Prevents public-key substitution attacks where an adversary swaps both the pack and public key.
 */
export class KeyDiscoveryService {
  private static readonly AUTHORITY_DOMAIN = 'https://truthworld.ai';
  private static readonly WELL_KNOWN_ENDPOINT = '/.well-known/truthworld-keys.json';

  // In-memory authority keystore (persisted in production via Firestore system config)
  private static readonly KEY_STORE: Map<string, AuthorityKeyRecord> = new Map();
  private static activeKid: string = 'tw_authority_ed25519_2026_v1';

  static {
    // Initialize default primary authority key
    const primaryPubPem = CryptographicProvenanceService.getAuthorityPublicKey();
    const fingerprint = this.computePublicKeyFingerprint(primaryPubPem);

    const primaryRecord: AuthorityKeyRecord = {
      kid: this.activeKid,
      algorithm: 'Ed25519',
      publicKeyPem: primaryPubPem,
      publicKeyFingerprintSha256: fingerprint,
      status: 'active',
      validFrom: '2026-01-01T00:00:00Z',
      validUntil: '2028-01-01T00:00:00Z',
    };

    this.KEY_STORE.set(this.activeKid, primaryRecord);
  }

  /**
   * Compute the canonical SHA-256 fingerprint of an Ed25519 public key.
   * Strips PEM formatting headers and whitespace to hash raw key bytes.
   */
  public static computePublicKeyFingerprint(publicKeyPem: string): string {
    const rawKeyBase64 = publicKeyPem
      .replace(/-----BEGIN PUBLIC KEY-----/g, '')
      .replace(/-----END PUBLIC KEY-----/g, '')
      .replace(/\s+/g, '');
    const keyBuffer = Buffer.from(rawKeyBase64, 'base64');
    return crypto.createHash('sha256').update(keyBuffer).digest('hex');
  }

  /**
   * Return the authoritative public key set for external audit discovery (/.well-known/truthworld-keys.json).
   */
  public static getWellKnownKeySet(): WellKnownKeySet {
    const keys = Array.from(this.KEY_STORE.values());
    return {
      authority: this.AUTHORITY_DOMAIN,
      endpoint: `${this.AUTHORITY_DOMAIN}${this.WELL_KNOWN_ENDPOINT}`,
      publishedAt: new Date().toISOString(),
      keys,
    };
  }

  /**
   * Verify whether a given public key PEM genuinely belongs to TruthWorld's authoritative key set.
   */
  public static verifyKeyAuthenticity(publicKeyPem: string): {
    isAuthentic: boolean;
    keyRecord?: AuthorityKeyRecord;
    error?: string;
  } {
    const targetFingerprint = this.computePublicKeyFingerprint(publicKeyPem);

    for (const record of this.KEY_STORE.values()) {
      if (record.publicKeyFingerprintSha256 === targetFingerprint) {
        if (record.status === 'revoked') {
          return {
            isAuthentic: false,
            keyRecord: record,
            error: `Key ${record.kid} was formally REVOKED on ${record.revokedAt}: ${record.revocationReason}`,
          };
        }
        return {
          isAuthentic: true,
          keyRecord: record,
        };
      }
    }

    return {
      isAuthentic: false,
      error: `Unknown public key: fingerprint ${targetFingerprint} does not match any registered TruthWorld authority key.`,
    };
  }

  /**
   * Rotate authority signing key, preserving the previous key in historical deprecated state.
   */
  public static rotateAuthorityKey(newKeyPem?: string): AuthorityKeyRecord {
    const oldRecord = this.KEY_STORE.get(this.activeKid);
    if (oldRecord) {
      oldRecord.status = 'deprecated';
      oldRecord.validUntil = new Date().toISOString();
    }

    const keypair = CryptographicProvenanceService.generateEd25519KeyPair();
    const pubPem = newKeyPem || keypair.publicKeyPem;
    const newKid = `tw_authority_ed25519_${Date.now()}`;
    const fingerprint = this.computePublicKeyFingerprint(pubPem);

    const newRecord: AuthorityKeyRecord = {
      kid: newKid,
      algorithm: 'Ed25519',
      publicKeyPem: pubPem,
      publicKeyFingerprintSha256: fingerprint,
      status: 'active',
      validFrom: new Date().toISOString(),
      validUntil: new Date(Date.now() + 2 * 365 * 24 * 60 * 60 * 1000).toISOString(),
    };

    this.KEY_STORE.set(newKid, newRecord);
    this.activeKid = newKid;
    return newRecord;
  }

  /**
   * Formally revoke a compromised or retired key.
   */
  public static revokeKey(kid: string, reason: string): boolean {
    const record = this.KEY_STORE.get(kid);
    if (!record) return false;

    record.status = 'revoked';
    record.revokedAt = new Date().toISOString();
    record.revocationReason = reason;
    return true;
  }

  /**
   * Get the current active authority key record.
   */
  public static getActiveKey(): AuthorityKeyRecord {
    return this.KEY_STORE.get(this.activeKid)!;
  }
}
