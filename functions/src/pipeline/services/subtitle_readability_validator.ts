/**
 * 🛡️ SUBTITLE READABILITY & QUALITY VALIDATOR
 *
 * Implements automated validation checks across subtitle tracks (SRT / WebVTT / JSON):
 * - Timing monotonicity & syntax (start < end, non-negative)
 * - Cue overlap detection
 * - Inter-cue gap verification (prevents redraw flicker)
 * - Duration boundaries (minimum and maximum display time)
 * - Reading speed thresholds (Characters Per Second - CPS)
 * - Line length limits (Characters Per Line - CPL)
 * - Unicode & linguistic integrity (no entities, no replacement chars, no orphan cues)
 */

import { SubtitleLanguageProfile, getSubtitleProfile, getGraphemeCount } from "./subtitle_language_profiles";

export interface LocalizedSubtitleCue {
  id: number;
  languageCode: string;
  text: string;
  startMs: number;
  endMs: number;
  durationMs: number;
  sourceWordStartIndex: number;
  sourceWordEndIndex: number;
  charactersPerSecond: number;
  charactersPerLine: number;
  alignmentConfidence: number;
  validationStatus: "pass" | "warning" | "review";
  speaker?: string;
  lines?: string[];
}

export interface SubtitleValidationReport {
  languageCode: string;
  totalCues: number;
  status: "pass" | "warning" | "review";
  isValidSyntax: boolean;
  hasOverlaps: boolean;
  maxCps: number;
  avgCps: number;
  minDurationMs: number;
  maxDurationMs: number;
  warnings: string[];
  errors: string[];
  reviewRequired: boolean;
}

export class SubtitleReadabilityValidator {
  /**
   * Validates an entire subtitle track against language-specific standards.
   */
  public static validateTrack(
    cues: LocalizedSubtitleCue[],
    languageCode: string,
    profile?: SubtitleLanguageProfile
  ): SubtitleValidationReport {
    const prof = profile || getSubtitleProfile(languageCode);
    const errors: string[] = [];
    const warnings: string[] = [];

    if (!cues || cues.length === 0) {
      return {
        languageCode,
        totalCues: 0,
        status: "warning",
        isValidSyntax: true,
        hasOverlaps: false,
        maxCps: 0,
        avgCps: 0,
        minDurationMs: 0,
        maxDurationMs: 0,
        warnings: ["Track contains zero subtitle cues."],
        errors: [],
        reviewRequired: false,
      };
    }

    let hasOverlaps = false;
    let maxCps = 0;
    let totalCps = 0;
    let minDurationMs = Infinity;
    let maxDurationMs = 0;

    for (let i = 0; i < cues.length; i++) {
      const cue = cues[i];
      const dur = cue.endMs - cue.startMs;

      // 1. Syntax & Monotonicity
      if (cue.startMs < 0) {
        errors.push(`Cue ${cue.id}: Start timestamp is negative (${cue.startMs}ms).`);
      }
      if (cue.endMs <= cue.startMs) {
        errors.push(`Cue ${cue.id}: End timestamp (${cue.endMs}ms) is <= start timestamp (${cue.startMs}ms).`);
      }
      if (i > 0 && cue.startMs < cues[i - 1].startMs) {
        errors.push(`Cue ${cue.id}: Start timestamp is earlier than previous cue ${cues[i - 1].id}.`);
      }

      // 2. Overlaps
      if (i > 0 && cue.startMs < cues[i - 1].endMs) {
        hasOverlaps = true;
        const overlapMs = cues[i - 1].endMs - cue.startMs;
        errors.push(`Cue ${cue.id}: Overlaps with previous cue by ${overlapMs}ms.`);
      }

      // 3. Inter-Cue Gap (Flicker Guard)
      if (i > 0 && cue.startMs === cues[i - 1].endMs) {
        warnings.push(`Cue ${cue.id}: 0ms gap with previous cue (recommended min ${prof.minInterCueGapMs}ms to prevent eye flicker).`);
      }

      // 4. Duration Bounds
      if (dur < prof.minimumCueDurationMs) {
        warnings.push(`Cue ${cue.id}: Duration (${dur}ms) is below minimum threshold (${prof.minimumCueDurationMs}ms).`);
      }
      if (dur > prof.maximumCueDurationMs) {
        warnings.push(`Cue ${cue.id}: Duration (${dur}ms) exceeds maximum threshold (${prof.maximumCueDurationMs}ms).`);
      }

      if (dur < minDurationMs) minDurationMs = dur;
      if (dur > maxDurationMs) maxDurationMs = dur;

      // 5. Reading Speed (CPS)
      const charCount = getGraphemeCount(cue.text);
      const durSec = dur / 1000;
      const cps = durSec > 0 ? Number((charCount / durSec).toFixed(2)) : 0;
      cue.charactersPerSecond = cps;

      if (cps > maxCps) maxCps = cps;
      totalCps += cps;

      if (cps > prof.maxReadingSpeedCps) {
        warnings.push(`Cue ${cue.id}: Excessive reading speed (${cps} CPS vs max allowed ${prof.maxReadingSpeedCps} CPS).`);
        cue.validationStatus = "warning";
      }

      // 6. Line Length & Line Breaks (CPL)
      const lines = cue.text.split("\n");
      cue.lines = lines;
      if (lines.length > prof.maxLines) {
        warnings.push(`Cue ${cue.id}: Number of lines (${lines.length}) exceeds maximum allowed (${prof.maxLines}).`);
        cue.validationStatus = "warning";
      }
      for (const line of lines) {
        const lineLen = getGraphemeCount(line);
        if (lineLen > cue.charactersPerLine) cue.charactersPerLine = lineLen;
        if (lineLen > prof.maxCharactersPerLine) {
          warnings.push(`Cue ${cue.id}: Line length (${lineLen} chars) exceeds maximum allowed (${prof.maxCharactersPerLine} chars).`);
          cue.validationStatus = "warning";
        }
      }

      // 7. Linguistic Integrity & Encoding
      if (!cue.text || cue.text.trim().length === 0) {
        errors.push(`Cue ${cue.id}: Text is empty.`);
      }
      if (cue.text.includes("\uFFFD")) {
        errors.push(`Cue ${cue.id}: Contains Unicode replacement character (broken encoding).`);
      }
      if (/&(?:amp|lt|gt|quot|#39);/i.test(cue.text)) {
        warnings.push(`Cue ${cue.id}: Contains unescaped HTML entities.`);
      }
      if (/\[(?:music|applause|laughter|silence)\]/i.test(cue.text)) {
        warnings.push(`Cue ${cue.id}: Contains unstripped audio bracket annotation.`);
      }

      if (cue.validationStatus !== "warning" && errors.length === 0) {
        cue.validationStatus = "pass";
      }
    }

    const avgCps = cues.length > 0 ? Number((totalCps / cues.length).toFixed(2)) : 0;
    const isValidSyntax = errors.length === 0;
    const reviewRequired = warnings.length > 0 || !isValidSyntax;

    let overallStatus: "pass" | "warning" | "review" = "pass";
    if (!isValidSyntax) {
      overallStatus = "review";
    } else if (warnings.length > 0) {
      overallStatus = "warning";
    }

    return {
      languageCode,
      totalCues: cues.length,
      status: overallStatus,
      isValidSyntax,
      hasOverlaps,
      maxCps,
      avgCps,
      minDurationMs: minDurationMs === Infinity ? 0 : minDurationMs,
      maxDurationMs,
      warnings,
      errors,
      reviewRequired,
    };
  }
}
