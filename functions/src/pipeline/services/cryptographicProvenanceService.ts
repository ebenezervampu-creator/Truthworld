import * as crypto from 'crypto';
import { CryptographicProvenanceRecord, DatasetIntegrityManifest } from '../types';

/**
 * 🔐 Cryptographic Provenance & Independent Integrity Service (Ed25519 Hardened)
 * 
 * Provides deterministic, tamper-evident cryptographic primitives:
 * - Canonical deterministic JSON serialization (RFC 8785 subset)
 * - SHA-256 cryptographic content hashing
 * - Asymmetric Ed25519 digital signatures (PureEdDSA) for public independent verification
 * - Merkle / Manifest verification ensuring that any single-byte mutation
 *   in any claim immediately breaks cryptographic verification.
 * 
 * Epistemic Note:
 * Cryptographic signatures establish non-repudiation and document integrity (that a
 * specific authority verified and signed a record at a given point in time without subsequent alteration).
 * They do not replace empirical truth, but ensure accountability and reproducibility.
 */
export class CryptographicProvenanceService {
  private static readonly DEFAULT_AUDIT_SECRET = 'truthworld_sovereign_audit_key_prod_2026';

  // Institutional Authority Ed25519 Keypair (Supports Secret Manager / Environment Injection)
  private static initAuthorityKeyPair(): {
    publicKey: crypto.KeyObject;
    privateKey: crypto.KeyObject;
    publicKeyPem: string;
    privateKeyPem: string;
  } {
    try {
      const envPrivateKeyPem = process.env.AUDIT_AUTHORITY_PRIVATE_KEY_PEM;
      if (envPrivateKeyPem && envPrivateKeyPem.trim().length > 0) {
        const privateKey = crypto.createPrivateKey(envPrivateKeyPem);
        const publicKey = crypto.createPublicKey(privateKey);
        return {
          publicKey,
          privateKey,
          publicKeyPem: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
          privateKeyPem: envPrivateKeyPem,
        };
      }
    } catch {
      // Fallback cleanly to internal key generation on secret parse failure
    }
    const generated = crypto.generateKeyPairSync('ed25519');
    return {
      publicKey: generated.publicKey,
      privateKey: generated.privateKey,
      publicKeyPem: generated.publicKey.export({ type: 'spki', format: 'pem' }).toString(),
      privateKeyPem: generated.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
    };
  }

  private static _authorityData = CryptographicProvenanceService.initAuthorityKeyPair();
  private static _authorityKeyPair = {
    publicKey: CryptographicProvenanceService._authorityData.publicKey,
    privateKey: CryptographicProvenanceService._authorityData.privateKey,
  };
  private static _authorityPublicKeyPem: string = CryptographicProvenanceService._authorityData.publicKeyPem;
  private static _authorityPrivateKeyPem: string = CryptographicProvenanceService._authorityData.privateKeyPem;

  /**
   * Retrieves active authority Key ID for versioning and rotation tracking.
   */
  public static getAuthorityKeyId(): string {
    return process.env.AUDIT_AUTHORITY_KEY_ID || 'tw-ed25519-v1';
  }

  /**
   * Deterministic canonical JSON serialization (RFC 8785 standard subset).
   * - Normalizes negative zero (-0 -> 0)
   * - Lexicographically sorts object keys by UTF-16 code units
   * - Filters undefined properties consistently across memory and disk representations
   */
  public static canonicalStringify(obj: any): string {
    if (obj === null) {
      return 'null';
    }
    if (typeof obj === 'number') {
      if (Object.is(obj, -0)) return '0';
      if (!Number.isFinite(obj)) return 'null';
      return obj.toString();
    }
    if (typeof obj === 'boolean') {
      return obj ? 'true' : 'false';
    }
    if (typeof obj === 'string') {
      return JSON.stringify(obj);
    }
    if (typeof obj !== 'object') {
      return JSON.stringify(obj);
    }
    if (Array.isArray(obj)) {
      return '[' + obj.map(item => (item === undefined || typeof item === 'function' || typeof item === 'symbol' ? 'null' : this.canonicalStringify(item))).join(',') + ']';
    }
    const sortedKeys = Object.keys(obj)
      .filter(k => obj[k] !== undefined && typeof obj[k] !== 'function' && typeof obj[k] !== 'symbol')
      .sort();
    const parts = sortedKeys.map(k => `${JSON.stringify(k)}:${this.canonicalStringify(obj[k])}`);
    return '{' + parts.join(',') + '}';
  }

  /**
   * Compute SHA-256 hash of an arbitrary object using canonical serialization.
   */
  public static computeSha256(data: any): string {
    const canonicalText = typeof data === 'string' ? data : this.canonicalStringify(data);
    return crypto.createHash('sha256').update(canonicalText, 'utf8').digest('hex');
  }

  /**
   * Generate a new independent Ed25519 keypair for external auditors or specialized authorities.
   */
  public static generateEd25519KeyPair(): { publicKeyPem: string; privateKeyPem: string } {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
    return {
      publicKeyPem: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
      privateKeyPem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
    };
  }

  /**
   * Retrieve the institutional public verification key (PEM format).
   * External auditors use this key to verify signatures without access to the private signing key.
   */
  public static getAuthorityPublicKey(): string {
    return this._authorityPublicKeyPem;
  }

  /**
   * Retrieve the institutional private signing key (PEM format) - internal only.
   */
  public static getAuthorityPrivateKey(): string {
    return this._authorityPrivateKeyPem;
  }

  /**
   * Asymmetric signature generation using Ed25519.
   * Signs the data buffer using the private key.
   */
  public static signHashEd25519(hashOrData: string, privateKeyPem?: string): string {
    const privKey = privateKeyPem
      ? crypto.createPrivateKey(privateKeyPem)
      : this._authorityKeyPair.privateKey;
    const signatureBuffer = crypto.sign(null, Buffer.from(hashOrData, 'utf8'), privKey);
    return signatureBuffer.toString('hex');
  }

  /**
   * Asymmetric signature verification using Ed25519.
   * Any independent third party can verify without the private signing key.
   */
  public static verifySignatureEd25519(hashOrData: string, signatureHex: string, publicKeyPem?: string): boolean {
    try {
      const pubKey = publicKeyPem
        ? crypto.createPublicKey(publicKeyPem)
        : this._authorityKeyPair.publicKey;
      return crypto.verify(
        null,
        Buffer.from(hashOrData, 'utf8'),
        pubKey,
        Buffer.from(signatureHex, 'hex')
      );
    } catch {
      return false;
    }
  }

  /**
   * Legacy symmetric HMAC-SHA256 signature over a payload hash (retained for backward compatibility).
   */
  public static signHash(hash: string, secretKey: string = this.DEFAULT_AUDIT_SECRET): string {
    return crypto.createHmac('sha256', secretKey).update(hash, 'utf8').digest('hex');
  }

  /**
   * Create a signed cryptographic provenance record for a benchmark claim.
   * Uses asymmetric Ed25519 digital signatures.
   */
  public static createProvenanceRecord(
    recordId: string,
    payload: any,
    signerId: string = 'audit_authority_truthworld_main',
    privateKeyPem?: string
  ): CryptographicProvenanceRecord {
    const payloadHash = this.computeSha256(payload);
    const signature = this.signHashEd25519(payloadHash, privateKeyPem);

    return {
      recordId,
      payloadHash,
      signature,
      signerId,
      publicKeyPem: this.getAuthorityPublicKey(),
      timestamp: new Date().toISOString(),
      algorithm: 'Ed25519',
      isTamperEvident: true,
    };
  }

  /**
   * Verify that a record has not been mutated and matches its cryptographic signature.
   */
  public static verifyRecordIntegrity(
    payload: any,
    provenance: CryptographicProvenanceRecord,
    verificationKey?: string
  ): boolean {
    const computedHash = this.computeSha256(payload);
    if (computedHash !== provenance.payloadHash) {
      return false; // Payload was mutated
    }

    if (provenance.algorithm === 'Ed25519') {
      const pubKey = verificationKey || provenance.publicKeyPem || this.getAuthorityPublicKey();
      return this.verifySignatureEd25519(computedHash, provenance.signature, pubKey);
    }

    // Fallback for legacy HMAC-SHA256 records
    const secret = verificationKey || this.DEFAULT_AUDIT_SECRET;
    const expectedSignature = this.signHash(computedHash, secret);
    return expectedSignature === provenance.signature;
  }

  /**
   * Generate a tamper-evident Dataset Integrity Manifest over a complete benchmark corpus.
   * Signs the manifest content hash with asymmetric Ed25519.
   */
  public static generateDatasetManifest(
    dataset: Array<{ id: string; [key: string]: any }>,
    datasetVersion: string,
    datasetName: string = 'truthworld_gold_standard',
    signerId: string = 'audit_authority_truthworld_main',
    privateKeyPem?: string
  ): DatasetIntegrityManifest {
    const recordHashes: Record<string, string> = {};

    for (const record of dataset) {
      recordHashes[record.id] = this.computeSha256(record);
    }

    // Sort record IDs to ensure deterministic content hash
    const sortedRecordHashes = Object.keys(recordHashes)
      .sort()
      .map(k => `${k}:${recordHashes[k]}`)
      .join(';');

    const datasetContentHash = this.computeSha256(sortedRecordHashes);
    const signature = this.signHashEd25519(datasetContentHash, privateKeyPem);

    return {
      manifestId: `manifest_${datasetVersion}_${Date.now()}`,
      datasetVersion,
      datasetName,
      totalRecords: dataset.length,
      datasetContentHash,
      recordHashes,
      createdAt: new Date().toISOString(),
      signedBy: signerId,
      signature,
      publicKeyPem: this.getAuthorityPublicKey(),
      algorithm: 'Ed25519',
    };
  }

  /**
   * Verify that a dataset exactly matches its signed manifest using the public verification key.
   */
  public static verifyDatasetManifest(
    manifest: DatasetIntegrityManifest,
    dataset: Array<{ id: string; [key: string]: any }>,
    publicKeyPem?: string
  ): { isValid: boolean; discrepancies: string[] } {
    const discrepancies: string[] = [];

    if (dataset.length !== manifest.totalRecords) {
      discrepancies.push(`Record count mismatch: manifest expected ${manifest.totalRecords}, found ${dataset.length}.`);
    }

    // Verify manifest signature with public key
    const pubKey = publicKeyPem || manifest.publicKeyPem || this.getAuthorityPublicKey();
    const isSigValid = manifest.algorithm === 'HMAC-SHA256'
      ? (this.signHash(manifest.datasetContentHash, publicKeyPem || this.DEFAULT_AUDIT_SECRET) === manifest.signature)
      : this.verifySignatureEd25519(manifest.datasetContentHash, manifest.signature, pubKey);

    if (!isSigValid) {
      discrepancies.push('Manifest signature is invalid or has been forged.');
    }

    // Verify individual record hashes
    for (const record of dataset) {
      const expectedHash = manifest.recordHashes[record.id];
      if (!expectedHash) {
        discrepancies.push(`Unknown or unlisted record ID found in dataset: ${record.id}`);
        continue;
      }
      const actualHash = this.computeSha256(record);
      if (actualHash !== expectedHash) {
        discrepancies.push(`Tamper detected in record ${record.id}: computed hash ${actualHash} !== manifest ${expectedHash}`);
      }
    }

    return {
      isValid: discrepancies.length === 0,
      discrepancies,
    };
  }
}
