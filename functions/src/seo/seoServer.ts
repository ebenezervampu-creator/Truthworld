import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import axios from "axios";
import { Request, Response } from "express";

let cachedIndexHtml: string | null = null;
const DOMAIN = "https://www.truthworld.in";

// Fetch the main index.html for bootstrapping Flutter and injecting SEO
async function fetchIndexHtml(): Promise<string> {
  if (cachedIndexHtml) return cachedIndexHtml;
  try {
    const response = await axios.get(`${DOMAIN}/index.html`);
    cachedIndexHtml = response.data;
    return cachedIndexHtml!;
  } catch (e) {
    console.error("Failed to fetch index.html", e);
    // Fallback simple HTML to not crash crawlers if fetch fails
    return `<!DOCTYPE html><html><head><title>Truthworld</title></head><body></body></html>`;
  }
}

function escapeHtml(unsafe: string): string {
  if (!unsafe) return "";
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function cleanJsonLd(obj: any): any {
  if (Array.isArray(obj)) {
    const arr = obj.map(cleanJsonLd).filter(v => v !== null && v !== undefined && v !== "" && (Array.isArray(v) ? v.length > 0 : true));
    return arr.length > 0 ? arr : undefined;
  }
  if (obj !== null && typeof obj === 'object') {
    const cleaned: any = {};
    for (const key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        const val = cleanJsonLd(obj[key]);
        if (val !== null && val !== undefined && val !== "" && (Array.isArray(val) ? val.length > 0 : true)) {
          cleaned[key] = val;
        }
      }
    }
    return Object.keys(cleaned).length > 0 ? cleaned : undefined;
  }
  return obj;
}

function formatIsoDuration(durationMs?: number): string | undefined {
  if (!durationMs || durationMs <= 0) return undefined;
  const totalSeconds = Math.floor(durationMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  
  let result = "PT";
  if (hours > 0) result += `${hours}H`;
  if (minutes > 0) result += `${minutes}M`;
  if (seconds > 0 || result === "PT") result += `${seconds}S`;
  return result;
}

function formatDate(timestamp?: any): string {
  if (!timestamp) return new Date().toISOString();
  if (typeof timestamp.toMillis === "function") {
    return new Date(timestamp.toMillis()).toISOString();
  }
  if (timestamp instanceof Date) {
    return timestamp.toISOString();
  }
  if (typeof timestamp === "number") {
    return new Date(timestamp).toISOString();
  }
  if (typeof timestamp === "string") {
    return new Date(timestamp).toISOString();
  }
  return new Date().toISOString();
}

function getCanonicalUrl(host: string, path: string, query: any): string {
  const isStudio = host.includes("studio") || path.startsWith("/studio");
  const base = isStudio 
    ? (host.includes("localhost") || host.includes("127.0.0.1") ? `http://${host}` : "https://studio.truthworld.in")
    : DOMAIN;
  
  if (path.startsWith("/watch")) {
    const v = query.v;
    return v ? `${base}/watch?v=${v}` : `${base}/watch`;
  }
  if (path.startsWith("/playlist")) {
    const list = query.list;
    return list ? `${base}/playlist?list=${list}` : `${base}/playlist`;
  }
  if (isStudio && (path === "/" || path === "/studio" || path === "" || path === "/index.html")) {
    return "https://studio.truthworld.in/";
  }
  return `${base}${path}`;
}

function injectSeoMeta(html: string, meta: any): string {
  let cleanedHtml = html;
  cleanedHtml = cleanedHtml.replace(/<title>.*?<\/title>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta name="description"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<link rel="canonical"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta name="robots"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta name="googlebot"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta property="og:[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta name="twitter:[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<link rel="alternate"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(
    /<script type="application\/ld\+json">[\s\S]*?<\/script>/gi,
    ""
  );

  const robotsDirective = meta.robots || "index, follow";

  let tags = `
  <title>${escapeHtml(meta.title)}</title>
  <meta name="description" content="${escapeHtml(meta.description)}" />
  <meta name="robots" content="${robotsDirective}" />
  <meta name="googlebot" content="${robotsDirective}" />
  <link rel="canonical" href="${meta.url}" />
  <link rel="alternate" hreflang="x-default" href="${meta.url}" />
  <meta property="og:type" content="${meta.type || "website"}" />
  <meta property="og:url" content="${meta.url}" />
  <meta property="og:title" content="${escapeHtml(meta.title)}" />
  <meta property="og:description" content="${escapeHtml(meta.description)}" />
  ${meta.image ? `<meta property="og:image" content="${meta.image}" />` : ""}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeHtml(meta.title)}" />
  <meta name="twitter:description" content="${escapeHtml(meta.description)}" />
  ${meta.image ? `<meta name="twitter:image" content="${meta.image}" />` : ""}
  `;

  // Future-proofing translation alternate links
  const supportedLangs = ["en", "hi", "te", "ta", "kn"];
  for (const lang of supportedLangs) {
    tags += `<link rel="alternate" hreflang="${lang}" href="${meta.url}" />\n  `;
  }

  if (meta.jsonLd) {
    const cleanedLd = cleanJsonLd(meta.jsonLd);
    if (cleanedLd) {
      const jsonLdBlocks = Array.isArray(cleanedLd) ? cleanedLd : [cleanedLd];
      for (const block of jsonLdBlocks) {
        tags += `<script type="application/ld+json">\n${JSON.stringify(block, null, 2)}\n</script>\n  `;
      }
    }
  }

  if (meta.rawData && meta.dataType) {
    const globalName = `__${meta.dataType.toUpperCase()}_DATA__`;
    tags += `<script>window.${globalName} = ${JSON.stringify(meta.rawData)};</script>\n  `;
  }

  return cleanedHtml.replace(/<head>/i, `<head>\n${tags}`);
}

// ─── Sitemap Handlers ──────────────────────────────────────────────────────────

async function handleSitemapIndex(req: Request, res: Response) {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>${DOMAIN}/sitemap-static.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-videos.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-channels.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-topics.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-playlists.xml</loc>
  </sitemap>
</sitemapindex>`;

  res.set("Content-Type", "application/xml");
  res.set("Cache-Control", "public, max-age=3600, s-maxage=86400");
  res.status(200).send(xml);
}

async function handleSitemapStatic(req: Request, res: Response) {
  const pages = [
    "",
    "/home",
    "/about",
    "/privacy",
    "/terms",
    "/help",
    "/feedback",
    "/settings",
    "/premium",
    "/studio",
    "/advertiser"
  ];
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;
  const dateStr = new Date().toISOString().split("T")[0];
  for (const page of pages) {
    xml += `
  <url>
    <loc>${DOMAIN}${page}</loc>
    <lastmod>${dateStr}</lastmod>
    <changefreq>daily</changefreq>
    <priority>${page === "" || page === "/home" ? "1.0" : "0.6"}</priority>
  </url>`;
  }
  xml += `\n</urlset>`;

  res.set("Content-Type", "application/xml");
  res.set("Cache-Control", "public, max-age=3600, s-maxage=86400");
  res.status(200).send(xml);
}

async function handleSitemapVideos(req: Request, res: Response) {
  const db = admin.firestore();
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:video="http://www.google.com/schemas/sitemap-video/1.1">`;

  try {
    const snap = await db
      .collection("videos")
      .where("visibility", "==", "public")
      .orderBy("uploadedAt", "desc")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      if (status === "ready" && data.earlyPrecheck?.status === "approved") {
        const title = escapeHtml(data.title || "Video");
        const description = escapeHtml(data.description || `Watch ${data.title} on Truthworld.`);
        const thumbnail = escapeHtml(data.thumbnailUrl || data.thumbnail || `${DOMAIN}/icons/og-image.png`);
        const contentUrl = escapeHtml(data.hlsUrl || data.originalUrl || data.videoUrl || "");
        const durationSec = data.durationMs ? Math.floor(data.durationMs / 1000) : 0;
        const uploadDate = formatDate(data.uploadedAt || data.createdAt);
        const viewCount = data.viewCount || data.views || 0;
        const channelName = escapeHtml(data.channelName || "Uploader");

        xml += `
  <url>
    <loc>${DOMAIN}/watch?v=${doc.id}</loc>
    <lastmod>${formatDate(data.updatedAt || data.uploadedAt || data.createdAt).split("T")[0]}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
    <video:video>
      <video:thumbnail_loc>${thumbnail}</video:thumbnail_loc>
      <video:title>${title}</video:title>
      <video:description>${description}</video:description>
      ${contentUrl ? `<video:content_loc>${contentUrl}</video:content_loc>` : ""}
      <video:duration>${durationSec}</video:duration>
      <video:view_count>${viewCount}</video:view_count>
      <video:publication_date>${uploadDate}</video:publication_date>
      <video:family_friendly>${data.isKidFriendly ? "yes" : "no"}</video:family_friendly>
      <video:uploader info="${DOMAIN}/channel/${data.channelId}">${channelName}</video:uploader>
    </video:video>
  </url>`;
      }
    });
  } catch (e) {
    console.error("Error generating videos sitemap", e);
  }

  xml += `\n</urlset>`;
  res.set("Content-Type", "application/xml");
  res.set("Cache-Control", "public, max-age=1800, s-maxage=7200");
  res.status(200).send(xml);
}

async function handleSitemapChannels(req: Request, res: Response) {
  const db = admin.firestore();
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("channels")
      .where("status", "==", "active")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      let handle = data.handleLowercase || data.handle;
      const lastmod = formatDate(data.updatedAt || data.createdAt).split("T")[0];
      if (handle) {
        if (handle.startsWith("@")) {
          handle = handle.substring(1);
        }
        xml += `
  <url>
    <loc>${DOMAIN}/@${handle}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>`;
      }
      xml += `
  <url>
    <loc>${DOMAIN}/channel/${doc.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`;
    });
  } catch (e) {
    console.error("Error generating channels sitemap", e);
  }

  xml += `\n</urlset>`;
  res.set("Content-Type", "application/xml");
  res.set("Cache-Control", "public, max-age=1800, s-maxage=7200");
  res.status(200).send(xml);
}

async function handleSitemapTopics(req: Request, res: Response) {
  const db = admin.firestore();
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("topics")
      .where("status", "==", "active")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const slug = data.slug || doc.id;
      const lastmod = formatDate(data.updatedAt || data.createdAt).split("T")[0];
      xml += `
  <url>
    <loc>${DOMAIN}/topic/${slug}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>`;
    });
  } catch (e) {
    console.error("Error generating topics sitemap", e);
  }

  xml += `\n</urlset>`;
  res.set("Content-Type", "application/xml");
  res.set("Cache-Control", "public, max-age=1800, s-maxage=7200");
  res.status(200).send(xml);
}

async function handleSitemapPlaylists(req: Request, res: Response) {
  const db = admin.firestore();
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("public_playlists")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const lastmod = formatDate(data.updatedAt || data.createdAt).split("T")[0];
      xml += `
  <url>
    <loc>${DOMAIN}/playlist?list=${doc.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`;
    });
  } catch (e) {
    console.error("Error generating playlists sitemap", e);
  }

  xml += `\n</urlset>`;
  res.set("Content-Type", "application/xml");
  res.set("Cache-Control", "public, max-age=1800, s-maxage=7200");
  res.status(200).send(xml);
}

// ─── Cloud Function Endpoint ──────────────────────────────────────────────────

export const seoServer = onRequest(
  {
    region: "asia-south1",
    memory: "512MiB",
  },
  async (req: Request, res: Response) => {
    try {
      const path = req.path;

      // 1. Sitemap routes
      if (path === "/sitemap.xml") {
        return await handleSitemapIndex(req, res);
      }
      if (path === "/sitemap-static.xml") {
        return await handleSitemapStatic(req, res);
      }
      if (path === "/sitemap-videos.xml") {
        return await handleSitemapVideos(req, res);
      }
      if (path === "/sitemap-channels.xml") {
        return await handleSitemapChannels(req, res);
      }
      if (path === "/sitemap-topics.xml") {
        return await handleSitemapTopics(req, res);
      }
      if (path === "/sitemap-playlists.xml") {
        return await handleSitemapPlaylists(req, res);
      }

      // 2. Dynamic SEO Routes
      let meta: any = null;
      const db = admin.firestore();
      const host = (req.hostname || req.headers.host || "").toLowerCase();
      const isStudioDomain = host.includes("studio") || path.startsWith("/studio");

      if (isStudioDomain) {
        const canonical = getCanonicalUrl(host, path, req.query);
        const isLanding = path === "/" || path === "/studio" || path === "/index.html" || path === "";
        meta = {
          title: "Creator Studio - Truthworld",
          description: "Manage your channel, upload validation-secured videos, track real-time analytics, and build your community on Truthworld Creator Studio.",
          url: canonical,
          type: "website",
          image: `${DOMAIN}/icons/og-image.png`,
          robots: isLanding ? "index, follow" : "noindex, nofollow"
        };
      } else if (path.startsWith("/watch")) {
        let videoId = req.query.v as string;
        if (!videoId && path.split("/").length > 2) {
          videoId = path.split("/")[2];
        }
        if (videoId) {
          const doc = await db.collection("videos").doc(videoId).get();
          if (doc.exists) {
            const data = doc.data()!;
            const status = (data.status || "").toLowerCase();
            const visibility = (data.visibility || "").toLowerCase();

            if (status === "deleted") {
              meta = {
                title: "Video Removed - Truthworld",
                description: "This video has been permanently removed.",
                url: `${DOMAIN}/watch?v=${videoId}`,
                robots: "noindex, nofollow",
              };
              const baseHtml = await fetchIndexHtml();
              const finalHtml = injectSeoMeta(baseHtml, meta);
              res.status(410).send(finalHtml);
              return;
            }

            if (visibility === "private") {
              meta = {
                title: "Private Video - Truthworld",
                description: "This video is private.",
                url: `${DOMAIN}/watch?v=${videoId}`,
                robots: "noindex, nofollow",
              };
              const baseHtml = await fetchIndexHtml();
              const finalHtml = injectSeoMeta(baseHtml, meta);
              res.status(403).send(finalHtml);
              return;
            }

            const titleStr = `${data.title} - Truthworld`;
            const descStr = data.description || `Watch ${data.title} on Truthworld.`;
            const imgStr = data.thumbnailUrl || data.thumbnail || `${DOMAIN}/icons/og-image.png`;
            const uploadDate = formatDate(data.uploadedAt || data.createdAt);

            const isPrivate = visibility === "unlisted";
            const robotsDirective = isPrivate ? "noindex, nofollow" : "index, follow";

            let channelName = data.channelName || "Channel";
            let channelHandle = "";
            if (data.channelId) {
              const channelDoc = await db.collection("channels").doc(data.channelId).get();
              if (channelDoc.exists) {
                const channelData = channelDoc.data()!;
                channelName = channelData.displayName || channelData.name || channelName;
                channelHandle = channelData.handle || "";
              }
            }
            const authorUrl = channelHandle 
              ? `${DOMAIN}/${channelHandle.startsWith("@") ? channelHandle : `@${channelHandle}`}`
              : `${DOMAIN}/channel/${data.channelId}`;

            meta = {
              title: titleStr,
              description: descStr,
              image: imgStr,
              url: `${DOMAIN}/watch?v=${videoId}`,
              type: "video.other",
              robots: robotsDirective,
              jsonLd: [
                {
                  "@context": "https://schema.org",
                  "@type": "VideoObject",
                  name: data.title,
                  description: descStr,
                  thumbnailUrl: imgStr,
                  uploadDate: uploadDate,
                  duration: formatIsoDuration(data.durationMs),
                  contentUrl: data.hlsUrl || data.originalUrl || data.videoUrl,
                  interactionStatistic: {
                    "@type": "InteractionCounter",
                    interactionType: { "@type": "WatchAction" },
                    userInteractionCount: data.viewCount || data.views || 0,
                  },
                  publisher: {
                    "@type": "Organization",
                    name: "Truthworld",
                    logo: {
                      "@type": "ImageObject",
                      url: `${DOMAIN}/icons/Icon-192.png`,
                    },
                  },
                  author: {
                    "@type": "Person",
                    name: channelName,
                    url: authorUrl
                  },
                  potentialAction: {
                    "@type": "WatchAction",
                    target: `${DOMAIN}/watch?v=${videoId}`
                  }
                },
                {
                  "@context": "https://schema.org",
                  "@type": "BreadcrumbList",
                  itemListElement: [
                    {
                      "@type": "ListItem",
                      position: 1,
                      name: "Home",
                      item: DOMAIN
                    },
                    {
                      "@type": "ListItem",
                      position: 2,
                      name: channelName,
                      item: authorUrl
                    },
                    {
                      "@type": "ListItem",
                      position: 3,
                      name: data.title,
                      item: `${DOMAIN}/watch?v=${videoId}`
                    }
                  ]
                }
              ],
              rawData: { id: doc.id, ...data },
              dataType: "video",
            };
          } else {
            meta = {
              title: "Video Not Found - Truthworld",
              description: "The video you are looking for does not exist or has been removed.",
              url: `${DOMAIN}${path}`,
              robots: "noindex, nofollow",
            };
            const baseHtml = await fetchIndexHtml();
            const finalHtml = injectSeoMeta(baseHtml, meta);
            res.status(404).send(finalHtml);
            return;
          }
        }
      } else if (
        path.startsWith("/channel/") ||
        path.startsWith("/@") ||
        path.startsWith("/c/") ||
        path.startsWith("/user/")
      ) {
        let handleOrId = "";
        let queryType = "id";
        if (path.startsWith("/@")) {
          handleOrId = path.substring(2);
          queryType = "handle";
        } else if (path.startsWith("/channel/")) {
          handleOrId = path.split("/")[2];
          queryType = "id";
        } else {
          handleOrId = path.split("/")[2];
          queryType = "handle";
        }

        if (handleOrId) {
          let docData: any = null;
          if (queryType === "id") {
            const doc = await db.collection("channels").doc(handleOrId).get();
            if (doc.exists) docData = { id: doc.id, ...(doc.data() as any) } as any;
          } else {
            const qs = await db
              .collection("channels")
              .where("handleLowercase", "==", handleOrId.toLowerCase())
              .limit(1)
              .get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) } as any;
          }

          if (docData) {
            const status = (docData.status || "").toLowerCase();
            if (status === "deleted") {
              meta = {
                title: "Channel Removed - Truthworld",
                description: "This channel has been permanently removed.",
                url: `${DOMAIN}${path}`,
                robots: "noindex, nofollow",
              };
              const baseHtml = await fetchIndexHtml();
              const finalHtml = injectSeoMeta(baseHtml, meta);
              res.status(410).send(finalHtml);
              return;
            }

            if (status === "suspended") {
              meta = {
                title: "Channel Suspended - Truthworld",
                description: "This channel has been suspended.",
                url: `${DOMAIN}${path}`,
                robots: "noindex, nofollow",
              };
              const baseHtml = await fetchIndexHtml();
              const finalHtml = injectSeoMeta(baseHtml, meta);
              res.status(403).send(finalHtml);
              return;
            }

            const channelName = docData.displayName || docData.name || "Channel";
            const titleStr = `${channelName} - Truthworld`;
            const descStr = docData.about || docData.description || `Watch videos from ${channelName} on Truthworld.`;
            const imgStr = docData.profile?.photoUrl || docData.avatarUrl || docData.avatar || `${DOMAIN}/icons/og-image.png`;
            const handle = docData.handle || "";
            const channelUrl = handle 
              ? `${DOMAIN}/${handle.startsWith("@") ? handle : `@${handle}`}`
              : `${DOMAIN}/channel/${docData.id}`;

            const isBrand = docData.isBrand === true || docData.creatorType === "Organization" || docData.type === "custom";
            const mainEntityType = isBrand ? "Organization" : "Person";

            const sameAsList: string[] = [];
            if (docData.profile?.links) {
              const links = docData.profile.links;
              for (const k in links) {
                if (links[k]) sameAsList.push(links[k]);
              }
            } else if (docData.socialLinks) {
              const links = docData.socialLinks;
              for (const k in links) {
                if (links[k]) sameAsList.push(links[k]);
              }
            }

            meta = {
              title: titleStr,
              description: descStr,
              image: imgStr,
              url: channelUrl,
              type: "profile",
              jsonLd: [
                {
                  "@context": "https://schema.org",
                  "@type": "ProfilePage",
                  mainEntity: {
                    "@type": mainEntityType,
                    name: channelName,
                    description: descStr,
                    image: imgStr,
                    url: channelUrl,
                    interactionStatistic: [
                      {
                        "@type": "InteractionCounter",
                        interactionType: { "@type": "SubscribeAction" },
                        userInteractionCount: docData.stats?.subscriberCount || docData.subscriberCount || 0
                      }
                    ],
                    sameAs: sameAsList
                  }
                },
                {
                  "@context": "https://schema.org",
                  "@type": "BreadcrumbList",
                  itemListElement: [
                    {
                      "@type": "ListItem",
                      position: 1,
                      name: "Home",
                      item: DOMAIN
                    },
                    {
                      "@type": "ListItem",
                      position: 2,
                      name: channelName,
                      item: channelUrl
                    }
                  ]
                }
              ],
              rawData: docData,
              dataType: "channel",
            };
          } else {
            meta = {
              title: "Channel Not Found - Truthworld",
              description: "The channel you are looking for does not exist.",
              url: `${DOMAIN}${path}`,
              robots: "noindex, nofollow",
            };
            const baseHtml = await fetchIndexHtml();
            const finalHtml = injectSeoMeta(baseHtml, meta);
            res.status(404).send(finalHtml);
            return;
          }
        }
      } else if (path.startsWith("/topic/") || path.startsWith("/T/")) {
        const slug = path.split("/")[2];
        if (slug) {
          let docData: any = null;
          const qs = await db
            .collection("topics")
            .where("slug", "==", slug)
            .limit(1)
            .get();
          if (!qs.empty) {
            docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) } as any;
          } else {
            const doc = await db.collection("topics").doc(slug).get();
            if (doc.exists) {
              docData = { id: doc.id, ...(doc.data() as any) } as any;
            }
          }

          if (docData) {
            const status = (docData.status || "").toLowerCase();
            if (status === "deleted" || status === "inactive") {
              meta = {
                title: "Topic Unavailable - Truthworld",
                description: "This topic is currently unavailable.",
                url: `${DOMAIN}${path}`,
                robots: "noindex, nofollow",
              };
              const baseHtml = await fetchIndexHtml();
              const finalHtml = injectSeoMeta(baseHtml, meta);
              res.status(404).send(finalHtml);
              return;
            }

            const topicTitle = docData.title || "Topic";
            const descStr = docData.description || `Explore the ${topicTitle} topic on Truthworld.`;
            const imgStr = docData.thumbnailUrl || docData.coverImage || `${DOMAIN}/icons/og-image.png`;
            const topicUrl = `${DOMAIN}${path}`;

            const topVideos: any[] = [];
            try {
              const videosSnap = await db
                .collection("videos")
                .where("visibility", "==", "public")
                .where("topics", "array-contains", docData.id)
                .orderBy("uploadedAt", "desc")
                .limit(10)
                .get();
              videosSnap.forEach((vDoc) => {
                topVideos.push({ id: vDoc.id, ...vDoc.data() });
              });
            } catch (err) {
              console.error("Error fetching videos for topic JSON-LD", err);
            }

            meta = {
              title: `${topicTitle} - Topic | Truthworld`,
              description: descStr,
              image: imgStr,
              url: topicUrl,
              type: "website",
              jsonLd: [
                {
                  "@context": "https://schema.org",
                  "@type": "CollectionPage",
                  name: topicTitle,
                  description: descStr,
                  url: topicUrl,
                  mainEntity: {
                    "@type": "ItemList",
                    name: topicTitle,
                    numberOfItems: topVideos.length,
                    itemListElement: topVideos.map((v, i) => ({
                      "@type": "ListItem",
                      position: i + 1,
                      url: `${DOMAIN}/watch?v=${v.id}`
                    }))
                  }
                },
                {
                  "@context": "https://schema.org",
                  "@type": "BreadcrumbList",
                  itemListElement: [
                    {
                      "@type": "ListItem",
                      position: 1,
                      name: "Home",
                      item: DOMAIN
                    },
                    {
                      "@type": "ListItem",
                      position: 2,
                      name: topicTitle,
                      item: topicUrl
                    }
                  ]
                }
              ],
              rawData: docData,
              dataType: "topic",
            };
          } else {
            meta = {
              title: "Topic Not Found - Truthworld",
              description: "The topic you are looking for does not exist.",
              url: `${DOMAIN}${path}`,
              robots: "noindex, nofollow",
            };
            const baseHtml = await fetchIndexHtml();
            const finalHtml = injectSeoMeta(baseHtml, meta);
            res.status(404).send(finalHtml);
            return;
          }
        }
      } else if (path.startsWith("/playlist")) {
        let playlistId = req.query.list as string;
        if (!playlistId && path.split("/").length > 2) {
          playlistId = path.split("/")[2];
        }
        if (playlistId) {
          let doc = await db.collection("public_playlists").doc(playlistId).get();
          if (!doc.exists) {
            doc = await db.collection("playlists").doc(playlistId).get();
          }

          if (doc.exists) {
            const data = doc.data()!;
            const visibility = (data.visibility || "").toLowerCase();

            if (visibility === "private") {
              meta = {
                title: "Private Playlist - Truthworld",
                description: "This playlist is private.",
                url: `${DOMAIN}/playlist?list=${playlistId}`,
                robots: "noindex, nofollow",
              };
              const baseHtml = await fetchIndexHtml();
              const finalHtml = injectSeoMeta(baseHtml, meta);
              res.status(403).send(finalHtml);
              return;
            }

            const playlistName = data.playlistName || data.name || "Playlist";
            const titleStr = `${playlistName} - Playlist | Truthworld`;
            const descStr = data.description || `Watch this playlist on Truthworld.`;
            const imgStr = data.thumbnailUrl || data.thumbnail || `${DOMAIN}/icons/og-image.png`;
            const playlistUrl = `${DOMAIN}/playlist?list=${playlistId}`;

            const videoIds = data.videoIds || [];
            meta = {
              title: titleStr,
              description: descStr,
              image: imgStr,
              url: playlistUrl,
              type: "website",
              jsonLd: [
                {
                  "@context": "https://schema.org",
                  "@type": "ItemList",
                  name: playlistName,
                  description: descStr,
                  numberOfItems: videoIds.length,
                  itemListElement: videoIds.slice(0, 20).map((vid: string, i: number) => ({
                    "@type": "ListItem",
                    position: i + 1,
                    url: `${DOMAIN}/watch?v=${vid}`
                  }))
                },
                {
                  "@context": "https://schema.org",
                  "@type": "BreadcrumbList",
                  itemListElement: [
                    {
                      "@type": "ListItem",
                      position: 1,
                      name: "Home",
                      item: DOMAIN
                    },
                    {
                      "@type": "ListItem",
                      position: 2,
                      name: playlistName,
                      item: playlistUrl
                    }
                  ]
                }
              ],
              rawData: { id: doc.id, ...data },
              dataType: "playlist",
            };
          } else {
            meta = {
              title: "Playlist Not Found - Truthworld",
              description: "The playlist you are looking for does not exist.",
              url: `${DOMAIN}/playlist?list=${playlistId}`,
              robots: "noindex, nofollow",
            };
            const baseHtml = await fetchIndexHtml();
            const finalHtml = injectSeoMeta(baseHtml, meta);
            res.status(404).send(finalHtml);
            return;
          }
        }
      } else if (path === "/advertiser" || path.startsWith("/advertiser")) {
        meta = {
          title: "Advertiser Portal - Truthworld Ads",
          description: "Promote your channel, videos, or brand directly to engaged audiences on Truthworld. Set flexible budgets and track conversion analytics.",
          url: `${DOMAIN}/advertiser`,
          type: "website",
          image: `${DOMAIN}/icons/og-image.png`,
        };
      }

      // 3. Fallback to homepage/default if no meta found
      if (!meta) {
        meta = {
          title: "Truthworld - Verify before you share",
          description: "Truthworld is a premium video-sharing platform that integrates automated content validation into the publishing pipeline, ensuring trustworthy storytelling.",
          url: `${DOMAIN}${path}`,
          type: "website",
          image: `${DOMAIN}/icons/og-image.png`,
          jsonLd: [
            {
              "@context": "https://schema.org",
              "@type": "WebSite",
              "name": "Truthworld",
              "url": DOMAIN,
              "potentialAction": {
                "@type": "SearchAction",
                "target": `${DOMAIN}/search?q={search_term_string}`,
                "query-input": "required name=search_term_string"
              }
            },
            {
              "@context": "https://schema.org",
              "@type": "Organization",
              "name": "Truthworld",
              "url": DOMAIN,
              "logo": `${DOMAIN}/icons/Icon-192.png`
            }
          ]
        };
      }

      // 4. Inject into HTML and serve
      const baseHtml = await fetchIndexHtml();
      const finalHtml = injectSeoMeta(baseHtml, meta);

      res.set("Cache-Control", "public, max-age=300, s-maxage=3600");
      res.status(200).send(finalHtml);
    } catch (error) {
      console.error("SEO Server Error:", error);
      // Fallback to basic html without failing the request
      const baseHtml = await fetchIndexHtml();
      res.status(200).send(baseHtml);
    }
  }
);
