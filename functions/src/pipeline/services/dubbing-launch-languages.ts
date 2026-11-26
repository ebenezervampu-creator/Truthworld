/**
 * Dubbing launch languages (dependency-free, unit-tested).
 *
 * v1.0 (decided 2026-11-23): dubbing is sold only from English into Hindi, Telugu, Marathi, Tamil and
 * Malayalam. These are the pairs that have native voices for both genders, hand-written honorific
 * rules and spoken-style guidance in the editor, and that are checked by native speakers before
 * release. Subtitles are not affected: they keep every language Google Translation supports.
 *
 * The same lists are used by the quote (getDubbingQuote), the order (triggerVideoAIFeatures) and the
 * dubbing worker (07-dubbing.ts), so a language can never be quoted, charged and then dropped. The
 * worker check also covers orders that reach it without the server price (the upload screen).
 *
 * Settings (comma-separated language codes; "all" lifts the limit):
 *   DUBBING_SOURCE_LANGUAGES   default "en"
 *   DUBBING_TARGET_LANGUAGES   default "te,hi,mr,ta,ml"
 * Add a language here only after it has passed the native-speaker check.
 */

export const DEFAULT_DUBBING_SOURCE_LANGUAGES: readonly string[] = ["en"];
export const DEFAULT_DUBBING_TARGET_LANGUAGES: readonly string[] = ["te", "hi", "mr", "ta", "ml"];

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English", te: "Telugu", hi: "Hindi", mr: "Marathi", ta: "Tamil", ml: "Malayalam",
  kn: "Kannada", bn: "Bengali", gu: "Gujarati", pa: "Punjabi", ur: "Urdu",
};

export function baseLanguageCode(lang: unknown): string {
  return String(lang ?? "").toLowerCase().trim().split(/[-_]/)[0];
}

/** null = no limit ("all"). */
function readList(raw: string | undefined, fallback: readonly string[]): Set<string> | null {
  const value = (raw ?? "").trim();
  if (!value) return new Set(fallback);
  if (value.toLowerCase() === "all") return null;
  const codes = value.split(",").map(baseLanguageCode).filter(Boolean);
  return new Set(codes.length > 0 ? codes : fallback);
}

export function dubbingSourceLanguages(): Set<string> | null {
  return readList(process.env.DUBBING_SOURCE_LANGUAGES, DEFAULT_DUBBING_SOURCE_LANGUAGES);
}

export function dubbingTargetLanguages(): Set<string> | null {
  return readList(process.env.DUBBING_TARGET_LANGUAGES, DEFAULT_DUBBING_TARGET_LANGUAGES);
}

export function isDubbingSourceLanguage(lang: unknown): boolean {
  const allowed = dubbingSourceLanguages();
  const code = baseLanguageCode(lang);
  return allowed === null ? code.length > 0 : allowed.has(code);
}

export function isDubbingTargetLanguage(lang: unknown): boolean {
  const allowed = dubbingTargetLanguages();
  const code = baseLanguageCode(lang);
  return allowed === null ? code.length > 0 : allowed.has(code);
}

/** Whether a dub from `source` into `target` may be sold and produced. */
export function isLaunchDubbingPair(source: unknown, target: unknown): boolean {
  return isDubbingSourceLanguage(source) && isDubbingTargetLanguage(target) && baseLanguageCode(source) !== baseLanguageCode(target);
}

export interface DubbingLanguageCheck {
  ok: boolean;
  sourceSupported: boolean;
  /** Requested targets that can be dubbed. */
  dubbableTargets: string[];
  /** Requested targets that cannot be dubbed. */
  unsupportedTargets: string[];
}

/** Splits a dubbing request into what can and can't be produced. */
export function checkDubbingRequest(source: unknown, targets: readonly unknown[]): DubbingLanguageCheck {
  const sourceSupported = isDubbingSourceLanguage(source);
  const dubbableTargets: string[] = [];
  const unsupportedTargets: string[] = [];
  for (const t of targets) {
    const code = baseLanguageCode(t);
    if (!code) continue;
    if (sourceSupported && isLaunchDubbingPair(source, code)) dubbableTargets.push(code);
    else unsupportedTargets.push(code);
  }
  return { ok: sourceSupported && unsupportedTargets.length === 0, sourceSupported, dubbableTargets, unsupportedTargets };
}

function languageName(code: string): string {
  if (LANGUAGE_NAMES[code]) return LANGUAGE_NAMES[code];
  try {
    // Intl.DisplayNames exists at runtime (Node 14+) but not in the es2017 type library this repo targets.
    const DisplayNames = (Intl as any).DisplayNames;
    const name: string | undefined = DisplayNames ? new DisplayNames(["en"], { type: "language" }).of(code) : undefined;
    if (name && name.toLowerCase() !== code) return name;
  } catch {
    // Unknown or malformed code — fall through.
  }
  return code.toUpperCase();
}

function listNames(codes: Iterable<string>): string {
  const names = Array.from(codes).map(languageName);
  if (names.length <= 1) return names.join("");
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

/** Friendly, creator-facing explanation for a request that can't be dubbed (no technical detail). */
export function dubbingLanguageMessage(check: DubbingLanguageCheck): string {
  const sources = dubbingSourceLanguages();
  const targets = dubbingTargetLanguages();
  if (!check.sourceSupported && sources) {
    return `Audio dubbing is available for videos in ${listNames(sources)} for now. Subtitles are still available for this video.`;
  }
  if (check.unsupportedTargets.length > 0 && targets) {
    return `Audio dubbing is available in ${listNames(targets)} for now. Please remove ${listNames(check.unsupportedTargets)} from your dubbing languages. Subtitles are still available in every language.`;
  }
  return "Audio dubbing isn't available for this video right now.";
}

/** Notice shown when the worker skips a language that is outside the launch list (charge refunded). */
export function launchUnsupportedNotice(source: unknown, target: unknown): string {
  const targetName = languageName(baseLanguageCode(target));
  if (!isDubbingSourceLanguage(source)) {
    const sources = dubbingSourceLanguages();
    return `We didn't create a ${targetName} audio track because audio dubbing is available only for videos in ${sources ? listNames(sources) : "supported languages"} for now. ${targetName} subtitles are ready, and your dubbing charge for this language has been refunded to your wallet.`;
  }
  return `We didn't create a ${targetName} audio track because ${targetName} audio dubbing is not available yet. ${targetName} subtitles are ready, and your dubbing charge for this language has been refunded to your wallet.`;
}

/** The lists the app shows, from the same settings the server enforces. */
export function dubbingLanguagesForClient(): { sourceLanguages: string[] | "all"; targetLanguages: string[] | "all" } {
  const s = dubbingSourceLanguages();
  const t = dubbingTargetLanguages();
  return { sourceLanguages: s ? Array.from(s) : "all", targetLanguages: t ? Array.from(t) : "all" };
}
