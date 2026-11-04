import sharp from "sharp";
import {
  renderVideoCardImage,
  formatDurationMs,
  wrapTextToLines
} from "../../src/seo/render/videoCardImageRenderer";

describe("Video Card Image Renderer & Sharing Architecture", () => {
  test("formatDurationMs formats milliseconds accurately into MM:SS or HH:MM:SS", () => {
    expect(formatDurationMs(undefined)).toBe("");
    expect(formatDurationMs(0)).toBe("");
    expect(formatDurationMs(-500)).toBe("");
    expect(formatDurationMs(65000)).toBe("1:05");
    expect(formatDurationMs(704000)).toBe("11:44");
    expect(formatDurationMs(705000)).toBe("11:45");
    expect(formatDurationMs(3665000)).toBe("1:01:05");
  });

  test("wrapTextToLines wraps text cleanly to max lines with ellipsis", () => {
    const shortText = "Truthworld Video";
    expect(wrapTextToLines(shortText, 56, 2)).toEqual(["Truthworld Video"]);

    const longTitle = "Sowjanya Case: What Happened in Dharmasthala? | Full Case Explained and Detailed Investigation with Verified Facts";
    const wrapped = wrapTextToLines(longTitle, 40, 2);
    expect(wrapped.length).toBeLessThanOrEqual(2);
    expect(wrapped[1].endsWith("...")).toBe(true);
  });

  test("renderVideoCardImage generates a valid 1024x848 PNG matching Image 2 architecture", async () => {
    const pngBuffer = await renderVideoCardImage({
      title: "Sowjanya Case: What Happened in Dharmasthala? | Full Case Explained",
      description: "Watch family-safe, verified video with epistemic clarity on Truthworld.",
      channelName: "Ebenezer Vampu",
      durationMs: 705000, // 11:45
      videoId: "f362639f-054a-42d7-91c6-3398b09f77b6"
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    expect(pngBuffer.length).toBeGreaterThan(1000);

    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
    expect(metadata.format).toBe("png");
  });

  test("renderVideoCardImage suppresses junk 'Uploading...' and 'Processing...' tokens", async () => {
    const pngBuffer = await renderVideoCardImage({
      title: "Uploading...",
      description: "Processing... • Video by Ebenezer Vampu • 0 views • 11:44 • Truthworld",
      channelName: "Ebenezer Vampu",
      durationMs: 704000,
      videoId: "test_junk_tokens_video"
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
  });

  test("renderVideoCardImage for chapter produces an image strictly under 300KB (WhatsApp mobile limit)", async () => {
    const pngBuffer = await renderVideoCardImage({
      title: '"Jio Platforms IPO: Hype vs. Reality" - Jio IPO 2026',
      description: 'Watch "Jio Platforms IPO: Hype vs. Reality" from "Jio IPO 2026" by Ebenezer Vampu on Truthworld (Chapter at 0:19).',
      channelName: "Ebenezer Vampu",
      durationMs: 273000,
      videoId: "1482f69a-43e3-45cd-993c-13c0a0504830"
    });

    expect(Buffer.isBuffer(pngBuffer)).toBe(true);
    // WhatsApp on Android drops any OG image exceeding 300 KB (307,200 bytes)
    expect(pngBuffer.length).toBeLessThan(300 * 1024);

    const metadata = await sharp(pngBuffer).metadata();
    expect(metadata.width).toBe(1024);
    expect(metadata.height).toBe(848);
    expect(metadata.format).toBe("png");
  });
});
