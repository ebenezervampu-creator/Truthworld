import {
  isSummaryLanguageMismatch,
  getLanguageDisplayName,
  normalizeLanguageCode,
} from "../../src/shared/language-normalizer";

describe("Summary Language Guard & Native Localization Validation", () => {
  describe("getLanguageDisplayName", () => {
    it("returns correct native script display names for major languages", () => {
      expect(getLanguageDisplayName("te")).toBe("Telugu (తెలుగు)");
      expect(getLanguageDisplayName("hi")).toBe("Hindi (हिन्दी)");
      expect(getLanguageDisplayName("ta")).toBe("Tamil (தமிழ்)");
      expect(getLanguageDisplayName("kn")).toBe("Kannada (ಕನ್ನಡ)");
      expect(getLanguageDisplayName("ml")).toBe("Malayalam (മലയാളം)");
      expect(getLanguageDisplayName("en")).toBe("English");
      expect(getLanguageDisplayName("es")).toBe("Spanish (Español)");
      expect(getLanguageDisplayName("ar")).toBe("Arabic (العربية)");
    });
  });

  describe("isSummaryLanguageMismatch - Telugu Content (Taj Mahal Real-World Case)", () => {
    const englishTajMahalSummary =
      "This video provides a detailed analysis of the Taj Mahal's history, from its origins and architectural design to the materials used in its construction. It addresses and debunks various myths and conspiracy theories, including the 'Tejo Mahalaya' theory, by presenting historical facts and evidence.";

    const authenticTeluguSummary =
      "ఈ వీడియోలో తాజ్ మహల్ చరిత్ర, దాని నిర్మాణ శైలి మరియు 20,000 మంది కార్మికుల నిర్మాణ నేపథ్యాన్ని చారిత్రక ఆధారాలతో సమగ్రంగా విశ్లేషించడం జరిగింది. తేజో మహాలయ సిద్ధాంతం వంటి అపోహలను ఆధారాలతో నిరూపిస్తుంది.";

    it("flags English summary for Telugu video as a decisive mismatch", () => {
      expect(isSummaryLanguageMismatch(englishTajMahalSummary, "te")).toBe(true);
      expect(isSummaryLanguageMismatch(englishTajMahalSummary, "telugu")).toBe(true);
    });

    it("accepts authentic Telugu script summary for Telugu video", () => {
      expect(isSummaryLanguageMismatch(authenticTeluguSummary, "te")).toBe(false);
      expect(isSummaryLanguageMismatch(authenticTeluguSummary, "telugu")).toBe(false);
    });
  });

  describe("isSummaryLanguageMismatch - Hindi, Tamil & Indic Languages", () => {
    const englishSummary =
      "In this video, the creator explores the economic development and infrastructure expansion across India over the past decade.";

    const hindiSummary =
      "इस वीडियो में भारत के पिछले एक दशक के आर्थिक विकास और बुनियादी ढांचे के विस्तार का गहन विश्लेषण प्रस्तुत किया गया है।";

    const tamilSummary =
      "இந்த காணொளியில் இந்தியாவின் கடந்த பத்தாண்டுகளின் பொருளாதார வளர்ச்சி மற்றும் உள்கட்டமைப்பு விரிவாக்கம் விரிவாக விளக்கப்பட்டுள்ளது.";

    it("flags English summary for Hindi video as mismatch", () => {
      expect(isSummaryLanguageMismatch(englishSummary, "hi")).toBe(true);
    });

    it("accepts authentic Devanagari Hindi summary for Hindi video", () => {
      expect(isSummaryLanguageMismatch(hindiSummary, "hi")).toBe(false);
    });

    it("flags English summary for Tamil video as mismatch", () => {
      expect(isSummaryLanguageMismatch(englishSummary, "ta")).toBe(true);
    });

    it("accepts authentic Tamil summary for Tamil video", () => {
      expect(isSummaryLanguageMismatch(tamilSummary, "ta")).toBe(false);
    });
  });

  describe("isSummaryLanguageMismatch - English & Latin Languages", () => {
    const englishSummary =
      "This video explores the latest advancements in quantum computing and their potential impact on cryptography and scientific research.";

    const spanishSummary =
      "Este video explora los últimos avances en computación cuántica y su impacto potencial en la criptografía y la investigación científica.";

    it("accepts English summary for English video", () => {
      expect(isSummaryLanguageMismatch(englishSummary, "en")).toBe(false);
    });

    it("flags pure Telugu summary for English video as mismatch", () => {
      const teluguSummary =
        "ఈ వీడియోలో తాజ్ మహల్ చరిత్ర, దాని నిర్మాణ శైలి మరియు కార్మికుల నేపథ్యాన్ని చారిత్రక ఆధారాలతో సమగ్రంగా విశ్లేషించడం జరిగింది.";
      expect(isSummaryLanguageMismatch(teluguSummary, "en")).toBe(true);
    });

    it("flags English narrative opener for Spanish video as mismatch", () => {
      expect(isSummaryLanguageMismatch(englishSummary, "es")).toBe(true);
    });

    it("accepts authentic Spanish summary for Spanish video", () => {
      expect(isSummaryLanguageMismatch(spanishSummary, "es")).toBe(false);
    });
  });
});
