import sharp from "sharp";
import { safeFetchImageBuffer } from "./safeImageFetcher";
import { initSeoFontConfig, TW_PREVIEW_FONT_FAMILY } from "./fontConfig";

export interface ClaimCardData {
  claimText: string;
  verdictLabel?: string;
  verdictColor?: string;
  summaryTakeaway?: string;
  confidenceText?: string;
  primarySourceDomain?: string;
  videoTitle?: string;
  thumbnailUrl?: string;
  channelName?: string;
  videoId?: string;
  claimIndex?: number;
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

export function wrapTextToLines(text?: string, maxCharsPerLine: number = 54, maxLines: number = 3): string[] {
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

export function resolveVerdictColor(verdict?: string): { color: string; bg: string; border: string; label: string } {
  const v = (verdict || "").toUpperCase().trim();
  if (v.includes("TRUE") || v.includes("VERIFIED") || v.includes("CORRECT") || v.includes("ACCURATE")) {
    return {
      color: "#10b981",
      bg: "rgba(16, 185, 129, 0.16)",
      border: "rgba(16, 185, 129, 0.4)",
      label: v || "VERIFIED TRUE",
    };
  }
  if (v.includes("FALSE") || v.includes("DEBUNKED") || v.includes("INCORRECT") || v.includes("FAKE")) {
    return {
      color: "#ef4444",
      bg: "rgba(239, 68, 68, 0.16)",
      border: "rgba(239, 68, 68, 0.4)",
      label: v || "FALSE CLAIM",
    };
  }
  return {
    color: "#f59e0b",
    bg: "rgba(245, 158, 11, 0.16)",
    border: "rgba(245, 158, 11, 0.4)",
    label: v || "CAUTION",
  };
}

// In-memory cache to prevent re-rendering identical cards for crawlers
interface CachedImage {
  buffer: Buffer;
  expiresAt: number;
}
const claimCardCache = new Map<string, CachedImage>();
const CACHE_TTL_MS = 3600 * 1000; // 1 hour
const MAX_CACHE_ENTRIES = 500;

function getFromCache(key: string): Buffer | null {
  const item = claimCardCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiresAt) {
    claimCardCache.delete(key);
    return null;
  }
  return item.buffer;
}

function setToCache(key: string, buffer: Buffer): void {
  if (claimCardCache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = claimCardCache.keys().next().value;
    if (oldestKey) claimCardCache.delete(oldestKey);
  }
  claimCardCache.set(key, { buffer, expiresAt: Date.now() + CACHE_TTL_MS });
}

/**
 * Renders a high-fidelity 1024x848 social share preview card for a fact-checked claim
 * matching Truthworld architecture:
 * - 16:9 thumbnail at top (1024x440) with [FACT CHECK] and verdict pill overlays
 * - Video context title / Channel name
 * - Quotation styling for the claim statement (bold white text)
 * - Takeaway card with verdict explanation, confidence, and primary source domain
 * - Truthworld Fact Check footer with link icon & chevron
 */
export async function renderClaimCardImage(data: ClaimCardData): Promise<Buffer> {
  initSeoFontConfig();

  const cacheKey = `${data.videoId || ""}_${data.claimIndex ?? 0}_${data.claimText.slice(0, 30)}_${data.verdictLabel || ""}_${(data.thumbnailUrl || "").slice(-25)}`;
  const cached = getFromCache(cacheKey);
  if (cached) return cached;

  const width = 1024;
  const thumbnailHeight = 440;
  const height = 848;

  const rawClaim = (data.claimText || "Truthworld Fact Check Claim").trim();
  const claimLines = wrapTextToLines(rawClaim, 52, 2);

  const videoTitle = (data.videoTitle || data.channelName || "Truthworld Video Fact Check").trim();
  const videoTitleLines = wrapTextToLines(videoTitle, 65, 1);

  const verdict = resolveVerdictColor(data.verdictLabel);
  const effectiveColor = data.verdictColor || verdict.color;
  const effectiveLabel = verdict.label;

  const takeaway = (data.summaryTakeaway || "Verified through authoritative documentation and institutional records.").trim();
  const takeawayLines = wrapTextToLines(takeaway, 64, 2);

  const hasConfidence = Boolean(data.confidenceText && data.confidenceText.trim().length > 0);
  const confidenceStr = hasConfidence ? `Confidence: ${data.confidenceText!.trim()}` : "";
  const sourceStr = (data.primarySourceDomain || "").trim();

  // 1. Fetch & process Thumbnail safely with SSRF defense
  let thumbnailBuffer: Buffer | null = null;
  if (data.thumbnailUrl) {
    try {
      const rawThumb = await safeFetchImageBuffer(
        data.thumbnailUrl,
        "Truthworld-Claim-Card-Renderer/1.0",
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
      <linearGradient id="twClaimGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#140a24"/>
        <stop offset="50%" stop-color="#1f1035"/>
        <stop offset="100%" stop-color="#0a0014"/>
      </linearGradient>
    </defs>
    <rect x="0" y="0" width="${width}" height="${thumbnailHeight}" fill="url(#twClaimGrad)"/>
    <g transform="translate(${width / 2 - 36}, ${thumbnailHeight / 2 - 40})">
      <circle cx="36" cy="36" r="36" fill="rgba(255,255,255,0.12)"/>
      <path d="M36 18 L48 24 L48 38 C48 48 36 54 36 54 C36 54 24 48 24 38 L24 24 Z" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linejoin="round"/>
    </g>
    <text x="${width / 2}" y="${thumbnailHeight / 2 + 56}" fill="rgba(255,255,255,0.25)" font-size="24" font-weight="bold" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="3">TRUTHWORLD FACT CHECK</text>
  `;

  // Calculated vertical positions
  const contextY = 478;
  const quoteY = 514;
  const claimY1 = 516;
  const claimY2 = 552;
  const hasTwoClaimLines = claimLines.length > 1;

  const takeawayBoxY = hasTwoClaimLines ? 574 : 544;
  const takeawayBoxHeight = 168;

  const takeawayTextY1 = takeawayBoxY + 36;
  const takeawayTextY2 = takeawayBoxY + 68;
  const takeawayMetaY = takeawayBoxY + 138;
  const takeawayDividerY = takeawayBoxY + 104;

  const dividerY = 762;
  const footerY = 804;

  const svgContent = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      <defs>
        <clipPath id="claimCardClip">
          <rect x="0" y="0" width="${width}" height="${height}" rx="24" ry="24"/>
        </clipPath>
        <linearGradient id="thumbTopOverlay" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="rgba(0,0,0,0.7)"/>
          <stop offset="50%" stop-color="rgba(0,0,0,0)"/>
          <stop offset="100%" stop-color="rgba(0,0,0,0.85)"/>
        </linearGradient>
      </defs>

      <!-- Rounded Card Frame -->
      <g clip-path="url(#claimCardClip)">
        <!-- Solid Dark Background (#161719 matching Truthworld share architecture) -->
        <rect x="0" y="0" width="${width}" height="${height}" fill="#161719"/>

        <!-- Top Thumbnail (Widescreen, Uncropped) -->
        ${thumbBase64 ? `<image href="${thumbBase64}" xlink:href="${thumbBase64}" x="0" y="0" width="${width}" height="${thumbnailHeight}" preserveAspectRatio="xMidYMid meet"/>` : fallbackThumbSvg}

        <!-- Top & Bottom Gradient Shadows for High Contrast readability -->
        <rect x="0" y="0" width="${width}" height="${thumbnailHeight}" fill="url(#thumbTopOverlay)"/>

        <!-- Top Left: [FACT CHECK] Pill Badge -->
        <g transform="translate(36, 24)">
          <rect x="0" y="0" width="112" height="32" rx="6" fill="rgba(0,0,0,0.78)" stroke="rgba(255,255,255,0.25)" stroke-width="1"/>
          <text x="56" y="21" fill="#ffffff" font-size="12" font-weight="800" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="1.2">FACT CHECK</text>
        </g>

        <!-- Top Right: Dynamic Verdict Badge Pill -->
        <g transform="translate(${width - 240}, 24)">
          <rect x="0" y="0" width="204" height="32" rx="6" fill="${verdict.bg}" stroke="${verdict.border}" stroke-width="1.2"/>
          <text x="102" y="21" fill="${effectiveColor}" font-size="13" font-weight="800" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="middle" letter-spacing="0.8">${escapeXml(effectiveLabel)}</text>
        </g>

        <!-- Seam line divider between thumbnail and text container -->
        <rect x="0" y="${thumbnailHeight}" width="${width}" height="1" fill="#27272a" opacity="0.6"/>

        <!-- Video Context Eyebrow / Channel -->
        <text x="44" y="${contextY}" fill="#8e8e93" font-size="17" font-weight="600" font-family="${TW_PREVIEW_FONT_FAMILY}" letter-spacing="0.4">${escapeXml(videoTitleLines[0] || "Truthworld Fact Check")}</text>

        <!-- Quotation Mark Icon + Claim Text (Bold White) -->
        <text x="44" y="${quoteY}" fill="rgba(255,255,255,0.3)" font-size="34" font-weight="900" font-family="Georgia, serif">“</text>
        ${claimLines[0] ? `<text x="76" y="${claimY1}" fill="#ffffff" font-size="26" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(claimLines[0])}</text>` : ""}
        ${claimLines[1] ? `<text x="76" y="${claimY2}" fill="#ffffff" font-size="26" font-weight="700" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(claimLines[1])}</text>` : ""}

        <!-- Verdict Takeaway Card -->
        <g transform="translate(44, ${takeawayBoxY})">
          <rect x="0" y="0" width="${width - 88}" height="${takeawayBoxHeight}" rx="14" fill="#1b1c20" stroke="${verdict.border}" stroke-width="1"/>
        </g>

        <!-- Takeaway Text Lines -->
        ${takeawayLines[0] ? `<text x="68" y="${takeawayTextY1}" fill="#e4e4e7" font-size="19" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(takeawayLines[0])}</text>` : ""}
        ${takeawayLines[1] ? `<text x="68" y="${takeawayTextY2}" fill="#e4e4e7" font-size="19" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(takeawayLines[1])}</text>` : ""}

        <!-- Takeaway Inner Divider -->
        <line x1="68" y1="${takeawayDividerY}" x2="${width - 68}" y2="${takeawayDividerY}" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>

        <!-- Takeaway Meta: Confidence + Source Domain -->
        ${confidenceStr ? `<text x="68" y="${takeawayMetaY}" fill="#8e8e93" font-size="16" font-weight="500" font-family="${TW_PREVIEW_FONT_FAMILY}">${escapeXml(confidenceStr)}</text>` : ""}
        ${sourceStr ? `<text x="${width - 68}" y="${takeawayMetaY}" fill="#60a5fa" font-size="16" font-weight="600" font-family="${TW_PREVIEW_FONT_FAMILY}" text-anchor="end">${escapeXml(sourceStr)}</text>` : ""}

        <!-- Footer Divider Line -->
        <line x1="44" y1="${dividerY}" x2="${width - 44}" y2="${dividerY}" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>

        <!-- Footer: Link Icon + Truthworld Fact Check + Chevron > -->
        <g transform="translate(44, ${footerY - 18})">
          <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
          <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
        </g>
        <text x="82" y="${footerY}" fill="#ffffff" font-size="21" font-weight="600" font-family="${TW_PREVIEW_FONT_FAMILY}" letter-spacing="-0.2">Truthworld Fact Check</text>

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
