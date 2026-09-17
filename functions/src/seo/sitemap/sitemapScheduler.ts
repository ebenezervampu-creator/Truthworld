import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { generateVideosSitemapShard, generateChannelsSitemapShard, generateTopicsSitemap, generatePlaylistsSitemap, generateCommunityPostsSitemapShard } from "./sitemapGenerator";
import { generateRssFeed } from "./rssGenerator";
import { logSeoEvent } from "../monitor/searchHealth";

export const rebuildDirtySitemapsScheduler = onSchedule(
  {
    schedule: "every 30 minutes",
    region: "asia-south1",
    memory: "512MiB"
  },
  async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    try {
      const dirtySnap = await db.collection("dirty_shards").get();
      if (dirtySnap.empty) {
        logSeoEvent({ eventType: "sitemap_built", details: "No dirty sitemap shards found." });
        return;
      }

      for (const doc of dirtySnap.docs) {
        const shardId = doc.id;
        let xmlContent = "";

        if (shardId.startsWith("videos")) {
          xmlContent = await generateVideosSitemapShard(db);
        } else if (shardId.startsWith("channels")) {
          xmlContent = await generateChannelsSitemapShard(db);
        } else if (shardId === "topics") {
          xmlContent = await generateTopicsSitemap(db);
        } else if (shardId === "playlists") {
          xmlContent = await generatePlaylistsSitemap(db);
        } else if (shardId.startsWith("community")) {
          xmlContent = await generateCommunityPostsSitemapShard(db);
        }

        if (xmlContent) {
          const file = bucket.file(`seo/sitemaps/${shardId}.xml`);
          await file.save(xmlContent, {
            contentType: "application/xml",
            metadata: { cacheControl: "public, max-age=1800" }
          });
        }

        // Delete dirty flag doc after rebuild
        await doc.ref.delete();
      }

      // Rebuild RSS feed
      const recentVideosSnap = await db
        .collection("videos")
        .where("visibility", "==", "public")
        .orderBy("uploadedAt", "desc")
        .limit(50)
        .get();

      const rssVideos: any[] = [];
      recentVideosSnap.forEach((d) => rssVideos.push({ id: d.id, ...d.data() }));

      const rssXml = generateRssFeed(rssVideos);
      const rssFile = bucket.file("seo/rss/videos.xml");
      await rssFile.save(rssXml, {
        contentType: "application/rss+xml; charset=utf-8",
        metadata: { cacheControl: "public, max-age=1800" }
      });

      logSeoEvent({ eventType: "sitemap_built", details: `Rebuilt ${dirtySnap.docs.length} dirty shards and RSS feed.` });
    } catch (err: any) {
      console.error("Error in sitemap scheduler:", err);
      logSeoEvent({ eventType: "error", details: `Sitemap scheduler error: ${err?.message}` });
    }
  }
);
