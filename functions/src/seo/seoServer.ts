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
  generatePlaylistsSitemap
} from "./sitemap/sitemapGenerator";

let cachedIndexHtml: string | null = null;

async function fetchIndexHtml(): Promise<string> {
  if (cachedIndexHtml) return cachedIndexHtml;
  try {
    const response = await axios.get(`${DOMAIN}/index.html`);
    cachedIndexHtml = response.data;
    return cachedIndexHtml!;
  } catch (e) {
    console.error("Failed to fetch index.html", e);
    return `<!DOCTYPE html><html><head><title>Truthworld</title></head><body></body></html>`;
  }
}

function sendHtmlResponse(req: Request, res: Response, html: string, etagStr: string, lastModifiedStr: string): void {
  // Check conditional GET request (If-None-Match)
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
          const cacheKey = `watch_${videoId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          // L3 Fallback Generation
          logSeoEvent({ eventType: "cache_miss", path: canonicalUrl, durationMs: Date.now() - startTime });
          const doc = await db.collection("videos").doc(videoId).get();
          if (doc.exists) {
            const data = doc.data()!;
            const status = (data.status || "").toLowerCase();
            const visibility = (data.visibility || "").toLowerCase();

            if (status === "deleted" || visibility === "private") {
              const baseHtml = await fetchIndexHtml();
              res.status(404).send(baseHtml);
              return;
            }

            let channelName = data.channelName || "Channel";
            let channelHandle = "";
            if (data.channelId) {
              const cDoc = await db.collection("channels").doc(data.channelId).get();
              if (cDoc.exists) {
                const cData = cDoc.data()!;
                channelName = cData.displayName || cData.name || channelName;
                channelHandle = cData.handle || "";
              }
            }
            const authorUrl = channelHandle 
              ? `${DOMAIN}/${channelHandle.startsWith("@") ? channelHandle : `@${channelHandle}`}`
              : `${DOMAIN}/channel/${data.channelId}`;

            const videoSchema = generateVideoSchema({ id: doc.id, ...data } as any, authorUrl, channelName);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: authorUrl },
              { name: data.title || "Video", url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${data.title} - Truthworld`,
              description: data.description || `Watch ${data.title} on Truthworld.`,
              url: canonicalUrl,
              image: data.thumbnailUrl || data.thumbnail,
              type: "video.other",
              robots: visibility === "unlisted" ? "noindex, nofollow" : "index, follow",
              jsonLd: [videoSchema, breadcrumbs.jsonLd, ...orgSchemas],
              breadcrumbHtml: breadcrumbs.html,
              contentHeading: data.title,
              authorName: channelName,
              authorUrl: authorUrl,
              transcriptExcerpt: data.transcript || data.captionsText
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
        let queryType = "id";
        if (path.startsWith("/@")) {
          handleOrId = path.substring(2);
          queryType = "handle";
        } else {
          handleOrId = path.split("/")[2];
          queryType = path.startsWith("/channel/") ? "id" : "handle";
        }

        if (handleOrId) {
          const cacheKey = queryType === "handle" ? `channel_handle_${handleOrId.toLowerCase().replace(/^@/, "")}` : `channel_${handleOrId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let docData: any = null;
          if (queryType === "id") {
            const doc = await db.collection("channels").doc(handleOrId).get();
            if (doc.exists) docData = { id: doc.id, ...(doc.data() as any) };
          } else {
            const qs = await db.collection("channels").where("handleLowercase", "==", handleOrId.toLowerCase()).limit(1).get();
            if (!qs.empty) docData = { id: qs.docs[0].id, ...(qs.docs[0].data() as any) };
          }

          if (docData && docData.status !== "deleted" && docData.status !== "suspended") {
            const channelName = docData.displayName || docData.name || "Channel";
            const channelSchema = generateChannelSchema(docData, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: channelName, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${channelName} - Truthworld`,
              description: docData.about || docData.description || `Watch videos from ${channelName} on Truthworld.`,
              url: canonicalUrl,
              image: docData.profile?.photoUrl || docData.avatarUrl,
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
          const cacheKey = `topic_${cleanSlug.toLowerCase()}`;
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

            const topicImage = docData.thumbnailUrl ||
              docData.coverImage ||
              docData.imageUrl ||
              docData.iconUrl ||
              docData.bannerUrl ||
              (topVideos.length > 0 ? (topVideos[0].thumbnailUrl || topVideos[0].thumbnail || topVideos[0].coverUrl) : undefined);

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
          const cacheKey = `playlist_${playlistId}`;
          const cached = await getCachedSnapshot(cacheKey);
          if (cached) {
            logSeoEvent({ eventType: "cache_hit", path: canonicalUrl, durationMs: Date.now() - startTime });
            sendHtmlResponse(req, res, cached.html, cached.etag, cached.lastModified);
            return;
          }

          let doc = await db.collection("public_playlists").doc(playlistId).get();
          if (!doc.exists) doc = await db.collection("playlists").doc(playlistId).get();

          if (doc.exists) {
            const data = doc.data()!;
            const playlistName = data.playlistName || data.name || "Playlist";
            const playlistSchema = generatePlaylistSchema({ id: doc.id, ...data }, canonicalUrl);
            const breadcrumbs = generateBreadcrumbData([
              { name: playlistName, url: canonicalUrl }
            ]);

            const finalHtml = buildSemanticSsrHtml({
              title: `${playlistName} - Playlist | Truthworld`,
              description: data.description || `Watch this playlist on Truthworld.`,
              url: canonicalUrl,
              image: data.thumbnailUrl || data.thumbnail,
              type: "website",
              robots: data.visibility === "private" ? "noindex, nofollow" : "index, follow",
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

      // ─── 3. Fallback / Default Homepage HTML ─────────────────────────────────
      const homepageHtml = buildSemanticSsrHtml({
        title: "Truthworld - Verify before you share",
        description: "Truthworld is a premium video-sharing platform with automated validation pipelines for trustworthy storytelling.",
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
