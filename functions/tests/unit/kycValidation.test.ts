// Extracting validation logic inline as per instructions since they are not exported
function normalizeName(input: string): string {
  if (!input) return "";
  let cleaned = input.toLowerCase().trim();
  const honorifics = ["mr", "mrs", "ms", "dr", "shri", "smt", "md", "mister", "miss"];
  for (const h of honorifics) {
    cleaned = cleaned.replace(new RegExp(`\\b${h}\\b[.]?`, "g"), "");
  }
  cleaned = cleaned.replace(/[^a-z0-9\s]/g, " ");
  return cleaned.replace(/\s+/g, " ").trim();
}

function calculateNameSimilarity(name1: string, name2: string): number {
  const s1 = normalizeName(name1);
  const s2 = normalizeName(name2);
  if (!s1 || !s2) return 0;
  if (s1 === s2) return 1.0;

  const tokens1 = new Set(s1.split(" ").filter(Boolean));
  const tokens2 = new Set(s2.split(" ").filter(Boolean));

  if (tokens1.size === 0 || tokens2.size === 0) return 0;

  const intersection = new Set([...tokens1].filter((x) => tokens2.has(x))).size;
  const union = new Set([...tokens1, ...tokens2]).size;
  const jaccard = union > 0 ? intersection / union : 0;

  const isSubset1 = [...tokens1].every((t) => tokens2.has(t));
  const isSubset2 = [...tokens2].every((t) => tokens1.has(t));
  if (isSubset1 || isSubset2) {
    return Math.max(0.90, jaccard);
  }

  return jaccard;
}

const PAN_REGEX = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;

describe("KYC Validation Logic", () => {
  describe("PAN Format Validation", () => {
    it("should accept valid PAN formats", () => {
      expect(PAN_REGEX.test("ABCDE1234F")).toBe(true);
      expect(PAN_REGEX.test("QWERT9876Y")).toBe(true);
    });

    it("should reject invalid PAN formats", () => {
      expect(PAN_REGEX.test("ABCD12345F")).toBe(false); // 4 letters at start
      expect(PAN_REGEX.test("ABCDE123F")).toBe(false);  // 3 digits
      expect(PAN_REGEX.test("ABCDE12345")).toBe(false); // No ending letter
      expect(PAN_REGEX.test("abcde1234f")).toBe(false); // Lowercase
      expect(PAN_REGEX.test("")).toBe(false);
    });
  });

  describe("Name Normalization", () => {
    it("should strip honorifics", () => {
      expect(normalizeName("Mr. John Doe")).toBe("john doe");
      expect(normalizeName("Dr Smith")).toBe("smith");
      expect(normalizeName("Shri Ram Kumar")).toBe("ram kumar");
      expect(normalizeName("Smt. Sita Devi")).toBe("sita devi");
    });

    it("should handle special characters and extra spaces", () => {
      expect(normalizeName("John-Doe, Jr.")).toBe("john doe jr");
      expect(normalizeName("  Alice   Bob  ")).toBe("alice bob");
    });
  });

  describe("Name Similarity Calculation", () => {
    it("should return 1.0 for exact matches", () => {
      expect(calculateNameSimilarity("John Doe", "John Doe")).toBe(1.0);
      expect(calculateNameSimilarity("Mr. John Doe", "John Doe")).toBe(1.0);
    });

    it("should return >= 0.90 for subsets (missing middle name)", () => {
      const score = calculateNameSimilarity("John Robert Doe", "John Doe");
      expect(score).toBeGreaterThanOrEqual(0.90);
    });

    it("should calculate correct Jaccard similarity for partial matches", () => {
      // "John Robert Doe" vs "John Smith Doe" -> Intersection: John, Doe (2). Union: John, Robert, Doe, Smith (4) -> 2/4 = 0.5
      const score = calculateNameSimilarity("John Robert Doe", "John Smith Doe");
      expect(score).toBe(0.5);
    });

    it("should return 0 for completely mismatched names", () => {
      expect(calculateNameSimilarity("Alice", "Bob")).toBe(0);
    });

    it("should handle empty inputs", () => {
      expect(calculateNameSimilarity("", "Bob")).toBe(0);
      expect(calculateNameSimilarity("Alice", "")).toBe(0);
      expect(calculateNameSimilarity("", "")).toBe(0);
    });
  });
});
