// No logger needed here yet

export type SourceTier = "A" | "B" | "C" | "D" | "E";

export interface SourceReputation {
  domain: string;
  tier: SourceTier;
  reputationScore: number; // 0.0 - 1.0
  verticals?: string[];    // Areas of high expertise
  isOfficial?: boolean;
}

/**
 * 🏛 v12.0: Source Trust Service (The Trust Graph)
 * 
 * Implements institutional-grade source reputation weighting.
 * Ensures that institutional sources (NOAA, CDC, Britannica) outrank 
 * blogs, social media, or general press.
 */
export class SourceTrustService {
  private static readonly TRUST_GRAPH: Record<string, SourceReputation> = {
    // Tier A: Global Institutional / Scientific Bodies
    "who.int": { domain: "who.int", tier: "A", reputationScore: 1.0, verticals: ["health"], isOfficial: true },
    "cdc.gov": { domain: "cdc.gov", tier: "A", reputationScore: 1.0, verticals: ["health"], isOfficial: true },
    "nih.gov": { domain: "nih.gov", tier: "A", reputationScore: 1.0, verticals: ["health", "science"], isOfficial: true },
    "noaa.gov": { domain: "noaa.gov", tier: "A", reputationScore: 1.0, verticals: ["climate", "weather", "ocean"], isOfficial: true },
    "nasa.gov": { domain: "nasa.gov", tier: "A", reputationScore: 1.0, verticals: ["space", "science"], isOfficial: true },
    "un.org": { domain: "un.org", tier: "A", reputationScore: 1.0, verticals: ["geopolitics", "human_rights"], isOfficial: true },
    "imf.org": { domain: "imf.org", tier: "A", reputationScore: 1.0, verticals: ["finance", "economics"], isOfficial: true },
    "worldbank.org": { domain: "worldbank.org", tier: "A", reputationScore: 1.0, verticals: ["finance", "economics"], isOfficial: true },
    "britannica.com": { domain: "britannica.com", tier: "A", reputationScore: 0.98, verticals: ["history", "science", "general"], isOfficial: false },
    "nature.com": { domain: "nature.com", tier: "A", reputationScore: 1.0, verticals: ["science", "medical"], isOfficial: false },
    "science.org": { domain: "science.org", tier: "A", reputationScore: 1.0, verticals: ["science"], isOfficial: false },

    // Tier B: Gold Standard News Agencies
    "reuters.com": { domain: "reuters.com", tier: "B", reputationScore: 0.95, verticals: ["news", "geopolitics"], isOfficial: false },
    "apnews.com": { domain: "apnews.com", tier: "B", reputationScore: 0.95, verticals: ["news", "geopolitics"], isOfficial: false },
    "bloomberg.com": { domain: "bloomberg.com", tier: "B", reputationScore: 0.95, verticals: ["finance", "economics"], isOfficial: false },
    "wsj.com": { domain: "wsj.com", tier: "B", reputationScore: 0.95, verticals: ["finance", "news"], isOfficial: false },
    "nytimes.com": { domain: "nytimes.com", tier: "B", reputationScore: 0.92, verticals: ["news", "politics"], isOfficial: false },
    "ft.com": { domain: "ft.com", tier: "B", reputationScore: 0.95, verticals: ["finance", "economics"], isOfficial: false },
    "bbc.com": { domain: "bbc.com", tier: "B", reputationScore: 0.92, verticals: ["news", "geopolitics"], isOfficial: false },

    // Tier C: Encyclopedic / Deep Knowledge
    "wikipedia.org": { domain: "wikipedia.org", tier: "C", reputationScore: 0.85, verticals: ["general"], isOfficial: false },
    "investopedia.com": { domain: "investopedia.com", tier: "C", reputationScore: 0.9, verticals: ["finance"], isOfficial: false },
    "healthline.com": { domain: "healthline.com", tier: "C", reputationScore: 0.8, verticals: ["health"], isOfficial: false },
    "sciencedirect.com": { domain: "sciencedirect.com", tier: "C", reputationScore: 0.95, verticals: ["science", "academic"], isOfficial: false },

    // Tier D: Mainstream Press
    "techcrunch.com": { domain: "techcrunch.com", tier: "D", reputationScore: 0.8, verticals: ["technology"], isOfficial: false },
    "theverge.com": { domain: "theverge.com", tier: "D", reputationScore: 0.8, verticals: ["technology"], isOfficial: false },
    "wired.com": { domain: "wired.com", tier: "D", reputationScore: 0.8, verticals: ["technology", "culture"], isOfficial: false },
    "forbes.com": { domain: "forbes.com", tier: "D", reputationScore: 0.75, verticals: ["business", "finance"], isOfficial: false },
    "guardian.com": { domain: "guardian.com", tier: "D", reputationScore: 0.85, verticals: ["news", "politics"], isOfficial: false },
  };

  /**
   * Resolves the reputation and tier of a source URL.
   */
  resolveSourceTrust(url: string, vertical?: string): SourceReputation {
    const domain = this.extractDomain(url);
    const rep = SourceTrustService.TRUST_GRAPH[domain];

    if (rep) {
      // Apply vertical boost if the source is an expert in this field
      let score = rep.reputationScore;
      if (vertical && rep.verticals?.includes(vertical.toLowerCase())) {
        score = Math.min(1.0, score + 0.05);
      }
      return { ...rep, reputationScore: score };
    }

    // Default for unknown sources
    return {
      domain,
      tier: this.inferTier(domain),
      reputationScore: 0.4, // Base trust for unknown domains
      isOfficial: false
    };
  }

  /**
   * Extracts the root domain from a URL.
   */
  private extractDomain(url: string): string {
    try {
      const parsed = new URL(url);
      const parts = parsed.hostname.split('.');
      if (parts.length > 2) {
        // Handle subdomains (e.g. en.wikipedia.org -> wikipedia.org)
        // This is a simple heuristic; a real system might use Public Suffix List
        return parts.slice(-2).join('.');
      }
      return parsed.hostname;
    } catch {
      return url.replace(/^https?:\/\//, '').split('/')[0];
    }
  }

  /**
   * Infers tier based on TLD if domain not in graph.
   */
  private inferTier(domain: string): SourceTier {
    if (domain.endsWith(".gov") || domain.endsWith(".mil") || domain.endsWith(".int") || domain.endsWith(".edu")) return "A";
    return "E";
  }

  /**
   * Returns a numerical weight for a tier to be used in scoring algorithms.
   */
  getTierWeight(tier: SourceTier): number {
    const weights = { "A": 1.0, "B": 0.85, "C": 0.7, "D": 0.5, "E": 0.3 };
    return weights[tier];
  }
}

export const sourceTrustService = new SourceTrustService();
