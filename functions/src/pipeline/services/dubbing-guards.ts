/**
 * Dependency-free guards for the dubbing TTS path, applied to every eleven_v4 dubbing language.
 *
 * Kept free of Firebase / axios imports so they can be unit-tested in isolation.
 *
 * Why these exist (Clip 2 regression, 2026-11-19):
 *  - ElevenLabs was never told which language it was reading. With an English preset voice
 *    and an English audio tag ("[sad]") in front of a short Telugu line, the model auto-detected
 *    the language and read Telugu with English phonetics ("చింతించకు" → "C-N-T-N-ku").
 *  - Per-segment stability swung between 0.20 and 0.85 for the same speaker. Low stability on
 *    eleven_v4 lets the voice drift in timbre and slur non-English phonemes, so one character
 *    sounded like a different person in every scene.
 */

import { expressiveModeEnabled, expressiveStabilityFloor } from "./expressive-mode";
import { isIntenseDeliveryTag, MIN_INTENSE_STABILITY } from "./emotion-transfer";

/**
 * Every language code ElevenLabs publishes for eleven_v4 (91 languages, checked 2026-11-19 against
 * https://elevenlabs.io/docs/overview/capabilities/text-to-speech/eleven-v4).
 * ISO 639-1 where one exists, ISO 639-3 otherwise (ast, yue, ceb, fil, kam, ckb).
 * Sending a code outside this list makes ElevenLabs reject the request, so only these are sent.
 */
export const ELEVEN_V4_LANGUAGE_CODES: ReadonlySet<string> = new Set([
  "af", "am", "ar", "hy", "as", "ast", "az", "be", "bn", "bs", "bg", "my", "yue", "ca", "ceb", "hr",
  "cs", "da", "nl", "en", "et", "fil", "fi", "fr", "ff", "gl", "ka", "de", "el", "gu", "ha", "he",
  "hi", "hu", "is", "id", "it", "ja", "jv", "kam", "kn", "kk", "ko", "ky", "lo", "lv", "ln", "lt",
  "lg", "lb", "mk", "ms", "ml", "mt", "zh", "mi", "mr", "mn", "ne", "no", "oc", "or", "ps", "fa",
  "pl", "pt", "pa", "ro", "ru", "sr", "sn", "sd", "sk", "sl", "so", "ckb", "es", "sw", "sv", "tg",
  "ta", "te", "th", "tr", "uk", "ur", "uz", "vi", "cy", "wo", "zu",
]);

/** TruthWorld codes that name the same language under a different code on ElevenLabs. */
const LANGUAGE_CODE_ALIASES: Record<string, string> = {
  tl: "fil", // Tagalog → Filipino
  iw: "he", // legacy Hebrew code
  nb: "no", // Norwegian Bokmål
  in: "id", // legacy Indonesian code
};

type Range = [number, number];
const DEVANAGARI: Range[] = [[0x0900, 0x097f], [0xa8e0, 0xa8ff]];
const BENGALI: Range[] = [[0x0980, 0x09ff]];
const ARABIC: Range[] = [[0x0600, 0x06ff], [0x0750, 0x077f], [0x08a0, 0x08ff], [0xfb50, 0xfdff], [0xfe70, 0xfeff]];
const CYRILLIC: Range[] = [[0x0400, 0x04ff], [0x0500, 0x052f]];
const CJK: Range[] = [[0x3400, 0x4dbf], [0x4e00, 0x9fff], [0xf900, 0xfaff], [0x20000, 0x2a6df]];
const KANA: Range[] = [[0x3040, 0x309f], [0x30a0, 0x30ff], [0x31f0, 0x31ff], [0xff66, 0xff9f]];
const HANGUL: Range[] = [[0xac00, 0xd7af], [0x1100, 0x11ff], [0x3130, 0x318f]];

/**
 * Native script(s) of every eleven_v4 language that is written in a single non-Latin script.
 * Latin-script languages are not listed: there, romanized text and correct text look the same.
 * Left out on purpose: Hindi (Hinglish keeps English words in Latin), Serbian / Uzbek / Azerbaijani
 * (written in Latin and Cyrillic), Kazakh (moving to Latin), Mongolian (Cyrillic and traditional).
 */
const NATIVE_SCRIPT_RANGES: Record<string, Range[]> = {
  // Indic
  te: [[0x0c00, 0x0c7f]],
  kn: [[0x0c80, 0x0cff]],
  ta: [[0x0b80, 0x0bff]],
  ml: [[0x0d00, 0x0d7f]],
  mr: DEVANAGARI,
  ne: DEVANAGARI,
  bn: BENGALI,
  as: BENGALI,
  gu: [[0x0a80, 0x0aff]],
  pa: [[0x0a00, 0x0a7f]],
  or: [[0x0b00, 0x0b7f]],
  // Arabic script
  ar: ARABIC,
  fa: ARABIC,
  ur: ARABIC,
  ps: ARABIC,
  sd: ARABIC,
  ckb: ARABIC,
  // Others
  he: [[0x0590, 0x05ff], [0xfb1d, 0xfb4f]],
  el: [[0x0370, 0x03ff], [0x1f00, 0x1fff]],
  ru: CYRILLIC,
  uk: CYRILLIC,
  be: CYRILLIC,
  bg: CYRILLIC,
  mk: CYRILLIC,
  ky: CYRILLIC,
  tg: CYRILLIC,
  hy: [[0x0530, 0x058f]],
  ka: [[0x10a0, 0x10ff], [0x1c90, 0x1cbf]],
  am: [[0x1200, 0x139f], [0x2d80, 0x2ddf]],
  th: [[0x0e00, 0x0e7f]],
  lo: [[0x0e80, 0x0eff]],
  my: [[0x1000, 0x109f], [0xaa60, 0xaa7f]],
  zh: CJK,
  yue: CJK,
  ja: [...CJK, ...KANA],
  ko: [...HANGUL, ...CJK],
};

/** Indic languages (kept for callers that need to tell them apart). */
const INDIC = new Set(["te", "kn", "ta", "ml", "hi", "mr", "ne", "bn", "as", "gu", "pa", "or", "ur", "sd"]);

/** Minimum share of letters that must be in the native script. */
export const MIN_NATIVE_SCRIPT_RATIO = 0.6;

/**
 * Stability floor for every non-English target ("Natural" on eleven_v4).
 * Below this the model drifts in timbre between takes and slurs phonemes outside English.
 */
export const MIN_DUBBING_STABILITY = 0.5;
/** @deprecated kept for existing imports; same value as MIN_DUBBING_STABILITY. */
export const INDIC_MIN_STABILITY = MIN_DUBBING_STABILITY;

/** "te-IN" / "TE" / "te_in" → "te"; "tl" → "fil". */
export function baseLanguage(lang?: string): string {
  const base = (lang || "").toLowerCase().trim().split(/[-_]/)[0];
  return LANGUAGE_CODE_ALIASES[base] || base;
}

/** True when ElevenLabs publishes eleven_v4 support for this language. */
export function isElevenV4Language(lang?: string): boolean {
  return ELEVEN_V4_LANGUAGE_CODES.has(baseLanguage(lang));
}

/** Returns the code to send as ElevenLabs `language_code`, or undefined when the language is not on the v4 list. */
export function elevenLabsLanguageCode(lang?: string): string | undefined {
  const base = baseLanguage(lang);
  return ELEVEN_V4_LANGUAGE_CODES.has(base) ? base : undefined;
}

/** True for Indic languages. */
export function isIndicLanguage(lang?: string): boolean {
  return INDIC.has(baseLanguage(lang));
}

/** True when the language has a registered native script that dubbing text must use. */
export function requiresNativeScript(lang?: string): boolean {
  return Object.prototype.hasOwnProperty.call(NATIVE_SCRIPT_RANGES, baseLanguage(lang));
}

/**
 * Share of letters (ignoring digits, punctuation, spaces and [audio tags]) that are in the
 * language's native script. Returns 1 for languages without a registered script.
 */
export function nativeScriptRatio(text: string, lang?: string): number {
  const ranges = NATIVE_SCRIPT_RANGES[baseLanguage(lang)];
  if (!ranges || !text) return 1;
  const withoutTags = text.replace(/\[[^\]]*\]/g, " ");
  let letters = 0;
  let native = 0;
  for (const ch of withoutTags) {
    if (!/\p{L}|\p{M}/u.test(ch)) continue;
    letters++;
    const cp = ch.codePointAt(0) as number;
    if (ranges.some(([lo, hi]) => cp >= lo && cp <= hi)) native++;
  }
  return letters === 0 ? 1 : native / letters;
}

export class NonNativeScriptError extends Error {
  readonly code = "TTS_NON_NATIVE_SCRIPT";
  constructor(readonly language: string, readonly ratio: number, readonly preview: string) {
    super(
      `[DubbingGuard] Refusing to synthesize '${language}' text that is only ${Math.round(ratio * 100)}% native script ` +
      `(needs ${Math.round(MIN_NATIVE_SCRIPT_RATIO * 100)}%). Romanized, mis-encoded or untranslated text is read ` +
      `with English phonetics. Preview: "${preview}"`
    );
    this.name = "NonNativeScriptError";
  }
}

/**
 * Throws NonNativeScriptError when text for a native-script language is mostly in another script
 * (romanized text, mojibake, or an untranslated English line). Fails before ElevenLabs is called,
 * so no credits are spent on gibberish.
 */
export function assertNativeScriptForTts(text: string, lang?: string): void {
  const base = baseLanguage(lang);
  if (!requiresNativeScript(base)) return;
  const ratio = nativeScriptRatio(text, base);
  if (ratio < MIN_NATIVE_SCRIPT_RATIO) {
    throw new NonNativeScriptError(base, ratio, text.slice(0, 60));
  }
}

/**
 * Raises stability to the dubbing floor for every non-English target; English passes through.
 * A line tagged with an intense delivery (shouting, crying, …; see emotion-transfer.ts) gets a
 * lower floor: at 0.5 the voice reads a roar or a sob as calm speech. Timbre drift is a smaller
 * risk on a short emotional line than a flat performance is.
 */
export function applyDubbingStabilityFloor(stability: number, lang?: string, emotionTag?: string | null): number {
  const base = baseLanguage(lang);
  if (!base || base === "en") return stability;
  // DUBBING_EXPRESSIVE (expressive-mode.ts): a lower floor for ordinary lines; intense lines keep theirs.
  const ordinaryFloor = expressiveModeEnabled() ? expressiveStabilityFloor() : MIN_DUBBING_STABILITY;
  const floor = isIntenseDeliveryTag(emotionTag) ? Math.min(MIN_INTENSE_STABILITY, ordinaryFloor) : ordinaryFloor;
  return Math.max(floor, stability);
}

/** @deprecated use applyDubbingStabilityFloor; kept so existing imports keep working. */
export const applyIndicStabilityFloor = applyDubbingStabilityFloor;
