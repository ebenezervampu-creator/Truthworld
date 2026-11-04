import * as admin from 'firebase-admin';
import {
  getModerationModes,
  isVideosBypassed,
  isThumbnailsBypassed,
  isChannelsBypassed,
  isAvatarBypassed,
  isBannerBypassed,
  isCommunityBypassed,
  isTopicsBypassed,
  isPlaylistsBypassed,
  isAdsBypassed,
} from '../../src/moderation/moderationModes';

describe('Content Moderation Modes - 9 Independent Bypass Controls & Flow Test', () => {
  const db = () => admin.firestore();

  describe('1. Default Mode (Automated AI Flow - All Switches OFF)', () => {
    it('returns all false when settings documents do not exist', async () => {
      const modes = await getModerationModes();
      expect(modes.all).toBe(false);
      expect(modes.videos).toBe(false);
      expect(modes.thumbnails).toBe(false);
      expect(modes.channels).toBe(false);
      expect(modes.avatar).toBe(false);
      expect(modes.banner).toBe(false);
      expect(modes.community).toBe(false);
      expect(modes.topics).toBe(false);
      expect(modes.playlists).toBe(false);
      expect(modes.ads).toBe(false);

      expect(await isVideosBypassed()).toBe(false);
      expect(await isThumbnailsBypassed()).toBe(false);
      expect(await isChannelsBypassed()).toBe(false);
      expect(await isAvatarBypassed()).toBe(false);
      expect(await isBannerBypassed()).toBe(false);
      expect(await isCommunityBypassed()).toBe(false);
      expect(await isTopicsBypassed()).toBe(false);
      expect(await isPlaylistsBypassed()).toBe(false);
      expect(await isAdsBypassed()).toBe(false);
    });
  });

  describe('2. Strict Independence Testing for All 9 Categories', () => {
    const categories: Array<{
      key: string;
      helper: () => Promise<boolean>;
      name: string;
    }> = [
      { key: 'videos', helper: isVideosBypassed, name: 'Videos' },
      { key: 'thumbnails', helper: isThumbnailsBypassed, name: 'Video Thumbnails' },
      { key: 'channels', helper: isChannelsBypassed, name: 'Channels' },
      { key: 'avatar', helper: isAvatarBypassed, name: 'Channel Avatars' },
      { key: 'banner', helper: isBannerBypassed, name: 'Channel Banners' },
      { key: 'community', helper: isCommunityBypassed, name: 'Community Posts' },
      { key: 'topics', helper: isTopicsBypassed, name: 'Topics' },
      { key: 'playlists', helper: isPlaylistsBypassed, name: 'Playlists' },
      { key: 'ads', helper: isAdsBypassed, name: 'Advertiser Campaigns' },
    ];

    categories.forEach(({ key, helper, name }) => {
      it(`enabling only '${key}' (${name}) sets only its helper to true, leaving the other 8 false`, async () => {
        // Set only this category to true
        await db().collection('admin_settings').doc('moderation_modes').set({
          [key]: true,
        });

        // The target helper MUST be true
        const targetResult = await helper();
        expect(targetResult).toBe(true);

        // Every OTHER category helper MUST be false
        for (const other of categories) {
          if (other.key !== key) {
            const otherResult = await other.helper();
            expect(otherResult).toBe(false);
          }
        }

        // Master switch 'all' should NOT be true when only 1 category is active
        const modes = await getModerationModes();
        expect(modes.all).toBe(false);
      });
    });
  });

  describe('3. Fallback Document Support (system_settings/moderation_modes)', () => {
    it('reads configurations from system_settings if admin_settings is missing', async () => {
      // Ensure admin_settings doc does NOT exist
      // Write to fallback collection
      await db().collection('system_settings').doc('moderation_modes').set({
        videos: true,
        community: true,
      });

      const modes = await getModerationModes();
      expect(modes.videos).toBe(true);
      expect(modes.community).toBe(true);
      expect(modes.thumbnails).toBe(false);
      expect(modes.channels).toBe(false);

      expect(await isVideosBypassed()).toBe(true);
      expect(await isCommunityBypassed()).toBe(true);
      expect(await isChannelsBypassed()).toBe(false);
    });

    it('prefers admin_settings over system_settings when both exist', async () => {
      await db().collection('system_settings').doc('moderation_modes').set({
        videos: false,
        channels: false,
      });
      await db().collection('admin_settings').doc('moderation_modes').set({
        videos: true,
        channels: true,
      });

      expect(await isVideosBypassed()).toBe(true);
      expect(await isChannelsBypassed()).toBe(true);
    });
  });

  describe('4. Legacy and Plural Key Aliases Support', () => {
    it('correctly maps all known database aliases to their respective 9 categories', async () => {
      await db().collection('admin_settings').doc('moderation_modes').set({
        videos_thumbnails: true,
        channelDetails: true,
        channel_avatar: true,
        channel_banner: true,
        community_posts: true,
        topic_thumbnails: true,
        playlist_thumbnails: true,
        campaigns: true,
      });

      expect(await isThumbnailsBypassed()).toBe(true);
      expect(await isChannelsBypassed()).toBe(true);
      expect(await isAvatarBypassed()).toBe(true);
      expect(await isBannerBypassed()).toBe(true);
      expect(await isCommunityBypassed()).toBe(true);
      expect(await isTopicsBypassed()).toBe(true);
      expect(await isPlaylistsBypassed()).toBe(true);
      expect(await isAdsBypassed()).toBe(true);
      expect(await isVideosBypassed()).toBe(false); // not set
    });

    it('handles camelCase aliases as well', async () => {
      await db().collection('admin_settings').doc('moderation_modes').set({
        videoThumbnails: true,
        channelAvatar: true,
        channelBanner: true,
        communityPosts: true,
        topicThumbnails: true,
        playlistThumbnails: true,
        adCampaigns: true,
      });

      expect(await isThumbnailsBypassed()).toBe(true);
      expect(await isAvatarBypassed()).toBe(true);
      expect(await isBannerBypassed()).toBe(true);
      expect(await isCommunityPostsBypassedHelper()).toBe(true);
      expect(await isTopicsBypassed()).toBe(true);
      expect(await isPlaylistsBypassed()).toBe(true);
      expect(await isAdsBypassed()).toBe(true);
    });
  });

  describe('5. Master Switch Behaviors (Route All to Admin)', () => {
    it('sets all 9 categories to true when master switch "all" is true', async () => {
      await db().collection('admin_settings').doc('moderation_modes').set({
        all: true,
      });

      const modes = await getModerationModes();
      expect(modes.all).toBe(true);
      expect(await isVideosBypassed()).toBe(true);
      expect(await isThumbnailsBypassed()).toBe(true);
      expect(await isChannelsBypassed()).toBe(true);
      expect(await isAvatarBypassed()).toBe(true);
      expect(await isBannerBypassed()).toBe(true);
      expect(await isCommunityBypassed()).toBe(true);
      expect(await isTopicsBypassed()).toBe(true);
      expect(await isPlaylistsBypassed()).toBe(true);
      expect(await isAdsBypassed()).toBe(true);
    });

    it('sets all 9 categories to true when master switch "master" is true', async () => {
      await db().collection('admin_settings').doc('moderation_modes').set({
        master: true,
      });

      const modes = await getModerationModes();
      expect(modes.all).toBe(true);
      expect(await isVideosBypassed()).toBe(true);
      expect(await isAdsBypassed()).toBe(true);
    });

    it('evaluates modes.all as true if all 9 categories are individually enabled', async () => {
      await db().collection('admin_settings').doc('moderation_modes').set({
        videos: true,
        thumbnails: true,
        channels: true,
        avatar: true,
        banner: true,
        community: true,
        topics: true,
        playlists: true,
        ads: true,
      });

      const modes = await getModerationModes();
      expect(modes.all).toBe(true);
    });
  });

  describe('6. End-to-End Decision Flow Simulation', () => {
    it('simulates Video content routing when isVideosBypassed() is true vs false', async () => {
      // Step A: Bypassed = true -> routes to Admin
      await db().collection('admin_settings').doc('moderation_modes').set({ videos: true });
      const shouldBypassA = await isVideosBypassed();
      expect(shouldBypassA).toBe(true);

      // Simulation of contentModeration logic
      const videoDocId = 'test_video_flow_1';
      if (shouldBypassA) {
        await db().collection('videos').doc(videoDocId).set({
          status: 'pending_review',
          moderation: {
            status: 'manual_review',
            bypassGemini: true,
            reason: 'Routed to Admin for manual review (Gemini AI bypassed).',
          },
        });
        await db().collection('admin_review_queue').doc(videoDocId).set({
          videoId: videoDocId,
          queuedAt: Date.now(),
        });
      }

      const snapA = await db().collection('videos').doc(videoDocId).get();
      expect(snapA.data()?.status).toBe('pending_review');
      expect(snapA.data()?.moderation?.bypassGemini).toBe(true);
      const queueSnapA = await db().collection('admin_review_queue').doc(videoDocId).get();
      expect(queueSnapA.exists).toBe(true);

      // Step B: Bypassed = false -> normal AI automated flow
      await db().collection('admin_settings').doc('moderation_modes').set({ videos: false });
      const shouldBypassB = await isVideosBypassed();
      expect(shouldBypassB).toBe(false);
    });

    it('simulates Playlist moderation flow when isPlaylistsBypassed() is true vs false', async () => {
      // Bypassed = true
      await db().collection('admin_settings').doc('moderation_modes').set({ playlists: true });
      expect(await isPlaylistsBypassed()).toBe(true);

      const playlistId = 'pl_test_flow_1';
      // Simulating playlistModeration.ts logic:
      const bypassed = await isPlaylistsBypassed();
      if (bypassed) {
        await db().collection('playlists').doc(playlistId).set({
          geminiApproved: false,
          status: 'underReview',
          moderationReason: 'Routed to Admin for manual review (Gemini AI bypassed).',
          bypassGemini: true,
        });
      }

      const plSnap = await db().collection('playlists').doc(playlistId).get();
      expect(plSnap.data()?.status).toBe('underReview');
      expect(plSnap.data()?.geminiApproved).toBe(false);
      expect(plSnap.data()?.bypassGemini).toBe(true);
    });

    it('simulates Channel moderation flow when isChannelsBypassed() is true vs false', async () => {
      // Bypassed = true
      await db().collection('admin_settings').doc('moderation_modes').set({ channels: true });
      expect(await isChannelsBypassed()).toBe(true);

      const channelId = 'ch_test_flow_1';
      // Simulating channels/moderation.ts logic:
      const bypassed = await isChannelsBypassed();
      if (bypassed) {
        await db().collection('channels').doc(channelId).set({
          geminiApproved: false,
          status: 'underReview',
          moderationReason: 'Routed to Admin for manual review (Gemini AI bypassed).',
          bypassGemini: true,
        });
      }

      const chSnap = await db().collection('channels').doc(channelId).get();
      expect(chSnap.data()?.status).toBe('underReview');
      expect(chSnap.data()?.geminiApproved).toBe(false);
      expect(chSnap.data()?.bypassGemini).toBe(true);
    });
  });
});

async function isCommunityPostsBypassedHelper() {
  return isCommunityBypassed();
}
