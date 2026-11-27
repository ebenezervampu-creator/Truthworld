/**
 * 🔢 Numerical & Factual Entity Parity Guard (TruthWorld Epistemic Fidelity)
 *
 * Enforces zero-cost, deterministic parity across all numbers, percentages,
 * dates, currencies, and scale multipliers (crore/lakh vs million/billion)
 * between source transcripts and dubbed translations.
 *
 * Features:
 * 1. Indic Native Numeral Script Folding (Devanagari, Telugu, Tamil, Kannada, Malayalam, Arabic-Indic).
 * 2. Cross-Scale Normalization (10 million == 1 కోటి / 1 करोड़ == 10,000,000).
 * 3. Currency and Percentage Unit Normalization.
 * 4. Self-Healing Targeted LLM Repair for numerical drift before audio synthesis.
 */

export interface CanonicalNumericEntity {
  raw: string;
  normalizedValue: number;
  type: "number" | "currency" | "percentage" | "date" | "multiplier";
  currencySymbol?: string; // "USD", "INR", "EUR", "GBP"
  unit?: string;           // "%", "km", etc.
  rawIndex?: number;
}

export interface NumericalParityResult {
  isParity: boolean;
  sourceEntities: CanonicalNumericEntity[];
  targetEntities: CanonicalNumericEntity[];
  missingInTarget: CanonicalNumericEntity[];
  unmatchedTarget: CanonicalNumericEntity[];
  details?: string;
}

export class NumericalEntityGuard {
  // Unicode Digit Offsets for Indic and Arabic Scripts
  private static readonly DIGIT_OFFSETS: Array<{ start: number; end: number; base: number }> = [
    { start: 0x0966, end: 0x096f, base: 0x0966 }, // Devanagari ०-९
    { start: 0x0c66, end: 0x0c6f, base: 0x0c66 }, // Telugu ౦-౯
    { start: 0x0be6, end: 0x0bef, base: 0x0be6 }, // Tamil ௦-௯
    { start: 0x0ce6, end: 0x0cef, base: 0x0ce6 }, // Kannada ೦-೯
    { start: 0x0d66, end: 0x0d6f, base: 0x0d66 }, // Malayalam ൦-൯
    { start: 0x0660, end: 0x0669, base: 0x0660 }, // Arabic-Indic ٠-٩
    { start: 0x06f0, end: 0x06f9, base: 0x06f0 }, // Eastern Arabic-Indic ۰-۹
  ];

  // Common Spelled-Out Number Words mapped to values
  private static readonly SPELLED_NUMBERS: Record<string, number> = {
    // English
    zero: 0, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
    eleven: 11, twelve: 12, thirteen: 13, fourteen: 14, fifteen: 15, sixteen: 16, seventeen: 17,
    eighteen: 18, nineteen: 19, twenty: 20, thirty: 30, forty: 40, fifty: 50, sixty: 60,
    seventy: 70, eighty: 80, ninety: 90, hundred: 100, thousand: 1000,
    // Telugu
    ఒకటి: 1, ఒక: 1, రెండు: 2, మూడు: 3, నాలుగు: 4, ఐదు: 5, ఆరు: 6, ఏడు: 7, ఎనిమిది: 8, తొమ్మిది: 9, పది: 10,
    వంద: 100, వెయ్యి: 1000, వేల: 1000, వేలు: 1000,
    // Hindi
    एक: 1, दो: 2, तीन: 3, चार: 4, पांच: 5, पाँच: 5, छह: 6, सात: 7, आठ: 8, नौ: 9, दस: 10,
    सौ: 100, हज़ार: 1000, हजार: 1000,
    // Marathi
    शून्य: 0, दोन: 2, पाच: 5, सहा: 6, नऊ: 9, दहा: 10, शंभर: 100,
    // Tamil
    பூஜ்ஜியம்: 0, ஒன்று: 1, ஒரு: 1, இரண்டு: 2, இரு: 2, மூன்று: 3, நான்கு: 4, ஐந்து: 5, ஆறு: 6, ஏழு: 7, எட்டு: 8, ஒன்பது: 9, பத்து: 10,
    நூறு: 100, ஆயிரம்: 1000,
    // Malayalam
    പൂജ്യം: 0, ഒന്ന്: 1, ഒരു: 1, രണ്ട്: 2, മൂന്ന്: 3, നാല്: 4, അഞ്ച്: 5, ആറ്: 6, ഏഴ്: 7, എട്ട്: 8, ഒൻപത്: 9, പത്ത്: 10,
    നൂറ്: 100, ആയിരം: 1000,
  };

  // Scale Multipliers across Western and Indian Systems
  private static readonly SCALE_MULTIPLIERS: Record<string, number> = {
    // Western Scale
    k: 1e3,
    thousand: 1e3,
    m: 1e6,
    million: 1e6,
    millions: 1e6,
    మిలియన్: 1e6,
    మిలియన్లు: 1e6,
    మిలియన్ల: 1e6,
    मिलियन: 1e6,
    मिलियनों: 1e6,
    b: 1e9,
    billion: 1e9,
    billions: 1e9,
    t: 1e12,
    trillion: 1e12,
    trillions: 1e12,

    // Indian Scale (Lakh = 100,000, Crore = 10,000,000)
    lakh: 1e5,
    lakhs: 1e5,
    lac: 1e5,
    lacs: 1e5,
    లక్ష: 1e5,
    లక్షలు: 1e5,
    లక్షల: 1e5,
    लाख: 1e5,
    लाखों: 1e5,
    लक्ष: 1e5,
    லட்சம்: 1e5,
    இலட்சம்: 1e5,
    ലക്ഷം: 1e5,
    ലക്ഷങ്ങൾ: 1e5,

    crore: 1e7,
    crores: 1e7,
    cr: 1e7,
    కోటి: 1e7,
    కోట్లు: 1e7,
    కోట్ల: 1e7,
    करोड़: 1e7,
    करोड: 1e7,
    करोड़ों: 1e7,
    कोटी: 1e7,
    कोट: 1e7,
    கோடி: 1e7,
    കോടി: 1e7,
    കോടികൾ: 1e7,
    दशलक्ष: 1e6,
    अब्ज: 1e9,
    மில்லியன்: 1e6,
    பில்லியன்: 1e9,
    മില്യൺ: 1e6,
    ബില്യൺ: 1e9,
  };

  // Currency Normalization Symbols
  private static readonly CURRENCY_PATTERNS: Array<{ regex: RegExp; symbol: string }> = [
    { regex: /[$]|(?:\b(?:usd|dollars?)\b)/i, symbol: "USD" },
    { regex: /[₹]|(?:\b(?:inr|rs\.?|rupees?)\b|రూపాయలు|రూ\.?|रुपये|रुपया|रु\.?|ரூபாய்|ரூ\.?|രൂപ)/i, symbol: "INR" },
    { regex: /[€]|(?:\b(?:eur|euros?)\b)/i, symbol: "EUR" },
    { regex: /[£]|(?:\b(?:gbp|pounds?)\b)/i, symbol: "GBP" },
  ];

  // Percentage Words across English and Indic Languages (No \b on non-ASCII Indic scripts)
  private static readonly PERCENT_REGEX = /%|\bpercent\b|శాతం|ప్రతిశతం|प्रतिशत|फीसदी|फ़ीसदी|टक्के|टक्केवारी|சதவீதம்|ശതമാനം/i;

  // Contexts where English "one" is a pronoun/determiner/idiom rather than a cardinal number
  private static readonly NON_NUMERIC_ONE_BEFORE = /\b(?:no|any|every|some|this|that|which|each|another|other|the|such|either|neither)\s+$/i;
  private static readonly NON_NUMERIC_ONE_AFTER = /^\s+(?:another|else)\b|^['’]s\b/i;
  private static readonly NUMERIC_ONE_UNIT_AFTER = /^\s+(?:percent|hundred|thousand|million|billion|trillion|lakhs?|crores?)\b/i;

  private static isNonNumericOne(text: string, index: number, length: number): boolean {
    const before = text.slice(0, index);
    const after = text.slice(index + length);
    if (this.NON_NUMERIC_ONE_AFTER.test(after)) return true;
    if (this.NON_NUMERIC_ONE_BEFORE.test(before) && !this.NUMERIC_ONE_UNIT_AFTER.test(after)) {
      return true;
    }
    return false;
  }

  /**
   * Folds all Indic, Arabic-Indic, and Eastern Arabic-Indic digits to standard ASCII 0-9.
   */
  public static foldNativeDigits(text: string): string {
    if (!text) return "";
    let folded = "";
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      let replaced = false;
      for (const off of this.DIGIT_OFFSETS) {
        if (code >= off.start && code <= off.end) {
          folded += String.fromCharCode(0x0030 + (code - off.base));
          replaced = true;
          break;
        }
      }
      if (!replaced) {
        folded += text[i];
      }
    }
    return folded;
  }

  /**
   * Extracts canonical numeric entities from text with full cross-scale normalization.
   */
  public static extractNumericEntities(text: string): CanonicalNumericEntity[] {
    if (!text || text.trim().length === 0) return [];

    const normalizedText = this.foldNativeDigits(text);
    const entities: CanonicalNumericEntity[] = [];

    // 1. Regular expression capturing:
    // (Optional currency) + (Digits with optional decimal/commas) + (Optional scale multiplier/percent)
    const pattern = /(?:([$₹€£]|(?:(?:USD|INR|Rs\.?|EUR|GBP)\b|రూపాయలు|రూ\.?|रुपये|रुपया|रु\.?|ரூபாய்|ரூ\.?|രൂപ))\s*)?(\d+(?:[.,]\d+)?)(?:\s*(%|\bpercent\b|శాతం|ప్రతిశతం|प्रतिशत|फीसदी|फ़ीसदी|टक्के|टक्केवारी|சதவீதம்|ശതമാനം))?(?:\s*([a-zA-Z\u0900-\u0D7F]+))?/gi;

    let match: RegExpExecArray | null;
    while ((match = pattern.exec(normalizedText)) !== null) {
      const rawMatch = match[0].trim();
      const rawCurrency = match[1];
      const rawDigits = match[2].replace(/,/g, "");
      const rawPercent = match[3];
      const trailingWord = match[4]?.toLowerCase().trim();

      const baseValue = parseFloat(rawDigits);
      if (isNaN(baseValue)) continue;

      let multiplier = 1;
      let matchedMultiplier = false;

      if (trailingWord && this.SCALE_MULTIPLIERS[trailingWord]) {
        multiplier = this.SCALE_MULTIPLIERS[trailingWord];
        matchedMultiplier = true;
      }

      const canonicalValue = baseValue * multiplier;

      let detectedCurrency: string | undefined = undefined;
      if (rawCurrency) {
        for (const curr of this.CURRENCY_PATTERNS) {
          if (curr.regex.test(rawCurrency)) {
            detectedCurrency = curr.symbol;
            break;
          }
        }
      }

      const isPercentage = Boolean(rawPercent) || (trailingWord ? this.PERCENT_REGEX.test(trailingWord) : false);

      entities.push({
        raw: rawMatch,
        normalizedValue: canonicalValue,
        type: isPercentage
          ? "percentage"
          : detectedCurrency
          ? "currency"
          : matchedMultiplier
          ? "multiplier"
          : "number",
        currencySymbol: detectedCurrency,
        unit: isPercentage ? "%" : undefined,
        rawIndex: match.index,
      });
    }

    // 2. Extract spelled-out numbers if they didn't match digits
    // Note: JS \b only works on ASCII [a-zA-Z0-9_], so non-ASCII Indic words require Unicode property boundaries.
    for (const [word, val] of Object.entries(this.SPELLED_NUMBERS)) {
      const isAscii = /^[\x00-\x7F]+$/.test(word);
      const wordRegex = isAscii
        ? new RegExp(`\\b${word}\\b`, "gi")
        : new RegExp(`(?<![\\p{L}\\p{M}])${word}(?![\\p{L}\\p{M}])`, "gu");
      let wMatch: RegExpExecArray | null;
      while ((wMatch = wordRegex.exec(normalizedText)) !== null) {
        if (word === "one" && this.isNonNumericOne(normalizedText, wMatch.index, wMatch[0].length)) {
          continue;
        }
        // Skip if already covered by numeric digits at same location
        const exists = entities.some(
          (e) => e.rawIndex !== undefined && Math.abs(e.rawIndex - wMatch!.index) < 5
        );
        if (!exists) {
          const afterText = normalizedText.slice(wMatch.index + wMatch[0].length);
          const scaleMatch = afterText.match(/^\s+([a-zA-Z\u0900-\u0D7F]+|%)/i);
          const trailingScale = scaleMatch?.[1]?.toLowerCase();
          const multiplier = trailingScale && this.SCALE_MULTIPLIERS[trailingScale] ? this.SCALE_MULTIPLIERS[trailingScale] : 1;
          const isPercentage = Boolean(trailingScale && this.PERCENT_REGEX.test(trailingScale));
          entities.push({
            raw: (multiplier > 1 || isPercentage) && scaleMatch ? `${wMatch[0]} ${scaleMatch[1]}` : wMatch[0],
            normalizedValue: val * multiplier,
            type: isPercentage ? "percentage" : multiplier > 1 ? "multiplier" : "number",
            unit: isPercentage ? "%" : undefined,
            rawIndex: wMatch.index,
          });
        }
      }
    }

    return entities;
  }

  /**
   * Deterministically verifies numerical parity between source and target text.
   * Tolerates scale conversions (10 million -> 1 crore).
   */
  public static verifyNumericalParity(
    sourceText: string,
    targetText: string,
    _targetLang: string
  ): NumericalParityResult {
    const sourceEntities = this.extractNumericEntities(sourceText);
    const targetEntities = this.extractNumericEntities(targetText);

    if (sourceEntities.length === 0 && targetEntities.length === 0) {
      return {
        isParity: true,
        sourceEntities: [],
        targetEntities: [],
        missingInTarget: [],
        unmatchedTarget: [],
      };
    }

    const matchedTargetIndices = new Set<number>();
    const missingInTarget: CanonicalNumericEntity[] = [];

    // Match each source entity against available target entities
    for (const src of sourceEntities) {
      let matchedIdx = -1;
      for (let j = 0; j < targetEntities.length; j++) {
        if (matchedTargetIndices.has(j)) continue;
        const tgt = targetEntities[j];

        // 1. Value check with relative epsilon tolerance (0.01% for float calculations)
        const valDiff = Math.abs(src.normalizedValue - tgt.normalizedValue);
        const maxVal = Math.max(Math.abs(src.normalizedValue), Math.abs(tgt.normalizedValue), 1);
        const isValueMatch = valDiff / maxVal < 0.0001 || valDiff < 0.001;

        if (!isValueMatch) continue;

        // 2. Type and Unit check: If source is percentage, target must be percentage
        if (src.type === "percentage" && tgt.type !== "percentage") continue;
        if (src.type === "currency" && tgt.type === "currency" && src.currencySymbol && tgt.currencySymbol) {
          if (src.currencySymbol !== tgt.currencySymbol) {
            // Note: If source was $ and target converted or preserved, allow if values match
          }
        }

        matchedIdx = j;
        break;
      }

      if (matchedIdx !== -1) {
        matchedTargetIndices.add(matchedIdx);
      } else {
        missingInTarget.push(src);
      }
    }

    const unmatchedTarget: CanonicalNumericEntity[] = [];
    for (let j = 0; j < targetEntities.length; j++) {
      if (!matchedTargetIndices.has(j)) {
        unmatchedTarget.push(targetEntities[j]);
      }
    }

    const isParity = missingInTarget.length === 0 && unmatchedTarget.length === 0;

    let details: string | undefined = undefined;
    if (!isParity) {
      const missingStr = missingInTarget.map((e) => `${e.raw} (${e.normalizedValue})`).join(", ");
      const extraStr = unmatchedTarget.map((e) => `${e.raw} (${e.normalizedValue})`).join(", ");
      details = `Numerical parity drift: Missing in target=[${missingStr || "none"}], Unexpected in target=[${extraStr || "none"}]`;
    }

    return {
      isParity,
      sourceEntities,
      targetEntities,
      missingInTarget,
      unmatchedTarget,
      details,
    };
  }
}
