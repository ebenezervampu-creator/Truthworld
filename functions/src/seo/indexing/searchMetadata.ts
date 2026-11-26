import * as admin from "firebase-admin";
import { computeTextEmbedding } from "../../search/embeddingService";
import { safeMergeExistingVideo } from "../../utils/videosCollectionGuard";

export async function updateVideoSearchMetadata(db: admin.firestore.Firestore, videoId: string, data: any) {
  if (!videoId) return;

  const embeddingText = `${data.title || ""} ${data.channelName || ""} ${data.category || ""} ${(data.tags || []).join(" ")}`.trim();
  const embeddingVector = embeddingText.length > 3 ? await computeTextEmbedding(embeddingText) : null;

  const searchDoc: Record<string, any> = {
    id: videoId,
    title: data.title || "",
    titleLowercase: (data.title || "").toLowerCase(),
    description: data.description || "",
    channelId: data.channelId || "",
    channelName: data.channelName || "",
    durationMs: data.durationMs || 0,
    thumbnailUrl: data.thumbnailUrl || data.thumbnail || "",
    visibility: data.visibility || "public",
    status: data.status || "ready",
    uploadedAt: data.uploadedAt || data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  if (embeddingVector && embeddingVector.length > 0) {
    searchDoc.embedding = admin.firestore.FieldValue.vector(embeddingVector);
  }

  await db.collection("video_search").doc(videoId).set(searchDoc, { merge: true });

  if (embeddingVector && embeddingVector.length > 0) {
    const hasEmbedding = Boolean(data.embedding);
    const hasTitleLowercase = Boolean(data.titleLowercase);
    if (!hasEmbedding || !hasTitleLowercase) {
      await safeMergeExistingVideo(
        videoId,
        {
          embedding: admin.firestore.FieldValue.vector(embeddingVector),
          titleLowercase: (data.title || "").toLowerCase(),
        },
        "[SearchMetadata]"
      );
    }
  }
}

export async function updateChannelSearchMetadata(db: admin.firestore.Firestore, channelId: string, data: any) {
  if (!channelId) return;

  const vis = (data.visibility || "").toLowerCase();
  const isPrivateOrUnlisted = vis === "private" || vis === "unlisted" || data.isPublic === false;
  if (isPrivateOrUnlisted) {
    await db.collection("channel_search").doc(channelId).delete().catch(() => {});
    return;
  }

  const searchDoc = {
    id: channelId,
    name: data.displayName || data.name || "",
    nameLowercase: (data.displayName || data.name || "").toLowerCase(),
    handle: data.handle || "",
    handleLowercase: (data.handle || "").toLowerCase().replace(/^@/, ""),
    avatarUrl: data.profile?.photoUrl || data.avatarUrl || data.avatar || "",
    subscriberCount: data.stats?.subscriberCount || data.subscriberCount || 0,
    status: data.status || "active",
    visibility: data.visibility || "Public",
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection("channel_search").doc(channelId).set(searchDoc, { merge: true });
}

export async function updateTopicSearchMetadata(db: admin.firestore.Firestore, topicId: string, data: any) {
  if (!topicId) return;
  const searchDoc = {
    id: topicId,
    title: data.title || data.name || "",
    slug: data.slug || topicId,
    status: data.status || "active",
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection("topic_search").doc(topicId).set(searchDoc, { merge: true });
}

export async function updatePlaylistSearchMetadata(db: admin.firestore.Firestore, playlistId: string, data: any) {
  if (!playlistId) return;
  const searchDoc = {
    id: playlistId,
    name: data.playlistName || data.name || "",
    description: data.description || "",
    videoCount: (data.videoIds || []).length,
    visibility: data.visibility || "public",
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection("playlist_search").doc(playlistId).set(searchDoc, { merge: true });
}
