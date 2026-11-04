import { calculateDubbingCost, calculateSubtitleCost } from "../../src/pipeline/services/cost-engine";

describe("CostEngine Discounts & Waivers", () => {
  it("calculates dubbing cost with 0% discount (base rate)", () => {
    const cost = calculateDubbingCost(2, 120, "standard", "standard", 0);
    expect(cost).toBe(0.50); // 2 * $0.25
  });

  it("calculates dubbing cost with 50% discount", () => {
    const cost = calculateDubbingCost(2, 120, "standard", "standard", 50);
    expect(cost).toBe(0.25); // 50% of $0.50
  });

  it("calculates dubbing cost with 100% free waiver", () => {
    const cost = calculateDubbingCost(2, 120, "standard", "standard", 100);
    expect(cost).toBe(0.0);
  });

  it("calculates subtitle cost with 0%, 50%, and 100% discount", () => {
    const baseCost = calculateSubtitleCost(4, 300, "standard", 0);
    expect(baseCost).toBe(0.10); // 4 * $0.025

    const discountedCost = calculateSubtitleCost(4, 300, "standard", 50);
    expect(discountedCost).toBe(0.05);

    const freeCost = calculateSubtitleCost(4, 300, "standard", 100);
    expect(freeCost).toBe(0.0);
  });
});
