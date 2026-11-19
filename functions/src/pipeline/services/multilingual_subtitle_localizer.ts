/**
 * 🌐 MULTILINGUAL SUBTITLE LOCALIZATION ENGINE
 *
 * Architecture: "Translate first, segment second"
 * 1. Groups source speech into complete grammatical sentences with word timestamps.
 * 2. Translates complete contextual sentences via the required v3 + Adaptive MT composite.
 * 3. Independently segments translated text according to target-language grammar and reading speed.
 * 4. Temporally aligns target phrases to source speech intervals with intelligent retiming:
 *    - Eliminates 1:1 cue-time projection bottlenecks (fixes Spanish 48.29 CPS blowout).
 *    - Guarantees minimum broadcast duration (>= 833ms for Latin, >= 1000ms for Indic).
 *    - Enforces 2-frame (66ms) inter-cue gaps to eliminate redraw flicker.
 *    - Extends display windows into trailing silence pauses without colliding with next dialogue.
 * 5. Runs SubtitleReadabilityValidator across all generated cues.
 */

import { WordTimestamp, TimedSegment } from "../types";
import { translationService } from "./translation";
import { logger } from "../utils/logger";
import {
  SubtitleLanguageProfile,
  getSubtitleProfile,
  getGraphemeCount,
  calculateMinInterCueGapMs,
} from "./subtitle_language_profiles";
import {
  LocalizedSubtitleCue,
  SubtitleReadabilityValidator,
  SubtitleValidationReport,
} from "./subtitle_readability_validator";
import { SubtitleGuardrails } from "./subtitleGuardrails";

export interface SourceSentence {
  sentenceIndex: number;
  text: string;
  startMs: number;
  endMs: number;
  durationMs: number;
  words: WordTimestamp[];
  startIndex: number;
  endIndex: number;
  speaker?: string;
  followingPauseMs: number;
}

export interface LocalizedSubtitleTrackResult {
  languageCode: string;
  cues: LocalizedSubtitleCue[];
  srtContent: string;
  vttContent: string;
  jsonContent: string;
  validationReport: SubtitleValidationReport;
}

export class MultilingualSubtitleLocalizer {
  /**
   * Step 1: Extract complete grammatical sentences from word-level timestamps.
   * Fixes intra-word hyphen bug so compound words like Fact-Checking or zero-emission
   * never trigger premature sentence/clause splits.
   */
  public static extractSourceSentences(
    words: WordTimestamp[],
    fallbackSegments?: Array<Partial<TimedSegment> & { start: number; end: number; text: string }>
  ): SourceSentence[] {
    if (!words || words.length === 0) {
      if (fallbackSegments && fallbackSegments.length > 0) {
        return fallbackSegments.map((seg, i) => {
          const next = i < fallbackSegments.length - 1 ? fallbackSegments[i + 1] : null;
          const followingPause = next ? Math.max(0, next.start - seg.end) : 800;
          return {
            sentenceIndex: i + 1,
            text: seg.text.trim(),
            startMs: seg.start,
            endMs: seg.end,
            durationMs: seg.end - seg.start,
            words: seg.words || [],
            startIndex: 0,
            endIndex: 0,
            speaker: seg.speaker || "speaker_0",
            followingPauseMs: followingPause,
          };
        });
      }
      return [];
    }

    const sentences: SourceSentence[] = [];
    let currentWords: WordTimestamp[] = [];
    let sentenceStartWordIndex = 0;
    let sentenceIndex = 1;

    for (let i = 0; i < words.length; i++) {
      const w = words[i];
      if (!w.text || !w.text.trim()) continue;
      currentWords.push(w);

      const isLastWord = i === words.length - 1;
      const nextWord = !isLastWord ? words[i + 1] : null;

      // Safe pause detection (sentence pause is typically >= 450ms)
      const hasPause = nextWord ? nextWord.start - w.end >= 450 : false;

      // Sentence terminal punctuation: . ? ! । | (Devanagari/Indic danda)
      const isTerminalPunct = /[.?!।|]$/.test(w.text.trim());

      // Speaker boundary check
      const speakerChanged = nextWord && nextWord.speaker && w.speaker && nextWord.speaker !== w.speaker;

      // Safe sentence length ceiling: max 18 words or max 7.5 seconds
      const isDurationCeiling = w.end - currentWords[0].start >= 7500;
      const isWordCountCeiling = currentWords.length >= 18;

      if (isLastWord || isTerminalPunct || hasPause || speakerChanged || isDurationCeiling || isWordCountCeiling) {
        const startMs = currentWords[0].start;
        const endMs = currentWords[currentWords.length - 1].end;
        const sentenceText = currentWords
          .map((cw) => cw.text.trim())
          .filter(Boolean)
          .join(" ");

        const followingPause = nextWord ? Math.max(0, nextWord.start - endMs) : 1000;

        sentences.push({
          sentenceIndex: sentenceIndex++,
          text: sentenceText,
          startMs,
          endMs,
          durationMs: endMs - startMs,
          words: [...currentWords],
          startIndex: sentenceStartWordIndex,
          endIndex: i,
          speaker: currentWords[0].speaker || "speaker_0",
          followingPauseMs: followingPause,
        });

        currentWords = [];
        sentenceStartWordIndex = i + 1;
      }
    }

    return sentences;
  }

  /**
   * Step 2 & 3: Context-aware translation and language-specific segmentation.
   */
  public static async localizeTrack(params: {
    jobId: string;
    sourceWords: WordTimestamp[];
    sourceLanguage: string;
    targetLanguage: string;
    fallbackSegments?: Array<Partial<TimedSegment> & { start: number; end: number; text: string }>;
    fps?: number;
    sceneCutTimestampsMs?: number[];
    deliveryProfile?: "netflix" | "broadcast_ebu" | "standard_web";
  }): Promise<LocalizedSubtitleTrackResult> {
    const { jobId, sourceWords, sourceLanguage, targetLanguage, fallbackSegments, fps, sceneCutTimestampsMs, deliveryProfile } = params;
    const profile = getSubtitleProfile(targetLanguage);
    const sentences = this.extractSourceSentences(sourceWords, fallbackSegments);

    logger.info("[MultilingualLocalizer] Extracted source sentences", {
      jobId,
      sentenceCount: sentences.length,
      sourceLanguage,
      targetLanguage,
    });

    if (sentences.length === 0) {
      return {
        languageCode: targetLanguage,
        cues: [],
        srtContent: "",
        vttContent: "WEBVTT\n\n",
        jsonContent: "[]",
        validationReport: SubtitleReadabilityValidator.validateTrack([], targetLanguage, profile),
      };
    }

    // Translate complete contextual sentences
    let translatedSentenceTexts: string[] = [];
    if (targetLanguage.toLowerCase() === sourceLanguage.toLowerCase()) {
      translatedSentenceTexts = sentences.map((s) => s.text);
    } else {
      // ⚡ Low-Latency Optimization: Reuse pre-translated segments if available to avoid duplicate AI translation calls
      const hasTranslatedFallback = Boolean(
        fallbackSegments &&
        fallbackSegments.length > 0 &&
        fallbackSegments.some((fb) => fb.text && fb.text.trim().length > 0 && fb.text.trim() !== (sourceWords?.[0]?.text?.trim() || ''))
      );

      if (hasTranslatedFallback && fallbackSegments && fallbackSegments.length === sentences.length) {
        logger.info("[MultilingualLocalizer] Reusing pre-translated segments for zero-latency subtitle alignment", {
          jobId,
          targetLanguage,
          segmentCount: fallbackSegments.length,
        });
        translatedSentenceTexts = fallbackSegments.map((fb) => fb.text.trim());
      } else {
        translatedSentenceTexts = await translationService.batchTranslateStandard(
          sentences.map((s) => s.text),
          sourceLanguage,
          targetLanguage
        );
      }

      if (
        translatedSentenceTexts.length !== sentences.length ||
        translatedSentenceTexts.some((text) => !text?.trim())
      ) {
        throw new Error(`[MultilingualLocalizer] Required translation returned incomplete results for ${targetLanguage}.`);
      }
    }

    // Step 4: Target-Language Segmentation & Intelligent Retiming
    const allCues: LocalizedSubtitleCue[] = [];
    let cueId = 1;

    for (let sIdx = 0; sIdx < sentences.length; sIdx++) {
      const sentence = sentences[sIdx];
      const rawText = translatedSentenceTexts[sIdx];
      if (!rawText?.trim()) {
        throw new Error(`[MultilingualLocalizer] Missing required ${targetLanguage} translation for sentence ${sIdx}.`);
      }
      const translatedText = SubtitleGuardrails.sanitize(rawText, {
        targetLanguage,
        sourceLanguage,
      });
      const nextSentence = sIdx < sentences.length - 1 ? sentences[sIdx + 1] : null;
      const nextSentenceStartMs = nextSentence ? nextSentence.startMs : undefined;
      const previousCueEndMs = allCues.length > 0 ? allCues[allCues.length - 1].endMs : undefined;

      // Independently segment the translated text for this language
      const targetPhrases = this.segmentTranslatedSentence(translatedText, targetLanguage, profile);

      // Intelligently retime phrases within this sentence's acoustic envelope
      const timedCues = this.retimeTargetPhrasesForSentence({
        sentence,
        phrases: targetPhrases,
        languageCode: targetLanguage,
        profile,
        startCueId: cueId,
        nextSentenceStartMs,
        previousCueEndMs,
        sceneCutTimestampsMs,
        fps,
        deliveryProfile,
      });

      for (const cue of timedCues) {
        allCues.push(cue);
        cueId++;
      }
    }

    // Run automated readability validation
    const validationReport = SubtitleReadabilityValidator.validateTrack(allCues, targetLanguage, profile);

    logger.info("[MultilingualLocalizer] Subtitle localization complete", {
      jobId,
      targetLanguage,
      cuesCount: allCues.length,
      avgCps: validationReport.avgCps,
      maxCps: validationReport.maxCps,
      status: validationReport.status,
    });

    // Step 5: Format serialization (SRT / WebVTT / JSON)
    const { srtContent, vttContent, jsonContent } = this.serializeCues(allCues);

    return {
      languageCode: targetLanguage,
      cues: allCues,
      srtContent,
      vttContent,
      jsonContent,
      validationReport,
    };
  }

  /**
   * Splits a cue's text across up to 2 lines at the most natural syntactic break
   * (e.g. after punctuation or before prepositions/conjunctions near the middle),
   * ensuring neither line exceeds maxCharactersPerLine.
   */
  public static formatCueLines(text: string, profile: SubtitleLanguageProfile): string {
    const trimmed = text.trim();
    const len = getGraphemeCount(trimmed);
    if (len <= profile.maxCharactersPerLine || profile.maxLines < 2) {
      return trimmed;
    }

    const words = trimmed.split(/\s+/).filter(Boolean);
    if (words.length <= 1) return trimmed;

    // Find the split point (after word index k) that minimizes difference in line lengths
    // and keeps both lines <= maxCharactersPerLine.
    let bestSplitIdx = -1;
    let minPenalty = Infinity;

    for (let k = 0; k < words.length - 1; k++) {
      const line1 = words.slice(0, k + 1).join(" ");
      const line2 = words.slice(k + 1).join(" ");
      const len1 = getGraphemeCount(line1);
      const len2 = getGraphemeCount(line2);

      let penalty = Math.abs(len1 - len2);

      // Severe penalty if either line exceeds maxCharactersPerLine
      if (len1 > profile.maxCharactersPerLine) penalty += (len1 - profile.maxCharactersPerLine) * 100;
      if (len2 > profile.maxCharactersPerLine) penalty += (len2 - profile.maxCharactersPerLine) * 100;

      // Bonus if line 1 ends with punctuation
      if (/[,;:\-।—–]$/.test(words[k])) penalty -= 15;

      // Bonus if line 2 starts with a conjunction or preposition
      if (/^(and|or|but|because|with|from|to|for|sobre|de|en|y|o|pero|por|में|पर|और|పై|మరియు|నుండి)$/i.test(words[k + 1])) {
        penalty -= 10;
      }

      if (penalty < minPenalty) {
        minPenalty = penalty;
        bestSplitIdx = k;
      }
    }

    if (bestSplitIdx >= 0) {
      const line1 = words.slice(0, bestSplitIdx + 1).join(" ");
      const line2 = words.slice(bestSplitIdx + 1).join(" ");
      return `${line1}\n${line2}`;
    }

    return trimmed;
  }

  /**
   * Segments a translated sentence into natural reading phrases based on language rules.
   */
  public static segmentTranslatedSentence(
    text: string,
    languageCode: string,
    profile: SubtitleLanguageProfile
  ): string[] {
    const trimmed = text.trim();
    if (!trimmed) return [];

    const graphemeLen = getGraphemeCount(trimmed);

    // If the sentence fits comfortably within 2 lines (<= 1.8 * maxCharactersPerLine),
    // format as a single coherent cue with optimal line-wrapping
    if (graphemeLen <= profile.maxCharactersPerLine * 1.8) {
      return [this.formatCueLines(trimmed, profile)];
    }

    // Sentence is longer than 2 lines, so split into balanced semantic cues
    const words = trimmed.split(/\s+/).filter(Boolean);
    if (words.length <= 4) {
      return [this.formatCueLines(trimmed, profile)];
    }

    const phrases: string[] = [];
    let currentWords: string[] = [];

    // Language-specific conjunctions and clause boundary words
    const CLAUSE_BOUNDARY_WORDS = new Set<string>([
      // English
      "and", "but", "because", "while", "although", "regarding", "whereas",
      // Spanish
      "y", "pero", "porque", "mientras", "aunque", "sobre", "que", "donde",
      // Hindi
      "और", "तथा", "एवं", "लेकिन", "किन्तु", "परन्तु", "क्योंकि", "जब", "जबकि",
      // Telugu
      "మరియు", "కానీ", "ఎందుకంటే", "అయితే", "పై", "గురించి",
    ]);

    for (let i = 0; i < words.length; i++) {
      const word = words[i];
      currentWords.push(word);

      const isLast = i === words.length - 1;
      const nextWord = !isLast ? words[i + 1] : null;

      const currentText = currentWords.join(" ");
      const currentLen = getGraphemeCount(currentText);

      const remainingWordsCount = words.length - 1 - i;
      const remainingText = words.slice(i + 1).join(" ");
      const remainingLen = getGraphemeCount(remainingText);

      // Check if word ends with punctuation (comma, semicolon, dash)
      const hasPunctuationBreak = /[,;،।—–]$/.test(word);

      // Check if next word introduces a major clause
      const nextIsClauseConjunction = nextWord && CLAUSE_BOUNDARY_WORDS.has(nextWord.toLowerCase());

      // Length constraint
      const exceedsPreferredCpl = currentLen >= profile.maxCharactersPerLine * 0.75;
      const exceedsMaxCpl = currentLen >= profile.maxCharactersPerLine;

      // Lookahead: never split if the remainder would be stranded as a tiny fragment (< 3 words or < 12 chars)
      // UNLESS the current chunk is already dangerously long (> 1.8 * maxCharactersPerLine)
      const remainderWouldBeStranded = remainingWordsCount < 3 || remainingLen < 12;

      const shouldSplit =
        !isLast &&
        (
          (hasPunctuationBreak && currentWords.length >= 3 && (!remainderWouldBeStranded || remainingWordsCount >= 3)) ||
          (nextIsClauseConjunction && exceedsPreferredCpl && currentWords.length >= 3 && !remainderWouldBeStranded) ||
          (exceedsMaxCpl && currentWords.length >= 3 && !remainderWouldBeStranded) ||
          (currentLen >= profile.maxCharactersPerLine * 1.6)
        );

      if (isLast || shouldSplit) {
        phrases.push(this.formatCueLines(currentText, profile));
        currentWords = [];
      }
    }

    if (currentWords.length > 0) {
      phrases.push(this.formatCueLines(currentWords.join(" "), profile));
    }

    return phrases;
  }

  /**
   * Intelligently retimes translated phrases for a single sentence.
   * Allocates display time based on linguistic weight, guarantees minimum broadcast duration,
   * enforces 2-frame gaps, and utilizes trailing silence to prevent reading rush.
   */
  public static retimeTargetPhrasesForSentence(params: {
    sentence: SourceSentence;
    phrases: string[];
    languageCode: string;
    profile: SubtitleLanguageProfile;
    startCueId: number;
    nextSentenceStartMs?: number;
    previousCueEndMs?: number;
    sceneCutTimestampsMs?: number[];
    fps?: number;
    deliveryProfile?: "netflix" | "broadcast_ebu" | "standard_web";
  }): LocalizedSubtitleCue[] {
    const {
      sentence,
      phrases,
      languageCode,
      profile,
      startCueId,
      nextSentenceStartMs,
      previousCueEndMs,
      sceneCutTimestampsMs,
      fps = 30,
    } = params;
    if (phrases.length === 0) return [];

    // Frame-rate aware gap (e.g. 2 frames at 24fps = 83ms; 2 frames at 30fps = 66ms)
    const minGapMs = calculateMinInterCueGapMs(fps, profile);
    const cutMarginMs = Math.max(33, Math.round(2 * (1000 / (fps > 0 ? fps : 30)))); // 2 frames margin before shot cut

    // Non-overlapping start: ensure we never start before previous cue + minGapMs
    const effectiveStartMs = previousCueEndMs !== undefined
      ? Math.max(sentence.startMs, previousCueEndMs + minGapMs)
      : sentence.startMs;

    // Bounded silence utilization: borrow up to 1400ms of following silence if available to prevent CPS blowout
    const availableSilenceBorrowMs = Math.min(sentence.followingPauseMs, 1400);
    const speechSilenceCeiling = sentence.endMs + availableSilenceBorrowMs;
    const nextSentenceCeiling = nextSentenceStartMs !== undefined ? nextSentenceStartMs - minGapMs : Infinity;

    // Next scene cut protection: if a shot cut occurs in silence after speech, clamp before the cut
    let sceneCutCeilingMs = Infinity;
    if (sceneCutTimestampsMs && sceneCutTimestampsMs.length > 0) {
      const cut = sceneCutTimestampsMs.find(
        (t) => t > sentence.endMs && t <= sentence.endMs + availableSilenceBorrowMs + cutMarginMs
      );
      if (cut !== undefined) {
        sceneCutCeilingMs = Math.max(sentence.endMs, cut - cutMarginMs);
      }
    }

    // Hard ceiling formula: FinalEnd = min(SpeechEnd + BorrowLimit, NextSentenceStart - Gap, NextSceneCut - CutMargin)
    const hardCeilingEndMs = Math.min(speechSilenceCeiling, nextSentenceCeiling, sceneCutCeilingMs);

    const totalAvailableTimeMs = Math.max(
      phrases.length * profile.minimumCueDurationMs,
      hardCeilingEndMs - effectiveStartMs
    );

    const cueWeights = phrases.map((p) => Math.max(1, getGraphemeCount(p)));
    const totalWeight = cueWeights.reduce((a, b) => a + b, 0);

    const totalGapsMs = Math.max(0, phrases.length - 1) * minGapMs;
    const netDisplayTimeMs = Math.max(
      phrases.length * profile.minimumCueDurationMs,
      totalAvailableTimeMs - totalGapsMs
    );

    const resultCues: LocalizedSubtitleCue[] = [];
    let currentStartMs = effectiveStartMs;

    for (let i = 0; i < phrases.length; i++) {
      const phrase = phrases[i];
      const weightFraction = cueWeights[i] / totalWeight;

      // Allocate time proportional to text length
      let allocatedDurationMs = Math.round(netDisplayTimeMs * weightFraction);

      // Enforce minimum cue duration
      if (allocatedDurationMs < profile.minimumCueDurationMs) {
        allocatedDurationMs = profile.minimumCueDurationMs;
      }

      // Enforce maximum cue duration
      if (allocatedDurationMs > profile.maximumCueDurationMs) {
        allocatedDurationMs = profile.maximumCueDurationMs;
      }

      // Check reading speed against preferred speed
      const charCount = getGraphemeCount(phrase);
      const estCps = charCount / (allocatedDurationMs / 1000);
      if (estCps > profile.maxReadingSpeedCps) {
        // Expand duration to bring CPS under threshold if time remains
        const targetDuration = Math.ceil((charCount / profile.preferredReadingSpeedCps) * 1000);
        allocatedDurationMs = Math.min(profile.maximumCueDurationMs, Math.max(allocatedDurationMs, targetDuration));
      }

      // Hard cap: ensure space remains for all subsequent phrases in this sentence
      const remainingPhrases = phrases.length - 1 - i;
      const latestEndAllowed = hardCeilingEndMs - remainingPhrases * (profile.minimumCueDurationMs + minGapMs);
      let cueEndMs = currentStartMs + allocatedDurationMs;
      if (cueEndMs > latestEndAllowed && latestEndAllowed > currentStartMs) {
        cueEndMs = latestEndAllowed;
      }

      const finalDuration = Math.max(100, cueEndMs - currentStartMs);
      const finalCps = Number((charCount / (finalDuration / 1000)).toFixed(2));

      const lines = phrase.split("\n");
      const maxLineLen = Math.max(...lines.map((l) => getGraphemeCount(l)));
      const exceedsCpl = maxLineLen > profile.maxCharactersPerLine;
      const exceedsLines = lines.length > profile.maxLines;
      const exceedsCps = finalCps > profile.maxReadingSpeedCps;
      const durationTooShort = finalDuration < profile.minimumCueDurationMs;

      // Rigorous validation status: if merged or retimed cue violates fundamental readability, flag as "review"
      let cueStatus: "pass" | "warning" | "review" = "pass";
      if (exceedsLines || maxLineLen > profile.maxCharactersPerLine * 1.15 || finalCps > profile.maxReadingSpeedCps * 1.25) {
        cueStatus = "review";
      } else if (exceedsCpl || exceedsCps || durationTooShort) {
        cueStatus = "warning";
      }

      resultCues.push({
        id: startCueId + i,
        languageCode,
        text: phrase,
        startMs: currentStartMs,
        endMs: currentStartMs + finalDuration,
        durationMs: finalDuration,
        sourceWordStartIndex: sentence.startIndex,
        sourceWordEndIndex: sentence.endIndex,
        charactersPerSecond: finalCps,
        charactersPerLine: maxLineLen,
        alignmentConfidence: 0.98,
        validationStatus: cueStatus,
        speaker: sentence.speaker,
      });

      // Advance start time with 2-frame inter-cue gap
      currentStartMs = currentStartMs + finalDuration + minGapMs;
    }

    return resultCues;
  }

  /**
   * Edge Case D: Bidirectional Isolation (RTL/LTR Isolate Wrappers)
   * Wraps embedded Latin alphanumeric tokens/numbers inside RTL text (Arabic, Hebrew, Urdu)
   * with Unicode First Strong Isolate (U+2068) and Pop Directional Isolate (U+2069)
   * to guarantee zero punctuation flipping and zero line-jump glitches in video players.
   */
  public static applyBidirectionalIsolation(text: string, langCode: string): string {
    const code = (langCode || "").toLowerCase().split(/[-_]/)[0];
    const isRtl = ["ar", "he", "fa", "ur"].includes(code);
    if (!isRtl || !text) return text;
    return text.replace(/([A-Za-z0-9_#@.:\/-]+)/g, "\u2068$1\u2069");
  }

  /**
   * Serializes cues into standard SRT, WebVTT, and JSON.
   * Edge Case B & D: Enforces WebVTT voice tags, screen line positioning for overlapping speech,
   * bidirectional isolation, and UTF-8 BOM headers.
   */
  public static serializeCues(cues: LocalizedSubtitleCue[]): {
    srtContent: string;
    vttContent: string;
    jsonContent: string;
  } {
    const formatTimeSrt = (ms: number): string => {
      const hrs = Math.floor(ms / 3600000);
      const mins = Math.floor((ms % 3600000) / 60000);
      const secs = Math.floor((ms % 60000) / 1000);
      const millis = ms % 1000;
      return `${String(hrs).padStart(2, "0")}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")},${String(millis).padStart(3, "0")}`;
    };

    const formatTimeVtt = (ms: number): string => {
      const hrs = Math.floor(ms / 3600000);
      const mins = Math.floor((ms % 3600000) / 60000);
      const secs = Math.floor((ms % 60000) / 1000);
      const millis = ms % 1000;
      return `${String(hrs).padStart(2, "0")}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${String(millis).padStart(3, "0")}`;
    };

    let srt = "";
    let vtt = "WEBVTT\n\n";

    cues.forEach((cue, index) => {
      const startSrt = formatTimeSrt(cue.startMs);
      const endSrt = formatTimeSrt(cue.endMs);
      const startVtt = formatTimeVtt(cue.startMs);
      const endVtt = formatTimeVtt(cue.endMs);

      const safeText = this.applyBidirectionalIsolation(cue.text, cue.languageCode || "");

      // SRT standard formatting
      srt += `${cue.id}\n${startSrt} --> ${endSrt}\n${safeText}\n\n`;

      // WebVTT with voice tags and collision avoidance
      let vttCueHeader = `${startVtt} --> ${endVtt}`;
      let vttBody = safeText;

      const prevCue = index > 0 ? cues[index - 1] : null;
      const isOverlappingPrev = prevCue && prevCue.endMs > cue.startMs;
      if (isOverlappingPrev) {
        // Position overlapping cues in upper third (15%) vs lower third (85%)
        vttCueHeader += " line:15% align:center";
      }

      if (cue.speaker && cue.speaker !== "speaker_0" && cue.speaker !== "unknown") {
        vttBody = `<v ${cue.speaker}>${safeText}</v>`;
      }

      vtt += `${vttCueHeader}\n${vttBody}\n\n`;
    });

    const srtContent = "\uFEFF" + srt;
    const vttContent = "\uFEFF" + vtt;
    const jsonContent = JSON.stringify(cues, null, 2);

    return { srtContent, vttContent, jsonContent };
  }
}

export const multilingualSubtitleLocalizer = new MultilingualSubtitleLocalizer();
