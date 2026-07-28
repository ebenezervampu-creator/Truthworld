import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { logger } from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const adminSearchContent = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { contentType, filters = {}, pagination = {} } = req.body;
      if (!contentType) {
        res.status(400).json({ error: "Missing contentType" });
        return;
      }

      const limit = Math.min(Number(pagination.limit) || 50, 50);
      const startAfter = pagination.startAfter;

      let collectionName = "";
      let orderField = "";

      switch (contentType) {
        case "images":
          collectionName = "flagged_images_review";
          orderField = "flaggedAt";
          break;
        case "videos":
          collectionName = "videos";
          orderField = "createdAt";
          break;
        case "channels":
          collectionName = "channels";
          orderField = "updatedAt";
          break;
        case "reports":
          collectionName = "reports";
          orderField = "createdAt";
          break;
        default:
          res.status(400).json({ error: "Invalid contentType" });
          return;
      }

      let query: admin.firestore.Query = admin.firestore().collection(collectionName);

      if (filters.userId) query = query.where("userId", "==", filters.userId);
      if (filters.trustTier) query = query.where("trustTier", "==", filters.trustTier);
      if (filters.violationCategory) query = query.where("violationCategory", "==", filters.violationCategory);
      if (filters.status) query = query.where("status", "==", filters.status);
      
      if (filters.dateRange?.start) query = query.where(orderField, ">=", filters.dateRange.start);
      if (filters.dateRange?.end) query = query.where(orderField, "<=", filters.dateRange.end);

      query = query.orderBy(orderField, "desc");

      if (startAfter) {
        const cursorDoc = await admin.firestore().collection(collectionName).doc(startAfter).get();
        if (cursorDoc.exists) {
          query = query.startAfter(cursorDoc);
        }
      }

      // If searchText exists, we might need to fetch more to filter in memory
      const fetchLimit = filters.searchText ? limit * 3 : limit;
      query = query.limit(fetchLimit);

      const snapshot = await query.get();
      let items = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

      if (filters.searchText) {
        const searchLower = filters.searchText.toLowerCase();
        items = items.filter((item) => {
          return JSON.stringify(item).toLowerCase().includes(searchLower);
        });
        items = items.slice(0, limit);
      }

      let nextCursor = null;
      if (items.length > 0 && items.length === limit) {
        nextCursor = items[items.length - 1].id;
      } else if (!filters.searchText && snapshot.docs.length === fetchLimit) {
         nextCursor = snapshot.docs[snapshot.docs.length - 1].id;
      }

      let totalCount = 0;
      try {
        const aggr = await admin.firestore().collection(collectionName).count().get();
        totalCount = aggr.data().count;
      } catch (e) {
          logger.warn("Count query failed", e);
      }

      res.status(200).json({ items, nextCursor, totalCount });
    } catch (error) {
      logger.error("[adminSearchContent] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);
