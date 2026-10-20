import { DOMAIN, SCHEMA_VERSION, escapeHtml, cleanJsonLd } from "../schema/schemaConfig";

export const SNAPSHOT_VERSION = 7;

export interface HtmlRenderOptions {
  title: string;
  description: string;
  url: string;
  image?: string;
  imageWidth?: number;
  imageHeight?: number;
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
  // Video-specific properties for rich link previews
  videoUrl?: string;
  embedUrl?: string;
  durationSeconds?: number;
  uploadDate?: string;
  // Custom semantic HTML content for rich landing pages
  customBodyHtml?: string;
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
  let rawImage = options.image || `${DOMAIN}/icons/og-image.png?v=2`;
  if (rawImage.startsWith("/")) {
    rawImage = `${DOMAIN}${rawImage}`;
  }
  const image = rawImage;
  const canonicalUrl = options.url || DOMAIN;
  const safeDurationSeconds = typeof options.durationSeconds === "number" && isFinite(options.durationSeconds)
    ? Math.floor(options.durationSeconds) : undefined;

  // Build JSON-LD blocks
  let jsonLdScriptTags = "";
  if (options.jsonLd) {
    const cleanedLd = cleanJsonLd(options.jsonLd);
    if (cleanedLd) {
      const blocks = Array.isArray(cleanedLd) ? cleanedLd : [cleanedLd];
      for (const block of blocks) {
        jsonLdScriptTags += `<script type="application/ld+json">\n${JSON.stringify(block, null, 2).replace(/<\//g, "<\\/")}\n</script>\n  `;
      }
    }
  }

  // Alternate hreflang tags
  const supportedLangs = ["en", "hi", "te", "ta", "kn"];
  let hreflangTags = "";
  for (const lang of supportedLangs) {
    hreflangTags += `<link rel="alternate" hreflang="${lang}" href="${escapeHtml(canonicalUrl)}" />\n  `;
  }

  // Determine image MIME type reliably
  let cleanImagePath = image.split("?")[0].toLowerCase();
  try {
    cleanImagePath = decodeURIComponent(cleanImagePath);
  } catch (_) {}
  const isPng = cleanImagePath.endsWith(".png");
  const isWebp = cleanImagePath.endsWith(".webp");
  const isGif = cleanImagePath.endsWith(".gif");
  const mimeType = isPng ? "image/png" : (isWebp ? "image/webp" : (isGif ? "image/gif" : "image/jpeg"));

  // Standard 16:9 widescreen dimensions (1280x720 for large social cards)
  const isVideo = options.type === "video.other" || !!options.videoUrl || !!options.embedUrl;
  const width = options.imageWidth || 1280;
  const height = options.imageHeight || 720;

  // Video-specific Open Graph and Twitter Player tags for WhatsApp, Telegram, Twitter/X, Facebook
  let videoMetaTags = "";
  if (isVideo) {
    const embed = options.embedUrl || canonicalUrl;
    videoMetaTags = `
  <meta property="og:video" content="${escapeHtml(embed)}" />
  <meta property="og:video:url" content="${escapeHtml(embed)}" />
  <meta property="og:video:secure_url" content="${escapeHtml(embed)}" />
  <meta property="og:video:type" content="text/html" />
  <meta property="og:video:width" content="1280" />
  <meta property="og:video:height" content="720" />
  ${safeDurationSeconds ? `<meta property="video:duration" content="${safeDurationSeconds}" />` : ""}
  ${options.uploadDate ? `<meta property="video:release_date" content="${escapeHtml(options.uploadDate)}" />` : ""}
  <meta name="twitter:player" content="${escapeHtml(embed)}" />
  <meta name="twitter:player:width" content="1280" />
  <meta name="twitter:player:height" content="720" />`;
  }

  // Header meta tags
  const headMetaTags = `
  <title>${escapeHtml(options.title)}</title>
  <meta name="description" content="${escapeHtml(options.description)}" />
  <meta name="robots" content="${escapeHtml(robotsDirective)}" />
  <meta name="googlebot" content="${escapeHtml(robotsDirective)}" />
  <link rel="canonical" href="${escapeHtml(canonicalUrl)}" />
  <link rel="alternate" hreflang="x-default" href="${escapeHtml(canonicalUrl)}" />
  ${hreflangTags}
  <meta property="og:site_name" content="Truthworld" />
  <meta property="og:type" content="${options.type || "website"}" />
  <meta property="og:url" content="${escapeHtml(canonicalUrl)}" />
  <meta property="og:title" content="${escapeHtml(options.title)}" />
  <meta property="og:description" content="${escapeHtml(options.description)}" />
  <meta property="og:image" content="${escapeHtml(image)}" />
  <meta property="og:image:secure_url" content="${escapeHtml(image)}" />
  <meta property="og:image:type" content="${mimeType}" />
  <meta property="og:image:width" content="${width}" />
  <meta property="og:image:height" content="${height}" />
  <meta property="og:image:alt" content="${escapeHtml(options.title)}" />
  <link rel="image_src" href="${escapeHtml(image)}" />${videoMetaTags}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:site" content="@truthworld" />
  <meta name="twitter:title" content="${escapeHtml(options.title)}" />
  <meta name="twitter:description" content="${escapeHtml(options.description)}" />
  <meta name="twitter:image" content="${escapeHtml(image)}" />
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

  // Video player above the fold for Google Video Indexing prominence
  let videoPlayerHtml = "";
  if (isVideo) {
    const poster = image;
    const mediaSource = options.videoUrl;
    const isHls = mediaSource ? (mediaSource.includes(".m3u8") || mediaSource.includes("hls")) : false;
    videoPlayerHtml = `
    <div class="tw-video-player-container" style="position: relative; width: 100%; aspect-ratio: 16/9; max-width: 960px; min-width: 280px; min-height: 157px; margin: 0 auto 20px; background: #000; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.5);" itemscope itemtype="https://schema.org/VideoObject">
      <meta itemprop="name" content="${escapeHtml(options.title)}" />
      <meta itemprop="description" content="${escapeHtml(options.description)}" />
      <meta itemprop="thumbnailUrl" content="${escapeHtml(poster)}" />
      ${options.uploadDate ? `<meta itemprop="uploadDate" content="${escapeHtml(options.uploadDate)}" />` : ""}
      ${safeDurationSeconds ? `<meta itemprop="duration" content="PT${safeDurationSeconds}S" />` : ""}
      ${options.embedUrl ? `<meta itemprop="embedUrl" content="${escapeHtml(options.embedUrl)}" />` : ""}
      <video controls playsinline poster="${escapeHtml(poster)}" preload="metadata" style="width: 100%; height: 100%; object-fit: contain; display: block;" itemprop="video">
        ${mediaSource ? (isHls ? `<source src="${escapeHtml(mediaSource)}" type="application/x-mpegURL" />\n        <source src="${escapeHtml(mediaSource)}" type="video/mp4" />` : `<source src="${escapeHtml(mediaSource)}" type="video/mp4" />`) : ""}
        <p style="padding: 20px; color: #a1a1aa; text-align: center;">Your browser does not support the video tag. Watch on <a href="${escapeHtml(canonicalUrl)}" style="color: #9B30FF;">Truthworld</a>.</p>
      </video>
    </div>`;
  }

  const semanticBodyHtml = `
  <!-- Truthworld SEO Snapshot | Schema Version: ${SCHEMA_VERSION} | Snapshot Version: ${SNAPSHOT_VERSION} -->
  <header style="padding: 14px 20px; background: #090011; border-bottom: 1px solid #27272a; display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 12px;">
    <div style="display: flex; align-items: center; gap: 24px;">
      <a href="${DOMAIN}" style="font-size: 20px; font-weight: bold; color: #9B30FF; text-decoration: none; letter-spacing: -0.5px;">Truthworld</a>
      <nav style="display: flex; align-items: center; gap: 16px; font-size: 14px;">
        <a href="${DOMAIN}/trending" style="color: #d4d4d8; text-decoration: none; font-weight: 500;">Trending</a>
        <a href="${DOMAIN}/browse" style="color: #d4d4d8; text-decoration: none; font-weight: 500;">Browse</a>
        <a href="${DOMAIN}/studio" style="color: #d4d4d8; text-decoration: none; font-weight: 500;">Studio</a>
        <a href="${DOMAIN}/advertisements" style="color: #d4d4d8; text-decoration: none; font-weight: 500;">Advertisements</a>
      </nav>
    </div>
    <div>
      <a href="${DOMAIN}/search" style="color: #a1a1aa; text-decoration: none; font-size: 14px; background: #18181b; padding: 6px 14px; border-radius: 16px; border: 1px solid #27272a;">Search</a>
    </div>
  </header>

  ${options.breadcrumbHtml || ""}

  <main style="max-width: 1000px; margin: 0 auto; padding: 16px; color: #f4f4f5; font-family: Roboto, sans-serif;">
    <article>
      ${videoPlayerHtml}
      <h1 style="font-size: 24px; font-weight: bold; line-height: 1.3; color: #ffffff;">${escapeHtml(headingText)}</h1>
      ${authorHtml}
      <p style="margin-top: 12px; line-height: 1.5; color: #d4d4d8; font-size: 15px;">${escapeHtml(options.description)}</p>
      ${topicLinksHtml}
      ${transcriptHtml}
      ${options.customBodyHtml || ""}
    </article>
    ${relatedLinksHtml}
  </main>

  <footer style="margin-top: 48px; padding: 32px 20px 24px; border-top: 1px solid #27272a; background: #08000f; color: #a1a1aa; font-family: Roboto, sans-serif; font-size: 13px;">
    <div style="max-width: 1000px; margin: 0 auto; display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 24px; margin-bottom: 24px; text-align: left;">
      <div>
        <h4 style="color: #f4f4f5; font-size: 14px; margin-bottom: 12px; font-weight: 600;">Discover</h4>
        <ul style="list-style: none; padding: 0; margin: 0; line-height: 2;">
          <li><a href="${DOMAIN}" style="color: #a1a1aa; text-decoration: none;">Home Feed</a></li>
          <li><a href="${DOMAIN}/trending" style="color: #a1a1aa; text-decoration: none;">Trending Videos</a></li>
          <li><a href="${DOMAIN}/browse" style="color: #a1a1aa; text-decoration: none;">Browse Categories & Topics</a></li>
          <li><a href="${DOMAIN}/search" style="color: #a1a1aa; text-decoration: none;">Search Truthworld</a></li>
        </ul>
      </div>
      <div>
        <h4 style="color: #f4f4f5; font-size: 14px; margin-bottom: 12px; font-weight: 600;">Creators & Brands</h4>
        <ul style="list-style: none; padding: 0; margin: 0; line-height: 2;">
          <li><a href="${DOMAIN}/studio" style="color: #a1a1aa; text-decoration: none;">Truthworld Studio</a></li>
          <li><a href="${DOMAIN}/advertisements" style="color: #a1a1aa; text-decoration: none;">Truthworld Advertisements</a></li>
          <li><a href="${DOMAIN}/feedback" style="color: #a1a1aa; text-decoration: none;">Creator Feedback</a></li>
        </ul>
      </div>
      <div>
        <h4 style="color: #f4f4f5; font-size: 14px; margin-bottom: 12px; font-weight: 600;">Trust & Safety</h4>
        <ul style="list-style: none; padding: 0; margin: 0; line-height: 2;">
          <li><a href="${DOMAIN}/about" style="color: #a1a1aa; text-decoration: none;">About Truthworld</a></li>
          <li><a href="${DOMAIN}/community-guidelines" style="color: #a1a1aa; text-decoration: none;">Community Guidelines</a></li>
          <li><a href="${DOMAIN}/copyright-complaint" style="color: #a1a1aa; text-decoration: none;">DMCA / Copyright Complaints</a></li>
        </ul>
      </div>
      <div>
        <h4 style="color: #f4f4f5; font-size: 14px; margin-bottom: 12px; font-weight: 600;">Legal</h4>
        <ul style="list-style: none; padding: 0; margin: 0; line-height: 2;">
          <li><a href="${DOMAIN}/privacy" style="color: #a1a1aa; text-decoration: none;">Privacy Policy</a></li>
          <li><a href="${DOMAIN}/terms" style="color: #a1a1aa; text-decoration: none;">Terms of Service</a></li>
        </ul>
      </div>
    </div>
    <div style="border-top: 1px solid #1c1917; padding-top: 16px; text-align: center; color: #71717a; font-size: 12px;">
      <p>&copy; ${new Date().getFullYear()} Truthworld. All rights reserved. Verify before you share.</p>
    </div>
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
  <link rel="icon" type="image/png" sizes="192x192" href="${DOMAIN}/icons/Icon-192.png?v=2" />
  <link rel="icon" type="image/png" sizes="48x48" href="${DOMAIN}/favicon-48x48.png?v=2" />
  <link rel="icon" type="image/png" href="${DOMAIN}/favicon.png?v=2" />
  <link rel="shortcut icon" href="${DOMAIN}/favicon.ico?v=2" />
  <link rel="apple-touch-icon" href="${DOMAIN}/icons/Icon-192.png?v=2" />
  <link rel="manifest" href="${DOMAIN}/manifest.json" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: #0D0014; color: #f4f4f5; }

    /* Mobile Smart App Banner */
    .tw-mobile-app-banner {
      display: none;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 10px 16px;
      background: #141416;
      border-bottom: 1px solid #27272a;
      position: sticky;
      top: 0;
      z-index: 999999;
      font-family: Roboto, -apple-system, sans-serif;
    }
    .tw-mobile-app-banner-info {
      display: flex;
      align-items: center;
      gap: 12px;
      min-width: 0;
      flex: 1;
    }
    .tw-mobile-app-banner-icon {
      width: 40px;
      height: 40px;
      border-radius: 8px;
      object-fit: cover;
      flex-shrink: 0;
      box-shadow: 0 2px 8px rgba(0,0,0,0.4);
    }
    .tw-mobile-app-banner-text {
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .tw-mobile-app-banner-title {
      font-size: 14px;
      font-weight: 700;
      color: #ffffff;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .tw-mobile-app-banner-desc {
      font-size: 12px;
      color: #a1a1aa;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .tw-mobile-app-banner-actions {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-shrink: 0;
    }
    .tw-mobile-app-banner-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 8px 18px;
      background: #ffffff;
      color: #000000;
      font-size: 13px;
      font-weight: 700;
      border-radius: 20px;
      text-decoration: none;
      cursor: pointer;
      box-shadow: 0 2px 10px rgba(0,0,0,0.3);
      transition: opacity 0.2s ease;
    }
    .tw-mobile-app-banner-close {
      background: transparent;
      border: none;
      color: #71717a;
      font-size: 20px;
      cursor: pointer;
      padding: 4px 6px;
      line-height: 1;
    }
  </style>
</head>
<body>
  <!-- Mobile Smart App Banner -->
  <div id="tw-app-banner" class="tw-mobile-app-banner">
    <div class="tw-mobile-app-banner-info">
      <img src="${DOMAIN}/icons/Icon-192.png" alt="Truthworld App" class="tw-mobile-app-banner-icon" />
      <div class="tw-mobile-app-banner-text">
        <span class="tw-mobile-app-banner-title">Truthworld App</span>
        <span class="tw-mobile-app-banner-desc">Open in the Truthworld mobile app</span>
      </div>
    </div>
    <div class="tw-mobile-app-banner-actions">
      <a id="tw-open-app-btn" href="#" class="tw-mobile-app-banner-btn">OPEN APP</a>
      <button id="tw-close-app-btn" class="tw-mobile-app-banner-close" aria-label="Close banner">&times;</button>
    </div>
  </div>

  ${semanticBodyHtml}
  <script>
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for (var registration of registrations) {
          registration.unregister();
        }
      }).catch(function() {});
    }

    // Mobile Deep Link & Smart Banner Controller
    (function() {
      var isAndroid = /Android/i.test(navigator.userAgent);
      var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
      if (!isAndroid && !isIOS) return;

      var banner = document.getElementById('tw-app-banner');
      var openBtn = document.getElementById('tw-open-app-btn');
      var closeBtn = document.getElementById('tw-close-app-btn');

      if (banner && sessionStorage.getItem('tw_banner_dismissed') !== 'true') {
        banner.style.display = 'flex';
      }

      if (closeBtn) {
        closeBtn.addEventListener('click', function() {
          if (banner) banner.style.display = 'none';
          sessionStorage.setItem('tw_banner_dismissed', 'true');
        });
      }

      var pathWithQuery = window.location.pathname + window.location.search + window.location.hash;
      var cleanPath = pathWithQuery.replace(/^\\/+/, '');
      var deepLinkIntentUrl = isAndroid
        ? 'intent://www.truthworld.in/' + cleanPath + '#Intent;scheme=https;package=com.truthworld.app;S.browser_fallback_url=' + encodeURIComponent(window.location.href) + ';end'
        : 'truthworld://' + cleanPath;

      if (openBtn) {
        openBtn.setAttribute('href', deepLinkIntentUrl);
        openBtn.addEventListener('click', function(e) {
          e.preventDefault();
          var freshPath = (window.location.pathname + window.location.search + window.location.hash).replace(/^\\/+/, '');
          var targetUrl = isAndroid
            ? 'intent://www.truthworld.in/' + freshPath + '#Intent;scheme=https;package=com.truthworld.app;S.browser_fallback_url=' + encodeURIComponent(window.location.href) + ';end'
            : 'truthworld://' + freshPath;
          window.location.href = targetUrl;
        });
      }

      // Auto-dispatch when opened inside mobile social messaging apps (WhatsApp, Telegram, Twitter, FB, IG)
      var isInAppBrowser = /FBAN|FBAV|Instagram|Twitter|Line|WhatsApp|Telegram|MicroMessenger/i.test(navigator.userAgent);
      var isReferrerExternal = document.referrer && !document.referrer.includes('truthworld.in');
      var hasAutoLaunched = sessionStorage.getItem('tw_app_launch_attempted');

      if ((isInAppBrowser || isReferrerExternal) && !hasAutoLaunched) {
        sessionStorage.setItem('tw_app_launch_attempted', 'true');
        setTimeout(function() {
          try {
            window.location.href = deepLinkIntentUrl;
          } catch (_) {}
        }, 300);
      }
    })();
  </script>
  <!-- Flutter bootstrap -->
  <script src="flutter_bootstrap.js"></script>
</body>
</html>`;
}
