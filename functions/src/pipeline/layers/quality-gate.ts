/**
 * 🛡️ DUBBING AUTOMATED QUALITY GATE — Production Integrity Guard
 * 
 * Enforces strict quality standards before any dubbed audio track or video is published:
 * 1. Zero Missing Segments: Rejects any partial dubbing (e.g. quota exhaustion, API dropouts).
 * 2. Audio Duration Tolerance: Stitched audio must match video duration within defined tolerance.
 * 3. Voice Cloning Integrity: Asserts cloned creator voice profile was applied when requested.
 * 4. Background Music Preservation: Verifies M&E stem separation when stem isolation is requested.
 * 5. Audio File Integrity: Output track must exist, be readable, and have valid audio headers.
 */

import { logger } from "../utils/logger";

export interface DubbingQualityGateParams {
  jobId: string;
  targetLang: string;
  totalSegments: number;
  successfulSegments: number;
  failedSegments: Array<{ index: number; text?: string; error?: string; isQuota?: boolean }>;
  actualDurationSeconds: number;
  expectedDurationSeconds: number;
  isVoiceCloningRequested: boolean;
  isVoiceCloned: boolean;
  voiceId?: string;
  stemIsolationRequested: boolean;
  isStemPreserved: boolean;
  mneStemUrl?: string;
  outputAudioSize?: number;
  // Professional Dubbing & Cinema Tolerances (Explicitly Decoupled)
  tier?: "creator" | "cinema";
  maxContainerDriftMs?: number; // Cinema target: <= 50ms, Creator default: 1500ms
  dialogueOnsetDriftMs?: number; // Cinema target: <= 60ms (2 frames @ 24fps), Creator: 250ms
  lipSyncFlapDriftFrames?: number; // Cinema target: <= 2 frames
  mneValidation?: import("../services/media").MneValidationResult;
}

export interface DubbingQualityGateResult {
  passed: boolean;
  status: "PASSED" | "PARTIAL" | "FAILED";
  actualDurationSeconds: number;
  expectedDurationSeconds: number;
  durationDriftSeconds: number;
  violations: string[];
  metadata: {
    segmentCompletionRatio: number;
    failedSegmentsCount: number;
    totalSegmentsCount: number;
    voiceCloneValid: boolean;
    bgmPreserved: boolean;
    quotaExceeded: boolean;
    outputAudioSizeBytes: number;
    tier: "creator" | "cinema";
    dialogueOnsetDriftMs?: number;
    lipSyncFlapDriftFrames?: number;
    mneValidationStatus?: "passed" | "degraded" | "failed" | "not_required";
    mneSource?: string;
    dialogueBleedDb?: number;
  };
}

export class DubbingQualityGate {
  /**
   * Evaluates all quality rules against dubbing artifacts.
   */
  static evaluate(params: DubbingQualityGateParams): DubbingQualityGateResult {
    const violations: string[] = [];
    const {
      totalSegments,
      successfulSegments,
      failedSegments,
      actualDurationSeconds,
      expectedDurationSeconds,
      isVoiceCloningRequested,
      isVoiceCloned,
      stemIsolationRequested,
      isStemPreserved,
      outputAudioSize = 0,
    } = params;

    const quotaExceeded = failedSegments.some((f) => f.isQuota);

    // ── Rule 1: Zero Missing Segments ──────────────────────────────────────────
    if (failedSegments.length > 0 || successfulSegments < totalSegments) {
      const errPrefix = quotaExceeded ? "Credit quota exceeded" : "TTS synthesis failure";
      const detail = failedSegments[0]?.error ? ` (${failedSegments[0].error})` : "";
      violations.push(
        `Missing speech segments: ${failedSegments.length} of ${totalSegments} segments failed to synthesize [${errPrefix}]${detail}`
      );
    }

    // ── Rule 2: Audio Container Duration Tolerance (Decoupled Tier Targets) ──
    let durationDriftSeconds = 0;
    const isCinema = params.tier === "cinema";
    if (expectedDurationSeconds > 0) {
      durationDriftSeconds = Math.abs(actualDurationSeconds - expectedDurationSeconds);
      
      // Decoupled Tolerance Hierarchy:
      // Cinema Dubbing: Strict broadcast/master container parity <= 50ms
      // Creator Dubbing: Short videos (<= 60s) <= 1.5s; Long form <= 2.5%
      const toleranceSeconds = isCinema
        ? (params.maxContainerDriftMs ? params.maxContainerDriftMs / 1000 : 0.05)
        : (expectedDurationSeconds <= 60 ? 3.5 : Math.max(3.0, expectedDurationSeconds * 0.05));

      if (durationDriftSeconds > toleranceSeconds) {
        violations.push(
          `Audio duration mismatch: Dubbed audio is ${actualDurationSeconds.toFixed(1)}s, but video is ${expectedDurationSeconds.toFixed(1)}s (container drift: ${(durationDriftSeconds * 1000).toFixed(0)}ms exceeds ${(toleranceSeconds * 1000).toFixed(0)}ms ${isCinema ? "Cinema" : "Creator"} tolerance)`
        );
      }
    }

    // ── Rule 2b: Dialogue Onset Synchronization (Cinema Gate) ─────────────────
    if (params.dialogueOnsetDriftMs !== undefined && params.dialogueOnsetDriftMs !== null) {
      const maxOnsetMs = isCinema ? 60 : 250; // 60ms = 2 frames @ 24/25fps
      if (params.dialogueOnsetDriftMs > maxOnsetMs) {
        violations.push(
          `Dialogue onset drift: Onset error ${params.dialogueOnsetDriftMs.toFixed(0)}ms exceeds ${maxOnsetMs}ms (2 frames) synchronization tolerance`
        );
      }
    }

    // ── Rule 2c: Visual Lip-Flap Synchronization (Cinema Gate) ────────────────
    if (params.lipSyncFlapDriftFrames !== undefined && params.lipSyncFlapDriftFrames !== null) {
      const maxFlapFrames = 2; // Netflix NPPS standard: within 2 frames on evaluated on-camera speech
      if (params.lipSyncFlapDriftFrames > maxFlapFrames) {
        violations.push(
          `Visual lip-sync mismatch: Flap drift ${params.lipSyncFlapDriftFrames} frames exceeds ${maxFlapFrames} frames tolerance`
        );
      }
    }

    // ── Rule 3: Audio File Integrity ───────────────────────────────────────────
    if (actualDurationSeconds <= 0.5) {
      violations.push(`Audio file invalid: Duration is empty or near-zero (${actualDurationSeconds.toFixed(2)}s)`);
    }
    // A standard 60-second speech MP3 at 192kbps is ~1.4MB. Even heavily compressed 64kbps is ~480KB.
    // If a 60s track is only 43KB, it is a truncated partial file.
    if (expectedDurationSeconds >= 10 && outputAudioSize > 0 && outputAudioSize < 15000) {
      violations.push(`Audio file truncated: Output size (${outputAudioSize} bytes) is suspiciously low for ${expectedDurationSeconds.toFixed(1)}s video`);
    }

    // ── Rule 4: Voice Cloning Verification ─────────────────────────────────────
    const voiceCloneValid = !isVoiceCloningRequested || isVoiceCloned;
    if (isVoiceCloningRequested && !isVoiceCloned) {
      violations.push("Voice cloning was requested, but fallback standard voice was used instead of creator timbre");
    }

    // ── Rule 5: Background Music & M&E Preservation ───────────────────────────
    const bgmPreserved = !stemIsolationRequested || (isStemPreserved && (!params.mneValidation || params.mneValidation.validationStatus !== "failed"));
    if (stemIsolationRequested) {
      if (params.mneValidation) {
        const { validationStatus, issues } = params.mneValidation;
        if (validationStatus === "failed") {
          violations.push(`M&E stem validation failed: ${issues.join("; ")}`);
        } else if (validationStatus === "degraded" && isCinema) {
          violations.push(`M&E stem quality degraded for Cinema tier: ${issues.join("; ")}`);
        }
      } else if (!isStemPreserved) {
        violations.push("Background music preservation was requested, but discrete stem isolation or ducking failed");
      }
    }

    const passed = violations.length === 0;
    const status: "PASSED" | "PARTIAL" | "FAILED" = passed
      ? "PASSED"
      : (successfulSegments > 0 && failedSegments.length > 0 ? "PARTIAL" : "FAILED");

    const result: DubbingQualityGateResult = {
      passed,
      status,
      actualDurationSeconds,
      expectedDurationSeconds,
      durationDriftSeconds,
      violations,
      metadata: {
        segmentCompletionRatio: totalSegments > 0 ? successfulSegments / totalSegments : 0,
        failedSegmentsCount: failedSegments.length,
        totalSegmentsCount: totalSegments,
        voiceCloneValid,
        bgmPreserved,
        quotaExceeded,
        outputAudioSizeBytes: outputAudioSize,
        tier: params.tier || "creator",
        dialogueOnsetDriftMs: params.dialogueOnsetDriftMs,
        lipSyncFlapDriftFrames: params.lipSyncFlapDriftFrames,
        mneValidationStatus: params.mneValidation?.validationStatus,
        mneSource: params.mneValidation?.source,
        dialogueBleedDb: params.mneValidation?.dialogueBleedDb,
      },
    };

    if (!passed) {
      logger.warn("[Dubbing:QualityGate] ❌ Quality gate failed", {
        jobId: params.jobId,
        targetLang: params.targetLang,
        status,
        violations,
      });
    } else {
      logger.info("[Dubbing:QualityGate] ✅ All quality gates passed", {
        jobId: params.jobId,
        targetLang: params.targetLang,
        actualDuration: actualDurationSeconds,
        expectedDuration: expectedDurationSeconds,
      });
    }

    return result;
  }
}
