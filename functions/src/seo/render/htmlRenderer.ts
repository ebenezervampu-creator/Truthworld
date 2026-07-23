import { DOMAIN, SCHEMA_VERSION, escapeHtml, cleanJsonLd } from "../schema/schemaConfig";

export const SNAPSHOT_VERSION = 1;

export interface HtmlRenderOptions {
  title: string;
  description: string;
  url: string;
  image?: string;
  type?: string;
  robots?: string;
  jsonLd?: any[];
  breadcrumbHtml?: string;
  // Content payload for crawler SSR body
  contentHeading?: string;
  authorName?: string;
  authorUrl?: string;
  transcriptExcerpt?: string;
  relatedItems?: Array<{ title: string; url: string }>;
  topicItems?: Array<{ title: string; url: string }>;
}

export function truncateTranscriptToSentence(transcript?: string, maxChars: number = 2500): string {
  if (!transcript || transcript.length <= maxChars) {
    return transcript || "";
  }
  const truncated = transcript.substring(0, maxChars);
  // Find last sentence end boundary (. ! ?)
  const lastSentenceEnd = Math.max(
    truncated.lastIndexOf("."),
    truncated.lastIndexOf("!"),
    truncated.lastIndexOf("?")
  );
  if (lastSentenceEnd > 500) {
    return truncated.substring(0, lastSentenceEnd + 1);
  }
  return truncated + "...";
}

export function buildSemanticSsrHtml(options: HtmlRenderOptions): string {
  const robotsDirective = options.robots || "index, follow";
  const image = options.image || `${DOMAIN}/icons/og-image.png`;
  const canonicalUrl = options.url || DOMAIN;

  // Build JSON-LD blocks
  let jsonLdScriptTags = "";
  if (options.jsonLd) {
    const cleanedLd = cleanJsonLd(options.jsonLd);
    if (cleanedLd) {
      const blocks = Array.isArray(cleanedLd) ? cleanedLd : [cleanedLd];
      for (const block of blocks) {
        jsonLdScriptTags += `<script type="application/ld+json">\n${JSON.stringify(block, null, 2)}\n</script>\n  `;
      }
    }
  }

  // Alternate hreflang tags
  const supportedLangs = ["en", "hi", "te", "ta", "kn"];
  let hreflangTags = "";
  for (const lang of supportedLangs) {
    hreflangTags += `<link rel="alternate" hreflang="${lang}" href="${canonicalUrl}" />\n  `;
  }

  // Header meta tags
  const headMetaTags = `
  <title>${escapeHtml(options.title)}</title>
  <meta name="description" content="${escapeHtml(options.description)}" />
  <meta name="robots" content="${robotsDirective}" />
  <meta name="googlebot" content="${robotsDirective}" />
  <link rel="canonical" href="${canonicalUrl}" />
  <link rel="alternate" hreflang="x-default" href="${canonicalUrl}" />
  ${hreflangTags}
  <meta property="og:site_name" content="Truthworld" />
  <meta property="og:type" content="${options.type || "website"}" />
  <meta property="og:url" content="${canonicalUrl}" />
  <meta property="og:title" content="${escapeHtml(options.title)}" />
  <meta property="og:description" content="${escapeHtml(options.description)}" />
  <meta property="og:image" content="${image}" />
  <meta property="og:image:secure_url" content="${image}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:image:alt" content="${escapeHtml(options.title)}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:site" content="@truthworld" />
  <meta name="twitter:title" content="${escapeHtml(options.title)}" />
  <meta name="twitter:description" content="${escapeHtml(options.description)}" />
  <meta name="twitter:image" content="${image}" />
  <meta name="twitter:image:alt" content="${escapeHtml(options.title)}" />
  ${jsonLdScriptTags}
  `;

  // Semantic Body Markup for Crawlers before Flutter hydrates
  const headingText = options.contentHeading || options.title;
  const transcriptExcerpt = truncateTranscriptToSentence(options.transcriptExcerpt);

  let relatedLinksHtml = "";
  if (options.relatedItems && options.relatedItems.length > 0) {
    relatedLinksHtml += `<aside class="tw-related-videos" style="margin-top: 24px; padding: 16px; background: #12011f; border-radius: 8px;">\n`;
    relatedLinksHtml += `  <h3 style="color: #e4e4e7; font-size: 18px; margin-bottom: 12px;">Related Videos & Content</h3>\n`;
    relatedLinksHtml += `  <ul style="list-style: none; padding: 0; margin: 0;">\n`;
    for (const item of options.relatedItems) {
      relatedLinksHtml += `    <li style="margin-bottom: 8px;"><a href="${escapeHtml(item.url)}" style="color: #c084fc; text-decoration: none;">${escapeHtml(item.title)}</a></li>\n`;
    }
    relatedLinksHtml += `  </ul>\n</aside>\n`;
  }

  let topicLinksHtml = "";
  if (options.topicItems && options.topicItems.length > 0) {
    topicLinksHtml += `<nav class="tw-topics" style="margin-top: 16px;">\n`;
    topicLinksHtml += `  <h4 style="color: #a1a1aa; font-size: 14px;">Topics:</h4>\n  <ul style="display: flex; gap: 8px; list-style: none; padding: 0; margin: 8px 0;">\n`;
    for (const top of options.topicItems) {
      topicLinksHtml += `    <li><a href="${escapeHtml(top.url)}" style="background: #27272a; color: #f4f4f5; padding: 4px 10px; border-radius: 16px; font-size: 12px; text-decoration: none;">${escapeHtml(top.title)}</a></li>\n`;
    }
    topicLinksHtml += `  </ul>\n</nav>\n`;
  }

  let authorHtml = "";
  if (options.authorName && options.authorUrl) {
    authorHtml = `<div class="tw-author" style="margin: 12px 0; color: #a1a1aa;">Published by <a href="${escapeHtml(options.authorUrl)}" style="color: #9B30FF; font-weight: 500; text-decoration: none;">${escapeHtml(options.authorName)}</a></div>\n`;
  }

  let transcriptHtml = "";
  if (transcriptExcerpt) {
    transcriptHtml = `
  <section class="tw-transcript" style="margin-top: 24px; padding: 16px; background: #18181b; border-radius: 8px; color: #d4d4d8;">
    <h3 style="color: #f4f4f5; font-size: 16px; margin-bottom: 8px;">Video Transcript Excerpt</h3>
    <p style="line-height: 1.6; font-size: 14px;">${escapeHtml(transcriptExcerpt)}</p>
  </section>`;
  }

  const semanticBodyHtml = `
  <!-- Truthworld SEO Snapshot | Schema Version: ${SCHEMA_VERSION} | Snapshot Version: ${SNAPSHOT_VERSION} -->
  <header style="padding: 16px; background: #090011; border-bottom: 1px solid #27272a; display: flex; justify-content: space-between; align-items: center;">
    <a href="${DOMAIN}" style="font-size: 20px; font-weight: bold; color: #9B30FF; text-decoration: none;">Truthworld</a>
    <a href="${DOMAIN}/search" style="color: #a1a1aa; text-decoration: none; font-size: 14px;">Search</a>
  </header>

  ${options.breadcrumbHtml || ""}

  <main style="max-width: 1000px; margin: 0 auto; padding: 16px; color: #f4f4f5; font-family: Roboto, sans-serif;">
    <article>
      <h1 style="font-size: 24px; font-weight: bold; line-height: 1.3; color: #ffffff;">${escapeHtml(headingText)}</h1>
      ${authorHtml}
      <p style="margin-top: 12px; line-height: 1.5; color: #d4d4d8; font-size: 15px;">${escapeHtml(options.description)}</p>
      ${topicLinksHtml}
      ${transcriptHtml}
    </article>
    ${relatedLinksHtml}
  </main>

  <footer style="margin-top: 48px; padding: 24px 16px; border-top: 1px solid #27272a; text-align: center; color: #71717a; font-size: 13px;">
    <p>&copy; ${new Date().getFullYear()} Truthworld. All rights reserved. Verify before you share.</p>
  </footer>
  `;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <base href="/" />
  ${headMetaTags}
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="theme-color" content="#9B30FF" />
  <link rel="icon" type="image/png" href="favicon.png" />
  <link rel="apple-touch-icon" href="icons/Icon-192.png" />
  <link rel="manifest" href="manifest.json" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: #0D0014; color: #f4f4f5; }
  </style>
</head>
<body>
  ${semanticBodyHtml}
  <!-- Flutter bootstrap -->
  <script src="flutter_bootstrap.js"></script>
</body>
</html>`;
}
