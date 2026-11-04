import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

export interface ModerationModes {
  all?: boolean;         // Convenience flag when all 9 are enabled
  videos: boolean;       // true = bypass Gemini, route video to Admin only; false = send to Gemini
  thumbnails: boolean;   // true = bypass Vision AI, route video thumbnail to Admin only; false = send to Vision AI
  channels: boolean;     // true = bypass Gemini, route channel details to Admin only; false = send to Gemini
  avatar: boolean;       // true = bypass Vision AI, route avatar to Admin only; false = send to Vision AI
  banner: boolean;       // true = bypass Vision AI, route banner to Admin only; false = send to Vision AI
  community: boolean;    // true = bypass Vision AI, route community posts to Admin only; false = send to Vision AI
  topics: boolean;       // true = bypass Vision AI / Gemini, route topic details & thumbnails to Admin only; false = send to AI
  playlists: boolean;    // true = bypass Vision AI / Gemini, route playlist details & thumbnails to Admin only; false = send to AI
  ads: boolean;          // true = bypass Gemini, route ad campaign to Admin only; false = send to Gemini
}

const DEFAULT_MODERATION_MODES: ModerationModes = {
  all: false,
  videos: false,
  thumbnails: false,
  channels: false,
  avatar: false,
  banner: false,
  community: false,
  topics: false,
  playlists: false,
  ads: false,
};

const db = () => admin.firestore();

/**
 * Reads the current moderation modes from admin_settings/moderation_modes.
 * Returns default (all false) if the document does not exist or fails to load.
 * Each of the 9 modes operates completely independently.
 */
export async function getModerationModes(): Promise<ModerationModes> {
  try {
    let data: any = null;
    const snap = await db().collection("admin_settings").doc("moderation_modes").get();
    if (snap.exists) {
      data = snap.data() || {};
    } else {
      // Check fallback collection system_settings if admin_settings not populated
      const fallbackSnap = await db().collection("system_settings").doc("moderation_modes").get();
      if (fallbackSnap.exists) {
        data = fallbackSnap.data() || {};
      }
    }

    if (!data) {
      return DEFAULT_MODERATION_MODES;
    }

    const masterBypass = data.all === true || data.master === true;
    const videos = masterBypass || data.videos === true;
    const thumbnails = masterBypass || data.thumbnails === true || data.videos_thumbnails === true || data.videoThumbnails === true;
    const channels = masterBypass || data.channels === true || data.channelDetails === true;
    const avatar = masterBypass || data.avatar === true || data.channelAvatar === true || data.channel_avatar === true;
    const banner = masterBypass || data.banner === true || data.channelBanner === true || data.channel_banner === true;
    const community = masterBypass || data.community === true || data.community_posts === true || data.communityPosts === true;
    const topics = masterBypass || data.topics === true || data.topic_thumbnails === true || data.topicThumbnails === true;
    const playlists = masterBypass || data.playlists === true || data.playlist_thumbnails === true || data.playlistThumbnails === true;
    const ads = masterBypass || data.ads === true || data.campaigns === true || data.adCampaigns === true || data.advertiser_campaigns === true;

    const allOn = videos && thumbnails && channels && avatar && banner && community && topics && playlists && ads;

    return {
      all: masterBypass || allOn,
      videos,
      thumbnails,
      channels,
      avatar,
      banner,
      community,
      topics,
      playlists,
      ads,
    };
  } catch (err) {
    logger.warn("[getModerationModes] Failed to read moderation modes, defaulting to AI auto mode:", err);
    return DEFAULT_MODERATION_MODES;
  }
}

/**
 * 1. Videos Content (Audio & Video Stream): true = Route to Admin only; false = Send to Gemini 2.5 Flash
 */
export async function isVideosBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.videos === true;
}

/**
 * 2. Video Thumbnails: true = Route to Admin only; false = Send to Google Cloud Vision SafeSearch
 */
export async function isThumbnailsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.thumbnails === true;
}

/**
 * 3. Channel Details & Registration: true = Route to Admin only; false = Send to Gemini AI
 */
export async function isChannelsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.channels === true;
}

/**
 * 4. Channel Avatars: true = Route to Admin only; false = Send to Google Cloud Vision SafeSearch
 */
export async function isAvatarBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.avatar === true;
}

/**
 * 5. Channel Banners: true = Route to Admin only; false = Send to Google Cloud Vision SafeSearch
 */
export async function isBannerBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.banner === true;
}

/**
 * 6. Community Posts: true = Route to Admin only; false = Send to Google Cloud Vision SafeSearch
 */
export async function isCommunityBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.community === true;
}

/**
 * 7. Topics Details & Cover: true = Route to Admin only; false = Send to Gemini AI & Vision
 */
export async function isTopicsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.topics === true;
}

/**
 * 8. Playlists Details & Cover: true = Route to Admin only; false = Send to Gemini AI & Vision
 */
export async function isPlaylistsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.playlists === true;
}

/**
 * 9. Advertiser Campaigns: true = Route to Admin only; false = Send to Gemini AI
 */
export async function isAdsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.ads === true;
}

export async function isCampaignsBypassed(): Promise<boolean> {
  return isAdsBypassed();
}
