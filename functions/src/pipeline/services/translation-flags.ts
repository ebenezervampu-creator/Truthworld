/**
 * Feature / rollback flags for dubbing translation fidelity & sync fixes (2026-11-25).
 * Every flag defaults to enabled (`true`); setting the env var to `"false"` restores the old behaviour.
 */

function envFlag(name: string, env: Record<string, string | undefined> = process.env): boolean {
  return String(env[name] ?? "true").toLowerCase() !== "false";
}

/** Fix 1.1: Subtitles for non-source languages reuse dual-track `subtitleText` from the dub pass. */
export function subtitlesFromDubPassEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return envFlag("DUBBING_SUBTITLES_FROM_DUB_PASS", env);
}

/** Fix 2.3 (D2): Unresolved meaning / polarity / number errors block the language before TTS. */
export function blockOnTranslationErrorsEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return envFlag("DUBBING_BLOCK_ON_TRANSLATION_ERRORS", env);
}

/** Fix 3.1: Pre-TTS estimator and editor budget share `services/speech-rate.ts`. */
export function unifiedSpeechRateEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return envFlag("DUBBING_UNIFIED_SPEECH_RATE", env);
}

/** Fix 3.3: Post-TTS concise retakes use each voice's measured speaking rate. */
export function voiceRateCalibrationEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return envFlag("DUBBING_VOICE_RATE_CALIBRATION", env);
}

/** Fix 3.6: Dubbing permissible window caps extra trailing buffer at scene cuts. */
export function shotChangeWindowEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return envFlag("DUBBING_SHOT_CHANGE_WINDOW", env);
}

/** Fix 4.1–4.3: Editor receives creatorDNA/targetPlatform, isSong, and visualSceneNotes. */
export function editorContextEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return envFlag("DUBBING_EDITOR_CONTEXT", env);
}

export interface BlockedTranslationLine {
  index: number;
  reason: string;
  source: string;
  text: string;
}

/**
 * Returns every segment still carrying an unresolved `translationBlockReason`,
 * or `[]` when `DUBBING_BLOCK_ON_TRANSLATION_ERRORS=false`.
 */
export function findBlockedTranslationLines<
  T extends { originalText: string; translatedText: string; translationBlockReason?: string },
>(segments: T[], enabled: boolean = blockOnTranslationErrorsEnabled()): BlockedTranslationLine[] {
  if (!enabled) return [];
  const out: BlockedTranslationLine[] = [];
  for (let idx = 0; idx < segments.length; idx++) {
    const seg = segments[idx];
    if (seg.translationBlockReason) {
      out.push({
        index: idx,
        reason: seg.translationBlockReason,
        source: seg.originalText,
        text: seg.translatedText,
      });
    }
  }
  return out;
}

/**
 * Pre-TTS dubbing eligibility and initial outcome for a target language (Fix 2.3 / R1).
 */
export function evaluatePreTtsDubbingDecision(params: {
  generateDubbing: boolean;
  targetLang: string;
  sourceLang: string;
  isV4DubbingLanguage: boolean;
  nativeVoiceBlock?: string;
  blockedLines: Array<{ index: number }>;
}): {
  isDubbingSupportedForTarget: boolean;
  blockedByTranslation: boolean;
  initialDubOutcome: "not_requested" | "not_dubbable" | "failed";
} {
  const blockedByTranslation =
    params.generateDubbing &&
    params.targetLang !== params.sourceLang &&
    params.blockedLines.length > 0;
  const isDubbingSupportedForTarget =
    params.isV4DubbingLanguage && !params.nativeVoiceBlock && params.blockedLines.length === 0;

  let initialDubOutcome: "not_requested" | "not_dubbable" | "failed" = "not_requested";
  if (params.generateDubbing && params.targetLang !== params.sourceLang) {
    if (blockedByTranslation) {
      initialDubOutcome = "failed";
    } else if (!params.isV4DubbingLanguage || params.nativeVoiceBlock) {
      initialDubOutcome = "not_dubbable";
    }
  }
  return { isDubbingSupportedForTarget, blockedByTranslation, initialDubOutcome };
}

/**
 * Long-form languages that were requested (excluding source) but excluded from `dubLanguages`
 * (blocked by translation gate, unsupported by v4, or missing native voice) so they can be refunded (R3).
 */
export function findLongFormSkippedRefundLanguages(
  languagesToProcess: string[],
  dubLanguages: string[],
  sourceLang: string,
  normalize: (lang: string) => string = (l) => (l || "").toLowerCase().split(/[-_]/)[0]
): string[] {
  const normSource = normalize(sourceLang);
  const dubbedSet = new Set(dubLanguages.map(normalize));
  return languagesToProcess.filter((rawLang) => {
    const norm = normalize(rawLang);
    return norm !== normSource && !dubbedSet.has(norm);
  });
}
