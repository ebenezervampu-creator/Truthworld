import { setCache, getCache, deleteCache, clearCache } from "../../src/shared/memory-cache";
import { normalizeLanguageCode, normalizeLanguageCodes } from "../../src/shared/language-normalizer";

describe("Memory Cache & Language Normalizer", () => {
  describe("Memory Cache", () => {
    beforeEach(() => {
      clearCache();
      jest.restoreAllMocks();
    });

    it("should set and get cache successfully", () => {
      setCache("key1", { data: "test" }, 60);
      const result = getCache<{ data: string }>("key1");
      expect(result).toEqual({ data: "test" });
    });

    it("should return undefined for cache miss", () => {
      const result = getCache("missing_key");
      expect(result).toBeUndefined();
    });

    it("should delete specific key", () => {
      setCache("key1", "val1", 60);
      setCache("key2", "val2", 60);
      deleteCache("key1");
      expect(getCache("key1")).toBeUndefined();
      expect(getCache("key2")).toBe("val2");
    });

    it("should expire cache based on TTL", () => {
      const now = 1000000000000;
      jest.spyOn(Date, "now").mockReturnValue(now);

      setCache("key1", "val1", 60); // expires at now + 60000

      // Advance time by 30 seconds
      jest.spyOn(Date, "now").mockReturnValue(now + 30000);
      expect(getCache("key1")).toBe("val1");

      // Advance time by 61 seconds
      jest.spyOn(Date, "now").mockReturnValue(now + 61000);
      expect(getCache("key1")).toBeUndefined();
    });

    it("should handle capacity limits (if applicable) or robustly clear cache", () => {
      // Current implementation does not have capacity limits, so we test clearCache
      setCache("k1", "v1", 60);
      setCache("k2", "v2", 60);
      clearCache();
      expect(getCache("k1")).toBeUndefined();
      expect(getCache("k2")).toBeUndefined();
    });
  });

  describe("Language Normalizer", () => {
    it("should normalize valid codes", () => {
      expect(normalizeLanguageCode("en")).toBe("en");
      expect(normalizeLanguageCode("hi")).toBe("hi");
    });

    it("should map full language names to codes", () => {
      expect(normalizeLanguageCode("English")).toBe("en");
      expect(normalizeLanguageCode("TAMIL")).toBe("ta");
      expect(normalizeLanguageCode("  hindi  ")).toBe("hi");
    });

    it("should handle unknown languages gracefully", () => {
      expect(normalizeLanguageCode("unknownlang")).toBe("unknownlang");
      expect(normalizeLanguageCode("")).toBe("en");
      // @ts-ignore
      expect(normalizeLanguageCode(null)).toBe("en");
    });

    it("should normalize array of languages and deduplicate", () => {
      const result = normalizeLanguageCodes(["English", "en", "hindi", "TAMIL", "unknownlang"]);
      expect(result).toEqual(["en", "hi", "ta", "unknownlang"]);
    });

    it("should handle empty or invalid arrays", () => {
      expect(normalizeLanguageCodes([])).toEqual([]);
      // @ts-ignore
      expect(normalizeLanguageCodes(null)).toEqual(["en"]);
    });
  });
});
