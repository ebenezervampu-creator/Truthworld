import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import axios from "axios";
import { Request, Response } from "express";
import { DOMAIN } from "./schema/schemaConfig";
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
    const bucket = admin.storage().bucket();
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
  // 1. Direct channel image fields (banner -> cover -> avatar -> photo)
  let img = ensureAbsoluteImageUrl(
    docData.bannerUrl ||
    docData.coverUrl ||
    docData.banner ||
    docData.avatarUrl ||
    docData.photoUrl ||
    docData.profile?.photoUrl ||
    docData.profilePicture ||
    docData.imageUrl ||
    docData.iconUrl
  );
  if (img) return img;

  // 2. Fallback to channel's latest video thumbnail
  try {
    const vSnap = await db.collection("videos")
      .where("channelId", "==", channelId)
      .where("visibility", "==", "public")
      .orderBy("uploadedAt", "desc")
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

      // WATCH ROUTE
      if (path.startsWith("/watch")) {
        let videoId = req.query.v as string;
        if (!videoId && path.split("/").length > 2) {
          videoId = path.split("/")[2];
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
            if (docData.channelId) {
              const cDoc = await db.collection("channels").doc(docData.channelId).get();
              if (cDoc.exists) {
                const cData = cDoc.data()!;
                channelName = cData.displayName || cData.name || channelName;
                channelHandle = cData.handle || "";
              }
            }
            const authorUrl = channelHandle 
              ? `${DOMAIN}/${channelHandle.startsWith("@") ? channelHandle : `@${channelHandle}`}`
              : `${DOMAIN}/channel/${docData.channelId}`;

            const videoImage = await resolveVideoImage(db, docData);
            const videoSchema = generateVideoSchema({ id: docId, ...docData } as any, authorUrl, channelName);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: authorUrl },
              { name: docData.title || "Video", url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${docData.title} - Truthworld`,
              description: docData.description || `Watch ${docData.title} on Truthworld.`,
              url: canonicalUrl,
              image: videoImage,
              type: "video.other",
              robots: visibility === "unlisted" ? "noindex, nofollow" : "index, follow",
              jsonLd: [videoSchema, breadcrumbs.jsonLd, ...orgSchemas],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: docData.title,
              authorName: channelName,
              authorUrl: authorUrl,
              transcriptExcerpt: docData.transcript || docData.captionsText
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          }
        }
      }

      // CHANNEL / HANDLE ROUTE
      if (path.startsWith("/channel/") || path.startsWith("/@") || path.startsWith("/c/") || path.startsWith("/user/")) {
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
            const channelName = docData.displayName || docData.name || "Channel";
            const channelImage = await resolveChannelImage(db, docData.id, docData);
            const channelSchema = generateChannelSchema(docData, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${channelName} - Truthworld`,
              description: docData.about || docData.description || `Watch videos from ${channelName} on Truthworld.`,
              url: canonicalUrl,
              image: channelImage,
              type: "profile",
              robots: "index, follow",
              jsonLd: [channelSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: channelName,
              authorName: channelName,
              authorUrl: canonicalUrl
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          }
        }
      }

      // TOPIC ROUTE
      if (path.startsWith("/topic") || path.startsWith("/topics") || path.startsWith("/T/") || path.startsWith("/t/")) {
        let slug = (req.query.id || req.query.slug) as string;
        if (!slug) {
          const parts = path.split("/").filter(p => p.length > 0);
          if (parts.length >= 2) {
            slug = parts[1];
          } else if (parts.length === 1 && (parts[0] !== "topic" && parts[0] !== "topics" && parts[0] !== "T" && parts[0] !== "t")) {
            slug = parts[0];
          }
        }

        if (slug) {
          const cleanSlug = slug.replace(/^(T\/|t\/)/i, "").trim();
          const cacheKey = `topic_v2_${cleanSlug.toLowerCase()}`;
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

          if (docData && docData.status !== "deleted" && docData.status !== "inactive") {
            const topicTitle = docData.title || docData.name || "Topic";
            const topVideos: any[] = [];
            try {
              const vSnap = await db.collection("videos")
                .where("visibility", "==", "public")
                .where("topics", "array-contains", docData.id)
                .orderBy("uploadedAt", "desc")
                .limit(10).get();
              vSnap.forEach((d) => topVideos.push({ id: d.id, ...d.data() }));
            } catch (err) {
              console.error("Error fetching topic videos", err);
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
            const topicDescription = docData.description && docData.description.trim().length > 0
              ? `${docData.description.trim()} • ${followerCount} Followers • ${videoCount} Videos on Truthworld`
              : `Explore top videos and discussions in ${topicTitle} • ${followerCount} Followers • ${videoCount} Videos on Truthworld.`;

            const topicSchema = generateTopicSchema(docData, canonicalUrl, topVideos);
            const breadcrumbs = generateBreadcrumbData([
              { name: topicTitle, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${topicTitle} - Topic | Truthworld`,
              description: topicDescription,
              url: canonicalUrl,
              image: topicImage,
              type: "website",
              robots: "index, follow",
              jsonLd: [topicSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: `${topicTitle} Topic`,
              relatedItems: topVideos.map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` }))
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          }
        }
      }

      // PLAYLIST ROUTE
      if (path.startsWith("/playlist")) {
        let playlistId = req.query.list as string;
        if (!playlistId && path.split("/").length > 2) {
          playlistId = path.split("/")[2];
        }
        if (playlistId) {
          const cacheKey = `playlist_v2_${playlistId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let docData: any = null;

          // 1. Check public_playlists by doc ID
          const docPub = await db.collection("public_playlists").doc(playlistId).get();
          if (docPub.exists) {
            docData = { id: docPub.id, ...(docPub.data() as any) };
          }

          // 2. Check playlists by doc ID
          if (!docData) {
            const docPriv = await db.collection("playlists").doc(playlistId).get();
            if (docPriv.exists) {
              docData = { id: docPriv.id, ...(docPriv.data() as any) };
            }
          }

          // 3. Query public_playlists by playlistId field
          if (!docData) {
            const qs = await db.collection("public_playlists").where("playlistId", "==", playlistId).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 4. Query playlists by playlistId field
          if (!docData) {
            const qs = await db.collection("playlists").where("playlistId", "==", playlistId).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          // 5. Query channel_playlists by doc ID
          if (!docData) {
            const docCp = await db.collection("channel_playlists").doc(playlistId).get();
            if (docCp.exists) docData = { id: docCp.id, ...(docCp.data() as any) };
          }

          if (docData) {
            const playlistName = docData.playlistName || docData.name || docData.title || "Playlist";
            const playlistImage = await resolvePlaylistImage(db, docData.id, docData);
            const playlistSchema = generatePlaylistSchema({ id: docData.id, ...docData }, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: playlistName, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${playlistName} - Playlist | Truthworld`,
              description: docData.description || `Watch this playlist on Truthworld.`,
              url: canonicalUrl,
              image: playlistImage,
              type: "website",
              robots: docData.visibility === "private" ? "noindex, nofollow" : "index, follow",
              jsonLd: [playlistSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: playlistName
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          }
        }
      }

      // COMMUNITY POST ROUTE
      if (path.startsWith("/post") || path.startsWith("/community")) {
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

          const doc = await db.collection("community_posts").doc(postId).get();
          if (doc.exists) {
            const data = doc.data()!;
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
              robots: data.visibility === "Private" ? "noindex, nofollow" : "index, follow",
              jsonLd: [postSchema, breadcrumbs.jsonLd],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: postTitle,
              authorName: authorName,
              authorUrl: authorUrl
            });

            const saved = await saveSnapshot(cacheKey, finalHtml);
            sendHtmlResponse(req, res, finalHtml, saved.etag, saved.lastModified);
            return;
          }
        }
      }

      // SETTINGS ROUTE (Private Page - Exclude from Search Engines)
      if (path === "/settings" || path.startsWith("/settings/")) {
        res.set("X-Robots-Tag", "noindex, nofollow");
        const baseHtml = await fetchIndexHtml();
        res.status(200).send(baseHtml.replace("</head>", '<meta name="robots" content="noindex, nofollow" /></head>'));
        return;
      }

      // STUDIO ROUTE
      if (path === "/studio" || path.startsWith("/studio/")) {
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
        path === "/advertiser" ||
        path.startsWith("/advertiser/") ||
        path === "/advertisements" ||
        path.startsWith("/advertisements/") ||
        path === "/ads" ||
        path.startsWith("/ads/")
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
