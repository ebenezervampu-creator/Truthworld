import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { updateVideoSearchMetadata, updateChannelSearchMetadata } from "./searchMetadata";
import { submitIndexNow } from "./indexNowService";
import { DOMAIN, formatDate } from "../schema/schemaConfig";
import { generateVideoSchema } from "../schema/videoSchema";
import { generateChannelSchema } from "../schema/channelSchema";
import { generateTopicSchema } from "../schema/topicSchema";
import { generatePlaylistSchema } from "../schema/playlistSchema";
import { generateCommunityPostSchema } from "../schema/communityPostSchema";
import { generateOrganizationSchema } from "../schema/organizationSchema";
import { generateBreadcrumbData } from "../render/breadcrumbRenderer";
import { buildSemanticSsrHtml } from "../render/htmlRenderer";
import { saveSnapshot } from "../cache/storageCache";
import { logSeoEvent } from "../monitor/searchHealth";

export const onVideoSeoWritten = onDocumentWritten(
  {
    document: "videos/{videoId}",
    region: "asia-south1"
  },
  async (event) => {
    const videoId = event.params.videoId;
    const afterData = event.data?.after?.data();
    if (!afterData) return;

    const db = admin.firestore();
    const visibility = (afterData.visibility || "").toLowerCase();
    const status = (afterData.status || "").toLowerCase();

    await updateVideoSearchMetadata(db, videoId, afterData);

    if (visibility === "public" && status === "ready") {
      await db.collection("dirty_shards").doc("videos-001").set({
        shardId: "videos-001",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      let channelName = afterData.channelName || "Truthworld Creator";
      let channelHandle = "";
      if (afterData.channelId) {
        const channelDoc = await db.collection("channels").doc(afterData.channelId).get();
        if (channelDoc.exists) {
          const cData = channelDoc.data()!;
          channelName = cData.displayName || cData.name || channelName;
          channelHandle = cData.handle || "";
        }
      }
      const authorUrl = channelHandle 
        ? `${DOMAIN}/${channelHandle.startsWith("@") ? channelHandle : `@${channelHandle}`}`
        : `${DOMAIN}/channel/${afterData.channelId}`;

      const watchUrl = `${DOMAIN}/watch?v=${videoId}`;
      const videoSchema = generateVideoSchema({ id: videoId, ...afterData } as any, authorUrl, channelName);
      const breadcrumbs = generateBreadcrumbData([
        { name: channelName, url: authorUrl },
        { name: afterData.title || "Video", url: watchUrl }
      ]);
      const orgSchemas = generateOrganizationSchema();
      const videoDurationSec = afterData.durationMs 
        ? Math.floor(afterData.durationMs / 1000) 
        : (typeof afterData.duration === "number" ? afterData.duration : 0);

      const html = buildSemanticSsrHtml({
        title: `${afterData.title} - Truthworld`,
        description: afterData.description || `Watch ${afterData.title} by ${channelName} on Truthworld.`,
        url: watchUrl,
        image: afterData.thumbnailUrl || afterData.thumbnail,
        imageWidth: 1280,
        imageHeight: 720,
        type: "video.other",
        videoUrl: afterData.hlsUrl || afterData.originalUrl || afterData.videoUrl,
        embedUrl: `${DOMAIN}/embed/${videoId}`,
        durationSeconds: videoDurationSec,
        uploadDate: formatDate(afterData.uploadedAt || afterData.createdAt),
        robots: "index, follow",
        jsonLd: [videoSchema, breadcrumbs.jsonLd, ...orgSchemas],
        breadcrumbHtml: breadcrumbs.html,
        contentHeading: afterData.title,
        authorName: channelName,
        authorUrl: authorUrl,
        transcriptExcerpt: afterData.transcript || afterData.captionsText
      });

      await saveSnapshot(`watch_v2_${videoId}`, html);
      await submitIndexNow([watchUrl]);

      logSeoEvent({
        eventType: "ssr_render",
        path: `/watch?v=${videoId}`,
        details: "Pre-rendered HTML snapshot and notified IndexNow."
      });
    } else {
      // Video is no longer public/ready — invalidate cached snapshot
      await saveSnapshot(`watch_v2_${videoId}`, '');
      logSeoEvent({
        eventType: "ssr_render",
        path: `/watch?v=${videoId}`,
        details: `Video unpublished or not ready (visibility=${visibility}, status=${status}). Snapshot cleared.`
      });
    }
  }
);

export const onChannelSeoWritten = onDocumentWritten(
  {
    document: "channels/{channelId}",
    region: "asia-south1"
  },
  async (event) => {
    const channelId = event.params.channelId;
    const afterData = event.data?.after?.data();
    if (!afterData) return;

    const db = admin.firestore();
    const status = (afterData.status || "").toLowerCase();

    await updateChannelSearchMetadata(db, channelId, afterData);

    if (status === "active") {
      await db.collection("dirty_shards").doc("channels-001").set({
        shardId: "channels-001",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const handle = afterData.handle || "";
      const channelUrl = handle 
        ? `${DOMAIN}/${handle.startsWith("@") ? handle : `@${handle}`}`
        : `${DOMAIN}/channel/${channelId}`;

      const channelSchema = generateChannelSchema(afterData as any, channelUrl);
      const breadcrumbs = generateBreadcrumbData([
        { name: afterData.displayName || afterData.name || "Channel", url: channelUrl }
      ]);

      const html = buildSemanticSsrHtml({
        title: `${afterData.displayName || afterData.name} - Truthworld`,
        description: afterData.about || afterData.description || `Watch videos from ${afterData.displayName || afterData.name} on Truthworld.`,
        url: channelUrl,
        image: afterData.profile?.photoUrl || afterData.avatarUrl,
        type: "profile",
        robots: "index, follow",
        jsonLd: [channelSchema, breadcrumbs.jsonLd],
        breadcrumbHtml: breadcrumbs.html,
        contentHeading: afterData.displayName || afterData.name,
        authorName: afterData.displayName || afterData.name,
        authorUrl: channelUrl
      });

      const cacheKey = `channel_v2_${(handle || channelId).toLowerCase().replace(/^@/, "")}`;
      await saveSnapshot(cacheKey, html);

      await submitIndexNow([channelUrl]);

      logSeoEvent({
        eventType: "ssr_render",
        path: channelUrl,
        details: "Pre-rendered channel HTML snapshot and notified IndexNow."
      });
    }
  }
);

export const onTopicSeoWritten = onDocumentWritten(
  {
    document: "topics/{topicId}",
    region: "asia-south1"
  },
  async (event) => {
    const topicId = event.params.topicId;
    const afterData = event.data?.after?.data();
    if (!afterData) return;

    const db = admin.firestore();
    const status = (afterData.status || "").toLowerCase();
    const slug = (afterData.slug || topicId).trim();
    const rawTitle = (afterData.title || afterData.name || "").trim();

    if (status === "active" && slug && rawTitle) {
      await db.collection("dirty_shards").doc("topics").set({
        shardId: "topics",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const cleanSlug = slug.replace(/^(T\/|t\/)/i, "").trim();
      const topicUrl = `${DOMAIN}/topic/${cleanSlug}`;
      const cleanTitle = rawTitle.replace(/^[#Tt]\//, "").trim();

      const topVideos: any[] = [];
      try {
        const vSnap = await db.collection("videos")
          .where("topics", "array-contains", cleanSlug)
          .orderBy("uploadedAt", "desc")
          .limit(10).get();
        vSnap.forEach((d) => {
          const data = d.data();
          if ((data.visibility || "public").toLowerCase() === "public") {
            topVideos.push({ id: d.id, title: data.title || "Video" });
          }
        });
      } catch (_) {}

      const topicSchema = generateTopicSchema({ id: topicId, ...afterData }, topicUrl, topVideos);
      const breadcrumbs = generateBreadcrumbData([
        { name: `#${cleanTitle}`, url: topicUrl }
      ]);

      const html = buildSemanticSsrHtml({
        title: `#${cleanTitle} - Topic | Truthworld`,
        description: afterData.description || `Explore top videos and discussions in #${cleanTitle} on Truthworld.`,
        url: topicUrl,
        image: afterData.coverUrl || afterData.bannerUrl || afterData.imageUrl,
        type: "website",
        robots: "index, follow",
        jsonLd: [topicSchema, breadcrumbs.jsonLd],
        breadcrumbHtml: breadcrumbs.html,
        contentHeading: `#${cleanTitle} Topic`,
        relatedItems: topVideos.map(v => ({ title: v.title, url: `${DOMAIN}/watch?v=${v.id}` }))
      });

      const cacheKey = `topic_v3_${cleanSlug.toLowerCase()}`;
      await saveSnapshot(cacheKey, html);
      await submitIndexNow([topicUrl]);

      logSeoEvent({
        eventType: "ssr_render",
        path: topicUrl,
        details: "Pre-rendered topic HTML snapshot and notified IndexNow."
      });
    }
  }
);

export const onCommunityPostSeoWritten = onDocumentWritten(
  {
    document: "Community/{postId}",
    region: "asia-south1"
  },
  async (event) => {
    const postId = event.params.postId;
    const afterData = event.data?.after?.data();
    if (!afterData) return;

    const db = admin.firestore();
    const status = (afterData.status || "").toLowerCase();
    const visibility = (afterData.visibility || "public").toLowerCase();

    if (status !== "deleted" && status !== "rejected" && visibility !== "private") {
      await db.collection("dirty_shards").doc("community-001").set({
        shardId: "community-001",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const postUrl = `${DOMAIN}/post/${postId}`;
      const postTitle = afterData.title || (afterData.description ? afterData.description.substring(0, 80) : "Community Post");
      const authorName = afterData.channelName || "Channel";
      const authorUrl = afterData.channelId ? `${DOMAIN}/channel/${afterData.channelId}` : DOMAIN;

      const postSchema = generateCommunityPostSchema({ id: postId, ...afterData }, postUrl);
      const breadcrumbs = generateBreadcrumbData([
        { name: authorName, url: authorUrl },
        { name: postTitle, url: postUrl }
      ]);

      const image = (afterData.images && afterData.images.length > 0) ? afterData.images[0] : (afterData.image || afterData.channelImage);

      const html = buildSemanticSsrHtml({
        title: `${postTitle} - Post by ${authorName} | Truthworld`,
        description: afterData.description || `Community post by ${authorName} on Truthworld.`,
        url: postUrl,
        image: image,
        type: "article",
        robots: "index, follow",
        jsonLd: [postSchema, breadcrumbs.jsonLd],
        breadcrumbHtml: breadcrumbs.html,
        contentHeading: postTitle,
        authorName: authorName,
        authorUrl: authorUrl
      });

      const cacheKey = `post_${postId}`;
      await saveSnapshot(cacheKey, html);
      await submitIndexNow([postUrl]);

      logSeoEvent({
        eventType: "ssr_render",
        path: postUrl,
        details: "Pre-rendered community post HTML snapshot and notified IndexNow."
      });
    }
  }
);

export const onPlaylistSeoWritten = onDocumentWritten(
  {
    document: "playlists/{playlistId}",
    region: "asia-south1"
  },
  async (event) => {
    const playlistId = event.params.playlistId;
    const afterData = event.data?.after?.data();
    if (!afterData) return;

    const db = admin.firestore();
    const status = (afterData.status || "").toLowerCase();
    const visibility = (afterData.visibility || "").toLowerCase();
    const isPublic = visibility === "public" || afterData.isPublic === true;
    const name = (afterData.name || afterData.playlistName || afterData.title || "").trim();

    if (isPublic && status !== "deleted" && name && !name.toLowerCase().startsWith("untitled")) {
      await db.collection("dirty_shards").doc("playlists").set({
        shardId: "playlists",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const playlistUrl = `${DOMAIN}/playlist?list=${playlistId}`;
      const playlistSchema = generatePlaylistSchema({ id: playlistId, ...afterData }, playlistUrl);
      const breadcrumbs = generateBreadcrumbData([
        { name: name, url: playlistUrl }
      ]);

      const html = buildSemanticSsrHtml({
        title: `${name} - Playlist | Truthworld`,
        description: afterData.description || `Watch ${name} playlist on Truthworld.`,
        url: playlistUrl,
        image: afterData.thumbnailUrl || afterData.thumbnail,
        type: "website",
        robots: "index, follow",
        jsonLd: [playlistSchema, breadcrumbs.jsonLd],
        breadcrumbHtml: breadcrumbs.html,
        contentHeading: `${name} Playlist`
      });

      const cacheKey = `playlist_v3_${playlistId}`;
      await saveSnapshot(cacheKey, html);
      await submitIndexNow([playlistUrl]);

      logSeoEvent({
        eventType: "ssr_render",
        path: playlistUrl,
        details: "Pre-rendered playlist HTML snapshot and notified IndexNow."
      });
    }
  }
);
