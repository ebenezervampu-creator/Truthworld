import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { updateVideoSearchMetadata, updateChannelSearchMetadata } from "./searchMetadata";
import { submitIndexNow } from "./indexNowService";
import { DOMAIN } from "../schema/schemaConfig";
import { generateVideoSchema } from "../schema/videoSchema";
import { generateChannelSchema } from "../schema/channelSchema";
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

      let channelName = afterData.channelName || "Creator";
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
      const videoSchema = generateVideoSchema(afterData as any, authorUrl, channelName);
      const breadcrumbs = generateBreadcrumbData([
        { name: channelName, url: authorUrl },
        { name: afterData.title || "Video", url: watchUrl }
      ]);
      const orgSchemas = generateOrganizationSchema();

      const html = buildSemanticSsrHtml({
        title: `${afterData.title} - Truthworld`,
        description: afterData.description || `Watch ${afterData.title} on Truthworld.`,
        url: watchUrl,
        image: afterData.thumbnailUrl || afterData.thumbnail,
        type: "video.other",
        robots: "index, follow",
        jsonLd: [videoSchema, breadcrumbs.jsonLd, ...orgSchemas],
        breadcrumbHtml: breadcrumbs.html,
        contentHeading: afterData.title,
        authorName: channelName,
        authorUrl: authorUrl,
        transcriptExcerpt: afterData.transcript || afterData.captionsText
      });

      await saveSnapshot(`watch_${videoId}`, html);
      await submitIndexNow([watchUrl]);

      logSeoEvent({
        eventType: "ssr_render",
        path: `/watch?v=${videoId}`,
        details: "Pre-rendered HTML snapshot and notified IndexNow."
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

      const cacheKey = handle ? `channel_handle_${handle.toLowerCase().replace(/^@/, "")}` : `channel_${channelId}`;
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
