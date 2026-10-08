import sharp from "sharp";
import axios from "axios";

export interface VideoCardData {
  title: string;
  thumbnailUrl?: string;
  description?: string;
  channelName?: string;
  durationMs?: number;
  videoId?: string;
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

export function wrapTextToLines(text?: string, maxCharsPerLine: number = 58, maxLines: number = 2): string[] {
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
const videoCardCache = new Map<string, CachedImage>();
const CACHE_TTL_MS = 3600 * 1000; // 1 hour
const MAX_CACHE_ENTRIES = 500;

function getFromCache(key: string): Buffer | null {
  const item = videoCardCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiresAt) {
    videoCardCache.delete(key);
    return null;
  }
  return item.buffer;
}

function setToCache(key: string, buffer: Buffer): void {
  if (videoCardCache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = videoCardCache.keys().next().value;
    if (oldestKey) videoCardCache.delete(oldestKey);
  }
  videoCardCache.set(key, { buffer, expiresAt: Date.now() + CACHE_TTL_MS });
}

/**
 * Renders a high-fidelity 1024x780 social share preview card matching the Truthworld architecture:
 * - Exact 16:9 uncropped thumbnail at top (1024x576)
 * - Dark #161719 card body below
 * - Bold white Title (up to 2 lines)
 * - Muted grey Description (up to 2 lines, truncated with ...)
 * - "Truthworld" at the bottom
 */
export async function renderVideoCardImage(data: VideoCardData): Promise<Buffer> {
  const cacheKey = `${data.videoId || ""}_${data.title}_${(data.thumbnailUrl || "").slice(-25)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 1024;
  const thumbnailHeight = 576; // Exact 16:9 aspect ratio: 1024 * (9 / 16) = 576
  const bottomHeight = 204;
  const height = thumbnailHeight + bottomHeight; // 780px

  const title = (data.title || "Truthworld Video").trim();
  const rawDesc = (data.description || "").trim();
  const titleLines = wrapTextToLines(title, 56, 2);
  const descLines = wrapTextToLines(
    rawDesc || "Watch verified, family-safe video with epistemic clarity on Truthworld.",
    68,
    2
  );

  // 1. Fetch & process Thumbnail without losing any part (fit: contain / cover with 16:9)
  let thumbnailBuffer: Buffer | null = null;
  if (data.thumbnailUrl) {
    try {
      const resp = await axios.get(data.thumbnailUrl, {
        responseType: "arraybuffer",
        timeout: 4000,
        headers: { "User-Agent": "Truthworld-Video-Card-Renderer/1.0" },
      });
      thumbnailBuffer = await sharp(resp.data)
        .resize(width, thumbnailHeight, {
          fit: "contain",
          background: "#000000",
        })
        .png()
        .toBuffer();
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
      <linearGradient id="twVideoGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#19042b"/>
        <stop offset="50%" stop-color="#2a0a4a"/>
        <stop offset="100%" stop-color="#0a0014"/>
      </linearGradient>
    </defs>
    <rect x="0" y="0" width="${width}" height="${thumbnailHeight}" fill="url(#twVideoGrad)"/>
    <g transform="translate(${width / 2 - 40}, ${thumbnailHeight / 2 - 40})">
      <circle cx="40" cy="40" r="40" fill="rgba(255,255,255,0.12)"/>
      <polygon points="32,24 58,40 32,56" fill="#ffffff"/>
    </g>
    <text x="${width / 2}" y="${thumbnailHeight / 2 + 75}" fill="rgba(255,255,255,0.22)" font-size="28" font-weight="bold" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" text-anchor="middle" letter-spacing="3">TRUTHWORLD VIDEO</text>
  `;

  // Calculate dynamic text baseline positions
  const titleY1 = 618;
  const titleY2 = 654;
  const hasTwoTitleLines = titleLines.length > 1;
  const descY1 = hasTwoTitleLines ? 692 : 668;
  const descY2 = hasTwoTitleLines ? 722 : 698;
  const footerY = 754;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <clipPath id="videoCardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="24" ry="24"/>
        </clipPath>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#videoCardClip)">
        <!-- Solid Dark Background -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Thumbnail (Exact 16:9 Widescreen, No Cropping) -->
        ${thumbBase64 ? `<image href="${thumbBase64}" x="0" y="0" width="${width}" height="${thumbnailHeight}" preserveAspectRatio="xMidYMid meet"/>` : fallbackThumbSvg}

        <!-- Seam line divider between thumbnail and text container -->
        <rect x="0" y="${thumbnailHeight}" width="${width}" height="1" fill="#27272a" opacity="0.6"/>

        <!-- Title Line 1 -->
        ${titleLines[0] ? `<text x="36" y="${titleY1}" fill="#ffffff" font-size="28" font-weight="700" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(titleLines[0])}</text>` : ""}

        <!-- Title Line 2 -->
        ${titleLines[1] ? `<text x="36" y="${titleY2}" fill="#ffffff" font-size="28" font-weight="700" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(titleLines[1])}</text>` : ""}

        <!-- Two lines of description -->
        ${descLines[0] ? `<text x="36" y="${descY1}" fill="#9ca3af" font-size="20" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[0])}</text>` : ""}
        ${descLines[1] ? `<text x="36" y="${descY2}" fill="#9ca3af" font-size="20" font-weight="400" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">${escapeXml(descLines[1])}</text>` : ""}

        <!-- Bottom Line: Truthworld -->
        <text x="36" y="${footerY}" fill="#e4e6eb" font-size="20" font-weight="600" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" letter-spacing="-0.2">Truthworld</text>
      </g>
    </svg>
  `;

  const finalBuffer = await sharp(Buffer.from(svgContent)).png().toBuffer();
  setToCache(cacheKey, finalBuffer);
  return finalBuffer;
}
