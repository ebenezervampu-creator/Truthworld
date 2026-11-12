import {
  EvidenceRetrievalService,
  WebSearchProvider,
} from "../../src/pipeline/services/evidenceRetrievalService";
import { UrlVerificationService, HttpProbeTransport, DnsLookupFn } from "../../src/pipeline/services/urlVerificationService";
import { CitationRetractionService } from "../../src/pipeline/services/citationRetractionService";
import { EvidenceCandidate } from "../../src/pipeline/types";

describe("Unit: EvidenceRetrievalService (Closed-World Multi-Provider Catalog)", () => {
  const publicDns: DnsLookupFn = async () => [{ address: "93.184.216.34", family: 4 }];

  const buildTransportFromRoutes = (
    routes: Record<string, { statusCode: number; html: string; location?: string }>
  ): HttpProbeTransport => {
    return async (url) => {
      const full = url.toString();
      const matched = Object.entries(routes).find(([k]) => full.includes(k));
      if (!matched) {
        return {
          statusCode: 404,
          headers: { "content-type": "text/html" },
          bodyText: "<html><head><title>404 Not Found</title></head><body>Not found</body></html>",
        };
      }
      const route = matched[1];
      return {
        statusCode: route.statusCode,
        headers: {
          "content-type": "text/html",
          ...(route.location ? { location: route.location } : {}),
        },
        bodyText: route.html,
      };
    };
  };

  it("handles Telugu Claim #18 (Doctor Advices / aging), filters 404 & Soft-404 URLs, and builds E1..En catalog", async () => {
    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: buildTransportFromRoutes({
        "mayoclinic.org/healthy-lifestyle/fake": {
          statusCode: 200,
          html: "<html><head><title>Page Not Found - Mayo Clinic</title></head><body><h1>Page Not Found</h1><p>The page you are trying to reach is not available on our site.</p></body></html>",
        },
        "medicalnewstoday.com/articles/fake": {
          statusCode: 200,
          html: "<html><head><title>Medical News Today</title></head><body><h1>Oops! Looks like we've hit a bit of a snag.</h1><p>Status: 404 Message: Not Found</p></body></html>",
        },
        "news.harvard.edu/gazette/fake": {
          statusCode: 404,
          html: "<html><head><title>404 | The Harvard Gazette</title></head><body><p>This page could not be found.</p></body></html>",
        },
        "pubmed.ncbi.nlm.nih.gov/38900123": {
          statusCode: 200,
          html: "<html><head><title>Lifestyle factors and biological aging biomarkers - PubMed</title></head><body><p>Diet, regular exercise, quality sleep, and stress management modulate biological aging clocks.</p></body></html>",
        },
        "en.wikipedia.org/wiki/Biological_age": {
          statusCode: 200,
          html: "<html><head><title>Biomarkers of aging - Wikipedia</title></head><body><p>Biological age reflects cellular senescence and physiological decline influenced by lifestyle choices.</p></body></html>",
        },
      }),
    });

    const mockGrounding: WebSearchProvider = {
      name: "google_grounding",
      search: async () => [
        {
          title: "Biological vs. chronological age - Mayo Clinic",
          url: "https://www.mayoclinic.org/healthy-lifestyle/fake",
          domain: "mayoclinic.org",
          snippet: "Broken link",
          tier: "A",
          retrievalProvider: "Google Grounding",
          retrievalMethod: "google_grounding",
        },
        {
          title: "Difference Between Chronological Age",
          url: "https://www.medicalnewstoday.com/articles/fake",
          domain: "medicalnewstoday.com",
          snippet: "Soft 404 link",
          tier: "C",
          retrievalProvider: "Google Grounding",
          retrievalMethod: "google_grounding",
        },
        {
          title: "Harvard Gazette Aging",
          url: "https://news.harvard.edu/gazette/fake",
          domain: "news.harvard.edu",
          snippet: "HTTP 404 link",
          tier: "A",
          retrievalProvider: "Google Grounding",
          retrievalMethod: "google_grounding",
        },
      ],
    };

    const mockPubMed: WebSearchProvider = {
      name: "pubmed",
      search: async () => [
        {
          title: "Lifestyle factors and biological aging biomarkers",
          url: "https://pubmed.ncbi.nlm.nih.gov/38900123/",
          domain: "pubmed.ncbi.nlm.nih.gov",
          publisher: "Nature Aging",
          snippet: "Randomized lifestyle interventions alter epigenetic biological aging.",
          pmid: "38900123",
          doi: "10.1038/s43587-024-00001-x",
          sourceType: "journal",
          tier: "A",
          retrievalProvider: "PubMed",
          retrievalMethod: "pubmed_eutils",
          verifiedAcademicMetadata: {
            title: "Lifestyle factors and biological aging biomarkers",
            journalName: "Nature Aging",
            yearPublished: 2024,
            pmid: "38900123",
            doi: "10.1038/s43587-024-00001-x",
            retrievalProvider: "PubMed",
          },
        },
      ],
    };

    const mockWiki: WebSearchProvider = {
      name: "wikipedia",
      search: async (_q, opts) =>
        opts?.language === "en"
          ? [
              {
                title: "Biomarkers of aging - Wikipedia",
                url: "https://en.wikipedia.org/wiki/Biological_age",
                domain: "en.wikipedia.org",
                publisher: "Wikipedia",
                snippet: "Biological age reflects cellular decline influenced by lifestyle choices.",
                sourceType: "encyclopedia",
                tier: "B",
                retrievalProvider: "Wikipedia",
                retrievalMethod: "wikipedia_api",
              },
            ]
          : [],
    };

    const noop: WebSearchProvider = { name: "noop", search: async () => [] };

    const retrieval = new EvidenceRetrievalService({
      urlVerifier: verifier,
      googleGrounding: mockGrounding,
      pubmed: mockPubMed,
      europePmc: noop,
      crossref: noop,
      openalex: noop,
      wikipedia: mockWiki,
      serper: noop,
      queryNormalizer: async () => ({
        englishQueries: ["biological aging lifestyle diet exercise", "chronological vs biological age"],
        nativeQuery: "వృద్ధాప్యం జీవనశైలి",
        isBiomedicalOrHealth: true,
        isScholarlyOrScientific: true,
        detectedLanguage: "te",
      }),
    });

    const catalog = await retrieval.buildEvidenceCatalogForClaim({
      claimText: "మనం ఎంత ఫాస్ట్ గా వృద్ధాప్యం వైపు వెళుతున్నాము అనేది కొంత మేరకు మనం మార్చుకోవచ్చు",
      domainContext: "Health",
      videoContextTitle: "Doctor Advices",
    });

    expect(catalog.orderedCandidates).toHaveLength(2);
    expect(catalog.candidatesById["E1"].url).toBe("https://pubmed.ncbi.nlm.nih.gov/38900123/");
    expect(catalog.candidatesById["E1"].verification?.status).toBe("VERIFIED");
    expect(catalog.candidatesById["E2"].url).toBe("https://en.wikipedia.org/wiki/Biological_age");

    // All three dead URLs must be audited as rejected and never enter orderedCandidates
    expect(catalog.rejectedCandidates).toHaveLength(3);
    expect(catalog.rejectedCandidates.map((r) => r.status)).toEqual(
      expect.arrayContaining(["SOFT_404", "NOT_FOUND"])
    );
  });

  it("retains independently verified academic metadata even when publisher landing URL returns BOT_BLOCKED (403)", async () => {
    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: buildTransportFromRoutes({
        "doi.org/10.1056/example": {
          statusCode: 403,
          html: "<html><head><title>Just a moment...</title></head><body>Cloudflare WAF</body></html>",
        },
      }),
    });

    const mockCrossref: WebSearchProvider = {
      name: "crossref",
      search: async () => [
        {
          title: "Dietary Patterns and Cellular Longevity",
          url: "https://doi.org/10.1056/example",
          domain: "doi.org",
          publisher: "NEJM",
          snippet: "Controlled cohort study on aging biomarkers.",
          doi: "10.1056/example",
          sourceType: "journal",
          tier: "A",
          retrievalProvider: "Crossref",
          retrievalMethod: "crossref_api",
          verifiedAcademicMetadata: {
            title: "Dietary Patterns and Cellular Longevity",
            journalName: "NEJM",
            yearPublished: 2023,
            doi: "10.1056/example",
            retrievalProvider: "Crossref",
          },
        } as EvidenceCandidate,
      ],
    };

    const noop: WebSearchProvider = { name: "noop", search: async () => [] };
    const retrieval = new EvidenceRetrievalService({
      urlVerifier: verifier,
      googleGrounding: noop,
      pubmed: noop,
      europePmc: noop,
      crossref: mockCrossref,
      openalex: noop,
      wikipedia: noop,
      serper: noop,
      queryNormalizer: async () => ({
        englishQueries: ["dietary patterns cellular longevity"],
        isBiomedicalOrHealth: true,
        isScholarlyOrScientific: true,
        detectedLanguage: "en",
      }),
    });

    const catalog = await retrieval.buildEvidenceCatalogForClaim({
      claimText: "Dietary patterns influence cellular longevity",
      domainContext: "Health",
    });

    // Clickable URL must NOT be admitted because HTTP returned 403 BOT_BLOCKED
    expect(catalog.orderedCandidates).toHaveLength(0);
    expect(catalog.rejectedCandidates).toHaveLength(1);
    expect(catalog.rejectedCandidates[0].status).toBe("BOT_BLOCKED");

    // Independent bibliographic metadata MUST still be retained non-clickably
    expect(catalog.verifiedAcademicMetadata).toHaveLength(1);
    expect(catalog.verifiedAcademicMetadata[0].doi).toBe("10.1056/example");
  });

  it("ensures CitationRetractionService integration is non-retracted checked", () => {
    expect(CitationRetractionService.lookupDoi("10.1016/s0140-6736(97)11096-0")?.status).toBe("retracted");
  });
});
