/**
 * 🌐 LANGUAGE NORMALIZER
 * 
 * Maps language names, aliases, and localized strings to canonical ISO 639-1 / 639-2 codes
 * for Google Cloud Translation v3, Speech-to-Text, and Dubbing APIs.
 */

export const LANGUAGE_NAME_TO_CODE: Record<string, string> = {
  // Global / Major
  english: "en",
  spanish: "es",
  french: "fr",
  german: "de",
  chinese: "zh",
  japanese: "ja",
  russian: "ru",
  portuguese: "pt",
  arabic: "ar",
  korean: "ko",
  italian: "it",
  turkish: "tr",
  vietnamese: "vi",
  thai: "th",
  indonesian: "id",
  dutch: "nl",
  polish: "pl",
  swedish: "sv",
  danish: "da",
  norwegian: "no",
  finnish: "fi",
  greek: "el",
  czech: "cs",
  hungarian: "hu",
  romanian: "ro",
  ukrainian: "uk",
  hebrew: "he",
  persian: "fa",
  farsi: "fa",
  filipino: "fil",
  tagalog: "tl",
  malay: "ms",

  // Indian Languages (Crucial for Truthworld)
  hindi: "hi",
  bengali: "bn",
  bangla: "bn",
  telugu: "te",
  tamil: "ta",
  marathi: "mr",
  gujarati: "gu",
  kannada: "kn",
  malayalam: "ml",
  punjabi: "pa",
  odia: "or",
  oriya: "or",
  assamese: "as",
  urdu: "ur",
  kashmiri: "ks",
  sindhi: "sd",
  sanskrit: "sa",
  nepali: "ne",
  sinhala: "si",
  burmese: "my",
  myanmar: "my",

  // European / Others
  afrikaans: "af",
  albanian: "sq",
  amharic: "am",
  armenian: "hy",
  azerbaijani: "az",
  basque: "eu",
  belarusian: "be",
  bosnian: "bs",
  bulgarian: "bg",
  catalan: "ca",
  cebuano: "ceb",
  chichewa: "ny",
  corsican: "co",
  croatian: "hr",
  esperanto: "eo",
  estonian: "et",
  frisian: "fy",
  galician: "gl",
  georgian: "ka",
  gujrati: "gu",
  haitian: "ht",
  hausa: "ha",
  hawaiian: "haw",
  hmong: "hmn",
  icelandic: "is",
  igbo: "ig",
  irish: "ga",
  javanese: "jv",
  kazakh: "kk",
  khmer: "km",
  kinyarwanda: "rw",
  kirghiz: "ky",
  kurdish: "ku",
  kyrgyz: "ky",
  lao: "lo",
  latin: "la",
  latvian: "lv",
  lingala: "ln",
  lithuanian: "lt",
  luxembourgish: "lb",
  macedonian: "mk",
  malagasy: "mg",
  maltese: "mt",
  maori: "mi",
  mongolian: "mn",
  nyanja: "ny",
  pashto: "ps",
  samoan: "sm",
  serbian: "sr",
  sesotho: "st",
  shona: "sn",
  slovak: "sk",
  slovenian: "sl",
  somali: "so",
  sundanese: "su",
  swahili: "sw",
  tajik: "tg",
  tatar: "tt",
  turkmen: "tk",
  uyghur: "ug",
  uzbek: "uz",
  welsh: "cy",
  xhosa: "xh",
  yiddish: "yi",
  yoruba: "yo",
  zulu: "zu",
};

/**
 * Normalizes any language string (full name, mixed-case, code) into a valid ISO code.
 * E.g. "Tamil" -> "ta", "TAMIL" -> "ta", "ta" -> "ta", "Hindi" -> "hi", "en" -> "en"
 */
export function normalizeLanguageCode(lang: string): string {
  if (!lang || typeof lang !== "string") return "en";
  let trimmed = lang.trim().toLowerCase();

  // If contains locale delimiter like en_us or en-US, split to base language code
  if (trimmed.includes("-") || trimmed.includes("_")) {
    const base = trimmed.split(/[-_]/)[0].toLowerCase();
    if (base.length >= 2 && base.length <= 3) {
      trimmed = base;
    }
  }

  // If already a valid 2 or 3 letter code in the values set
  if (trimmed.length >= 2 && trimmed.length <= 3) {
    return trimmed;
  }

  // Look up in name-to-code map
  return LANGUAGE_NAME_TO_CODE[trimmed] || trimmed;
}

/**
 * Normalizes an array of language inputs, ensuring deduplication and fallback.
 */
export function normalizeLanguageCodes(langs: string[]): string[] {
  if (!Array.isArray(langs)) return ["en"];
  const normalized = langs
    .map(normalizeLanguageCode)
    .filter((code) => code && code.length >= 2);
  
  return Array.from(new Set(normalized));
}

/**
 * 📜 Unicode Script Identification
 * Scans text (e.g. video title, description, tags, transcript) for authentic native scripts.
 * Returns candidate ISO 639-1 language codes with matching character count and script name.
 */
export interface ScriptMatchResult {
  language: string;
  script: string;
  matchCount: number;
}

export function detectScriptsFromText(text: string): ScriptMatchResult[] {
  if (!text || typeof text !== "string") return [];

  const scriptPatterns: Array<{ script: string; language: string; regex: RegExp }> = [
    { script: "Telugu", language: "te", regex: /[\u0C00-\u0C7F]/g },
    { script: "Tamil", language: "ta", regex: /[\u0B80-\u0BFF]/g },
    { script: "Kannada", language: "kn", regex: /[\u0C80-\u0CFF]/g },
    { script: "Malayalam", language: "ml", regex: /[\u0D00-\u0D7F]/g },
    { script: "Devanagari", language: "hi", regex: /[\u0900-\u097F]/g },
    { script: "Bengali", language: "bn", regex: /[\u0980-\u09FF]/g },
    { script: "Gujarati", language: "gu", regex: /[\u0A80-\u0AFF]/g },
    { script: "Gurmukhi", language: "pa", regex: /[\u0A00-\u0A7F]/g },
    { script: "Odia", language: "or", regex: /[\u0B00-\u0B7F]/g },
    { script: "Arabic", language: "ar", regex: /[\u0600-\u06FF\u0750-\u077F]/g },
    { script: "Japanese-Kana", language: "ja", regex: /[\u3040-\u309F\u30A0-\u30FF]/g },
    { script: "Hangul", language: "ko", regex: /[\uAC00-\uD7AF\u1100-\u11FF]/g },
    { script: "Hanzi", language: "zh", regex: /[\u4E00-\u9FFF]/g },
    { script: "Cyrillic", language: "ru", regex: /[\u0400-\u04FF]/g },
    { script: "Greek", language: "el", regex: /[\u0370-\u03FF]/g },
    { script: "Hebrew", language: "he", regex: /[\u0590-\u05FF]/g },
    { script: "Thai", language: "th", regex: /[\u0E00-\u0E7F]/g },
  ];

  const keywordPatterns: Array<{ script: string; language: string; regex: RegExp }> = [
    { script: "Telugu", language: "te", regex: /\b(?:telugu|telugulo|in telugu|#telugufacts|#telugu)\b/gi },
    { script: "Tamil", language: "ta", regex: /\b(?:tamil|in tamil|#tamil|#tamilfacts)\b/gi },
    { script: "Hindi", language: "hi", regex: /\b(?:hindi|hindime|in hindi|#hindi|#hindifacts)\b/gi },
    { script: "Kannada", language: "kn", regex: /\b(?:kannada|in kannada|#kannada)\b/gi },
    { script: "Malayalam", language: "ml", regex: /\b(?:malayalam|in malayalam|#malayalam)\b/gi },
    { script: "Bengali", language: "bn", regex: /\b(?:bengali|bangla|in bengali|#bengali)\b/gi },
    { script: "Marathi", language: "mr", regex: /\b(?:marathi|in marathi|#marathi)\b/gi },
    { script: "Gujarati", language: "gu", regex: /\b(?:gujarati|in gujarati|#gujarati)\b/gi },
    { script: "Spanish", language: "es", regex: /\b(?:spanish|en español|#spanish)\b/gi },
    { script: "French", language: "fr", regex: /\b(?:french|en français|#french)\b/gi },
    { script: "German", language: "de", regex: /\b(?:german|auf deutsch|#german)\b/gi },
    { script: "Japanese", language: "ja", regex: /\b(?:japanese|in japanese|#japanese)\b/gi },
  ];

  const results: ScriptMatchResult[] = [];
  for (const { script, language, regex } of scriptPatterns) {
    const matches = text.match(regex);
    if (matches && matches.length >= 2) {
      results.push({
        script,
        language,
        matchCount: matches.length,
      });
    }
  }

  for (const { script, language, regex } of keywordPatterns) {
    const matches = text.match(regex);
    if (matches && matches.length >= 1) {
      // Scale keyword match count to provide decisive evidence for regional content
      results.push({
        script: `${script}-Keyword`,
        language,
        matchCount: matches.length * 6,
      });
    }
  }

  return results.sort((a, b) => b.matchCount - a.matchCount);
}


/**
 * 🏷️ Language Code to Human-Friendly Native Name Mapping
 */
export const LANGUAGE_CODE_TO_NAME: Record<string, string> = {
  te: "Telugu (తెలుగు)",
  ta: "Tamil (தமிழ்)",
  kn: "Kannada (ಕನ್ನಡ)",
  ml: "Malayalam (മലയാളം)",
  hi: "Hindi (हिन्दी)",
  bn: "Bengali (বাংলা)",
  mr: "Marathi (मराठी)",
  gu: "Gujarati (ગુજરાતી)",
  pa: "Punjabi (ਪੰਜਾਬੀ)",
  or: "Odia (ଓଡ଼ିଆ)",
  ur: "Urdu (اردو)",
  ar: "Arabic (العربية)",
  fa: "Persian (فارسی)",
  es: "Spanish (Español)",
  fr: "French (Français)",
  de: "German (Deutsch)",
  ja: "Japanese (日本語)",
  ko: "Korean (한국어)",
  zh: "Chinese (中文)",
  ru: "Russian (Русский)",
  pt: "Portuguese (Português)",
  it: "Italian (Italiano)",
  tr: "Turkish (Türkçe)",
  vi: "Vietnamese (Tiếng Việt)",
  th: "Thai (ไทย)",
  id: "Indonesian (Bahasa Indonesia)",
  nl: "Dutch (Nederlands)",
  pl: "Polish (Polski)",
  sv: "Swedish (Svenska)",
  el: "Greek (Ελληνικά)",
  he: "Hebrew (עברית)",
  en: "English",
};

/**
 * Returns human-friendly name with native script for prompts (e.g. "te" -> "Telugu (తెలుగు)")
 */
export function getLanguageDisplayName(code: string): string {
  const norm = normalizeLanguageCode(code);
  return LANGUAGE_CODE_TO_NAME[norm] || norm.toUpperCase();
}

/**
 * 🔍 Summary Language Mismatch Detector
 * Returns true if the summary text is in a different language/script than the target language.
 * E.g., an English summary for a Telugu or Hindi video returns true (mismatch),
 * triggering automatic regeneration in the video's authentic native language.
 */
export function isSummaryLanguageMismatch(summaryText?: string, targetLanguage?: string): boolean {
  if (!summaryText || typeof summaryText !== "string") return false;
  const trimmed = summaryText.trim();
  if (trimmed.length < 10) return false;

  const targetLang = normalizeLanguageCode(targetLanguage || "");
  if (!targetLang) return false;

  const nonLatinScriptPatterns: Array<{ langGroup: string[]; regex: RegExp }> = [
    { langGroup: ["te"], regex: /[\u0C00-\u0C7F]/g },
    { langGroup: ["ta"], regex: /[\u0B80-\u0BFF]/g },
    { langGroup: ["kn"], regex: /[\u0C80-\u0CFF]/g },
    { langGroup: ["ml"], regex: /[\u0D00-\u0D7F]/g },
    { langGroup: ["hi", "mr", "ne", "sa"], regex: /[\u0900-\u097F]/g },
    { langGroup: ["bn", "as"], regex: /[\u0980-\u09FF]/g },
    { langGroup: ["gu"], regex: /[\u0A80-\u0AFF]/g },
    { langGroup: ["pa"], regex: /[\u0A00-\u0A7F]/g },
    { langGroup: ["or"], regex: /[\u0B00-\u0B7F]/g },
    { langGroup: ["ar", "fa", "ur"], regex: /[\u0600-\u06FF\u0750-\u077F]/g },
    { langGroup: ["ja"], regex: /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/g },
    { langGroup: ["ko"], regex: /[\uAC00-\uD7AF\u1100-\u11FF]/g },
    { langGroup: ["zh"], regex: /[\u4E00-\u9FFF]/g },
    { langGroup: ["ru", "uk", "be", "bg"], regex: /[\u0400-\u04FF]/g },
    { langGroup: ["el"], regex: /[\u0370-\u03FF]/g },
    { langGroup: ["he"], regex: /[\u0590-\u05FF]/g },
    { langGroup: ["th"], regex: /[\u0E00-\u0E7F]/g },
  ];

  // Case 1: Target language is English ("en")
  if (targetLang === "en") {
    // If target is English, but summary has substantial non-Latin script, it's a mismatch
    for (const { regex } of nonLatinScriptPatterns) {
      const matches = trimmed.match(regex);
      if (matches && matches.length >= 15) {
        return true;
      }
    }
    return false;
  }

  // Case 2: Target language is a non-Latin script language (e.g. "te", "hi", "ta", "ar", etc.)
  const matchedScriptGroup = nonLatinScriptPatterns.find((item) =>
    item.langGroup.includes(targetLang)
  );

  if (matchedScriptGroup) {
    const nativeMatches = trimmed.match(matchedScriptGroup.regex);
    const nativeCount = nativeMatches ? nativeMatches.length : 0;
    const latinMatches = trimmed.match(/[a-zA-Z]/g);
    const latinCount = latinMatches ? latinMatches.length : 0;

    // If native characters are less than 3, and Latin letters are prominent (> 15), it is a mismatch
    if (nativeCount < 3 && latinCount > 15) {
      return true;
    }
  }

  // Case 3: Target language is non-English, but summary begins with classic English narrative openers
  const englishOpenerRegex = /^(This video|In this video|The video|The creator|This clip|Here is|Summary:|A comprehensive|This episode)\b/i;
  if (targetLang !== "en" && englishOpenerRegex.test(trimmed)) {
    return true;
  }

  return false;
}
