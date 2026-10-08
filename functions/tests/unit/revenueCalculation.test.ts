import { calculateShare } from "../../src/economy/revenue";

// Mocking TYPE_REVENUE_SHARE if needed, or we can just test the function's internal logic.
jest.mock("../../src/economy/types", () => ({
  TYPE_REVENUE_SHARE: {
    standard: {
      ads: 0.7,
      premiumSubs: 0.7,
      superchats: 1.0, // Assuming based on syncChannelStatements rules
      members: 1.0
    }
  }
}));

describe("Revenue Calculation", () => {
  describe("calculateShare", () => {
    it("should return 100% for custom channels (Ads)", () => {
      const share = calculateShare(100, "ads", "custom");
      expect(share).toBe(100);
    });

    it("should return 100% for custom channels (Superchats)", () => {
      const share = calculateShare(50, "superchats", "custom");
      expect(share).toBe(50);
    });

    it("should calculate standard channel share for ads (70%)", () => {
      const share = calculateShare(100, "ads", "standard");
      expect(share).toBe(70);
    });

    it("should calculate standard channel share for premiumSubs (70%)", () => {
      const share = calculateShare(100, "premiumSubs", "standard");
      expect(share).toBe(70);
    });

    it("should calculate standard channel share for superchats (100%)", () => {
      const share = calculateShare(100, "superchats", "standard");
      expect(share).toBe(100);
    });

    it("should calculate standard channel share for members (100%)", () => {
      const share = calculateShare(50, "members", "standard");
      expect(share).toBe(50);
    });

    it("should handle zero gross revenue", () => {
      expect(calculateShare(0, "ads", "standard")).toBe(0);
      expect(calculateShare(0, "ads", "custom")).toBe(0);
    });

    it("should handle negative gross revenue safely", () => {
      expect(calculateShare(-50, "ads", "standard")).toBe(-35);
      expect(calculateShare(-50, "members", "custom")).toBe(-50);
    });

    it("should handle very large numbers", () => {
      expect(calculateShare(1000000, "ads", "standard")).toBe(700000);
      expect(calculateShare(1000000, "ads", "custom")).toBe(1000000);
    });

    it("should use fallback 70% for unknown source types", () => {
      // @ts-ignore - testing runtime fallback
      const share = calculateShare(100, "unknown_type", "standard");
      expect(share).toBe(70);
    });
  });
});
