import sharp from "sharp";
import {
  renderPlaylistCardImage,
  formatVideoCount,
  wrapTextToLines
} from "../../src/seo/render/playlistCardImageRenderer";

describe("Playlist Card Image Renderer & Sharing Architecture", () => {
  test("formatVideoCount formats video counts accurately", () => {
    expect(formatVideoCount(undefined)).toBe("0 videos");
    expect(formatVideoCount(0)).toBe("0 videos");
    expect(formatVideoCount(-5)).toBe("0 videos");
    expect(formatVideoCount(1)).toBe("1 video");
    expect(formatVideoCount(3)).toBe("3 videos");
    expect(formatVideoCount(1200)).toBe("1.2K videos");
    expect(formatVideoCount(1500000)).toBe("1.5M videos");
  });

  test("wrapTextToLines wraps playlist title cleanly to max 2 lines with ellipsis", () => {
    const shortTitle = "Watch Later";
    expect(wrapTextToLines(shortTitle, 54, 2)).toEqual(["Watch Later"]);

    const longTitle = "Christian Songs 2026 Worship Praise Hope Faith - Curated Gospel and Global Spiritual Music Collection";
    const wrapped = wrapTextToLines(longTitle, 40, 2);
    expect(wrapped.length).toBeLessThanOrEqual(2);
    expect(wrapped[1].endsWith("...")).toBe(true);
  });

  test("renderPlaylistCardImage generates a valid 1024x848 PNG matching Image 2 architecture", async () => {
    const pngBuffer = await renderPlaylistCardImage({
      playlistName: "Watch Later",
      channelName: "Ebenezer Vampu",
      videoCount: 3,
      playlistId: "watchlater",
      description: "Watch Later playlist on Truthworld. Verified videos with epistemic clarity.",
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    expect(pngBuffer.length).toBeGreaterThan(1000);

    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
    expect(metadata.format).toBe("png");
  });

  test("renderPlaylistCardImage handles empty and fallback values gracefully", async () => {
    const pngBuffer = await renderPlaylistCardImage({
      playlistName: "",
      channelName: "",
      videoCount: 0,
      thumbnailUrl: undefined,
      description: "",
      playlistId: "fallback_playlist",
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
  });
});
