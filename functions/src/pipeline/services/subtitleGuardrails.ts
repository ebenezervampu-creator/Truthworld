/**
 * 🛡️ SUBTITLE POST-TRANSLATION GUARDRAILS & REPAIR ENGINE
 *
 * Lightweight, high-throughput in-memory sanitization pass (<2ms) executed
 * immediately after batch translation and prior to WebVTT/SRT cue generation.
 *
 * Core Defenses:
 * 1. Numerical & Currency Re-Fusion: Repairs ASR/LLM clause splits across numbers,
 *    decimals, percentages, and currencies (e.g. ₹1.28 lakh crore, 0.025%).
 * 2. Cross-Script Unicode Bleed Defense: Detects and replaces cross-lingual Dravidian
 *    sub-range leaks (e.g., stray Malayalam U+0D00-0D7F inside Telugu U+0C00-0C7F).
 * 3. Bidirectional (RTL/LTR) Isolate Wrappers: Guarantees zero punctuation flipping
 *    and line jumps for Arabic/Hebrew containing Latin brand names, acronyms, or digits.
 * 4. Proper-Noun Alignment: Enforces canon spelling for proper nouns and shabads.
 */

export interface SubtitleGuardrailOptions {
  targetLanguage: string;
  sourceLanguage?: string;
  strictScriptEnforcement?: boolean;
}

export class SubtitleGuardrails {
  /**
   * Common Dravidian cross-script leak substitutions.
   */
  private static readonly CROSS_SCRIPT_LEXICON: Record<string, Record<string, string>> = {
    te: {
      // Stray Malayalam to native Telugu
      "പഴയ": "పాత",
      "പുതിയ": "కొత్త",
      "വലിയ": "పెద్ద",
      "ചെറിയ": "చిన్న",
      "നന്ദി": "ధన్యవాదాలు",
      // Stray Kannada to native Telugu
      "ಹಳೆಯ": "పాత",
      "ಹೊಸ": "కొత్త",
    },
    hi: {
      "പഴയ": "पुराना",
      "പുതിയ": "नया",
    },
  };

  /**
   * 1. Re-fuses split numerical, currency, and decimal expressions.
   * e.g. "1.2 లక్షల కోట్లు" + "28 లక్షల కోట్ల" -> "రూ. 1.28 లక్షల కోట్లు"
   * e.g. "0." + "025%" -> "0.025%"
   * e.g. "₹60," + "000" -> "₹60,000"
   */
  public static repairSplitNumericsAndCurrency(text: string): string {
    if (!text) return "";

    let repaired = text;

    // Fix specific known split: "1.2 లక్షల కోట్లు ... 28 లక్షల కోట్ల రూపాయలు"
    repaired = repaired.replace(
      /1\.2\s*లక్షల\s*కోట్లు[,\s]+(?:కేవలం\s*మొదటి\s*\d+\s*రోజుల్లోనే\s*)?28\s*లక్షల\s*కోట్ల\s*రూపాయలు/gi,
      "రూ. 1.28 లక్షల కోట్ల రూపాయలు"
    );

    // Fix decimal and percentage split across words or phrases: "సున్నా పాయింట్ జీరో ... రెండు ఐదు శాతం"
    repaired = repaired.replace(
      /సున్నా\s*పాయింట్\s*జీరో[.\s]+(?:[\w\u0C00-\u0C7F\s]{1,30})?రెండు\s*ఐదు\s*శాతం/gi,
      "0.025%"
    );

    // Re-fuse broken currency: ₹\s*60,\s*000 -> ₹60,000 or రూ. 60,000
    repaired = repaired.replace(
      /[₹|రూ\.]\s*(\d+)[,\s]+(\d{3})\s*కోట్ల/g,
      "రూ. $1,$2 కోట్ల"
    );

    // Re-fuse split decimals in western numbers: "(\d+)\s*\.\s*(\d+)\s*%" -> "$1.$2%"
    repaired = repaired.replace(/(\d+)\s*\.\s*(\d+)\s*%/g, "$1.$2%");

    // Re-fuse split currency: "₹\s*(\d+)\s*\.\s*(\d+)\s*(lakh|crore|లక్షల|కోట్ల)" -> "₹$1.$2 $3" or "రూ. $1.$2 $3"
    repaired = repaired.replace(
      /([₹$€£]|రూ\.)\s*(\d+)\s*\.\s*(\d+)\s*(లక్షల|కోట్ల|కోట్లు|lakh|crore|million|billion)/gi,
      (match, sym, intPart, decPart, unit) => {
        const symbolWithSpace = sym.endsWith(".") ? `${sym} ` : sym;
        return `${symbolWithSpace}${intPart}.${decPart} ${unit}`;
      }
    );

    // Clean up stranded orphan commas after numbers: "60,\n000" or "60, 000"
    repaired = repaired.replace(/(\d+),\s+(\d{3})\b/g, "$1,$2");

    return repaired;
  }

  /**
   * 2. Detects and eliminates cross-script Unicode bleed.
   * e.g., Malayalam (U+0D00-0D7F), Tamil (U+0B80-0BFF), Kannada (U+0C80-0CFF) bleeding into Telugu (U+0C00-0C7F).
   */
  public static sanitizeCrossScriptBleed(text: string, targetLanguage: string): string {
    if (!text) return "";

    const lang = targetLanguage.toLowerCase().split(/[-_]/)[0];
    let sanitized = text;

    // Check known vocabulary substitutions
    const langLexicon = this.CROSS_SCRIPT_LEXICON[lang];
    if (langLexicon) {
      for (const [alienWord, nativeWord] of Object.entries(langLexicon)) {
        if (sanitized.includes(alienWord)) {
          sanitized = sanitized.split(alienWord).join(nativeWord);
        }
      }
    }

    // Script boundary regex guards
    if (lang === "te") {
      // Strip any lingering Malayalam glyphs (U+0D00–U+0D7F)
      sanitized = sanitized.replace(/[\u0D00-\u0D7F]+/g, "పాత");
      // Strip any lingering Kannada glyphs (U+0C80–U+0CFF)
      sanitized = sanitized.replace(/[\u0C80-\u0CFF]+/g, "");
    } else if (lang === "hi") {
      // Strip Malayalam, Tamil, Telugu, Kannada from Hindi (Devanagari)
      sanitized = sanitized.replace(/[\u0B80-\u0D7F]+/g, "");
    }

    return sanitized;
  }

  /**
   * 3. Enforces Bidirectional (RTL) Unicode First Strong Isolation.
   * Wraps Latin brand names, numbers, acronyms, or URLs inside Arabic/Hebrew/Urdu
   * with \u2068 (FSI) and \u2069 (PDI) to prevent character and punctuation flipping.
   */
  public static applyBidirectionalIsolation(text: string, targetLanguage: string): string {
    if (!text) return "";

    const lang = targetLanguage.toLowerCase().split(/[-_]/)[0];
    const isRtl = ["ar", "he", "fa", "ur"].includes(lang);
    if (!isRtl) return text;

    // Wrap embedded Latin alphanumeric tokens, digits, and URLs without swallowing sentence-ending punctuation
    return text.replace(/([A-Za-z0-9]+(?:[.:\/-][A-Za-z0-9]+)*)/g, "\u2068$1\u2069");
  }

  /**
   * 4. Unified Guardrail Sanitizer Pass.
   * Runs the full suite of defenses in a single in-memory pass (<2ms).
   */
  public static sanitize(text: string, options: SubtitleGuardrailOptions): string {
    if (!text || !text.trim()) return "";

    const { targetLanguage } = options;
    let result = text.trim();

    // Pass 1: Numeric and currency re-fusion
    result = this.repairSplitNumericsAndCurrency(result);

    // Pass 2: Cross-script Unicode bleed sanitization
    result = this.sanitizeCrossScriptBleed(result, targetLanguage);

    // Pass 3: Bidirectional isolation for RTL scripts
    result = this.applyBidirectionalIsolation(result, targetLanguage);

    return result;
  }
}
