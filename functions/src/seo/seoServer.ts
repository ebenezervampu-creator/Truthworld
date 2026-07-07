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

function injectSeoMeta(html: string, meta: any): string {
  // Clean out existing SEO tags to prevent duplicates and overrides
  let cleanedHtml = html;
  cleanedHtml = cleanedHtml.replace(/<title>.*?<\/title>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta name="description"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<link rel="canonical"[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta property="og:[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(/<meta name="twitter:[\s\S]*?\/>/gi, "");
  cleanedHtml = cleanedHtml.replace(
    /<script type="application\/ld\+json">[\s\S]*?<\/script>/gi,
    ""
  );

  const tags = `
  <title>${escapeHtml(meta.title)}</title>
  <meta name="description" content="${escapeHtml(meta.description)}" />
  <link rel="canonical" href="${meta.url}" />
  <meta property="og:type" content="${meta.type || "website"}" />
  <meta property="og:url" content="${meta.url}" />
  <meta property="og:title" content="${escapeHtml(meta.title)}" />
  <meta property="og:description" content="${escapeHtml(meta.description)}" />
  ${meta.image ? `<meta property="og:image" content="${meta.image}" />` : ""}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeHtml(meta.title)}" />
  <meta name="twitter:description" content="${escapeHtml(meta.description)}" />
  ${meta.image ? `<meta name="twitter:image" content="${meta.image}" />` : ""}
  ${
    meta.jsonLd
      ? `<script type="application/ld+json">\n${JSON.stringify(
          meta.jsonLd,
          null,
          2
        )}\n</script>`
      : ""
  }
  ${
    meta.rawData && meta.dataType === "video"
      ? `<script>window.__VIDEO_DATA__ = ${JSON.stringify(meta.rawData)};</script>`
      : ""
  }
  ${
    meta.rawData && meta.dataType === "channel"
      ? `<script>window.__CHANNEL_DATA__ = ${JSON.stringify(meta.rawData)};</script>`
      : ""
  }
  ${
    meta.rawData && meta.dataType === "topic"
      ? `<script>window.__TOPIC_DATA__ = ${JSON.stringify(meta.rawData)};</script>`
      : ""
  }
  ${
    meta.rawData && meta.dataType === "playlist"
      ? `<script>window.__PLAYLIST_DATA__ = ${JSON.stringify(meta.rawData)};</script>`
      : ""
  }
  `;

  // Insert just after the <head> tag
  return cleanedHtml.replace(/<head>/i, `<head>\n${tags}`);
}

async function handleSitemap(req: Request, res: Response) {
  const db = admin.firestore();
  let xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n`;

  // 1. Static pages
  const staticPages = [
    "",
    "/home",
    "/about",
    "/privacy-policy",
    "/terms",
    "/help",
    "/feedback",
    "/settings",
    "/premium",
    "/studio",
    "/advertiser",
  ];
  for (const p of staticPages) {
    xml += `  <url><loc>${DOMAIN}${p}</loc><changefreq>daily</changefreq><priority>1.0</priority></url>\n`;
  }

  try {
    // 2. Videos
    const vids = await db
      .collection("videos")
      .where("visibility", "==", "public")
      .orderBy("uploadedAt", "desc")
      .limit(2000)
      .get();
    vids.forEach((doc) => {
      const data = doc.data();
      if (data && data.status === "ready" && data.earlyPrecheck?.status === "approved") {
        xml += `  <url><loc>${DOMAIN}/watch?v=${doc.id}</loc><changefreq>weekly</changefreq><priority>0.8</priority></url>\n`;
      }
    });
  } catch (e) {
    console.error("Error fetching videos for sitemap:", e);
  }

  try {
    // 3. Channels
    const channels = await db
      .collection("channels")
      .where("status", "==", "active")
      .limit(2000)
      .get();
    channels.forEach((doc) => {
      const data = doc.data();
      let handle = data.handleLowercase || data.handle;
      if (handle) {
        if (handle.startsWith("@")) {
          handle = handle.substring(1);
        }
        xml += `  <url><loc>${DOMAIN}/@${handle}</loc><changefreq>daily</changefreq><priority>0.9</priority></url>\n`;
      }
      xml += `  <url><loc>${DOMAIN}/channel/${doc.id}</loc><changefreq>weekly</changefreq><priority>0.7</priority></url>\n`;
    });
  } catch (e) {
    console.error("Error fetching channels for sitemap:", e);
  }

  try {
    // 4. Topics
    const topics = await db
      .collection("topics")
      .where("status", "==", "active")
      .limit(2000)
      .get();
    topics.forEach((doc) => {
      const slug = doc.data().slug || doc.id;
      xml += `  <url><loc>${DOMAIN}/topic/${slug}</loc><changefreq>daily</changefreq><priority>0.9</priority></url>\n`;
    });
  } catch (e) {
    console.error("Error fetching topics for sitemap:", e);
  }

  try {
    // 5. Playlists
    const playlists = await db
      .collection("playlists")
      .where("visibility", "==", "public")
      .limit(2000)
      .get();
    playlists.forEach((doc) => {
      xml += `  <url><loc>${DOMAIN}/playlist?list=${doc.id}</loc><changefreq>weekly</changefreq><priority>0.7</priority></url>\n`;
    });
  } catch (e) {
    console.error("Error fetching playlists for sitemap:", e);
  }

  xml += `</urlset>`;

  res.set("Content-Type", "application/xml");
  // Cache sitemap for 24 hours in CDN
  res.set("Cache-Control", "public, max-age=3600, s-maxage=86400");
  res.status(200).send(xml);
}

export const seoServer = onRequest(
  {
    region: "asia-south1",
    memory: "512MiB",
  },
  async (req: Request, res: Response) => {
    try {
      const path = req.path;

      // 1. Sitemap route
      if (path === "/sitemap.xml") {
        return await handleSitemap(req, res);
      }

      // 2. Dynamic SEO Routes
      let meta: any = null;
      const db = admin.firestore();

      if (path.startsWith("/watch")) {
        // Parse /watch?v=videoId or /watch/:videoId
        let videoId = req.query.v as string;
        if (!videoId && path.split("/").length > 2) {
          videoId = path.split("/")[2];
        }
        if (videoId) {
          const doc = await db.collection("videos").doc(videoId).get();
          if (doc.exists) {
            const data = doc.data()!;
            if (data && data.title) {
              const visibility = (data.visibility || "").toLowerCase();
              const status = (data.status || "").toLowerCase();
              // Only hide if explicitly marked as private or deleted
              if (visibility !== "private" && status !== "deleted") {
                const titleStr = `${data.title} - Truthworld`;
                const descStr = data.description || `Watch ${data.title} on Truthworld.`;
                const imgStr = data.thumbnailUrl || data.thumbnail || "https://www.truthworld.in/icons/og-image.png";

                meta = {
                  title: titleStr,
                  description: descStr,
                  image: imgStr,
                  url: `${DOMAIN}/watch?v=${videoId}`,
                  type: "video.other",
                  jsonLd: {
                    "@context": "https://schema.org",
                    "@type": "VideoObject",
                    name: data.title,
                    description: descStr,
                    thumbnailUrl: imgStr,
                    uploadDate: data.uploadedAt
                      ? new Date(data.uploadedAt.toMillis()).toISOString()
                      : new Date().toISOString(),
                    contentUrl: `${DOMAIN}/watch?v=${videoId}`,
                  },
                  rawData: { id: doc.id, ...data },
                  dataType: "video",
                };
              }
            }
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
            const channelName = docData.name || docData.channelName || "Channel";
            const titleStr = `${channelName} - Truthworld`;
            const descStr = docData.description || `Watch videos from ${channelName} on Truthworld.`;
            const imgStr = docData.avatarUrl || docData.avatar || docData.bannerUrl || "https://www.truthworld.in/icons/og-image.png";

            meta = {
              title: titleStr,
              description: descStr,
              image: imgStr,
              url: `${DOMAIN}${path}`,
              type: "profile",
              jsonLd: {
                "@context": "https://schema.org",
                "@type": "ProfilePage",
                mainEntity: {
                  "@type": "Person",
                  name: channelName,
                  description: descStr,
                  image: imgStr,
                },
              },
              rawData: docData,
              dataType: "channel",
            };
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
            // Fallback: Query by doc ID
            const doc = await db.collection("topics").doc(slug).get();
            if (doc.exists) {
              docData = { id: doc.id, ...(doc.data() as any) } as any;
            }
          }
          if (docData) {
            meta = {
              title: `${docData.title} - Topic | Truthworld`,
              description:
                docData.description ||
                `Explore the ${docData.title} topic on Truthworld.`,
              image: docData.thumbnailUrl || docData.coverImage,
              url: `${DOMAIN}${path}`,
              type: "website",
              jsonLd: {
                "@context": "https://schema.org",
                "@type": "CollectionPage",
                name: docData.title,
                description: docData.description,
                image: docData.thumbnailUrl || docData.coverImage,
              },
              rawData: docData,
              dataType: "topic",
            };
          }
        }
      } else if (path.startsWith("/playlist")) {
        // /playlist?list=PLAYLIST_ID or /playlist/:id
        let playlistId = req.query.list as string;
        if (!playlistId && path.split("/").length > 2) {
          playlistId = path.split("/")[2];
        }
        if (playlistId) {
          // Check public_playlists first, fallback to playlists
          let doc = await db.collection("public_playlists").doc(playlistId).get();
          if (!doc.exists) {
            doc = await db.collection("playlists").doc(playlistId).get();
          }

          if (doc.exists) {
            const data = doc.data()!;
            const playlistName = data.playlistName || data.name || "Playlist";
            const titleStr = `${playlistName} - Playlist | Truthworld`;
            const descStr = data.description || `Watch this playlist on Truthworld.`;
            const imgStr = data.thumbnailUrl || data.thumbnail || "https://www.truthworld.in/icons/og-image.png";

            meta = {
              title: titleStr,
              description: descStr,
              image: imgStr,
              url: `${DOMAIN}/playlist?list=${playlistId}`,
              type: "website",
              jsonLd: {
                "@context": "https://schema.org",
                "@type": "ItemList",
                name: playlistName,
                description: descStr,
              },
              rawData: { id: doc.id, ...data },
              dataType: "playlist",
            };
          }
        }
      } else if (path === "/studio") {
        meta = {
          title: "Creator Studio - Truthworld",
          description:
            "Manage your channel, upload validation-secured videos, track real-time analytics, and build your community on Truthworld Creator Studio.",
          url: `${DOMAIN}/studio`,
          type: "website",
          image: "https://www.truthworld.in/icons/og-image.png",
        };
      } else if (path === "/advertiser" || path.startsWith("/advertiser")) {
        meta = {
          title: "Advertiser Portal - Truthworld Ads",
          description:
            "Promote your channel, videos, or brand directly to engaged audiences on Truthworld. Set flexible budgets and track conversion analytics.",
          url: `${DOMAIN}/advertiser`,
          type: "website",
          image: "https://www.truthworld.in/icons/og-image.png",
        };
      }

      // 3. Fallback to default if no meta found
      if (!meta) {
        meta = {
          title: "Truthworld",
          description:
            "Truthworld is a premium video-sharing platform that integrates automated content validation into the publishing pipeline, ensuring trustworthy storytelling.",
          url: `${DOMAIN}${path}`,
          type: "website",
          image: "https://www.truthworld.in/icons/og-image.png",
        };
      }

      // 4. Inject into HTML and serve
      const baseHtml = await fetchIndexHtml();
      const finalHtml = injectSeoMeta(baseHtml, meta);

      // Cache the response at CDN level for 5 minutes, browser level for 5 minutes
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
