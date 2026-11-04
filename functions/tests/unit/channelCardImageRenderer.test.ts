import sharp from "sharp";
import {
  renderChannelCardImage,
  formatSubscribersCount,
  wrapTextToLines
} from "../../src/seo/render/channelCardImageRenderer";

describe("Channel Card Image Renderer & Sharing Architecture", () => {
  test("formatSubscribersCount formats counts accurately", () => {
    expect(formatSubscribersCount(undefined)).toBe("0 subscribers");
    expect(formatSubscribersCount(0)).toBe("0 subscribers");
    expect(formatSubscribersCount(-10)).toBe("0 subscribers");
    expect(formatSubscribersCount(1)).toBe("1 subscriber");
    expect(formatSubscribersCount(13)).toBe("13 subscribers");
    expect(formatSubscribersCount(1200)).toBe("1.2K subscribers");
    expect(formatSubscribersCount(1500000)).toBe("1.5M subscribers");
  });

  test("wrapTextToLines wraps description cleanly to max 2 lines with ellipsis", () => {
    const shortDesc = "Truthworld Channel";
    expect(wrapTextToLines(shortDesc, 68, 2)).toEqual(["Truthworld Channel"]);

    const longDesc = "Ebenezer vampu channel showing the Travel and vlogs global content across India and international destinations with verified authentic video quality.";
    const wrapped = wrapTextToLines(longDesc, 45, 2);
    expect(wrapped.length).toBeLessThanOrEqual(2);
    expect(wrapped[1].endsWith("...")).toBe(true);
  });

  test("renderChannelCardImage generates a valid 1024x848 PNG matching Image 2 architecture", async () => {
    const pngBuffer = await renderChannelCardImage({
      channelName: "Ebenezer Vampu",
      handle: "@ebenezer-vampu",
      subscriberCount: 1,
      description: "Ebenezer vampu channel showing the Travel and vlogs global content",
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    expect(pngBuffer.length).toBeGreaterThan(1000);

    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
    expect(metadata.format).toBe("png");
  });

  test("renderChannelCardImage handles empty and fallback values gracefully", async () => {
    const pngBuffer = await renderChannelCardImage({
      channelName: "",
      handle: "",
      subscriberCount: 0,
      description: "",
      bannerUrl: undefined,
      avatarUrl: undefined,
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
  });
});
