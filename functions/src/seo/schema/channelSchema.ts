import { DOMAIN } from "./schemaConfig";

export interface ChannelData {
  id: string;
  name?: string;
  displayName?: string;
  handle?: string;
  about?: string;
  description?: string;
  avatarUrl?: string;
  avatar?: string;
  bannerUrl?: string;
  bannerImage?: string;
  coverUrl?: string;
  videoCount?: number;
  profile?: { photoUrl?: string; links?: Record<string, string> };
  socialLinks?: Record<string, string>;
  stats?: { subscriberCount?: number; videoCount?: number };
  subscriberCount?: number;
  isBrand?: boolean;
  creatorType?: string;
  type?: string;
}

export function generateChannelSchema(channel: ChannelData, channelUrl: string, resolvedImage?: string) {
  const channelName = channel.displayName || channel.name || "Channel";
  const descStr = channel.about || channel.description || `Watch videos from ${channelName} on Truthworld.`;
  const imgStr = resolvedImage || channel.bannerUrl || channel.coverUrl || channel.bannerImage || channel.profile?.photoUrl || channel.avatarUrl || channel.avatar || `${DOMAIN}/icons/og-image.png`;
  
  const isBrand = channel.isBrand === true || channel.creatorType === "Organization" || channel.type === "custom";
  const mainEntityType = isBrand ? "Organization" : "Person";

  const cleanHandle = channel.handle ? channel.handle.replace(/^@/, "").trim() : "";
  const handleWithAt = cleanHandle ? `@${cleanHandle}` : undefined;

  const sameAsList: string[] = [];
  const rawLinks = channel.profile?.links || channel.socialLinks;
  if (rawLinks) {
    for (const k in rawLinks) {
      const url = rawLinks[k];
      if (typeof url === "string" && (url.startsWith("http://") || url.startsWith("https://"))) {
        sameAsList.push(url);
      }
    }
  }

  const interactions: any[] = [
    {
      "@type": "InteractionCounter",
      interactionType: { "@type": "FollowAction" },
      userInteractionCount: channel.stats?.subscriberCount || channel.subscriberCount || 0
    }
  ];

  const totalVideos = channel.stats?.videoCount || channel.videoCount || 0;
  if (totalVideos > 0) {
    interactions.push({
      "@type": "InteractionCounter",
      interactionType: { "@type": "WriteAction" },
      userInteractionCount: totalVideos
    });
  }

  const mainEntity: Record<string, any> = {
    "@type": mainEntityType,
    name: channelName,
    description: descStr,
    image: imgStr,
    url: channelUrl,
    interactionStatistic: interactions
  };

  if (handleWithAt) {
    mainEntity.alternateName = handleWithAt;
  }

  if (sameAsList.length > 0) {
    mainEntity.sameAs = sameAsList;
  }

  return {
    "@context": "https://schema.org",
    "@type": "ProfilePage",
    mainEntity
  };
}
