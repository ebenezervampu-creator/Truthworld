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
}

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
  maximumCueDurationMs: 6000,
  minInterCueGapMs: 66, // 2 frames at 30fps
  segmentationStrategy: "clause",
  punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
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
    maximumCueDurationMs: 6000,
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
    maximumCueDurationMs: 6000,
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
    maximumCueDurationMs: 6000,
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
    maximumCueDurationMs: 6000,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
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
    maximumCueDurationMs: 6000,
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
    maximumCueDurationMs: 6000,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
    protectedWordPatterns: [],
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
    maximumCueDurationMs: 6000,
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
    maximumCueDurationMs: 6000,
    minInterCueGapMs: 66,
    segmentationStrategy: "indic_postpositional",
    punctuationBreakRules: [/[.?!।|]/, /[,;:—–]/],
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
    maximumCueDurationMs: 6000,
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
    maxCharactersPerLine: 40,
    preferredReadingSpeedCps: 16.0,
    maxReadingSpeedCps: 19.0,
    minimumCueDurationMs: 833,
    maximumCueDurationMs: 6000,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.?!]/, /[,;:—–]/],
    protectedWordPatterns: [/^\b(?:Herr|Frau|Dr|Prof)\.\s*\w+$/i],
  },
  ja: {
    languageCode: "ja",
    languageName: "Japanese",
    scriptFamily: "cjk",
    maxLines: 2,
    maxCharactersPerLine: 16, // CJK ideographs
    preferredReadingSpeedCps: 7.0,
    maxReadingSpeedCps: 10.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: 6000,
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
    maxCharactersPerLine: 16,
    preferredReadingSpeedCps: 7.0,
    maxReadingSpeedCps: 10.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: 6000,
    minInterCueGapMs: 66,
    segmentationStrategy: "cjk_phrased",
    punctuationBreakRules: [/[。！？]/, /[、，]/],
    protectedWordPatterns: [],
  },
  ar: {
    languageCode: "ar",
    languageName: "Arabic",
    scriptFamily: "arabic",
    maxLines: 2,
    maxCharactersPerLine: 36,
    preferredReadingSpeedCps: 12.0,
    maxReadingSpeedCps: 16.0,
    minimumCueDurationMs: 1000,
    maximumCueDurationMs: 6000,
    minInterCueGapMs: 66,
    segmentationStrategy: "clause",
    punctuationBreakRules: [/[.؟!؛]/, /[,،]/],
    protectedWordPatterns: [],
  },
};

/**
 * Returns the language profile for the requested language code,
 * falling back to default Latin or Indic based on code pattern.
 */
export function getSubtitleProfile(langCode: string): SubtitleLanguageProfile {
  const code = (langCode || "en").toLowerCase().split(/[-_]/)[0];
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
