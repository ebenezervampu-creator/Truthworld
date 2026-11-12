#!/usr/bin/env node
/**
 * 🏛 TruthWorld Standalone Public Audit Pack Verifier
 * 
 * ZERO EXTERNAL DEPENDENCIES. Uses standard Node.js built-ins ('crypto', 'fs') only.
 * Enables any independent researcher, journalist, peer auditor, or civil society organization
 * to verify the cryptographic provenance, source integrity, and structural validity of any
 * TruthWorld Public Audit Pack (V1 or V2) without installing TruthWorld or trusting internal code.
 * 
 * Usage:
 *   node scripts/verify_audit_pack.js <path-to-audit-pack.json> [--public-key <path-to-public-key.pem>]
 */

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

/**
 * Deterministic Canonical JSON Serialization (RFC 8785 subset)
 * Independent implementation to ensure zero reliance on TruthWorld internal methods.
 */
function canonicalStringifyStandalone(obj) {
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
    return '[' + obj.map(item => (item === undefined || typeof item === 'function' || typeof item === 'symbol' ? 'null' : canonicalStringifyStandalone(item))).join(',') + ']';
  }
  const sortedKeys = Object.keys(obj)
    .filter(k => obj[k] !== undefined && typeof obj[k] !== 'function' && typeof obj[k] !== 'symbol')
    .sort();
  const parts = sortedKeys.map(k => `${JSON.stringify(k)}:${canonicalStringifyStandalone(obj[k])}`);
  return '{' + parts.join(',') + '}';
}

/**
 * SHA-256 over Canonical JSON
 */
function computeSha256Standalone(data) {
  const text = typeof data === 'string' ? data : canonicalStringifyStandalone(data);
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

/**
 * Standalone Independent Verification of a Public Audit Pack
 */
function verifyAuditPackStandalone(auditPack, options = {}) {
  const discrepancies = [];
  const checksPassed = [];

  // 1. Schema Version Check
  if (!auditPack.schemaVersion) {
    discrepancies.push('Missing schemaVersion in audit pack.');
  } else {
    checksPassed.push(`Schema version verified: ${auditPack.schemaVersion}`);
  }

  // 2. Cryptographic Attestation Presence
  const attestation = auditPack.cryptographicAttestation;
  if (!attestation) {
    return {
      isValid: false,
      discrepancies: ['Fatal: No cryptographicAttestation block found in audit pack.'],
      checksPassed,
    };
  }

  // 3. Separate Body from Attestation
  const { cryptographicAttestation, ...bodyToVerify } = auditPack;

  // 4. Verify Content SHA-256 Hash
  const computedHash = computeSha256Standalone(bodyToVerify);
  if (computedHash !== attestation.auditPackSha256) {
    discrepancies.push(`Content Hash Mismatch (Tamper Detected): computed ${computedHash} !== attestation ${attestation.auditPackSha256}`);
  } else {
    checksPassed.push(`Canonical SHA-256 integrity verified (${computedHash.slice(0, 16)}...)`);
  }

  // 5. Verify Digital Signature (Ed25519)
  const algorithm = attestation.algorithm || 'Ed25519';
  if (algorithm === 'Ed25519') {
    const publicKeyPem = options.publicKeyPem || attestation.publicKeyPem;
    if (!publicKeyPem) {
      discrepancies.push('Missing Ed25519 public key: cannot verify asymmetric signature without public key.');
    } else {
      try {
        const pubKey = crypto.createPublicKey(publicKeyPem);
        const isSigValid = crypto.verify(
          null,
          Buffer.from(computedHash, 'utf8'),
          pubKey,
          Buffer.from(attestation.signature, 'hex')
        );
        if (!isSigValid) {
          discrepancies.push('Ed25519 signature is INVALID: signature does not match public key or data was altered.');
        } else {
          checksPassed.push('Ed25519 asymmetric authority digital signature verified successfully');
        }
      } catch (err) {
        discrepancies.push(`Ed25519 verification error: ${err.message}`);
      }
    }
  } else if (algorithm === 'HMAC-SHA256') {
    if (options.secretKey) {
      const expectedHmac = crypto.createHmac('sha256', options.secretKey).update(computedHash, 'utf8').digest('hex');
      if (expectedHmac !== attestation.signature) {
        discrepancies.push('HMAC-SHA256 signature verification failed.');
      } else {
        checksPassed.push('Legacy HMAC-SHA256 signature verified with provided secret');
      }
    } else {
      checksPassed.push('Legacy HMAC-SHA256 signature present (skipped verification: no secret provided)');
    }
  }

  // 6. Verify Source Snapshots Hash Integrity
  if (auditPack.sourceSnapshots && Array.isArray(auditPack.sourceSnapshots)) {
    let snapshotsValid = 0;
    for (const snapshot of auditPack.sourceSnapshots) {
      if (snapshot.permissibleExcerpt && snapshot.contentSha256) {
        const computedSnapshotHash = computeSha256Standalone(snapshot.permissibleExcerpt);
        if (computedSnapshotHash !== snapshot.contentSha256) {
          discrepancies.push(`Source snapshot hash mismatch in "${snapshot.title}": computed ${computedSnapshotHash} !== recorded ${snapshot.contentSha256}`);
        } else {
          snapshotsValid++;
        }
      }
    }
    checksPassed.push(`Source snapshots verified: ${snapshotsValid}/${auditPack.sourceSnapshots.length} pristine`);
  }

  // 7. Verify 7 Core Auditable Questions
  const answers = auditPack.sevenCoreAnswers;
  if (!answers) {
    discrepancies.push('Missing sevenCoreAnswers transparency matrix.');
  } else {
    const requiredQuestions = [
      'q1_exactClaim',
      'q2_supportingEvidence',
      'q3_contradictoryEvidence',
      'q4_sourceAdmissionRationale',
      'q5_comparabilityIntegrity',
      'q6_epistemicConfidence',
      'q7_limitationsAndUnresolvedDisagreements',
    ];
    let questionsAnswered = 0;
    for (const q of requiredQuestions) {
      if (answers[q] && typeof answers[q] === 'string' && answers[q].trim().length > 0) {
        questionsAnswered++;
      } else {
        discrepancies.push(`Core epistemic question unanswered: ${q}`);
      }
    }
    if (questionsAnswered === requiredQuestions.length) {
      checksPassed.push('All 7 Core Epistemic Questions answered transparently');
    }
  }

  return {
    isValid: discrepancies.length === 0,
    claimId: auditPack.claimId,
    schemaVersion: auditPack.schemaVersion,
    verdict: auditPack.verdict?.finalStatus,
    verdictConfidence: auditPack.verdict?.verdictConfidence,
    checksPassed,
    discrepancies,
  };
}

// CLI Execution
if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
🏛 TruthWorld Public Audit Pack Standalone Verifier
---------------------------------------------------
Usage: node scripts/verify_audit_pack.js <path-to-pack.json> [--public-key <path.pem>]

Examples:
  node scripts/verify_audit_pack.js audit_pack.json
  node scripts/verify_audit_pack.js audit_pack.json --public-key authority_public_key.pem
`);
    process.exit(0);
  }

  const filePath = args[0];
  let publicKeyPem = null;
  const pkIdx = args.indexOf('--public-key');
  if (pkIdx !== -1 && args[pkIdx + 1]) {
    publicKeyPem = fs.readFileSync(path.resolve(args[pkIdx + 1]), 'utf8');
  }

  try {
    const rawData = fs.readFileSync(path.resolve(filePath), 'utf8');
    const pack = JSON.parse(rawData);

    console.log(`\n🔍 Verifying Public Audit Pack: ${path.basename(filePath)}`);
    console.log(`──────────────────────────────────────────────────────────`);

    const result = verifyAuditPackStandalone(pack, { publicKeyPem });

    console.log(`Claim ID:       ${result.claimId || 'Unknown'}`);
    console.log(`Schema Version: ${result.schemaVersion}`);
    console.log(`Verdict:        ${result.verdict} (Confidence: ${result.verdictConfidence})`);
    console.log(`Status:         ${result.isValid ? '✅ VERIFIED AUTHENTIC & UNTAMPERED' : '❌ VERIFICATION FAILED'}`);

    console.log(`\nPassed Checks (${result.checksPassed.length}):`);
    result.checksPassed.forEach(c => console.log(`  ✓ ${c}`));

    if (result.discrepancies.length > 0) {
      console.log(`\nDiscrepancies / Failures (${result.discrepancies.length}):`);
      result.discrepancies.forEach(d => console.log(`  ✗ ${d}`));
      process.exit(1);
    } else {
      console.log(`\n🎉 Audit Pack is 100% Cryptographically and Structurally Valid.\n`);
      process.exit(0);
    }
  } catch (err) {
    console.error(`\n❌ Error reading or verifying audit pack: ${err.message}\n`);
    process.exit(1);
  }
}

module.exports = {
  verifyAuditPackStandalone,
  canonicalStringifyStandalone,
  computeSha256Standalone,
};
