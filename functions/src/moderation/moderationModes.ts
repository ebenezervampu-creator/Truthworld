import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

export interface ModerationModes {
  videos: boolean;       // true = bypass Gemini, route video to Admin only; false = send to Gemini
  thumbnails: boolean;   // true = bypass Vision AI, route video thumbnail to Admin only; false = send to Vision AI
  channels: boolean;     // true = bypass Gemini, route channel details to Admin only; false = send to Gemini
  avatar: boolean;       // true = bypass Vision AI, route avatar to Admin only; false = send to Vision AI
  banner: boolean;       // true = bypass Vision AI, route banner to Admin only; false = send to Vision AI
  community: boolean;    // true = bypass Vision AI, route community posts to Admin only; false = send to Vision AI
  topics: boolean;       // true = bypass Vision AI, route topic thumbnails to Admin only; false = send to Vision AI
  playlists: boolean;    // true = bypass Vision AI, route playlist thumbnails to Admin only; false = send to Vision AI
  ads: boolean;          // true = bypass Gemini, route ad campaign to Admin only; false = send to Gemini
}

const DEFAULT_MODERATION_MODES: ModerationModes = {
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
 */
export async function getModerationModes(): Promise<ModerationModes> {
  try {
    const snap = await db().collection("admin_settings").doc("moderation_modes").get();
    if (!snap.exists) {
      // Check fallback collection system_settings if admin_settings not populated
      const fallbackSnap = await db().collection("system_settings").doc("moderation_modes").get();
      if (fallbackSnap.exists) {
        const data = fallbackSnap.data() || {};
        return {
          videos: data.videos === true,
          thumbnails: data.thumbnails === true || data.videos_thumbnails === true || data.videoThumbnails === true,
          channels: data.channels === true || data.channelDetails === true,
          avatar: data.avatar === true || data.channelAvatar === true || data.channel_avatar === true,
          banner: data.banner === true || data.channelBanner === true || data.channel_banner === true,
          community: data.community === true || data.community_posts === true || data.communityPosts === true,
          topics: data.topics === true || data.topic_thumbnails === true || data.topicThumbnails === true,
          playlists: data.playlists === true || data.playlist_thumbnails === true || data.playlistThumbnails === true,
          ads: data.ads === true || data.campaigns === true || data.adCampaigns === true || data.advertiser_campaigns === true,
        };
      }
      return DEFAULT_MODERATION_MODES;
    }

    const data = snap.data() || {};
    return {
      videos: data.videos === true,
      thumbnails: data.thumbnails === true || data.videos_thumbnails === true || data.videoThumbnails === true,
      channels: data.channels === true || data.channelDetails === true,
      avatar: data.avatar === true || data.channelAvatar === true || data.channel_avatar === true,
      banner: data.banner === true || data.channelBanner === true || data.channel_banner === true,
      community: data.community === true || data.community_posts === true || data.communityPosts === true,
      topics: data.topics === true || data.topic_thumbnails === true || data.topicThumbnails === true,
      playlists: data.playlists === true || data.playlist_thumbnails === true || data.playlistThumbnails === true,
      ads: data.ads === true || data.campaigns === true || data.adCampaigns === true || data.advertiser_campaigns === true,
    };
  } catch (err) {
    logger.warn("[getModerationModes] Failed to read moderation modes, defaulting to AI auto mode:", err);
    return DEFAULT_MODERATION_MODES;
  }
}

export async function isVideosBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.videos;
}

export async function isThumbnailsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.thumbnails;
}

export async function isChannelsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.channels;
}

export async function isAvatarBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.avatar;
}

export async function isBannerBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.banner;
}

export async function isCommunityBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.community;
}

export async function isTopicsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.topics;
}

export async function isPlaylistsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.playlists;
}

export async function isAdsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.ads;
}

export async function isCampaignsBypassed(): Promise<boolean> {
  return isAdsBypassed();
}

