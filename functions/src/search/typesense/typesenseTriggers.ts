import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { getTypesenseAdminClient } from "./typesenseClient";
import {
  mapVideoToTypesense,
  mapChannelToTypesense,
  mapTopicToTypesense,
} from "./typesenseMappers";

/**
 * Real-time sync trigger for Firestore videos -> Typesense videos collection.
 */
export const onVideoWrittenTypesenseSync = onDocumentWritten(
  {
    document: "videos/{videoId}",
    region: "asia-south1",
    retry: true,
    maxInstances: 5,
  },
  async (event) => {
    const videoId = event.params.videoId;
    const afterData = event.data?.after.data();
    const client = getTypesenseAdminClient();

    try {
      if (!afterData) {
        // Document deleted from Firestore
        await client.collections("videos").documents(videoId).delete();
        logger.info("[TypesenseSync] Deleted video document from search", { videoId });
        return;
      }

      const doc = mapVideoToTypesense(videoId, afterData);
      if (!doc) {
        // Video is draft, blocked, deleted, or suspended -> remove from search index
        try {
          await client.collections("videos").documents(videoId).delete();
          logger.info("[TypesenseSync] Removed non-discoverable video from index", { videoId });
        } catch (err: any) {
          if (err?.httpStatus !== 404) throw err;
        }
        return;
      }

      await client.collections("videos").documents().upsert(doc);
      logger.info("[TypesenseSync] Upserted video to search index", { videoId, title: doc.title });
    } catch (err: any) {
      logger.error("[TypesenseSync] Video sync failed", {
        videoId,
        error: err?.message || String(err),
      });
    }
  }
);

/**
 * Real-time sync trigger for Firestore channels -> Typesense channels collection.
 */
export const onChannelWrittenTypesenseSync = onDocumentWritten(
  {
    document: "channels/{channelId}",
    region: "asia-south1",
    retry: true,
    maxInstances: 5,
  },
  async (event) => {
    const channelId = event.params.channelId;
    const afterData = event.data?.after.data();
    const client = getTypesenseAdminClient();

    try {
      if (!afterData) {
        await client.collections("channels").documents(channelId).delete();
        logger.info("[TypesenseSync] Deleted channel from search", { channelId });
        return;
      }

      const doc = mapChannelToTypesense(channelId, afterData);
      if (!doc) {
        try {
          await client.collections("channels").documents(channelId).delete();
        } catch (err: any) {
          if (err?.httpStatus !== 404) throw err;
        }
        return;
      }

      await client.collections("channels").documents().upsert(doc);
      logger.info("[TypesenseSync] Upserted channel to search index", {
        channelId,
        channelName: doc.channelName,
      });
    } catch (err: any) {
      logger.error("[TypesenseSync] Channel sync failed", {
        channelId,
        error: err?.message || String(err),
      });
    }
  }
);

/**
 * Real-time sync trigger for Firestore topics -> Typesense topics collection.
 */
export const onTopicWrittenTypesenseSync = onDocumentWritten(
  {
    document: "topics/{topicId}",
    region: "asia-south1",
    retry: true,
    maxInstances: 5,
  },
  async (event) => {
    const topicId = event.params.topicId;
    const afterData = event.data?.after.data();
    const client = getTypesenseAdminClient();

    try {
      if (!afterData) {
        await client.collections("topics").documents(topicId).delete();
        logger.info("[TypesenseSync] Deleted topic from search", { topicId });
        return;
      }

      const doc = mapTopicToTypesense(topicId, afterData);
      if (!doc) {
        try {
          await client.collections("topics").documents(topicId).delete();
        } catch (err: any) {
          if (err?.httpStatus !== 404) throw err;
        }
        return;
      }

      await client.collections("topics").documents().upsert(doc);
      logger.info("[TypesenseSync] Upserted topic to search index", {
        topicId,
        title: doc.title,
      });
    } catch (err: any) {
      logger.error("[TypesenseSync] Topic sync failed", {
        topicId,
        error: err?.message || String(err),
      });
    }
  }
);
