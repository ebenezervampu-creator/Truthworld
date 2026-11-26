import { calculateDubbingCost, calculateSubtitleCost } from "../../src/pipeline/services/cost-engine";

describe("CostEngine Discounts & Waivers", () => {
  it("calculates dubbing cost with 0% discount (base rate)", () => {
    // 2 languages * (120s / 60s) * $0.30/min = $1.20
    const cost = calculateDubbingCost(2, 120, "standard", "standard", 0);
    expect(cost).toBe(1.20);
  });

  it("calculates dubbing cost with 50% discount", () => {
    const cost = calculateDubbingCost(2, 120, "standard", "standard", 50);
    expect(cost).toBe(0.60); // 50% of $1.20
  });

  it("calculates dubbing cost with 100% free waiver", () => {
    const cost = calculateDubbingCost(2, 120, "standard", "standard", 100);
    expect(cost).toBe(0.0);
  });

  it("calculates subtitle cost with 0%, 50%, and 100% discount", () => {
    // 4 languages, 300s (5 min) Ultra Subtitles: base ($0.25) + additional ($0.30) = $0.55
    const baseCost = calculateSubtitleCost(4, 300, "standard", 0);
    expect(baseCost).toBe(0.55);

    const discountedCost = calculateSubtitleCost(4, 300, "standard", 50);
    expect(discountedCost).toBe(0.28);

    const freeCost = calculateSubtitleCost(4, 300, "standard", 100);
    expect(freeCost).toBe(0.0);
  });
});
