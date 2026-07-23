import { DOMAIN, escapeHtml, formatDate } from "../schema/schemaConfig";

export interface RssVideoItem {
  id: string;
  title: string;
  description?: string;
  thumbnailUrl?: string;
  uploadedAt?: any;
  createdAt?: any;
  channelName?: string;
}

export function generateRssFeed(videos: RssVideoItem[]): string {
  const pubDate = new Date().toUTCString();

  let itemsXml = "";
  for (const v of videos) {
    const link = `${DOMAIN}/watch?v=${v.id}`;
    const title = escapeHtml(v.title || "Video");
    const description = escapeHtml(v.description || `Watch ${v.title} on Truthworld.`);
    const itemDate = new Date(formatDate(v.uploadedAt || v.createdAt)).toUTCString();
    const thumbnail = escapeHtml(v.thumbnailUrl || `${DOMAIN}/icons/og-image.png`);
    const author = escapeHtml(v.channelName || "Truthworld Creator");

    itemsXml += `
    <item>
      <title>${title}</title>
      <link>${link}</link>
      <guid isPermaLink="true">${link}</guid>
      <pubDate>${itemDate}</pubDate>
      <description>${description}</description>
      <author>${author}</author>
      <media:thumbnail url="${thumbnail}" />
      <media:content url="${link}" medium="video" />
    </item>`;
  }

  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" 
     xmlns:media="http://search.yahoo.com/mrss/" 
     xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Truthworld - Latest Videos</title>
    <link>${DOMAIN}</link>
    <description>Verify before you share. The latest trustworthy stories and video insights on Truthworld.</description>
    <language>en-us</language>
    <lastBuildDate>${pubDate}</lastBuildDate>
    <atom:link href="${DOMAIN}/feeds/videos.xml" rel="self" type="application/rss+xml" />
    ${itemsXml}
  </channel>
</rss>`;
}
