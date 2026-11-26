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
import { blockOnTranslationErrorsEnabled } from "../services/translation-flags";

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
  tier?: "creator" | "cinema" | "audio_track";
  maxContainerDriftMs?: number; // Cinema target: <= 50ms, Creator default: 1500ms
  dialogueOnsetDriftMs?: number; // Cinema target: <= 60ms (2 frames @ 24fps), Creator: 250ms
  segmentCollisionsCount?: number; // Count of overlapping turns (speech end > next speech start)
  outroSpeechTruncated?: boolean; // True if speech active within 120ms of container end without margin
  trueSpeechEndMs?: number; // Pre-fade, post-tempo true waveform end timestamp (ms)
  containerDurationMs?: number; // Total container duration (ms)
  mneValidation?: import("../services/media").MneValidationResult;
  translatedSegments?: Array<{ original?: string; translated?: string; text?: string; translatedText?: string }>;
  translatedTexts?: string[];
  /** Findings from measuring the dub against the original (dub-sync-check.ts syncViolations). */
  syncViolations?: string[];
  /** Lines that still failed number, polarity, or meaning checks after repair (Fix 2.3). */
  translationBlockedLines?: Array<{ index: number; reason: string; source: string; text: string }>;
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
    tier: "creator" | "cinema" | "audio_track";
    dialogueOnsetDriftMs?: number;
    segmentCollisionsCount?: number;
    outroSpeechTruncated?: boolean;
    trueSpeechEndMs?: number;
    containerDurationMs?: number;
    mneValidationStatus?: "passed" | "degraded" | "failed" | "not_required";
    mneSource?: string;
    dialogueBleedDb?: number;
  };
}

/**
 * Violations that mean the creator would receive a broken track, so no tier may publish it (A4):
 * missing lines, a track much shorter or longer than the video, speech out of sync, or an
 * empty / truncated file. Other violations (voice-clone fallback, background stem quality, tail
 * margin, turn overlaps, translation wording checks) stay warnings for the audio-track tier.
 */
export const BLOCKING_VIOLATION_PREFIXES = [
  "Missing speech segments",
  "Audio duration mismatch",
  "Dialogue onset drift",
  "Audio file invalid",
  "Audio file truncated",
  // Measured against the original audio (dub-sync-check.ts), 2026-11-24.
  "Dubbed speech missing",
  "Voice gender mismatch",
  "Translation meaning error",
] as const;

export function isBlockingViolation(violation: string): boolean {
  if (violation.startsWith("Translation meaning error") && !blockOnTranslationErrorsEnabled()) {
    return false;
  }
  return BLOCKING_VIOLATION_PREFIXES.some((p) => violation.startsWith(p));
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

    // ── Rule 0: the dub measured against the original (missing lines, wrong-gender voice) ──
    for (const v of params.syncViolations || []) violations.push(v);

    // ── Rule 0b: Unresolved translation meaning / polarity / number errors (Fix 2.3) ──
    for (const b of params.translationBlockedLines || []) {
      violations.push(
        `Translation meaning error: line ${b.index + 1} (${b.reason}): "${b.source}" → "${b.text}"`
      );
    }

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
      // Cinema Dubbing & Precision Dialogue: Strict container parity <= 50ms
      // Audio Track Tier: Generous tolerance (up to 10s or 10%) to accommodate natural dialogue pauses or outro silence
      // Creator Dubbing: Precision short-form container drift <= 50ms (or maxContainerDriftMs); Long form <= 5%
      const toleranceSeconds = isCinema || (params.maxContainerDriftMs !== undefined && params.maxContainerDriftMs <= 50)
        ? (params.maxContainerDriftMs ? params.maxContainerDriftMs / 1000 : 0.05)
        : (params.tier === "audio_track"
            ? Math.max(5.0, expectedDurationSeconds * 0.10)
            : (expectedDurationSeconds <= 60 ? (params.maxContainerDriftMs ? params.maxContainerDriftMs / 1000 : 0.05) : Math.max(3.0, expectedDurationSeconds * 0.05)));

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

    // ── Rule 2c: Per-Segment Envelope Collision Check ─────────────────────────
    if (params.segmentCollisionsCount !== undefined && params.segmentCollisionsCount > 0) {
      violations.push(
        `Dialogue turn collision: ${params.segmentCollisionsCount} segments exceed permissible window and overlap consecutive speech turns`
      );
    }

    // ── Rule 2d: True Waveform Outro Completion Check (Pre-Fade Guard) ─────────
    const minRequiredTailSilenceMs = 120;
    if (params.trueSpeechEndMs !== undefined && params.containerDurationMs !== undefined) {
      if (params.trueSpeechEndMs > params.containerDurationMs - minRequiredTailSilenceMs) {
        violations.push(
          `Final speech ends at ${params.trueSpeechEndMs}ms, violating ${minRequiredTailSilenceMs}ms tail margin before ${params.containerDurationMs}ms EOF`
        );
      }
    } else if (params.outroSpeechTruncated) {
      violations.push(
        "Outro speech truncated: Active speech continues within 120ms of container end without sufficient tail margin"
      );
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
    const isStrictStem = isCinema || params.tier === undefined;
    const bgmPreserved = !stemIsolationRequested || (isStemPreserved && (!params.mneValidation || params.mneValidation.validationStatus !== "failed"));
    if (stemIsolationRequested) {
      if (params.mneValidation) {
        const { validationStatus, issues } = params.mneValidation;
        if (validationStatus === "failed") {
          if (isStrictStem) {
            violations.push(`M&E stem validation failed: ${issues.join("; ")}`);
          } else {
            logger.warn("[Dubbing:QualityGate] M&E stem degraded/fallback for audio track tier — proceeding with dialogue master:", issues);
          }
        } else if (validationStatus === "degraded" && isCinema) {
          violations.push(`M&E stem quality degraded for Cinema tier: ${issues.join("; ")}`);
        }
      } else if (!isStemPreserved) {
        if (isStrictStem) {
          violations.push("Background music preservation was requested, but discrete stem isolation or ducking failed");
        } else {
          logger.warn("[Dubbing:QualityGate] Discrete stem isolation unavailable for audio track tier — proceeding with dialogue master");
        }
      }
    }

    // ── Rule 6: Lexical & Theological Quality Gate Checks ───────────────────
    if (params.targetLang === "te") {
      const textsToCheck: string[] = [];
      if (params.translatedTexts) {
        textsToCheck.push(...params.translatedTexts);
      }
      if (params.translatedSegments) {
        textsToCheck.push(...params.translatedSegments.map((s) => s.translatedText || s.translated || s.text || ""));
      }
      for (const t of textsToCheck) {
        if (!t) continue;
        if (/సారి\s*చే|సారి\s*దిద్ద/i.test(t)) {
          violations.push(
            `Prohibited Telugu mistranslation detected: "సారి చేస్తుంది" found in dubbing text. Must use short స "సరిచేస్తోంది" / "సరిచేస్తున్నారు".`
          );
          break;
        }
        if (/మరియు\s+కానీ/i.test(t)) {
          violations.push(
            `Prohibited grammatical drift detected: redundant "మరియు కానీ" in Telugu dubbing text.`
          );
          break;
        }
        if (/\b\d{1,3}\s*:\s*\d{1,3}\b/.test(t)) {
          violations.push(
            `Unexpanded scripture citation detected in Telugu dubbing text: raw ":" character will vocalize as "colon". Must normalize via normalizeScriptureCitationsForTts.`
          );
          break;
        }
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
        segmentCollisionsCount: params.segmentCollisionsCount,
        outroSpeechTruncated: params.outroSpeechTruncated,
        trueSpeechEndMs: params.trueSpeechEndMs,
        containerDurationMs: params.containerDurationMs,
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
