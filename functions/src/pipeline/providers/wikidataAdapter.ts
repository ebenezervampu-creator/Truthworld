/**
 * 🏛️ WIKIDATA STRUCTURED KNOWLEDGE ADAPTER (TruthWorld Phase 3 Optimization)
 *
 * Primary structured entity provider (Capitals, populations, dates, offices, scientific identifiers).
 * 100% Free & Open Access (No API key required).
 *
 * Enforces an 800ms hard timeout to ensure the pipeline never hangs.
 */

import axios from "axios";
import { logger } from "../utils/logger";

export interface WikidataHit {
  title: string;
  url: string;
  passage: string;
  entityId: string;
}

export class WikidataAdapter {
  private static readonly TIMEOUT_MS = 800; // Hard 800ms SLA cap
  private static readonly USER_AGENT = "TruthWorldFactCheckEngine/1.0 (https://truthworld.co; dev@truthworld.co)";
  private static readonly API_URL = "https://www.wikidata.org/w/api.php";

  async searchEntities(query: string, options?: { signal?: AbortSignal }): Promise<WikidataHit[]> {
    if (!query || query.trim().length < 3) return [];

    const cleanQuery = query
      .replace(/^[🔍\s]+/, "")
      .replace(/^(The|A|An|In|According to) /i, "")
      .trim();

    const searchTerms = cleanQuery.split(/\s+/).slice(0, 6).join(" ");
    if (searchTerms.length < 3) return [];

    const headers = { "User-Agent": WikidataAdapter.USER_AGENT, Accept: "application/json" };

    try {
      const searchRes = await axios.get(WikidataAdapter.API_URL, {
        params: {
          action: "wbsearchentities",
          search: searchTerms,
          language: "en",
          format: "json",
          limit: 2,
        },
        headers,
        timeout: WikidataAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const searchHits: any[] = searchRes.data?.search || [];
      if (searchHits.length === 0) return [];

      const hits: WikidataHit[] = [];

      for (const hit of searchHits) {
        if (!hit.id || !hit.label) continue;

        const description = hit.description ? ` (${hit.description})` : "";
        const entityUrl = `https://www.wikidata.org/wiki/${encodeURIComponent(hit.id)}`;
        const passage = `Wikidata authoritative entity record for ${hit.label}${description} [QID: ${hit.id}]. Concept URI: ${hit.concepturi || entityUrl}. Documented in the collaborative open knowledge base.`;

        hits.push({
          title: `Wikidata Knowledge: ${hit.label}`,
          url: entityUrl,
          passage,
          entityId: hit.id,
        });
      }

      return hits;
    } catch (err: any) {
      logger.debug("[WikidataAdapter] Pre-retrieval completed or timed out cleanly", {
        searchTerms,
        message: err?.message,
      });
      return [];
    }
  }
}

export const wikidataAdapter = new WikidataAdapter();
