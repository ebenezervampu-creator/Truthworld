import sharp from "sharp";
import { safeFetchImageBuffer } from "./safeImageFetcher";
import { initSeoFontConfig, TW_PREVIEW_FONT_FAMILY } from "./fontConfig";

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

export function formatDurationMs(durationMs?: number): string {
  if (!durationMs || durationMs <= 0 || !isFinite(durationMs)) return "";
  const totalSeconds = Math.floor(durationMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  }
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
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
 * Renders a high-fidelity 1024x848 social share preview card matching Truthworld architecture:
 * - Exact 16:9 uncropped thumbnail at top (1024x576) with duration overlay badge
 * - Dark #161719 card body with rounded corners
 * - Header row: [VIDEO] pill badge + creator channel name
 * - Bold white Title (up to 2 lines)
 * - Muted grey Description (up to 2 lines, default: "Watch family-safe, verified video with epistemic clarity on Truthworld.")
 * - Truthworld footer with link icon & chevron >
 */
export async function renderVideoCardImage(data: VideoCardData): Promise<Buffer> {
  initSeoFontConfig();

  const cacheKey = `${data.videoId || ""}_${data.title}_${data.channelName || ""}_${data.durationMs || 0}_${(data.thumbnailUrl || "").slice(-25)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 1024;
  const thumbnailHeight = 576; // Exact 16:9 aspect ratio: 1024 * (9 / 16) = 576
  const height = 848;

  let rawTitle = (data.title || "Truthworld Video").trim();
  if (rawTitle.toLowerCase().startsWith("uploading") || rawTitle.toLowerCase() === "untitled video") {
    rawTitle = "Truthworld Video";
  }

  let rawDesc = (data.description || "").trim();
  const isJunkDesc = !rawDesc ||
    rawDesc.toLowerCase().startsWith("processing") ||
    rawDesc.toLowerCase().startsWith("uploading") ||
    rawDesc.toLowerCase() === "description";

  const effectiveDesc = isJunkDesc
    ? "Watch family-safe, verified video with epistemic clarity on Truthworld."
    : rawDesc;

  const channelName = (data.channelName || "").trim();
  const durationStr = formatDurationMs(data.durationMs);
  const durationBadgeWidth = durationStr ? Math.max(54, durationStr.length * 11 + 16) : 0;

  const titleLines = wrapTextToLines(rawTitle, 56, 2);
  const descLines = wrapTextToLines(effectiveDesc, 68, 2);

  // 1. Fetch & process Thumbnail safely with SSRF defense (fit: contain / cover with 16:9)
  let thumbnailBuffer: Buffer | null = null;
  if (data.thumbnailUrl) {
    try {
      const rawThumb = await safeFetchImageBuffer(
        data.thumbnailUrl,
        "Truthworld-Video-Card-Renderer/1.0",
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
    <text x="${width / 2}" y="${thumbnailHeight / 2 + 75}" fill="rgba(255,255,255,0.22)" font-size="28" font-weight="bold" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="3">TRUTHWORLD VIDEO</text>
  `;

  // Dynamic vertical baseline positions
  const hasTwoTitleLines = titleLines.length > 1;
  const titleY1 = 654;
  const titleY2 = 690;
  const descY1 = hasTwoTitleLines ? 726 : 692;
  const descY2 = hasTwoTitleLines ? 754 : 720;
  const dividerY = hasTwoTitleLines ? 784 : 750;
  const footerY = hasTwoTitleLines ? 816 : 782;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <defs>
        <clipPath id="videoCardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="24" ry="24"/>
        </clipPath>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#videoCardClip)">
        <!-- Solid Dark Background (#161719 matching Truthworld share architecture) -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Thumbnail (Exact 16:9 Widescreen, Uncropped) -->
        ${thumbBase64 ? `<image href="${thumbBase64}" xlink:href="${thumbBase64}" x="0" y="0" width="${width}" height="${thumbnailHeight}" preserveAspectRatio="xMidYMid meet"/>` : fallbackThumbSvg}

        <!-- Duration Badge overlay on bottom-right of thumbnail (Image 2) -->
        ${durationStr ? `
        <g transform="translate(${width - durationBadgeWidth - 20}, ${thumbnailHeight - 44})">
          <rect x="0" y="0" width="${durationBadgeWidth}" height="30" rx="5" fill="rgba(0,0,0,0.85)" stroke="rgba(255,255,255,0.18)" stroke-width="0.8"/>
          <text x="${durationBadgeWidth / 2}" y="21" fill="#ffffff" font-size="16" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="0.4">${escapeXml(durationStr)}</text>
        </g>` : ""}

        <!-- Seam line divider between thumbnail and text container -->
        <rect x="0" y="${thumbnailHeight}" width="${width}" height="1" fill="#27272a" opacity="0.6"/>

        <!-- Header Row: [VIDEO] pill badge + Channel Name (Image 2) -->
        <g transform="translate(36, 600)">
          <!-- [VIDEO] pill badge -->
          <rect x="0" y="0" width="64" height="26" rx="4" fill="rgba(255,255,255,0.12)"/>
          <text x="32" y="18" fill="#ffffff" font-size="12" font-weight="800" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="0.8">VIDEO</text>

          <!-- Channel Name -->
          ${channelName ? `<text x="76" y="19" fill="#8e8e93" font-size="19" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(channelName)}</text>` : ""}
        </g>

        <!-- Video Title (Bold, White, up to 2 lines - Image 2) -->
        ${titleLines[0] ? `<text x="36" y="${titleY1}" fill="#ffffff" font-size="28" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(titleLines[0])}</text>` : ""}
        ${titleLines[1] ? `<text x="36" y="${titleY2}" fill="#ffffff" font-size="28" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(titleLines[1])}</text>` : ""}

        <!-- Video Description (Muted grey, up to 2 lines - Image 2) -->
        ${descLines[0] ? `<text x="36" y="${descY1}" fill="#9ca3af" font-size="20" font-weight="400" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(descLines[0])}</text>` : ""}
        ${descLines[1] ? `<text x="36" y="${descY2}" fill="#9ca3af" font-size="20" font-weight="400" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(descLines[1])}</text>` : ""}

        <!-- Footer Divider Line (Image 2) -->
        <line x1="36" y1="${dividerY}" x2="${width - 36}" y2="${dividerY}" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>

        <!-- Footer: Link Icon + Truthworld + Chevron > (Image 2) -->
        <g transform="translate(36, ${footerY - 18})">
          <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
          <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
        </g>
        <text x="74" y="${footerY}" fill="#ffffff" font-size="22" font-weight="600" font-family="${TW_PREVIEW_FONT_FAMILY}" letter-spacing="-0.2">Truthworld</text>

        <!-- Chevron > on far right -->
        <g transform="translate(${width - 56}, ${footerY - 15})">
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
