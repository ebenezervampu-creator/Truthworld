import axios from "axios";
import { logger } from "../utils/logger";

export interface Tier0Context {
  claimId: string;
  context: string | null;
}

export class Tier0KnowledgeService {
  private static getWikipediaSearchUrl(lang: string = "en"): string {
    const safeLang = /^[a-z]{2,5}$/i.test(lang) ? lang.toLowerCase() : "en";
    return `https://${safeLang}.wikipedia.org/w/api.php`;
  }
  private static readonly MAX_TIMEOUT_MS = 1500; // Fast timeout for Tier-0

  /**
   * Fetches Wikipedia context for a batch of claims concurrently.
   */
  async getBatchContext(claims: { claimId: string; text: string }[], lang: string = "en"): Promise<Tier0Context[]> {
    if (claims.length === 0) return [];

    const promises = claims.map(async (claim) => {
      try {
        const context = await this.fetchWikipediaContext(claim.text, lang);
        return { claimId: claim.claimId, context };
      } catch (error) {
        logger.warn(`[Tier0] Failed to fetch Wikipedia context for claim ${claim.claimId}`, { error });
        return { claimId: claim.claimId, context: null };
      }
    });

    return Promise.all(promises);
  }

  /**
   * Cleans claim text and fetches the top Wikipedia snippet.
   */
  private async fetchWikipediaContext(query: string, lang: string = "en"): Promise<string | null> {
    try {
      // 1. Clean the query (remove emojis and leading phrases)
      const cleanQuery = query
        .replace(/^[🔍\s]+/, '') // Remove search emoji
        .replace(/^(The|A|An|In|According to) /i, '') // Remove common leading stop words
        .trim();

      // For long claims, extract the first 8 meaningful words for better search matching
      const searchTerms = cleanQuery.split(/\s+/).slice(0, 8).join(' ');

      if (searchTerms.length < 3) return null;

      const apiUrl = Tier0KnowledgeService.getWikipediaSearchUrl(lang);

      // 2. Search Wikipedia for the best matching page title
      const searchRes = await axios.get(apiUrl, {
        params: {
          action: 'query',
          list: 'search',
          srsearch: searchTerms,
          utf8: '',
          format: 'json',
          srlimit: 1
        },
        timeout: Tier0KnowledgeService.MAX_TIMEOUT_MS
      });

      const searchHits = searchRes.data?.query?.search;
      if (!searchHits || searchHits.length === 0) {
        return null;
      }

      const topTitle = searchHits[0].title;

      // 3. Fetch the extract for the matching page
      const extractRes = await axios.get(apiUrl, {
        params: {
          action: 'query',
          prop: 'extracts',
          exsentences: 3, // Top 3 sentences
          exlimit: 1,
          titles: topTitle,
          explaintext: 1, // Plain text
          formatversion: 2,
          format: 'json'
        },
        timeout: Tier0KnowledgeService.MAX_TIMEOUT_MS
      });

      const pages = extractRes.data?.query?.pages;
      if (pages && pages.length > 0 && pages[0].extract) {
        // Return a clean snippet
        const snippet = pages[0].extract.trim().replace(/\n/g, ' ');
        return `[Source: Wikipedia - ${topTitle}] ${snippet}`;
      }

      return null;
    } catch (error) {
      // Silently fail to not block the pipeline
      return null;
    }
  }
}

export const tier0KnowledgeService = new Tier0KnowledgeService();
