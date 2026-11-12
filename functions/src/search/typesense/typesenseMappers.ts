export interface TypesenseVideoDoc {
  id: string;
  title: string;
  description?: string;
  channelId?: string;
  channelName: string;
  channelImage?: string;
  thumbnailUrl?: string;
  views: number;
  isFactChecked?: boolean;
  isTrusted?: boolean;
  category?: string;
  tags?: string[];
  topics?: string[];
  language?: string;
  durationMs?: number;
  visibility: string;
  status: string;
  createdAt: number;
}

export interface TypesenseChannelDoc {
  id: string;
  channelName: string;
  handle: string;
  avatarUrl?: string;
  subscriberCount: number;
  category?: string;
  isVerified?: boolean;
  isTrusted?: boolean;
  status?: string;
  createdAt: number;
}

export interface TypesenseTopicDoc {
  id: string;
  title: string;
  slug: string;
  thumbnailUrl?: string;
  videoCount: number;
  category?: string;
  isActive?: boolean;
  createdAt: number;
}

function parseDateToMillis(dateVal: any): number {
  if (!dateVal) return Date.now();
  if (typeof dateVal.toMillis === "function") return dateVal.toMillis();
  if (typeof dateVal.toDate === "function") return dateVal.toDate().getTime();
  if (dateVal instanceof Date) return dateVal.getTime();
  const parsed = Date.parse(String(dateVal));
  return isNaN(parsed) ? Date.now() : parsed;
}

function firstNonEmpty(items: any[]): string {
  for (const item of items) {
    if (typeof item === "string" && item.trim().length > 0) {
      return item.trim();
    }
  }
  return "";
}

/**
 * Validates whether a video should be indexed in Typesense search.
 */
export function isVideoIndexable(data: any): boolean {
  if (!data) return false;
  const vis = String(data.visibility || "public").toLowerCase();
  const status = String(data.status || "ready").toLowerCase();

  const isPublicOrMember =
    vis === "public" ||
    vis === "members_only" ||
    vis === "members" ||
    vis === "subscribers_only" ||
    vis === "subscribers";

  if (!isPublicOrMember) return false;
  if (
    status === "draft" ||
    status === "uploading" ||
    status === "suspended" ||
    status === "blocked" ||
    data.isDeleted === true ||
    data.moderationStatus === "rejected" ||
    data.copyrightStrike === true
  ) {
    return false;
  }
  return true;
}

export function mapVideoToTypesense(id: string, data: any): TypesenseVideoDoc | null {
  if (!isVideoIndexable(data)) return null;

  const rawTitle = firstNonEmpty([data.title, data.vTitle]);
  const title = rawTitle.length > 0 ? rawTitle : "Untitled";

  const rawChannelName = firstNonEmpty([data.channelName, data.ownerName, data.creatorName]);
  const channelName = rawChannelName.length > 0 ? rawChannelName : "Unknown";

  const channelImage = firstNonEmpty([
    data.channelImage,
    data.channelAvatarUrl,
    data.avatarUrl,
    data.photoUrl,
    data.profileImageUrl,
  ]);

  const mediaMap = typeof data.media === "object" && data.media ? data.media : null;
  const thumbnailUrl = firstNonEmpty([
    data.thumbnailUrl,
    data.thumbnail,
    mediaMap?.thumbnailUrl,
    mediaMap?.thumbnail,
  ]);

  const views = Number(data.viewCount || data.views || data.stats?.views || 0);

  const isFactChecked =
    data.isFactChecked === true ||
    data.credibilityVerified === true ||
    (typeof data.factCheckUrl === "string" && data.factCheckUrl.trim().length > 0);

  const isTrusted =
    data.channelTrustedModerationBypass === true ||
    data.isChannelTrusted === true ||
    data.trustedModerationBypass === true;

  const durationMs = Number(data.durationMs) ||
    (Number(data.duration) ? Math.round(Number(data.duration) * 1000) : undefined);

  return {
    id,
    title,
    description: typeof data.description === "string" ? data.description.slice(0, 1000) : undefined,
    channelId: data.channelId ? String(data.channelId) : undefined,
    channelName,
    channelImage: channelImage || undefined,
    thumbnailUrl: thumbnailUrl || undefined,
    views: isNaN(views) ? 0 : views,
    isFactChecked,
    isTrusted,
    category: data.category ? String(data.category) : undefined,
    tags: Array.isArray(data.tags) ? data.tags.map(String) : undefined,
    topics: Array.isArray(data.topics) ? data.topics.map(String) : undefined,
    language: data.language ? String(data.language) : undefined,
    durationMs,
    visibility: String(data.visibility || "public"),
    status: String(data.status || "ready"),
    createdAt: parseDateToMillis(data.uploadedAt || data.createdAt || data.publishedAt),
  };
}

export function mapChannelToTypesense(id: string, data: any): TypesenseChannelDoc | null {
  if (!data) return null;

  const isSuspended =
    data.status === "suspended" ||
    data.status === "banned" ||
    data.status === "deleted" ||
    data.isSuspended === true ||
    data.isBanned === true ||
    data.isActive === false ||
    data.isPublic === false;

  if (isSuspended) return null;

  const channelName = firstNonEmpty([
    data.channelName,
    data.name,
    data.displayName,
    "Channel",
  ]);

  const rawHandle = firstNonEmpty([data.handle, data.channelHandle, data.customUrl]);
  const handle = rawHandle.startsWith("@") ? rawHandle : `@${rawHandle}`;

  const avatarUrl = firstNonEmpty([
    data.avatarUrl,
    data.avatarImage,
    data.channelAvatarUrl,
    data.channelImage,
    data.photoUrl,
    data.profileImageUrl,
  ]);

  const subs = Number(data.subscriberCount || data.subscribers || 0);

  return {
    id,
    channelName,
    handle: handle === "@" ? channelName : handle,
    avatarUrl: avatarUrl || undefined,
    subscriberCount: isNaN(subs) ? 0 : subs,
    category: data.category ? String(data.category) : undefined,
    isVerified: data.isVerified === true,
    isTrusted: data.trustedChannel === true || data.trustedModerationBypass === true,
    status: String(data.status || "active"),
    createdAt: parseDateToMillis(data.createdAt),
  };
}

export function mapTopicToTypesense(id: string, data: any): TypesenseTopicDoc | null {
  if (!data) return null;

  if (
    data.isActive === false ||
    data.isSuspended === true ||
    data.status === "suspended" ||
    data.status === "deleted"
  ) {
    return null;
  }

  const title = firstNonEmpty([data.title, data.name, data.slug, "Topic"]);
  const slug = firstNonEmpty([data.slug, id]);
  const thumbnailUrl = firstNonEmpty([data.thumbnailUrl, data.coverImage, data.image]);
  const videoCount = Number(data.videoCount || data.count || 0);

  return {
    id,
    title,
    slug,
    thumbnailUrl: thumbnailUrl || undefined,
    videoCount: isNaN(videoCount) ? 0 : videoCount,
    category: data.category ? String(data.category) : undefined,
    isActive: true,
    createdAt: parseDateToMillis(data.createdAt),
  };
}
