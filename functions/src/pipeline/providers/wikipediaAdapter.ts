import axios from "axios";
import { logger } from "../utils/logger";

export interface WikipediaHit {
  title: string;
  url: string;
  extract: string;
}

export class WikipediaAdapter {
  private static readonly TIMEOUT_MS = 2500;
  private static readonly USER_AGENT = "TruthWorldFactCheckEngine/1.0 (https://truthworld.co; contact@truthworld.co)";

  async searchPassages(query: string, options?: { limit?: number; lang?: string; signal?: AbortSignal }): Promise<WikipediaHit[]> {
    const cleanQuery = query
      .replace(/^[🔍\s]+/, "")
      .replace(/^(The|A|An|In|According to) /i, "")
      .trim();

    const searchTerms = cleanQuery.split(/\s+/).slice(0, 8).join(" ");
    if (searchTerms.length < 3) return [];

    const lang = options?.lang || "en";
    const apiUrl = `https://${lang}.wikipedia.org/w/api.php`;
    const headers = { "User-Agent": WikipediaAdapter.USER_AGENT, Accept: "application/json" };

    try {
      const searchRes = await axios.get(apiUrl, {
        params: {
          action: "query",
          list: "search",
          srsearch: searchTerms,
          utf8: "",
          format: "json",
          srlimit: Math.min(options?.limit ?? 2, 5),
        },
        headers,
        timeout: WikipediaAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const searchHits: any[] = searchRes.data?.query?.search || [];
      if (searchHits.length === 0) return [];

      const hits: WikipediaHit[] = [];

      for (const hit of searchHits) {
        if (!hit.title) continue;
        const extractRes = await axios.get(apiUrl, {
          params: {
            action: "query",
            prop: "extracts",
            exsentences: 3,
            exlimit: 1,
            titles: hit.title,
            explaintext: 1,
            formatversion: 2,
            format: "json",
          },
          headers,
          timeout: WikipediaAdapter.TIMEOUT_MS,
          signal: options?.signal,
        });

        const pages = extractRes.data?.query?.pages;
        if (pages && pages.length > 0 && pages[0].extract) {
          const extract = pages[0].extract.trim().replace(/\n/g, " ");
          const url = `https://${lang}.wikipedia.org/wiki/${encodeURIComponent(hit.title.replace(/ /g, "_"))}`;
          hits.push({
            title: hit.title,
            url,
            extract,
          });
        }
      }

      return hits;
    } catch (err: any) {
      logger.warn("[WikipediaAdapter] Search failed cleanly", { query: searchTerms, err: err?.message || String(err) });
      return [];
    }
  }
}

export const wikipediaAdapter = new WikipediaAdapter();
