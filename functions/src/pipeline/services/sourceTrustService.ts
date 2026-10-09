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
    // Tier A: Global Multilateral / Scientific Bodies & Space Agencies
    "who.int": { domain: "who.int", tier: "A", reputationScore: 1.0, verticals: ["health"], isOfficial: true },
    "un.org": { domain: "un.org", tier: "A", reputationScore: 1.0, verticals: ["geopolitics", "human_rights"], isOfficial: true },
    "unesco.org": { domain: "unesco.org", tier: "A", reputationScore: 1.0, verticals: ["culture", "education", "science"], isOfficial: true },
    "wmo.int": { domain: "wmo.int", tier: "A", reputationScore: 1.0, verticals: ["climate", "weather"], isOfficial: true },
    "ipcc.ch": { domain: "ipcc.ch", tier: "A", reputationScore: 1.0, verticals: ["climate", "science"], isOfficial: true },
    "iaea.org": { domain: "iaea.org", tier: "A", reputationScore: 1.0, verticals: ["nuclear", "science"], isOfficial: true },
    "icrc.org": { domain: "icrc.org", tier: "A", reputationScore: 1.0, verticals: ["human_rights", "humanitarian"], isOfficial: true },
    "unicef.org": { domain: "unicef.org", tier: "A", reputationScore: 1.0, verticals: ["human_rights", "children"], isOfficial: true },
    "fao.org": { domain: "fao.org", tier: "A", reputationScore: 1.0, verticals: ["agriculture", "food"], isOfficial: true },
    "imf.org": { domain: "imf.org", tier: "A", reputationScore: 1.0, verticals: ["finance", "economics"], isOfficial: true },
    "worldbank.org": { domain: "worldbank.org", tier: "A", reputationScore: 1.0, verticals: ["finance", "economics"], isOfficial: true },
    "cdc.gov": { domain: "cdc.gov", tier: "A", reputationScore: 1.0, verticals: ["health"], isOfficial: true },
    "nih.gov": { domain: "nih.gov", tier: "A", reputationScore: 1.0, verticals: ["health", "science"], isOfficial: true },
    "noaa.gov": { domain: "noaa.gov", tier: "A", reputationScore: 1.0, verticals: ["climate", "weather", "ocean"], isOfficial: true },
    "nasa.gov": { domain: "nasa.gov", tier: "A", reputationScore: 1.0, verticals: ["space", "science"], isOfficial: true },
    "esa.int": { domain: "esa.int", tier: "A", reputationScore: 1.0, verticals: ["space", "science"], isOfficial: true },
    "isro.gov.in": { domain: "isro.gov.in", tier: "A", reputationScore: 1.0, verticals: ["space", "science"], isOfficial: true },
    "jaxa.jp": { domain: "jaxa.jp", tier: "A", reputationScore: 1.0, verticals: ["space", "science"], isOfficial: true },
    "cern.ch": { domain: "cern.ch", tier: "A", reputationScore: 1.0, verticals: ["physics", "science"], isOfficial: true },
    "nature.com": { domain: "nature.com", tier: "A", reputationScore: 1.0, verticals: ["science", "medical"], isOfficial: false },
    "science.org": { domain: "science.org", tier: "A", reputationScore: 1.0, verticals: ["science"], isOfficial: false },
    "thelancet.com": { domain: "thelancet.com", tier: "A", reputationScore: 1.0, verticals: ["medical", "health"], isOfficial: false },
    "cell.com": { domain: "cell.com", tier: "A", reputationScore: 1.0, verticals: ["biology", "science"], isOfficial: false },
    "pnas.org": { domain: "pnas.org", tier: "A", reputationScore: 1.0, verticals: ["science"], isOfficial: false },
    "nejm.org": { domain: "nejm.org", tier: "A", reputationScore: 1.0, verticals: ["medical"], isOfficial: false },
    "bmj.com": { domain: "bmj.com", tier: "A", reputationScore: 1.0, verticals: ["medical"], isOfficial: false },
    "britannica.com": { domain: "britannica.com", tier: "A", reputationScore: 0.98, verticals: ["history", "science", "general"], isOfficial: false },

    // Tier B: Gold Standard Global News & Verified Fact-Checking Networks
    "reuters.com": { domain: "reuters.com", tier: "B", reputationScore: 0.95, verticals: ["news", "geopolitics"], isOfficial: false },
    "apnews.com": { domain: "apnews.com", tier: "B", reputationScore: 0.95, verticals: ["news", "geopolitics"], isOfficial: false },
    "afp.com": { domain: "afp.com", tier: "B", reputationScore: 0.95, verticals: ["news", "geopolitics"], isOfficial: false },
    "dw.com": { domain: "dw.com", tier: "B", reputationScore: 0.94, verticals: ["news", "geopolitics"], isOfficial: false },
    "nhk.or.jp": { domain: "nhk.or.jp", tier: "B", reputationScore: 0.94, verticals: ["news", "culture"], isOfficial: false },
    "bloomberg.com": { domain: "bloomberg.com", tier: "B", reputationScore: 0.95, verticals: ["finance", "economics"], isOfficial: false },
    "wsj.com": { domain: "wsj.com", tier: "B", reputationScore: 0.95, verticals: ["finance", "news"], isOfficial: false },
    "ft.com": { domain: "ft.com", tier: "B", reputationScore: 0.95, verticals: ["finance", "economics"], isOfficial: false },
    "bbc.com": { domain: "bbc.com", tier: "B", reputationScore: 0.92, verticals: ["news", "geopolitics"], isOfficial: false },
    "nytimes.com": { domain: "nytimes.com", tier: "B", reputationScore: 0.92, verticals: ["news", "politics"], isOfficial: false },
    "thehindu.com": { domain: "thehindu.com", tier: "B", reputationScore: 0.93, verticals: ["news", "politics"], isOfficial: false },
    "indianexpress.com": { domain: "indianexpress.com", tier: "B", reputationScore: 0.92, verticals: ["news", "investigative"], isOfficial: false },
    "aljazeera.com": { domain: "aljazeera.com", tier: "B", reputationScore: 0.91, verticals: ["news", "geopolitics"], isOfficial: false },
    "lemonde.fr": { domain: "lemonde.fr", tier: "B", reputationScore: 0.92, verticals: ["news", "geopolitics"], isOfficial: false },
    "elpais.com": { domain: "elpais.com", tier: "B", reputationScore: 0.92, verticals: ["news", "geopolitics"], isOfficial: false },
    "allafrica.com": { domain: "allafrica.com", tier: "B", reputationScore: 0.90, verticals: ["news", "africa"], isOfficial: false },
    "clarin.com": { domain: "clarin.com", tier: "B", reputationScore: 0.90, verticals: ["news", "latin_america"], isOfficial: false },
    "straitstimes.com": { domain: "straitstimes.com", tier: "B", reputationScore: 0.91, verticals: ["news", "asia"], isOfficial: false },
    "fullfact.org": { domain: "fullfact.org", tier: "B", reputationScore: 0.95, verticals: ["fact_check"], isOfficial: false },
    "snopes.com": { domain: "snopes.com", tier: "B", reputationScore: 0.95, verticals: ["fact_check"], isOfficial: false },
    "politifact.com": { domain: "politifact.com", tier: "B", reputationScore: 0.94, verticals: ["fact_check"], isOfficial: false },
    "factcheck.org": { domain: "factcheck.org", tier: "B", reputationScore: 0.95, verticals: ["fact_check"], isOfficial: false },
    "africacheck.org": { domain: "africacheck.org", tier: "B", reputationScore: 0.94, verticals: ["fact_check"], isOfficial: false },
    "chequeado.com": { domain: "chequeado.com", tier: "B", reputationScore: 0.93, verticals: ["fact_check"], isOfficial: false },
    "boomlive.in": { domain: "boomlive.in", tier: "B", reputationScore: 0.93, verticals: ["fact_check"], isOfficial: false },
    "verafiles.org": { domain: "verafiles.org", tier: "B", reputationScore: 0.92, verticals: ["fact_check"], isOfficial: false },

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
    },
    {
      name: "ISRO",
      defaultTier: "A" as SourceTier,
      domains: ["isro.gov.in"],
      socialHandles: ["x.com/isro", "twitter.com/isro"]
    },
    {
      name: "ESA",
      defaultTier: "A" as SourceTier,
      domains: ["esa.int"],
      socialHandles: ["x.com/esa", "twitter.com/esa"]
    },
    {
      name: "SpaceX",
      defaultTier: "B" as SourceTier,
      domains: ["spacex.com"],
      socialHandles: ["x.com/spacex", "twitter.com/spacex"]
    },
    {
      name: "WION",
      defaultTier: "C" as SourceTier,
      domains: ["wionews.com"],
      socialHandles: ["youtube.com/@wion", "x.com/wionews"]
    },
    {
      name: "Visual Capitalist",
      defaultTier: "C" as SourceTier,
      domains: ["visualcapitalist.com"],
      socialHandles: ["x.com/visualcap"]
    },
    {
      name: "Wikipedia",
      defaultTier: "C" as SourceTier,
      domains: ["wikipedia.org", "en.wikipedia.org"],
      socialHandles: ["x.com/wikipedia"]
    },
    {
      name: "MDPI",
      defaultTier: "B" as SourceTier,
      domains: ["mdpi.com"],
      socialHandles: ["x.com/mdpiopenaccess"]
    },
    {
      name: "HeroX",
      defaultTier: "C" as SourceTier,
      domains: ["herox.com"],
      socialHandles: ["x.com/herox"]
    },
    {
      name: "Reuters",
      defaultTier: "B" as SourceTier,
      domains: ["reuters.com"],
      socialHandles: ["x.com/reuters"]
    },
    {
      name: "BBC",
      defaultTier: "B" as SourceTier,
      domains: ["bbc.com", "bbc.co.uk"],
      socialHandles: ["x.com/bbcnews"]
    },
    {
      name: "Bloomberg",
      defaultTier: "B" as SourceTier,
      domains: ["bloomberg.com"],
      socialHandles: ["x.com/bloomberg"]
    },
    {
      name: "AP News",
      defaultTier: "B" as SourceTier,
      domains: ["apnews.com"],
      socialHandles: ["x.com/ap"]
    },
    {
      name: "Associated Press",
      defaultTier: "B" as SourceTier,
      domains: ["apnews.com"],
      socialHandles: ["x.com/ap"]
    },
    {
      name: "Nature",
      defaultTier: "A" as SourceTier,
      domains: ["nature.com"],
      socialHandles: ["x.com/nature"]
    },
    {
      name: "Science",
      defaultTier: "A" as SourceTier,
      domains: ["science.org"],
      socialHandles: ["x.com/science"]
    },
    {
      name: "The Lancet",
      defaultTier: "A" as SourceTier,
      domains: ["thelancet.com"],
      socialHandles: ["x.com/thelancet"]
    },
    {
      name: "NEJM",
      defaultTier: "A" as SourceTier,
      domains: ["nejm.org"],
      socialHandles: ["x.com/nejm"]
    },
    {
      name: "BMJ",
      defaultTier: "A" as SourceTier,
      domains: ["bmj.com"],
      socialHandles: ["x.com/bmj_latest"]
    },
    {
      name: "PNAS",
      defaultTier: "A" as SourceTier,
      domains: ["pnas.org"],
      socialHandles: ["x.com/pnasnews"]
    },
    {
      name: "Wall Street Journal",
      defaultTier: "B" as SourceTier,
      domains: ["wsj.com"],
      socialHandles: ["x.com/wsj"]
    },
    {
      name: "WSJ",
      defaultTier: "B" as SourceTier,
      domains: ["wsj.com"],
      socialHandles: ["x.com/wsj"]
    },
    {
      name: "New York Times",
      defaultTier: "B" as SourceTier,
      domains: ["nytimes.com"],
      socialHandles: ["x.com/nytimes"]
    },
    {
      name: "The Guardian",
      defaultTier: "B" as SourceTier,
      domains: ["theguardian.com"],
      socialHandles: ["x.com/guardian"]
    },
    {
      name: "Financial Times",
      defaultTier: "B" as SourceTier,
      domains: ["ft.com"],
      socialHandles: ["x.com/ft"]
    },
    {
      name: "United Nations",
      defaultTier: "A" as SourceTier,
      domains: ["un.org"],
      socialHandles: ["x.com/un"]
    },
    {
      name: "UN",
      defaultTier: "A" as SourceTier,
      domains: ["un.org"],
      socialHandles: ["x.com/un"]
    },
    {
      name: "World Bank",
      defaultTier: "A" as SourceTier,
      domains: ["worldbank.org"],
      socialHandles: ["x.com/worldbank"]
    },
    {
      name: "IMF",
      defaultTier: "A" as SourceTier,
      domains: ["imf.org"],
      socialHandles: ["x.com/imfnews"]
    },
    {
      name: "NOAA",
      defaultTier: "A" as SourceTier,
      domains: ["noaa.gov"],
      socialHandles: ["x.com/noaa"]
    },
    {
      name: "FDA",
      defaultTier: "A" as SourceTier,
      domains: ["fda.gov"],
      socialHandles: ["x.com/us_fda"]
    },
    {
      name: "EPA",
      defaultTier: "A" as SourceTier,
      domains: ["epa.gov"],
      socialHandles: ["x.com/epa"]
    },
    {
      name: "USDA",
      defaultTier: "A" as SourceTier,
      domains: ["usda.gov"],
      socialHandles: ["x.com/usda"]
    },
    {
      name: "CERN",
      defaultTier: "A" as SourceTier,
      domains: ["cern.ch"],
      socialHandles: ["x.com/cern"]
    },
    {
      name: "Oxford University",
      defaultTier: "B" as SourceTier,
      domains: ["ox.ac.uk"],
      socialHandles: ["x.com/uniofoxford"]
    },
    {
      name: "Cambridge University",
      defaultTier: "B" as SourceTier,
      domains: ["cam.ac.uk"],
      socialHandles: ["x.com/cambridge_uni"]
    },
    {
      name: "Britannica",
      defaultTier: "B" as SourceTier,
      domains: ["britannica.com"],
      socialHandles: ["x.com/britannica"]
    },
    {
      name: "Snopes",
      defaultTier: "B" as SourceTier,
      domains: ["snopes.com"],
      socialHandles: ["x.com/snopes"]
    },
    {
      name: "PolitiFact",
      defaultTier: "B" as SourceTier,
      domains: ["politifact.com"],
      socialHandles: ["x.com/politifact"]
    },
    {
      name: "FactCheck.org",
      defaultTier: "B" as SourceTier,
      domains: ["factcheck.org"],
      socialHandles: ["x.com/factcheckdotorg"]
    },
    {
      name: "AFP",
      defaultTier: "B" as SourceTier,
      domains: ["afp.com", "factcheck.afp.com"],
      socialHandles: ["x.com/afp", "x.com/afpfactcheck"]
    },
    {
      name: "Deutsche Welle",
      defaultTier: "B" as SourceTier,
      domains: ["dw.com"],
      socialHandles: ["x.com/dwnews"]
    },
    {
      name: "NHK",
      defaultTier: "B" as SourceTier,
      domains: ["nhk.or.jp"],
      socialHandles: ["x.com/nhk_news"]
    },
    {
      name: "UNESCO",
      defaultTier: "A" as SourceTier,
      domains: ["unesco.org"],
      socialHandles: ["x.com/unesco"]
    },
    {
      name: "The Hindu",
      defaultTier: "B" as SourceTier,
      domains: ["thehindu.com"],
      socialHandles: ["x.com/the_hindu"]
    },
    {
      name: "Full Fact",
      defaultTier: "B" as SourceTier,
      domains: ["fullfact.org"],
      socialHandles: ["x.com/fullfact"]
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
    // 3. International government & intergovernmental bodies (.gov, .gov.*, .gob.*, .gouv.*, .govt.*, .go.*, .mil, .int, etc.)
    const isGov = /(?:^|\.)(?:gov|gob|gouv|govt|go|mil|int)(?:\.[a-z]{2,3})?$/i.test(domain) ||
                  domain.endsWith(".gov") || domain.endsWith(".mil") || domain.endsWith(".int") ||
                  domain.includes(".gov.") || domain.includes(".gob.") || domain.includes(".gouv.") ||
                  domain.includes(".govt.") || domain.includes(".go.") || domain.endsWith(".admin.ch");

    if (isGov) {
      tier = "A";
      reputationScore = 1.0;
    }
    // 4. International Academic / Educational institutions (.edu, .edu.*, .ac, .ac.*, etc.)
    else if (/(?:^|\.)(?:edu|ac)(?:\.[a-z]{2,3})?$/i.test(domain) ||
             domain.endsWith(".edu") || domain.includes(".edu.") || domain.includes(".ac.") ||
             domain.endsWith(".ac.uk") || domain.endsWith(".edu.cn") || domain.endsWith(".edu.in") ||
             domain.endsWith(".res.in")) {
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

  /**
   * Resolves the primary official domain for a publisher/organization name.
   */
  resolvePublisherDomain(publisherName: string): string | undefined {
    if (!publisherName || !publisherName.trim()) return undefined;
    const cleanName = publisherName.trim().toLowerCase();
    const cleanAlpha = cleanName.replace(/[^a-z0-9]/g, "");

    const allPublishers = [...this.dbPublishers, ...SourceTrustService.PUBLISHERS];
    for (const pub of allPublishers) {
      const pubLower = pub.name.toLowerCase();
      const pubAlpha = pubLower.replace(/[^a-z0-9]/g, "");
      if (pubLower === cleanName || pubAlpha === cleanAlpha || cleanName.includes(pubLower) || pubLower.includes(cleanName)) {
        if (pub.domains && pub.domains.length > 0) {
          return pub.domains[0];
        }
      }
    }
    return undefined;
  }
}

export const sourceTrustService = new SourceTrustService();
