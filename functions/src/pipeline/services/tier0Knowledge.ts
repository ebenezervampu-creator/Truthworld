import axios from "axios";
import { logger } from "../utils/logger";
import type { ExtractedClaim } from "./factExtraction";
import type { AdjudicatedClaim, EvidenceProvider } from "../types";
import { claimCacheService } from "./claimCacheService";
import { sourceTrustService } from "./sourceTrustService";
import { normalizeClaimForDeterministicMatch } from "./deterministicRegistry";
import type { ClaimStatus, SourceRole } from "../types";

export interface Tier0Context {
  claimId: string;
  context: string | null;
}

export interface PreIndexedFactMatch {
  matched: boolean;
  title: string;
  status: 'verified_true' | 'false_claim';
  confidence: number;
  reasoning: string;
  source: string;
  url: string;
  domain: string;
  tier: 'A';
  similarity: number;
  claimStance: 'SUPPORTS' | 'CONTRADICTS';
  sourceKind: SourceRole;
}

interface PreIndexedCorpusEntry {
  title: string;
  /** Descriptive only: never used to match a claim. */
  keywords: string[];
  patterns: RegExp[];
  status: 'verified_true' | 'false_claim';
  reasoning: string;
  source: string;
  url: string;
  domain: string;
  sourceKind?: SourceRole;
}

export class Tier0KnowledgeService {
  private static readonly CANONICAL_CORPUS: PreIndexedCorpusEntry[] = [
    // ── Physical & Chemical Constants ──
    {
      title: "Speed of Light in Vacuum",
      keywords: ["speed", "light", "vacuum", "constant", "physics", "meters"],
      patterns: [/^(the )?speed of light( in (a )?vacuum)? is (about |approximately |exactly )?(299792458 (m|meters|metres) per (s|second)|299792 (km|kilometers|kilometres) per (s|second)|300000 (km|kilometers|kilometres) per (s|second))$/],
      status: "verified_true",
      reasoning: "Light travels at about 299,792,458 meters every second in empty space. Scientists around the world use this exact speed as a standard measure.",
      source: "National Institute of Standards and Technology (NIST)",
      url: "https://physics.nist.gov/cuu/Constants/",
      domain: "nist.gov",
    },
    {
      title: "Freezing & Boiling Points of Pure Water at Sea Level",
      keywords: ["freezing", "boiling", "water", "temperature", "celsius", "fahrenheit"],
      patterns: [/^(pure )?water freezes at (0|zero) degrees( celsius| c)?( at sea level)?$/, /^(pure )?water boils at 100 degrees( celsius| c)?( at sea level)?$/, /^(the )?freezing point of (pure )?water is (0|zero) degrees( celsius| c)?$/, /^(the )?boiling point of (pure )?water( at sea level)? is 100 degrees( celsius| c)?$/, /^(pure )?water freezes at (0|zero) degrees( celsius| c)? and boils at 100 degrees( celsius| c)?( at sea level)?$/],
      status: "verified_true",
      reasoning: "At normal sea-level air pressure, clean water turns into ice at 0°C (32°F) and boils at 100°C (212°F).",
      source: "Encyclopaedia Britannica (Physical Chemistry)",
      url: "https://www.britannica.com/science/water",
      domain: "britannica.com",
    },
    {
      title: "Atmospheric Composition of Earth",
      keywords: ["earth", "atmosphere", "nitrogen", "oxygen", "percentage", "gases"],
      patterns: [/^(the )?earths? atmosphere is (approximately |about )?78 % nitrogen$/, /^(the )?earths? atmosphere is mostly nitrogen$/],
      status: "verified_true",
      reasoning: "The air around Earth is made mostly of nitrogen gas (about 78%) and oxygen gas (about 21%), with small amounts of argon and carbon dioxide.",
      source: "NASA Earth Science Division",
      url: "https://earthdata.nasa.gov/",
      domain: "nasa.gov",
    },
    {
      title: "DNA Double Helix Structure",
      keywords: ["dna", "structure", "double", "helix", "watson", "crick", "franklin", "nucleotide"],
      patterns: [/^dna (is|has) a double helix( structure)?$/],
      status: "verified_true",
      reasoning: "DNA is shaped like a twisted ladder (called a double helix) made of two strands, first mapped by scientists in 1953.",
      source: "National Institutes of Health (NIH) / NHGRI",
      url: "https://www.genome.gov/about-genomics/fact-sheets/Deoxyribonucleic-Acid-Fact-Sheet",
      domain: "nih.gov",
    },

    // ── Universal Health & Medical Baselines ──
    {
      title: "Vaccination and Immune System Priming",
      keywords: ["vaccine", "vaccines", "immunity", "antibodies", "pathogen", "immune"],
      patterns: [/^vaccines work by (stimulating|training) the immune system( to produce antibodies)?$/, /^vaccines (help the body )?produce antibodies$/],
      status: "verified_true",
      reasoning: "Vaccines safely train your body's defense system to recognize a germ and build antibodies, helping protect you without giving you the full illness.",
      source: "World Health Organization (WHO) Vaccines Guidance",
      url: "https://www.who.int/news-room/questions-and-answers/item/vaccines-and-immunization-what-is-vaccination",
      domain: "who.int",
    },
    {
      title: "Smoking and Cardiovascular / Respiratory Disease Link",
      keywords: ["smoking", "tobacco", "cigarettes", "cancer", "cardiovascular", "heart", "disease"],
      patterns: [/^((clinical )?(research|studies|evidence) (proves?|shows?|confirms?) (that )?)?(smoking causes lung cancer|tobacco causes heart disease|smoking increases cardiovascular risk)$/],
      status: "verified_true",
      reasoning: "Years of large health studies prove that smoking tobacco directly causes lung cancer, serious breathing diseases, and heart problems.",
      source: "Centers for Disease Control and Prevention (CDC)",
      url: "https://www.cdc.gov/tobacco/basic_information/health_effects/",
      domain: "cdc.gov",
    },
    {
      title: "Antibiotics Ineffective Against Viral Infections",
      keywords: ["antibiotics", "viruses", "bacteria", "penicillin"],
      patterns: [/^antibiotics (do not|dont|cannot|cant) kill viruses$/, /^antibiotics only kill bacteria$/, /^antibiotics are ineffective against viruses$/],
      status: "verified_true",
      reasoning: "Antibiotic medicines only fight bacteria. They cannot kill viruses like the common cold, the flu, or COVID-19.",
      source: "World Health Organization (WHO) Antimicrobial Resistance",
      url: "https://www.who.int/news-room/fact-sheets/detail/antibiotic-resistance",
      domain: "who.int",
    },
    {
      title: "Antibiotics Treat Viral Infections (Refuted)",
      keywords: ["antibiotics", "viral", "cure", "cold", "flu"],
      patterns: [/^antibiotics (cure|treat|kill) (viral infections|viruses|the common cold|the flu)$/, /^antibiotics are effective against (viral infections|viruses)( and (the )?common cold)?$/],
      status: "false_claim",
      reasoning: "Antibiotics only kill bacteria, not viruses. They do not cure colds, the flu, or other viral sicknesses.",
      source: "Centers for Disease Control and Prevention (CDC)",
      url: "https://www.cdc.gov/antibiotic-use/index.html",
      domain: "cdc.gov",
    },
    {
      title: "Turmeric Water Cures Cancer (Refuted)",
      keywords: ["turmeric", "curcumin", "cancer", "cure", "water", "drinking"],
      patterns: [/^(drinking )?turmeric( water)? (cures|treats|prevents) cancer$/, /^curcumin (cures|treats) cancer$/],
      status: "false_claim",
      reasoning: "Doctors and cancer researchers agree this is not true. While lab tests have studied turmeric for swelling, there is no real proof in people that drinking turmeric water cures cancer. Major health groups like WHO and Cancer Research UK warn people never to skip real medical care for unproven home drinks.",
      source: "National Cancer Institute (NCI) / Cancer Research UK",
      url: "https://www.cancerresearchuk.org/about-cancer/treatment/complementary-alternative-therapies/individual-therapies/turmeric",
      domain: "cancerresearchuk.org",
    },

    // ── Geopolitical & Treaty Baselines ──
    {
      title: "Foundation of the United Nations (1945)",
      keywords: ["united nations", "un", "charter", "founded", "1945", "san francisco"],
      patterns: [/^(the )?united nations was founded in 1945$/, /^(the )?un charter was signed in 1945$/],
      status: "verified_true",
      reasoning: "The United Nations officially started on October 24, 1945, after founding countries signed and approved its agreement.",
      source: "United Nations Historical Registry",
      url: "https://www.un.org/en/about-us/history-of-the-un",
      domain: "un.org",
    },
    {
      title: "Universal Declaration of Human Rights (1948)",
      keywords: ["universal declaration", "human rights", "udhr", "1948", "paris", "eleanor roosevelt"],
      patterns: [/^(the )?universal declaration of human rights was adopted in 1948$/, /^(the )?udhr was proclaimed in 1948$/],
      status: "verified_true",
      reasoning: "World leaders at the United Nations approved the Universal Declaration of Human Rights in Paris on December 10, 1948.",
      source: "United Nations Treaty Series (UDHR)",
      url: "https://www.un.org/en/about-us/universal-declaration-of-human-rights",
      domain: "un.org",
    },

    // ── Universal Historical Consensus Baselines ──
    {
      title: "Apollo 11 Crewed Moon Landing (1969)",
      keywords: ["apollo 11", "moon", "landing", "1969", "neil armstrong", "buzz aldrin", "lunar"],
      patterns: [/^apollo 11 landed on the moon in 1969$/, /^humans first walked on the moon in 1969$/, /^neil armstrong walked on the moon( in 1969)?$/],
      status: "verified_true",
      reasoning: "NASA astronauts Neil Armstrong and Buzz Aldrin landed on the Moon during the Apollo 11 space mission on July 20, 1969.",
      source: "NASA Apollo Missions History",
      url: "https://www.nasa.gov/mission/apollo-11/",
      domain: "nasa.gov",
    },
    {
      title: "Earth is an Oblate Spheroid",
      keywords: ["earth", "flat", "sphere", "oblate", "spheroid", "planet", "orbit"],
      patterns: [/^(the )?earth is flat$/, /^(the )?earth is a flat disc$/],
      status: "false_claim",
      reasoning: "Space photos, satellite measurements, and round-the-world trips prove Earth is not flat — it is shaped like a big round ball.",
      source: "National Oceanic and Atmospheric Administration (NOAA)",
      url: "https://oceanservice.noaa.gov/facts/earth-round.html",
      domain: "noaa.gov",
    }
  ];

  /**
   * High-speed, in-memory Tier-0 lookup for a few settled facts (< 1ms).
   *
   * Every pattern is anchored to the WHOLE normalized claim: a claim that only shares
   * keywords with an entry ("Apollo 11 was faked", "smoking prevents cancer") never matches.
   * There is deliberately no keyword-overlap fallback — overlapping words say nothing about
   * whether the claim asserts the fact or its opposite.
   */
  lookupPreIndexedFact(claimText: string): PreIndexedFactMatch | null {
    if (!claimText || claimText.trim().length < 5) return null;
    const clean = normalizeClaimForDeterministicMatch(claimText);

    for (const entry of Tier0KnowledgeService.CANONICAL_CORPUS) {
      for (const pattern of entry.patterns) {
        if (pattern.test(clean)) {
          return {
            matched: true,
            title: entry.title,
            status: entry.status,
            confidence: 0.99,
            reasoning: entry.reasoning,
            source: entry.source,
            url: entry.url,
            domain: entry.domain,
            tier: "A",
            similarity: 1.0,
            claimStance: entry.status === "false_claim" ? "CONTRADICTS" : "SUPPORTS",
            sourceKind: entry.sourceKind ?? "REFERENCE",
          };
        }
      }
    }

    return null;
  }
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
      const wikiHeaders = {
        'User-Agent': 'TruthWorldFactCheckEngine/1.0 (https://truthworld.co; contact@truthworld.co)',
        'Accept': 'application/json',
      };

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
        headers: wikiHeaders,
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
        headers: wikiHeaders,
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

  /**
   * Partitions claims into Tier-0 instant cache hits vs claims requiring verification.
   */
  async partitionClaims(claims: ExtractedClaim[]): Promise<{
    cachedAdjudications: AdjudicatedClaim[];
    uncachedClaims: ExtractedClaim[];
  }> {
    const cachedAdjudications: AdjudicatedClaim[] = [];
    const uncachedClaims: ExtractedClaim[] = [];

    for (const claim of claims) {
      const queryText = claim.normalizedClaim || claim.verbatimQuote || "";
      const corpusMatch = this.lookupPreIndexedFact(queryText);
      if (corpusMatch) {
        cachedAdjudications.push({
          claimId: claim.claimId,
          verdict: corpusMatch.status === "verified_true" ? "VERIFIED" : "FALSE",
          confidence: corpusMatch.confidence,
          rationale: corpusMatch.reasoning,
          citedEvidenceIds: ["E1"],
          v2VerifiedUrls: [
            {
              evidenceId: "E1",
              title: corpusMatch.source || corpusMatch.title,
              uri: corpusMatch.url,
              snippet: corpusMatch.reasoning,
              sourceProvider: "WIKIPEDIA",
            },
          ],
          hasConflictingEvidence: false,
          escalatedToTier3: false,
          thinkingLevelUsed: "LOW",
          usedPreRetrievedEvidence: true,
        });
        continue;
      }

      const cached = await claimCacheService.get(queryText).catch(() => null);
      if (cached && cached.status) {
        const statusToVerdict: Record<string, "VERIFIED" | "FALSE" | "MISLEADING" | "DISPUTED" | "UNVERIFIABLE"> = {
          verified_true: "VERIFIED",
          mostly_true: "VERIFIED",
          false_claim: "FALSE",
          mostly_false: "MISLEADING",
          misleading: "MISLEADING",
          disputed: "DISPUTED",
          unproven: "UNVERIFIABLE",
          unverifiable: "UNVERIFIABLE",
        };
        const verdict = statusToVerdict[cached.status] || "VERIFIED";

        cachedAdjudications.push({
          claimId: claim.claimId,
          verdict,
          confidence: cached.verificationConfidence || 0.95,
          rationale: cached.reasoning || "Verified via institutional credibility archive.",
          citedEvidenceIds: ["E1"],
          v2VerifiedUrls: (cached.richSources || []).map((s, idx) => ({
            evidenceId: `E${idx + 1}`,
            title: s.title || "Cached Verified Source",
            uri: s.url || "",
            snippet: s.snippet,
            sourceProvider: "WIKIPEDIA" as EvidenceProvider,
          })),
          hasConflictingEvidence: false,
          escalatedToTier3: false,
          thinkingLevelUsed: "LOW",
          usedPreRetrievedEvidence: true,
        });
        continue;
      }

      uncachedClaims.push(claim);
    }

    return { cachedAdjudications, uncachedClaims };
  }

  /**
   * Persists newly verified claims back to Tier-0 cache for 30-day cross-video deduplication.
   */
  async upsertVerifiedClaims(
    uncachedClaims: ExtractedClaim[],
    freshAdjudications: AdjudicatedClaim[]
  ): Promise<void> {
    const claimById = new Map(uncachedClaims.map((c) => [c.claimId, c]));
    for (const adj of freshAdjudications) {
      const original = claimById.get(adj.claimId);
      if (!original) continue;
      const text = original.normalizedClaim || original.verbatimQuote || "";
      if (!text) continue;

      // 🛡️ Edge-Case Safeguard: Skip caching UNVERIFIABLE verdicts so breaking/novel
      // claims are not pinned as unproven across future videos before indexing.
      if (adj.verdict === "UNVERIFIABLE" || adj.verdict === "OPINION_BELIEF") {
        continue;
      }

      const verdictToStatus: Record<string, ClaimStatus> = {
        VERIFIED: "verified_true" as ClaimStatus,
        FALSE: "false_claim" as ClaimStatus,
        MISLEADING: "misleading" as ClaimStatus,
        DISPUTED: "disputed" as ClaimStatus,
        UNVERIFIABLE: "unproven" as ClaimStatus,
      };

      await claimCacheService.set({
        claimId: adj.claimId,
        text,
        // Fail closed: an unknown verdict is never cached as "verified_true".
        status: verdictToStatus[adj.verdict] || ("unproven" as ClaimStatus),
        verificationConfidence: adj.confidence,
        reasoning: adj.rationale,
        richSources: adj.v2VerifiedUrls.map((s) => {
          const trust = sourceTrustService.resolveSourceTrust(s.uri);
          return {
            title: s.title,
            url: s.uri,
            directUrl: s.uri,
            domain: trust.domain,
            tier: trust.tier,
            snippet: s.snippet || "",
            retrievalMethod: s.sourceProvider === "VERTEX_GROUNDING" ? "google_grounding" : "academic_direct",
            // Epistemic Guard: Never fabricate synthetic urlVerification records. Real verification
            // status is resolved authoritatively by UrlVerificationService.
          };
        }),
        sources: adj.v2VerifiedUrls.map((s) => s.uri),
        sourceStatus: adj.v2VerifiedUrls.length > 0 ? "verified" : "missing",
        isGrounded: true,
        verificationMethod: "grounded",
        claimType: "factual",
      } as any).catch((err) => {
        logger.warn("[Tier0] Failed to cache verified claim", { text, err });
      });
    }
  }
}

export const tier0KnowledgeService = new Tier0KnowledgeService();
