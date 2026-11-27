/**
 * 🌍 SUBTITLE LANGUAGE PROFILES (Netflix / BBC / EBU-TT Standard)
 *
 * Provides language- and script-aware constraints for subtitle timing,
 * reading speed (CPS), line length (CPL), and segmentation rules.
 */

export interface SubtitleLanguageProfile {
  languageCode: string;
  languageName: string;
  scriptFamily: "latin" | "indic" | "cjk" | "arabic" | "cyrillic" | "other";
  maxLines: number;
  maxCharactersPerLine: number;
  preferredReadingSpeedCps: number;
  maxReadingSpeedCps: number;
  minimumCueDurationMs: number;
  maximumCueDurationMs: number;
  minInterCueGapMs: number;
  minInterCueGapFrames?: number; // Configurable frame-based gap (e.g. 2 frames)
  segmentationStrategy: "clause" | "syntactic" | "indic_postpositional" | "cjk_phrased";
  punctuationBreakRules: RegExp[];
  protectedWordPatterns: RegExp[];
  /**
   * How two speakers in one subtitle are marked (Netflix "Dual Speakers"):
   *  - "dash": hyphen without a space on each line ("-Are you coming?" / "-In a minute.")
   *  - "dash_space": hyphen and a space on each line (Brazilian Portuguese, Basque)
   *  - "dash_second_only": hyphen without a space on the second speaker's line only (Dutch)
   * Default "dash".
   */
  dualSpeakerStyle?: "dash" | "dash_space" | "dash_second_only";
  /** Song lyrics: "italic" (most Netflix guides) or "plain" (e.g. Chinese). Default "italic". */
  lyricsStyle?: "italic" | "plain";
  /** Words that should not end the first line of a two-line subtitle (articles, prepositions, conjunctions). */
  weakLineEndWords?: string[];
}

/**
 * Netflix Timed Text Style Guide, General Requirements: maximum 7 seconds per subtitle event
 * (minimum 5/6 s, 2-frame gap, 2 lines). Per-language profiles below keep their own minimums.
 */
export const NETFLIX_MAX_CUE_DURATION_MS = 7000;

/**
 * Languages with official, published Netflix Timed Text Style Guides (TTSG).
 * These 22 languages have authoritative Netflix rules for CPL, CPS, min/max duration, and line breaking.
 */
export const NETFLIX_OFFICIAL_TTSG_LANGUAGES = [
  "en", "es", "fr", "de", "it", "pt", "ja", "zh", "ko", "th", "ar", "ru",
  "hi", "ta", "te", "kn", "ml", "bn", "mr", "nl", "pl", "tr",
] as const;

export type NetflixOfficialLanguageCode = typeof NETFLIX_OFFICIAL_TTSG_LANGUAGES[number];

/**
 * TruthWorld regional Indic expansion languages (Eighth Schedule languages).
 * Note: Netflix does not publish individual Timed Text Style Guides for these regional languages;
 * they follow TruthWorld / Doordarshan broadcast standards with Indic conjunct formatting.
 */
export const TRUTHWORLD_REGIONAL_INDIC_LANGUAGES = [
  "gu", "pa", "or", "as", "ur",
] as const;

export type TruthWorldRegionalIndicLanguageCode = typeof TRUTHWORLD_REGIONAL_INDIC_LANGUAGES[number];

/**
 * The 22 primary broadcast languages supported by TruthWorld for localized subtitles:
 * 13 Indian languages (including the major Eighth Schedule languages) + 9 major global languages.
 */
export const NETFLIX_22_LANGUAGES = [
  "en", "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or", "as", "ur",
  "es", "fr", "de", "pt", "ja", "zh", "ar", "ru", "it",
] as const;

export type Netflix22LanguageCode = typeof NETFLIX_22_LANGUAGES[number];

/**
 * Calculates frame-rate aware inter-cue gap.
 * e.g. 2 frames at 24fps = 83ms; 2 frames at 30fps = 66ms; 2 frames at 25fps = 80ms.
 */
export function calculateMinInterCueGapMs(
  fps: number = 30,
  profile?: SubtitleLanguageProfile
): number {
  const frames = profile?.minInterCueGapFrames ?? 2;
  const safeFps = fps > 0 ? fps : 30;
  return Math.max(33, Math.round(frames * (1000 / safeFps)));
}

const DEFAULT_LATIN_PROFILE: SubtitleLanguageProfile = {
  languageCode: "en",
  languageName: "English",
  scriptFamily: "latin",
  maxLines: 2,
  maxCharactersPerLine: 42,
  preferredReadingSpeedCps: 16.0,
  maxReadingSpeedCps: 20.0,
  minimumCueDurationMs: 833, // 5/6th second broadcast threshold
  maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
  minInterCueGapMs: 66, // 2 frames at 30fps
  segmentationStrategy: "clause",
  punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
  weakLineEndWords: [
    "a", "an", "the", "of", "to", "in", "on", "at", "for", "with", "from", "by", "and", "or", "but",
    "my", "your", "his", "her", "our", "their", "its", "this", "that", "Mr.", "Mrs.", "Ms.", "Dr.",
  ],
  protectedWordPatterns: [
    /^\b(?:Mr|Mrs|Ms|Dr|Prof|Gov|Pres)\.\s*\w+$/i,
    /^\b\d+(?:[\.,]\d+)?\s*(?:%|percent|USD|INR|EUR|km|kg|mph)\b/i,
    /^\b[A-Za-z0-9]+-[A-Za-z0-9]+\b/, // Compound words: Fact-Checking, zero-emission
  ],
};

const PROFILES: Record<string, SubtitleLanguageProfile> = {
  en: DEFAULT_LATIN_PROFILE,
  es: {
    languageCode: "es",
    languageName: "Spanish",
    scriptFamily: "latin",
    maxLines: 2,
    maxCharactersPerLine: 42,
    preferredReadingSpeedCps: 17.0,
    maxReadingSpeedCps: 21.0,
    minimumCueDurationMs: 833,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!¡¿]/, /[,;:—–]/],
    protectedWordPatterns: [
      /^\b(?:Sr|Sra|Srta|Dr|Dra)\.\s*\w+$/i,
      /^\b\d+(?:[\.,]\d+)?\s*(?:%|km|kg|USD|EUR)\b/i,
      /^\b[A-Za-z0-9]+-[A-Za-z0-9]+\b/,
    ],
  },
  te: {
    languageCode: "te",
    languageName: "Telugu",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 35,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000, // Indic conjuncts require slightly longer visual recognition
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [
      /^\b(?:గారు|యొక్క|వద్ద|నుండి|ద్వారా|తో|లో)\b/,
      /^\b\d+(?:[\.,]\d+)?\s*(?:%|శాతం|రూపాయలు|కోట్లు|లక్షలు)\b/,
    ],
  },
  hi: {
    languageCode: "hi",
    languageName: "Hindi",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 12.0,
    maxReadingSpeedCps: 15.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [
      /^\b(?:श्री|श्रीमती|डॉ|प्रोफेसर)\s*\w+$/i,
      /^\b(?:के|की|का|को|से|में|पर|द्वारा|लिए)\b/,
      /^\b\d+(?:[\.,]\d+)?\s*(?:%|प्रतिशत|रुपये|करोड़|लाख)\b/,
    ],
  },
  ta: {
    languageCode: "ta",
    languageName: "Tamil",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 34,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [
      /^(?:திரு|திருமதி|டாக்டர்|பேராசிரியர்)\s*\S+$/,
      /^(?:அவர்கள்|உடைய|இருந்து|மூலம்|உடன்|பற்றி)$/,
      /^\d+(?:[.,]\d+)?\s*(?:%|சதவீதம்|ரூபாய்|கோடி|இலட்சம்|லட்சம்)$/,
    ],
  },
  kn: {
    languageCode: "kn",
    languageName: "Kannada",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 35,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  ml: {
    languageCode: "ml",
    languageName: "Malayalam",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 32, // Very long compound words
    preferredReadingSpeedCps: 10.0,
    maxReadingSpeedCps: 13.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [
      /^(?:ശ്രീ|ശ്രീമതി|ഡോ\.?|പ്രൊഫസർ)\s*\S+$/,
      /^(?:യുടെ|ൽ|നിന്ന്|വഴി|കൂടി|കുറിച്ച്)$/,
      /^\d+(?:[.,]\d+)?\s*(?:%|ശതമാനം|രൂപ|കോടി|ലക്ഷം)$/,
    ],
  },
  bn: {
    languageCode: "bn",
    languageName: "Bengali",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 12.0,
    maxReadingSpeedCps: 15.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  mr: {
    languageCode: "mr",
    languageName: "Marathi",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 12.0,
    maxReadingSpeedCps: 15.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [
      /^(?:श्री|श्रीमती|डॉ\.?|प्रा\.)\s*\S+$/,
      /^(?:च्या|ची|चा|चे|ला|ना|मध्ये|वर|पासून|साठी|द्वारे)$/,
      /^\d+(?:[.,]\d+)?\s*(?:%|टक्के|रुपये|कोटी|लाख|लक्ष)$/,
    ],
  },
  gu: {
    languageCode: "gu",
    languageName: "Gujarati",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  pa: {
    languageCode: "pa",
    languageName: "Punjabi",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  or: {
    languageCode: "or",
    languageName: "Odia",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  as: {
    languageCode: "as",
    languageName: "Assamese",
    scriptFamily: "indic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 11.0,
    maxReadingSpeedCps: 14.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  ur: {
    languageCode: "ur",
    languageName: "Urdu",
    scriptFamily: "arabic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 12.0,
    maxReadingSpeedCps: 15.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.؟!؛]/, /[,،]/],
    protectedWordPatterns: [],
  },
  fr: {
    languageCode: "fr",
    languageName: "French",
    scriptFamily: "latin",
    maxLines: 2,
    maxCharactersPerLine: 42,
    preferredReadingSpeedCps: 17.0,
    maxReadingSpeedCps: 20.0,
    minimumCueDurationMs: 833,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [/^\b(?:M|Mme|Mlle|Dr)\.\s*\w+$/i],
  },
  de: {
    languageCode: "de",
    languageName: "German",
    scriptFamily: "latin",
    maxLines: 2,
    maxCharactersPerLine: 42,
    preferredReadingSpeedCps: 14.0,
    maxReadingSpeedCps: 17.0, // Netflix German TTSG: 17 CPS adult, 13 CPS children
    minimumCueDurationMs: 833,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [/^\b(?:Herr|Frau|Dr|Prof)\.\s*\w+$/i],
  },
  it: {
    languageCode: "it",
    languageName: "Italian",
    scriptFamily: "latin",
    maxLines: 2,
    maxCharactersPerLine: 42,
    preferredReadingSpeedCps: 16.0,
    maxReadingSpeedCps: 20.0,
    minimumCueDurationMs: 833,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [/^\b(?:Sig|Sig\.ra|Dott|Prof)\.\s*\w+$/i],
  },
  pt: {
    languageCode: "pt",
    languageName: "Portuguese",
    scriptFamily: "latin",
    maxLines: 2,
    maxCharactersPerLine: 42,
    preferredReadingSpeedCps: 16.0,
    maxReadingSpeedCps: 20.0,
    minimumCueDurationMs: 833,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    dualSpeakerStyle: "dash_space",
    protectedWordPatterns: [/^\b(?:Sr|Sra|Dr|Dra)\.\s*\w+$/i],
  },
  ru: {
    languageCode: "ru",
    languageName: "Russian",
    scriptFamily: "cyrillic",
    maxLines: 2,
    maxCharactersPerLine: 42,
    preferredReadingSpeedCps: 14.0,
    maxReadingSpeedCps: 17.0,
    minimumCueDurationMs: 833,
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  ja: {
    languageCode: "ja",
    languageName: "Japanese",
    scriptFamily: "cjk",
    maxLines: 2,
    maxCharactersPerLine: 13, // Netflix Japanese TTSG: 13 full-width characters per line (horizontal)
    preferredReadingSpeedCps: 10.0,
    maxReadingSpeedCps: 13.0, // Netflix Japanese TTSG: 13 CPS adult, 10 CPS children
    minimumCueDurationMs: 500, // Netflix Japanese TTSG: 500ms (0.5 seconds / 12 frames at 24fps)
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "cjk_phrased",
    punctuationBreakRules: [/[。！？]/, /[、，]/],
    protectedWordPatterns: [],
  },
  zh: {
    languageCode: "zh",
    languageName: "Chinese",
    scriptFamily: "cjk",
    maxLines: 2,
    maxCharactersPerLine: 16, // Netflix Chinese TTSG: 16 full-width characters per line
    preferredReadingSpeedCps: 9.0,
    maxReadingSpeedCps: 12.0, // Netflix Chinese TTSG: 12 CPS adult, 9 CPS children
    minimumCueDurationMs: 500, // Netflix Chinese TTSG: 500ms (0.5 seconds / 12 frames at 24fps)
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "cjk_phrased",
    punctuationBreakRules: [/[。！？]/, /[、，]/],
    protectedWordPatterns: [],
  },
  ko: {
    languageCode: "ko",
    languageName: "Korean",
    scriptFamily: "cjk",
    maxLines: 2,
    maxCharactersPerLine: 16, // Netflix Korean TTSG: 16 characters per line
    preferredReadingSpeedCps: 9.0,
    maxReadingSpeedCps: 12.0, // Netflix Korean TTSG: 12 CPS adult
    minimumCueDurationMs: 500, // Netflix Korean TTSG: 500ms (0.5 seconds)
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "cjk_phrased",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  th: {
    languageCode: "th",
    languageName: "Thai",
    scriptFamily: "other",
    maxLines: 2,
    maxCharactersPerLine: 39, // Netflix Thai TTSG: 39 characters per line
    preferredReadingSpeedCps: 13.0,
    maxReadingSpeedCps: 16.0, // Netflix Thai TTSG: 16 CPS adult
    minimumCueDurationMs: 833, // Netflix Thai TTSG: 5/6 second
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [],
  },
  ar: {
    languageCode: "ar",
    languageName: "Arabic",
    scriptFamily: "arabic",
    maxLines: 2,
    maxCharactersPerLine: 37, // Netflix Arabic TTSG: 37 characters per line
    preferredReadingSpeedCps: 12.0,
    maxReadingSpeedCps: 15.0, // Netflix Arabic TTSG: 15 CPS adult
    minimumCueDurationMs: 833, // Netflix Arabic TTSG: 5/6 second (833ms)
    maximumCueDurationMs: NETFLIX_MAX_CUE_DURATION_MS,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.؟!؛]/, /[,،]/],
    protectedWordPatterns: [],
  },
};

/**
 * Per-language Netflix conventions that differ from the defaults (from each language's
 * Netflix Timed Text Style Guide): dual-speaker hyphen style and song-lyric styling.
 */
const NETFLIX_STYLE_OVERRIDES: Record<string, Partial<SubtitleLanguageProfile>> = {
  pt: { dualSpeakerStyle: "dash_space" },        // Brazilian Portuguese: hyphen followed by a space
  eu: { dualSpeakerStyle: "dash_space" },        // Basque: hyphen followed by a space
  nl: { dualSpeakerStyle: "dash_second_only" },  // Dutch: hyphen on the second speaker only
  zh: { lyricsStyle: "plain" },                  // Chinese: no italics or quotes for lyrics
};

/**
 * Returns the language profile for the requested language code,
 * falling back to default Latin or Indic based on code pattern.
 */
export function getSubtitleProfile(langCode: string): SubtitleLanguageProfile {
  const code = (langCode || "en").toLowerCase().split(/[-_]/)[0];
  const overrides = NETFLIX_STYLE_OVERRIDES[code] || {};
  return { ...resolveBaseProfile(code), ...overrides };
}

function resolveBaseProfile(code: string): SubtitleLanguageProfile {
  if (PROFILES[code]) {
    return PROFILES[code];
  }
  // Check if it's an Indic language code
  const isIndic = ["as", "or", "pa", "gu", "sd", "ks", "sa"].includes(code);
  if (isIndic) {
    return {
      ...PROFILES.hi,
      languageCode: code,
      languageName: code,
    };
  }
  // Default fallback
  return {
    ...DEFAULT_LATIN_PROFILE,
    languageCode: code,
    languageName: code,
  };
}

/**
 * Calculates grapheme length accurately (handling Indic conjuncts and Unicode surrogate pairs).
 */
export function getGraphemeCount(text: string): number {
  if (!text) return 0;
  if (typeof Intl !== "undefined" && (Intl as any).Segmenter) {
    const segmenter = new (Intl as any).Segmenter(undefined, { granularity: "grapheme" });
    return Array.from(segmenter.segment(text)).length;
  }
  // Fallback for Node environments without full Intl Segmenter
  return Array.from(text).length;
}

/**
 * Characters a viewer actually reads in a cue: formatting tags (<i>, {\an8}) and line breaks
 * are not counted. Used for reading speed (CPS) and line length (CPL).
 */
export function getReadableCharCount(text: string): number {
  if (!text) return 0;
  const plain = text
    .replace(/<\/?[a-z][^>]*>/gi, "")
    .replace(/\{\\an\d\}/g, "")
    .replace(/\r?\n/g, " ");
  return getGraphemeCount(plain);
}
