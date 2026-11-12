import * as admin from "firebase-admin";
import { EvidenceRole, EvidentiaryStance, ClaimStatus } from "../types";

export type SourceTier = "A" | "B" | "C" | "D" | "E";

export interface EpistemicInvariantResult {
  invariantVerdict: ClaimStatus;
  supportMass: number;
  contradictMass: number;
  highestTierSupport?: SourceTier;
  highestTierContradict?: SourceTier;
  isOverridden: boolean;
  reason: string;
}

export interface SourceReputation {
  domain: string;
  tier: SourceTier;
  reputationScore: number; // 0.0 - 1.0
  verticals?: string[];    // Areas of high expertise
  isOfficial?: boolean;
  isRetracted?: boolean;
  retractionReason?: string;
  isProvisionallyDowngraded?: boolean;
}

export interface FormalRetractionRecord {
  targetUrlOrDoi: string;
  sourceDomain: string;
  retractingEntity: string;
  reason: string;
  retractedAtUtc: string;
  formalNoticeUrl?: string;
}

export interface ProvisionalDowngradeRecord {
  domain: string;
  downgradedTier: SourceTier;
  reducedReputationScore: number;
  reason: string;
  authorizedByQuorum: boolean;
  authorizedAtUtc: string;
}

/**
 * 🏛 v12.0: Source Trust Service (The Trust Graph)
 * 
 * Implements institutional and news-agency source reputation weighting.
 * Tier A: Intergovernmental & scientific authorities (WHO, UN, NOAA, NASA, Nature, Lancet)
 *         AND premier global wire services (Reuters, AP, AFP, Bloomberg) with frontline bureaus.
 * Tier B: Esteemed international investigative journalism (BBC, NYT, WSJ, FT), IFCN fact-checkers,
 *         and curated reference encyclopedias (Britannica).
 * Tier C: Open encyclopedias & specialized repositories (Wikipedia, Investopedia).
 * Tier D: General commercial and tech press.
 * Tier E: UGC, unverified social media, and personal blogs.
 */
export class SourceTrustService {
  private dbRegistry: Record<string, SourceReputation> = {};
  private dbPublishers: any[] = [];
  private lastFetched = 0;
  private FETCH_INTERVAL_MS = 600_000; // 10 minutes cache

  // Formal scientific/journal retractions registry
  private formalRetractions: Map<string, FormalRetractionRecord> = new Map();
  // Authorized institutional provisional downgrades (ombudsman/quorum approved)
  private provisionalDowngrades: Map<string, ProvisionalDowngradeRecord> = new Map();

  /**
   * Register a formal publication, study, or artifact retraction.
   * Invalidates specific articles or DOIs, reducing their reputation weight to 0.0.
   */
  public registerFormalRetraction(record: FormalRetractionRecord): void {
    const key = record.targetUrlOrDoi.toLowerCase().trim();
    this.formalRetractions.set(key, record);
  }

  /**
   * Check if a specific URL, DOI, or artifact is formally retracted.
   */
  public isRetracted(urlOrDoi: string): boolean {
    if (!urlOrDoi) return false;
    const clean = urlOrDoi.toLowerCase().trim();
    if (this.formalRetractions.has(clean)) return true;
    for (const [key] of this.formalRetractions.entries()) {
      if (clean.includes(key) || key.includes(clean)) return true;
    }
    return false;
  }

  /**
   * Apply an authorized provisional institutional downgrade.
   * Authorized by multi-signatory ombudsman quorum (e.g., following systemic misconduct).
   * Note: Raw community report spikes CANNOT trigger this (protected by TN-08).
   */
  public applyAuthorizedProvisionalDowngrade(record: ProvisionalDowngradeRecord): void {
    if (!record.authorizedByQuorum) {
      throw new Error("Provisional downgrade rejected: Multi-signatory quorum authorization required.");
    }
    const cleanDomain = record.domain.toLowerCase().trim();
    this.provisionalDowngrades.set(cleanDomain, record);
  }

  /**
   * Clear test overrides.
   */
  public resetDynamicOverrides(): void {
    this.formalRetractions.clear();
    this.provisionalDowngrades.clear();
  }

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
    "cancer.gov": { domain: "cancer.gov", tier: "A", reputationScore: 1.0, verticals: ["health", "science", "medical"], isOfficial: true },
    "cancerresearchuk.org": { domain: "cancerresearchuk.org", tier: "A", reputationScore: 1.0, verticals: ["health", "medical", "science"], isOfficial: true },

    // Tier A: Gold Standard Global Wire Services & Primary Real-Time News Agencies
    "reuters.com": { domain: "reuters.com", tier: "A", reputationScore: 0.99, verticals: ["news", "geopolitics", "finance", "investigative"], isOfficial: false },
    "apnews.com": { domain: "apnews.com", tier: "A", reputationScore: 0.99, verticals: ["news", "geopolitics", "investigative"], isOfficial: false },
    "afp.com": { domain: "afp.com", tier: "A", reputationScore: 0.99, verticals: ["news", "geopolitics"], isOfficial: false },
    "bloomberg.com": { domain: "bloomberg.com", tier: "A", reputationScore: 0.98, verticals: ["finance", "economics", "markets", "news"], isOfficial: false },

    // Tier A: Independent Non-Profit Investigative Journalism & Open-Source Telemetry (OSINT)
    "propublica.org": { domain: "propublica.org", tier: "A", reputationScore: 0.98, verticals: ["investigative", "politics", "public_interest"], isOfficial: false },
    "bellingcat.com": { domain: "bellingcat.com", tier: "A", reputationScore: 0.97, verticals: ["investigative", "geopolitics", "conflict", "osint"], isOfficial: false },
    "icij.org": { domain: "icij.org", tier: "A", reputationScore: 0.98, verticals: ["investigative", "finance", "global"], isOfficial: false },
    "ourworldindata.org": { domain: "ourworldindata.org", tier: "A", reputationScore: 0.98, verticals: ["science", "economics", "health", "climate"], isOfficial: false },
    "archive.org": { domain: "archive.org", tier: "A", reputationScore: 0.99, verticals: ["history", "archive", "primary_source"], isOfficial: false },
    "biblegateway.com": { domain: "biblegateway.com", tier: "B", reputationScore: 0.90, verticals: ["religion", "scripture", "history"], isOfficial: true },
    "quran.com": { domain: "quran.com", tier: "B", reputationScore: 0.90, verticals: ["religion", "scripture"], isOfficial: true },
    "sefaria.org": { domain: "sefaria.org", tier: "B", reputationScore: 0.90, verticals: ["religion", "scripture"], isOfficial: true },
    "gutenberg.org": { domain: "gutenberg.org", tier: "B", reputationScore: 0.90, verticals: ["literature", "history", "primary_source"], isOfficial: true },

    // Tier B: Esteemed Global Broadcasters, Investigative Press, Curated Reference & Fact-Checking Networks
    "britannica.com": { domain: "britannica.com", tier: "B", reputationScore: 0.92, verticals: ["history", "science", "reference", "general"], isOfficial: false },
    "arxiv.org": { domain: "arxiv.org", tier: "B", reputationScore: 0.93, verticals: ["physics", "science", "mathematics"], isOfficial: false },
    "dw.com": { domain: "dw.com", tier: "B", reputationScore: 0.94, verticals: ["news", "geopolitics"], isOfficial: false },
    "nhk.or.jp": { domain: "nhk.or.jp", tier: "B", reputationScore: 0.94, verticals: ["news", "culture"], isOfficial: false },
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
      defaultTier: "A" as SourceTier,
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
      defaultTier: "A" as SourceTier,
      domains: ["bloomberg.com"],
      socialHandles: ["x.com/bloomberg"]
    },
    {
      name: "AP News",
      defaultTier: "A" as SourceTier,
      domains: ["apnews.com"],
      socialHandles: ["x.com/ap"]
    },
    {
      name: "Associated Press",
      defaultTier: "A" as SourceTier,
      domains: ["apnews.com"],
      socialHandles: ["x.com/ap"]
    },
    {
      name: "ProPublica",
      defaultTier: "A" as SourceTier,
      domains: ["propublica.org"],
      socialHandles: ["x.com/propublica"]
    },
    {
      name: "Bellingcat",
      defaultTier: "A" as SourceTier,
      domains: ["bellingcat.com"],
      socialHandles: ["x.com/bellingcat"]
    },
    {
      name: "ICIJ",
      defaultTier: "A" as SourceTier,
      domains: ["icij.org"],
      socialHandles: ["x.com/icijorg"]
    },
    {
      name: "Our World in Data",
      defaultTier: "A" as SourceTier,
      domains: ["ourworldindata.org"],
      socialHandles: ["x.com/ourworldindata"]
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
      defaultTier: "A" as SourceTier,
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

    // 1. Check if the specific URL or artifact is formally retracted
    if (this.isRetracted(url)) {
      const retraction = [...this.formalRetractions.values()].find(r => 
        url.toLowerCase().includes(r.targetUrlOrDoi.toLowerCase())
      );
      return {
        domain,
        tier: "E",
        reputationScore: 0.0,
        isOfficial: false,
        isRetracted: true,
        retractionReason: retraction?.reason || "Formally retracted by publishing journal or authority."
      };
    }

    // 2. Check if the domain has an authorized provisional downgrade
    const downgrade = this.provisionalDowngrades.get(domain);
    if (downgrade) {
      return {
        domain,
        tier: downgrade.downgradedTier,
        reputationScore: downgrade.reducedReputationScore,
        isOfficial: false,
        isProvisionallyDowngraded: true,
      };
    }
    
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
    const ugcPatterns = [
      /reddit\.com/i, /twitter\.com/i, /x\.com/i, /facebook\.com/i, /youtube\.com/i,
      /instagram\.com/i, /medium\.com/i, /quora\.com/i, /scribd\.com/i, /tiktok\.com/i,
      /threads\.net/i, /substack\.com/i, /linkedin\.com/i, /pinterest\.com/i
    ];
    // 2. Blog check
    const isBlog = domain.includes("blog") || domain.includes("wordpress") || domain.includes("tumblr") || domain.includes("blogspot");

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
  resolvePublisher(url: string): {
    publisher?: string;
    tier?: SourceTier;
    isSecondary?: boolean;
    isRejectedUgc?: boolean;
    isQuarantined?: boolean;
    isScribd?: boolean;
    rejectionReason?: string;
  } {
    const urlLower = url.toLowerCase().replace(/^(https?:\/\/)?(www\.)?/, "");
    
    // Explicit platforms with hard rejections
    if (urlLower.startsWith("scribd.com")) {
      return {
        isRejectedUgc: true,
        isQuarantined: true,
        isScribd: true,
        tier: "E",
        rejectionReason: "UGC document platform (Scribd) is quarantined and cannot serve as authoritative evidence"
      };
    }
    if (urlLower.startsWith("reddit.com")) {
      return {
        isRejectedUgc: true,
        tier: "E",
        rejectionReason: "UGC forum (Reddit) cannot serve as authoritative evidence"
      };
    }
    if (urlLower.startsWith("quora.com")) {
      return {
        isRejectedUgc: true,
        tier: "E",
        rejectionReason: "UGC forum (Quora) cannot serve as authoritative evidence"
      };
    }
    if (urlLower.startsWith("medium.com") || urlLower.startsWith("substack.com") || urlLower.startsWith("wordpress.com") || urlLower.startsWith("blogspot.com") || urlLower.startsWith("tumblr.com")) {
      return {
        isRejectedUgc: true,
        tier: "E",
        rejectionReason: "Independent blog/self-publishing platform cannot serve as primary authoritative evidence"
      };
    }

    const socialDomains = ["youtube.com", "x.com", "twitter.com", "tiktok.com", "facebook.com", "instagram.com", "threads.net", "linkedin.com", "pinterest.com", "t.me", "telegram.org"];
    const isSocial = socialDomains.some(d => urlLower.startsWith(d));

    const allPublishers = [...this.dbPublishers, ...SourceTrustService.PUBLISHERS];

    if (isSocial) {
      // Find matching official social handle (must match domain and channel/account path)
      for (const pub of allPublishers) {
        for (const handle of pub.socialHandles) {
          const cleanHandle = handle.toLowerCase().replace(/^(https?:\/\/)?(www\.)?/, "");
          if (urlLower === cleanHandle || urlLower.startsWith(cleanHandle + "/") || urlLower.startsWith(cleanHandle + "?")) {
            return {
              publisher: pub.name,
              tier: pub.defaultTier,
              isSecondary: true
            };
          }
        }
      }
      return {
        isRejectedUgc: true,
        tier: "E",
        rejectionReason: "Unverified social media content cannot serve as authoritative evidence"
      };
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

  /**
   * P7.1: Domain-Role Precedence Matrix (M_domain).
   * Maps claim domain context and evidence role to a precedence multiplier [0.0 - 1.0].
   * Ensures primary records take precedence in legal/finance, meta-analyses in health,
   * and frontline investigative reporting in breaking news.
   */
  public getDomainRoleMultiplier(domainContext: string, role: EvidenceRole): number {
    const d = (domainContext || "general").toLowerCase().trim();

    // Legal / Regulatory Domain
    if (d.includes("legal") || d.includes("court") || d.includes("crime") || d.includes("law") || d.includes("regulatory")) {
      switch (role) {
        case EvidenceRole.PRIMARY_RECORD: return 1.0;            // Official court docket / gazette
        case EvidenceRole.INVESTIGATIVE_REPORTING: return 0.75;  // Investigative press reporting on filings
        case EvidenceRole.INDEPENDENT_CORROBORATION: return 0.70;
        case EvidenceRole.EXPERT_SYNTHESIS: return 0.65;
        case EvidenceRole.OFFICIAL_ASSERTION: return 0.40;       // Statement by accused/litigant
        case EvidenceRole.SECONDARY_COMMENTARY: return 0.30;
        default: return 0.50;
      }
    }

    // Health / Clinical / Medical Domain
    if (d.includes("health") || d.includes("medical") || d.includes("pharma") || d.includes("clinical") || d.includes("epidemiology")) {
      switch (role) {
        case EvidenceRole.EXPERT_SYNTHESIS: return 1.0;          // Systematic reviews, meta-analyses (Cochrane, Lancet)
        case EvidenceRole.PRIMARY_RECORD: return 0.90;           // Published clinical trial results
        case EvidenceRole.INDEPENDENT_CORROBORATION: return 0.80;
        case EvidenceRole.OFFICIAL_ASSERTION: return 0.60;       // Public health body advisory
        case EvidenceRole.INVESTIGATIVE_REPORTING: return 0.50;
        case EvidenceRole.SECONDARY_COMMENTARY: return 0.30;
        default: return 0.50;
      }
    }

    // Breaking News / Geopolitics / Conflict
    if (d.includes("news") || d.includes("geopolitics") || d.includes("conflict") || d.includes("war") || d.includes("politics")) {
      switch (role) {
        case EvidenceRole.INVESTIGATIVE_REPORTING: return 1.0;   // Frontline wire bureau / verified OSINT
        case EvidenceRole.OFFICIAL_ASSERTION: return 0.85;       // Diplomatic communiqué / official statement
        case EvidenceRole.INDEPENDENT_CORROBORATION: return 0.85;
        case EvidenceRole.PRIMARY_RECORD: return 0.80;
        case EvidenceRole.EXPERT_SYNTHESIS: return 0.40;         // Stale post-event analysis
        case EvidenceRole.SECONDARY_COMMENTARY: return 0.30;
        default: return 0.50;
      }
    }

    // Economics / Finance Domain
    if (d.includes("finance") || d.includes("economy") || d.includes("economic") || d.includes("market") || d.includes("banking")) {
      switch (role) {
        case EvidenceRole.PRIMARY_RECORD: return 1.0;            // Central bank ledger, SEC/MCA filings, census
        case EvidenceRole.INVESTIGATIVE_REPORTING: return 0.85;  // Financial press investigative pieces
        case EvidenceRole.EXPERT_SYNTHESIS: return 0.80;
        case EvidenceRole.INDEPENDENT_CORROBORATION: return 0.75;
        case EvidenceRole.OFFICIAL_ASSERTION: return 0.60;
        case EvidenceRole.SECONDARY_COMMENTARY: return 0.35;
        default: return 0.50;
      }
    }

    // Science / Technology Domain
    if (d.includes("science") || d.includes("technology") || d.includes("tech") || d.includes("physics") || d.includes("astronomy")) {
      switch (role) {
        case EvidenceRole.EXPERT_SYNTHESIS: return 1.0;          // Meta-analyses / literature reviews
        case EvidenceRole.PRIMARY_RECORD: return 0.95;           // Original peer-reviewed journal papers
        case EvidenceRole.INDEPENDENT_CORROBORATION: return 0.85;
        case EvidenceRole.INVESTIGATIVE_REPORTING: return 0.75;
        case EvidenceRole.OFFICIAL_ASSERTION: return 0.65;
        case EvidenceRole.SECONDARY_COMMENTARY: return 0.40;
        default: return 0.50;
      }
    }

    // General / Default Domain
    switch (role) {
      case EvidenceRole.PRIMARY_RECORD: return 0.95;
      case EvidenceRole.EXPERT_SYNTHESIS: return 0.90;
      case EvidenceRole.INDEPENDENT_CORROBORATION: return 0.85;
      case EvidenceRole.INVESTIGATIVE_REPORTING: return 0.80;
      case EvidenceRole.OFFICIAL_ASSERTION: return 0.65;
      case EvidenceRole.SECONDARY_COMMENTARY: return 0.40;
      default: return 0.50;
    }
  }

  /**
   * P7.1: Calculates non-negative Evidentiary Capacity (C_s >= 0).
   * C_s = W_base * M_domain * Relevance * Independence
   */
  public calculateEvidentiaryCapacity(params: {
    baseReliability: number;
    domainContext?: string;
    role?: EvidenceRole;
    relevance?: number;
    independenceFactor?: number;
  }): number {
    const wBase = Math.max(0.0, Math.min(1.0, params.baseReliability ?? 0.5));
    const mDomain = this.getDomainRoleMultiplier(
      params.domainContext || "general",
      params.role || EvidenceRole.SECONDARY_COMMENTARY
    );
    const relevance = Math.max(0.0, Math.min(1.0, params.relevance ?? 1.0));
    const independence = Math.max(0.2, Math.min(1.0, params.independenceFactor ?? 1.0));

    const capacity = wBase * mDomain * relevance * independence;
    return Math.max(0.0, Math.min(1.0, Math.round(capacity * 1000) / 1000));
  }

  /**
   * P7.1: Dual-Mass Aggregation & Epistemic Invariant Evaluator.
   * Enforces the non-negotiable rule: unproven is the epistemic null state.
   * false_claim strictly requires affirmative contradiction from reliable sources.
   */
  public evaluateDualMassInvariants(
    sources: Array<{
      evidentiaryCapacity?: number;
      stance?: EvidentiaryStance;
      tier?: SourceTier;
      role?: EvidenceRole;
      isContradictory?: boolean;
    }>,
    proposedVerdict?: ClaimStatus
  ): EpistemicInvariantResult {
    let supportMass = 0.0;
    let contradictMass = 0.0;

    let hasTierASupport = false;
    let hasTierBSupport = false;
    let hasTierAContradict = false;
    let hasTierBContradict = false;

    for (const s of sources) {
      const cap = Math.max(0.0, s.evidentiaryCapacity ?? 0.5);
      const isContradictory = s.stance === "CONTRADICTS" || s.isContradictory === true;
      const isSupporting = s.stance === "SUPPORTS" || (!isContradictory && s.stance !== "NEUTRAL" && s.stance !== "CONTEXTUAL");

      if (isContradictory) {
        contradictMass += cap;
        if (s.tier === "A") hasTierAContradict = true;
        if (s.tier === "B") hasTierBContradict = true;
      } else if (isSupporting) {
        supportMass += cap;
        if (s.tier === "A") hasTierASupport = true;
        if (s.tier === "B") hasTierBSupport = true;
      }
    }

    supportMass = Math.round(supportMass * 100) / 100;
    contradictMass = Math.round(contradictMass * 100) / 100;

    const highestTierSupport: SourceTier | undefined = hasTierASupport ? "A" : hasTierBSupport ? "B" : undefined;
    const highestTierContradict: SourceTier | undefined = hasTierAContradict ? "A" : hasTierBContradict ? "B" : undefined;

    // 1. Strict False Claim Invariant
    // Requires affirmative empirical contradiction mass >= 1.5 AND authoritative contradictor (Tier A or B)
    if (contradictMass >= 1.5 && (hasTierAContradict || hasTierBContradict) && supportMass < 0.4) {
      return {
        invariantVerdict: "false_claim",
        supportMass,
        contradictMass,
        highestTierSupport,
        highestTierContradict,
        isOverridden: proposedVerdict !== "false_claim",
        reason: `Substantiated contradiction: Contradict mass ${contradictMass} >= 1.5 with ${highestTierContradict}-tier evidence.`
      };
    }

    // 2. Strict Verified True Invariant
    if (supportMass >= 1.5 && (hasTierASupport || hasTierBSupport) && contradictMass < 0.3) {
      return {
        invariantVerdict: "verified_true",
        supportMass,
        contradictMass,
        highestTierSupport,
        highestTierContradict,
        isOverridden: proposedVerdict !== "verified_true",
        reason: `Substantiated confirmation: Support mass ${supportMass} >= 1.5 with ${highestTierSupport}-tier corroboration.`
      };
    }

    // 3. Mostly True Invariant
    if (supportMass >= 1.2 && contradictMass < 0.5) {
      return {
        invariantVerdict: "mostly_true",
        supportMass,
        contradictMass,
        highestTierSupport,
        highestTierContradict,
        isOverridden: proposedVerdict !== "mostly_true",
        reason: `Substantial corroboration: Support mass ${supportMass} >= 1.2 with minimal contradiction.`
      };
    }

    // 4. Disputed Invariant (both sides have substantial mass)
    if (supportMass >= 1.0 && contradictMass >= 1.0) {
      return {
        invariantVerdict: "disputed",
        supportMass,
        contradictMass,
        highestTierSupport,
        highestTierContradict,
        isOverridden: proposedVerdict !== "disputed",
        reason: `Contested evidence: Substantial conflicting evidence (Support: ${supportMass}, Contradict: ${contradictMass}).`
      };
    }

    // 5. Invariant Guard: Prevent absence-of-evidence being labeled as false_claim
    if (proposedVerdict === "false_claim" || proposedVerdict === "verified_false") {
      if (contradictMass < 1.0 || (!hasTierAContradict && !hasTierBContradict)) {
        return {
          invariantVerdict: "unproven",
          supportMass,
          contradictMass,
          highestTierSupport,
          highestTierContradict,
          isOverridden: true,
          reason: `P7.1 Invariant Overrule: Claim was proposed as false_claim, but lacks affirmative contradiction (Contradict mass: ${contradictMass} < 1.0, authoritative: ${hasTierAContradict || hasTierBContradict}). Converted to unproven.`
        };
      }
    }

    // 6. Default Epistemic Null State (Unproven)
    if (supportMass < 0.8 && contradictMass < 0.8) {
      return {
        invariantVerdict: "unproven",
        supportMass,
        contradictMass,
        highestTierSupport,
        highestTierContradict,
        isOverridden: proposedVerdict !== "unproven" && proposedVerdict !== "unsupported",
        reason: `Insufficient evidence: Support mass ${supportMass} and Contradict mass ${contradictMass} are below threshold (0.8). Assigned epistemic null.`
      };
    }

    // 7. Fallback to proposed verdict if already valid, otherwise unproven
    const safeVerdict = proposedVerdict || "unproven";
    return {
      invariantVerdict: safeVerdict,
      supportMass,
      contradictMass,
      highestTierSupport,
      highestTierContradict,
      isOverridden: false,
      reason: "Verdict consistent with dual-mass parameters."
    };
  }
}

export const sourceTrustService = new SourceTrustService();
