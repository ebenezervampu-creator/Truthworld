import { DOMAIN } from "./schemaConfig";

export interface TopicData {
  id: string;
  title?: string;
  name?: string;
  description?: string;
  slug?: string;
}

export function generateTopicSchema(topic: TopicData, topicUrl: string, videos: Array<{ id: string; title: string }>) {
  const topicTitle = topic.title || topic.name || "Topic";
  const descStr = topic.description || `Explore top videos in ${topicTitle} on Truthworld.`;

  return {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: topicTitle,
    description: descStr,
    url: topicUrl,
    mainEntity: videos.length > 0 ? {
      "@type": "ItemList",
      name: topicTitle,
      numberOfItems: videos.length,
      itemListElement: videos.map((v, idx) => ({
        "@type": "ListItem",
        position: idx + 1,
        name: v.title,
        url: `${DOMAIN}/watch?v=${v.id}`
      }))
    } : {
      "@type": "Thing",
      name: topicTitle,
      description: descStr,
      url: topicUrl
    }
  };
}
