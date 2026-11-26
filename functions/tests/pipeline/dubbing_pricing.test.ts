/**
 * Character-based dubbing price: $0.30 per 1K dubbed characters, minimum $0.30 per minute.
 * See dubbing-pricing.ts; profit rule in dubbing-economics.ts.
 */
import { netRevenueUsd, planDubBudget, profitFloorUsd } from "../../src/pipeline/services/dubbing-economics";
import {
  CHAR_LENGTH_FACTOR,
  estimateDubbedChars,
  minutePriceUsd,
  quoteDubbing,
  quoteLanguage,
  transcriptCharacters,
  UNKNOWN_LENGTH_FACTOR,
} from "../../src/pipeline/services/dubbing-pricing";

describe("quoteLanguage", () => {
  test("typical 10-minute English video into Hindi stays at $3 (minute price)", () => {
    const q = quoteLanguage(600, 9000, "en", "hi");
    expect(q.estimatedChars).toBe(9900);
    expect(q).toMatchObject({ minutePriceUsd: 3, priceUsd: 3, basis: "minutes" });
  });

  test("talk-heavy English into Malayalam is priced on characters", () => {
    const q = quoteLanguage(600, 13000, "en", "ml");
    expect(q.estimatedChars).toBe(18850);
    expect(q.characterPriceUsd).toBe(5.66);
    expect(q).toMatchObject({ priceUsd: 5.66, basis: "characters" });
  });

  test("Chinese text is short, so a Chinese dub stays at the minute price", () => {
    expect(quoteLanguage(600, 13000, "en", "zh")).toMatchObject({ priceUsd: 3, basis: "minutes" });
  });

  test("non-English source uses the ratio of the two languages", () => {
    expect(estimateDubbedChars(10000, "hi", "ml")).toBe(Math.ceil((10000 * 1.45) / 1.1));
    expect(estimateDubbedChars(10000, "xx", "en")).toBe(Math.ceil(10000 / UNKNOWN_LENGTH_FACTOR));
    expect(estimateDubbedChars(10000, "en", "xx")).toBe(Math.ceil(10000 * UNKNOWN_LENGTH_FACTOR));
    expect(estimateDubbedChars(0, "en", "hi")).toBe(0);
  });

  test("minute price matches the existing per-minute pricing (60-second minimum)", () => {
    expect(minutePriceUsd(600)).toBe(3);
    expect(minutePriceUsd(20)).toBe(0.3);
    expect(minutePriceUsd(0)).toBe(0.3);
    expect(minutePriceUsd(90)).toBe(0.45);
  });

  test("character price rounds up to the cent, never down", () => {
    expect(quoteLanguage(60, 3334, "en", "en").characterPriceUsd).toBe(1.01); // 1.0002 → 1.01
  });
});

describe("quoteDubbing", () => {
  test("sums languages, skips the source language and duplicates, applies a discount", () => {
    const q = quoteDubbing({ durationSec: 600, sourceChars: 13000, sourceLanguage: "en", targetLanguages: ["hi", "ml", "en", "ML"], discountPercent: 10 });
    expect(q.languages.map((l) => l.language)).toEqual(["hi", "ml"]);
    expect(q.subtotalUsd).toBe(Math.round((q.languages[0].priceUsd + q.languages[1].priceUsd) * 100) / 100);
    expect(q.totalUsd).toBe(Math.round(q.subtotalUsd * 0.9 * 100) / 100);
  });

  test("same transcript, same quote (what the creator sees is what the server charges)", () => {
    const input = { durationSec: 754, sourceChars: 11873, sourceLanguage: "en", targetLanguages: ["te", "ta"] };
    expect(quoteDubbing(input)).toEqual(quoteDubbing({ ...input }));
  });
});

describe("transcriptCharacters", () => {
  test("counts utterance text with whitespace collapsed; falls back to text", () => {
    expect(transcriptCharacters({ utterances: [{ text: "Hello  world." }, { text: " Bye" }] })).toBe("Hello world. Bye".length);
    expect(transcriptCharacters({ text: "a  b" })).toBe(3);
    expect(transcriptCharacters(null)).toBe(0);
    expect(transcriptCharacters({ utterances: [{ text: 5 as any }] })).toBe(0);
  });
});

describe("business rule: the price always keeps the profit share", () => {
  // Every target language, from English, at speech densities from sparse to very talk-heavy.
  const targets = Object.keys(CHAR_LENGTH_FACTOR).filter((l) => l !== "en");
  const densities = [300, 900, 1300, 1800, 2200]; // source characters per minute

  test.each(densities)("%i source chars/min, 10 minutes, into every language", (perMinute) => {
    const failures: string[] = [];
    for (const lang of targets) {
      const sourceChars = perMinute * 10;
      const q = quoteLanguage(600, sourceChars, "en", lang);
      const b = planDubBudget({
        priceUsd: q.priceUsd,
        durationSec: 600,
        languages: 1,
        translationCharsIn: sourceChars,
        translationCharsOut: q.estimatedChars,
        ttsChars: q.estimatedChars,
      });
      const profit = netRevenueUsd(q.priceUsd) - b.plannedUsd;
      if (profit < profitFloorUsd(q.priceUsd) - 0.005) failures.push(`${lang}: price ${q.priceUsd}, profit ${profit.toFixed(2)}`);
    }
    expect(failures).toEqual([]);
  });

  test("short videos too: 1 minute, very dense speech, into every language", () => {
    for (const lang of targets) {
      const q = quoteLanguage(60, 2200, "en", lang);
      const b = planDubBudget({ priceUsd: q.priceUsd, durationSec: 60, languages: 1, translationCharsIn: 2200, translationCharsOut: q.estimatedChars, ttsChars: q.estimatedChars });
      expect(netRevenueUsd(q.priceUsd) - b.plannedUsd).toBeGreaterThanOrEqual(profitFloorUsd(q.priceUsd) - 0.005);
    }
  });
});

import { channelDubbingDiscountPercent } from "../../src/pipeline/services/dubbing-pricing";

describe("channelDubbingDiscountPercent (admin-set channel fields only)", () => {
  test("free and percentage discounts from the channel document", () => {
    expect(channelDubbingDiscountPercent({ isDubbingFree: true }, false)).toBe(100);
    expect(channelDubbingDiscountPercent({ aiDiscounts: { dubbing: { type: "free" } } }, false)).toBe(100);
    expect(channelDubbingDiscountPercent({ dubbingDiscountPercent: 25 }, false)).toBe(25);
    expect(channelDubbingDiscountPercent({ aiDiscounts: { dubbing: { percent: 140 } } }, false)).toBe(100);
    expect(channelDubbingDiscountPercent({ dubbingDiscountPercent: "abc" }, false)).toBe(0);
    expect(channelDubbingDiscountPercent({}, false)).toBe(0);
    expect(channelDubbingDiscountPercent(undefined, false)).toBe(0);
  });

  test("admins dub free", () => {
    expect(channelDubbingDiscountPercent({}, true)).toBe(100);
  });
});

import { dubbingCharge } from "../../src/pipeline/services/dubbing-pricing";

describe("dubbingCharge (shared by the quote endpoint and the actual charge)", () => {
  const quote = quoteDubbing({ durationSec: 600, sourceChars: 13000, sourceLanguage: "en", targetLanguages: ["hi", "ml"], discountPercent: 20 });

  test("minute mode: per-minute price per language, discount applied, matches the old server formula", () => {
    const c = dubbingCharge({ targetLanguages: ["hi", "ml"], minutePricePerLanguageUsd: 3, discountPercent: 20, quote, characterPricing: false });
    expect(c).toEqual({ chargedUsd: 4.8, priceByLanguage: { hi: 2.4, ml: 2.4 }, basis: "minutes" });
    expect(dubbingCharge({ targetLanguages: ["hi"], minutePricePerLanguageUsd: 3, discountPercent: 0, quote: null, characterPricing: true }).basis).toBe("minutes");
  });

  test("character mode: the quote's total, and per-language prices after discount", () => {
    const c = dubbingCharge({ targetLanguages: ["hi", "ml"], minutePricePerLanguageUsd: 3, discountPercent: 20, quote, characterPricing: true });
    expect(c.basis).toBe("characters");
    expect(c.chargedUsd).toBe(quote.totalUsd);
    expect(c.priceByLanguage.ml).toBe(Math.round(quote.languages[1].priceUsd * 0.8 * 100) / 100);
  });

  test("100% discount charges nothing", () => {
    expect(dubbingCharge({ targetLanguages: ["hi"], minutePricePerLanguageUsd: 3, discountPercent: 100, quote: null, characterPricing: false }).chargedUsd).toBe(0);
  });
});
