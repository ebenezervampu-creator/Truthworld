import sharp from "sharp";
import { safeFetchImageBuffer } from "./safeImageFetcher";
import { initSeoFontConfig, TW_PREVIEW_FONT_FAMILY } from "./fontConfig";

export interface ChannelCardData {
  channelName: string;
  handle?: string;
  subscriberCount?: number;
  description?: string;
  bannerUrl?: string;
  avatarUrl?: string;
}

function escapeXml(unsafe?: string): string {
  if (!unsafe) return "";
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

export function formatSubscribersCount(count?: number): string {
  if (typeof count !== "number" || count <= 0) return "0 subscribers";
  if (count >= 1000000) {
    return (count / 1000000).toFixed(1).replace(/\.0$/, "") + "M subscribers";
  }
  if (count >= 1000) {
    return (count / 1000).toFixed(1).replace(/\.0$/, "") + "K subscribers";
  }
  return `${count} subscriber${count === 1 ? "" : "s"}`;
}

export function wrapTextToLines(text?: string, maxCharsPerLine: number = 68, maxLines: number = 2): string[] {
  if (!text) return [];
  const clean = text.replace(/[\r\n\t]+/g, " ").replace(/\s+/g, " ").trim();
  if (!clean) return [];

  const words = clean.split(" ");
  const lines: string[] = [];
  let currentLine = "";

  for (const word of words) {
    if ((currentLine + " " + word).trim().length <= maxCharsPerLine) {
      currentLine = (currentLine + " " + word).trim();
    } else {
      if (lines.length + 1 >= maxLines) {
        let last = currentLine;
        while ((last + "...").length > maxCharsPerLine && last.lastIndexOf(" ") > 0) {
          last = last.substring(0, last.lastIndexOf(" "));
        }
        lines.push(last ? `${last}...` : "...");
        return lines;
      }
      lines.push(currentLine);
      currentLine = word;
    }
  }

  if (currentLine && lines.length < maxLines) {
    lines.push(currentLine);
  } else if (currentLine && lines.length >= maxLines) {
    let last = lines[maxLines - 1];
    if (!last.endsWith("...")) {
      lines[maxLines - 1] = last.length > maxCharsPerLine - 3
        ? last.substring(0, maxCharsPerLine - 3) + "..."
        : last + "...";
    }
  }

  return lines.slice(0, maxLines);
}

// In-memory cache to prevent re-processing identical cards under heavy crawler traffic
interface CachedImage {
  buffer: Buffer;
  expiresAt: number;
}
const cardCache = new Map<string, CachedImage>();
const CACHE_TTL_MS = 3600 * 1000; // 1 hour
const MAX_CACHE_ENTRIES = 500;

function getFromCache(key: string): Buffer | null {
  const item = cardCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiresAt) {
    cardCache.delete(key);
    return null;
  }
  return item.buffer;
}

function setToCache(key: string, buffer: Buffer): void {
  if (cardCache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = cardCache.keys().next().value;
    if (oldestKey) cardCache.delete(oldestKey);
  }
  cardCache.set(key, { buffer, expiresAt: Date.now() + CACHE_TTL_MS });
}

/**
 * Renders a high-fidelity 1024x848 social share preview card matching Truthworld architecture:
 * - Widescreen channel banner across the top (1024x480)
 * - Solid #161719 card body with rounded corners
 * - Circular creator avatar (116x116) with subtle white ring
 * - Channel Name (bold white)
 * - Channel Handle (@handle, muted grey #8e8e93)
 * - Subscriber count (e.g. "1 subscriber" / "1.2M subscribers")
 * - Two lines of channel description (muted grey #9ca3af)
 * - Truthworld footer with link icon & chevron >
 */
export async function renderChannelCardImage(data: ChannelCardData): Promise<Buffer> {
  initSeoFontConfig();

  const cacheKey = `${data.handle || ""}_${data.channelName}_${data.subscriberCount || 0}_${(data.bannerUrl || "").slice(-25)}_${(data.avatarUrl || "").slice(-25)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 1024;
  const height = 848;
  const bannerHeight = 480;
  const avatarSize = 116;

  const name = (data.channelName || "Truthworld Channel").trim();
  const rawHandle = (data.handle || "").replace(/^@/, "").trim();
  const handleStr = rawHandle ? `@${rawHandle}` : "@channel";
  const subStr = formatSubscribersCount(data.subscriberCount);
  const descLines = wrapTextToLines(
    data.description || "Watch family-safe, verified videos on Truthworld. Epistemic clarity and high quality content.",
    68,
    2
  );

  // 1. Fetch & process Banner safely with SSRF defense
  let bannerBuffer: Buffer | null = null;
  if (data.bannerUrl) {
    try {
      const rawBanner = await safeFetchImageBuffer(
        data.bannerUrl,
        "Truthworld-Channel-Card-Renderer/1.0",
        4000
      );
      if (rawBanner) {
        bannerBuffer = await sharp(rawBanner)
          .resize(width, bannerHeight, { fit: "cover", position: "center" })
          .png()
          .toBuffer();
      }
    } catch (_) {
      // Graceful fallback to gradient banner
    }
  }

  // 2. Fetch & process Avatar safely with SSRF defense
  let avatarBuffer: Buffer | null = null;
  if (data.avatarUrl) {
    try {
      const rawAvatar = await safeFetchImageBuffer(
        data.avatarUrl,
        "Truthworld-Channel-Card-Renderer/1.0",
        4000
      );

      if (rawAvatar) {
        const resizedAvatar = await sharp(rawAvatar)
          .resize(avatarSize, avatarSize, { fit: "cover", position: "center" })
          .png()
          .toBuffer();

        const circleMask = Buffer.from(`
          <svg width="${avatarSize}" height="${avatarSize}">
            <circle cx="${avatarSize / 2}" cy="${avatarSize / 2}" r="${avatarSize / 2}" fill="#ffffff"/>
          </svg>
        `);

        avatarBuffer = await sharp(resizedAvatar)
          .composite([{ input: circleMask, blend: "dest-in" }])
          .png()
          .toBuffer();
      }
    } catch (_) {
      // Graceful fallback to monogram avatar
    }
  }

  const bannerBase64 = bannerBuffer ? `data:image/png;base64,${bannerBuffer.toString("base64")}` : "";
  const avatarBase64 = avatarBuffer ? `data:image/png;base64,${avatarBuffer.toString("base64")}` : "";

  // Fallback banner SVG markup
  const fallbackBannerSvg = `
    <defs>
      <linearGradient id="twBannerGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#1e1035"/>
        <stop offset="50%" stop-color="#2d1254"/>
        <stop offset="100%" stop-color="#0f051d"/>
      </linearGradient>
    </defs>
    <rect x="0" y="0" width="${width}" height="${bannerHeight}" fill="url(#twBannerGrad)"/>
    <text x="${width / 2}" y="${bannerHeight / 2 + 15}" fill="rgba(255,255,255,0.18)" font-size="52" font-weight="bold" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="4">TRUTHWORLD</text>
  `;

  // Fallback avatar SVG markup
  const initialLetter = name.length > 0 ? name.charAt(0).toUpperCase() : "T";
  const avatarCenterX = 44 + avatarSize / 2; // 102
  const avatarCenterY = bannerHeight + 26 + avatarSize / 2; // 564
  const fallbackAvatarSvg = `
    <circle cx="${avatarCenterX}" cy="${avatarCenterY}" r="${avatarSize / 2}" fill="#2a1b40"/>
    <text x="${avatarCenterX}" y="${avatarCenterY + 16}" fill="#ffffff" font-size="48" font-weight="bold" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle">${escapeXml(initialLetter)}</text>
  `;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <defs>
        <clipPath id="channelCardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="24" ry="24"/>
        </clipPath>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#channelCardClip)">
        <!-- Solid Dark Background (#161719 matching Truthworld share architecture) -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Banner (16:9 widescreen section, cover fit) -->
        ${bannerBase64 ? `<image href="${bannerBase64}" xlink:href="${bannerBase64}" x="0" y="0" width="${width}" height="${bannerHeight}" preserveAspectRatio="xMidYMid slice"/>` : fallbackBannerSvg}

        <!-- Seam line divider between banner and content -->
        <rect x="0" y="${bannerHeight}" width="${width}" height="1" fill="#27272a" opacity="0.6"/>

        <!-- Avatar Border Ring -->
        <circle cx="${avatarCenterX}" cy="${avatarCenterY}" r="${avatarSize / 2 + 2}" fill="none" stroke="rgba(255,255,255,0.18)" stroke-width="2.5"/>

        <!-- Avatar Image or Monogram -->
        ${avatarBase64 ? `<image href="${avatarBase64}" xlink:href="${avatarBase64}" x="44" y="${bannerHeight + 26}" width="${avatarSize}" height="${avatarSize}"/>` : fallbackAvatarSvg}

        <!-- Channel Title (Bold White) -->
        <text x="184" y="538" fill="#ffffff" font-size="28" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(name)}</text>

        <!-- Channel Handle (Muted Grey #8e8e93) -->
        <text x="184" y="572" fill="#8e8e93" font-size="20" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(handleStr)}</text>

        <!-- Subscriber Count (Muted Grey #8e8e93) -->
        <text x="184" y="604" fill="#8e8e93" font-size="20" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(subStr)}</text>

        <!-- Two lines of channel description (Image 2) -->
        ${descLines[0] ? `<text x="44" y="668" fill="#9ca3af" font-size="20" font-weight="400" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(descLines[0])}</text>` : ""}
        ${descLines[1] ? `<text x="44" y="702" fill="#9ca3af" font-size="20" font-weight="400" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(descLines[1])}</text>` : ""}

        <!-- Footer Divider Line (Image 2) -->
        <line x1="44" y1="744" x2="${width - 44}" y2="744" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>

        <!-- Footer: Link Icon + Truthworld + Chevron > (Image 2) -->
        <g transform="translate(44, 768)">
          <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
          <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
        </g>
        <text x="82" y="786" fill="#ffffff" font-size="22" font-weight="600" font-family="${TW_PREVIEW_FONT_FAMILY}" letter-spacing="-0.2">Truthworld</text>

        <!-- Chevron > on far right -->
        <g transform="translate(${width - 64}, 771)">
          <path d="M2 2 L9 9 L2 16" fill="none" stroke="#ffffff" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
        </g>

        <!-- Outer Border Stroke -->
        <rect x="0.5" y="0.5" width="${width - 1}" height="${height - 1}" rx="24" ry="24" fill="none" stroke="#27272a" stroke-width="1.5"/>
      </g>
    </svg>
  `;

  let finalBuffer = await sharp(Buffer.from(svgContent))
    .png({ compressionLevel: 9, effort: 8 })
    .toBuffer();

  // Social scrapers drop images exceeding 300KB. If needed, apply gentle optimization.
  if (finalBuffer.length > 290 * 1024) {
    finalBuffer = await sharp(Buffer.from(svgContent))
      .png({ compressionLevel: 9, effort: 8, quality: 92 })
      .toBuffer();
  }

  setToCache(cacheKey, finalBuffer);
  return finalBuffer;
}
