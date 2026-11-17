import axios from "axios";
import { logger } from "../utils/logger";

export interface CrossrefHit {
  title: string;
  doiUrl: string;
  abstract?: string;
  subtitle?: string;
}

export class CrossrefAdapter {
  private static readonly BASE_URL = "https://api.crossref.org/works";
  private static readonly TIMEOUT_MS = 3500;
  private static readonly USER_AGENT = "TruthWorldFactCheckEngine/1.0 (mailto:ops@truthworld.co)";

  async searchWorks(query: string, options?: { limit?: number; signal?: AbortSignal }): Promise<CrossrefHit[]> {
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const limit = Math.min(options?.limit ?? 2, 5);
    try {
      const res = await axios.get(CrossrefAdapter.BASE_URL, {
        params: {
          query: trimmed,
          rows: limit,
          select: "DOI,title,abstract,subtitle,author,issued",
        },
        headers: { "User-Agent": CrossrefAdapter.USER_AGENT },
        timeout: CrossrefAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const items: any[] = res.data?.message?.items || [];
      const hits: CrossrefHit[] = [];

      for (const item of items) {
        const titleArr = Array.isArray(item.title) ? item.title : (item.title ? [item.title] : []);
        const rawTitle = titleArr[0];
        if (!rawTitle) continue;

        const doi = typeof item.DOI === "string" ? item.DOI.trim() : "";
        const doiUrl = doi ? `https://doi.org/${encodeURIComponent(doi)}` : "";
        if (!doiUrl) continue;

        const rawAbstract = typeof item.abstract === "string"
          ? item.abstract.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
          : undefined;

        const subArr = Array.isArray(item.subtitle) ? item.subtitle : (item.subtitle ? [item.subtitle] : []);
        const subtitle = subArr[0];

        hits.push({
          title: String(rawTitle).trim(),
          doiUrl,
          abstract: rawAbstract,
          subtitle: subtitle ? String(subtitle).trim() : undefined,
        });
      }

      return hits;
    } catch (err: any) {
      logger.warn("[CrossrefAdapter] Search failed cleanly", { query: trimmed, err: err?.message || String(err) });
      return [];
    }
  }
}

export const crossrefAdapter = new CrossrefAdapter();
