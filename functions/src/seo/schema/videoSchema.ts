import { DOMAIN, formatIsoDuration, formatDate } from "./schemaConfig";

export interface VideoData {
  id: string;
  title: string;
  description?: string;
  thumbnailUrl?: string;
  thumbnail?: string;
  durationMs?: number;
  uploadedAt?: any;
  createdAt?: any;
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
  chapters?: Array<{ title: string; startMs: number; endMs?: number }>;
}

export function extractClipsFromDescription(description: string, durationMs?: number): any[] {
  if (!description) return [];
  const clips: any[] = [];
  
  // Match timestamp patterns like 0:00, 00:00, 1:23:45 followed by title
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

    clips.push({
      "@type": "Clip",
      name: current.name,
      startOffset: startOffset,
      endOffset: endOffset,
      url: `${DOMAIN}/watch?v=${encodeURIComponent(current.name)}&t=${startOffset}`
    });
  }

  return clips;
}

export function generateVideoSchema(video: VideoData, authorUrl: string, channelName: string) {
  const watchUrl = `${DOMAIN}/watch?v=${video.id}`;
  const embedUrl = `${DOMAIN}/embed/watch?v=${video.id}`;
  const thumbnailUrl = video.thumbnailUrl || video.thumbnail || `${DOMAIN}/icons/og-image.png`;
  const contentUrl = video.hlsUrl || video.originalUrl || video.videoUrl || "";
  const uploadDate = formatDate(video.uploadedAt || video.createdAt);
  const durationIso = formatIsoDuration(video.durationMs);

  let clips: any[] = [];
  if (video.chapters && video.chapters.length > 0) {
    clips = video.chapters.map((ch, idx) => {
      const startSec = Math.floor(ch.startMs / 1000);
      const nextCh = video.chapters![idx + 1];
      const endSec = nextCh ? Math.floor(nextCh.startMs / 1000) : (video.durationMs ? Math.floor(video.durationMs / 1000) : startSec + 30);
      return {
        "@type": "Clip",
        name: ch.title,
        startOffset: startSec,
        endOffset: endSec,
        url: `${watchUrl}&t=${startSec}`
      };
    });
  } else if (video.description) {
    clips = extractClipsFromDescription(video.description, video.durationMs);
  }

  const schema: any = {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    name: video.title,
    description: video.description || `Watch ${video.title} on Truthworld.`,
    thumbnailUrl: [thumbnailUrl],
    uploadDate: uploadDate,
    duration: durationIso,
    contentUrl: contentUrl,
    embedUrl: embedUrl,
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
      logo: {
        "@type": "ImageObject",
        url: `${DOMAIN}/icons/Icon-192.png`
      }
    },
    author: {
      "@type": "Person",
      name: channelName,
      url: authorUrl
    },
    potentialAction: {
      "@type": "WatchAction",
      target: watchUrl
    }
  };

  if (clips.length > 0) {
    schema.hasPart = clips;
  }

  return schema;
}
