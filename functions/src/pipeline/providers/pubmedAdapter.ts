import axios from "axios";
import { logger } from "../utils/logger";

export interface PubMedHit {
  pmid: string;
  title: string;
  abstractText: string;
}

export class PubMedAdapter {
  private static readonly BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";
  private static readonly TIMEOUT_MS = 3500;
  private static readonly USER_AGENT = "TruthWorldFactCheckEngine/1.0 (https://truthworld.co)";

  async searchAbstracts(query: string, options?: { limit?: number; signal?: AbortSignal }): Promise<PubMedHit[]> {
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const limit = Math.min(options?.limit ?? 2, 5);
    try {
      const searchRes = await axios.get(`${PubMedAdapter.BASE_URL}/esearch.fcgi`, {
        params: {
          db: "pubmed",
          retmode: "json",
          retmax: limit,
          sort: "relevance",
          term: trimmed,
        },
        headers: { "User-Agent": PubMedAdapter.USER_AGENT },
        timeout: PubMedAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const idList: string[] = searchRes.data?.esearchresult?.idlist || [];
      if (idList.length === 0) return [];

      const summaryRes = await axios.get(`${PubMedAdapter.BASE_URL}/esummary.fcgi`, {
        params: {
          db: "pubmed",
          retmode: "json",
          id: idList.join(","),
        },
        headers: { "User-Agent": PubMedAdapter.USER_AGENT },
        timeout: PubMedAdapter.TIMEOUT_MS,
        signal: options?.signal,
      });

      const resultObj = summaryRes.data?.result || {};
      const hits: PubMedHit[] = [];

      for (const pmid of idList) {
        const rec = resultObj[pmid];
        if (!rec || !rec.title) continue;
        const journal = rec.fulljournalname || rec.source || "PubMed";
        const pubdate = rec.pubdate || "";
        const title = String(rec.title).replace(/\.$/, "").trim();
        const snippet = `${title}. Published in ${journal} (${pubdate}).`;
        hits.push({
          pmid,
          title,
          abstractText: snippet,
        });
      }

      return hits;
    } catch (err: any) {
      logger.warn("[PubMedAdapter] Search failed cleanly", { query: trimmed, err: err?.message || String(err) });
      return [];
    }
  }
}

export const pubmedAdapter = new PubMedAdapter();
