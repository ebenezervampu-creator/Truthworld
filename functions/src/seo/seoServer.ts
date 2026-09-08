import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp({
    databaseURL: "https://truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "truthworld-1.firebasestorage.app"
  });
}

import { onRequest } from "firebase-functions/v2/https";
import axios from "axios";
import { Request, Response } from "express";
import { DOMAIN, escapeHtml, formatDate } from "./schema/schemaConfig";
import { normalizeUrl } from "./indexing/urlNormalizer";
import { generateBreadcrumbData } from "./render/breadcrumbRenderer";
import { generateVideoSchema } from "./schema/videoSchema";
import { generateChannelSchema } from "./schema/channelSchema";
import { generateTopicSchema } from "./schema/topicSchema";
import { generatePlaylistSchema } from "./schema/playlistSchema";
import { generateCommunityPostSchema } from "./schema/communityPostSchema";
import { generateOrganizationSchema } from "./schema/organizationSchema";
import { buildSemanticSsrHtml } from "./render/htmlRenderer";
import { getCachedSnapshot, saveSnapshot, computeEtag } from "./cache/storageCache";
import { logSeoEvent } from "./monitor/searchHealth";
import {
  generateSitemapIndex,
  generateStaticSitemap,
  generateVideosSitemapShard,
  generateChannelsSitemapShard,
  generateTopicsSitemap,
  generatePlaylistsSitemap,
  generateCommunityPostsSitemapShard
} from "./sitemap/sitemapGenerator";

let cachedIndexHtml: string | null = null;

async function fetchIndexHtml(): Promise<string> {
  if (cachedIndexHtml) return cachedIndexHtml;
  try {
    // Read index.html directly from the default hosting bucket
    // to avoid circular dependency when seoServer rewrites intercept the fetch.
    const bucket = admin.storage().bucket("truthworld-1.firebasestorage.app");
    const file = bucket.file("hosting/index.html");
    const [exists] = await file.exists();
    if (exists) {
      const [buffer] = await file.download();
      cachedIndexHtml = buffer.toString("utf8");
      return cachedIndexHtml!;
    }
  } catch (e) {
    console.warn("Failed to read index.html from Storage, trying HTTP", e);
  }

  // Fallback: fetch via HTTP with a direct path that bypasses rewrites
  try {
    const response = await axios.get(`${DOMAIN}/index.html`, {
      headers: { "X-Firebase-Hosting-Redirect": "bypass" },
      timeout: 5000,
    });
    cachedIndexHtml = response.data;
    return cachedIndexHtml!;
  } catch (e) {
    console.error("Failed to fetch index.html via HTTP", e);
  }

  // Last resort: return minimal HTML that bootstraps Flutter
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <base href="/" />
  <title>Truthworld</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>html, body { width: 100%; height: 100%; margin: 0; background: #0D0014; }</style>
</head>
<body>
  <script src="flutter_bootstrap.js"></script>
</body>
</html>`;
}


function sendHtmlResponse(req: Request, res: Response, html: string, etagStr: string, lastModifiedStr: string): void {
  const clientEtag = req.headers["if-none-match"];
  if (clientEtag && clientEtag === etagStr) {
    res.status(304).end();
    return;
  }

  res.set("ETag", etagStr);
  res.set("Last-Modified", lastModifiedStr);
  res.set("Cache-Control", "public, max-age=300, s-maxage=3600");
  res.set("Content-Type", "text/html; charset=utf-8");
  res.status(200).send(html);
}

// ─── Dynamic Image Resolution Helpers for Social Link Previews ─────────────
function ensureAbsoluteImageUrl(url?: string): string | undefined {
  if (!url || typeof url !== "string" || url.trim().length === 0) return undefined;
  const trimmed = url.trim();
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
    return trimmed;
  }
  if (trimmed.startsWith("/")) {
    return `${DOMAIN}${trimmed}`;
  }
  return `${DOMAIN}/${trimmed}`;
}

async function resolveVideoImage(db: admin.firestore.Firestore, data: any): Promise<string | undefined> {
  let img = ensureAbsoluteImageUrl(
    data.thumbnailUrl ||
    data.thumbnail ||
    data.thumbnail_url ||
    data.posterUrl ||
    data.coverUrl ||
    data.imageUrl ||
    data.previewUrl ||
    data.mediaUrl ||
    data.media?.thumbnailUrl ||
    data.bannerUrl
  );
  if (img) return img;

  // Fallback to channel avatar/banner if video thumbnail is missing
  if (data.channelId) {
    try {
      const cDoc = await db.collection("channels").doc(data.channelId).get();
      if (cDoc.exists) {
        const cData = cDoc.data()!;
        img = ensureAbsoluteImageUrl(
          cData.bannerUrl ||
          cData.coverUrl ||
          cData.banner ||
          cData.avatarUrl ||
          cData.photoUrl ||
          cData.profile?.photoUrl ||
          cData.profilePicture ||
          cData.imageUrl
        );
        if (img) return img;
      }
    } catch (_) {}
  }
  return undefined;
}

async function resolveChannelImage(db: admin.firestore.Firestore, channelId: string, docData: any): Promise<string | undefined> {
  // 1. Direct channel banner fields (16:9 widescreen for high-impact social preview cards)
  let bannerImg = ensureAbsoluteImageUrl(
    docData.bannerUrl ||
    docData.bannerImage ||
    docData.coverUrl ||
    docData.banner ||
    docData.coverImage
  );
  if (bannerImg) return bannerImg;

  // 2. Fallback to channel's latest public video thumbnail (16:9 widescreen)
  try {
    const vSnap = await db.collection("videos")
      .where("channelId", "==", channelId)
      .where("visibility", "==", "public")
      .orderBy("uploadedAt", "desc")
      .limit(1)
      .get();
    if (!vSnap.empty) {
      const vData = vSnap.docs[0].data();
      const vImg = ensureAbsoluteImageUrl(
        vData.thumbnailUrl ||
        vData.thumbnail ||
        vData.thumbnail_url ||
        vData.posterUrl ||
        vData.coverUrl ||
        vData.imageUrl
      );
      if (vImg) return vImg;
    }
  } catch (_) {}

  // 3. Fallback to channel avatar / profile photo
  let avatarImg = ensureAbsoluteImageUrl(
    docData.avatarUrl ||
    docData.avatarImage ||
    docData.photoUrl ||
    docData.profile?.photoUrl ||
    docData.profilePicture ||
    docData.imageUrl ||
    docData.iconUrl
  );
  if (avatarImg) return avatarImg;

  // 4. Default brand OG image
  return `${DOMAIN}/icons/og-image.png`;
}

async function resolvePlaylistImage(db: admin.firestore.Firestore, playlistId: string, data: any): Promise<string | undefined> {
  // 1. Direct playlist image fields
  let img = ensureAbsoluteImageUrl(
    data.thumbnailUrl ||
    data.thumbnail ||
    data.coverUrl ||
    data.bannerUrl ||
    data.imageUrl ||
    data.iconUrl
  );
  if (img) return img;

  // 2. Check inline videos array in playlist doc
  if (Array.isArray(data.videos) && data.videos.length > 0) {
    const firstV = data.videos[0];
    img = ensureAbsoluteImageUrl(
      firstV.thumbnailUrl ||
      firstV.thumbnail ||
      firstV.coverUrl ||
      firstV.imageUrl
    );
    if (img) return img;
  }

  // 3. Check inline videoIds array in playlist doc
  if (Array.isArray(data.videoIds) && data.videoIds.length > 0) {
    try {
      const vDoc = await db.collection("videos").doc(data.videoIds[0]).get();
      if (vDoc.exists) {
        const vData = vDoc.data()!;
        img = ensureAbsoluteImageUrl(
          vData.thumbnailUrl ||
          vData.thumbnail ||
          vData.thumbnail_url ||
          vData.posterUrl ||
          vData.coverUrl ||
          vData.imageUrl
        );
        if (img) return img;
      }
    } catch (_) {}
  }

  // 4. Query videos in this playlist
  try {
    const vSnap = await db.collection("videos")
      .where("playlistId", "==", playlistId)
      .limit(1)
      .get();
    if (!vSnap.empty) {
      const vData = vSnap.docs[0].data();
      img = ensureAbsoluteImageUrl(
        vData.thumbnailUrl ||
        vData.thumbnail ||
        vData.thumbnail_url ||
        vData.posterUrl ||
        vData.coverUrl ||
        vData.imageUrl
      );
      if (img) return img;
    }
  } catch (_) {}

  return undefined;
}

export const seoServer = onRequest(
  {
    region: "asia-south1",
    memory: "512MiB",
  },
  async (req: Request, res: Response): Promise<void> => {
    const startTime = Date.now();
    try {
      const path = req.path;
      const lowerPath = path.toLowerCase();
      const host = (req.hostname || req.headers.host || "").toLowerCase();
      const canonicalUrl = normalizeUrl(host, path, req.query);

      // ─── 0. Digital Asset Links & App Site Association ─────────────────────────
      if (path === "/.well-known/assetlinks.json") {
        res.set("Content-Type", "application/json");
        res.set("Cache-Control", "public, max-age=86400");
        res.status(200).send(JSON.stringify([
          {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
              "namespace": "android_app",
              "package_name": "com.example.truthworld",
              "sha256_cert_fingerprints": [
                "10:ED:17:F1:C9:46:1A:11:80:C1:F6:41:09:59:E4:FA:21:40:9D:6F:02:4B:92:4B:FA:05:8B:71:0D:37:A1:AC",
                "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C"
              ]
            }
          }
        ]));
        return;
      }
      if (path === "/.well-known/apple-app-site-association") {
        res.set("Content-Type", "application/json");
        res.set("Cache-Control", "public, max-age=86400");
        res.status(200).send(JSON.stringify({
          "applinks": {
            "apps": [],
            "details": [
              {
                "appID": "TEAMID.com.example.truthworld",
                "paths": ["/watch/*", "/channel/*", "/@*", "/c/*", "/user/*", "/playlist/*", "/topic/*", "/topics/*", "/T/*", "/t/*", "/studio/*", "/advertiser/*", "/ads/*"]
              }
            ]
          }
        }));
        return;
      }
      if (path === "/truthworld_indexnow_key_2026.txt") {
        res.set("Content-Type", "text/plain");
        res.set("Cache-Control", "public, max-age=86400");
        res.status(200).send("truthworld_indexnow_key_2026");
        return;
      }

      // ─── 1. Sitemaps & RSS Feeds ─────────────────────────────────────────────
      if (path === "/sitemap.xml") {
        const xml = await generateSitemapIndex();
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path === "/sitemap-static.xml") {
        const xml = await generateStaticSitemap();
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path.startsWith("/sitemap-videos")) {
        const xml = await generateVideosSitemapShard(admin.firestore());
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path.startsWith("/sitemap-channels")) {
        const xml = await generateChannelsSitemapShard(admin.firestore());
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path.startsWith("/sitemap-topics")) {
        const xml = await generateTopicsSitemap(admin.firestore());
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path.startsWith("/sitemap-playlists")) {
        const xml = await generatePlaylistsSitemap(admin.firestore());
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path.startsWith("/sitemap-community")) {
        const xml = await generateCommunityPostsSitemapShard(admin.firestore());
        res.set("Content-Type", "application/xml");
        res.set("Cache-Control", "public, max-age=1800");
        res.status(200).send(xml);
        return;
      }
      if (path === "/feeds/videos.xml") {
        try {
          const bucket = admin.storage().bucket();
          const file = bucket.file("seo/rss/videos.xml");
          const [exists] = await file.exists();
          if (exists) {
            const [buffer] = await file.download();
            res.set("Content-Type", "application/rss+xml; charset=utf-8");
            res.set("Cache-Control", "public, max-age=1800");
            res.status(200).send(buffer.toString("utf8"));
            return;
          }
        } catch (err) {
          console.error("RSS fetch error", err);
        }
      }

      // ─── 2. Route Handling with 3-Tier Caching ────────────────────────────────
      const db = admin.firestore();
      const orgSchemas = generateOrganizationSchema();

      // EMBED ROUTE (/embed/:videoId, /embed/watch?v=..., /embed?v=...)
      if (lowerPath.startsWith("/embed")) {
        let videoId = (req.query.v || req.query.id) as string;
        if (!videoId) {
          const parts = path.split("/").filter(p => p.length > 0);
          if (parts.length >= 2 && parts[0].toLowerCase() === "embed" && parts[1].toLowerCase() !== "watch") {
            videoId = parts[1];
          }
        }

        if (videoId) {
          let docData: any = null;
          let docId = videoId;

          // Lookup video
          const docDirect = await db.collection("videos").doc(videoId).get();
          if (docDirect.exists) {
            docId = docDirect.id;
            docData = docDirect.data();
          } else {
            const qs = await db.collection("videos").where("videoId", "==", videoId).limit(1).get();
            if (!qs.empty) {
              docId = qs.docs[0].id;
              docData = qs.docs[0].data();
            } else {
              const qs2 = await db.collection("videos").where("id", "==", videoId).limit(1).get();
              if (!qs2.empty) {
                docId = qs2.docs[0].id;
                docData = qs2.docs[0].data();
              }
            }
          }

          if (docData) {
            const status = (docData.status || "").toLowerCase();
            const visibility = (docData.visibility || "").toLowerCase();

            if (status === "deleted" || visibility === "private") {
              res.status(404).send("Video not available");
              return;
            }

            const videoImage = await resolveVideoImage(db, docData);
            const videoUrl = docData.hlsUrl || docData.originalUrl || docData.videoUrl || "";
            const rawTitle = (docData.title || "Truthworld Video").trim();

            const isHls = videoUrl.includes(".m3u8") || videoUrl.includes("hls");

            const embedHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="referrer" content="no-referrer-when-downgrade" />
  <title>${escapeHtml(rawTitle)} - Truthworld Player</title>
  <meta name="robots" content="noindex, follow" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    .player-wrap { position: relative; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }
    video { width: 100%; height: 100%; max-height: 100%; object-fit: contain; background: #000; }
  </style>
  ${isHls ? `<script src="https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js"><\/script>` : ""}
</head>
<body>
  <div class="player-wrap">
    <video id="tw-player" controls playsinline ${videoImage ? `poster="${escapeHtml(videoImage)}"` : ""} preload="metadata">
      ${videoUrl ? (isHls
        ? `<source src="${escapeHtml(videoUrl)}" type="application/x-mpegURL" />`
        : `<source src="${escapeHtml(videoUrl)}" type="video/mp4" />`)
      : ""}
      <p style="color: #fff; text-align: center;">Watch on <a href="${DOMAIN}/watch?v=${escapeHtml(docId)}" target="_blank" style="color: #9B30FF;">Truthworld</a></p>
    </video>
  </div>
  ${isHls ? `<script>
    (function() {
      var video = document.getElementById('tw-player');
      var src = '${escapeHtml(videoUrl)}';
      if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = src;
      } else if (typeof Hls !== 'undefined' && Hls.isSupported()) {
        var hls = new Hls();
        hls.loadSource(src);
        hls.attachMedia(video);
      }
    })();
  <\/script>` : ""}
</body>
</html>`;

            res.set("Content-Type", "text/html; charset=utf-8");
            res.set("Content-Security-Policy", "default-src 'self' 'unsafe-inline' https: data: blob:; frame-ancestors *;");
            res.set("Access-Control-Allow-Origin", "*");
            res.set("X-Frame-Options", "ALLOWALL");
            res.set("Cache-Control", "public, max-age=600, s-maxage=3600");
            res.status(200).send(embedHtml);
            return;
          } else {
            res.status(404).send("Video not found");
            return;
          }
        } else {
          res.status(404).send("Video not found");
          return;
        }
      }

      // WATCH / V / SHORTS ROUTE
      if (lowerPath.startsWith("/watch") || lowerPath.startsWith("/v/") || lowerPath.startsWith("/shorts/")) {
        let videoId = (req.query.v || req.query.id) as string;
        if (!videoId) {
          const parts = path.split("/").filter(p => p.length > 0);
          const p0 = parts.length > 0 ? parts[0].toLowerCase() : "";
          if (parts.length >= 2 && (p0 === "watch" || p0 === "v" || p0 === "shorts")) {
            videoId = parts[1];
          }
        }
        if (videoId) {
          const cacheKey = `watch_v2_${videoId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          logSeoEvent({ eventType: "cache_miss", path: canonicalUrl, durationMs: Date.now() - startTime });
          let docData: any = null;
          let docId = videoId;

          // 1. Direct doc lookup by ID
          const docDirect = await db.collection("videos").doc(videoId).get();
          if (docDirect.exists) {
            docId = docDirect.id;
            docData = docDirect.data();
          }

          // 2. Query by videoId field
          if (!docData) {
            const qs = await db.collection("videos").where("videoId", "==", videoId).limit(1).get();
            if (!qs.empty) {
              docId = qs.docs[0].id;
              docData = qs.docs[0].data();
            }
          }

          // 3. Query by id field
          if (!docData) {
            const qs = await db.collection("videos").where("id", "==", videoId).limit(1).get();
            if (!qs.empty) {
              docId = qs.docs[0].id;
              docData = qs.docs[0].data();
            }
          }

          if (docData) {
            const status = (docData.status || "").toLowerCase();
            const visibility = (docData.visibility || "").toLowerCase();

            if (status === "deleted" || visibility === "private") {
              const baseHtml = await fetchIndexHtml();
              res.status(404).send(baseHtml);
              return;
            }

            let channelName = docData.channelName || "Channel";
            let channelHandle = "";
            let channelIsBrand = false;
            if (docData.channelId) {
              const cDoc = await db.collection("channels").doc(docData.channelId).get();
              if (cDoc.exists) {
                const cData = cDoc.data()!;
                channelName = cData.displayName || cData.name || channelName;
                channelHandle = cData.handle || "";
                channelIsBrand = cData.isBrand === true || cData.creatorType === "Organization" || cData.type === "custom";
              }
            }
            const authorUrl = channelHandle 
              ? `${DOMAIN}/${channelHandle.startsWith("@") ? channelHandle : `@${channelHandle}`}`
              : `${DOMAIN}/channel/${docData.channelId}`;

            const rawTitle = (docData.title || "Video").trim();
            const videoDurationSec = docData.durationMs ? Math.floor(docData.durationMs / 1000) : (docData.duration || 0);
            const viewCount = docData.viewCount || docData.views || 0;
            const viewCountStr = viewCount >= 1000000
              ? `${(viewCount / 1000000).toFixed(1).replace(/\.0$/, "")}M views`
              : viewCount >= 1000
                ? `${(viewCount / 1000).toFixed(1).replace(/\.0$/, "")}K views`
                : `${viewCount} view${viewCount === 1 ? "" : "s"}`;

            const durationFormatted = videoDurationSec > 0
              ? `${Math.floor(videoDurationSec / 60)}:${(videoDurationSec % 60).toString().padStart(2, "0")}`
              : "";

            // Format Video Title cleanly
            let pageTitle = `${rawTitle} - Truthworld`;
            if (channelName && channelName !== "Channel" && !rawTitle.toLowerCase().includes(channelName.toLowerCase())) {
              pageTitle = `${rawTitle} - ${channelName} | Truthworld`;
            }

            // Rich Industry Standard Description
            const rawDesc = (docData.description || "").trim();
            let pageDescription = `Watch "${rawTitle}" by ${channelName} on Truthworld. Stream verified family-safe video.`;
            if (rawDesc) {
              pageDescription = `${rawDesc} • Video by ${channelName}${viewCountStr ? ` • ${viewCountStr}` : ""}${durationFormatted ? ` • ${durationFormatted}` : ""} • Truthworld`;
            } else {
              pageDescription = `Watch "${rawTitle}" by ${channelName} on Truthworld. • ${viewCountStr}${durationFormatted ? ` • ${durationFormatted}` : ""} • Family-safe verified video platform.`;
            }

            const videoImage = await resolveVideoImage(db, docData);
            const videoSchema = generateVideoSchema({ ...docData, id: docId } as any, authorUrl, channelName, channelIsBrand);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: authorUrl },
              { name: rawTitle, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalUrl,
              image: videoImage,
              imageWidth: 1280,
              imageHeight: 720,
              type: "video.other",
              videoUrl: docData.hlsUrl || docData.originalUrl || docData.videoUrl,
              embedUrl: `${DOMAIN}/embed/${docId}`,
              durationSeconds: videoDurationSec,
              uploadDate: formatDate(docData.uploadedAt || docData.createdAt),
              robots: visibility === "unlisted" ? "noindex, nofollow" : "index, follow",
              jsonLd: [videoSchema, breadcrumbs.jsonLd, ...orgSchemas],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: rawTitle,
              authorName: channelName,
              authorUrl: authorUrl,
              transcriptExcerpt: docData.transcript || docData.captionsText
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            const notFoundHtml = buildSemanticSsrHtml({
              title: "Video Not Found - Truthworld",
              description: "The requested video could not be found or is no longer available on Truthworld.",
              url: canonicalUrl,
              type: "website",
              robots: "noindex, follow",
              jsonLd: orgSchemas
            });
            res.status(404).send(notFoundHtml);
            return;
          }
        } else {
          const baseHtml = await fetchIndexHtml();
          res.status(404).send(baseHtml);
          return;
        }
      }

      // CHANNEL / HANDLE ROUTE
      if (lowerPath.startsWith("/channel/") || path.startsWith("/@") || lowerPath.startsWith("/c/") || lowerPath.startsWith("/user/")) {
        let handleOrId = "";
        if (path.startsWith("/@")) {
          handleOrId = path.substring(2);
        } else {
          handleOrId = path.split("/")[2];
        }

        if (handleOrId) {
          const cacheKey = `channel_v2_${handleOrId.toLowerCase().replace(/^@/, "")}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let docData: any = null;

          // 1. Direct doc lookup by ID
          const docDirect = await db.collection("channels").doc(handleOrId).get();
          if (docDirect.exists) {
            docData = { id: docDirect.id, ...(docDirect.data() as any) };
          }

          // 2. Query by handleLowercase
          if (!docData) {
            const cleanHandle = handleOrId.toLowerCase().replace(/^@/, "");
            const qs = await db.collection("channels").where("handleLowercase", "==", cleanHandle).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 3. Query by handle exact
          if (!docData) {
            const cleanHandle = handleOrId.replace(/^@/, "");
            const qs = await db.collection("channels").where("handle", "==", cleanHandle).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 4. Query by id field
          if (!docData) {
            const qs = await db.collection("channels").where("id", "==", handleOrId).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 5. Query by customUrlLowercase
          if (!docData) {
            const cleanHandle = handleOrId.toLowerCase().replace(/^@/, "");
            const qs = await db.collection("channels").where("customUrlLowercase", "==", cleanHandle).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          if (docData && docData.status !== "deleted" && docData.status !== "suspended") {
            const rawChannelName = (docData.displayName || docData.name || docData.channelName || "Channel").trim();
            const channelName = (rawChannelName.toLowerCase().startsWith("untitled") || !rawChannelName)
              ? "Truthworld Channel"
              : rawChannelName;
            
            const handle = (docData.handle || "").replace(/^@/, "").trim();
            const handleWithAt = handle ? `@${handle}` : "";
            const canonicalChannelUrl = handle ? `${DOMAIN}/@${handle}` : canonicalUrl;

            // Format Title cleanly avoiding redundant "Truthworld - Truthworld"
            let pageTitle: string;
            if (channelName.toLowerCase() === "truthworld" || channelName.toLowerCase() === "truth world") {
              pageTitle = handleWithAt 
                ? `Truthworld (${handleWithAt}) - Official Video Channel` 
                : `Truthworld - Official Video Channel | Truthworld`;
            } else if (handleWithAt) {
              pageTitle = `${channelName} (${handleWithAt}) - Truthworld`;
            } else {
              pageTitle = `${channelName} - Truthworld`;
            }

            // Extract subscriber & video metrics
            const subscriberCount = docData.subscriberCount || docData.subscribers || docData.stats?.subscriberCount || 0;
            const videoCount = docData.videoCount || 0;
            const subStr = subscriberCount >= 1000000 
              ? `${(subscriberCount / 1000000).toFixed(1).replace(/\.0$/, "")}M Subscribers`
              : subscriberCount >= 1000
                ? `${(subscriberCount / 1000).toFixed(1).replace(/\.0$/, "")}K Subscribers`
                : `${subscriberCount} Subscriber${subscriberCount === 1 ? "" : "s"}`;
            const vidStr = `${videoCount} Video${videoCount === 1 ? "" : "s"}`;

            // Build rich industry-standard description
            const rawBio = (docData.about || docData.description || "").trim();
            let pageDescription: string;
            if (rawBio) {
              pageDescription = `${rawBio} • ${subStr} • ${vidStr} on Truthworld.`;
            } else {
              pageDescription = `Watch family-safe, verified videos from ${channelName} on Truthworld. • ${subStr} • ${vidStr}`;
            }

            const channelImage = await resolveChannelImage(db, docData.id, docData);
            const channelSchema = generateChannelSchema(docData, canonicalChannelUrl, channelImage);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: canonicalChannelUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalChannelUrl,
              image: channelImage,
              imageWidth: 1280,
              imageHeight: 720,
              type: "profile",
              robots: "index, follow",
              jsonLd: [channelSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: `${channelName}${handleWithAt ? ` (${handleWithAt})` : ""}`,
              authorName: channelName,
              authorUrl: canonicalChannelUrl
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            const notFoundHtml = buildSemanticSsrHtml({
              title: "Channel Not Found - Truthworld",
              description: "The requested channel could not be found or has been removed from Truthworld.",
              url: canonicalUrl,
              type: "website",
              robots: "noindex, follow",
              jsonLd: orgSchemas
            });
            res.status(404).send(notFoundHtml);
            return;
          }
        }
      }

      // TOPIC ROUTE
      if (lowerPath.startsWith("/topic") || lowerPath.startsWith("/topics") || lowerPath.startsWith("/t/")) {
        let slug = (req.query.id || req.query.slug) as string;
        if (!slug) {
          const parts = path.split("/").filter(p => p.length > 0);
          if (parts.length >= 2) {
            slug = parts[1];
          } else if (parts.length === 1 && (parts[0].toLowerCase() !== "topic" && parts[0].toLowerCase() !== "topics" && parts[0].toLowerCase() !== "t")) {
            slug = parts[0];
          }
        }

        if (slug) {
          const cleanSlug = slug.replace(/^(T\/|t\/)/i, "").trim();
          const cacheKey = `topic_v3_${cleanSlug.toLowerCase()}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let docData: any = null;

          // 1. Direct doc lookup by ID
          const docDirect = await db.collection("topics").doc(cleanSlug).get();
          if (docDirect.exists) {
            docData = { id: docDirect.id, ...(docDirect.data() as any) };
          }

          // 2. Query by slug exact
          if (!docData) {
            const qs = await db.collection("topics").where("slug", "==", cleanSlug).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 3. Query by slug lowercase
          if (!docData) {
            const qsLower = await db.collection("topics").where("slug", "==", cleanSlug.toLowerCase()).limit(1).get();
            if (!qsLower.empty) docData = { id: qsLower.docs[0].id, ...(qsLower.docs[0].data() as any) };
          }

          // 4. Query by handle or handleLowercase
          if (!docData) {
            const qsHandle = await db.collection("topics").where("handleLowercase", "==", `t/${cleanSlug.toLowerCase()}`).limit(1).get();
            if (!qsHandle.empty) docData = { id: qsHandle.docs[0].id, ...(qsHandle.docs[0].data() as any) };
          }

          if (docData && docData.status !== "deleted" && docData.status !== "inactive" && docData.status !== "archived" && docData.status !== "verificationRejected") {
            const rawTitle = (docData.title || docData.name || "Topic").trim();
            const cleanTitle = rawTitle.replace(/^[#Tt]\//, "").trim();
            const topVideos: any[] = [];
            const topicKeys = [docData.slug, cleanSlug, docData.id].filter(Boolean);

            for (const key of topicKeys) {
              if (topVideos.length >= 10) break;
              try {
                const vSnap = await db.collection("videos")
                  .where("topics", "array-contains", key)
                  .orderBy("uploadedAt", "desc")
                  .limit(15).get();
                vSnap.forEach((d) => {
                  const data = d.data();
                  const vis = (data.visibility || "public").toLowerCase();
                  const st = (data.status || "").toLowerCase();
                  if (vis === "public" && st !== "deleted" && st !== "draft" && !topVideos.some(tv => tv.id === d.id)) {
                    topVideos.push({ id: d.id, ...data });
                  }
                });
              } catch (err) {
                try {
                  const fallbackSnap = await db.collection("videos")
                    .where("topics", "array-contains", key)
                    .limit(15).get();
                  fallbackSnap.forEach((d) => {
                    const data = d.data();
                    const vis = (data.visibility || "public").toLowerCase();
                    const st = (data.status || "").toLowerCase();
                    if (vis === "public" && st !== "deleted" && st !== "draft" && !topVideos.some(tv => tv.id === d.id)) {
                      topVideos.push({ id: d.id, ...data });
                    }
                  });
                } catch (fallbackErr) {
                  console.error("Error fetching topic videos fallback", fallbackErr);
                }
              }
            }

            // Zero-video topic guard: Do not index or serve empty topic SEO pages
            if (topVideos.length === 0 && (Number(docData.videoCount) || 0) <= 0) {
              const notFoundHtml = buildSemanticSsrHtml({
                title: "Topic Not Found - Truthworld",
                description: "The requested topic could not be found or has been removed from Truthworld.",
                url: canonicalUrl,
                type: "website",
                robots: "noindex, follow",
                jsonLd: orgSchemas
              });
              res.status(404).send(notFoundHtml);
              return;
            }

            const rawTopicImg = docData.thumbnailUrl ||
              docData.coverImage ||
              docData.imageUrl ||
              docData.iconUrl ||
              docData.bannerUrl ||
              (topVideos.length > 0 ? (topVideos[0].thumbnailUrl || topVideos[0].thumbnail || topVideos[0].coverUrl) : undefined);

            const topicImage = ensureAbsoluteImageUrl(rawTopicImg);
            const videoCount = docData.videoCount || topVideos.length || 0;
            const followerCount = docData.followerCount || 0;
            const vidStr = `${videoCount} Video${videoCount === 1 ? "" : "s"}`;
            const folStr = followerCount >= 1000
              ? `${(followerCount / 1000).toFixed(1).replace(/\.0$/, "")}K Followers`
              : `${followerCount} Follower${followerCount === 1 ? "" : "s"}`;

            const rawDesc = (docData.description || "").trim();
            let topicDescription: string;
            if (rawDesc) {
              topicDescription = `${rawDesc} • #${cleanTitle} • ${folStr} • ${vidStr} on Truthworld.`;
            } else {
              topicDescription = `Explore top videos and discussions in #${cleanTitle} on Truthworld. • ${folStr} • ${vidStr} • Verified family-safe content.`;
            }

            const topicSchema = generateTopicSchema(docData, canonicalUrl, topVideos);
            const breadcrumbs = generateBreadcrumbData([
              { name: `#${cleanTitle}`, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `#${cleanTitle} - Topic | Truthworld`,
              description: topicDescription,
              url: canonicalUrl,
              image: topicImage,
              imageWidth: 1280,
              imageHeight: 720,
              type: "website",
              robots: "index, follow",
              jsonLd: [topicSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: `#${cleanTitle} Topic`,
              relatedItems: topVideos.map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` }))
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            const notFoundHtml = buildSemanticSsrHtml({
              title: "Topic Not Found - Truthworld",
              description: "The requested topic could not be found or has been removed from Truthworld.",
              url: canonicalUrl,
              type: "website",
              robots: "noindex, follow",
              jsonLd: orgSchemas
            });
            res.status(404).send(notFoundHtml);
            return;
          }
        }
      }

      // PLAYLIST ROUTE
      if (lowerPath.startsWith("/playlist")) {
        let playlistId = req.query.list as string;
        if (!playlistId && path.split("/").length > 2) {
          playlistId = path.split("/")[2];
        }
        if (playlistId) {
          const cacheKey = `playlist_v3_${playlistId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let docData: any = null;

          // 1. Check playlists by doc ID
          const docPriv = await db.collection("playlists").doc(playlistId).get();
          if (docPriv.exists) {
            docData = { id: docPriv.id, ...(docPriv.data() as any) };
          }

          // 2. Check public_playlists by doc ID
          if (!docData) {
            const docPub = await db.collection("public_playlists").doc(playlistId).get();
            if (docPub.exists) {
              docData = { id: docPub.id, ...(docPub.data() as any) };
            }
          }

          // 3. Query playlists by playlistId field
          if (!docData) {
            const qs = await db.collection("playlists").where("playlistId", "==", playlistId).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 4. Query public_playlists by playlistId field
          if (!docData) {
            const qs = await db.collection("public_playlists").where("playlistId", "==", playlistId).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 5. Query channel_playlists by doc ID
          if (!docData) {
            const docCp = await db.collection("channel_playlists").doc(playlistId).get();
            if (docCp.exists) docData = { id: docCp.id, ...(docCp.data() as any) };
          }

          if (docData && docData.status !== "deleted") {
            let videoItems: Array<{ id: string; title: string }> = [];
            if (Array.isArray(docData.videos) && docData.videos.length > 0) {
              videoItems = docData.videos.map((v: any) => ({
                id: v.id || v.videoId || "",
                title: v.title || v.name || `Video ${v.id || ""}`
              })).filter((v: any) => v.id);
            } else if (Array.isArray(docData.videoIds) && docData.videoIds.length > 0) {
              const idsToFetch = docData.videoIds.slice(0, 20);
              try {
                const videoDocRefs = idsToFetch.map((vid: string) => db.collection("videos").doc(vid));
                const videoDocs = await db.getAll(...videoDocRefs);
                videoDocs.forEach((vd) => {
                  if (vd.exists) {
                    const vdData = vd.data()!;
                    videoItems.push({
                      id: vd.id,
                      title: vdData.title || `Video ${vd.id}`
                    });
                  }
                });
              } catch (fetchErr) {
                console.warn("Could not batch fetch playlist video titles:", fetchErr);
                videoItems = idsToFetch.map((id: string) => ({ id, title: `Video ${id}` }));
              }
            }

            const playlistName = (docData.playlistName || docData.name || docData.title || "Playlist").trim();
            const playlistImage = await resolvePlaylistImage(db, docData.id, docData);
            const playlistSchema = generatePlaylistSchema({ id: docData.id, ...docData, videos: videoItems }, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: playlistName, url: canonicalUrl }
            ]);

            const videoCount = docData.videoCount || (Array.isArray(docData.videos) ? docData.videos.length : (Array.isArray(docData.videoIds) ? docData.videoIds.length : videoItems.length));
            const vidStr = `${videoCount} Video${videoCount === 1 ? "" : "s"}`;
            const channelName = docData.channelName || docData.creatorName || "";

            const rawDesc = (docData.description || "").trim();
            let pageDescription: string;
            if (rawDesc) {
              pageDescription = `${rawDesc} • Playlist${channelName ? ` by ${channelName}` : ""} • ${vidStr} on Truthworld.`;
            } else {
              pageDescription = `Watch the "${playlistName}" playlist${channelName ? ` by ${channelName}` : ""} on Truthworld. • ${vidStr} • Verified video platform.`;
            }

            const pageTitle = channelName
              ? `${playlistName} - ${channelName} | Truthworld`
              : `${playlistName} - Playlist | Truthworld`;

            const relatedVideos = videoItems.map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` }));

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalUrl,
              image: playlistImage,
              imageWidth: 1280,
              imageHeight: 720,
              type: "website",
              robots: docData.visibility === "private" ? "noindex, nofollow" : "index, follow",
              jsonLd: [playlistSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: `${playlistName} Playlist`,
              relatedItems: relatedVideos.length > 0 ? relatedVideos : undefined
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            const notFoundHtml = buildSemanticSsrHtml({
              title: "Playlist Not Found - Truthworld",
              description: "The requested playlist could not be found or is private on Truthworld.",
              url: canonicalUrl,
              type: "website",
              robots: "noindex, follow",
              jsonLd: orgSchemas
            });
            res.status(404).send(notFoundHtml);
            return;
          }
        }
      }

      // COMMUNITY POST ROUTE
      if (lowerPath.startsWith("/post") || lowerPath.startsWith("/community")) {
        let postId = req.query.id as string;
        if (!postId && path.split("/").length > 2) {
          postId = path.split("/")[2];
        }
        if (postId) {
          const cacheKey = `post_${postId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let doc = await db.collection("Community").doc(postId).get();
          if (!doc.exists) {
            doc = await db.collection("community_posts").doc(postId).get();
          }

          if (doc.exists) {
            const data = doc.data()!;
            const status = (data.status || "").toLowerCase();
            const isPrivate = (data.visibility || "").toLowerCase() === "private";

            if (status === "deleted" || status === "rejected") {
              const notFoundHtml = buildSemanticSsrHtml({
                title: "Community Post Not Found - Truthworld",
                description: "The requested community post could not be found or has been removed from Truthworld.",
                url: canonicalUrl,
                type: "website",
                robots: "noindex, follow",
                jsonLd: orgSchemas
              });
              res.status(404).send(notFoundHtml);
              return;
            }

            const postTitle = data.title || (data.description ? data.description.substring(0, 80) : "Community Post");
            const authorName = data.channelName || "Channel";
            const authorUrl = data.channelId ? `${DOMAIN}/channel/${data.channelId}` : DOMAIN;
            const postSchema = generateCommunityPostSchema({ id: doc.id, ...data }, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: authorName, url: authorUrl },
              { name: postTitle, url: canonicalUrl }
            ]);

            const image = (data.images && data.images.length > 0) ? data.images[0] : (data.image || data.channelImage);

            const finalHtml = buildSemanticSsrHtml({
              title: `${postTitle} - Post by ${authorName} | Truthworld`,
              description: data.description || `Community post by ${authorName} on Truthworld.`,
              url: canonicalUrl,
              image: image,
              type: "article",
              robots: isPrivate ? "noindex, nofollow" : "index, follow",
              jsonLd: [postSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: postTitle,
              authorName: authorName,
              authorUrl: authorUrl
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            const notFoundHtml = buildSemanticSsrHtml({
              title: "Community Post Not Found - Truthworld",
              description: "The requested community post could not be found or has been removed from Truthworld.",
              url: canonicalUrl,
              type: "website",
              robots: "noindex, follow",
              jsonLd: orgSchemas
            });
            res.status(404).send(notFoundHtml);
            return;
          }
        }
      }

      // SETTINGS ROUTE (Private Page - Exclude from Search Engines)
      if (lowerPath === "/settings" || lowerPath.startsWith("/settings/")) {
        res.set("X-Robots-Tag", "noindex, nofollow");
        const baseHtml = await fetchIndexHtml();
        res.status(200).send(baseHtml.replace("</head>", '<meta name="robots" content="noindex, nofollow" /></head>'));
        return;
      }

      // STUDIO ROUTE
      if (lowerPath === "/studio" || lowerPath.startsWith("/studio/")) {
        const cacheKey = `studio_page`;
        const cached = await getCachedSnapshot(cacheKey);
        if (cached) {
          logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
          sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
          return;
        }

        const studioBreadcrumbs = generateBreadcrumbData([
          { name: "Truthworld Studio", url: canonicalUrl }
        ]);

        const studioSchema = {
          "@context": "https://schema.org",
          "@type": "WebApplication",
          "name": "Truthworld Studio",
          "url": canonicalUrl,
          "applicationCategory": "MultimediaApplication",
          "operatingSystem": "All",
          "description": "Truthworld Studio gives creators full control over video uploads, channel analytics, monetization, and audience engagement."
        };

        const finalHtml = buildSemanticSsrHtml({
          title: "Truthworld Studio - Creator Dashboard & Analytics",
          description: "Manage your creator channel, upload content, track performance analytics, and engage with viewers on Truthworld Studio.",
          url: canonicalUrl,
          type: "website",
          robots: "index, follow",
          jsonLd: [studioSchema, studioBreadcrumbs.jsonLd, ...orgSchemas],
          breadcrumbHtml: studioBreadcrumbs.html,
          contentHeading: "Truthworld Studio - Creator Dashboard"
        });

        const saved = await saveSnapshot(cacheKey, finalHtml);
        sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
        return;
      }

      // ADVERTISEMENTS / ADVERTISER ROUTE
      if (
        lowerPath === "/advertiser" ||
        lowerPath.startsWith("/advertiser/") ||
        lowerPath === "/advertisements" ||
        lowerPath.startsWith("/advertisements/") ||
        lowerPath === "/ads" ||
        lowerPath.startsWith("/ads/")
      ) {
        const cacheKey = `advertisements_page`;
        const cached = await getCachedSnapshot(cacheKey);
        if (cached) {
          logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
          sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
          return;
        }

        const adBreadcrumbs = generateBreadcrumbData([
          { name: "Truthworld Advertisements", url: canonicalUrl }
        ]);

        const adSchema = {
          "@context": "https://schema.org",
          "@type": "WebApplication",
          "name": "Truthworld Advertisements",
          "url": canonicalUrl,
          "applicationCategory": "BusinessApplication",
          "operatingSystem": "All",
          "description": "Create, manage, and scale high-impact video ad campaigns targeting engaged audiences on Truthworld Advertisements."
        };

        const finalHtml = buildSemanticSsrHtml({
          title: "Truthworld Advertisements - Video Ad Campaigns & Growth",
          description: "Reach engaged viewers with targeted video advertisement campaigns, transparent analytics, and high ROI on Truthworld Advertisements.",
          url: canonicalUrl,
          type: "website",
          robots: "index, follow",
          jsonLd: [adSchema, adBreadcrumbs.jsonLd, ...orgSchemas],
          breadcrumbHtml: adBreadcrumbs.html,
          contentHeading: "Truthworld Advertisements - Video Ad Platform"
        });

        const saved = await saveSnapshot(cacheKey, finalHtml);
        sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
        return;
      }

      // ─── 3. Fallback / Default Homepage HTML ─────────────────────────────────
      const homepageHtml = buildSemanticSsrHtml({
        title: "Truthworld - Watch, Share & Create Verified Videos",
        description: "Watch family-safe videos with AI dubbing in 70+ languages & 100+ subtitles. Automated fact-checking, creator studio tools, and 100% creator revenue.",
        url: canonicalUrl,
        type: "website",
        jsonLd: orgSchemas
      });

      const etagStr = computeEtag(homepageHtml);
      sendHtmlResponse(req, res, homepageHtml, etagStr, new Date().toUTCString());
      return;

    } catch (error) {
      console.error("SEO Server Error:", error);
      const baseHtml = await fetchIndexHtml();
      res.status(200).send(baseHtml);
      return;
    }
  }
);
