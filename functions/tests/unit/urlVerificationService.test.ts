import {
  UrlVerificationService,
  canonicalizeUrl,
  detectSoft404,
  extractHtmlSignals,
  isGenericHomepageUrl,
  isPrivateOrReservedIp,
  validateSafeExternalUrl,
  HttpProbeTransport,
  DnsLookupFn,
} from "../../src/pipeline/services/urlVerificationService";

describe("Unit: UrlVerificationService (SSRF, DNS Rebinding, Soft-404, Status Taxonomy)", () => {
  const publicDns: DnsLookupFn = async () => [{ address: "93.184.216.34", family: 4 }];

  describe("SSRF & IPv4/IPv6 CIDR Blocking", () => {
    it("blocks private, loopback, link-local, CGNAT, and metadata IPv4/IPv6 ranges", () => {
      expect(isPrivateOrReservedIp("127.0.0.1")).toBe(true);
      expect(isPrivateOrReservedIp("10.0.12.4")).toBe(true);
      expect(isPrivateOrReservedIp("172.16.0.1")).toBe(true);
      expect(isPrivateOrReservedIp("172.31.255.255")).toBe(true);
      expect(isPrivateOrReservedIp("192.168.1.10")).toBe(true);
      expect(isPrivateOrReservedIp("169.254.169.254")).toBe(true);
      expect(isPrivateOrReservedIp("100.64.0.1")).toBe(true);
      expect(isPrivateOrReservedIp("::1")).toBe(true);
      expect(isPrivateOrReservedIp("fe80::1")).toBe(true);
      expect(isPrivateOrReservedIp("fc00::1")).toBe(true);
      expect(isPrivateOrReservedIp("::ffff:127.0.0.1")).toBe(true);
      expect(isPrivateOrReservedIp("::ffff:a9fe:a9fe")).toBe(true); // 169.254.169.254 mapped IPv6
      expect(isPrivateOrReservedIp("64:ff9b::10.0.0.1")).toBe(true); // NAT64 private IPv4
      expect(isPrivateOrReservedIp("not-an-ip")).toBe(true);

      // Valid public IPs must pass
      expect(isPrivateOrReservedIp("93.184.216.34")).toBe(false);
      expect(isPrivateOrReservedIp("8.8.8.8")).toBe(false);
      expect(isPrivateOrReservedIp("2606:4700:4700::1111")).toBe(false);
    });

    it("rejects non-http schemes, embedded credentials, non-standard ports, and internal hostnames", () => {
      expect(validateSafeExternalUrl("javascript:alert(1)")).toBeNull();
      expect(validateSafeExternalUrl("file:///etc/passwd")).toBeNull();
      expect(validateSafeExternalUrl("https://user:pass@mayoclinic.org/article")).toBeNull();
      expect(validateSafeExternalUrl("https://mayoclinic.org:8443/article")).toBeNull();
      expect(validateSafeExternalUrl("http://metadata.google.internal/computeMetadata/v1/")).toBeNull();
      expect(validateSafeExternalUrl("http://localhost/admin")).toBeNull();
      expect(validateSafeExternalUrl("http://169.254.169.254/latest/meta-data/")).toBeNull();
      expect(validateSafeExternalUrl("http://redis/keys")).toBeNull();
      expect(validateSafeExternalUrl("https://www.mayoclinic.org/healthy-lifestyle/aging")).not.toBeNull();
    });

    it("prevents DNS rebinding by rejecting split-answer DNS containing any private IP", async () => {
      let lookupCalls = 0;
      const rebindingDns: DnsLookupFn = async () => {
        lookupCalls += 1;
        return [
          { address: "93.184.216.34", family: 4 },
          { address: "169.254.169.254", family: 4 },
        ];
      };
      const mockTransport: HttpProbeTransport = jest.fn();

      const svc = new UrlVerificationService({
        dnsLookup: rebindingDns,
        transport: mockTransport,
        useFirestoreCache: false,
      });

      const res = await svc.verifyUrl("https://rebind.attacker.example/article/test");
      expect(res.status).toBe("FETCH_FAILED");
      expect(res.errorReason).toContain("SSRF");
      expect(lookupCalls).toBe(1);
      expect(mockTransport).not.toHaveBeenCalled();
    });

    it("pins the single resolved public IP to the transport without performing a second DNS resolution", async () => {
      let dnsCalls = 0;
      let observedPinnedIp = "";
      const countingDns: DnsLookupFn = async () => {
        dnsCalls += 1;
        // Even if a compromised resolver would flip on call #2, only call #1 is used per hop
        return dnsCalls === 1
          ? [{ address: "142.250.190.46", family: 4 }]
          : [{ address: "127.0.0.1", family: 4 }];
      };

      const transport: HttpProbeTransport = async (_url, opts) => {
        observedPinnedIp = opts.pinnedIp;
        return {
          statusCode: 200,
          headers: { "content-type": "text/html" },
          bodyText: "<html><head><title>Healthy Aging Guide</title></head><body><p>Exercise and diet slow biological aging.</p></body></html>",
          remoteAddress: opts.pinnedIp,
        };
      };

      const svc = new UrlVerificationService({
        dnsLookup: countingDns,
        transport,
        useFirestoreCache: false,
      });

      const res = await svc.verifyUrl("https://www.nih.gov/news-events/healthy-aging-study");
      expect(res.status).toBe("VERIFIED");
      expect(dnsCalls).toBe(1);
      expect(observedPinnedIp).toBe("142.250.190.46");
    });

    it("blocks redirect chains attempting SSRF to internal metadata IP", async () => {
      const transport: HttpProbeTransport = async () => ({
        statusCode: 302,
        headers: { location: "http://169.254.169.254/computeMetadata/v1/" },
        bodyText: "",
      });

      const svc = new UrlVerificationService({
        dnsLookup: publicDns,
        transport,
        useFirestoreCache: false,
      });

      const res = await svc.verifyUrl(
        "https://vertexaisearch.cloud.google.com/grounding-api-redirect/ABC123"
      );
      expect(res.status).toBe("FETCH_FAILED");
      expect(res.errorReason).toContain("SSRF");
    });
  });

  describe("Soft-404 & Explicit HTTP Status Taxonomy", () => {
    it("detects Mayo Clinic, Medical News Today, and Harvard Gazette HTTP 200 Soft-404 fixtures", async () => {
      const fixtures: Array<{ url: string; html: string }> = [
        {
          url: "https://www.mayoclinic.org/healthy-lifestyle/healthy-aging/in-depth/fake-slug",
          html: "<html><head><title>Page Not Found - Mayo Clinic</title></head><body><h1>Page Not Found</h1><p>The page you are trying to reach is not available on our site.</p></body></html>",
        },
        {
          url: "https://www.medicalnewstoday.com/articles/biological-vs-chronological-fake",
          html: "<html><head><title>Medical News Today</title></head><body><h1>Oops! Looks like we've hit a bit of a snag.</h1><p>We seem to have misplaced this page. Status: 404 Message: Not Found</p></body></html>",
        },
        {
          url: "https://news.harvard.edu/gazette/story/2025/01/nonexistent-story/",
          html: "<html><head><title>404 | The Harvard Gazette</title></head><body><div>404</div><p>This page could not be found.</p></body></html>",
        },
      ];

      for (const fx of fixtures) {
        const svc = new UrlVerificationService({
          dnsLookup: publicDns,
          transport: async () => ({
            statusCode: 200,
            headers: { "content-type": "text/html" },
            bodyText: fx.html,
          }),
          useFirestoreCache: false,
        });
        const res = await svc.verifyUrl(fx.url, { bypassCache: true });
        expect(res.status).toBe("SOFT_404");
        expect(res.isSoft404).toBe(true);
        expect(res.fetchStatus).toBe("SOFT_404");
      }
    });

    it("does not false-positive on long substantive articles discussing HTTP 404 troubleshooting", () => {
      const longBody = "How to debug HTTP 404 status codes in web servers. ".repeat(120);
      const html = `<html><head><title>Understanding Web Server Status Codes</title></head><body><h1>Debugging HTTP Status Codes</h1><p>${longBody}</p></body></html>`;
      const signals = extractHtmlSignals(html);
      const soft = detectSoft404(
        "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404",
        "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404",
        signals,
        false
      );
      expect(soft.isSoft404).toBe(false);
    });

    it("distinguishes NOT_FOUND (404/410), BOT_BLOCKED (403/429), and FETCH_FAILED (503)", async () => {
      const makeSvc = (statusCode: number) =>
        new UrlVerificationService({
          dnsLookup: publicDns,
          transport: async () => ({
            statusCode,
            headers: { "content-type": "text/html" },
            bodyText: "<html><body>Notice</body></html>",
          }),
          useFirestoreCache: false,
        });

      expect((await makeSvc(404).verifyUrl("https://who.int/article-a", { bypassCache: true })).status).toBe("NOT_FOUND");
      expect((await makeSvc(410).verifyUrl("https://who.int/article-b", { bypassCache: true })).status).toBe("NOT_FOUND");
      expect((await makeSvc(403).verifyUrl("https://reuters.com/article-c", { bypassCache: true })).status).toBe("BOT_BLOCKED");
      expect((await makeSvc(429).verifyUrl("https://reuters.com/article-d", { bypassCache: true })).status).toBe("BOT_BLOCKED");
      expect((await makeSvc(503).verifyUrl("https://cdc.gov/article-e", { bypassCache: true })).status).toBe("FETCH_FAILED");
    });

    it("unwraps Vertex AI grounding redirect URLs to permanent canonical article URLs", async () => {
      const transport: HttpProbeTransport = async (url) => {
        if (url.hostname === "vertexaisearch.cloud.google.com") {
          return {
            statusCode: 302,
            headers: {
              location:
                "https://www.nia.nih.gov/health/healthy-aging/what-do-we-know-about-healthy-aging?utm_source=google",
            },
            bodyText: "",
          };
        }
        return {
          statusCode: 200,
          headers: { "content-type": "text/html" },
          bodyText:
            "<html><head><title>What Do We Know About Healthy Aging? | NIA</title></head><body><p>Research on biological aging and healthy lifestyle habits such as diet, sleep, and exercise.</p></body></html>",
        };
      };

      const svc = new UrlVerificationService({
        dnsLookup: publicDns,
        transport,
        useFirestoreCache: false,
      });

      const res = await svc.verifyUrl(
        "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQ_TOKEN",
        {
          bypassCache: true,
          relevanceQueries: ["biological aging lifestyle exercise diet"],
        }
      );

      expect(res.status).toBe("VERIFIED");
      expect(res.canonicalUrl).toBe("https://www.nia.nih.gov/health/healthy-aging/what-do-we-know-about-healthy-aging");
      expect(res.canonicalUrl).not.toContain("vertexaisearch.cloud.google.com");
      expect(res.canonicalUrl).not.toContain("utm_source");
      expect(res.redirectHops).toBe(1);
      expect(res.verifierMethod).toBe("grounding_resolved");
    });

    it("marks dead deep links silently redirected to generic root homepages as SOFT_404", async () => {
      const transport: HttpProbeTransport = async (url) => {
        if (url.pathname.includes("old-deleted-article")) {
          return {
            statusCode: 301,
            headers: { location: "https://www.mayoclinic.org/" },
            bodyText: "",
          };
        }
        return {
          statusCode: 200,
          headers: { "content-type": "text/html" },
          bodyText: "<html><head><title>Mayo Clinic Home</title></head><body>Welcome</body></html>",
        };
      };

      const svc = new UrlVerificationService({
        dnsLookup: publicDns,
        transport,
        useFirestoreCache: false,
      });

      const res = await svc.verifyUrl(
        "https://www.mayoclinic.org/healthy-lifestyle/old-deleted-article",
        { bypassCache: true }
      );
      expect(res.status).toBe("SOFT_404");
      expect(res.isGenericHomepage).toBe(true);
    });

    it("detects IRRELEVANT live pages when content has zero overlap with claim queries", async () => {
      const svc = new UrlVerificationService({
        dnsLookup: publicDns,
        transport: async () => ({
          statusCode: 200,
          headers: { "content-type": "text/html" },
          bodyText:
            "<html><head><title>Privacy Policy and Cookie Preferences</title></head><body><p>Manage analytics tracking consent settings on our website.</p></body></html>",
        }),
        useFirestoreCache: false,
      });

      const res = await svc.verifyUrl("https://www.nih.gov/web-policies-notices", {
        bypassCache: true,
        relevanceQueries: ["biological aging lifestyle diet exercise longevity"],
      });

      expect(res.status).toBe("IRRELEVANT");
    });
  });

  describe("URL Canonicalization & Homepage Helpers", () => {
    it("strips marketing tracking parameters while retaining meaningful IDs", () => {
      expect(
        canonicalizeUrl("https://PubMed.ncbi.nlm.nih.gov/12345/?utm_source=x&fbclid=abc&tab=abstract")
      ).toBe("https://pubmed.ncbi.nlm.nih.gov/12345/?tab=abstract");
    });

    it("identifies generic root homepages accurately", () => {
      expect(isGenericHomepageUrl("https://www.mayoclinic.org")).toBe(true);
      expect(isGenericHomepageUrl("https://www.mayoclinic.org/")).toBe(true);
      expect(isGenericHomepageUrl("https://news.harvard.edu/en-us/")).toBe(true);
      expect(isGenericHomepageUrl("https://physics.nist.gov/cuu/Constants/")).toBe(false);
      expect(isGenericHomepageUrl("https://pubmed.ncbi.nlm.nih.gov/38123456/")).toBe(false);
    });
  });
});
