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
    { path: "/advertisements", priority: "0.9" },
    { path: "/browse", priority: "0.8" },
    { path: "/trending", priority: "0.8" },
    { path: "/about", priority: "0.6" },
    { path: "/privacy", priority: "0.5" },
    { path: "/terms", priority: "0.5" },
    { path: "/community-guidelines", priority: "0.5" },
    { path: "/copyright-complaint", priority: "0.4" },
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
    let snap: admin.firestore.QuerySnapshot | null = null;

    // Tier 1: Try public visibility
    try {
      let query = db
        .collection("videos")
        .where("visibility", "in", ["public", "Public"])
        .limit(SHARD_SIZE);

      if (shardIndex > 1) {
        query = query.offset((shardIndex - 1) * SHARD_SIZE);
      }
      const testSnap = await query.get();
      if (!testSnap.empty) {
        snap = testSnap;
      }
    } catch (e) {
      console.warn("Tier 1 video sitemap query failed:", e);
    }

    // Tier 2: Try published/ready status
    if (!snap || snap.empty) {
      try {
        let query = db
          .collection("videos")
          .where("status", "in", ["published", "ready", "active"])
          .limit(SHARD_SIZE);

        if (shardIndex > 1) {
          query = query.offset((shardIndex - 1) * SHARD_SIZE);
        }
        const testSnap = await query.get();
        if (!testSnap.empty) {
          snap = testSnap;
        }
      } catch (e) {
        console.warn("Tier 2 video sitemap query failed:", e);
      }
    }

    // Tier 3: Broad fallback query without restrictive filter
    if (!snap || snap.empty) {
      try {
        let query = db
          .collection("videos")
          .limit(SHARD_SIZE);

        if (shardIndex > 1) {
          query = query.offset((shardIndex - 1) * SHARD_SIZE);
        }
        snap = await query.get();
      } catch (e) {
        console.error("Tier 3 broad video sitemap query failed:", e);
      }
    }

    if (snap && !snap.empty) {
      snap.forEach((doc) => {
        const data = doc.data();
        const status = (data.status || "").toLowerCase();
        const visibility = (data.visibility || "public").toLowerCase();
        const rawTitle = (data.title || "").trim();
        const lowerTitle = rawTitle.toLowerCase();

        // Strict validation: exclude deleted, rejected, flagged, draft, private, or untitled
        if (
          visibility === "private" ||
          visibility === "draft" ||
          status === "deleted" ||
          status === "rejected" ||
          status === "flagged" ||
          status === "draft" ||
          status === "private" ||
          !rawTitle ||
          lowerTitle === "untitled" ||
          lowerTitle.startsWith("untitled") ||
          lowerTitle.startsWith("uploading")
        ) {
          return;
        }

        const title = escapeHtml(rawTitle);
        const description = escapeHtml((data.description || `Watch ${rawTitle} on Truthworld.`).trim());

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
      });
    }
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
    let query: admin.firestore.Query = db.collection("channels").limit(SHARD_SIZE);

    if (shardIndex > 1) {
      query = query.offset((shardIndex - 1) * SHARD_SIZE);
    }

    const snap = await query.get();

    snap.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      if (status === "suspended" || status === "banned" || status === "deleted") {
        return;
      }

      const vis = (data.visibility || "").toLowerCase();
      if (vis === "private" || vis === "unlisted" || data.isPublic === false) {
        return;
      }

      let handle = data.handleLowercase || data.handle;
      const rawName = (data.displayName || data.name || data.channelName || "").trim();
      if (rawName.toLowerCase().startsWith("untitled") && !handle) {
        return;
      }

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
      .limit(2000)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      if (status === "deleted" || status === "inactive") return;

      const slug = (data.slug || doc.id).trim();
      const title = (data.title || data.name || "").trim().toLowerCase();
      const lowerSlug = slug.toLowerCase();

      if (
        !slug ||
        !title ||
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
    let snap: admin.firestore.QuerySnapshot | null = null;
    try {
      const pSnap = await db.collection("playlists").limit(2000).get();
      if (!pSnap.empty) {
        snap = pSnap;
      }
    } catch (e) {
      console.warn("Query playlists collection failed:", e);
    }

    if (!snap || snap.empty) {
      try {
        const pubSnap = await db.collection("public_playlists").limit(2000).get();
        if (!pubSnap.empty) {
          snap = pubSnap;
        }
      } catch (e) {
        console.warn("Query public_playlists collection failed:", e);
      }
    }

    if (snap && !snap.empty) {
      snap.forEach((doc) => {
        const data = doc.data();
        const isPublic = data.visibility === "public" || data.visibility === "Public" || data.isPublic === true || data.visibility === undefined;
        if (!isPublic) return;
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
    }
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
    let snap: admin.firestore.QuerySnapshot | null = null;
    try {
      let query = db.collection("Community").limit(SHARD_SIZE);
      if (shardIndex > 1) {
        query = query.offset((shardIndex - 1) * SHARD_SIZE);
      }
      const cSnap = await query.get();
      if (!cSnap.empty) {
        snap = cSnap;
      }
    } catch (e) {
      console.warn("Query Community collection failed:", e);
    }

    if (!snap || snap.empty) {
      try {
        let query = db.collection("community_posts").limit(SHARD_SIZE);
        if (shardIndex > 1) {
          query = query.offset((shardIndex - 1) * SHARD_SIZE);
        }
        const cpSnap = await query.get();
        if (!cpSnap.empty) {
          snap = cpSnap;
        }
      } catch (e) {
        console.warn("Query community_posts collection failed:", e);
      }
    }

    if (snap && !snap.empty) {
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
    }
  } catch (err) {
    console.error("Error generating community posts sitemap shard", err);
  }

  xml += `\n</urlset>`;
  return xml;
}
