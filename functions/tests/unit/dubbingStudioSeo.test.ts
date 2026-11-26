import * as fs from "fs";
import * as path from "path";
import { generateOrganizationSchema } from "../../src/seo/schema/organizationSchema";
import { normalizeUrl } from "../../src/seo/indexing/urlNormalizer";
import { generateStaticSitemap } from "../../src/seo/sitemap/sitemapGenerator";
import { buildSemanticSsrHtml } from "../../src/seo/render/htmlRenderer";

describe("Unit: Truthworld Dubbing Studio SEO & Search Accessibility", () => {
  it("exposes Truthworld Dubbing Studio in Organization/WebSite/Sitelinks JSON-LD", () => {
    const schemas = generateOrganizationSchema();
    const website = schemas.find((s: any) => s["@type"] === "WebSite") as any;
    const brand = schemas.find((s: any) => s["@type"] === "Brand") as any;
    const sitelinks = schemas.find((s: any) => s["@type"] === "ItemList") as any;

    expect(website.alternateName).toContain("Truthworld Dubbing Studio");
    expect(brand.alternateName).toContain("Truthworld Dubbing Studio");

    const dubbingSitelink = sitelinks.itemListElement.find(
      (el: any) => el.name === "Truthworld Dubbing Studio"
    );
    expect(dubbingSitelink).toBeDefined();
    expect(dubbingSitelink.url).toBe("https://www.truthworld.in/dubbing");
  });

  it("canonicalizes dubbing.truthworld.in and /dubbing aliases cleanly", () => {
    expect(normalizeUrl("dubbing.truthworld.in", "/")).toBe("https://dubbing.truthworld.in/");
    expect(normalizeUrl("dubbing.truthworld.in", "/dubbing")).toBe("https://dubbing.truthworld.in/");
    expect(normalizeUrl("www.truthworld.in", "/dubbing")).toBe("https://www.truthworld.in/dubbing");
    expect(normalizeUrl("www.truthworld.in", "/dubbing/")).toBe("https://www.truthworld.in/dubbing");
    expect(normalizeUrl("www.truthworld.in", "/dubbing-studio")).toBe("https://www.truthworld.in/dubbing");
  });

  it("includes /dubbing in generated static sitemap", async () => {
    const xml = await generateStaticSitemap();
    expect(xml).toContain("<loc>https://www.truthworld.in/dubbing</loc>");
  });

  it("includes Truthworld Dubbing Studio links in SSR navigation and footer", () => {
    const html = buildSemanticSsrHtml({
      title: "Test",
      description: "Test description",
      url: "https://www.truthworld.in/",
    });
    expect(html).toContain('href="https://www.truthworld.in/dubbing"');
    expect(html).toContain("Truthworld Dubbing Studio");
  });

  it("wires /dubbing SSR route, 301 /dubbing-studio redirect, and app links in seoServer.ts", () => {
    const seoServerCode = fs.readFileSync(
      path.resolve(__dirname, "../../src/seo/seoServer.ts"),
      "utf-8"
    );
    expect(seoServerCode).toContain("dubbing_studio_canonical_page_v1");
    expect(seoServerCode).toContain("com.truthworld.dubbing");
    expect(seoServerCode).toContain("/dubbing*");
    expect(seoServerCode).toContain('lowerPath === "/dubbing-studio"');
  });
});
