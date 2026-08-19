import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

export interface ModerationModes {
  videos: boolean;       // true = bypass Gemini, route video to Admin only; false = send to Gemini
  thumbnails: boolean;   // true = bypass Gemini/AI, route thumbnail to Admin only; false = send to Gemini
  channels: boolean;     // true = bypass Gemini, route channel details to Admin only; false = send to Gemini
  avatar: boolean;       // true = bypass Gemini/AI, route avatar to Admin only; false = send to Gemini
  banner: boolean;       // true = bypass Gemini/AI, route banner to Admin only; false = send to Gemini
  topics: boolean;       // true = bypass Gemini, route topics to Admin only; false = send to Gemini
}

const DEFAULT_MODERATION_MODES: ModerationModes = {
  videos: false,
  thumbnails: false,
  channels: false,
  avatar: false,
  banner: false,
  topics: false,
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
          thumbnails: data.thumbnails === true || data.videos_thumbnails === true,
          channels: data.channels === true || data.channelDetails === true,
          avatar: data.avatar === true || data.channelAvatar === true,
          banner: data.banner === true || data.channelBanner === true,
          topics: data.topics === true,
        };
      }
      return DEFAULT_MODERATION_MODES;
    }

    const data = snap.data() || {};
    return {
      videos: data.videos === true,
      thumbnails: data.thumbnails === true || data.videos_thumbnails === true,
      channels: data.channels === true || data.channelDetails === true,
      avatar: data.avatar === true || data.channelAvatar === true,
      banner: data.banner === true || data.channelBanner === true,
      topics: data.topics === true,
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

export async function isTopicsBypassed(): Promise<boolean> {
  const modes = await getModerationModes();
  return modes.topics;
}
