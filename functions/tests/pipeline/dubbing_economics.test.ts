/**
 * Business rule: $1 of a $3, 10-minute, one-language dub is profit and is never spent.
 * See dubbing-economics.ts.
 */
import {
  costBudgetUsd,
  DEFAULT_MARGIN_POLICY,
  evaluateMargin,
  netRevenueUsd,
  planDubBudget,
  profitFloorUsd,
  readMarginPolicy,
  RetryBudget,
} from "../../src/pipeline/services/dubbing-economics";

const tenMinutes = { priceUsd: 3, durationSec: 600, languages: 1, translationCharsIn: 9000, translationCharsOut: 11000 };

describe("revenue, profit floor and budget", () => {
  test("$3 dub, GST inside the price, 2% gateway: $1 profit, about $1.48 to spend", () => {
    expect(netRevenueUsd(3)).toBeCloseTo(3 / 1.18 - 0.06, 4);
    expect(profitFloorUsd(3)).toBeCloseTo(1, 4);
    expect(costBudgetUsd(3)).toBeCloseTo(1.4824, 3);
  });

  test("if GST is charged on top, the budget is about $1.94", () => {
    const p = { ...DEFAULT_MARGIN_POLICY, priceIncludesGst: false };
    expect(costBudgetUsd(3, p)).toBeCloseTo(3 - 0.06 - 1, 4);
  });

  test("the floor scales with price (per-minute pricing): a $0.30 one-minute dub keeps $0.10", () => {
    expect(profitFloorUsd(0.3)).toBeCloseTo(0.1, 4);
  });

  test("settings come from env, with bad values ignored", () => {
    const p = readMarginPolicy({ PRICE_INCLUDES_GST: "false", PAYMENT_GATEWAY_FEE_RATE: "0.025", ELEVENLABS_USD_PER_1K_CHARS: "0.05", GST_RATE: "abc" });
    expect(p.priceIncludesGst).toBe(false);
    expect(p.gatewayFeeRate).toBe(0.025);
    expect(p.ttsUsdPerChar).toBeCloseTo(0.00005, 8);
    expect(p.gstRate).toBe(0.18);
    expect(readMarginPolicy({})).toEqual(DEFAULT_MARGIN_POLICY);
  });
});

describe("planDubBudget", () => {
  test("typical 10-minute video (11K voiced characters) keeps the $1 with room for retries", () => {
    const b = planDubBudget({ ...tenMinutes, ttsChars: 11000 });
    expect(b.ttsUsd).toBeCloseTo(0.88, 4);
    expect(b.withinBudget).toBe(true);
    expect(b.projectedProfitUsd).toBeGreaterThanOrEqual(b.profitFloorUsd);
    expect(b.retryBudgetChars).toBeGreaterThan(1000);
  });

  test("talk-heavy 10-minute video (16K characters) cannot keep $1 at $3 with GST inside", () => {
    const b = planDubBudget({ ...tenMinutes, ttsChars: 16000 });
    expect(b.withinBudget).toBe(false);
    expect(b.retryBudgetChars).toBe(0);
  });

  test("shared per-video costs are split across languages, so extra languages are more profitable", () => {
    const one = planDubBudget({ ...tenMinutes, ttsChars: 11000 });
    const three = planDubBudget({ ...tenMinutes, languages: 3, ttsChars: 11000 });
    expect(three.sharedShareUsd).toBeCloseTo(one.sharedShareUsd / 3, 3);
    expect(three.retryBudgetChars).toBeGreaterThan(one.retryBudgetChars);
  });

  test("a cheaper ElevenLabs plan rate widens the budget", () => {
    const p = { ...DEFAULT_MARGIN_POLICY, ttsUsdPerChar: 0.05 / 1000 };
    expect(planDubBudget({ ...tenMinutes, ttsChars: 16000 }, p).withinBudget).toBe(true);
  });
});

describe("RetryBudget", () => {
  test("hands out characters until the limit, then refuses", () => {
    const r = new RetryBudget(100);
    expect(r.tryConsume(60)).toBe(true);
    expect(r.tryConsume(50)).toBe(false);
    expect(r.tryConsume(40)).toBe(true);
    expect(r.tryConsume(1)).toBe(false);
    expect([r.usedChars, r.refused]).toEqual([100, 2]);
  });

  test("a zero budget allows no regeneration", () => {
    expect(new RetryBudget(0).tryConsume(1)).toBe(false);
  });
});

describe("evaluateMargin", () => {
  test("after the job: actual cost under budget meets the floor; over budget is flagged", () => {
    expect(evaluateMargin(3, 1.3).meetsFloor).toBe(true);
    const bad = evaluateMargin(3, 1.6);
    expect(bad.meetsFloor).toBe(false);
    expect(bad.profitUsd).toBeLessThan(1);
  });
});
