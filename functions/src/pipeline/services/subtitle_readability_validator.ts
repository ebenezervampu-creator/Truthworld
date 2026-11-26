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

import { SubtitleLanguageProfile, getSubtitleProfile, getReadableCharCount } from "./subtitle_language_profiles";

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
  /** Sung lyrics (styled per the language's Netflix guide). */
  isLyric?: boolean;
  /** Two speakers in one subtitle, one per line, marked with hyphens. */
  isDualSpeaker?: boolean;
  /** On-screen text translation ("forced narrative"), shown at the top and allowed to overlap dialogue. */
  isForcedNarrative?: boolean;
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
  shotChangeViolations?: number;
}

export interface NetflixRuleCheckResult {
  minDuration: boolean;
  maxDuration: boolean;
  readingSpeed: boolean;
  lineLength: boolean;
  lineCount: boolean;
  interCueGap: boolean;
  noOverlap: boolean;
  shotChangeAlignment: boolean;
  textFormatting: boolean;
}

export interface NetflixScoringResult {
  cueId: number;
  languageCode: string;
  text: string;
  startMs: number;
  endMs: number;
  durationMs: number;
  cps: number;
  cpl: number;
  lineCount: number;
  gapWithPreviousMs: number | null;
  ruleResults: NetflixRuleCheckResult;
  passedAll: boolean;
  violations: string[];
}

export interface NetflixComplianceScorecard {
  totalCues: number;
  passedCues: number;
  complianceRate: number; // 0.0 to 1.0 (e.g. 0.984)
  rulePassRates: Record<keyof NetflixRuleCheckResult, number>;
  languageScores: Record<string, {
    totalCues: number;
    passedCues: number;
    complianceRate: number;
    failedRules: Partial<Record<keyof NetflixRuleCheckResult, number>>;
  }>;
  unresolvedViolations: Array<{
    cueId: number;
    languageCode: string;
    text: string;
    rule: string;
    detail: string;
  }>;
}

export class SubtitleReadabilityValidator {
  /**
   * Validates an entire subtitle track against language-specific standards.
   */
  public static validateTrack(
    cues: LocalizedSubtitleCue[],
    languageCode: string,
    profile?: SubtitleLanguageProfile,
    shotChangesMs?: number[]
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
        shotChangeViolations: 0,
      };
    }

    let hasOverlaps = false;
    let maxCps = 0;
    let totalCps = 0;
    let minDurationMs = Infinity;
    let maxDurationMs = 0;
    let shotChangeViolations = 0;

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

      // 2. Overlaps — on-screen text (forced narratives) sits at the top of the frame and may
      // overlap dialogue, so each cue is only compared with the previous cue of its own kind.
      let prevSameKind: LocalizedSubtitleCue | undefined;
      for (let j = i - 1; j >= 0; j--) {
        if (Boolean(cues[j].isForcedNarrative) === Boolean(cue.isForcedNarrative)) { prevSameKind = cues[j]; break; }
      }
      if (prevSameKind && cue.startMs < prevSameKind.endMs) {
        hasOverlaps = true;
        const overlapMs = prevSameKind.endMs - cue.startMs;
        errors.push(`Cue ${cue.id}: Overlaps with previous cue by ${overlapMs}ms.`);
      }

      // 3. Inter-Cue Gap (Flicker Guard)
      if (prevSameKind && cue.startMs === prevSameKind.endMs) {
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
      const charCount = getReadableCharCount(cue.text);
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
        const lineLen = getReadableCharCount(line);
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

      // 8. Shot Changes (Netflix Timed Text Style Guide: half-second window)
      if (shotChangesMs && shotChangesMs.length > 0) {
        for (const cut of shotChangesMs) {
          if (cut - 500 <= cue.startMs && cue.startMs < cut && cue.endMs - cut < 500) {
            shotChangeViolations++;
            warnings.push(`Cue ${cue.id}: Starts within half a second before shot cut at ${cut}ms (cut flash violation).`);
          } else if (cut < cue.startMs && cue.startMs <= cut + 500) {
            shotChangeViolations++;
            warnings.push(`Cue ${cue.id}: Starts within half a second after shot cut at ${cut}ms (unsnapped shot lead-in).`);
          } else if (cut < cue.endMs && cue.endMs <= cut + 500) {
            shotChangeViolations++;
            warnings.push(`Cue ${cue.id}: Ends within half a second after shot cut at ${cut}ms (cut bleed violation).`);
          }
        }
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
      shotChangeViolations,
    };
  }

  /**
   * Scores a single subtitle cue strictly against the Netflix Timed Text Style Guide requirements.
   */
  public static scoreSubtitleAgainstNetflixRules(
    cue: LocalizedSubtitleCue,
    prevCue: LocalizedSubtitleCue | undefined,
    nextCue: LocalizedSubtitleCue | undefined,
    profile: SubtitleLanguageProfile,
    shotChangesMs?: number[],
    fps: number = 30
  ): NetflixScoringResult {
    const halfSecondFrames = Math.round(fps * 0.5); // 15 frames at 30fps, 12 frames at 24fps
    const halfSecondMs = Math.round((halfSecondFrames / fps) * 1000); // ~500ms
    const dur = cue.endMs - cue.startMs;
    const charCount = getReadableCharCount(cue.text);
    const durSec = dur / 1000;
    const cps = durSec > 0 ? Number((charCount / durSec).toFixed(2)) : 0;
    const lines = cue.text.split("\n");
    const maxLineLen = Math.max(...lines.map((l) => getReadableCharCount(l)));

    const minDurPass = dur >= profile.minimumCueDurationMs;
    const maxDurPass = dur <= profile.maximumCueDurationMs;
    const readingSpeedPass = cps <= profile.maxReadingSpeedCps;
    const lineLengthPass = maxLineLen <= profile.maxCharactersPerLine;
    const lineCountPass = lines.length <= profile.maxLines;

    const gapWithPrev = prevCue ? cue.startMs - prevCue.endMs : null;
    const interCueGapPass = prevCue ? gapWithPrev! >= profile.minInterCueGapMs : true;
    const noOverlapPass = prevCue ? cue.startMs >= prevCue.endMs : true;

    // Shot change checks according to Netflix Subtitle Timing Guidelines (half-second window)
    let shotChangePass = true;
    if (shotChangesMs && shotChangesMs.length > 0) {
      for (const cut of shotChangesMs) {
        // Dialogue starts within half-second after shot change without snapping to cut
        if (cut < cue.startMs && cue.startMs <= cut + halfSecondMs) {
          shotChangePass = false;
          break;
        }
        // Dialogue starts within half-second before shot change without crossing properly
        if (cut - halfSecondMs <= cue.startMs && cue.startMs < cut && cue.endMs - cut < halfSecondMs) {
          shotChangePass = false;
          break;
        }
        // Dialogue ends within half-second after shot change without snapping back
        if (cut < cue.endMs && cue.endMs <= cut + halfSecondMs) {
          shotChangePass = false;
          break;
        }
        // Dialogue ends within half-second before shot change without extending to cut - 2 frames
        if (cut - halfSecondMs <= cue.endMs && cue.endMs < cut - profile.minInterCueGapMs) {
          shotChangePass = false;
          break;
        }
        // Shot crossing: must be present for at least half a second before and after the cut
        if (cue.startMs < cut && cue.endMs > cut) {
          const pre = cut - cue.startMs;
          const post = cue.endMs - cut;
          if (pre < halfSecondMs || post < halfSecondMs) {
            shotChangePass = false;
            break;
          }
        }
      }
    }

    const hasUnicodeErr = cue.text.includes("\uFFFD");
    const hasEntityErr = /&(?:amp|lt|gt|quot|#39);/i.test(cue.text);
    const textFormattingPass = cue.text.trim().length > 0 && !hasUnicodeErr && !hasEntityErr;

    const ruleResults: NetflixRuleCheckResult = {
      minDuration: minDurPass,
      maxDuration: maxDurPass,
      readingSpeed: readingSpeedPass,
      lineLength: lineLengthPass,
      lineCount: lineCountPass,
      interCueGap: interCueGapPass,
      noOverlap: noOverlapPass,
      shotChangeAlignment: shotChangePass,
      textFormatting: textFormattingPass,
    };

    const violations: string[] = [];
    if (!minDurPass) violations.push(`min_duration (${dur}ms < ${profile.minimumCueDurationMs}ms)`);
    if (!maxDurPass) violations.push(`max_duration (${dur}ms > ${profile.maximumCueDurationMs}ms)`);
    if (!readingSpeedPass) violations.push(`reading_speed (${cps} CPS > max ${profile.maxReadingSpeedCps} CPS)`);
    if (!lineLengthPass) violations.push(`line_length (${maxLineLen} chars > max ${profile.maxCharactersPerLine})`);
    if (!lineCountPass) violations.push(`line_count (${lines.length} lines > max ${profile.maxLines})`);
    if (!interCueGapPass) violations.push(`inter_cue_gap (${gapWithPrev}ms < ${profile.minInterCueGapMs}ms)`);
    if (!noOverlapPass) violations.push(`overlap (${prevCue!.endMs - cue.startMs}ms overlap)`);
    if (!shotChangePass) violations.push(`shot_change_alignment (cut boundary violation)`);
    if (!textFormattingPass) violations.push(`text_formatting (encoding/entity flaw)`);

    const passedAll = violations.length === 0;

    return {
      cueId: cue.id,
      languageCode: cue.languageCode,
      text: cue.text,
      startMs: cue.startMs,
      endMs: cue.endMs,
      durationMs: dur,
      cps,
      cpl: maxLineLen,
      lineCount: lines.length,
      gapWithPreviousMs: gapWithPrev,
      ruleResults,
      passedAll,
      violations,
    };
  }

  /**
   * Evaluates an entire subtitle track and produces a comprehensive Netflix compliance scorecard.
   */
  public static scoreTrackAgainstNetflixRules(
    cues: LocalizedSubtitleCue[],
    languageCode: string,
    shotChangesMs?: number[],
    fps: number = 30
  ): NetflixComplianceScorecard {
    const prof = getSubtitleProfile(languageCode);
    const sorted = [...cues].sort((a, b) => a.startMs - b.startMs);
    const scoredCues: NetflixScoringResult[] = [];

    const ruleFailures: Record<keyof NetflixRuleCheckResult, number> = {
      minDuration: 0,
      maxDuration: 0,
      readingSpeed: 0,
      lineLength: 0,
      lineCount: 0,
      interCueGap: 0,
      noOverlap: 0,
      shotChangeAlignment: 0,
      textFormatting: 0,
    };

    const unresolvedViolations: Array<{
      cueId: number;
      languageCode: string;
      text: string;
      rule: string;
      detail: string;
    }> = [];

    let passedCount = 0;

    for (let i = 0; i < sorted.length; i++) {
      const cue = sorted[i];
      let prevDialogue: LocalizedSubtitleCue | undefined;
      for (let j = i - 1; j >= 0; j--) {
        if (Boolean(sorted[j].isForcedNarrative) === Boolean(cue.isForcedNarrative)) {
          prevDialogue = sorted[j];
          break;
        }
      }
      const nextCue = i < sorted.length - 1 ? sorted[i + 1] : undefined;

      const scored = this.scoreSubtitleAgainstNetflixRules(cue, prevDialogue, nextCue, prof, shotChangesMs, fps);
      scoredCues.push(scored);

      if (scored.passedAll) {
        passedCount++;
      } else {
        (Object.keys(scored.ruleResults) as Array<keyof NetflixRuleCheckResult>).forEach((rule) => {
          if (!scored.ruleResults[rule]) {
            ruleFailures[rule]++;
            unresolvedViolations.push({
              cueId: cue.id,
              languageCode,
              text: cue.text.replace(/\n/g, " "),
              rule,
              detail: scored.violations.find((v) => v.startsWith(rule)) || rule,
            });
          }
        });
      }
    }

    const totalCues = sorted.length;
    const complianceRate = totalCues > 0 ? Number((passedCount / totalCues).toFixed(4)) : 1.0;

    const rulePassRates = {} as Record<keyof NetflixRuleCheckResult, number>;
    (Object.keys(ruleFailures) as Array<keyof NetflixRuleCheckResult>).forEach((rule) => {
      rulePassRates[rule] = totalCues > 0 ? Number(((totalCues - ruleFailures[rule]) / totalCues).toFixed(4)) : 1.0;
    });

    return {
      totalCues,
      passedCues: passedCount,
      complianceRate,
      rulePassRates,
      languageScores: {
        [languageCode]: {
          totalCues,
          passedCues: passedCount,
          complianceRate,
          failedRules: ruleFailures,
        },
      },
      unresolvedViolations,
    };
  }
}
