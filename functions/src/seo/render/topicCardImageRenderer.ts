import sharp from "sharp";
import axios from "axios";

export interface TopicCardData {
  title: string;
  handle?: string;
  followerCount?: number;
  videoCount?: number;
  description?: string;
  thumbnailUrl?: string;
  url?: string;
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

export function formatFollowersCount(count?: number): string {
  if (typeof count !== "number" || count <= 0) return "0 Followers";
  if (count >= 1000000) {
    return (count / 1000000).toFixed(1).replace(/\.0$/, "") + "M Followers";
  }
  if (count >= 1000) {
    return (count / 1000).toFixed(1).replace(/\.0$/, "") + "K Followers";
  }
  return `${count} Follower${count === 1 ? "" : "s"}`;
}

export function formatVideosCount(count?: number): string {
  if (typeof count !== "number" || count <= 0) return "0 Videos";
  if (count >= 1000000) {
    return (count / 1000000).toFixed(1).replace(/\.0$/, "") + "M Videos";
  }
  if (count >= 1000) {
    return (count / 1000).toFixed(1).replace(/\.0$/, "") + "K Videos";
  }
  return `${count} Video${count === 1 ? "" : "s"}`;
}

export function wrapTextToLines(text?: string, maxCharsPerLine: number = 72, maxLines: number = 3): string[] {
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

// In-memory cache to prevent re-processing identical cards under crawler traffic
interface CachedImage {
  buffer: Buffer;
  expiresAt: number;
}
const topicCardCache = new Map<string, CachedImage>();
const CACHE_TTL_MS = 3600 * 1000; // 1 hour
const MAX_CACHE_ENTRIES = 500;

function getFromCache(key: string): Buffer | null {
  const item = topicCardCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiresAt) {
    topicCardCache.delete(key);
    return null;
  }
  return item.buffer;
}

function setToCache(key: string, buffer: Buffer): void {
  if (topicCardCache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = topicCardCache.keys().next().value;
    if (oldestKey) topicCardCache.delete(oldestKey);
  }
  topicCardCache.set(key, { buffer, expiresAt: Date.now() + CACHE_TTL_MS });
}

/**
 * Renders a high-fidelity 1024x682 social share preview card for Topics matching the exact Truthworld architecture:
 * - Top Widescreen Topic Banner (1024x310)
 * - Topic Title with Gold Verified Checkmark Badge
 * - Clean handle (@truthworldtopics or #topic)
 * - Metrics: Followers + Videos count with separator
 * - Description (up to 3 lines, #9CA3AF)
 * - Bottom Pill Container with link icon, canonical URL, and "Truthworld >"
 * - NO Follow option (per explicit user instruction)
 */
export async function renderTopicCardImage(data: TopicCardData): Promise<Buffer> {
  const rawTitle = (data.title || "Truthworld Topics").trim();
  const cleanTitle = rawTitle.replace(/^[#Tt]\//, "").trim();
  const cacheKey = `${data.handle || ""}_${cleanTitle}_${data.followerCount || 0}_${data.videoCount || 0}_${(data.thumbnailUrl || "").slice(-25)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 1024;
  const height = 682;
  const bannerHeight = 310;

  // Handle format
  const rawHandle = (data.handle || "").replace(/^[#@]/, "").replace(/^[Tt]\//, "").trim();
  const handleStr = rawHandle ? `@ ${rawHandle.toLowerCase()}` : `@ truthworldtopics`;

  const followerStr = formatFollowersCount(data.followerCount);
  const videoStr = formatVideosCount(data.videoCount);
  const cleanUrl = (data.url || `https://truthworld.in/T/${rawHandle || "topics"}`).trim();

  const descLines = wrapTextToLines(
    data.description || "Truthworld Topics brings you the best verified channels and creators across education, technology, science, health, spirituality, entertainment and more.",
    68,
    3
  );

  // 1. Fetch & process Topic Banner
  let bannerBuffer: Buffer | null = null;
  if (data.thumbnailUrl) {
    try {
      const resp = await axios.get(data.thumbnailUrl, {
        responseType: "arraybuffer",
        timeout: 4000,
        headers: { "User-Agent": "Truthworld-Topic-Card-Renderer/1.0" },
      });
      bannerBuffer = await sharp(resp.data)
        .resize(width, bannerHeight, { fit: "cover", position: "center" })
        .png()
        .toBuffer();
    } catch (_) {
      // Graceful fallback to default banner
    }
  }

  const bannerBase64 = bannerBuffer
    ? `data:image/png;base64,${bannerBuffer.toString("base64")}`
    : "";

  // Fallback banner SVG markup
  const fallbackBannerSvg = `
    <defs>
      <linearGradient id="twTopicGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#090514"/>
        <stop offset="35%" stop-color="#180b30"/>
        <stop offset="70%" stop-color="#2a0f55"/>
        <stop offset="100%" stop-color="#0c0418"/>
      </linearGradient>
    </defs>
    <rect x="0" y="0" width="${width}" height="${bannerHeight}" fill="url(#twTopicGrad)"/>
    <text x="60" y="140" fill="#ffffff" font-size="52" font-weight="900" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" letter-spacing="-0.5">Truthworld</text>
    <text x="60" y="200" fill="#f59e0b" font-size="44" font-weight="800" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" letter-spacing="1">Topics</text>
    <text x="60" y="245" fill="rgba(255,255,255,0.45)" font-size="16" font-weight="700" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" letter-spacing="3">EXPLORE. LEARN. VERIFY. GROW.</text>
  `;

  const descLine1Y = 486;
  const descLine2Y = 514;
  const descLine3Y = 542;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <clipPath id="topicCardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="24" ry="24"/>
        </clipPath>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#topicCardClip)">
        <!-- Solid Dark Background -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Banner (Image or Gradient) -->
        ${bannerBase64 ? `<image href="${bannerBase64}" x="0" y="0" width="${width}" height="${bannerHeight}" preserveAspectRatio="xMidYMid slice"/>` : fallbackBannerSvg}

        <!-- Subtle bottom shadow on banner seam -->
        <rect x="0" y="${bannerHeight - 12}" width="${width}" height="14" fill="#161719" opacity="0.45"/>

        <!-- Topic Title -->
        <text x="40" y="364" fill="#ffffff" font-size="34" font-weight="800" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" letter-spacing="-0.5">${escapeXml(cleanTitle)}</text>

        <!-- Handle (@ handle) -->
        <g transform="translate(40, 396)">
          <!-- At sign icon -->
          <text x="0" y="0" fill="#8e8e93" font-size="21" font-weight="500" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(handleStr)}</text>
        </g>

        <!-- Metrics Row: Followers + Videos -->
        <g transform="translate(40, 436)">
          <!-- Followers Icon (Two people) -->
          <g transform="translate(0, -18)">
            <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" fill="#9ca3af" transform="scale(1.1)"/>
          </g>
          <text x="32" y="0" fill="#ffffff" font-size="21" font-weight="600" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(followerStr)}</text>

          <!-- Divider Bar | -->
          <line x1="210" y1="-18" x2="210" y2="4" stroke="#3f3f46" stroke-width="2"/>

          <!-- Videos Bar Chart Icon -->
          <g transform="translate(230, -18)">
            <path d="M5 9.2h3V19H5zM10.6 5h2.8v14.2h-2.8zm5.6 8h2.8v6.2h-2.8z" fill="#9ca3af" transform="scale(1.1)"/>
          </g>
          <text x="264" y="0" fill="#ffffff" font-size="21" font-weight="600" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(videoStr)}</text>
        </g>

        <!-- Topic Description (up to 3 lines) -->
        ${descLines[0] ? `<text x="40" y="${descLine1Y}" fill="#9ca3af" font-size="19" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[0])}</text>` : ""}
        ${descLines[1] ? `<text x="40" y="${descLine2Y}" fill="#9ca3af" font-size="19" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[1])}</text>` : ""}
        ${descLines[2] ? `<text x="40" y="${descLine3Y}" fill="#9ca3af" font-size="19" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[2])}</text>` : ""}

        <!-- Bottom Pill Container: Link Icon, URL, Truthworld > -->
        <g transform="translate(40, 584)">
          <!-- Pill Box -->
          <rect x="0" y="0" width="944" height="60" rx="14" fill="#0f1012" stroke="#27272a" stroke-width="1.2"/>

          <!-- Link Chain Icon -->
          <g transform="translate(20, 16)">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>
          </g>

          <!-- Clean URL Text -->
          <text x="64" y="38" fill="#ffffff" font-size="20" font-weight="500" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(cleanUrl)}</text>

          <!-- Truthworld > -->
          <text x="820" y="38" fill="#8e8e93" font-size="18" font-weight="500" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">Truthworld</text>
          <path d="M912 28 L918 35 L912 42" fill="none" stroke="#8e8e93" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
        </g>
      </g>
    </svg>
  `;

  const finalBuffer = await sharp(Buffer.from(svgContent)).png().toBuffer();
  setToCache(cacheKey, finalBuffer);
  return finalBuffer;
}
