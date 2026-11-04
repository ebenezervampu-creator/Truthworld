import sharp from "sharp";
import {
  renderClaimCardImage,
  resolveVerdictColor,
  wrapTextToLines
} from "../../src/seo/render/claimCardImageRenderer";

describe("Claim Card Image Renderer & Sharing Architecture", () => {
  test("resolveVerdictColor resolves appropriate colors and labels", () => {
    const verified = resolveVerdictColor("VERIFIED TRUE");
    expect(verified.color).toBe("#10b981");
    expect(verified.label).toBe("VERIFIED TRUE");

    const falseClaim = resolveVerdictColor("FALSE CLAIM");
    expect(falseClaim.color).toBe("#ef4444");
    expect(falseClaim.label).toBe("FALSE CLAIM");

    const caution = resolveVerdictColor("MISLEADING");
    expect(caution.color).toBe("#f59e0b");
    expect(caution.label).toBe("MISLEADING");

    const fallback = resolveVerdictColor(undefined);
    expect(fallback.color).toBe("#f59e0b");
    expect(fallback.label).toBe("CAUTION");
  });

  test("wrapTextToLines wraps claim text cleanly to max lines with ellipsis", () => {
    const shortClaim = "Hyderabad is a rapidly growing city.";
    expect(wrapTextToLines(shortClaim, 52, 2)).toEqual(["Hyderabad is a rapidly growing city."]);

    const longClaim = "Global temperature averages exceeded historic benchmarks according to multiple independent international meteorological organizations across five continents.";
    const wrapped = wrapTextToLines(longClaim, 45, 2);
    expect(wrapped.length).toBeLessThanOrEqual(2);
    expect(wrapped[1].endsWith("...")).toBe(true);
  });

  test("renderClaimCardImage generates a valid 1024x848 PNG matching Truthworld architecture", async () => {
    const pngBuffer = await renderClaimCardImage({
      claimText: "Hyderabad is a rapidly growing city in southern India.",
      videoTitle: "Telangana Urban Growth Dossier",
      verdictLabel: "VERIFIED TRUE",
      summaryTakeaway: "Census data and economic growth metrics confirm substantial geographical and demographic expansion.",
      confidenceText: "High (98%)",
      primarySourceDomain: "telangana.gov.in",
      videoId: "vid_hyd_001",
      claimIndex: 0,
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    expect(pngBuffer.length).toBeGreaterThan(1000);

    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
    expect(metadata.format).toBe("png");
  });

  test("renderClaimCardImage handles empty and fallback values gracefully", async () => {
    const pngBuffer = await renderClaimCardImage({
      claimText: "",
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
    expect(metadata.format).toBe("png");
  });
});
