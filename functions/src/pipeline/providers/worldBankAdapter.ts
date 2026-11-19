/**
 * 🏛️ WORLD BANK DATA ADAPTER (TruthWorld Phase 3 Optimization)
 *
 * Primary economic indicator provider (GDP, Inflation, Unemployment, Population, Trade).
 * 100% Free & Open Access (No API key required).
 *
 * Enforces an 800ms hard timeout to ensure the pipeline never hangs.
 */

import axios from "axios";
import { logger } from "../utils/logger";

export interface WorldBankHit {
  title: string;
  url: string;
  passage: string;
  indicator: string;
  country: string;
}

const COMMON_INDICATOR_MAP: Array<{ regex: RegExp; code: string; name: string }> = [
  { regex: /\b(inflation|cpi|consumer price)\b/i, code: "FP.CPI.TOTL.ZG", name: "Inflation, consumer prices (annual %)" },
  { regex: /\b(gdp growth|economic growth)\b/i, code: "NY.GDP.MKTP.KD.ZG", name: "GDP growth (annual %)" },
  { regex: /\b(gdp|gross domestic product)\b/i, code: "NY.GDP.MKTP.CD", name: "GDP (current US$)" },
  { regex: /\b(unemployment|jobless)\b/i, code: "SL.UEM.TOTL.ZS", name: "Unemployment, total (% of total labor force)" },
  { regex: /\b(population|demographic)\b/i, code: "SP.POP.TOTL", name: "Population, total" },
];

const COUNTRY_CODE_MAP: Record<string, string> = {
  "united states": "USA", "us": "USA", "usa": "USA", "america": "USA",
  "india": "IND", "indian": "IND",
  "china": "CHN", "chinese": "CHN",
  "united kingdom": "GBR", "uk": "GBR", "britain": "GBR",
  "germany": "DEU", "france": "FRA", "japan": "JPN",
  "brazil": "BRA", "canada": "CAN", "global": "WLD", "world": "WLD",
};

export class WorldBankAdapter {
  private static readonly TIMEOUT_MS = 800; // Hard 800ms SLA cap
  private static readonly BASE_URL = "https://api.worldbank.org/v2";

  async searchIndicators(query: string, options?: { signal?: AbortSignal }): Promise<WorldBankHit[]> {
    if (!query || query.trim().length < 4) return [];

    const lower = query.toLowerCase();

    // Match indicator
    const matchedIndicator = COMMON_INDICATOR_MAP.find((m) => m.regex.test(lower));
    if (!matchedIndicator) return [];

    // Match country (default to USA if 'us'/'america' or WLD for world)
    let countryCode = "USA";
    for (const [name, code] of Object.entries(COUNTRY_CODE_MAP)) {
      if (new RegExp(`\\b${name}\\b`, "i").test(lower)) {
        countryCode = code;
        break;
      }
    }

    const url = `${WorldBankAdapter.BASE_URL}/country/${countryCode}/indicator/${matchedIndicator.code}`;

    try {
      const res = await axios.get(url, {
        params: {
          format: "json",
          mrv: 4, // Most recent 4 years
          per_page: 5,
        },
        timeout: WorldBankAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const records = res.data?.[1];
      if (!Array.isArray(records) || records.length === 0) return [];

      const validObservations = records
        .filter((r: any) => r.value !== null && r.value !== undefined)
        .slice(0, 3);

      if (validObservations.length === 0) return [];

      const latest = validObservations[0];
      const countryName = latest.country?.value || countryCode;
      const historyStr = validObservations
        .map((r: any) => `${r.date}: ${typeof r.value === "number" ? r.value.toFixed(2) : r.value}`)
        .join("; ");

      const title = `World Bank Official Data: ${matchedIndicator.name} (${countryName})`;
      const webUrl = `https://data.worldbank.org/indicator/${matchedIndicator.code}?locations=${countryCode}`;
      const passage = `World Bank authoritative records for ${countryName} - ${matchedIndicator.name}: ${historyStr}. Metric published by the World Bank Development Indicators database.`;

      return [
        {
          title,
          url: webUrl,
          passage,
          indicator: matchedIndicator.code,
          country: countryName,
        },
      ];
    } catch (err: any) {
      // Graceful 800ms timeout / network fallback
      logger.debug("[WorldBankAdapter] Pre-retrieval completed or timed out cleanly", {
        query: query.slice(0, 40),
        message: err?.message,
      });
      return [];
    }
  }
}

export const worldBankAdapter = new WorldBankAdapter();
