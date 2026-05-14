/**
 * CLOUD FUNCTION: Video SEO Integration
 * 
 * Triggered when videos are uploaded/updated in Firestore.
 * Updates video sitemap and pings Google for indexing.
 * 
 * Deploy to Firebase Cloud Functions:
 *   firebase deploy --only functions:onVideoUpload
 * 
 * Firestore trigger: videos/{videoId}
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin SDK
const db = admin.firestore();
const storage = admin.storage();

/**
 * Keep admin.initializeApp() ONLY if not already initialized
 * Cloud Functions auto-initialize, so this may not be needed
 */
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Helper: Format duration in seconds to ISO 8601
 */
function secondsToISO8601(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  let result = 'PT';
  if (hours > 0) result += `${hours}H`;
  if (minutes > 0) result += `${minutes}M`;
  if (secs > 0) result += `${secs}S`;
  if (result === 'PT') result = 'PT0S';

  return result;
}

/**
 * Helper: Escape XML special characters
 */
function escapeXml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/**
 * Generate Video Sitemap XML
 */
async function generateVideoSitemap() {
  try {
    console.log('📝 Generating video sitemap...');

    // Fetch all published videos
    const videosSnapshot = await db.collection('videos')
      .where('published', '==', true)
      .orderBy('uploadDate', 'desc')
      .limit(50000)
      .get();

    let sitemapXml = '<?xml version="1.0" encoding="UTF-8"?>\n';
    sitemapXml += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n';
    sitemapXml += '        xmlns:video="http://www.google.com/schemas/sitemap-video/1.1">\n';

    videosSnapshot.forEach(doc => {
      const video = doc.data();
      const videoId = doc.id;
      const slug = video.slug || videoId;

      // Ensure required fields
      const thumbnail = video.thumbnail || 'https://www.truthworld.in/og-image.png';
      const title = escapeXml(video.title || 'Untitled');
      const description = escapeXml(video.description || '');
      const duration = Math.floor(video.duration || 0);
      const uploadDate = video.uploadDate instanceof admin.firestore.Timestamp
        ? video.uploadDate.toDate().toISOString()
        : new Date(video.uploadDate || Date.now()).toISOString();

      sitemapXml += '  <url>\n';
      sitemapXml += `    <loc>https://www.truthworld.in/video/${slug}</loc>\n`;
      sitemapXml += `    <lastmod>${uploadDate.split('T')[0]}</lastmod>\n`;
      sitemapXml += '    <video:video>\n';
      sitemapXml += `      <video:thumbnail_loc>${escapeXml(thumbnail)}</video:thumbnail_loc>\n`;
      sitemapXml += `      <video:title>${title}</video:title>\n`;
      sitemapXml += `      <video:description>${description}</video:description>\n`;
      sitemapXml += `      <video:content_loc>https://www.truthworld.in/video/${slug}/stream</video:content_loc>\n`;
      sitemapXml += `      <video:duration>${duration}</video:duration>\n`;
      sitemapXml += `      <video:publication_date>${uploadDate}</video:publication_date>\n`;
      sitemapXml += `      <video:view_count>${Math.floor(video.viewCount || 0)}</video:view_count>\n`;

      // Add rating if available
      if (video.rating) {
        sitemapXml += `      <video:rating>${parseFloat(video.rating).toFixed(1)}</video:rating>\n`;
      }

      // Add tags if available
      if (video.tags && Array.isArray(video.tags)) {
        video.tags.slice(0, 32).forEach(tag => { // Google limit: 32 tags
          sitemapXml += `      <video:tag>${escapeXml(tag)}</video:tag>\n`;
        });
      }

      sitemapXml += '    </video:video>\n';
      sitemapXml += '  </url>\n';
    });

    sitemapXml += '</urlset>';

    // Upload to Firebase Storage (public bucket)
    const bucket = storage.bucket();
    const file = bucket.file('video-sitemap.xml');

    await file.save(sitemapXml, {
      contentType: 'application/xml',
      public: true,
      metadata: {
        cacheControl: 'public, max-age=3600', // Cache for 1 hour
      }
    });

    console.log(`✅ Sitemap generated: ${videosSnapshot.size} videos`);
    return sitemapXml;
  } catch (error) {
    console.error('❌ Error generating sitemap:', error);
    throw error;
  }
}

/**
 * Ping Google to notify about sitemap update
 */
async function pingGoogle() {
  try {
    console.log('📡 Pinging Google...');

    const sitemapUrl = 'https://www.truthworld.in/video-sitemap.xml';
    const pingUrl = `https://www.google.com/ping?sitemap=${encodeURIComponent(sitemapUrl)}`;

    const response = await axios.get(pingUrl, { timeout: 10000 });
    console.log(`✅ Google pinged (status: ${response.status})`);

    return true;
  } catch (error) {
    // Google ping may fail silently - not critical
    console.warn('⚠️ Google ping error (non-critical):', error.message);
    return false;
  }
}

/**
 * CLOUD FUNCTION: Triggered on video upload/update
 */
exports.onVideoUploadOrUpdate = functions.firestore
  .document('videos/{videoId}')
  .onWrite(async (change, context) => {
    try {
      console.log(`\n📹 Video operation: ${context.params.videoId}`);

      const before = change.before.exists ? change.before.data() : null;
      const after = change.after.exists ? change.after.data() : null;

      // Only process if video is published
      const isPublished = after && after.published === true;
      const wasPublished = before && before.published === true;

      if (!isPublished && !wasPublished) {
        console.log('⏭️ Skipping: Draft video');
        return;
      }

      // Regenerate sitemap
      await generateVideoSitemap();

      // Ping Google
      await pingGoogle();

      console.log('✅ Video SEO update complete\n');
    } catch (error) {
      console.error('💥 Error in onVideoUploadOrUpdate:', error);
      // Don't re-throw - Cloud Functions will retry
    }
  });

/**
 * CLOUD FUNCTION: Manual sitemap regeneration (HTTP trigger)
 * 
 * Usage:
 *   POST https://region-project.cloudfunctions.net/regenerateVideoSitemap
 * 
 * Call this periodically (e.g., via Cloud Scheduler) to keep sitemap fresh
 */
exports.regenerateVideoSitemap = functions.https.onRequest(async (req, res) => {
  try {
    // Optional: Verify authorization token
    const token = req.query.token || req.body.token;
    if (token !== process.env.SITEMAP_REGENERATE_TOKEN) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    console.log('🔄 Manual sitemap regeneration requested');

    await generateVideoSitemap();
    await pingGoogle();

    res.status(200).json({
      success: true,
      message: 'Video sitemap regenerated and Google notified',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error regenerating sitemap:', error);
    res.status(500).json({
      error: 'Failed to regenerate sitemap',
      message: error.message
    });
  }
});

/**
 * CLOUD SCHEDULER SETUP (Optional)
 * 
 * Create a Cloud Scheduler job to regenerate sitemap daily:
 * 
 * Command:
 *   gcloud scheduler jobs create http regenerate-video-sitemap \
 *     --schedule="0 2 * * *" \
 *     --uri="https://region-project.cloudfunctions.net/regenerateVideoSitemap?token=YOUR_TOKEN" \
 *     --http-method=POST
 * 
 * This runs every day at 2 AM UTC
 */

module.exports = exports;
