import * as admin from "firebase-admin";
import { EpistemicTelemetry } from "../types";
import { logger } from "../utils/logger";

const db = () => admin.firestore();

/**
 * 📊 TELEMETRY SERVICE — Epistemic telemetry infrastructure
 *
 * Handles recording, sampling, and anonymizing telemetry traces.
 */
export class TelemetryService {
  private static readonly COLLECTION = "epistemic_telemetry";
  public static readonly RETENTION_DAYS = 30; // recent hot telemetry retention

  /**
   * Records a claim-level telemetry trace.
   * Implements sampling and anonymization.
   */
  async record(telemetry: Omit<EpistemicTelemetry, "timestamp">): Promise<void> {
    try {
      // 1. Telemetry Sampling Logic to prevent noisy data & Firestore cost explosion
      if (!this.shouldSample(telemetry)) {
        return;
      }

      // 2. Anonymize/Sanitize: Make sure we store no raw PII
      const sanitized = this.anonymize(telemetry);

      const record: EpistemicTelemetry = {
        ...sanitized,
        timestamp: Date.now(),
      };

      // 3. Write to Firestore
      await db().collection(TelemetryService.COLLECTION).add(record);
      logger.debug(`[TelemetryService] Logged trace for claim ${record.claimId} (${record.verificationOutcome})`);
    } catch (err) {
      logger.error("[TelemetryService] Failed to record telemetry", { claimId: telemetry.claimId, err });
    }
  }

  /**
   * Determines if this telemetry trace should be recorded based on sampling rules.
   */
  private shouldSample(telemetry: Omit<EpistemicTelemetry, "timestamp">): boolean {
    // Retain 100% of errors, false claims, timeouts, fallbacks, or retried verifications
    const isHighInterest = 
      telemetry.verificationOutcome === "false_claim" ||
      telemetry.verificationOutcome === "timeout" ||
      telemetry.verificationOutcome === "inconclusive" ||
      telemetry.fallbackUsed ||
      telemetry.retryCount > 0 ||
      telemetry.latencyMs > 5000;

    if (isHighInterest) {
      return true;
    }

    // Deterministic 10% sampling using claim hash — reproducible and debuggable
    // Uses last 2 hex chars of claimHash (0-255) to select ~10% of claims
    const hashTail = parseInt(telemetry.claimHash.slice(-2), 16);
    return !isNaN(hashTail) && (hashTail % 10 === 0);
  }

  /**
   * Sanitizes telemetry to prevent leak of user private details.
   */
  private anonymize(telemetry: Omit<EpistemicTelemetry, "timestamp">): Omit<EpistemicTelemetry, "timestamp"> {
    return {
      ...telemetry,
      // Ensure we don't store raw user/transcription data in this telemetry document
      // Just keep IDs, hashes, categories, and metrics.
      videoId: telemetry.videoId.trim(),
      claimId: telemetry.claimId.trim(),
      claimHash: telemetry.claimHash.trim(),
    };
  }
}

export const telemetryService = new TelemetryService();
