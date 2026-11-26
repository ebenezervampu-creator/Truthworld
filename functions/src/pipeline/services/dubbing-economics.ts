/**
 * Dubbing unit economics (dependency-free, unit-tested).
 *
 * Business rule: TruthWorld keeps a fixed share of every dub's price as profit — $1 of a $3,
 * 10-minute, one-language dub — and never spends any of it on models or infrastructure.
 * Everything else (after payment-gateway fees and GST) is the cost budget. Costs may come in
 * under budget (the extra is kept); they must never go over.
 *
 * Price is per minute (cost-engine.ts), so the floor is a share of the price: 1/3 by default.
 *
 * The biggest cost is ElevenLabs voice, charged per character. After translation the exact
 * character count is known BEFORE any voice is generated, so the pipeline plans each language's
 * spend here and only spends on optional work (regenerating lines that run long) while the plan
 * still leaves the profit intact.
 *
 * Settings (env, all optional):
 *   DUBBING_PROFIT_SHARE        share of the gross price kept as profit        (default 0.3333)
 *   PRICE_INCLUDES_GST          "true" if the price the creator pays includes GST (default true)
 *   GST_RATE                    GST rate                                         (default 0.18)
 *   PAYMENT_GATEWAY_FEE_RATE    gateway fee as a share of the gross price        (default 0.02)
 *   ELEVENLABS_USD_PER_1K_CHARS effective voice price on your ElevenLabs plan    (default 0.08)
 * Defaults are deliberately conservative (GST inside the price, 2% gateway fee).
 */

import { DEMUCS_USD_PER_MINUTE } from "./separation-policy";

export interface MarginPolicy {
  profitShare: number;
  priceIncludesGst: boolean;
  gstRate: number;
  gatewayFeeRate: number;
  ttsUsdPerChar: number;
}

export const DEFAULT_MARGIN_POLICY: MarginPolicy = {
  profitShare: 1 / 3,
  priceIncludesGst: true,
  gstRate: 0.18,
  gatewayFeeRate: 0.02,
  ttsUsdPerChar: 0.08 / 1000,
};

/** Translation LLM ($10/M input + $10/M output characters, cost-engine.ts RATE_CARDS). */
export const TRANSLATION_USD_PER_CHAR = 0.00001;
/** Shared per-video work, per second of video: AssemblyAI ($0.23/h), Gemini diarization pass with
 * reference clips and speaker profiling (Flash-lite video tokens), media processing, and voice /
 * background separation at its worst case (GPU Demucs, separation-policy.ts; speech-only
 * videos cost $0). Estimate; actual spend is recorded per job in job_costs (cost-engine.ts). */
export const SHARED_USD_PER_SECOND = 0.23 / 3600 + 0.00012 + 0.0001 + DEMUCS_USD_PER_MINUTE / 60;
/** Per-language checks after voice (back-transcription + meaning comparison) and final mix. */
export const QC_RESERVE_USD_PER_MINUTE = 0.006;

function num(raw: string | undefined, fallback: number, min: number, max: number): number {
  const n = Number(raw);
  return raw !== undefined && raw !== "" && Number.isFinite(n) && n >= min && n <= max ? n : fallback;
}

export function readMarginPolicy(env: Record<string, string | undefined> = process.env): MarginPolicy {
  const d = DEFAULT_MARGIN_POLICY;
  return {
    profitShare: num(env.DUBBING_PROFIT_SHARE, d.profitShare, 0, 0.95),
    priceIncludesGst: (env.PRICE_INCLUDES_GST ?? "true").toLowerCase() !== "false",
    gstRate: num(env.GST_RATE, d.gstRate, 0, 0.5),
    gatewayFeeRate: num(env.PAYMENT_GATEWAY_FEE_RATE, d.gatewayFeeRate, 0, 0.2),
    ttsUsdPerChar: num(env.ELEVENLABS_USD_PER_1K_CHARS, d.ttsUsdPerChar * 1000, 0.001, 1) / 1000,
  };
}

const round = (n: number) => Math.round(n * 10000) / 10000;

/** What TruthWorld actually receives from a price: GST removed (if included), gateway fee paid. */
export function netRevenueUsd(priceUsd: number, p: MarginPolicy = DEFAULT_MARGIN_POLICY): number {
  const price = Math.max(0, priceUsd);
  const exGst = p.priceIncludesGst ? price / (1 + p.gstRate) : price;
  return round(exGst - price * p.gatewayFeeRate);
}

/** Profit that must be kept from a price. */
export function profitFloorUsd(priceUsd: number, p: MarginPolicy = DEFAULT_MARGIN_POLICY): number {
  return round(Math.max(0, priceUsd) * p.profitShare);
}

/** Most that may be spent on a dub at this price without touching the profit. */
export function costBudgetUsd(priceUsd: number, p: MarginPolicy = DEFAULT_MARGIN_POLICY): number {
  return round(Math.max(0, netRevenueUsd(priceUsd, p) - profitFloorUsd(priceUsd, p)));
}

export interface DubBudgetInput {
  /** Price of this one language (cost-engine.ts getFlatDubbingPricePerLanguage). */
  priceUsd: number;
  durationSec: number;
  /** Languages in the job; shared per-video costs are split across them. */
  languages: number;
  /** Characters sent to translation and received back, for this language. */
  translationCharsIn: number;
  translationCharsOut: number;
  /** Characters about to be voiced for this language. */
  ttsChars: number;
}

export interface DubBudget {
  priceUsd: number;
  netRevenueUsd: number;
  profitFloorUsd: number;
  costBudgetUsd: number;
  sharedShareUsd: number;
  translationUsd: number;
  ttsUsd: number;
  reserveUsd: number;
  plannedUsd: number;
  /** Budget left for optional regeneration; 0 when the plan already uses everything. */
  retryBudgetUsd: number;
  retryBudgetChars: number;
  /** False when even the required work would cut into the profit (price this video differently). */
  withinBudget: boolean;
  projectedProfitUsd: number;
}

/** Plans one language's spend before any voice is generated. */
export function planDubBudget(input: DubBudgetInput, p: MarginPolicy = DEFAULT_MARGIN_POLICY): DubBudget {
  const minutes = Math.max(0, input.durationSec) / 60;
  const languages = Math.max(1, Math.floor(input.languages || 1));
  const net = netRevenueUsd(input.priceUsd, p);
  const floor = profitFloorUsd(input.priceUsd, p);
  const budget = costBudgetUsd(input.priceUsd, p);
  const sharedShareUsd = round((Math.max(0, input.durationSec) * SHARED_USD_PER_SECOND) / languages);
  const translationUsd = round((Math.max(0, input.translationCharsIn) + Math.max(0, input.translationCharsOut)) * TRANSLATION_USD_PER_CHAR);
  const ttsUsd = round(Math.max(0, input.ttsChars) * p.ttsUsdPerChar);
  const reserveUsd = round(Math.max(1, minutes) * QC_RESERVE_USD_PER_MINUTE);
  const plannedUsd = round(sharedShareUsd + translationUsd + ttsUsd + reserveUsd);
  const retryBudgetUsd = round(Math.max(0, budget - plannedUsd));
  // A regenerated line costs its new translation plus its voice.
  const perRetryChar = p.ttsUsdPerChar + 2 * TRANSLATION_USD_PER_CHAR;
  return {
    priceUsd: round(input.priceUsd),
    netRevenueUsd: net,
    profitFloorUsd: floor,
    costBudgetUsd: budget,
    sharedShareUsd,
    translationUsd,
    ttsUsd,
    reserveUsd,
    plannedUsd,
    retryBudgetUsd,
    retryBudgetChars: Math.floor(retryBudgetUsd / perRetryChar),
    withinBudget: plannedUsd <= budget,
    projectedProfitUsd: round(net - plannedUsd),
  };
}

/** Hands out regeneration characters until the budget runs out. */
export class RetryBudget {
  private used = 0;
  private refusedCount = 0;
  constructor(readonly limitChars: number) {}

  /** Reserves chars if they fit; otherwise refuses (the line keeps its first take). */
  tryConsume(chars: number): boolean {
    const n = Math.max(0, Math.ceil(chars));
    if (this.used + n > this.limitChars) {
      this.refusedCount++;
      return false;
    }
    this.used += n;
    return true;
  }

  get usedChars(): number {
    return this.used;
  }
  get refused(): number {
    return this.refusedCount;
  }
}

export interface MarginResult {
  revenueUsd: number;
  netRevenueUsd: number;
  costUsd: number;
  profitUsd: number;
  profitFloorUsd: number;
  meetsFloor: boolean;
}

/** After the fact: did this job keep its profit? revenueUsd is what the creator paid in total. */
export function evaluateMargin(revenueUsd: number, costUsd: number, p: MarginPolicy = DEFAULT_MARGIN_POLICY): MarginResult {
  const net = netRevenueUsd(revenueUsd, p);
  const floor = profitFloorUsd(revenueUsd, p);
  const profit = round(net - Math.max(0, costUsd));
  return {
    revenueUsd: round(revenueUsd),
    netRevenueUsd: net,
    costUsd: round(costUsd),
    profitUsd: profit,
    profitFloorUsd: floor,
    meetsFloor: profit >= floor,
  };
}
