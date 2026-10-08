import sharp from "sharp";
import axios from "axios";

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

export function wrapTextToLines(text?: string, maxCharsPerLine: number = 64, maxLines: number = 2): string[] {
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

export async function renderChannelCardImage(data: ChannelCardData): Promise<Buffer> {
  const cacheKey = `${data.handle || ""}_${data.channelName}_${data.subscriberCount || 0}_${(data.bannerUrl || "").slice(-20)}_${(data.avatarUrl || "").slice(-20)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 850;
  const height = 1024;
  const bannerHeight = 472;
  const avatarSize = 144;

  const name = (data.channelName || "Truthworld Channel").trim();
  const rawHandle = (data.handle || "").replace(/^@/, "").trim();
  const handleStr = rawHandle ? `@${rawHandle}` : "@channel";
  const subStr = formatSubscribersCount(data.subscriberCount);
  const descLines = wrapTextToLines(
    data.description || "Watch family-safe, verified videos on Truthworld. Epistemic clarity and high quality content.",
    64,
    2
  );

  // 1. Fetch & process Banner
  let bannerBuffer: Buffer | null = null;
  if (data.bannerUrl) {
    try {
      const resp = await axios.get(data.bannerUrl, {
        responseType: "arraybuffer",
        timeout: 4000,
        headers: { "User-Agent": "Truthworld-Card-Renderer/1.0" }
      });
      bannerBuffer = await sharp(resp.data)
        .resize(width, bannerHeight, { fit: "cover", position: "center" })
        .png()
        .toBuffer();
    } catch (_) {
      // Graceful fallback to gradient banner
    }
  }

  // 2. Fetch & process Avatar
  let avatarBuffer: Buffer | null = null;
  if (data.avatarUrl) {
    try {
      const resp = await axios.get(data.avatarUrl, {
        responseType: "arraybuffer",
        timeout: 4000,
        headers: { "User-Agent": "Truthworld-Card-Renderer/1.0" }
      });

      const resizedAvatar = await sharp(resp.data)
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
    <text x="${width / 2}" y="${bannerHeight / 2 + 15}" fill="rgba(255,255,255,0.18)" font-size="52" font-weight="bold" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" text-anchor="middle" letter-spacing="4">TRUTHWORLD</text>
  `;

  // Fallback avatar SVG markup
  const initialLetter = name.length > 0 ? name.charAt(0).toUpperCase() : "T";
  const fallbackAvatarSvg = `
    <circle cx="128" cy="570" r="${avatarSize / 2}" fill="#2a1b40"/>
    <text x="128" y="588" fill="#ffffff" font-size="54" font-weight="bold" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" text-anchor="middle">${escapeXml(initialLetter)}</text>
  `;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <clipPath id="cardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="28" ry="28"/>
        </clipPath>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#cardClip)">
        <!-- Solid Dark Background -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Banner (Image or Gradient) -->
        ${bannerBase64 ? `<image href="${bannerBase64}" x="0" y="0" width="${width}" height="${bannerHeight}" preserveAspectRatio="xMidYMid slice"/>` : fallbackBannerSvg}

        <!-- Subtle bottom shadow on banner seam -->
        <rect x="0" y="${bannerHeight - 20}" width="${width}" height="22" fill="#161719" opacity="0.35"/>

        <!-- Avatar Border Ring -->
        <circle cx="128" cy="570" r="76" fill="none" stroke="#27272a" stroke-width="3.5"/>

        <!-- Avatar Image or Monogram -->
        ${avatarBase64 ? `<image href="${avatarBase64}" x="56" y="498" width="${avatarSize}" height="${avatarSize}"/>` : fallbackAvatarSvg}

        <!-- Channel Title -->
        <text x="232" y="534" fill="#ffffff" font-size="34" font-weight="700" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(name)}</text>

        <!-- Channel Handle -->
        <text x="232" y="574" fill="#8e8e93" font-size="23" font-weight="500" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(handleStr)}</text>

        <!-- Subscriber Count -->
        <text x="232" y="614" fill="#8e8e93" font-size="23" font-weight="500" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(subStr)}</text>

        <!-- Two lines of channel description -->
        ${descLines[0] ? `<text x="56" y="694" fill="#9ca3af" font-size="22" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[0])}</text>` : ""}
        ${descLines[1] ? `<text x="56" y="730" fill="#9ca3af" font-size="22" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[1])}</text>` : ""}

        <!-- Bottom Footer: Link Icon, Truthworld, Chevron -->
        <!-- Link Icon -->
        <g transform="translate(56, 922)">
          <path d="M10.59 13.41c.41.39 1.04.39 1.45 0l4.59-4.59a5.1 5.1 0 0 0 0-7.22 5.1 5.1 0 0 0-7.22 0l-2.73 2.73a5.1 5.1 0 0 0 0 7.22c.39.39 1.02.39 1.41 0 .39-.39.39-1.02 0-1.41a3.06 3.06 0 0 1 0-4.33l2.73-2.73a3.06 3.06 0 0 1 4.33 0 3.06 3.06 0 0 1 0 4.33l-4.59 4.59c-.39.41-.39 1.04.03 1.41zM14.41 11.59c-.41-.39-1.04-.39-1.45 0l-4.59 4.59a5.1 5.1 0 0 0 0 7.22 5.1 5.1 0 0 0 7.22 0l2.73-2.73a5.1 5.1 0 0 0 0-7.22c-.39-.39-1.02-.39-1.41 0-.39.39-.39 1.02 0 1.41a3.06 3.06 0 0 1 0 4.33l-2.73 2.73a3.06 3.06 0 0 1-4.33 0 3.06 3.06 0 0 1 0-4.33l4.59-4.59c.39-.41.39-1.04-.03-1.41z" fill="#ffffff" transform="scale(1.2)"/>
        </g>

        <!-- Truthworld Text -->
        <text x="100" y="948" fill="#ffffff" font-size="28" font-weight="600" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">Truthworld</text>

        <!-- Chevron Right -->
        <path d="M784 932 L794 943 L784 954" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
      </g>
    </svg>
  `;

  const finalBuffer = await sharp(Buffer.from(svgContent)).png().toBuffer();
  setToCache(cacheKey, finalBuffer);
  return finalBuffer;
}
