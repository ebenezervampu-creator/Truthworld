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
  const SHARD_SIZE = 2000;
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:video="http://www.google.com/schemas/sitemap-video/1.1">`;

  try {
    let snap: admin.firestore.QuerySnapshot;
    try {
      let query = db
        .collection("videos")
        .where("visibility", "in", ["public", "Public"])
        .limit(SHARD_SIZE);

      if (shardIndex > 1) {
        query = query.offset((shardIndex - 1) * SHARD_SIZE);
      }
      snap = await query.get();
    } catch (indexErr) {
      console.warn("Visibility query failed in video sitemap, running broad query", indexErr);
      let fallbackQuery = db
        .collection("videos")
        .limit(SHARD_SIZE);
      snap = await fallbackQuery.get();
    }

    snap.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      const visibility = (data.visibility || "public").toLowerCase();

      // Ensure video is not deleted, rejected, flagged, draft, or private
      if (
        (visibility === "public" || visibility === "") &&
        status !== "deleted" &&
        status !== "rejected" &&
        status !== "flagged" &&
        status !== "draft" &&
        status !== "private"
      ) {
        const title = escapeHtml((data.title || "Video").trim());
        const description = escapeHtml((data.description || `Watch ${data.title} on Truthworld.`).trim());
        
        let rawThumbnail = data.thumbnailUrl || data.thumbnail || `${DOMAIN}/icons/og-image.png`;
        if (rawThumbnail.startsWith("/")) rawThumbnail = `${DOMAIN}${rawThumbnail}`;
        const thumbnail = escapeHtml(rawThumbnail);

        let rawContentUrl = data.hlsUrl || data.originalUrl || data.videoUrl || "";
        if (rawContentUrl && !rawContentUrl.startsWith("http")) {
          rawContentUrl = `${DOMAIN}${rawContentUrl.startsWith("/") ? "" : "/"}${rawContentUrl}`;
        }
        const contentUrl = escapeHtml(rawContentUrl);
        const embedUrl = escapeHtml(`${DOMAIN}/embed/${doc.id}`);
        const durationSec = data.durationMs ? Math.floor(data.durationMs / 1000) : (typeof data.duration === "number" ? data.duration : 0);
        const uploadDate = formatDate(data.uploadedAt || data.publishedAt || data.createdAt);
        const viewCount = data.viewCount || data.views || 0;
        const channelName = escapeHtml(data.channelName || "Truthworld Creator");
        const channelUrl = escapeHtml(data.channelId ? `${DOMAIN}/channel/${data.channelId}` : DOMAIN);
        const isLive = data.isLive === true || data.status === "live" || data.streamStatus === "live";

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
      <video:player_loc allow_embed="yes" autoplay="ap=1">${embedUrl}</video:player_loc>
      ${durationSec > 0 ? `<video:duration>${durationSec}</video:duration>` : ""}
      <video:view_count>${viewCount}</video:view_count>
      <video:publication_date>${uploadDate}</video:publication_date>
      <video:family_friendly>${data.isKidFriendly !== false ? "yes" : "no"}</video:family_friendly>
      ${isLive ? `<video:live>yes</video:live>` : ""}
      <video:uploader info="${channelUrl}">${channelName}</video:uploader>
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
  const SHARD_SIZE = 2000;
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    let query = db
      .collection("channels")
      .where("status", "==", "active")
      .limit(SHARD_SIZE);

    if (shardIndex > 1) {
      query = query.offset((shardIndex - 1) * SHARD_SIZE);
    }

    const snap = await query.get();

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
      } else {
        xml += `
  <url>
    <loc>${DOMAIN}/channel/${doc.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>`;
      }
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
      const slug = (data.slug || doc.id).trim();
      const title = (data.title || data.name || "").trim().toLowerCase();
      const lowerSlug = slug.toLowerCase();

      const videoCount = Number(data.videoCount) || (Array.isArray(data.featuredVideoIds) ? data.featuredVideoIds.length : 0);
      if (
        !slug ||
        !title ||
        videoCount <= 0 ||
        lowerSlug === "topic" ||
        lowerSlug === "featured-topic" ||
        lowerSlug.startsWith("untitled") ||
        title === "topic" ||
        title === "featured topic" ||
        title.startsWith("untitled")
      ) {
        return;
      }

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
    let snap: admin.firestore.QuerySnapshot;
    try {
      snap = await db
        .collection("playlists")
        .where("visibility", "in", ["public", "Public"])
        .limit(2000)
        .get();
      if (snap.empty) {
        snap = await db
          .collection("playlists")
          .where("isPublic", "==", true)
          .limit(2000)
          .get();
      }
      if (snap.empty) {
        snap = await db
          .collection("playlists")
          .limit(2000)
          .get();
      }
    } catch (e) {
      snap = await db
        .collection("public_playlists")
        .limit(2000)
        .get();
    }

    snap.forEach((doc) => {
      const data = doc.data();
      const isPublic = data.visibility === "public" || data.visibility === "Public" || data.isPublic === true;
      if (data.visibility && !isPublic) return;
      if (data.status === "deleted") return;

      const name = (data.name || data.playlistName || data.title || "").trim().toLowerCase();

      if (
        !name ||
        name === "playlist" ||
        name === "truthworld playlist" ||
        name.startsWith("untitled")
      ) {
        return;
      }

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
  const SHARD_SIZE = 2000;
  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;

  try {
    let snap: admin.firestore.QuerySnapshot;
    try {
      let query = db
        .collection("Community")
        .where("visibility", "in", ["public", "Public"])
        .limit(SHARD_SIZE);
      if (shardIndex > 1) {
        query = query.offset((shardIndex - 1) * SHARD_SIZE);
      }
      snap = await query.get();
    } catch (e) {
      try {
        let query = db
          .collection("Community")
          .limit(SHARD_SIZE);
        if (shardIndex > 1) {
          query = query.offset((shardIndex - 1) * SHARD_SIZE);
        }
        snap = await query.get();
      } catch (err2) {
        let query = db
          .collection("community_posts")
          .limit(SHARD_SIZE);
        if (shardIndex > 1) {
          query = query.offset((shardIndex - 1) * SHARD_SIZE);
        }
        snap = await query.get();
      }
    }

    snap.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      const visibility = (data.visibility || "").toLowerCase();
      if (status === "deleted" || status === "rejected") return;
      if (visibility === "private") return;

      const lastmod = formatDate(data.timestamp || data.uploadedAt || data.createdAt).split("T")[0];
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
