import axios from "axios";
import { PIPELINE_CONFIG } from "../config";
import {
  EvidenceCandidate,
  EvidenceCatalog,
  RejectedEvidenceCandidate,
  SourceCategory,
  SourceTier,
  VerifiedAcademicMetadata,
} from "../types";
import { getVertexAI, type VertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";
import { logger } from "../utils/logger";
import { CitationRetractionService } from "./citationRetractionService";
import { sourceTrustService } from "./sourceTrustService";
import {
  UrlVerificationService,
  canonicalizeUrl,
  urlVerificationService,
  validateSafeExternalUrl,
} from "./urlVerificationService";

export interface SearchProviderOptions {
  claimText: string;
  normalizedQueries: string[];
  domainContext?: string;
  language?: string;
  maxResults?: number;
  signal?: AbortSignal;
}

export interface WebSearchProvider {
  readonly name: string;
  search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]>;
}

const TRUTH_BOT_UA = "TruthWorldFactCheckEngine/2.0 (https://truthworld.co; mailto:contact@truthworld.co)";
const DEFAULT_PROVIDER_TIMEOUT_MS = 4500;

function extractDomainSafe(rawUrl: string): string {
  try {
    return new URL(rawUrl).hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return "";
  }
}

function classifyProviderTier(url: string, domainContext: string = "General"): SourceTier {
  try {
    return sourceTrustService.resolveSourceTrust(url, domainContext).tier;
  } catch {
    return "C";
  }
}

/**
 * 1. Gemini Google Search Grounding Discovery Provider (Primary General Web)
 * Decouples search discovery from JSON schema generation: extracts URLs ONLY from
 * `groundingMetadata.groundingChunks[].web`, never from generated prose.
 */
export class GoogleGroundingProvider implements WebSearchProvider {
  readonly name = "google_grounding";

  constructor(private readonly genAI?: VertexAI) {}

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (!PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_GOOGLE_GROUNDING) return [];
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    try {
      const ai = this.genAI ?? getVertexAI();
      const modelId = PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-flash";
      const activeModel = ai.getGenerativeModel({
        model: modelId,
        tools: [{ googleSearch: {} } as any],
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
        ],
      });

      // Natural prose discovery prompt (NO JSON schema forcing URLs) preserves full groundingChunks
      const prompt = `Use Google Search to locate authoritative, primary web documentation verifying or evaluating the factual topic: "${trimmed}". Briefly summarize key empirical findings from retrieved web pages.`;
      const resp = await activeModel.generateContent(prompt);
      const candidate = resp?.response?.candidates?.[0] || resp?.candidates?.[0];
      const groundingMetadata = candidate?.groundingMetadata;
      const chunks: any[] = groundingMetadata?.groundingChunks || [];
      const supports: any[] = groundingMetadata?.groundingSupports || [];

      const supportByChunkIdx = new Map<number, string>();
      for (const sup of supports) {
        const seg = typeof sup?.segment?.text === "string" ? sup.segment.text.trim() : "";
        const indices: number[] = Array.isArray(sup?.groundingChunkIndices)
          ? sup.groundingChunkIndices
          : [];
        for (const idx of indices) {
          if (seg && !supportByChunkIdx.has(idx)) {
            supportByChunkIdx.set(idx, seg);
          }
        }
      }

      const maxResults = options?.maxResults ?? 6;
      const out: EvidenceCandidate[] = [];
      chunks.slice(0, maxResults).forEach((chunk: any, idx: number) => {
        const uri = chunk?.web?.uri;
        if (!uri || typeof uri !== "string") return;
        const domain = extractDomainSafe(uri) || String(chunk?.web?.domain || "").toLowerCase();
        out.push({
          title: String(chunk?.web?.title || domain || "Web Source").trim(),
          url: uri,
          domain,
          snippet: supportByChunkIdx.get(idx) || "",
          sourceType: domain.endsWith(".gov") || domain.includes(".gov.") ? "government" : "website",
          tier: classifyProviderTier(uri, options?.domainContext),
          retrievalProvider: "Google Grounding",
          retrievalMethod: "google_grounding",
        });
      });

      return out;
    } catch (err) {
      logger.warn("[GoogleGroundingProvider] Search failed cleanly", { query: trimmed, err });
      return [];
    }
  }
}

/**
 * 2. PubMed E-utilities Provider (Primary Medical / Health Research)
 */
export class PubMedProvider implements WebSearchProvider {
  readonly name = "pubmed";

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (!PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_PUBMED) return [];
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const limit = Math.min(options?.maxResults ?? 3, 5);
    try {
      const searchRes = await axios.get("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi", {
        params: {
          db: "pubmed",
          retmode: "json",
          retmax: limit,
          sort: "relevance",
          term: trimmed,
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const idList: string[] = searchRes.data?.esearchresult?.idlist || [];
      if (idList.length === 0) return [];

      const summaryRes = await axios.get("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi", {
        params: {
          db: "pubmed",
          retmode: "json",
          id: idList.join(","),
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const resultObj = summaryRes.data?.result || {};
      const out: EvidenceCandidate[] = [];

      for (const pmid of idList) {
        const rec = resultObj[pmid];
        if (!rec || !rec.title) continue;

        const doiObj = Array.isArray(rec.articleids)
          ? rec.articleids.find((a: any) => a?.idtype === "doi")
          : undefined;
        const doi = typeof doiObj?.value === "string" ? doiObj.value.trim() : undefined;

        if (doi) {
          const retraction = CitationRetractionService.lookupDoi(doi);
          if (retraction && retraction.status === "retracted") continue;
        }

        const authors = Array.isArray(rec.authors)
          ? rec.authors.map((a: any) => a?.name).filter(Boolean).slice(0, 5)
          : undefined;
        const yearMatch = String(rec.pubdate || "").match(/\b(19|20)\d{2}\b/);
        const yearPublished = yearMatch ? Number(yearMatch[0]) : undefined;
        const url = `https://pubmed.ncbi.nlm.nih.gov/${pmid}/`;

        const academicMeta: VerifiedAcademicMetadata = {
          title: String(rec.title).replace(/\.$/, ""),
          authors,
          journalName: rec.fulljournalname || rec.source || undefined,
          yearPublished,
          volume: rec.volume || undefined,
          issue: rec.issue || undefined,
          pages: rec.pages || undefined,
          doi,
          pmid,
          retrievalProvider: "PubMed",
        };

        out.push({
          title: academicMeta.title,
          url,
          domain: "pubmed.ncbi.nlm.nih.gov",
          publisher: academicMeta.journalName || "NIH / PubMed",
          snippet: `${academicMeta.title} (${academicMeta.journalName || "PubMed"}, ${yearPublished || ""})`.trim(),
          publishedAt: rec.pubdate,
          doi,
          pmid,
          sourceType: "journal",
          tier: "A",
          retrievalProvider: "PubMed",
          retrievalMethod: "pubmed_eutils",
          verifiedAcademicMetadata: academicMeta,
        });
      }

      return out;
    } catch (err) {
      logger.warn("[PubMedProvider] Search failed cleanly", { query: trimmed, err });
      return [];
    }
  }
}

/**
 * 3. Europe PMC Provider (Primary Biomedical Literature with Abstracts)
 */
export class EuropePMCProvider implements WebSearchProvider {
  readonly name = "europe_pmc";

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (!PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_EUROPE_PMC) return [];
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const limit = Math.min(options?.maxResults ?? 3, 5);
    try {
      const res = await axios.get("https://www.ebi.ac.uk/europepmc/webservices/rest/search", {
        params: {
          query: trimmed,
          format: "json",
          pageSize: limit,
          resultType: "core",
          sort_cited: "y",
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const items: any[] = res.data?.resultList?.result || [];
      const out: EvidenceCandidate[] = [];

      for (const item of items) {
        if (!item?.title || !item?.id || item?.isRetracted === "Y") continue;

        const doi = typeof item.doi === "string" ? item.doi.trim() : undefined;
        if (doi) {
          const retraction = CitationRetractionService.lookupDoi(doi);
          if (retraction && retraction.status === "retracted") continue;
        }

        const pmid = typeof item.pmid === "string" ? item.pmid.trim() : undefined;
        const sourceCode = String(item.source || "MED").trim();
        const url = item.pmcid
          ? `https://europepmc.org/article/PMC/${String(item.pmcid).replace(/^PMC/i, "")}`
          : `https://europepmc.org/article/${encodeURIComponent(sourceCode)}/${encodeURIComponent(String(item.id))}`;

        const rawAbstract = typeof item.abstractText === "string"
          ? item.abstractText.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
          : "";
        const snippet = rawAbstract
          ? rawAbstract.slice(0, 320)
          : String(item.title);
        const yearPublished = item.pubYear ? Number(item.pubYear) : undefined;

        const academicMeta: VerifiedAcademicMetadata = {
          title: String(item.title).replace(/<[^>]+>/g, "").replace(/\.$/, ""),
          authors: typeof item.authorString === "string"
            ? item.authorString.split(",").map((s: string) => s.trim()).slice(0, 5)
            : undefined,
          journalName: item.journalTitle || undefined,
          yearPublished: Number.isFinite(yearPublished) ? yearPublished : undefined,
          doi,
          pmid,
          abstractExcerpt: snippet,
          retrievalProvider: "Europe PMC",
        };

        out.push({
          title: academicMeta.title,
          url,
          domain: "europepmc.org",
          publisher: academicMeta.journalName || "Europe PMC",
          snippet,
          publishedAt: item.firstPublicationDate,
          doi,
          pmid,
          sourceType: "journal",
          tier: "A",
          retrievalProvider: "Europe PMC",
          retrievalMethod: "europe_pmc_rest",
          verifiedAcademicMetadata: academicMeta,
        });
      }

      return out;
    } catch (err) {
      logger.warn("[EuropePMCProvider] Search failed cleanly", { query: trimmed, err });
      return [];
    }
  }
}

/**
 * 4. Crossref Provider (Primary DOI & Publication Registry + Retraction Filter)
 */
export class CrossrefProvider implements WebSearchProvider {
  readonly name = "crossref";

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (!PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_CROSSREF) return [];
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const limit = Math.min(options?.maxResults ?? 3, 5);
    try {
      const res = await axios.get("https://api.crossref.org/works", {
        params: {
          "query.bibliographic": trimmed,
          rows: limit,
          select: "DOI,title,author,container-title,published-print,published-online,URL",
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const items: any[] = res.data?.message?.items || [];
      const out: EvidenceCandidate[] = [];

      for (const work of items) {
        const doi = typeof work?.DOI === "string" ? work.DOI.trim() : "";
        const title = Array.isArray(work?.title) && work.title[0] ? String(work.title[0]).trim() : "";
        if (!doi || !title) continue;

        const retraction = CitationRetractionService.lookupDoi(doi);
        if (retraction && retraction.status === "retracted") continue;

        const journalName = Array.isArray(work?.["container-title"]) ? work["container-title"][0] : undefined;
        const yearArr =
          work?.["published-print"]?.["date-parts"]?.[0] ||
          work?.["published-online"]?.["date-parts"]?.[0];
        const yearPublished = Array.isArray(yearArr) && typeof yearArr[0] === "number" ? yearArr[0] : undefined;
        const authors = Array.isArray(work?.author)
          ? work.author
              .slice(0, 5)
              .map((a: any) => [a?.given, a?.family].filter(Boolean).join(" "))
              .filter(Boolean)
          : undefined;

        const targetUrl = `https://doi.org/${doi}`;
        const academicMeta: VerifiedAcademicMetadata = {
          title,
          authors,
          journalName,
          yearPublished,
          doi,
          retrievalProvider: "Crossref",
        };

        out.push({
          title,
          url: targetUrl,
          domain: "doi.org",
          publisher: journalName || "Crossref Registry",
          snippet: `${title} (${journalName || "Peer-Reviewed"}, ${yearPublished || ""})`.trim(),
          doi,
          sourceType: "journal",
          tier: "A",
          retrievalProvider: "Crossref",
          retrievalMethod: "crossref_api",
          verifiedAcademicMetadata: academicMeta,
        });
      }

      return out;
    } catch (err) {
      logger.warn("[CrossrefProvider] Search failed cleanly", { query: trimmed, err });
      return [];
    }
  }
}

/**
 * 5. OpenAlex Provider (Secondary Open Scholarly Knowledge Graph)
 */
export class OpenAlexProvider implements WebSearchProvider {
  readonly name = "openalex";

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (!PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_OPENALEX) return [];
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const limit = Math.min(options?.maxResults ?? 2, 4);
    try {
      const res = await axios.get("https://api.openalex.org/works", {
        params: {
          search: trimmed,
          "per-page": limit,
          filter: "is_retracted:false",
          mailto: "contact@truthworld.co",
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const items: any[] = res.data?.results || [];
      const out: EvidenceCandidate[] = [];

      for (const work of items) {
        const title = String(work?.display_name || work?.title || "").trim();
        const landing =
          work?.primary_location?.landing_page_url ||
          work?.doi ||
          work?.id;
        if (!title || !landing || typeof landing !== "string") continue;

        const doi = typeof work?.doi === "string" ? work.doi.replace(/^https?:\/\/doi\.org\//i, "") : undefined;
        if (doi) {
          const retraction = CitationRetractionService.lookupDoi(doi);
          if (retraction && retraction.status === "retracted") continue;
        }

        const journalName = work?.primary_location?.source?.display_name;
        const yearPublished = typeof work?.publication_year === "number" ? work.publication_year : undefined;
        const authors = Array.isArray(work?.authorships)
          ? work.authorships.slice(0, 5).map((a: any) => a?.author?.display_name).filter(Boolean)
          : undefined;

        const academicMeta: VerifiedAcademicMetadata = {
          title,
          authors,
          journalName,
          yearPublished,
          doi,
          retrievalProvider: "OpenAlex",
        };

        out.push({
          title,
          url: landing,
          domain: extractDomainSafe(landing) || "openalex.org",
          publisher: journalName || "OpenAlex",
          snippet: `${title} (${journalName || "Scholarly Work"}, ${yearPublished || ""})`.trim(),
          doi,
          sourceType: "journal",
          tier: "B",
          retrievalProvider: "OpenAlex",
          retrievalMethod: "openalex_api",
          verifiedAcademicMetadata: academicMeta,
        });
      }

      return out;
    } catch (err) {
      logger.warn("[OpenAlexProvider] Search failed cleanly", { query: trimmed, err });
      return [];
    }
  }
}

/**
 * 6. Wikipedia REST/Action Provider (Supplementary General Encyclopedia)
 */
export class WikipediaProvider implements WebSearchProvider {
  readonly name = "wikipedia";

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (!PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_WIKIPEDIA) return [];
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    const lang = /^[a-z]{2,3}$/i.test(options?.language || "") ? options!.language!.toLowerCase() : "en";
    const apiUrl = `https://${lang}.wikipedia.org/w/api.php`;
    const limit = Math.min(options?.maxResults ?? 2, 3);

    try {
      const searchRes = await axios.get(apiUrl, {
        params: {
          action: "query",
          list: "search",
          srsearch: trimmed.split(/\s+/).slice(0, 10).join(" "),
          utf8: "",
          format: "json",
          srlimit: limit,
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const hits: any[] = searchRes.data?.query?.search || [];
      if (hits.length === 0) return [];

      const titles = hits.map((h) => h.title).filter(Boolean).slice(0, limit);
      const infoRes = await axios.get(apiUrl, {
        params: {
          action: "query",
          prop: "extracts|info",
          inprop: "url",
          exsentences: 3,
          explaintext: 1,
          titles: titles.join("|"),
          formatversion: 2,
          format: "json",
        },
        headers: { "User-Agent": TRUTH_BOT_UA },
        timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
        signal: options?.signal,
      });

      const pages: any[] = infoRes.data?.query?.pages || [];
      const out: EvidenceCandidate[] = [];
      for (const page of pages) {
        if (!page?.title || !page?.fullurl || page?.missing) continue;
        const extract = typeof page.extract === "string" ? page.extract.replace(/\s+/g, " ").trim() : "";
        out.push({
          title: `${page.title} - Wikipedia`,
          url: String(page.fullurl),
          domain: `${lang}.wikipedia.org`,
          publisher: "Wikipedia",
          snippet: extract.slice(0, 320),
          sourceType: "encyclopedia",
          tier: "B",
          retrievalProvider: "Wikipedia",
          retrievalMethod: "wikipedia_api",
        });
      }
      return out;
    } catch (err) {
      logger.warn("[WikipediaProvider] Search failed cleanly", { query: trimmed, lang, err });
      return [];
    }
  }
}

/**
 * 7. Feature-Flagged Serper Web Search Provider (Optional Regional / Indian News Coverage)
 * Inactive until ENABLE_SERPER_SEARCH=true and SERPER_API_KEY secret is configured.
 */
export class SerperProvider implements WebSearchProvider {
  readonly name = "serper";

  async search(query: string, options?: SearchProviderOptions): Promise<EvidenceCandidate[]> {
    if (
      !PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_SERPER_SEARCH ||
      !PIPELINE_CONFIG.SEARCH_PROVIDERS.SERPER_API_KEY
    ) {
      return [];
    }
    const trimmed = query.trim();
    if (trimmed.length < 3) return [];

    try {
      const res = await axios.post(
        "https://google.serper.dev/search",
        {
          q: trimmed,
          gl: "in",
          num: Math.min(options?.maxResults ?? 5, 8),
        },
        {
          headers: {
            "X-API-KEY": PIPELINE_CONFIG.SEARCH_PROVIDERS.SERPER_API_KEY,
            "Content-Type": "application/json",
          },
          timeout: DEFAULT_PROVIDER_TIMEOUT_MS,
          signal: options?.signal,
        }
      );

      const organic: any[] = res.data?.organic || [];
      return organic
        .filter((item) => item?.link && item?.title)
        .map((item) => {
          const url = String(item.link);
          const domain = extractDomainSafe(url);
          return {
            title: String(item.title),
            url,
            domain,
            snippet: String(item.snippet || ""),
            sourceType: (domain.endsWith(".gov.in") || domain.endsWith(".gov") ? "government" : "newspaper") as SourceCategory,
            tier: classifyProviderTier(url, options?.domainContext),
            retrievalProvider: "Serper Web Search",
            retrievalMethod: "serper_api",
          };
        });
    } catch (err) {
      logger.warn("[SerperProvider] Search failed cleanly", { query: trimmed, err });
      return [];
    }
  }
}

export interface NormalizedClaimQueries {
  englishQueries: string[];
  nativeQuery?: string;
  isBiomedicalOrHealth: boolean;
  isScholarlyOrScientific: boolean;
  detectedLanguage: string;
}

export class EvidenceRetrievalService {
  private readonly urlVerifier: UrlVerificationService;
  private readonly providers: {
    googleGrounding: WebSearchProvider;
    pubmed: WebSearchProvider;
    europePmc: WebSearchProvider;
    crossref: WebSearchProvider;
    openalex: WebSearchProvider;
    wikipedia: WebSearchProvider;
    serper: WebSearchProvider;
  };
  private readonly queryNormalizer?: (claimText: string, domainContext: string) => Promise<NormalizedClaimQueries>;

  constructor(deps?: {
    urlVerifier?: UrlVerificationService;
    googleGrounding?: WebSearchProvider;
    pubmed?: WebSearchProvider;
    europePmc?: WebSearchProvider;
    crossref?: WebSearchProvider;
    openalex?: WebSearchProvider;
    wikipedia?: WebSearchProvider;
    serper?: WebSearchProvider;
    queryNormalizer?: (claimText: string, domainContext: string) => Promise<NormalizedClaimQueries>;
  }) {
    this.urlVerifier = deps?.urlVerifier ?? urlVerificationService;
    this.providers = {
      googleGrounding: deps?.googleGrounding ?? new GoogleGroundingProvider(),
      pubmed: deps?.pubmed ?? new PubMedProvider(),
      europePmc: deps?.europePmc ?? new EuropePMCProvider(),
      crossref: deps?.crossref ?? new CrossrefProvider(),
      openalex: deps?.openalex ?? new OpenAlexProvider(),
      wikipedia: deps?.wikipedia ?? new WikipediaProvider(),
      serper: deps?.serper ?? new SerperProvider(),
    };
    this.queryNormalizer = deps?.queryNormalizer;
  }

  /**
   * Produces English + native search queries from multilingual claims (e.g. Telugu/Hindi claims)
   * without ever allowing the query synthesizer to fabricate URLs.
   */
  async normalizeQueriesForClaim(
    claimText: string,
    domainContext: string = "General",
    videoContextTitle?: string
  ): Promise<NormalizedClaimQueries> {
    if (this.queryNormalizer) {
      return this.queryNormalizer(claimText, domainContext);
    }

    const hasNonAscii = /[^\x00-\x7F]/.test(claimText);
    const heuristicBio =
      /\b(health|doctor|aging|age|disease|medicine|vaccine|cancer|heart|diet|sleep|stress|medical|clinical|virus|treatment|therapy|nutrition|exercise)\b/i.test(
        `${claimText} ${domainContext} ${videoContextTitle || ""}`
      );
    const heuristicSci =
      heuristicBio ||
      /\b(science|study|research|physics|biology|chemistry|climate|space|nasa|species|earth|dna)\b/i.test(
        `${claimText} ${domainContext} ${videoContextTitle || ""}`
      );

    // For clean short English claims in tests or without Vertex init, avoid extra LLM roundtrip unless helpful
    if (!hasNonAscii && process.env.NODE_ENV === "test") {
      return {
        englishQueries: [claimText.trim().slice(0, 140)],
        isBiomedicalOrHealth: heuristicBio,
        isScholarlyOrScientific: heuristicSci,
        detectedLanguage: "en",
      };
    }

    try {
      const ai = getVertexAI();
      const modelId = PIPELINE_CONFIG.GEMINI_MODELS?.queryDecomposition || "gemini-2.5-flash";
      const model = ai.getGenerativeModel({
        model: modelId,
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.1,
        },
      });

      const prompt = `Convert the following factual claim into concise search queries (no URLs).
Video Context Title: "${videoContextTitle || "N/A"}"
Domain Context: "${domainContext}"
Claim: "${claimText}"

Return strict JSON:
{
  "englishQueries": ["concise English search query 1", "concise English search query 2"],
  "nativeQuery": "short query in original script if non-English, else empty string",
  "isBiomedicalOrHealth": true,
  "isScholarlyOrScientific": true,
  "detectedLanguage": "en|te|hi|ta|kn|ml|mr|bn|other"
}`;

      const res = await model.generateContent(prompt);
      const text = extractCandidateText(res?.response?.candidates?.[0]) || "";
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        const englishQueries: string[] = Array.isArray(parsed.englishQueries)
          ? parsed.englishQueries.map((s: any) => String(s || "").trim()).filter(Boolean).slice(0, 2)
          : [];
        if (englishQueries.length > 0) {
          return {
            englishQueries,
            nativeQuery: typeof parsed.nativeQuery === "string" && parsed.nativeQuery.trim()
              ? parsed.nativeQuery.trim()
              : (hasNonAscii ? claimText.trim().slice(0, 120) : undefined),
            isBiomedicalOrHealth: Boolean(parsed.isBiomedicalOrHealth) || heuristicBio,
            isScholarlyOrScientific: Boolean(parsed.isScholarlyOrScientific) || heuristicSci,
            detectedLanguage: String(parsed.detectedLanguage || (hasNonAscii ? "other" : "en")),
          };
        }
      }
    } catch (err) {
      logger.warn("[EvidenceRetrievalService] Query normalization fallback used", { err });
    }

    return {
      englishQueries: [hasNonAscii ? `${videoContextTitle || ""} ${claimText}`.trim().slice(0, 140) : claimText.trim().slice(0, 140)],
      nativeQuery: hasNonAscii ? claimText.trim().slice(0, 120) : undefined,
      isBiomedicalOrHealth: heuristicBio,
      isScholarlyOrScientific: heuristicSci,
      detectedLanguage: hasNonAscii ? "other" : "en",
    };
  }

  /**
   * Builds a strictly verified, closed-world EvidenceCatalog for a single claim.
   * Every candidate URL is verified via UrlVerificationService before receiving an ID (E1, E2...).
   */
  async buildEvidenceCatalogForClaim(params: {
    claimText: string;
    domainContext?: string;
    videoContextTitle?: string;
    additionalSafeUrls?: string[];
    maxVerifiedSources?: number;
    enableWebGrounding?: boolean;
    signal?: AbortSignal;
  }): Promise<EvidenceCatalog> {
    const domainContext = params.domainContext || "General";
    const maxVerified = params.maxVerifiedSources ?? 5;
    const enableWebGrounding = params.enableWebGrounding !== false;

    const norm = await this.normalizeQueriesForClaim(
      params.claimText,
      domainContext,
      params.videoContextTitle
    );

    const primaryQuery = norm.englishQueries[0] || params.claimText;
    const secondaryQuery = norm.englishQueries[1] || primaryQuery;
    const searchOpts: SearchProviderOptions = {
      claimText: params.claimText,
      normalizedQueries: norm.englishQueries,
      domainContext,
      language: norm.detectedLanguage === "other" ? "en" : norm.detectedLanguage,
      signal: params.signal,
    };

    const tasks: Array<Promise<EvidenceCandidate[]>> = [];

    if (enableWebGrounding) {
      tasks.push(this.providers.googleGrounding.search(primaryQuery, searchOpts));
      if (norm.nativeQuery) {
        tasks.push(this.providers.googleGrounding.search(norm.nativeQuery, searchOpts));
      }
      if (PIPELINE_CONFIG.SEARCH_PROVIDERS.ENABLE_SERPER_SEARCH) {
        tasks.push(this.providers.serper.search(norm.nativeQuery || primaryQuery, searchOpts));
      }
    }

    if (norm.isBiomedicalOrHealth) {
      tasks.push(this.providers.pubmed.search(primaryQuery, searchOpts));
      tasks.push(this.providers.europePmc.search(secondaryQuery, searchOpts));
    }
    if (norm.isScholarlyOrScientific) {
      tasks.push(this.providers.crossref.search(primaryQuery, searchOpts));
      tasks.push(this.providers.openalex.search(secondaryQuery, searchOpts));
    }

    tasks.push(
      this.providers.wikipedia.search(primaryQuery, {
        ...searchOpts,
        language: "en",
      })
    );
    if (norm.nativeQuery && /^[a-z]{2,3}$/i.test(norm.detectedLanguage) && norm.detectedLanguage !== "en") {
      tasks.push(
        this.providers.wikipedia.search(norm.nativeQuery, {
          ...searchOpts,
          language: norm.detectedLanguage,
        })
      );
    }

    const settled = await Promise.allSettled(tasks);
    const rawCandidates: EvidenceCandidate[] = [];
    for (const r of settled) {
      if (r.status === "fulfilled" && Array.isArray(r.value)) {
        rawCandidates.push(...r.value);
      }
    }

    // Include explicitly provided safe URLs (e.g. creator references), subject to identical verification gate
    if (params.additionalSafeUrls && params.additionalSafeUrls.length > 0) {
      for (const raw of params.additionalSafeUrls.slice(0, 4)) {
        const parsed = validateSafeExternalUrl(raw);
        if (!parsed) continue;
        rawCandidates.push({
          title: parsed.hostname.replace(/^www\./, ""),
          url: parsed.toString(),
          domain: parsed.hostname.toLowerCase().replace(/^www\./, ""),
          snippet: "",
          tier: classifyProviderTier(parsed.toString(), domainContext),
          retrievalProvider: "Creator Reference",
          retrievalMethod: "provided_reference",
        });
      }
    }

    // Preserve independently verified academic metadata separately (never treated as clickable link unless URL passes!)
    const verifiedAcademicMetadata: VerifiedAcademicMetadata[] = [];
    const seenAcademicKeys = new Set<string>();
    for (const cand of rawCandidates) {
      if (cand.verifiedAcademicMetadata) {
        const key = (cand.doi || cand.pmid || cand.verifiedAcademicMetadata.title).toLowerCase();
        if (!seenAcademicKeys.has(key)) {
          seenAcademicKeys.add(key);
          verifiedAcademicMetadata.push(cand.verifiedAcademicMetadata);
        }
      }
    }

    // Deduplicate candidate URLs prior to probing (cap probe fan-out to top 10 unique URLs)
    const dedupedCandidates: EvidenceCandidate[] = [];
    const seenRawUrls = new Set<string>();
    for (const cand of rawCandidates) {
      const parsed = validateSafeExternalUrl(cand.url);
      if (!parsed) continue;
      const key = canonicalizeUrl(parsed.toString()).toLowerCase();
      if (seenRawUrls.has(key)) continue;
      seenRawUrls.add(key);
      dedupedCandidates.push(cand);
      if (dedupedCandidates.length >= 10) break;
    }

    const verificationResults = await this.urlVerifier.verifyBatch(
      dedupedCandidates.map((c) => c.url),
      {
        relevanceQueries: norm.englishQueries,
        signal: undefined,
      } as any
    );

    const candidatesById: Record<string, EvidenceCandidate> = {};
    const orderedCandidates: EvidenceCandidate[] = [];
    const rejectedCandidates: RejectedEvidenceCandidate[] = [];
    const seenCanonicalFinal = new Set<string>();

    for (const cand of dedupedCandidates) {
      const verification = verificationResults.get(cand.url);
      if (!verification || verification.status !== "VERIFIED") {
        rejectedCandidates.push({
          url: cand.url,
          title: cand.title,
          status: verification?.status ?? "UNVERIFIED",
          reason: verification?.errorReason || "URL failed HTTP/Soft-404 verification gate",
          provider: cand.retrievalProvider,
          httpStatus: verification?.httpStatus,
        });
        continue;
      }

      // Apply UGC / blocked platform check after unwrapping final canonical URL!
      const pubCheck = sourceTrustService.resolvePublisher(verification.canonicalUrl);
      if (pubCheck.isRejectedUgc) {
        rejectedCandidates.push({
          url: verification.canonicalUrl,
          title: cand.title,
          status: "IRRELEVANT",
          reason: pubCheck.rejectionReason || "Rejected UGC platform",
          provider: cand.retrievalProvider,
          httpStatus: verification.httpStatus,
        });
        continue;
      }

      const finalKey = verification.canonicalUrl.toLowerCase();
      if (seenCanonicalFinal.has(finalKey)) continue;
      seenCanonicalFinal.add(finalKey);

      const evidenceId = `E${orderedCandidates.length + 1}`;
      const enriched: EvidenceCandidate = {
        ...cand,
        evidenceId,
        url: verification.canonicalUrl,
        canonicalUrl: verification.canonicalUrl,
        domain: verification.domain || cand.domain,
        publisher: pubCheck.publisher || cand.publisher,
        tier: pubCheck.tier || cand.tier || classifyProviderTier(verification.canonicalUrl, domainContext),
        title: verification.contentTitle && cand.retrievalProvider === "Google Grounding"
          ? verification.contentTitle
          : cand.title,
        snippet: cand.snippet || verification.excerpt || verification.contentTitle || cand.title,
        verification,
      };

      candidatesById[evidenceId] = enriched;
      orderedCandidates.push(enriched);
      if (orderedCandidates.length >= maxVerified) break;
    }

    return {
      claimText: params.claimText,
      normalizedQueries: norm.englishQueries,
      candidatesById,
      orderedCandidates,
      rejectedCandidates,
      verifiedAcademicMetadata: verifiedAcademicMetadata.slice(0, 5),
      retrievedAtUtc: new Date().toISOString(),
    };
  }
}

export const evidenceRetrievalService = new EvidenceRetrievalService();
