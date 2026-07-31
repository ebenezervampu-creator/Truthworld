import * as admin from "firebase-admin";
import { DOMAIN, escapeHtml, formatDate } from "../schema/schemaConfig";

export async function generateSitemapIndex(): Promise<string> {
  return `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>${DOMAIN}/sitemap-static.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-videos-001.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-channels-001.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-topics.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-playlists.xml</loc>
  </sitemap>
  <sitemap>
    <loc>${DOMAIN}/sitemap-community-001.xml</loc>
  </sitemap>
</sitemapindex>`;
}

export async function generateStaticSitemap(): Promise<string> {
  const pages = [
    { path: "", priority: "1.0" },
    { path: "/home", priority: "1.0" },
    { path: "/studio", priority: "0.9" },
    { path: "/advertiser", priority: "0.9" },
    { path: "/advertisements", priority: "0.9" },
    { path: "/browse", priority: "0.8" },
    { path: "/trending", priority: "0.8" },
    { path: "/about", priority: "0.6" },
    { path: "/privacy", priority: "0.5" },
    { path: "/terms", priority: "0.5" },
    { path: "/help", priority: "0.6" },
    { path: "/feedback", priority: "0.6" },
    { path: "/premium", priority: "0.6" }
  ];
  const dateStr = new Date().toISOString().split("T")[0];
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  for (const page of pages) {
    xml += `
  <url>
    <loc>${DOMAIN}${page.path}</loc>
    <lastmod>${dateStr}</lastmod>
    <changefreq>daily</changefreq>
    <priority>${page.priority}</priority>
  </url>`;
  }
  xml += `\n</urlset>`;
  return xml;
}

export async function generateVideosSitemapShard(db: admin.firestore.Firestore, shardIndex: number = 1): Promise<string> {
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:video="http://www.google.com/schemas/sitemap-video/1.1">`;

  try {
    const snap = await db
      .collection("videos")
      .where("visibility", "==", "public")
      .orderBy("uploadedAt", "desc")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      if (status === "ready" && data.earlyPrecheck?.status === "approved") {
        const title = escapeHtml(data.title || "Video");
        const description = escapeHtml(data.description || `Watch ${data.title} on Truthworld.`);
        const thumbnail = escapeHtml(data.thumbnailUrl || data.thumbnail || `${DOMAIN}/icons/og-image.png`);
        const contentUrl = escapeHtml(data.hlsUrl || data.originalUrl || data.videoUrl || "");
        const durationSec = data.durationMs ? Math.floor(data.durationMs / 1000) : 0;
        const uploadDate = formatDate(data.uploadedAt || data.createdAt);
        const viewCount = data.viewCount || data.views || 0;
        const channelName = escapeHtml(data.channelName || "Uploader");

        xml += `
  <url>
    <loc>${DOMAIN}/watch?v=${doc.id}</loc>
    <lastmod>${formatDate(data.updatedAt || data.uploadedAt || data.createdAt).split("T")[0]}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
    <video:video>
      <video:thumbnail_loc>${thumbnail}</video:thumbnail_loc>
      <video:title>${title}</video:title>
      <video:description>${description}</video:description>
      ${contentUrl ? `<video:content_loc>${contentUrl}</video:content_loc>` : ""}
      <video:duration>${durationSec}</video:duration>
      <video:view_count>${viewCount}</video:view_count>
      <video:publication_date>${uploadDate}</video:publication_date>
      <video:family_friendly>${data.isKidFriendly ? "yes" : "no"}</video:family_friendly>
      <video:uploader info="${DOMAIN}/channel/${data.channelId}">${channelName}</video:uploader>
    </video:video>
  </url>`;
      }
    });
  } catch (err) {
    console.error("Error generating video sitemap shard", err);
  }

  xml += `\n</urlset>`;
  return xml;
}

export async function generateChannelsSitemapShard(db: admin.firestore.Firestore, shardIndex: number = 1): Promise<string> {
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("channels")
      .where("status", "==", "active")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      let handle = data.handleLowercase || data.handle;
      const lastmod = formatDate(data.updatedAt || data.createdAt).split("T")[0];
      if (handle) {
        if (handle.startsWith("@")) {
          handle = handle.substring(1);
        }
        xml += `
  <url>
    <loc>${DOMAIN}/@${handle}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>`;
      }
      xml += `
  <url>
    <loc>${DOMAIN}/channel/${doc.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`;
    });
  } catch (err) {
    console.error("Error generating channel sitemap shard", err);
  }

  xml += `\n</urlset>`;
  return xml;
}

export async function generateTopicsSitemap(db: admin.firestore.Firestore): Promise<string> {
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("topics")
      .where("status", "==", "active")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const slug = data.slug || doc.id;
      const lastmod = formatDate(data.updatedAt || data.createdAt).split("T")[0];
      xml += `
  <url>
    <loc>${DOMAIN}/topic/${slug}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>`;
    });
  } catch (err) {
    console.error("Error generating topics sitemap", err);
  }

  xml += `\n</urlset>`;
  return xml;
}

export async function generatePlaylistsSitemap(db: admin.firestore.Firestore): Promise<string> {
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("public_playlists")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const lastmod = formatDate(data.updatedAt || data.createdAt).split("T")[0];
      xml += `
  <url>
    <loc>${DOMAIN}/playlist?list=${doc.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`;
    });
  } catch (err) {
    console.error("Error generating playlists sitemap", err);
  }

  xml += `\n</urlset>`;
  return xml;
}

export async function generateCommunityPostsSitemapShard(db: admin.firestore.Firestore, shardIndex: number = 1): Promise<string> {
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    const snap = await db
      .collection("community_posts")
      .where("visibility", "==", "Public")
      .orderBy("uploadedAt", "desc")
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const lastmod = formatDate(data.uploadedAt || data.createdAt).split("T")[0];
      xml += `
  <url>
    <loc>${DOMAIN}/post/${doc.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`;
    });
  } catch (err) {
    console.error("Error generating community posts sitemap shard", err);
  }

  xml += `\n</urlset>`;
  return xml;
}
