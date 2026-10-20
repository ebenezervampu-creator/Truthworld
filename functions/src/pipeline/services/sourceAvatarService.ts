/**
 * 🏛 Source Avatar Resolution Service
 *
 * Provides authoritative high-resolution brand & institutional logos/avatars
 * for fact-checking citations and source verification.
 */
export class SourceAvatarService {
  // Curated institutional emblems and verified brand logos (High-res SVG / PNG)
  private static readonly INSTITUTIONAL_AVATARS: Record<string, string> = {
    // Government & Health Ministries
    "mohfw.gov.in": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/Emblem_of_India.svg/250px-Emblem_of_India.svg.png",
    "icmr.gov.in": "https://upload.wikimedia.org/wikipedia/en/thumb/d/d4/Indian_Council_of_Medical_Research_Logo.svg/250px-Indian_Council_of_Medical_Research_Logo.svg.png",
    "fao.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/FAO_logo.svg/250px-FAO_logo.svg.png",
    "who.int": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/WHO_logo.svg/250px-WHO_logo.svg.png",
    "cdc.gov": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/US_CDC_logo.svg/250px-US_CDC_logo.svg.png",
    "nih.gov": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/National_Institutes_of_Health_logo.svg/250px-National_Institutes_of_Health_logo.svg.png",
    "fda.gov": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/FDA_logo.svg/250px-FDA_logo.svg.png",
    "nasa.gov": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/NASA_logo.svg/250px-NASA_logo.svg.png",
    "isro.gov.in": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/ISRO_Logo.svg/250px-ISRO_Logo.svg.png",
    "un.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Flag_of_the_United_Nations.svg/250px-Flag_of_the_United_Nations.svg.png",
    "unesco.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/UNESCO_logo.svg/250px-UNESCO_logo.svg.png",
    "unicef.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/UNICEF_Logo.svg/250px-UNICEF_Logo.svg.png",
    "worldbank.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/The_World_Bank_logo.svg/250px-The_World_Bank_logo.svg.png",
    "imf.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/International_Monetary_Fund_logo.svg/250px-International_Monetary_Fund_logo.svg.png",

    // News & Media
    "dnaindia.com": "https://www.google.com/s2/favicons?domain=dnaindia.com&sz=128",
    "bbc.com": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/BBC.svg/250px-BBC.svg.png",
    "bbc.co.uk": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/BBC.svg/250px-BBC.svg.png",
    "reuters.com": "https://www.google.com/s2/favicons?domain=reuters.com&sz=128",
    "apnews.com": "https://www.google.com/s2/favicons?domain=apnews.com&sz=128",
    "thehindu.com": "https://www.google.com/s2/favicons?domain=thehindu.com&sz=128",
    "indianexpress.com": "https://www.google.com/s2/favicons?domain=indianexpress.com&sz=128",
    "ndtv.com": "https://www.google.com/s2/favicons?domain=ndtv.com&sz=128",
    "timesofindia.indiatimes.com": "https://www.google.com/s2/favicons?domain=timesofindia.indiatimes.com&sz=128",
    "nytimes.com": "https://www.google.com/s2/favicons?domain=nytimes.com&sz=128",
    "wsj.com": "https://www.google.com/s2/favicons?domain=wsj.com&sz=128",
    "bloomberg.com": "https://www.google.com/s2/favicons?domain=bloomberg.com&sz=128",
    "aljazeera.com": "https://www.google.com/s2/favicons?domain=aljazeera.com&sz=128",
    "theguardian.com": "https://www.google.com/s2/favicons?domain=theguardian.com&sz=128",

    // Scientific Journals & Fact Checkers
    "nature.com": "https://www.google.com/s2/favicons?domain=nature.com&sz=128",
    "science.org": "https://www.google.com/s2/favicons?domain=science.org&sz=128",
    "thelancet.com": "https://www.google.com/s2/favicons?domain=thelancet.com&sz=128",
    "nejm.org": "https://www.google.com/s2/favicons?domain=nejm.org&sz=128",
    "bmj.com": "https://www.google.com/s2/favicons?domain=bmj.com&sz=128",
    "pnas.org": "https://www.google.com/s2/favicons?domain=pnas.org&sz=128",
    "snopes.com": "https://www.google.com/s2/favicons?domain=snopes.com&sz=128",
    "factcheck.org": "https://www.google.com/s2/favicons?domain=factcheck.org&sz=128",
    "politifact.com": "https://www.google.com/s2/favicons?domain=politifact.com&sz=128",
    "boomlive.in": "https://www.google.com/s2/favicons?domain=boomlive.in&sz=128",
    "wikipedia.org": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/250px-Wikipedia-logo-v2.svg.png",
  };

  /**
   * Normalizes a raw URL or domain string into a clean domain.
   */
  public static cleanDomain(raw?: string): string {
    if (!raw) return "";
    let cleaned = raw.trim().toLowerCase();
    cleaned = cleaned.replace(/^https?:\/\//i, "");
    cleaned = cleaned.replace(/^www\./i, "");
    cleaned = cleaned.split("/")[0].split("?")[0].split("#")[0];
    return cleaned;
  }

  /**
   * Resolves the authentic avatar URL for a given domain, URL, or publisher.
   */
  public static resolveAvatar(domainOrUrl?: string, publisher?: string): string {
    const domain = this.cleanDomain(domainOrUrl);

    // 1. Direct match in institutional dictionary
    if (domain && this.INSTITUTIONAL_AVATARS[domain]) {
      return this.INSTITUTIONAL_AVATARS[domain];
    }

    // 2. Publisher name match fallback
    if (publisher) {
      const pubLower = publisher.toLowerCase().trim();
      if (pubLower.includes("health and family welfare") || pubLower === "mohfw") {
        return this.INSTITUTIONAL_AVATARS["mohfw.gov.in"];
      }
      if (pubLower.includes("icmr") || pubLower.includes("indian council of medical research")) {
        return this.INSTITUTIONAL_AVATARS["icmr.gov.in"];
      }
      if (pubLower.includes("food and agriculture") || pubLower === "fao") {
        return this.INSTITUTIONAL_AVATARS["fao.org"];
      }
      if (pubLower.includes("dna india") || pubLower === "dna") {
        return this.INSTITUTIONAL_AVATARS["dnaindia.com"];
      }
      if (pubLower.includes("bbc")) {
        return this.INSTITUTIONAL_AVATARS["bbc.com"];
      }
      if (pubLower.includes("world health") || pubLower === "who") {
        return this.INSTITUTIONAL_AVATARS["who.int"];
      }
      if (pubLower.includes("reuters")) {
        return this.INSTITUTIONAL_AVATARS["reuters.com"];
      }
    }

    // 3. Fallback to Google High-Resolution 128px Favicon Service
    if (domain && domain.includes(".")) {
      return `https://www.google.com/s2/favicons?domain=${encodeURIComponent(domain)}&sz=128`;
    }

    return "";
  }

  /**
   * Resolves a batch of domains/publishers, reading from Firestore cache and populating missing items.
   */
  public static async resolveBatch(
    items: Array<{ domain?: string; publisher?: string; url?: string }>
  ): Promise<Record<string, string>> {
    const result: Record<string, string> = {};
    if (!items || items.length === 0) return result;

    for (const item of items) {
      const key = this.cleanDomain(item.domain || item.url) || item.publisher?.toLowerCase().trim() || "";
      if (!key) continue;

      const avatar = this.resolveAvatar(item.domain || item.url, item.publisher);
      if (avatar) {
        result[key] = avatar;
        if (item.domain) result[item.domain] = avatar;
      }
    }

    return result;
  }
}
