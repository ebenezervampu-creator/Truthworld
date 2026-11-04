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
import { renderChannelCardImage } from "./render/channelCardImageRenderer";
import { renderVideoCardImage } from "./render/videoCardImageRenderer";
import { renderTopicCardImage } from "./render/topicCardImageRenderer";
import { renderPlaylistCardImage } from "./render/playlistCardImageRenderer";
import { renderClaimCardImage } from "./render/claimCardImageRenderer";
import { getCachedSnapshot, saveSnapshot } from "./cache/storageCache";
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
  let variantUrl: string | undefined;
  if (Array.isArray(data.thumbnailVariants) && data.thumbnailVariants.length > 0) {
    const first = data.thumbnailVariants[0];
    variantUrl = typeof first === "string" ? first : (first?.url || first?.thumbnailUrl);
  }
  const ytThumb = data.thumbnails?.maxres?.url || data.thumbnails?.standard?.url || data.thumbnails?.high?.url || data.thumbnails?.medium?.url || data.thumbnails?.default?.url;

  let img = ensureAbsoluteImageUrl(
    data.thumbnailUrl ||
    data.thumbnail ||
    data.thumbnail_url ||
    data.posterUrl ||
    variantUrl ||
    ytThumb ||
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

export async function resolveChannelImage(db: admin.firestore.Firestore, channelId: string, docData: any): Promise<string | undefined> {
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

  // 5. Fallback to creator channel avatar or banner
  if (data.channelId) {
    try {
      const cDoc = await db.collection("channels").doc(data.channelId).get();
      if (cDoc.exists) {
        const cData = cDoc.data()!;
        img = ensureAbsoluteImageUrl(
          cData.avatarUrl ||
          cData.avatarImage ||
          cData.channelAvatarUrl ||
          cData.bannerUrl ||
          cData.photoUrl
        );
        if (img) return img;
      }
    } catch (_) {}
  }

  return `${DOMAIN}/icons/og-image.png`;
}

export const seoServer = onRequest(
  {
    region: "asia-south1",
    memory: "512MiB",
    maxInstances: 10,
  },
  async (req: Request, res: Response): Promise<void> => {
    const startTime = Date.now();
    try {
      const path = req.path;
      const lowerPath = path.toLowerCase();
      let decodedPath = path;
      try {
        decodedPath = decodeURIComponent(path);
      } catch (_) {}
      const decodedLowerPath = decodedPath.toLowerCase();
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
              "package_name": "com.truthworld.app",
              "sha256_cert_fingerprints": [
                "0A:BB:3D:F0:30:E7:CD:77:FD:72:CF:01:9D:26:BA:A5:9E:FD:6A:19:5A:C1:C6:00:9C:B9:33:19:F3:C2:B9:2E",
                "E4:A1:36:64:70:A4:34:A6:7A:49:19:A4:5E:2E:F8:C0:4D:0B:3C:2D:E3:F4:4F:FC:65:A2:3F:7E:00:FF:C4:E1",
                "10:ED:17:F1:C9:46:1A:11:80:C1:F6:41:09:59:E4:FA:21:40:9D:6F:02:4B:92:4B:FA:05:8B:71:0D:37:A1:AC",
                "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C"
              ]
            }
          },
          {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
              "namespace": "android_app",
              "package_name": "com.example.truthworld",
              "sha256_cert_fingerprints": [
                "0A:BB:3D:F0:30:E7:CD:77:FD:72:CF:01:9D:26:BA:A5:9E:FD:6A:19:5A:C1:C6:00:9C:B9:33:19:F3:C2:B9:2E",
                "E4:A1:36:64:70:A4:34:A6:7A:49:19:A4:5E:2E:F8:C0:4D:0B:3C:2D:E3:F4:4F:FC:65:A2:3F:7E:00:FF:C4:E1",
                "10:ED:17:F1:C9:46:1A:11:80:C1:F6:41:09:59:E4:FA:21:40:9D:6F:02:4B:92:4B:FA:05:8B:71:0D:37:A1:AC",
                "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C"
              ]
            }
          },
          {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
              "namespace": "android_app",
              "package_name": "com.truthworld.studio",
              "sha256_cert_fingerprints": [
                "0A:BB:3D:F0:30:E7:CD:77:FD:72:CF:01:9D:26:BA:A5:9E:FD:6A:19:5A:C1:C6:00:9C:B9:33:19:F3:C2:B9:2E",
                "E4:A1:36:64:70:A4:34:A6:7A:49:19:A4:5E:2E:F8:C0:4D:0B:3C:2D:E3:F4:4F:FC:65:A2:3F:7E:00:FF:C4:E1",
                "10:ED:17:F1:C9:46:1A:11:80:C1:F6:41:09:59:E4:FA:21:40:9D:6F:02:4B:92:4B:FA:05:8B:71:0D:37:A1:AC",
                "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C"
              ]
            }
          },
          {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
              "namespace": "android_app",
              "package_name": "com.truthworld.advertiser",
              "sha256_cert_fingerprints": [
                "0A:BB:3D:F0:30:E7:CD:77:FD:72:CF:01:9D:26:BA:A5:9E:FD:6A:19:5A:C1:C6:00:9C:B9:33:19:F3:C2:B9:2E",
                "E4:A1:36:64:70:A4:34:A6:7A:49:19:A4:5E:2E:F8:C0:4D:0B:3C:2D:E3:F4:4F:FC:65:A2:3F:7E:00:FF:C4:E1",
                "10:ED:17:F1:C9:46:1A:11:80:C1:F6:41:09:59:E4:FA:21:40:9D:6F:02:4B:92:4B:FA:05:8B:71:0D:37:A1:AC",
                "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C"
              ]
            }
          },
          {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
              "namespace": "android_app",
              "package_name": "com.truthworld.admin",
              "sha256_cert_fingerprints": [
                "0A:BB:3D:F0:30:E7:CD:77:FD:72:CF:01:9D:26:BA:A5:9E:FD:6A:19:5A:C1:C6:00:9C:B9:33:19:F3:C2:B9:2E",
                "E4:A1:36:64:70:A4:34:A6:7A:49:19:A4:5E:2E:F8:C0:4D:0B:3C:2D:E3:F4:4F:FC:65:A2:3F:7E:00:FF:C4:E1",
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
                "appIDs": ["*.com.truthworld.app", "TEAMID.com.truthworld.app"],
                "paths": ["/watch/*", "/channel/*", "/@*", "/c/*", "/user/*", "/playlist/*", "/topic/*", "/topics/*", "/T/*", "/t/*", "/studio/*", "/advertiser/*", "/ads/*", "/post/*", "/community/*", "/claim-detail*", "/claim/*"]
              }
            ]
          },
          "webcredentials": {
            "apps": ["TEAMID.com.truthworld.app"]
          }
        }));
        return;
      }
      if (path === "/.well-known/traffic-advice") {
        res.set("Content-Type", "application/trafficadvice+json");
        res.set("X-Robots-Tag", "noindex, nofollow");
        res.set("Cache-Control", "public, max-age=86400");
        res.status(200).send(JSON.stringify([
          {
            "user_agent": "prefetch-proxy",
            "google_prefetch_proxy_eap": {
              "fraction": 1.0
            }
          }
        ]));
        return;
      }
      if (path.startsWith("/.well-known/")) {
        res.set("X-Robots-Tag", "noindex, nofollow");
        res.status(404).send("Not Found");
        return;
      }
      if (path === "/truthworld-indexnow-key-2026.txt") {
        res.set("Content-Type", "text/plain");
        res.set("Cache-Control", "public, max-age=86400");
        res.status(200).send("truthworld-indexnow-key-2026");
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

      // WATCH / V / SHORTS / CLIP / CHAPTER ROUTE & DYNAMIC VIDEO CARD IMAGE
      if (
        lowerPath.startsWith("/watch") ||
        decodedLowerPath.startsWith("/watch") ||
        lowerPath.startsWith("/v/") ||
        decodedLowerPath.startsWith("/v/") ||
        lowerPath.startsWith("/shorts/") ||
        decodedLowerPath.startsWith("/shorts/") ||
        lowerPath.startsWith("/clip/") ||
        decodedLowerPath.startsWith("/clip/") ||
        lowerPath.startsWith("/clips/") ||
        decodedLowerPath.startsWith("/clips/") ||
        lowerPath.startsWith("/chapter/") ||
        decodedLowerPath.startsWith("/chapter/") ||
        lowerPath.startsWith("/chapters/") ||
        decodedLowerPath.startsWith("/chapters/") ||
        lowerPath.startsWith("/api/og/video")
      ) {
        const isVideoCardImageRequest = lowerPath.endsWith("/og.png") || lowerPath.endsWith("/card.png") || lowerPath.startsWith("/api/og/video");
        let videoId = (req.query.v || req.query.id || req.query.videoId) as string;
        if (!videoId) {
          if (lowerPath.startsWith("/api/og/video")) {
            const parts = path.split("/").filter(p => p.length > 0);
            videoId = (parts[3] || "").replace(/\.(png|jpe?g|webp)$/i, "");
          } else {
            const parts = decodedPath.split("/").filter(p => p.length > 0);
            const p0 = parts.length > 0 ? parts[0].toLowerCase() : "";
            if (
              parts.length >= 2 &&
              (p0 === "watch" || p0 === "v" || p0 === "shorts" || p0 === "clip" || p0 === "clips" || p0 === "chapter" || p0 === "chapters")
            ) {
              videoId = parts[1].replace(/\.(png|jpe?g|webp)$/i, "").replace(/\/(og|card)\.png$/i, "").trim().replace(/\/+$/, "");
            }
          }
        }
        if (videoId) {
          videoId = decodeURIComponent(videoId).trim().replace(/\/+$/, "");
          const rawClipTitle = (req.query.clipTitle || req.query.title) as string;
          const clipTitle = rawClipTitle ? decodeURIComponent(rawClipTitle).trim() : "";
          const clipStartParam = (req.query.start || req.query.clipStart) as string;
          const clipEndParam = (req.query.end || req.query.clipEnd) as string;
          const timeParam = (req.query.t || req.query.time) as string;

          const isClip = Boolean(clipTitle || (clipStartParam && clipEndParam) || lowerPath.startsWith("/clip") || decodedLowerPath.startsWith("/clip"));
          const isChapter = Boolean(timeParam || lowerPath.startsWith("/chapter") || decodedLowerPath.startsWith("/chapter"));

          let cacheKey = `watch_v5_${videoId}`;
          if (isClip) {
            const sSec = clipStartParam ? parseInt(clipStartParam, 10) : 0;
            const eSec = clipEndParam ? parseInt(clipEndParam, 10) : 0;
            const cleanTitleSlug = clipTitle ? clipTitle.substring(0, 24).toLowerCase().replace(/\W+/g, "_") : "clip";
            cacheKey = `clip_v5_${videoId}_${sSec}_${eSec}_${cleanTitleSlug}`;
          } else if (isChapter && timeParam) {
            cacheKey = `chapter_v5_${videoId}_${timeParam.replace(/\W+/g, "_")}`;
          }

          if (!isVideoCardImageRequest) {
            const cached = await getCachedSnapshot(cacheKey);
            if (cached) {
              logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
              sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
              return;
            }
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
              if (isVideoCardImageRequest) {
                const fallbackBuffer = await renderVideoCardImage({
                  title: "Truthworld Video",
                  description: "Watch family-safe, verified video with epistemic clarity on Truthworld.",
                });
                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=3600");
                res.status(200).send(fallbackBuffer);
                return;
              }
              const baseHtml = await fetchIndexHtml();
              res.status(404).send(baseHtml);
              return;
            }

            // Concurrently query channel doc & related videos to eliminate latency
            const channelDocPromise = docData.channelId
              ? db.collection("channels").doc(docData.channelId).get().catch(() => null)
              : Promise.resolve(null);

            let rQuery = db.collection("videos").limit(8);
            if (docData.category) {
              rQuery = db.collection("videos").where("category", "==", docData.category).limit(8);
            } else if (docData.channelId) {
              rQuery = db.collection("videos").where("channelId", "==", docData.channelId).limit(8);
            }
            const relatedVideosPromise = rQuery.get().catch(() => null);

            const [cDoc, rSnap] = await Promise.all([channelDocPromise, relatedVideosPromise]);

            let channelName = docData.channelName || "Channel";
            let channelHandle = "";
            let channelIsBrand = false;
            if (cDoc && cDoc.exists) {
              const cData = cDoc.data()!;
              channelName = cData.displayName || cData.name || channelName;
              channelHandle = cData.handle || "";
              channelIsBrand = cData.isBrand === true || cData.creatorType === "Organization" || cData.type === "custom";
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

            // Format Video, Clip, or Chapter Title & Description cleanly
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

            let activeChapterThumbnail: string | undefined = undefined;

            if (isClip) {
              const displayClipTitle = clipTitle || `Clip from ${rawTitle}`;
              let segmentStr = "";
              if (clipStartParam && clipEndParam) {
                const sSec = parseInt(clipStartParam, 10) || 0;
                const eSec = parseInt(clipEndParam, 10) || 0;
                const sMin = `${Math.floor(sSec / 60)}:${(sSec % 60).toString().padStart(2, "0")}`;
                const eMin = `${Math.floor(eSec / 60)}:${(eSec % 60).toString().padStart(2, "0")}`;
                segmentStr = ` (${sMin} - ${eMin})`;
              }
              pageTitle = `"${displayClipTitle}"${segmentStr} - ${rawTitle} | Truthworld`;
              pageDescription = `Watch this verified video clip "${displayClipTitle}" from "${rawTitle}" by ${channelName} on Truthworld. Stream family-safe video.`;
            } else if (isChapter && timeParam) {
              let chapterTitle = "";
              let startSec = 0;
              if (timeParam.includes("m") || timeParam.includes("s")) {
                const mMatch = timeParam.match(/(\d+)m/);
                const sMatch = timeParam.match(/(\d+)s/);
                startSec = (mMatch ? parseInt(mMatch[1], 10) * 60 : 0) + (sMatch ? parseInt(sMatch[1], 10) : 0);
              } else {
                startSec = parseInt(timeParam, 10) || 0;
              }

              if (Array.isArray(docData.chapters) && docData.chapters.length > 0) {
                for (let ci = 0; ci < docData.chapters.length; ci++) {
                  const ch = docData.chapters[ci];
                  const chStart = Math.floor((ch.startMs || 0) / 1000);
                  const nextCh = docData.chapters[ci + 1];
                  const chEnd = nextCh ? Math.floor((nextCh.startMs || 0) / 1000) : videoDurationSec;
                  if (startSec >= chStart && (startSec < chEnd || !nextCh)) {
                    chapterTitle = ch.title;
                    activeChapterThumbnail = ensureAbsoluteImageUrl(ch.thumbnailUrl || ch.thumbnail);
                    break;
                  }
                }
              }

              if (chapterTitle) {
                pageTitle = `"${chapterTitle}" - ${rawTitle} | Truthworld`;
                pageDescription = `Watch "${chapterTitle}" from "${rawTitle}" by ${channelName} on Truthworld (Chapter at ${Math.floor(startSec / 60)}:${(startSec % 60).toString().padStart(2, "0")}).`;
              }
            }

            const videoImage = await resolveVideoImage(db, docData);
            const activeThumbnail = activeChapterThumbnail || videoImage;

            // Build deterministic, highly optimized card image URL for Open Graph and Twitter
            let cardImageUrl = `${DOMAIN}/api/og/video/${docId}.png`;
            if (isClip) {
              const qParams = new URLSearchParams();
              if (clipStartParam) qParams.set("start", clipStartParam);
              if (clipEndParam) qParams.set("end", clipEndParam);
              if (clipTitle) qParams.set("clipTitle", clipTitle);
              cardImageUrl = `${DOMAIN}/api/og/video/${docId}.png?${qParams.toString()}`;
            } else if (isChapter && timeParam) {
              cardImageUrl = `${DOMAIN}/api/og/video/${docId}.png?t=${encodeURIComponent(timeParam)}`;
            }

            // Industry standard: Social scrapers (WhatsApp, Twitter, FB, Telegram, iMessage)
            // enforce a strict <= 300KB file size limit. Raw user uploads in Firebase Storage can be 1MB-5MB+
            // and cause WhatsApp on Android/iOS to drop the thumbnail. Always serve the optimized card!
            const finalVideoThumbnail = cardImageUrl;

            // Dynamic Video Card Image for explicit card image endpoints
            if (isVideoCardImageRequest) {
              const cardTitle = isClip
                ? (clipTitle ? `"${clipTitle}" - ${rawTitle}` : `Clip from ${rawTitle}`)
                : (isChapter && pageTitle ? pageTitle.replace(/ \| Truthworld$/, "") : rawTitle);
              const cardDesc = (isClip || (isChapter && pageDescription)) ? pageDescription : rawDesc;

              try {
                const cardBuffer = await renderVideoCardImage({
                  title: cardTitle,
                  thumbnailUrl: activeThumbnail,
                  description: cardDesc,
                  channelName,
                  durationMs: docData.durationMs,
                  videoId: docId,
                });

                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
                res.status(200).send(cardBuffer);
                return;
              } catch (cardErr) {
                console.error("Failed to generate dynamic video card image, falling back", cardErr);
                const fallbackBuffer = await renderVideoCardImage({
                  title: cardTitle || "Truthworld Video",
                  channelName,
                  description: cardDesc,
                  videoId: docId,
                });
                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=3600");
                res.status(200).send(fallbackBuffer);
                return;
              }
            }

            const videoSchema = generateVideoSchema({ ...docData, id: docId } as any, authorUrl, channelName, channelIsBrand);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: authorUrl },
              { name: rawTitle, url: canonicalUrl }
            ]);

            // Populate related videos for continuous crawl graph
            let relatedVideosList: Array<{ title: string; url: string }> = [];
            if (rSnap && !rSnap.empty) {
              rSnap.forEach(rd => {
                if (rd.id !== docId) {
                  const rData = rd.data();
                  const rTitle = (rData.title || "").trim();
                  const rVis = (rData.visibility || "public").toLowerCase();
                  const rSt = (rData.status || "").toLowerCase();
                  if (rTitle && rVis !== "private" && rSt !== "deleted" && rSt !== "draft") {
                    relatedVideosList.push({ title: rTitle, url: `${DOMAIN}/watch?v=${rd.id}` });
                  }
                }
              });
            }

            // Topic items for this video
            const videoTopicItems: Array<{ title: string; url: string }> = [];
            if (Array.isArray(docData.topics)) {
              for (const t of docData.topics) {
                if (typeof t === "string" && t.trim()) {
                  videoTopicItems.push({ title: `#${t.trim()}`, url: `${DOMAIN}/topic/${encodeURIComponent(t.trim().toLowerCase())}` });
                }
              }
            } else if (docData.category) {
              videoTopicItems.push({ title: `#${docData.category}`, url: `${DOMAIN}/browse` });
            }

            // Instant video hydration payload for 0ms Flutter Web startup
            const videoHydrationData = {
              id: docId,
              title: rawTitle,
              description: rawDesc,
              thumbnail: activeThumbnail || videoImage || "",
              videoUrl: docData.videoUrl || docData.originalUrl || "",
              hlsUrl: docData.hlsUrl || "",
              dashUrl: docData.dashUrl || "",
              creatorId: docData.channelId || docData.userId || docData.ownerId || "unknown",
              channelId: docData.channelId || "",
              creatorName: channelName,
              category: docData.category || "General",
              tags: Array.isArray(docData.tags) ? docData.tags : (Array.isArray(docData.topics) ? docData.topics : []),
              viewCount: viewCount,
              duration: videoDurationSec,
            };
            const injectedHydrationScript = `window.__VIDEO_DATA__ = ${JSON.stringify(videoHydrationData)};`;

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalUrl,
              image: finalVideoThumbnail,
              imageWidth: 1024,
              imageHeight: 848,
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
              transcriptExcerpt: docData.transcript || docData.captionsText,
              relatedItems: relatedVideosList,
              topicItems: videoTopicItems,
              injectedScript: injectedHydrationScript
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            if (isVideoCardImageRequest) {
              const fallbackBuffer = await renderVideoCardImage({
                title: "Truthworld Video",
                description: "Watch family-safe, verified video with epistemic clarity on Truthworld.",
              });
              res.set("Content-Type", "image/png");
              res.set("Cache-Control", "public, max-age=3600");
              res.status(200).send(fallbackBuffer);
              return;
            }
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
          if (isVideoCardImageRequest) {
            const fallbackBuffer = await renderVideoCardImage({
              title: "Truthworld Video",
              description: "Watch family-safe, verified video with epistemic clarity on Truthworld.",
            });
            res.set("Content-Type", "image/png");
            res.set("Cache-Control", "public, max-age=3600");
            res.status(200).send(fallbackBuffer);
            return;
          }
          const baseHtml = await fetchIndexHtml();
          res.status(404).send(baseHtml);
          return;
        }
      }

      // CHANNEL / HANDLE ROUTE
      if (
        lowerPath.startsWith("/channel/") ||
        decodedLowerPath.startsWith("/channel/") ||
        path.startsWith("/@") ||
        decodedPath.startsWith("/@") ||
        lowerPath.startsWith("/c/") ||
        decodedLowerPath.startsWith("/c/") ||
        lowerPath.startsWith("/user/") ||
        decodedLowerPath.startsWith("/user/") ||
        lowerPath.startsWith("/api/og/channel")
      ) {
        const isChannelCardImageRequest = lowerPath.endsWith("/og.png") || lowerPath.endsWith("/card.png") || lowerPath.startsWith("/api/og/channel");
        let rawTarget = "";
        if (decodedPath.startsWith("/@")) {
          rawTarget = decodedPath.substring(2);
        } else if (path.startsWith("/@")) {
          rawTarget = path.substring(2);
        } else if (lowerPath.startsWith("/api/og/channel")) {
          const parts = path.split("/").filter(p => p.length > 0);
          rawTarget = parts[3] || (req.query.id as string) || (req.query.handle as string) || "";
        } else {
          const parts = decodedPath.split("/").filter(p => p.length > 0);
          rawTarget = parts[1] || "";
        }

        const handleOrId = rawTarget
          .replace(/\/(og|card)\.png$/i, "")
          .replace(/\.(png|jpe?g|webp)$/i, "")
          .trim()
          .replace(/\/+$/, "");

        if (handleOrId) {
          const cleanHandle = handleOrId.replace(/^@+/, "").trim();
          const cleanHandleLower = cleanHandle.toLowerCase();
          const handleWithAt = cleanHandle ? `@${cleanHandle}` : "";
          const handleWithAtLower = cleanHandleLower ? `@${cleanHandleLower}` : "";

          const cacheKey = `channel_v5_${cleanHandleLower || handleOrId.toLowerCase()}`;
          if (!isChannelCardImageRequest) {
            const cached = await getCachedSnapshot(cacheKey);
            if (cached) {
              logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
              sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
              return;
            }
          }

          let docData: any = null;

          // 1. Direct doc lookup by ID
          const docDirect = await db.collection("channels").doc(handleOrId).get();
          if (docDirect.exists) {
            docData = { id: docDirect.id, ...(docDirect.data() as any) };
          } else if (cleanHandle && cleanHandle !== handleOrId) {
            const docDirectClean = await db.collection("channels").doc(cleanHandle).get();
            if (docDirectClean.exists) {
              docData = { id: docDirectClean.id, ...(docDirectClean.data() as any) };
            }
          }

          // 2. Query channels by handleLowercase (both with and without @)
          if (!docData && cleanHandleLower) {
            const handleLowerCandidates = Array.from(new Set([cleanHandleLower, handleWithAtLower, cleanHandle, handleWithAt]));
            const qs = await db.collection("channels").where("handleLowercase", "in", handleLowerCandidates).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 3. Query channels by handle exact (both with and without @)
          if (!docData && cleanHandle) {
            const handleCandidates = Array.from(new Set([cleanHandle, handleWithAt, cleanHandleLower, handleWithAtLower]));
            const qs = await db.collection("channels").where("handle", "in", handleCandidates).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 4. Query channels by customUrlLowercase
          if (!docData && cleanHandleLower) {
            const customUrlCandidates = Array.from(new Set([cleanHandleLower, handleWithAtLower]));
            const qs = await db.collection("channels").where("customUrlLowercase", "in", customUrlCandidates).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 5. Query channels by nameLowercase
          if (!docData && cleanHandleLower) {
            const qs = await db.collection("channels").where("nameLowercase", "==", cleanHandleLower).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 6. Query channels by id field
          if (!docData) {
            const idCandidates = Array.from(new Set([handleOrId, cleanHandle]));
            const qs = await db.collection("channels").where("id", "in", idCandidates).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 7. Query channels by ownerId or userId
          if (!docData) {
            const ownerCandidates = Array.from(new Set([handleOrId, cleanHandle]));
            const qsOwner = await db.collection("channels").where("ownerId", "in", ownerCandidates).limit(1).get();
            if (!qsOwner.empty) {
              docData = { id: qsOwner.docs[0].id, ...(qsOwner.docs[0].data() as any) };
            } else {
              const qsUser = await db.collection("channels").where("userId", "in", ownerCandidates).limit(1).get();
              if (!qsUser.empty) docData = { id: qsUser.docs[0].id, ...(qsUser.docs[0].data() as any) };
            }
          }

          // 8. Fallback: Search users collection and link to channel
          if (!docData) {
            let userSnap = await db.collection("users").doc(handleOrId).get();
            if (!userSnap.exists && cleanHandle && cleanHandle !== handleOrId) {
              userSnap = await db.collection("users").doc(cleanHandle).get();
            }

            let userData: any = userSnap.exists ? { id: userSnap.id, ...(userSnap.data() as any) } : null;
            if (!userData && cleanHandleLower) {
              const userHandleCandidates = Array.from(new Set([cleanHandleLower, handleWithAtLower, cleanHandle, handleWithAt]));
              const uq1 = await db.collection("users").where("handleLowercase", "in", userHandleCandidates).limit(1).get();
              if (!uq1.empty) {
                userData = { id: uq1.docs[0].id, ...(uq1.docs[0].data() as any) };
              } else {
                const uq2 = await db.collection("users").where("username", "in", userHandleCandidates).limit(1).get();
                if (!uq2.empty) {
                  userData = { id: uq2.docs[0].id, ...(uq2.docs[0].data() as any) };
                } else {
                  const uq3 = await db.collection("users").where("handle", "in", userHandleCandidates).limit(1).get();
                  if (!uq3.empty) {
                    userData = { id: uq3.docs[0].id, ...(uq3.docs[0].data() as any) };
                  }
                }
              }
            }

            if (userData) {
              if (userData.channelId) {
                const chSnap = await db.collection("channels").doc(userData.channelId).get();
                if (chSnap.exists) {
                  docData = { id: chSnap.id, ...(chSnap.data() as any) };
                }
              }

              if (!docData) {
                const chByOwner = await db.collection("channels").where("ownerId", "==", userData.id).limit(1).get();
                if (!chByOwner.empty) {
                  docData = { id: chByOwner.docs[0].id, ...(chByOwner.docs[0].data() as any) };
                } else {
                  const chByUser = await db.collection("channels").where("userId", "==", userData.id).limit(1).get();
                  if (!chByUser.empty) {
                    docData = { id: chByUser.docs[0].id, ...(chByUser.docs[0].data() as any) };
                  }
                }
              }

              if (!docData) {
                docData = {
                  id: userData.id,
                  displayName: userData.displayName || userData.name || cleanHandle,
                  name: userData.displayName || userData.name || cleanHandle,
                  handle: userData.handle || handleWithAt || `@${cleanHandle}`,
                  handleLowercase: (userData.handle || handleWithAt || `@${cleanHandle}`).toLowerCase(),
                  avatarUrl: userData.photoURL || userData.photoUrl || userData.avatarUrl || userData.avatar || "",
                  photoUrl: userData.photoURL || userData.photoUrl || userData.avatarUrl || "",
                  about: userData.bio || userData.description || userData.about || "",
                  subscriberCount: userData.subscriberCount || 0,
                  videoCount: userData.videoCount || 0,
                  status: userData.status || "active",
                };
              }
            }
          }

          if (docData && docData.status !== "deleted" && docData.status !== "suspended") {
            const rawChannelName = (docData.displayName || docData.name || docData.channelName || "Channel").trim();
            const channelName = (rawChannelName.toLowerCase().startsWith("untitled") || !rawChannelName)
              ? "Truthworld Channel"
              : rawChannelName;
            
            const handle = (docData.handle || cleanHandle || "").replace(/^@/, "").trim();
            const handleWithAt = handle ? `@${handle}` : "";
            const canonicalChannelUrl = handle ? `${DOMAIN}/@${handle}` : canonicalUrl;

            // Extract subscriber & video metrics
            const subscriberCount = docData.subscriberCount || docData.subscribers || docData.stats?.subscriberCount || 0;
            const videoCount = docData.videoCount || 0;
            const subStr = subscriberCount >= 1000000 
              ? `${(subscriberCount / 1000000).toFixed(1).replace(/\.0$/, "")}M Subscribers`
              : subscriberCount >= 1000
                ? `${(subscriberCount / 1000).toFixed(1).replace(/\.0$/, "")}K Subscribers`
                : `${subscriberCount} Subscriber${subscriberCount === 1 ? "" : "s"}`;
            const vidStr = `${videoCount} Video${videoCount === 1 ? "" : "s"}`;

            const rawBio = (docData.about || docData.description || "").trim();

            const rawBanner = docData.bannerUrl ||
              docData.bannerImageUrl ||
              docData.bannerImage ||
              docData.coverUrl ||
              docData.banner ||
              docData.coverImage ||
              docData.bannerPicUrl ||
              docData.headerUrl;
            const bannerUrl = ensureAbsoluteImageUrl(rawBanner);

            const rawAvatar = docData.avatarUrl ||
              docData.avatarImage ||
              docData.channelAvatarUrl ||
              docData.channelImage ||
              docData.photoUrl ||
              docData.photoURL ||
              docData.profileImageUrl ||
              docData.profile?.photoUrl ||
              docData.profilePicture ||
              docData.avatar ||
              docData.imageUrl ||
              docData.iconUrl ||
              (Array.isArray(docData.avatarVariants) && docData.avatarVariants.length > 0 ? docData.avatarVariants[docData.avatarVariants.length - 1] : undefined);
            const avatarUrl = ensureAbsoluteImageUrl(rawAvatar);

            // Handle Dynamic Image Generation for Open Graph and Twitter Card
            if (isChannelCardImageRequest) {
              try {
                const cardBuffer = await renderChannelCardImage({
                  channelName,
                  handle: docData.handle,
                  subscriberCount,
                  description: rawBio,
                  bannerUrl,
                  avatarUrl,
                });

                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
                res.status(200).send(cardBuffer);
                return;
              } catch (cardErr) {
                console.error("Failed to generate dynamic channel card image, falling back", cardErr);
                const fallbackBuffer = await renderChannelCardImage({
                  channelName: channelName || "Truthworld Channel",
                  handle: docData?.handle,
                  description: rawBio,
                });
                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=3600");
                res.status(200).send(fallbackBuffer);
                return;
              }
            }

            const cardImageUrl = `${DOMAIN}/api/og/channel/${encodeURIComponent(cleanHandle || docData.id)}.png`;
            // Industry standard: Social scrapers (WhatsApp, FB, Telegram, iMessage) strictly drop images > 300KB.
            // Raw creator banners in storage are often 2-5MB. Always serve the optimized social card!
            const finalChannelImage = cardImageUrl;
            const channelImageWidth = 1024;
            const channelImageHeight = 848;

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

            // Build rich industry-standard description
            let pageDescription: string;
            if (rawBio) {
              pageDescription = `${rawBio} • ${subStr} • ${vidStr} on Truthworld.`;
            } else {
              pageDescription = `Watch family-safe, verified videos from ${channelName} on Truthworld. • ${subStr} • ${vidStr}`;
            }

            // Query creator's public videos for crawl continuity
            let channelVideosHtml = "";
            const channelRelatedVideos: Array<{ title: string; url: string }> = [];
            try {
              const cvSnap = await db.collection("videos")
                .where("channelId", "==", docData.id)
                .limit(12)
                .get();

              if (!cvSnap.empty) {
                channelVideosHtml = `
  <section class="tw-channel-uploads" style="margin-top: 32px; border-top: 1px solid #27272a; padding-top: 24px;">
    <h3 style="color: #f4f4f5; font-size: 18px; margin-bottom: 16px; font-weight: 600;">Videos by ${escapeHtml(channelName)}</h3>
    <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px;">
                `;
                cvSnap.forEach(cvd => {
                  const cvData = cvd.data();
                  const cvTitle = escapeHtml((cvData.title || "Video").trim());
                  const cvUrl = `${DOMAIN}/watch?v=${cvd.id}`;
                  const cvImg = escapeHtml(ensureAbsoluteImageUrl(cvData.thumbnailUrl || cvData.thumbnail) || `${DOMAIN}/icons/og-image.png`);
                  channelRelatedVideos.push({ title: (cvData.title || "Video").trim(), url: cvUrl });

                  channelVideosHtml += `
      <div style="background: #140521; border: 1px solid #27272a; border-radius: 8px; overflow: hidden;">
        <a href="${cvUrl}" style="display: block; aspect-ratio: 16/9; background: #000;">
          <img src="${cvImg}" alt="${cvTitle}" loading="lazy" style="width: 100%; height: 100%; object-fit: cover;" />
        </a>
        <div style="padding: 10px;">
          <h4 style="font-size: 13px; line-height: 1.4; margin: 0;">
            <a href="${cvUrl}" style="color: #f4f4f5; text-decoration: none;">${cvTitle}</a>
          </h4>
        </div>
      </div>`;
                });
                channelVideosHtml += `\n    </div>\n  </section>`;
              }
            } catch (_) {}

            const channelSchema = generateChannelSchema(docData, canonicalChannelUrl, finalChannelImage);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: canonicalChannelUrl }
            ]);

            // High-fidelity channel architecture card matching Image preview
            const channelCardHtml = `
  <section class="tw-channel-hero-card" style="margin: 20px auto 32px; max-width: 720px; background: #161719; border-radius: 20px; overflow: hidden; border: 1px solid #27272a; box-shadow: 0 8px 30px rgba(0,0,0,0.5);">
    <div style="aspect-ratio: 16/9; width: 100%; background: #0f051d; overflow: hidden; position: relative;">
      ${bannerUrl ? `<img src="${escapeHtml(bannerUrl)}" alt="${escapeHtml(channelName)} Banner" style="width: 100%; height: 100%; object-fit: cover;" />` : `<div style="width: 100%; height: 100%; background: linear-gradient(135deg, #1e1035, #2d1254, #0f051d); display: flex; align-items: center; justify-content: center; color: rgba(255,255,255,0.18); font-size: 28px; font-weight: bold; letter-spacing: 3px;">TRUTHWORLD</div>`}
    </div>
    <div style="padding: 20px 24px;">
      <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 14px;">
        <div style="width: 64px; height: 64px; border-radius: 50%; overflow: hidden; border: 2.5px solid #27272a; flex-shrink: 0; background: #27272a;">
          ${avatarUrl ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(channelName)}" style="width: 100%; height: 100%; object-fit: cover;" />` : `<div style="width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; color: #fff; font-weight: bold; font-size: 24px; background: #2a1b40;">${escapeHtml(channelName.charAt(0).toUpperCase())}</div>`}
        </div>
        <div>
          <h2 style="margin: 0; font-size: 22px; font-weight: 700; color: #ffffff;">${escapeHtml(channelName)}</h2>
          ${handleWithAt ? `<div style="font-size: 14px; color: #8e8e93; margin-top: 2px;">${escapeHtml(handleWithAt)}</div>` : ""}
          <div style="font-size: 14px; color: #8e8e93; margin-top: 2px;">${escapeHtml(subStr)}</div>
        </div>
      </div>
      <p style="margin: 0 0 18px; color: #9ca3af; font-size: 14px; line-height: 1.5; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;">${escapeHtml(rawBio || "Watch family-safe, verified videos on Truthworld.")}</p>
      <a href="${canonicalChannelUrl}" style="display: flex; align-items: center; justify-content: space-between; text-decoration: none; padding-top: 14px; border-top: 1px solid rgba(255,255,255,0.08);">
        <div style="display: flex; align-items: center; gap: 8px; color: #ffffff; font-weight: 600; font-size: 16px;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
          <span>Truthworld</span>
        </div>
        <span style="color: #ffffff; font-size: 18px;">&rsaquo;</span>
      </a>
    </div>
  </section>`;

            const channelVis = (docData.visibility || "").toLowerCase();
            const channelRobots = channelVis === "private"
              ? "noindex, nofollow"
              : channelVis === "unlisted"
                ? "noindex, follow"
                : (docData.isPublic === false ? "noindex, nofollow" : "index, follow");

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalChannelUrl,
              image: finalChannelImage,
              imageWidth: channelImageWidth,
              imageHeight: channelImageHeight,
              type: "profile",
              robots: channelRobots,
              jsonLd: [channelSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: `${channelName}${handleWithAt ? ` (${handleWithAt})` : ""}`,
              authorName: channelName,
              authorUrl: canonicalChannelUrl,
              customBodyHtml: channelCardHtml + channelVideosHtml,
              relatedItems: channelRelatedVideos
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            if (isChannelCardImageRequest) {
              const fallbackBuffer = await renderChannelCardImage({
                channelName: "Truthworld Channel",
                description: "Watch family-safe, verified videos on Truthworld.",
              });
              res.set("Content-Type", "image/png");
              res.set("Cache-Control", "public, max-age=3600");
              res.status(200).send(fallbackBuffer);
              return;
            }
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
        } else {
          if (isChannelCardImageRequest) {
            const fallbackBuffer = await renderChannelCardImage({
              channelName: "Truthworld Channel",
              description: "Watch family-safe, verified videos on Truthworld.",
            });
            res.set("Content-Type", "image/png");
            res.set("Cache-Control", "public, max-age=3600");
            res.status(200).send(fallbackBuffer);
            return;
          }
          const baseHtml = await fetchIndexHtml();
          res.status(404).send(baseHtml);
          return;
        }
      }

      // TOPIC ROUTE & DYNAMIC TOPIC CARD IMAGE
      if (lowerPath.startsWith("/topic") || lowerPath.startsWith("/topics") || lowerPath.startsWith("/t/") || lowerPath === "/t" || lowerPath.startsWith("/api/og/topic")) {
        const isTopicCardImageRequest = lowerPath.endsWith("/og.png") || lowerPath.endsWith("/card.png") || lowerPath.startsWith("/api/og/topic");
        let slug = (req.query.id || req.query.slug || req.query.topic || req.query.tag) as string;
        if (!slug) {
          if (lowerPath.startsWith("/api/og/topic")) {
            const parts = path.split("/").filter(p => p.length > 0);
            slug = (parts[3] || "").replace(/\.(png|jpe?g|webp)$/i, "");
          } else {
            const parts = path.split("/").filter(p => p.length > 0);
            if (parts.length >= 2) {
              slug = parts[1].replace(/\.(png|jpe?g|webp)$/i, "").replace(/\/(og|card)\.png$/i, "");
            } else if (parts.length === 1 && (parts[0].toLowerCase() !== "topic" && parts[0].toLowerCase() !== "topics" && parts[0].toLowerCase() !== "t")) {
              slug = parts[0].replace(/\.(png|jpe?g|webp)$/i, "").replace(/\/(og|card)\.png$/i, "");
            }
          }
        }

        if (slug) {
          slug = decodeURIComponent(slug).trim().replace(/^[\/#]+/, "");
          const cleanSlug = slug.replace(/^(T\/|t\/)/i, "").trim().replace(/^#/, "").replace(/\.(png|jpe?g|webp)$/i, "");
          const cacheKey = `topic_v5_${cleanSlug.toLowerCase()}`;
          if (!isTopicCardImageRequest) {
            const cached = await getCachedSnapshot(cacheKey);
            if (cached) {
              logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
              sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
              return;
            }
          }

          let docData: any = null;

          // 1. Direct doc lookup by ID (exact)
          const docDirect = await db.collection("topics").doc(cleanSlug).get();
          if (docDirect.exists) {
            docData = { id: docDirect.id, ...(docDirect.data() as any) };
          }

          // 2. Direct doc lookup by ID (lowercase)
          if (!docData && cleanSlug !== cleanSlug.toLowerCase()) {
            const docDirectLower = await db.collection("topics").doc(cleanSlug.toLowerCase()).get();
            if (docDirectLower.exists) {
              docData = { id: docDirectLower.id, ...(docDirectLower.data() as any) };
            }
          }

          // 3. Query by slug exact
          if (!docData) {
            const qs = await db.collection("topics").where("slug", "==", cleanSlug).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 4. Query by slug lowercase
          if (!docData) {
            const qsLower = await db.collection("topics").where("slug", "==", cleanSlug.toLowerCase()).limit(1).get();
            if (!qsLower.empty) docData = { id: qsLower.docs[0].id, ...(qsLower.docs[0].data() as any) };
          }

          // 5. Query by handle or handleLowercase
          if (!docData) {
            const qsHandle = await db.collection("topics").where("handleLowercase", "==", `t/${cleanSlug.toLowerCase()}`).limit(1).get();
            if (!qsHandle.empty) docData = { id: qsHandle.docs[0].id, ...(qsHandle.docs[0].data() as any) };
          }

          // 6. Query by title or name lowercase
          if (!docData) {
            const qsTitle = await db.collection("topics").where("titleLowercase", "==", cleanSlug.toLowerCase()).limit(1).get();
            if (!qsTitle.empty) docData = { id: qsTitle.docs[0].id, ...(qsTitle.docs[0].data() as any) };
          }
          if (!docData) {
            const qsName = await db.collection("topics").where("nameLowercase", "==", cleanSlug.toLowerCase()).limit(1).get();
            if (!qsName.empty) docData = { id: qsName.docs[0].id, ...(qsName.docs[0].data() as any) };
          }
          if (!docData) {
            const qsTitleExact = await db.collection("topics").where("title", "==", cleanSlug).limit(1).get();
            if (!qsTitleExact.empty) docData = { id: qsTitleExact.docs[0].id, ...(qsTitleExact.docs[0].data() as any) };
          }

          if (docData && docData.status !== "deleted" && docData.status !== "inactive" && docData.status !== "archived" && docData.status !== "verificationRejected") {
            const rawTitle = (docData.title || docData.name || "Topic").trim();
            const cleanTitle = rawTitle.replace(/^[#Tt]\//, "").trim();
            const topVideos: any[] = [];
            const topicKeys = [docData.slug, cleanSlug, cleanSlug.toLowerCase(), docData.id, docData.title].filter(Boolean);
            const seenKeys = new Set<string>();
            const uniqueKeys = topicKeys.filter(k => {
              const lower = String(k).toLowerCase();
              if (seenKeys.has(lower)) return false;
              seenKeys.add(lower);
              return true;
            });

            for (const key of uniqueKeys) {
              if (topVideos.length >= 10) break;
              try {
                // Do not use orderBy with array-contains because missing composite indexes throw and cause high latency
                const vSnap = await db.collection("videos")
                  .where("topics", "array-contains", key)
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
                console.warn(`Error fetching topic videos for key ${key}:`, err);
              }
            }

            // In-memory sort by upload time
            topVideos.sort((a, b) => {
              const tA = a.uploadedAt?._seconds || a.createdAt?._seconds || (a.uploadedAt ? new Date(a.uploadedAt).getTime() : 0);
              const tB = b.uploadedAt?._seconds || b.createdAt?._seconds || (b.uploadedAt ? new Date(b.uploadedAt).getTime() : 0);
              return tB - tA;
            });

            const rawTopicImg = docData.thumbnailUrl ||
              docData.coverImage ||
              docData.imageUrl ||
              docData.iconUrl ||
              docData.bannerUrl ||
              (topVideos.length > 0 ? (topVideos[0].thumbnailUrl || topVideos[0].thumbnail || topVideos[0].coverUrl) : undefined);

            const topicImage = ensureAbsoluteImageUrl(rawTopicImg);
            const cardImageUrl = `${DOMAIN}/api/og/topic/${encodeURIComponent(cleanSlug)}.png`;
            // Industry standard: Social scrapers strictly drop images > 300KB. Always serve the optimized card.
            const finalTopicImage = cardImageUrl;
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

            // Dynamic Topic Card Image for Explicit Image Requests (/og.png, /card.png)
            if (isTopicCardImageRequest) {
              try {
                const cardBuffer = await renderTopicCardImage({
                  title: cleanTitle,
                  handle: docData.handle || cleanSlug,
                  followerCount,
                  videoCount,
                  description: rawDesc,
                  thumbnailUrl: topicImage,
                  url: canonicalUrl,
                });

                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
                res.status(200).send(cardBuffer);
                return;
              } catch (cardErr) {
                console.error("Failed to generate dynamic topic card image, falling back", cardErr);
                const fallbackBuffer = await renderTopicCardImage({
                  title: cleanTitle || "Truthworld Topic",
                  handle: cleanSlug,
                  description: rawDesc,
                  url: canonicalUrl,
                });
                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=3600");
                res.status(200).send(fallbackBuffer);
                return;
              }
            }

            const topicSchema = generateTopicSchema(docData, canonicalUrl, topVideos);
            const breadcrumbs = generateBreadcrumbData([
              { name: `#${cleanTitle}`, url: canonicalUrl }
            ]);

            const rawTopicHandle = (docData.handle || cleanSlug).replace(/^[#@]/, "").replace(/^[Tt]\//, "").trim();

            // High-fidelity topic architecture card matching social preview architecture
            const topicCardHtml = `
  <section class="tw-topic-hero-card" style="margin: 20px auto 32px; max-width: 720px; background: #161719; border-radius: 20px; overflow: hidden; border: 1px solid #27272a; box-shadow: 0 8px 30px rgba(0,0,0,0.5);">
    <div style="aspect-ratio: 16/7; width: 100%; background: #0f051d; overflow: hidden; position: relative;">
      ${topicImage ? `<img src="${escapeHtml(topicImage)}" alt="${escapeHtml(cleanTitle)}" style="width: 100%; height: 100%; object-fit: cover;" />` : `<div style="width: 100%; height: 100%; background: linear-gradient(135deg, #090514, #180b30, #2a0f55, #0c0418); display: flex; flex-direction: column; align-items: center; justify-content: center;"><span style="color: #ffffff; font-size: 26px; font-weight: 800;">Truthworld</span><span style="color: #f59e0b; font-size: 22px; font-weight: 800;">Topics</span></div>`}
    </div>
    <div style="padding: 20px 24px;">
      <h2 style="margin: 0 0 4px; font-size: 24px; font-weight: 800; color: #ffffff;">${escapeHtml(cleanTitle)}</h2>
      <div style="font-size: 14px; color: #8e8e93; margin-bottom: 10px;">@ ${escapeHtml(rawTopicHandle || cleanSlug.toLowerCase())}</div>
      <div style="display: flex; align-items: center; gap: 12px; font-size: 14px; color: #ffffff; font-weight: 600; margin-bottom: 12px;">
        <span>${escapeHtml(folStr)}</span>
        <span style="color: #3f3f46;">|</span>
        <span>${escapeHtml(vidStr)}</span>
      </div>
      <p style="margin: 0 0 18px; color: #9ca3af; font-size: 14px; line-height: 1.5; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;">${escapeHtml(rawDesc || "Truthworld Topics brings you the best verified channels and creators across education, technology, science, health, spirituality, entertainment and more.")}</p>
      <a href="${canonicalUrl}" style="display: flex; align-items: center; justify-content: space-between; text-decoration: none; padding: 12px 16px; background: #0f1012; border: 1px solid #27272a; border-radius: 12px;">
        <div style="display: flex; align-items: center; gap: 8px; color: #ffffff; font-size: 14px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
          <span style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${escapeHtml(canonicalUrl)}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 4px; color: #8e8e93; font-size: 13px; flex-shrink: 0; margin-left: 12px;">
          <span>Truthworld</span>
          <span>&rsaquo;</span>
        </div>
      </a>
    </div>
  </section>`;

            const finalHtml = buildSemanticSsrHtml({
              title: `#${cleanTitle} - Topic | Truthworld`,
              description: topicDescription,
              url: canonicalUrl,
              image: finalTopicImage,
              imageWidth: 1024,
              imageHeight: 682,
              type: "website",
              robots: (topVideos.length === 0 && (Number(docData.videoCount) || 0) <= 0) ? "noindex, follow" : "index, follow",
              jsonLd: [topicSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: `#${cleanTitle} Topic`,
              customBodyHtml: topicCardHtml,
              relatedItems: topVideos.map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` }))
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            if (isTopicCardImageRequest) {
              const fallbackBuffer = await renderTopicCardImage({
                title: cleanSlug ? `#${cleanSlug}` : "Truthworld Topics",
                handle: cleanSlug,
                description: "Explore top videos and discussions on Truthworld.",
              });
              res.set("Content-Type", "image/png");
              res.set("Cache-Control", "public, max-age=3600");
              res.status(200).send(fallbackBuffer);
              return;
            }
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
        } else {
          if (isTopicCardImageRequest) {
            const fallbackBuffer = await renderTopicCardImage({
              title: "Truthworld Topics",
              description: "Explore top videos and discussions on Truthworld.",
            });
            res.set("Content-Type", "image/png");
            res.set("Cache-Control", "public, max-age=3600");
            res.status(200).send(fallbackBuffer);
            return;
          }
          const baseHtml = await fetchIndexHtml();
          res.status(404).send(baseHtml);
          return;
        }
      }

      // PLAYLIST ROUTE & DYNAMIC PLAYLIST CARD IMAGE
      if (lowerPath.startsWith("/playlist") || lowerPath.startsWith("/api/og/playlist")) {
        const isPlaylistCardImageRequest = lowerPath.endsWith("/og.png") || lowerPath.endsWith("/card.png") || lowerPath.startsWith("/api/og/playlist");
        let playlistId = (req.query.list || req.query.playlistId || req.query.id) as string;
        if (!playlistId) {
          if (lowerPath.startsWith("/api/og/playlist")) {
            const parts = path.split("/").filter(p => p.length > 0);
            playlistId = (parts[3] || "").replace(/\.(png|jpe?g|webp)$/i, "");
          } else {
            const parts = path.split("/").filter(p => p.length > 0);
            if (parts.length >= 2 && parts[0].toLowerCase() === "playlist") {
              playlistId = parts[1].replace(/\.(png|jpe?g|webp)$/i, "").replace(/\/(og|card)\.png$/i, "");
            }
          }
        }
        if (playlistId) {
          playlistId = decodeURIComponent(playlistId).trim().replace(/\/$/, "");
          const cacheKey = `playlist_v5_${playlistId}`;
          if (!isPlaylistCardImageRequest) {
            const cached = await getCachedSnapshot(cacheKey);
            if (cached) {
              logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
              sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
              return;
            }
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
            const cardImageUrl = `${DOMAIN}/api/og/playlist/${docData.id}.png`;
            // Industry standard: Social scrapers strictly drop images > 300KB. Always serve the optimized card.
            const finalPlaylistImage = cardImageUrl;
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

            // Dynamic Playlist Card Image for explicit card image endpoints
            if (isPlaylistCardImageRequest) {
              try {
                const cardBuffer = await renderPlaylistCardImage({
                  playlistName,
                  channelName,
                  videoCount,
                  thumbnailUrl: ensureAbsoluteImageUrl(playlistImage),
                  description: rawDesc,
                  playlistId: docData.id,
                });

                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
                res.status(200).send(cardBuffer);
                return;
              } catch (cardErr) {
                console.error("Failed to generate dynamic playlist card image, falling back", cardErr);
                const fallbackBuffer = await renderPlaylistCardImage({
                  playlistName: playlistName || "Truthworld Playlist",
                  channelName,
                  videoCount,
                  description: rawDesc,
                  playlistId: docData.id,
                });
                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=3600");
                res.status(200).send(fallbackBuffer);
                return;
              }
            }

            const relatedVideos = videoItems.map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` }));

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalUrl,
              image: finalPlaylistImage,
              imageWidth: 1024,
              imageHeight: 848,
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
            if (isPlaylistCardImageRequest) {
              const fallbackBuffer = await renderPlaylistCardImage({
                playlistName: "Truthworld Playlist",
                description: "Watch verified playlists on Truthworld."
              });
              res.set("Content-Type", "image/png");
              res.set("Cache-Control", "public, max-age=3600");
              res.status(200).send(fallbackBuffer);
              return;
            }
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
        } else {
          if (isPlaylistCardImageRequest) {
            const fallbackBuffer = await renderPlaylistCardImage({
              playlistName: "Truthworld Playlist",
              description: "Watch verified playlists on Truthworld."
            });
            res.set("Content-Type", "image/png");
            res.set("Cache-Control", "public, max-age=3600");
            res.status(200).send(fallbackBuffer);
            return;
          }
          const baseHtml = await fetchIndexHtml();
          res.status(404).send(baseHtml);
          return;
        }
      }

      // CLAIM DETAIL ROUTE & DYNAMIC CLAIM CARD IMAGE
      if (lowerPath.startsWith("/claim-detail") || lowerPath.startsWith("/claim/") || lowerPath.startsWith("/api/og/claim")) {
        const isClaimCardImageRequest = lowerPath.endsWith("/og.png") || lowerPath.endsWith("/card.png") || lowerPath.startsWith("/api/og/claim");
        let videoId = (req.query.videoId || req.query.v) as string;
        let claimIndex = parseInt((req.query.claimIndex || req.query.index || req.query.i || "0") as string, 10);
        if (isNaN(claimIndex)) claimIndex = 0;

        if (!videoId) {
          const parts = path.split("/").filter(p => p.length > 0);
          if (lowerPath.startsWith("/api/og/claim")) {
            videoId = (parts[3] || "").replace(/\.(png|jpe?g|webp)$/i, "");
            const idxStr = (parts[4] || "0").replace(/\.(png|jpe?g|webp)$/i, "");
            claimIndex = parseInt(idxStr, 10) || 0;
          } else if (parts.length >= 2) {
            videoId = parts[1].replace(/\.(png|jpe?g|webp)$/i, "");
            const idxStr = (parts[2] || "0").replace(/\.(png|jpe?g|webp)$/i, "");
            claimIndex = parseInt(idxStr, 10) || 0;
          }
        }

        if (videoId) {
          videoId = decodeURIComponent(videoId).trim();
          let docData: any = null;
          const vDoc = await db.collection("videos").doc(videoId).get();
          if (vDoc.exists) {
            docData = vDoc.data();
          }

          if (docData) {
            const claims = Array.isArray(docData.claims) ? docData.claims : [];
            const claim = claims[claimIndex] || claims[0] || {};
            const claimText = claim.claimText || claim.statement || claim.text || docData.title || "Fact Check Verification";
            const verdictLabel = claim.verdict || claim.verdictLabel || "Verified";
            const summaryTakeaway = claim.explanation || claim.summary || docData.description || "";
            const confidenceText = claim.confidenceScore ? `${Math.round(claim.confidenceScore * 100)}% Confidence` : "";
            const videoTitle = docData.title || "";
            const channelName = docData.channelName || "";
            const videoThumb = await resolveVideoImage(db, docData);

            if (isClaimCardImageRequest) {
              try {
                const cardBuffer = await renderClaimCardImage({
                  claimText,
                  verdictLabel,
                  summaryTakeaway,
                  confidenceText,
                  videoTitle,
                  channelName,
                  thumbnailUrl: videoThumb,
                  videoId,
                  claimIndex,
                });

                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
                res.status(200).send(cardBuffer);
                return;
              } catch (cardErr) {
                console.error("Failed to generate dynamic claim card image, falling back", cardErr);
                const fallbackBuffer = await renderClaimCardImage({
                  claimText: claimText || "Truthworld Fact Check",
                  verdictLabel: "Verified",
                  videoTitle,
                  videoId,
                });
                res.set("Content-Type", "image/png");
                res.set("Cache-Control", "public, max-age=3600");
                res.status(200).send(fallbackBuffer);
                return;
              }
            }

            const cardImageUrl = `${DOMAIN}/api/og/claim/${videoId}/${claimIndex}.png`;
            // Industry standard: Social scrapers strictly drop images > 300KB. Always serve the optimized card.
            const finalClaimImage = cardImageUrl;
            const pageTitle = `Fact Check: "${claimText}" - Truthworld`;
            const pageDescription = `Fact check analysis for "${claimText}" from ${videoTitle ? `"${videoTitle}"` : "Truthworld"}. Verdict: ${verdictLabel}. Verified on Truthworld.`;

            const finalHtml = buildSemanticSsrHtml({
              title: pageTitle,
              description: pageDescription,
              url: canonicalUrl,
              image: finalClaimImage,
              imageWidth: 1024,
              imageHeight: 848,
              type: "article",
              contentHeading: `Fact Check: ${claimText}`,
              robots: "index, follow",
            });

            const cacheKey = `claim_v5_${videoId}_${claimIndex}`;
            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          } else {
            if (isClaimCardImageRequest) {
              const fallbackBuffer = await renderClaimCardImage({
                claimText: "Truthworld Fact Check",
                verdictLabel: "Verified",
              });
              res.set("Content-Type", "image/png");
              res.set("Cache-Control", "public, max-age=3600");
              res.status(200).send(fallbackBuffer);
              return;
            }
            const baseHtml = await fetchIndexHtml();
            res.status(404).send(baseHtml);
            return;
          }
        } else {
          if (isClaimCardImageRequest) {
            const fallbackBuffer = await renderClaimCardImage({
              claimText: "Truthworld Fact Check",
              verdictLabel: "Verified",
            });
            res.set("Content-Type", "image/png");
            res.set("Cache-Control", "public, max-age=3600");
            res.status(200).send(fallbackBuffer);
            return;
          }
          const baseHtml = await fetchIndexHtml();
          res.status(404).send(baseHtml);
          return;
        }
      }

      // COMMUNITY POST ROUTE
      const isCommunityGuideline = lowerPath.startsWith("/community-guidelines") || lowerPath.startsWith("/community_guidelines");
      if (!isCommunityGuideline && (lowerPath.startsWith("/post") || lowerPath.startsWith("/community/") || lowerPath.startsWith("/p/"))) {
        let postId = (req.query.id || req.query.postId || req.query.p) as string;
        if (!postId) {
          const parts = path.split("/").filter(p => p.length > 0);
          if (parts.length >= 2) {
            postId = parts[1];
          }
        }
        if (postId) {
          postId = decodeURIComponent(postId).trim().replace(/\/$/, "");
          const cacheKey = `post_v5_${postId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let postData: any = null;

          // 1. Check Community collection (TruthWorld standard collection)
          const docCommunity = await db.collection("Community").doc(postId).get();
          if (docCommunity.exists) {
            postData = { id: docCommunity.id, ...docCommunity.data() };
          }

          // 2. Check community_posts collection
          if (!postData) {
            const docPosts = await db.collection("community_posts").doc(postId).get();
            if (docPosts.exists) postData = { id: docPosts.id, ...docPosts.data() };
          }

          // 3. Check posts collection
          if (!postData) {
            const docGeneral = await db.collection("posts").doc(postId).get();
            if (docGeneral.exists) postData = { id: docGeneral.id, ...docGeneral.data() };
          }

          // 4. Check lowercase community collection
          if (!postData) {
            const docLower = await db.collection("community").doc(postId).get();
            if (docLower.exists) postData = { id: docLower.id, ...docLower.data() };
          }

          if (postData) {
            const status = (postData.status || "").toLowerCase();
            const isPrivate = (postData.visibility || "").toLowerCase() === "private";

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

            const rawContent = (postData.content || postData.text || postData.description || postData.title || "").trim();
            const cleanText = rawContent.replace(/\s+/g, " ");
            const postTitle = postData.title || (cleanText.length > 0 ? (cleanText.length > 70 ? cleanText.substring(0, 70) + "..." : cleanText) : "Community Post");
            const authorName = postData.channelName || postData.creatorName || postData.authorName || "Creator";
            const authorUrl = postData.channelId ? `${DOMAIN}/channel/${postData.channelId}` : DOMAIN;
            const postSchema = generateCommunityPostSchema({ id: postData.id, ...postData }, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: authorName, url: authorUrl },
              { name: postTitle, url: canonicalUrl }
            ]);

            // Extract authentic post image or fallback to creator's channel avatar
            let rawPostImg = (Array.isArray(postData.images) && postData.images.length > 0 ? postData.images[0] : undefined) ||
              (Array.isArray(postData.media) && postData.media.length > 0 ? postData.media[0] : undefined) ||
              postData.imageUrl ||
              postData.image ||
              postData.mediaUrl ||
              postData.thumbnailUrl ||
              postData.channelImage ||
              postData.channelAvatarUrl;

            if (!rawPostImg && postData.channelId) {
              try {
                const chDoc = await db.collection("channels").doc(postData.channelId).get();
                if (chDoc.exists) {
                  const chData = chDoc.data()!;
                  rawPostImg = chData.avatarUrl || chData.photoUrl || chData.imageUrl || chData.bannerUrl;
                }
              } catch (e) {
                console.warn(`Error resolving creator avatar for post ${postId}:`, e);
              }
            }

            const finalPostImage = ensureAbsoluteImageUrl(rawPostImg) || `${DOMAIN}/icons/og-image.png`;

            const finalHtml = buildSemanticSsrHtml({
              title: `${postTitle} - Post by ${authorName} | Truthworld`,
              description: cleanText.length > 0 ? cleanText.substring(0, 200) : `Community post by ${authorName} on Truthworld.`,
              url: canonicalUrl,
              image: finalPostImage,
              imageWidth: 1200,
              imageHeight: 630,
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

      // SETTINGS & STUDIO ROUTES (Private Pages - Direct App Loading, Exclude from Search Engines)
      if (
        lowerPath === "/settings" ||
        lowerPath.startsWith("/settings/") ||
        lowerPath === "/studio" ||
        lowerPath.startsWith("/studio/")
      ) {
        res.set("X-Robots-Tag", "noindex, nofollow");
        const baseHtml = await fetchIndexHtml();
        res.status(200).send(baseHtml.replace("</head>", '<meta name="robots" content="noindex, nofollow" /></head>'));
        return;
      }

      // ─── 2b. ADVERTISEMENTS / ADVERTISER ROUTE ──────────────────────────────
      // 301 Redirect alternative advertiser paths to the canonical /advertisements URL
      if (
        lowerPath === "/advertiser" ||
        lowerPath.startsWith("/advertiser/") ||
        lowerPath === "/ads" ||
        lowerPath.startsWith("/ads/")
      ) {
        const targetUrl = `${DOMAIN}/advertisements`;
        res.redirect(301, targetUrl);
        return;
      }

      // CANONICAL ADVERTISEMENTS ROUTE (/advertisements, /advertisements/**)
      if (
        lowerPath === "/advertisements" ||
        lowerPath.startsWith("/advertisements/")
      ) {
        const canonicalAdvertisementsUrl = `${DOMAIN}/advertisements`;
        const cacheKey = `advertisements_canonical_page_v5`;
        const cached = await getCachedSnapshot(cacheKey);
        if (cached) {
          logSeoEvent({ eventType: "cache_hit", path: canonicalAdvertisementsUrl, durationMs: Date.now() - startTime });
          sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
          return;
        }

        const adBreadcrumbs = generateBreadcrumbData([
          { name: "Truthworld Advertisements", url: canonicalAdvertisementsUrl }
        ]);

        const adServiceSchema = {
          "@context": "https://schema.org",
          "@type": "Service",
          "name": "Truthworld Video Advertisements Platform",
          "provider": {
            "@type": "Organization",
            "name": "Truthworld",
            "url": DOMAIN
          },
          "url": canonicalAdvertisementsUrl,
          "serviceType": "Video Advertising & Brand Promotion",
          "description": "High-impact video advertising platform offering targeted in-stream video ads, AI-powered multilingual dubbing in 70+ languages, and verified engagement analytics.",
          "offers": {
            "@type": "Offer",
            "priceCurrency": "USD",
            "description": "Custom budget campaigns with flexible CPV, CPM, and direct creator sponsorships"
          }
        };

        const adFaqSchema = {
          "@context": "https://schema.org",
          "@type": "FAQPage",
          "mainEntity": [
            {
              "@type": "Question",
              "name": "What ad formats are available on Truthworld?",
              "acceptedAnswer": {
                "@type": "Answer",
                "text": "Truthworld provides high-impact in-stream video ads, non-skippable mid-roll ads, interactive pinned sponsor comments, display banners, and direct creator sponsorship integrations."
              }
            },
            {
              "@type": "Question",
              "name": "How does Truthworld's AI dubbing and localization benefit advertisers?",
              "acceptedAnswer": {
                "@type": "Answer",
                "text": "Advertiser campaigns on Truthworld can be automatically localized with AI audio dubbing into 70+ languages and subtitles into 100+ languages, allowing your brand to reach global audiences seamlessly without expensive multi-language production shoots."
              }
            },
            {
              "@type": "Question",
              "name": "How does audience targeting work for Truthworld video ads?",
              "acceptedAnswer": {
                "@type": "Answer",
                "text": "You can target engaged viewers using granular topic categories, verified channel niches, geographic locations, languages, and viewer demographics with real-time performance optimization."
              }
            },
            {
              "@type": "Question",
              "name": "What metrics and analytics are provided to advertisers?",
              "acceptedAnswer": {
                "@type": "Answer",
                "text": "Advertisers have full access to real-time analytics including verified impressions, video completion rate (VCR), click-through rate (CTR), cost-per-view (CPV), audience demographics, and conversions."
              }
            },
            {
              "@type": "Question",
              "name": "How do I launch a video advertisement campaign on Truthworld?",
              "acceptedAnswer": {
                "@type": "Answer",
                "text": "Simply log in with your Truthworld account at https://www.truthworld.in/advertisements, upload your video or creative assets, configure your target audience and budget, and submit your campaign for review."
              }
            }
          ]
        };

        const richAdvertisementsHtml = `
  <section style="margin-top: 32px; border-top: 1px solid #27272a; padding-top: 24px;">
    <h2 style="font-size: 20px; font-weight: bold; color: #f4f4f5; margin-bottom: 12px;">Grow Your Brand with Verified High-Retention Video Ads</h2>
    <p style="line-height: 1.6; color: #d4d4d8; font-size: 15px; margin-bottom: 16px;">
      Truthworld Advertisements connects businesses, creators, and brands with highly engaged, family-safe audiences. Our platform combines next-generation video streaming with AI-powered moderation, ensuring brand safety alongside unmatched retention and viewer trust.
    </p>

    <h3 style="font-size: 18px; font-weight: 600; color: #c084fc; margin: 20px 0 10px;">Why Advertise on Truthworld?</h3>
    <ul style="line-height: 1.8; color: #d4d4d8; font-size: 14px; padding-left: 20px; margin-bottom: 20px;">
      <li><strong>Unmatched Brand Safety:</strong> Automated fact-checking and AI content moderation ensure your brand only appears alongside verified, brand-safe video content.</li>
      <li><strong>AI Multilingual Localization:</strong> Automatically dub your commercial video creatives into 70+ languages and generate subtitles in 100+ languages to capture international markets at zero extra production cost.</li>
      <li><strong>High View-Through Rates:</strong> Non-intrusive ad placement and intelligent frequency capping keep viewers engaged without ad fatigue.</li>
      <li><strong>Granular Audience Targeting:</strong> Segment audiences by niche topics, creator channels, geographic territory, viewer language, and device type.</li>
      <li><strong>Transparent Metrics & Real-time ROI:</strong> Detailed dashboard reporting verified impressions, completion rates, click-through rates, and conversion attribution.</li>
    </ul>

    <h3 style="font-size: 18px; font-weight: 600; color: #c084fc; margin: 20px 0 10px;">Supported Video Ad Formats</h3>
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-bottom: 24px;">
      <div style="background: #18181b; padding: 16px; border-radius: 8px; border: 1px solid #27272a;">
        <h4 style="color: #ffffff; font-size: 16px; margin-bottom: 8px;">In-Stream Pre-Roll & Mid-Roll</h4>
        <p style="color: #a1a1aa; font-size: 13px; line-height: 1.5;">Deliver 15s to 30s video spots directly inside high-engagement video content with interactive call-to-action buttons.</p>
      </div>
      <div style="background: #18181b; padding: 16px; border-radius: 8px; border: 1px solid #27272a;">
        <h4 style="color: #ffffff; font-size: 16px; margin-bottom: 8px;">Direct Creator Sponsorships</h4>
        <p style="color: #a1a1aa; font-size: 13px; line-height: 1.5;">Partner with verified creators for sponsored channel integrations, pinned commentary, and product showcases.</p>
      </div>
      <div style="background: #18181b; padding: 16px; border-radius: 8px; border: 1px solid #27272a;">
        <h4 style="color: #ffffff; font-size: 16px; margin-bottom: 8px;">Interactive Feed Banners</h4>
        <p style="color: #a1a1aa; font-size: 13px; line-height: 1.5;">Promote products, apps, and services in Truthworld's trending and topic discovery feeds.</p>
      </div>
      <div style="background: #18181b; padding: 16px; border-radius: 8px; border: 1px solid #27272a;">
        <h4 style="color: #ffffff; font-size: 16px; margin-bottom: 8px;">Multilingual Dubbed Ads</h4>
        <p style="color: #a1a1aa; font-size: 13px; line-height: 1.5;">Leverage our AI voice cloning and lip-sync pipeline to broadcast your advertisement in any regional dialect.</p>
      </div>
    </div>

    <h3 style="font-size: 18px; font-weight: 600; color: #c084fc; margin: 24px 0 12px;">Frequently Asked Questions</h3>
    <div style="background: #12011f; padding: 16px; border-radius: 8px; border: 1px solid #3b0764; margin-bottom: 24px;">
      <details style="margin-bottom: 12px; cursor: pointer;" open>
        <summary style="font-weight: 600; color: #f4f4f5; font-size: 15px; padding: 6px 0;">What is the minimum campaign budget on Truthworld?</summary>
        <p style="color: #d4d4d8; font-size: 14px; line-height: 1.6; margin-top: 6px; padding-left: 12px;">You have 100% control over your daily and total campaign budget. Start testing campaigns with small initial budgets and scale as you verify positive ROI and conversion metrics.</p>
      </details>
      <details style="margin-bottom: 12px; cursor: pointer;">
        <summary style="font-weight: 600; color: #f4f4f5; font-size: 15px; padding: 6px 0;">How does AI dubbing for ad creatives work?</summary>
        <p style="color: #d4d4d8; font-size: 14px; line-height: 1.6; margin-top: 6px; padding-left: 12px;">When you submit your video ad in our portal, you can enable AI Localization. Our system automatically transcribes, translates, and generates studio-quality voiceovers in selected languages (Hindi, Spanish, Telugu, Tamil, French, German, Japanese, etc.) maintaining the emotional tone of your original creative.</p>
      </details>
      <details style="margin-bottom: 12px; cursor: pointer;">
        <summary style="font-weight: 600; color: #f4f4f5; font-size: 15px; padding: 6px 0;">How are ads reviewed before going live?</summary>
        <p style="color: #d4d4d8; font-size: 14px; line-height: 1.6; margin-top: 6px; padding-left: 12px;">All ad campaigns undergo automated multimodal Gemini AI moderation and editorial review to verify adherence to our Community Guidelines, factuality standards, and brand safety compliance within 24 hours.</p>
      </details>
      <details style="margin-bottom: 6px; cursor: pointer;">
        <summary style="font-weight: 600; color: #f4f4f5; font-size: 15px; padding: 6px 0;">How do I track impressions and conversions?</summary>
        <p style="color: #d4d4d8; font-size: 14px; line-height: 1.6; margin-top: 6px; padding-left: 12px;">The Truthworld Advertiser Studio provides interactive graphs, click attribution, viewer retention curves, and downloadable CSV audit reports for every active and completed campaign.</p>
      </details>
    </div>

    <div style="text-align: center; margin: 32px 0 16px;">
      <a href="https://www.truthworld.in/advertisements" style="display: inline-block; background: #9B30FF; color: #ffffff; padding: 14px 28px; border-radius: 8px; font-weight: bold; font-size: 16px; text-decoration: none; box-shadow: 0 4px 14px rgba(155, 48, 255, 0.4);">Launch Your Campaign on Truthworld</a>
    </div>
  </section>`;

        const finalHtml = buildSemanticSsrHtml({
          title: "Truthworld Advertisements - Video Ad Campaigns & High-ROI Brand Growth",
          description: "Reach engaged viewers with targeted video advertisement campaigns, AI multilingual dubbing in 70+ languages, transparent analytics, and high ROI on Truthworld Advertisements.",
          url: canonicalAdvertisementsUrl,
          type: "website",
          robots: "index, follow",
          jsonLd: [adServiceSchema, adFaqSchema, adBreadcrumbs.jsonLd, ...orgSchemas],
          breadcrumbHtml: adBreadcrumbs.html,
          contentHeading: "Truthworld Advertisements - Video Ad Platform & Brand Growth",
          customBodyHtml: richAdvertisementsHtml
        });

        const saved = await saveSnapshot(cacheKey, finalHtml);
        sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
        return;
      }

      // ─── 3. Fallback / Default Homepage HTML ─────────────────────────────────
      const homeCacheKey = "homepage_v6_ssr";
      const cachedHome = await getCachedSnapshot(homeCacheKey);
      if (cachedHome) {
        logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
        sendHtmlResponse(req, res, cachedHome.html, cachedHome.etag, cachedHome.lastModified);
        return;
      }

      // Fetch featured public videos
      let featuredVideos: any[] = [];
      try {
        let vSnap = await db.collection("videos")
          .where("visibility", "in", ["public", "Public"])
          .limit(16)
          .get();

        if (vSnap.empty) {
          vSnap = await db.collection("videos")
            .where("status", "in", ["published", "ready", "active"])
            .limit(16)
            .get();
        }
        if (vSnap.empty) {
          vSnap = await db.collection("videos").limit(16).get();
        }

        vSnap.forEach(d => {
          const data = d.data();
          const st = (data.status || "").toLowerCase();
          const vis = (data.visibility || "public").toLowerCase();
          const rawTitle = (data.title || "").trim();
          const lowerTitle = rawTitle.toLowerCase();

          if (
            st !== "deleted" &&
            st !== "rejected" &&
            st !== "draft" &&
            vis !== "private" &&
            vis !== "draft" &&
            rawTitle &&
            lowerTitle !== "untitled" &&
            !lowerTitle.startsWith("untitled") &&
            !lowerTitle.startsWith("uploading")
          ) {
            featuredVideos.push({ id: d.id, ...data, title: rawTitle });
          }
        });
      } catch (err) {
        console.warn("Failed to fetch featured videos for homepage SSR", err);
      }

      // Fetch featured creator channels
      let featuredChannels: any[] = [];
      try {
        const cSnap = await db.collection("channels").limit(8).get();
        cSnap.forEach(d => {
          const data = d.data();
          const st = (data.status || "").toLowerCase();
          const name = (data.displayName || data.name || data.channelName || "").trim();
          if (st !== "suspended" && st !== "banned" && st !== "deleted" && name && !name.toLowerCase().startsWith("untitled")) {
            featuredChannels.push({ id: d.id, ...data, resolvedName: name });
          }
        });
      } catch (err) {
        console.warn("Failed to fetch featured channels for homepage SSR", err);
      }

      // Fetch active topics
      let popularTopics: any[] = [];
      try {
        const tSnap = await db.collection("topics").limit(12).get();
        tSnap.forEach(d => {
          const data = d.data();
          const st = (data.status || "").toLowerCase();
          const slug = (data.slug || d.id).trim();
          const title = (data.title || data.name || "").trim();
          if (st !== "deleted" && st !== "inactive" && slug && title && !title.toLowerCase().startsWith("untitled")) {
            popularTopics.push({ slug, title });
          }
        });
      } catch (err) {
        console.warn("Failed to fetch popular topics for homepage SSR", err);
      }

      // JSON-LD ItemList for featured videos
      const videoItemListSchema = featuredVideos.length > 0 ? {
        "@context": "https://schema.org",
        "@type": "ItemList",
        "name": "Featured & Trending Videos on Truthworld",
        "itemListElement": featuredVideos.map((v, idx) => ({
          "@type": "ListItem",
          "position": idx + 1,
          "item": {
            "@type": "VideoObject",
            "name": v.title,
            "description": v.description || `Watch ${v.title} on Truthworld.`,
            "thumbnailUrl": [ensureAbsoluteImageUrl(v.thumbnailUrl || v.thumbnail) || `${DOMAIN}/icons/og-image.png`],
            "uploadDate": formatDate(v.uploadedAt || v.createdAt),
            "url": `${DOMAIN}/watch?v=${v.id}`
          }
        }))
      } : null;

      const homepageSchemas = videoItemListSchema ? [...orgSchemas, videoItemListSchema] : orgSchemas;

      // Construct semantic HTML body
      let homepageBodyHtml = `
  <section class="tw-hero" style="margin-bottom: 32px; padding: 24px; background: linear-gradient(135deg, #180029 0%, #0d0014 100%); border-radius: 12px; border: 1px solid #3b0764;">
    <h2 style="font-size: 22px; font-weight: bold; color: #ffffff; margin-bottom: 8px;">Watch Verified Videos, AI-Dubbed in 70+ Languages</h2>
    <p style="color: #d4d4d8; font-size: 15px; line-height: 1.6; max-width: 800px;">
      Watch family-safe videos with AI dubbing in 70+ languages &amp; 100+ subtitles. Automated fact-checking, creator studio tools, and 100% creator revenue.
    </p>
  </section>
      `;

      if (featuredVideos.length > 0) {
        homepageBodyHtml += `
  <section class="tw-featured-videos" style="margin-bottom: 40px;">
    <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 16px;">
      <h2 style="font-size: 20px; font-weight: bold; color: #f4f4f5;">Trending & Featured Videos</h2>
      <a href="${DOMAIN}/trending" style="color: #c084fc; font-size: 14px; text-decoration: none; font-weight: 500;">View all trending &rarr;</a>
    </div>
    <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 20px;">
        `;
        for (const v of featuredVideos) {
          const vTitle = escapeHtml((v.title || "Video").trim());
          const vUrl = `${DOMAIN}/watch?v=${v.id}`;
          const vImg = escapeHtml(ensureAbsoluteImageUrl(v.thumbnailUrl || v.thumbnail) || `${DOMAIN}/icons/og-image.png`);
          const cName = escapeHtml(v.channelName || "Creator");
          const cHandle = v.channelHandle ? `@${v.channelHandle.replace(/^@/, "")}` : "";
          const cUrl = cHandle ? `${DOMAIN}/${cHandle}` : (v.channelId ? `${DOMAIN}/channel/${v.channelId}` : DOMAIN);
          const viewCount = v.viewCount || v.views || 0;
          const viewStr = viewCount >= 1000 ? `${(viewCount / 1000).toFixed(1)}K views` : `${viewCount} views`;

          homepageBodyHtml += `
      <article style="background: #140521; border: 1px solid #27272a; border-radius: 10px; overflow: hidden; display: flex; flex-direction: column;">
        <a href="${vUrl}" style="text-decoration: none; display: block; position: relative; aspect-ratio: 16/9; background: #000; overflow: hidden;">
          <img src="${vImg}" alt="${vTitle}" loading="lazy" style="width: 100%; height: 100%; object-fit: cover;" />
        </a>
        <div style="padding: 12px; display: flex; flex-direction: column; flex-grow: 1;">
          <h3 style="font-size: 15px; font-weight: 600; line-height: 1.4; margin-bottom: 6px;">
            <a href="${vUrl}" style="color: #f4f4f5; text-decoration: none;">${vTitle}</a>
          </h3>
          <div style="margin-top: auto; font-size: 13px; color: #a1a1aa;">
            <a href="${cUrl}" style="color: #c084fc; text-decoration: none; font-weight: 500;">${cName}</a>
            <div style="margin-top: 4px; font-size: 12px; color: #71717a;">${viewStr}</div>
          </div>
        </div>
      </article>`;
        }
        homepageBodyHtml += `\n    </div>\n  </section>`;
      }

      if (featuredChannels.length > 0) {
        homepageBodyHtml += `
  <section class="tw-featured-channels" style="margin-bottom: 40px;">
    <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 16px;">
      <h2 style="font-size: 20px; font-weight: bold; color: #f4f4f5;">Popular Creator Channels</h2>
      <a href="${DOMAIN}/browse" style="color: #c084fc; font-size: 14px; text-decoration: none; font-weight: 500;">Explore all channels &rarr;</a>
    </div>
    <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 16px;">
        `;
        for (const c of featuredChannels) {
          const handle = (c.handle || "").replace(/^@/, "");
          const cUrl = handle ? `${DOMAIN}/@${handle}` : `${DOMAIN}/channel/${c.id}`;
          const cName = escapeHtml(c.resolvedName);
          const cImg = escapeHtml(ensureAbsoluteImageUrl(c.avatarUrl || c.photoUrl || c.imageUrl) || `${DOMAIN}/icons/Icon-192.png`);
          const subs = c.subscriberCount || c.subscribers || c.stats?.subscriberCount || 0;
          const subStr = subs >= 1000 ? `${(subs / 1000).toFixed(1)}K subscribers` : `${subs} subscribers`;

          homepageBodyHtml += `
      <div style="background: #140521; border: 1px solid #27272a; border-radius: 8px; padding: 16px; text-align: center;">
        <a href="${cUrl}" style="text-decoration: none; display: inline-block;">
          <img src="${cImg}" alt="${cName}" loading="lazy" style="width: 64px; height: 64px; border-radius: 50%; object-fit: cover; margin-bottom: 8px; border: 2px solid #9B30FF;" />
          <h3 style="color: #f4f4f5; font-size: 14px; font-weight: 600; margin-bottom: 4px;">${cName}</h3>
        </a>
        <p style="color: #a1a1aa; font-size: 12px;">${subStr}</p>
      </div>`;
        }
        homepageBodyHtml += `\n    </div>\n  </section>`;
      }

      if (popularTopics.length > 0) {
        homepageBodyHtml += `
  <section class="tw-popular-topics" style="margin-bottom: 32px;">
    <h2 style="font-size: 18px; font-weight: bold; color: #f4f4f5; margin-bottom: 12px;">Explore Topics & Categories</h2>
    <div style="display: flex; flex-wrap: wrap; gap: 10px;">
        `;
        for (const t of popularTopics) {
          homepageBodyHtml += `<a href="${DOMAIN}/topic/${t.slug}" style="background: #1f0b2f; color: #e9d5ff; border: 1px solid #581c87; padding: 6px 14px; border-radius: 20px; font-size: 13px; text-decoration: none; font-weight: 500;">#${escapeHtml(t.title)}</a>`;
        }
        homepageBodyHtml += `\n    </div>\n  </section>`;
      }

      const homepageHtml = buildSemanticSsrHtml({
        title: "Truthworld - Watch, Share & Create Verified Videos",
        description: "Watch family-safe videos with AI dubbing in 70+ languages & 100+ subtitles. Automated fact-checking, creator studio tools, and 100% creator revenue.",
        url: canonicalUrl,
        type: "website",
        jsonLd: homepageSchemas,
        customBodyHtml: homepageBodyHtml,
        relatedItems: featuredVideos.slice(0, 8).map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` })),
        topicItems: popularTopics.slice(0, 8).map(t => ({ title: `#${t.title}`, url: `${DOMAIN}/topic/${t.slug}` }))
      });

      const savedHome = await saveSnapshot(homeCacheKey, homepageHtml);
      sendHtmlResponse(req, res, homepageHtml, savedHome.etag, savedHome.lastModified);
      return;

    } catch (error) {
      console.error("SEO Server Error:", error);
      const baseHtml = await fetchIndexHtml();
      res.status(200).send(baseHtml);
      return;
    }
  }
);
