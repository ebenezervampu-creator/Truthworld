/**
 * 🏛️ FRED ECONOMIC DATA ADAPTER (TruthWorld Phase 3 Optimization)
 *
 * Federal Reserve Economic Data provider (CPI, Fed Funds Rate, Yields, Money Supply).
 * Enforces an 800ms hard timeout. Falls back cleanly if API key is not configured.
 */

import axios from "axios";
import { logger } from "../utils/logger";

export interface FredHit {
  title: string;
  url: string;
  passage: string;
  seriesId: string;
}

const COMMON_FRED_SERIES: Array<{ regex: RegExp; seriesId: string; title: string }> = [
  { regex: /\b(cpi|consumer price index|inflation)\b/i, seriesId: "CPIAUCSL", title: "Consumer Price Index for All Urban Consumers (CPIAUCSL)" },
  { regex: /\b(core cpi|core inflation)\b/i, seriesId: "CPILFESL", title: "Core CPI (Excluding Food and Energy)" },
  { regex: /\b(fed funds|federal funds rate|interest rate|fed rate)\b/i, seriesId: "FEDFUNDS", title: "Federal Funds Effective Rate" },
  { regex: /\b(10-year treasury|10 year yield|treasury yield)\b/i, seriesId: "DGS10", title: "10-Year Treasury Constant Maturity Rate" },
  { regex: /\b(unemployment rate|jobless rate)\b/i, seriesId: "UNRATE", title: "Civilian Unemployment Rate" },
  { regex: /\b(m2|money supply)\b/i, seriesId: "M2SL", title: "M2 Money Supply" },
];

export class FredAdapter {
  private static readonly TIMEOUT_MS = 800; // Hard 800ms SLA cap
  private static readonly BASE_URL = "https://api.stlouisfed.org/fred/series/observations";

  private get apiKey(): string | null {
    return process.env.FRED_API_KEY || null;
  }

  async searchObservations(query: string, options?: { signal?: AbortSignal }): Promise<FredHit[]> {
    if (!query || query.trim().length < 4) return [];

    const lower = query.toLowerCase();
    const matched = COMMON_FRED_SERIES.find((s) => s.regex.test(lower));
    if (!matched) return [];

    const apiKey = this.apiKey;
    if (!apiKey) {
      // If no key configured, return clean fallback without blocking
      return [];
    }

    try {
      const res = await axios.get(FredAdapter.BASE_URL, {
        params: {
          series_id: matched.seriesId,
          api_key: apiKey,
          file_type: "json",
          sort_order: "desc",
          limit: 3,
        },
        timeout: FredAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const observations: any[] = res.data?.observations || [];
      if (observations.length === 0) return [];

      const obsStr = observations
        .map((o) => `${o.date}: ${o.value}`)
        .join("; ");

      const url = `https://fred.stlouisfed.org/series/${matched.seriesId}`;
      const passage = `Federal Reserve Bank of St. Louis (FRED) official record for ${matched.title} [Series ID: ${matched.seriesId}]: Most recent observations: ${obsStr}. Published by the Federal Reserve System.`;

      return [
        {
          title: `FRED Official Metric: ${matched.title}`,
          url,
          passage,
          seriesId: matched.seriesId,
        },
      ];
    } catch (err: any) {
      logger.debug("[FredAdapter] Pre-retrieval completed or timed out cleanly", {
        seriesId: matched.seriesId,
        message: err?.message,
      });
      return [];
    }
  }
}

export const fredAdapter = new FredAdapter();
