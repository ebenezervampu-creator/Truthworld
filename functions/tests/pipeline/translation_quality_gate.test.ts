/**
 * 🧪 Test Suite: Translation Quality Gate & Numerical Entity Guard
 *
 * Verifies:
 * 1. Indic numeral script folding (Devanagari, Telugu, Tamil, Arabic-Indic).
 * 2. Cross-scale canonical normalization (million/billion vs crore/lakh).
 * 3. Currency and percentage parity.
 * 4. Critical negation polarity flip detection (fact-checking guard).
 * 5. Quarantined Adaptive MT Translation Memory gating.
 */

import {
  NumericalEntityGuard,
} from "../../src/pipeline/services/numericalEntityGuard";
import {
  TranslationQualityGate,
} from "../../src/pipeline/services/translationQualityGate";
import {
  AdaptiveMtDatasetService,
} from "../../src/pipeline/services/adaptiveMtDatasetService";

describe("NumericalEntityGuard (Factual & Epistemic Parity)", () => {
  describe("1. Indic and Arabic Native Numeral Folding", () => {
    it("folds Devanagari numerals (०-९) to ASCII 0-9", () => {
      const devanagari = "भारत में १५ करोड़ लोग रहते हैं"; // 15
      const folded = NumericalEntityGuard.foldNativeDigits(devanagari);
      expect(folded).toContain("15");
    });

    it("folds Telugu numerals (౦-౯) to ASCII 0-9", () => {
      const telugu = "ఈ ప్రాజెక్ట్ విలువ ₹౨౫ లక్షలు"; // 25
      const folded = NumericalEntityGuard.foldNativeDigits(telugu);
      expect(folded).toContain("25");
    });

    it("folds Tamil numerals (௦-௯) to ASCII 0-9", () => {
      const tamil = "மொத்தம் ௧௦௦ பேர்"; // 100
      const folded = NumericalEntityGuard.foldNativeDigits(tamil);
      expect(folded).toContain("100");
    });

    it("folds Arabic-Indic numerals (٠-٩) to ASCII 0-9", () => {
      const arabic = "بلغ عدد السكان ٥٠ مليون نسمة"; // 50
      const folded = NumericalEntityGuard.foldNativeDigits(arabic);
      expect(folded).toContain("50");
    });
  });

  describe("2. Cross-Scale Normalization (Crore/Lakh vs. Million/Billion)", () => {
    it("recognizes $10 million is equivalent to 1 crore (1 కోటి / 1 करोड़)", () => {
      const srcEn = "The investment totaled 10 million dollars.";
      const tgtTe = "మొత్తం పెట్టుబడి 1 కోటి డాలర్లు.";

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtTe, "te");
      expect(parity.isParity).toBe(true);
      expect(parity.sourceEntities[0].normalizedValue).toBe(10000000);
      expect(parity.targetEntities[0].normalizedValue).toBe(10000000);
    });

    it("recognizes 10 million is equivalent to 100 lakhs (100 లక్షలు)", () => {
      const srcEn = "Over 10 million users joined the network.";
      const tgtTe = "100 లక్షల కంటే ఎక్కువ మంది వినియోగదారులు చేరారు.";

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtTe, "te");
      expect(parity.isParity).toBe(true);
      expect(parity.sourceEntities[0].normalizedValue).toBe(10000000);
      expect(parity.targetEntities[0].normalizedValue).toBe(10000000);
    });

    it("catches scale distortion when 10 million is mistakenly translated as 10 crores (10 కోట్లు)", () => {
      const srcEn = "The company raised 10 million dollars.";
      const tgtTe = "కంపెనీ 10 కోట్ల డాలర్లు సమీకరించింది."; // 100 million! 10x error!

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtTe, "te");
      expect(parity.isParity).toBe(false);
      expect(parity.details).toContain("Numerical parity drift");
    });

    it("catches scale distortion when 10 million is mistakenly translated as 10 billion (10 బిలియన్)", () => {
      const srcEn = "10 million doses were distributed.";
      const tgtTe = "10 billion డోసులు పంపిణీ చేయబడ్డాయి."; // 10 billion! 1000x error!

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtTe, "te");
      expect(parity.isParity).toBe(false);
    });
  });

  describe("3. Percentages, Currencies, and Spelled Numbers", () => {
    it("matches percentage parity across English and Telugu (15% vs 15 శాతం)", () => {
      const srcEn = "Inflation dropped by 15% this quarter.";
      const tgtTe = "ఈ త్రైమాసికంలో ద్రవ్యోల్బణం 15 శాతం తగ్గింది.";

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtTe, "te");
      expect(parity.isParity).toBe(true);
      expect(parity.sourceEntities[0].normalizedValue).toBe(15);
      expect(parity.targetEntities[0].normalizedValue).toBe(15);
    });

    it("matches English spelled number ('five percent') with localized digit percentage ('5%')", () => {
      const srcEn = "The margin was five percent.";
      const tgtHi = "मार्जिन 5% था।";

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtHi, "hi");
      expect(parity.isParity).toBe(true);
      expect(parity.sourceEntities[0].normalizedValue).toBe(5);
      expect(parity.targetEntities[0].normalizedValue).toBe(5);
    });

    it("detects missing numbers if the translation drops a critical statistic", () => {
      const srcEn = "The study observed 450 patients over 12 months.";
      const tgtTe = "ఈ అధ్యయనంలో చాలా మంది రోగులను గమనించారు."; // Missing 450 and 12

      const parity = NumericalEntityGuard.verifyNumericalParity(srcEn, tgtTe, "te");
      expect(parity.isParity).toBe(false);
      expect(parity.missingInTarget.length).toBe(2);
    });
  });
});

describe("TranslationQualityGate (Spot-Check & Negation Flip Guard)", () => {
  describe("1. Negation Polarity Inversion Guard (Zero Tolerance for Fact Inversion)", () => {
    it("detects fatal negation flip when 'effective' becomes 'not effective'", () => {
      const srcEn = "Clinical trials show the vaccine is effective.";
      const backEn = "Clinical trials show the vaccine is not effective.";

      const flipped = TranslationQualityGate.checkNegationPolarityFlip(srcEn, backEn);
      expect(flipped).toBe(true);
    });

    it("detects fatal negation flip when 'did not commit fraud' becomes 'committed fraud'", () => {
      const srcEn = "The investigation proved the minister did not commit fraud.";
      const backEn = "The investigation proved the minister committed fraud.";

      const flipped = TranslationQualityGate.checkNegationPolarityFlip(srcEn, backEn);
      expect(flipped).toBe(true);
    });

    it("allows aligned negation when both source and back-translation are negative", () => {
      const srcEn = "The claim has not been verified by independent scientists.";
      const backEn = "The claim is unproven by independent scientists.";

      const flipped = TranslationQualityGate.checkNegationPolarityFlip(srcEn, backEn);
      expect(flipped).toBe(false);
    });

    it("allows aligned affirmative when both source and back-translation are positive", () => {
      const srcEn = "Renewable energy capacity expanded rapidly in 2024.";
      const backEn = "Renewable power capacity grew quickly in 2024.";

      const flipped = TranslationQualityGate.checkNegationPolarityFlip(srcEn, backEn);
      expect(flipped).toBe(false);
    });
  });

  describe("2. End-to-End Unified Quality Gate Evaluation", () => {
    it("passes compliant, number-aligned segments with zero flags", async () => {
      const input = [
        {
          index: 0,
          original: "India launched 25 satellites in 2024.",
          translated: "భారతదేశం 2024లో 25 ఉపగ్రహాలను ప్రయోగించింది.",
          isClaim: true,
        },
      ];

      const results = await TranslationQualityGate.evaluateQualityGate(
        input,
        "en",
        "te",
        {
          sampleRate: 1.0,
          backTranslateCallback: async () => "India launched 25 satellites in 2024.",
        }
      );

      expect(results[0].numericalParityVerified).toBe(true);
      expect(results[0].reviewRecommended).toBe(false);
      expect(results[0].polarityFlipped).toBeFalsy();
      expect(results[0].semanticParityScore).toBeGreaterThanOrEqual(0.85);
    });

    it("flags segments for review when numbers drift and repair is unavailable", async () => {
      const input = [
        {
          index: 0,
          original: "The project costs 50 million dollars.",
          translated: "ఈ ప్రాజెక్ట్ ఖర్చు 500 కోట్ల డాలర్లు.", // 500 crores is 5 billion (100x error)
          isClaim: true,
        },
      ];

      const results = await TranslationQualityGate.evaluateQualityGate(
        input,
        "en",
        "te",
        {
          sampleRate: 1.0,
          enableSelfHealing: false,
        }
      );

      expect(results[0].numericalParityVerified).toBe(false);
      expect(results[0].reviewRecommended).toBe(true);
      expect(results[0].numericalParityWarning).toContain("Numerical parity drift");
    });

    it("triggers self-healing repair callback when numerical drift is detected", async () => {
      const input = [
        {
          index: 0,
          original: "The subsidy is 10 million rupees.",
          translated: "రాయితీ మొత్తం చాలా ఎక్కువ.", // Missing 10 million
        },
      ];

      const results = await TranslationQualityGate.evaluateQualityGate(
        input,
        "en",
        "te",
        {
          sampleRate: 0.1,
          enableSelfHealing: true,
          repairCallback: async () => "రాయితీ మొత్తం 1 కోటి రూపాయలు.", // 1 crore == 10 million
        }
      );

      expect(results[0].numericalParityVerified).toBe(true);
      expect(results[0].translated).toBe("రాయితీ మొత్తం 1 కోటి రూపాయలు.");
      expect(results[0].reviewRecommended).toBe(false);
    });

    it("flags reviewRecommended when negation is inverted on a spot-checked claim", async () => {
      const input = [
        {
          index: 0,
          original: "The treatment is safe for human use.",
          translated: "ఈ చికిత్స మానవ వినియోగానికి సురక్షితం కాదు.", // Actually says "not safe"
          isClaim: true,
        },
      ];

      const results = await TranslationQualityGate.evaluateQualityGate(
        input,
        "en",
        "te",
        {
          sampleRate: 1.0,
          backTranslateCallback: async () => "This treatment is not safe for human use.",
        }
      );

      expect(results[0].polarityFlipped).toBe(true);
      expect(results[0].semanticParityScore).toBe(0.0);
      expect(results[0].reviewRecommended).toBe(true);
    });
  });
});

describe("AdaptiveMtDatasetService (Option 3 Quarantined Translation Memory)", () => {
  it("enforces strict quarantine: rejects ingestion if numerical parity failed", () => {
    const canIngest = TranslationQualityGate.canIngestIntoAdaptiveMt({
      numericalParityVerified: false,
      terminologyComplianceRate: 1.0,
      reviewRecommended: false,
    });
    expect(canIngest).toBe(false);
  });

  it("enforces strict quarantine: rejects ingestion if terminology compliance < 1.0", () => {
    const canIngest = TranslationQualityGate.canIngestIntoAdaptiveMt({
      numericalParityVerified: true,
      terminologyComplianceRate: 0.80,
      reviewRecommended: false,
    });
    expect(canIngest).toBe(false);
  });

  it("enforces strict quarantine: rejects ingestion if reviewRecommended is true", () => {
    const canIngest = TranslationQualityGate.canIngestIntoAdaptiveMt({
      numericalParityVerified: true,
      terminologyComplianceRate: 1.0,
      reviewRecommended: true,
    });
    expect(canIngest).toBe(false);
  });

  it("approves ingestion into Adaptive MT only when numerical parity passes, terminology is 100%, and reviewRecommended is false", () => {
    const canIngest = TranslationQualityGate.canIngestIntoAdaptiveMt({
      numericalParityVerified: true,
      terminologyComplianceRate: 1.0,
      reviewRecommended: false,
    });
    expect(canIngest).toBe(true);
  });

  it("generates deterministic pair hashes for translation memory deduplication", () => {
    const hash1 = AdaptiveMtDatasetService.hashPair("Democracy matters", "ప్రజాస్వామ్యం ముఖ్యం");
    const hash2 = AdaptiveMtDatasetService.hashPair("Democracy matters", "ప్రజాస్వామ్యం ముఖ్యం");
    const hashDiff = AdaptiveMtDatasetService.hashPair("Sovereignty matters", "సార్వభౌమత్వం ముఖ్యం");

    expect(hash1).toBe(hash2);
    expect(hash1).not.toBe(hashDiff);
    expect(hash1.length).toBe(24);
  });
});
