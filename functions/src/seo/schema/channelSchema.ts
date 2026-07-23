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
  profile?: { photoUrl?: string; links?: Record<string, string> };
  socialLinks?: Record<string, string>;
  stats?: { subscriberCount?: number };
  subscriberCount?: number;
  isBrand?: boolean;
  creatorType?: string;
  type?: string;
}

export function generateChannelSchema(channel: ChannelData, channelUrl: string) {
  const channelName = channel.displayName || channel.name || "Channel";
  const descStr = channel.about || channel.description || `Watch videos from ${channelName} on Truthworld.`;
  const imgStr = channel.profile?.photoUrl || channel.avatarUrl || channel.avatar || `${DOMAIN}/icons/og-image.png`;
  
  const isBrand = channel.isBrand === true || channel.creatorType === "Organization" || channel.type === "custom";
  const mainEntityType = isBrand ? "Organization" : "Person";

  const sameAsList: string[] = [];
  if (channel.profile?.links) {
    const links = channel.profile.links;
    for (const k in links) {
      if (links[k]) sameAsList.push(links[k]);
    }
  } else if (channel.socialLinks) {
    const links = channel.socialLinks;
    for (const k in links) {
      if (links[k]) sameAsList.push(links[k]);
    }
  }

  return {
    "@context": "https://schema.org",
    "@type": "ProfilePage",
    mainEntity: {
      "@type": mainEntityType,
      name: channelName,
      description: descStr,
      image: imgStr,
      url: channelUrl,
      interactionStatistic: [
        {
          "@type": "InteractionCounter",
          interactionType: { "@type": "SubscribeAction" },
          userInteractionCount: channel.stats?.subscriberCount || channel.subscriberCount || 0
        }
      ],
      sameAs: sameAsList
    }
  };
}
