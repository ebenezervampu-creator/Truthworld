import sharp from "sharp";
import { safeFetchImageBuffer } from "./safeImageFetcher";
import { initSeoFontConfig, TW_PREVIEW_FONT_FAMILY } from "./fontConfig";

export interface PlaylistCardData {
  playlistName: string;
  channelName?: string;
  videoCount?: number;
  thumbnailUrl?: string;
  description?: string;
  playlistId?: string;
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

export function formatVideoCount(count?: number): string {
  if (typeof count !== "number" || count <= 0) return "0 videos";
  if (count === 1) return "1 video";
  if (count >= 1000000) {
    return (count / 1000000).toFixed(1).replace(/\.0$/, "") + "M videos";
  }
  if (count >= 1000) {
    return (count / 1000).toFixed(1).replace(/\.0$/, "") + "K videos";
  }
  return `${count} videos`;
}

export function wrapTextToLines(text?: string, maxCharsPerLine: number = 56, maxLines: number = 2): string[] {
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

// In-memory cache to prevent re-rendering identical cards for crawlers
interface CachedImage {
  buffer: Buffer;
  expiresAt: number;
}
const playlistCardCache = new Map<string, CachedImage>();
const CACHE_TTL_MS = 3600 * 1000; // 1 hour
const MAX_CACHE_ENTRIES = 500;

function getFromCache(key: string): Buffer | null {
  const item = playlistCardCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiresAt) {
    playlistCardCache.delete(key);
    return null;
  }
  return item.buffer;
}

function setToCache(key: string, buffer: Buffer): void {
  if (playlistCardCache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = playlistCardCache.keys().next().value;
    if (oldestKey) playlistCardCache.delete(oldestKey);
  }
  playlistCardCache.set(key, { buffer, expiresAt: Date.now() + CACHE_TTL_MS });
}

/**
 * Renders a high-fidelity 1024x848 social share preview card matching Truthworld architecture:
 * - Exact 16:9 uncropped thumbnail at top (1024x576)
 * - Signature vertical playlist overlay bar on right edge of thumbnail (showing count & stacked lines icon)
 * - Dark #161719 card body with rounded corners
 * - Header row: [PLAYLIST] pill badge + creator channel name
 * - Bold white Title (up to 2 lines, e.g. "Watch Later")
 * - Subtitle / video count: "Playlist • 3 videos" (muted grey #8e8e93)
 * - Truthworld footer with link icon & chevron >
 */
export async function renderPlaylistCardImage(data: PlaylistCardData): Promise<Buffer> {
  initSeoFontConfig();

  const cacheKey = `${data.playlistId || ""}_${data.playlistName}_${data.channelName || ""}_${data.videoCount || 0}_${(data.thumbnailUrl || "").slice(-25)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 1024;
  const thumbnailHeight = 576; // 16:9 widescreen
  const height = 848;

  let rawTitle = (data.playlistName || "Truthworld Playlist").trim();
  if (rawTitle.toLowerCase().startsWith("untitled")) {
    rawTitle = "Truthworld Playlist";
  }

  const channelName = (data.channelName || "").trim();
  const videoCount = typeof data.videoCount === "number" ? Math.max(0, data.videoCount) : 0;
  const countStr = videoCount.toString();
  const subtitleStr = `Playlist • ${formatVideoCount(videoCount)}`;

  const titleLines = wrapTextToLines(rawTitle, 54, 2);

  // 1. Fetch & process Thumbnail safely with SSRF defense
  let thumbnailBuffer: Buffer | null = null;
  if (data.thumbnailUrl) {
    try {
      const rawThumb = await safeFetchImageBuffer(
        data.thumbnailUrl,
        "Truthworld-Playlist-Card-Renderer/1.0",
        4000
      );
      if (rawThumb) {
        thumbnailBuffer = await sharp(rawThumb)
          .resize(width, thumbnailHeight, {
            fit: "contain",
            background: "#000000",
          })
          .png()
          .toBuffer();
      }
    } catch (_) {
      // Fallback to gradient thumbnail
    }
  }

  const thumbBase64 = thumbnailBuffer
    ? `data:image/png;base64,${thumbnailBuffer.toString("base64")}`
    : "";

  // Fallback thumbnail SVG markup
  const fallbackThumbSvg = `
    <defs>
      <linearGradient id="twPlaylistGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#180429"/>
        <stop offset="50%" stop-color="#2a0d4a"/>
        <stop offset="100%" stop-color="#0a0014"/>
      </linearGradient>
    </defs>
    <rect x="0" y="0" width="${width}" height="${thumbnailHeight}" fill="url(#twPlaylistGrad)"/>
    <g transform="translate(${width / 2 - 36}, ${thumbnailHeight / 2 - 36})">
      <circle cx="36" cy="36" r="36" fill="rgba(255,255,255,0.12)"/>
      <rect x="22" y="22" width="28" height="3.5" rx="1.5" fill="#ffffff"/>
      <rect x="22" y="30" width="28" height="3.5" rx="1.5" fill="#ffffff"/>
      <rect x="22" y="38" width="18" height="3.5" rx="1.5" fill="#ffffff"/>
      <polygon points="44,35 52,40 44,45" fill="#ffffff"/>
    </g>
    <text x="${width / 2}" y="${thumbnailHeight / 2 + 75}" fill="rgba(255,255,255,0.22)" font-size="28" font-weight="bold" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="3">TRUTHWORLD PLAYLIST</text>
  `;

  // Overlay bar on right side of thumbnail (Image 2 signature element)
  const overlayBarWidth = 130;
  const overlayBarX = width - overlayBarWidth;
  const overlayCenterX = overlayBarX + overlayBarWidth / 2;

  // Dynamic vertical positions
  const hasTwoTitleLines = titleLines.length > 1;
  const headerY = 624;
  const titleY1 = hasTwoTitleLines ? 662 : 674;
  const titleY2 = 702;
  const subtitleY = hasTwoTitleLines ? 738 : 714;
  const dividerY = hasTwoTitleLines ? 764 : 748;
  const footerY = hasTwoTitleLines ? 802 : 790;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <defs>
        <clipPath id="playlistCardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="24" ry="24"/>
        </clipPath>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#playlistCardClip)">
        <!-- Solid Dark Background (#161719 matching Truthworld share architecture) -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Thumbnail (Exact 16:9 Widescreen, Uncropped) -->
        ${thumbBase64 ? `<image href="${thumbBase64}" xlink:href="${thumbBase64}" x="0" y="0" width="${width}" height="${thumbnailHeight}" preserveAspectRatio="xMidYMid meet"/>` : fallbackThumbSvg}

        <!-- Signature Right-Side Playlist Overlay Bar (Image 2) -->
        <rect x="${overlayBarX}" y="0" width="${overlayBarWidth}" height="${thumbnailHeight}" fill="rgba(16, 17, 25, 0.82)"/>
        <line x1="${overlayBarX}" y1="0" x2="${overlayBarX}" y2="${thumbnailHeight}" stroke="rgba(255,255,255,0.12)" stroke-width="1"/>

        <!-- Overlay Bar Content: Video Count Number + Stacked Playlist Icon (Image 2) -->
        <text x="${overlayCenterX}" y="278" fill="#ffffff" font-size="44" font-weight="800" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="-0.5">${escapeXml(countStr)}</text>
        <g transform="translate(${overlayCenterX - 18}, 304)">
          <rect x="0" y="0" width="36" height="4" rx="2" fill="#ffffff"/>
          <rect x="0" y="9" width="36" height="4" rx="2" fill="#ffffff"/>
          <rect x="0" y="18" width="22" height="4" rx="2" fill="#ffffff"/>
          <polygon points="28,15 39,21 28,27" fill="#ffffff"/>
        </g>

        <!-- Seam line divider between thumbnail and text container -->
        <rect x="0" y="${thumbnailHeight}" width="${width}" height="1" fill="#27272a" opacity="0.6"/>

        <!-- Header Row: [PLAYLIST] pill badge + Channel/Creator Name (Image 2) -->
        <g transform="translate(44, ${headerY - 20})">
          <!-- [PLAYLIST] pill badge -->
          <rect x="0" y="0" width="92" height="28" rx="4" fill="rgba(255,255,255,0.12)"/>
          <text x="46" y="19" fill="#ffffff" font-size="12" font-weight="800" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="0.8">PLAYLIST</text>

          <!-- Channel / Creator Name -->
          ${channelName ? `<text x="108" y="20" fill="#8e8e93" font-size="20" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(channelName)}</text>` : ""}
        </g>

        <!-- Playlist Title (Bold, White, up to 2 lines - Image 2) -->
        ${titleLines[0] ? `<text x="44" y="${titleY1}" fill="#ffffff" font-size="30" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(titleLines[0])}</text>` : ""}
        ${titleLines[1] ? `<text x="44" y="${titleY2}" fill="#ffffff" font-size="30" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(titleLines[1])}</text>` : ""}

        <!-- Subtitle: "Playlist • X videos" (Image 2) -->
        <text x="44" y="${subtitleY}" fill="#8e8e93" font-size="21" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(subtitleStr)}</text>

        <!-- Footer Divider Line (Image 2) -->
        <line x1="44" y1="${dividerY}" x2="${width - 44}" y2="${dividerY}" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>

        <!-- Footer: Link Icon + Truthworld + Chevron > (Image 2) -->
        <g transform="translate(44, ${footerY - 18})">
          <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
          <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
        </g>
        <text x="82" y="${footerY}" fill="#ffffff" font-size="22" font-weight="600" font-family="${TW_PREVIEW_FONT_FAMILY}" letter-spacing="-0.2">Truthworld</text>

        <!-- Chevron > on far right -->
        <g transform="translate(${width - 64}, ${footerY - 15})">
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
