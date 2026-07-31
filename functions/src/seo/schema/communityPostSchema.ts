import { DOMAIN, formatDate } from "./schemaConfig";

export interface CommunityPostSchemaData {
  id: string;
  title?: string;
  description?: string;
  channelId?: string;
  channelName?: string;
  channelImage?: string;
  images?: string[];
  image?: string;
  likes?: number;
  commentCount?: number;
  views?: number;
  uploadedAt?: any;
  createdAt?: any;
}

export function generateCommunityPostSchema(data: CommunityPostSchemaData, canonicalUrl: string) {
  const postTitle = data.title || (data.description ? data.description.substring(0, 80) : "Community Post");
  const authorName = data.channelName || "Channel";
  const authorUrl = data.channelId ? `${DOMAIN}/channel/${data.channelId}` : DOMAIN;
  const postDate = formatDate(data.uploadedAt || data.createdAt);

  const images: string[] = [];
  if (data.images && Array.isArray(data.images)) {
    images.push(...data.images);
  } else if (data.image) {
    images.push(data.image);
  }

  return {
    "@context": "https://schema.org",
    "@type": "SocialMediaPosting",
    "headline": postTitle,
    "articleBody": data.description || postTitle,
    "url": canonicalUrl,
    "datePublished": postDate,
    "dateModified": postDate,
    "image": images.length > 0 ? images : undefined,
    "author": {
      "@type": "Person",
      "name": authorName,
      "url": authorUrl,
      "image": data.channelImage
    },
    "publisher": {
      "@type": "Organization",
      "name": "Truthworld",
      "url": DOMAIN,
      "logo": `${DOMAIN}/icons/Icon-192.png`
    },
    "interactionStatistic": [
      {
        "@type": "InteractionCounter",
        "interactionType": "https://schema.org/LikeAction",
        "userInteractionCount": data.likes || 0
      },
      {
        "@type": "InteractionCounter",
        "interactionType": "https://schema.org/CommentAction",
        "userInteractionCount": data.commentCount || 0
      }
    ]
  };
}
