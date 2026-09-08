import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { logger } from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 🧹 CLEANUP MOCK TOPICS & PLAYLISTS
 * Administrative endpoint to clean up mock/placeholder/zero-video topics and playlists in Firestore.
 * 
 * Supports:
 * - dryRun: true/false (preview or execute deletion)
 * - collection: "all" | "topics" | "playlists"
 */
export const cleanupMockTopicsAndPlaylists = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { dryRun = false, target = "all" } = req.body || {};
      const db = admin.firestore();

      const deletedTopics: Array<{ id: string; title: string; slug: string; reason: string }> = [];
      const deletedPlaylists: Array<{ id: string; name: string; collection: string; reason: string }> = [];

      // ── Step 1: Cleanup Topics ─────────────────────────────────────────────
      if (target === "all" || target === "topics") {
        const topicsSnap = await db.collection("topics").get();
        const batch = db.batch();
        let opCount = 0;

        for (const doc of topicsSnap.docs) {
          const data = doc.data();
          const title = (data.title || data.name || "").trim();
          const slug = (data.slug || "").trim();
          const lowerTitle = title.toLowerCase();
          const lowerSlug = slug.toLowerCase();
          const videoCount = Number(data.videoCount) || 0;
          const featuredVideos = data.featuredVideoIds || [];

          let isMockOrEmpty = false;
          let reason = "";

          if (!title || !slug) {
            isMockOrEmpty = true;
            reason = "Missing title or slug";
          } else if (
            lowerTitle === "topic" ||
            lowerTitle === "featured topic" ||
            lowerTitle.startsWith("untitled") ||
            lowerSlug === "topic" ||
            lowerSlug === "featured-topic" ||
            lowerSlug.startsWith("untitled")
          ) {
            isMockOrEmpty = true;
            reason = `Placeholder title/slug ("${title}" / "${slug}")`;
          } else if (videoCount <= 0 && featuredVideos.length === 0) {
            const hasVideo = await db.collection("videos").where("topics", "array-contains", slug).limit(1).get();
            if (hasVideo.empty) {
              isMockOrEmpty = true;
              reason = "Topic has 0 videos and no linked video content";
            }
          }

          if (isMockOrEmpty) {
            deletedTopics.push({ id: doc.id, title, slug, reason });
            if (!dryRun) {
              batch.delete(doc.ref);
              opCount++;
              if (opCount >= 400) {
                await batch.commit();
                opCount = 0;
              }
            }
          }
        }

        if (!dryRun && opCount > 0) {
          await batch.commit();
        }
      }

      // ── Step 2: Cleanup Playlists (playlists & public_playlists) ───────────
      if (target === "all" || target === "playlists") {
        for (const col of ["playlists", "public_playlists"]) {
          const playlistsSnap = await db.collection(col).get();
          const batch = db.batch();
          let opCount = 0;

          for (const doc of playlistsSnap.docs) {
            const data = doc.data();
            const name = (data.name || data.playlistName || data.title || "").trim();
            const lowerName = name.toLowerCase();
            const videoCount = Number(data.videoCount) || Number(data.videosCount) || 0;
            const videoIds = data.videoIds || [];

            let isMockOrEmpty = false;
            let reason = "";

            if (!name) {
              isMockOrEmpty = true;
              reason = "Missing playlist name";
            } else if (
              lowerName === "playlist" ||
              lowerName === "truthworld playlist" ||
              lowerName === "untitled" ||
              lowerName.startsWith("untitled")
            ) {
              isMockOrEmpty = true;
              reason = `Placeholder name ("${name}")`;
            } else if (videoCount <= 0 && videoIds.length === 0) {
              isMockOrEmpty = true;
              reason = "0 videos in playlist";
            }

            if (isMockOrEmpty) {
              deletedPlaylists.push({ id: doc.id, name, collection: col, reason });
              if (!dryRun) {
                batch.delete(doc.ref);
                opCount++;
                if (opCount >= 400) {
                  await batch.commit();
                  opCount = 0;
                }
              }
            }
          }

          if (!dryRun && opCount > 0) {
            await batch.commit();
          }
        }
      }

      logger.info("[CleanupMockTopicsAndPlaylists] Cleanup run complete", {
        dryRun,
        deletedTopicsCount: deletedTopics.length,
        deletedPlaylistsCount: deletedPlaylists.length,
      });

      res.status(200).json({
        status: "success",
        dryRun,
        summary: {
          mockTopicsCount: deletedTopics.length,
          mockPlaylistsCount: deletedPlaylists.length,
        },
        deletedTopics,
        deletedPlaylists,
      });
    } catch (e: any) {
      logger.error("[CleanupMockTopicsAndPlaylists] Error during cleanup", e);
      res.status(500).json({ error: e?.message || "Internal server error" });
    }
  }
);
