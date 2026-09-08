import { DOMAIN, formatIsoDuration, formatDate } from "./schemaConfig";

export interface VideoData {
  id: string;
  videoId?: string;
  title: string;
  description?: string;
  thumbnailUrl?: string;
  thumbnail?: string;
  thumbnailVariants?: string[];
  durationMs?: number;
  duration?: any;
  uploadedAt?: any;
  createdAt?: any;
  publishedAt?: any;
  hlsUrl?: string;
  originalUrl?: string;
  videoUrl?: string;
  viewCount?: number;
  views?: number;
  likeCount?: number;
  likes?: number;
  channelId?: string;
  channelName?: string;
  channelHandle?: string;
  language?: string;
  isKidFriendly?: boolean;
  chapters?: Array<{ title: string; startMs: number; endMs?: number }>;
}

export function extractClipsFromDescription(
  description: string,
  durationMs?: number,
  watchUrl?: string
): any[] {
  if (!description) return [];
  const clips: any[] = [];
  const baseWatchUrl = watchUrl || `${DOMAIN}/watch`;

  // Match timestamp patterns like 0:00, 00:00, 1:23:45 followed by chapter title
  const timestampRegex = /(?:^|\n)(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s+[-–]?\s*([^\n]+)/g;
  let match;
  const parsedMatches: Array<{ startMs: number; name: string }> = [];

  while ((match = timestampRegex.exec(description)) !== null) {
    const hours = match[1] ? parseInt(match[1], 10) : 0;
    const minutes = parseInt(match[2], 10);
    const seconds = parseInt(match[3], 10);
    const title = match[4].trim();

    const startMs = (hours * 3600 + minutes * 60 + seconds) * 1000;
    parsedMatches.push({ startMs, name: title });
  }

  for (let i = 0; i < parsedMatches.length; i++) {
    const current = parsedMatches[i];
    const next = parsedMatches[i + 1];
    const startOffset = Math.floor(current.startMs / 1000);
    const endOffset = next
      ? Math.floor(next.startMs / 1000)
      : (durationMs ? Math.floor(durationMs / 1000) : startOffset + 30);

    const separator = baseWatchUrl.includes("?") ? "&" : "?";
    clips.push({
      "@type": "Clip",
      name: current.name,
      startOffset: startOffset,
      endOffset: endOffset,
      url: `${baseWatchUrl}${separator}t=${startOffset}`
    });
  }

  return clips;
}

export function generateVideoSchema(
  video: VideoData,
  authorUrl: string,
  channelName: string,
  isBrand: boolean = false
) {
  let rawId = String(video.id || video.videoId || "").trim();
  if (rawId.includes("watch?v=")) {
    rawId = rawId.split("watch?v=")[1].split("&")[0];
  } else if (rawId.includes("watch/")) {
    rawId = rawId.split("watch/")[1].split("/")[0].split("?")[0];
  }
  const videoId = rawId;
  const watchUrl = `${DOMAIN}/watch?v=${encodeURIComponent(videoId)}`;
  const embedUrl = `${DOMAIN}/embed/${encodeURIComponent(videoId)}`;
  
  const rawThumbnail = video.thumbnailUrl || video.thumbnail || `${DOMAIN}/icons/og-image.png`;
  const normalizedThumb = rawThumbnail.startsWith("http") ? rawThumbnail : `${DOMAIN}${rawThumbnail.startsWith("/") ? "" : "/"}${rawThumbnail}`;
  
  const thumbnailList: string[] = [normalizedThumb];
  if (Array.isArray(video.thumbnailVariants)) {
    for (const v of video.thumbnailVariants) {
      if (v && typeof v === "string" && !thumbnailList.includes(v)) {
        thumbnailList.push(v.startsWith("http") ? v : `${DOMAIN}${v.startsWith("/") ? "" : "/"}${v}`);
      }
    }
  }

  const contentUrl = video.hlsUrl || video.originalUrl || video.videoUrl || "";
  const uploadDate = formatDate(video.uploadedAt || video.publishedAt || video.createdAt);
  
  let durationMs = video.durationMs;
  if (!durationMs && typeof video.duration === "number") {
    durationMs = video.duration > 100000 ? video.duration : video.duration * 1000;
  }
  const durationIso = formatIsoDuration(durationMs);

  let clips: any[] = [];
  if (video.chapters && video.chapters.length > 0) {
    clips = video.chapters.map((ch, idx) => {
      const startSec = Math.floor(ch.startMs / 1000);
      const nextCh = video.chapters![idx + 1];
      const endSec = nextCh
        ? Math.floor(nextCh.startMs / 1000)
        : (durationMs ? Math.floor(durationMs / 1000) : startSec + 30);
      const sep = watchUrl.includes("?") ? "&" : "?";
      return {
        "@type": "Clip",
        name: ch.title,
        startOffset: startSec,
        endOffset: endSec,
        url: `${watchUrl}${sep}t=${startSec}`
      };
    });
  } else if (video.description) {
    clips = extractClipsFromDescription(video.description, durationMs, watchUrl);
  }

  const rawTitle = (video.title || "Video").trim();
  const rawDesc = (video.description || "").trim();
  const descriptionText = rawDesc || `Watch ${rawTitle} by ${channelName} on Truthworld. Verified family-safe video streaming.`;

  const schema: any = {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    "@id": watchUrl,
    url: watchUrl,
    name: rawTitle,
    description: descriptionText,
    thumbnailUrl: thumbnailList,
    uploadDate: uploadDate,
    duration: durationIso,
    contentUrl: contentUrl || undefined,
    embedUrl: embedUrl,
    inLanguage: video.language || "en",
    isFamilyFriendly: video.isKidFriendly !== false,
    interactionStatistic: [
      {
        "@type": "InteractionCounter",
        interactionType: { "@type": "WatchAction" },
        userInteractionCount: video.viewCount || video.views || 0
      },
      {
        "@type": "InteractionCounter",
        interactionType: { "@type": "LikeAction" },
        userInteractionCount: video.likeCount || video.likes || 0
      }
    ],
    publisher: {
      "@type": "Organization",
      name: "Truthworld",
      url: DOMAIN,
      logo: {
        "@type": "ImageObject",
        url: `${DOMAIN}/icons/Icon-192.png`,
        width: 192,
        height: 192
      }
    },
    author: {
      "@type": isBrand ? "Organization" : "Person",
      name: channelName || "Truthworld Creator",
      url: authorUrl || DOMAIN
    },
    potentialAction: [
      {
        "@type": "SeekToAction",
        target: `${watchUrl}&t={seek_to_second_number}`,
        "startOffset-input": "required name=seek_to_second_number"
      },
      {
        "@type": "WatchAction",
        target: watchUrl
      }
    ]
  };

  if (clips.length > 0) {
    schema.hasPart = clips;
  }

  return schema;
}
