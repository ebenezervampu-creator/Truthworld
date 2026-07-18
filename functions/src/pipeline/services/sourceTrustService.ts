import * as admin from "firebase-admin";

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
  private dbRegistry: Record<string, SourceReputation> = {};
  private dbPublishers: any[] = [];
  private lastFetched = 0;
  private FETCH_INTERVAL_MS = 600_000; // 10 minutes cache

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

  private static readonly PUBLISHERS = [
    {
      name: "WHO",
      defaultTier: "A" as SourceTier,
      domains: ["who.int", "who.org"],
      socialHandles: [
        "youtube.com/@who",
        "youtube.com/c/worldhealthorganization",
        "youtube.com/user/who",
        "x.com/who",
        "twitter.com/who"
      ]
    },
    {
      name: "NASA",
      defaultTier: "A" as SourceTier,
      domains: ["nasa.gov"],
      socialHandles: [
        "youtube.com/@nasa",
        "youtube.com/nasatelevision",
        "x.com/nasa",
        "twitter.com/nasa"
      ]
    },
    {
      name: "CDC",
      defaultTier: "A" as SourceTier,
      domains: ["cdc.gov"],
      socialHandles: [
        "youtube.com/@cdc",
        "youtube.com/user/cdcstreaminghealth",
        "x.com/cdcgov",
        "twitter.com/cdcgov"
      ]
    },
    {
      name: "NIH",
      defaultTier: "A" as SourceTier,
      domains: ["nih.gov"],
      socialHandles: [
        "youtube.com/@nih",
        "x.com/nih",
        "twitter.com/nih"
      ]
    },
    {
      name: "Stanford University",
      defaultTier: "B" as SourceTier,
      domains: ["stanford.edu"],
      socialHandles: [
        "youtube.com/@stanford",
        "x.com/stanford",
        "twitter.com/stanford"
      ]
    },
    {
      name: "Harvard University",
      defaultTier: "B" as SourceTier,
      domains: ["harvard.edu"],
      socialHandles: [
        "youtube.com/@harvard",
        "x.com/harvard",
        "twitter.com/harvard"
      ]
    },
    {
      name: "MIT",
      defaultTier: "B" as SourceTier,
      domains: ["mit.edu"],
      socialHandles: [
        "youtube.com/@mit",
        "x.com/mit",
        "twitter.com/mit"
      ]
    },
    {
      name: "Google",
      defaultTier: "B" as SourceTier,
      domains: ["google.com", "blog.google"],
      socialHandles: [
        "youtube.com/@google",
        "x.com/google",
        "twitter.com/google"
      ]
    },
    {
      name: "Apple",
      defaultTier: "B" as SourceTier,
      domains: ["apple.com"],
      socialHandles: [
        "youtube.com/@apple",
        "x.com/apple",
        "twitter.com/apple"
      ]
    }
  ];

  /**
   * Dynamic Loader for Database-Backed Registry
   */
  async loadRegistry(): Promise<void> {
    const now = Date.now();
    if (now - this.lastFetched < this.FETCH_INTERVAL_MS) {
      return;
    }
    try {
      const snap = await admin.firestore().collection("source_registry").get();
      if (!snap.empty) {
        const newRegistry: Record<string, SourceReputation> = {};
        const newPublishers: any[] = [];

        snap.forEach(doc => {
          const data = doc.data();
          if (data.type === "reputation") {
            newRegistry[doc.id] = {
              domain: data.domain || doc.id,
              tier: data.tier || "E",
              reputationScore: data.reputationScore ?? 0.4,
              verticals: data.verticals || [],
              isOfficial: !!data.isOfficial
            };
          } else if (data.type === "publisher") {
            newPublishers.push({
              name: data.name || doc.id,
              defaultTier: data.defaultTier || "E",
              domains: data.domains || [],
              socialHandles: data.socialHandles || []
            });
          }
        });

        if (Object.keys(newRegistry).length > 0) {
          this.dbRegistry = newRegistry;
        }
        if (newPublishers.length > 0) {
          this.dbPublishers = newPublishers;
        }
        this.lastFetched = now;
        console.log(`[SourceTrustService] Loaded ${Object.keys(this.dbRegistry).length} trust domains from dynamic database registry`);
      }
    } catch (err) {
      console.warn("[SourceTrustService] Failed to load source_registry from Firestore, falling back to static registry", err);
    }
  }

  /**
   * Resolves the reputation and tier of a source URL.
   */
  resolveSourceTrust(url: string, vertical?: string): SourceReputation {
    const domain = this.extractDomain(url).toLowerCase();
    
    // Check dynamic registry first, fall back to static
    const rep = this.dbRegistry[domain] || SourceTrustService.TRUST_GRAPH[domain];

    if (rep) {
      // Apply vertical boost if the source is an expert in this field
      let score = rep.reputationScore;
      if (vertical && rep.verticals?.includes(vertical.toLowerCase())) {
        score = Math.min(1.0, score + 0.05);
      }
      return { ...rep, reputationScore: score };
    }

    // Dynamic Rule-Based Fallback Engine
    let tier: SourceTier = "E";
    let reputationScore = 0.4; // Default base trust

    // 1. Social/Forum/UGC
    const ugcPatterns = [/reddit\.com/i, /twitter\.com/i, /x\.com/i, /facebook\.com/i, /youtube\.com/i, /instagram\.com/i, /medium\.com/i, /quora\.com/i];
    // 2. Blog check
    const isBlog = domain.includes("blog") || domain.includes("wordpress") || domain.includes("tumblr");

    if (ugcPatterns.some(p => p.test(domain)) || isBlog) {
      tier = "E";
      reputationScore = 0.2;
    }
    // 3. .gov / .mil / .int
    else if (domain.endsWith(".gov") || domain.endsWith(".mil") || domain.endsWith(".int")) {
      tier = "A";
      reputationScore = 1.0;
    }
    // 4. Academic/Educational
    else if (domain.endsWith(".edu") || domain === "ac.uk" || domain.endsWith(".ac.uk") || domain.includes(".ac.") || domain.endsWith(".edu.cn") || domain.endsWith(".edu.in")) {
      tier = "B";
      reputationScore = 0.9;
    }
    // 5. .org
    else if (domain.endsWith(".org")) {
      tier = "C";
      reputationScore = 0.70;
    }
    // 6. News keywords
    else if (["news", "times", "journal", "post", "press", "daily", "herald", "tribune"].some(kw => domain.includes(kw))) {
      tier = "D";
      reputationScore = 0.50;
    }

    return {
      domain,
      tier,
      reputationScore,
      isOfficial: false
    };
  }

  /**
   * Extracts the root domain from a URL.
   */
  private extractDomain(url: string): string {
    try {
      let resolvedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        resolvedUrl = 'https://' + url;
      }
      const parsed = new URL(resolvedUrl);
      const hostname = parsed.hostname.toLowerCase().replace(/^www\./, '');
      const parts = hostname.split('.');
      if (parts.length > 2) {
        const lastTwo = parts.slice(-2).join('.');
        const multiPartSuffixes = new Set([
          'co.uk', 'ac.uk', 'gov.uk', 'org.uk', 'me.uk',
          'gov.in', 'edu.in', 'res.in', 'org.in', 'co.in',
          'gov.au', 'edu.au', 'com.au', 'org.au',
          'edu.cn', 'gov.cn', 'com.cn', 'net.cn', 'org.cn',
          'co.jp', 'ne.jp', 'go.jp', 'or.jp', 'ac.jp',
          'co.za', 'gov.za', 'org.za', 'co.nz', 'govt.nz'
        ]);
        if (multiPartSuffixes.has(lastTwo)) {
          return parts.slice(-3).join('.');
        }
        return parts.slice(-2).join('.');
      }
      return hostname;
    } catch {
      return url.replace(/^https?:\/\//, '').split('/')[0].toLowerCase().replace(/^www\./, '');
    }
  }


  /**
   * Returns a numerical weight for a tier to be used in scoring algorithms.
   */
  getTierWeight(tier: SourceTier): number {
    const weights = { "A": 1.0, "B": 0.85, "C": 0.7, "D": 0.5, "E": 0.3 };
    return weights[tier];
  }

  /**
   * Resolves official publishers from URLs and handles UGC filtering.
   */
  resolvePublisher(url: string): { publisher?: string; tier?: SourceTier; isSecondary?: boolean; isRejectedUgc?: boolean } {
    const urlLower = url.toLowerCase().replace(/^(https?:\/\/)?(www\.)?/, "");
    
    // Check if UGC domain
    const ugcDomains = ["youtube.com", "reddit.com", "x.com", "twitter.com"];
    const isUgc = ugcDomains.some(d => urlLower.startsWith(d));

    const allPublishers = [...this.dbPublishers, ...SourceTrustService.PUBLISHERS];

    if (isUgc) {
      // Find matching official social handle
      for (const pub of allPublishers) {
        for (const handle of pub.socialHandles) {
          if (urlLower.startsWith(handle) || urlLower.includes("/" + handle.split("/")[1])) {
            return {
              publisher: pub.name,
              tier: pub.defaultTier,
              isSecondary: true
            };
          }
        }
      }
      return { isRejectedUgc: true };
    }

    // Non-UGC: Find matching official domain
    const domain = this.extractDomain(url).toLowerCase();
    for (const pub of allPublishers) {
      if (pub.domains.includes(domain)) {
        return {
          publisher: pub.name,
          tier: pub.defaultTier
        };
      }
    }

    return {};
  }
}

export const sourceTrustService = new SourceTrustService();
