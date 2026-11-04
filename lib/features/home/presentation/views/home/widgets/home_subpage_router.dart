import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart'
    deferred as about;
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart'
    deferred as channel_details;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart'
    deferred as community_guidelines;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart'
    deferred as privacy;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart'
    deferred as terms;
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart'
    deferred as discover;
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart'
    deferred as feedback;
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart'
    deferred as liked_videos;
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart'
    deferred as playlist_detail;
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart'
    deferred as playlist;
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart'
    deferred as trending;
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart'
    deferred as clips;
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as history;
import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart'
    deferred as watchlater;

/// Maps HomeController subpage selection to lazy deferred page builders.
class HomeSubPageRouter {
  const HomeSubPageRouter._();

  static Widget buildSubPage(
    BuildContext context,
    HomeController controller,
    int index,
  ) {
    switch (index) {
      case HomeController.indexTrending:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_trending'),
          loader: trending.loadLibrary,
          builder: () => trending.TrendingVideosPage(isDashboard: true),
        );
      case HomeController.indexHistory:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_history'),
          loader: history.loadLibrary,
          builder: () => history.WatchHistory(isDashboard: true),
        );
      case HomeController.indexWatchLater:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_watch_later'),
          loader: watchlater.loadLibrary,
          builder: () => watchlater.WatchLaterScreen(isDashboard: true),
        );
      case HomeController.indexYourVideos:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_my_videos'),
          loader: my_videos.loadLibrary,
          builder: () => my_videos.MyVideos(isDashboard: true),
        );
      case HomeController.indexLikedVideos:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_liked_videos'),
          loader: liked_videos.loadLibrary,
          builder: () => liked_videos.LikedVideoScreen(isDashboard: true),
        );
      case HomeController.indexDownloads:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.sideNavSelectedIndex.value ==
              HomeController.indexDownloads) {
            controller.sideNavSelectedIndex.value =
                HomeController.indexLibrary;
            AppNavigator.toDownloads();
          }
        });
        return const SizedBox.shrink();
      case HomeController.indexPlaylists:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_playlists'),
          loader: playlist.loadLibrary,
          builder: () => playlist.PlaylistScreen(isDashboard: true),
        );
      case HomeController.indexFollowingTopics:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_following_topics'),
          loader: following_topics.loadLibrary,
          builder: () =>
              following_topics.FollowingTopicsPage(isDashboard: true),
        );
      case HomeController.indexClips:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_clips'),
          loader: clips.loadLibrary,
          builder: () => clips.ClipsPage(isDashboard: true),
        );
      case HomeController.indexAbout:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_about'),
          loader: about.loadLibrary,
          builder: () => about.AboutPage(isDashboard: true),
        );
      case HomeController.indexPrivacy:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_privacy'),
          loader: privacy.loadLibrary,
          builder: () => privacy.PrivacyPolicyScreen(isDashboard: true),
        );
      case HomeController.indexTerms:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_terms'),
          loader: terms.loadLibrary,
          builder: () => terms.TermsAndConditionsPage(isDashboard: true),
        );
      case HomeController.indexCommunityGuidelines:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_community_guidelines'),
          loader: community_guidelines.loadLibrary,
          builder: () =>
              community_guidelines.CommunityGuidelinesPage(isDashboard: true),
        );
      case HomeController.indexSettings:
        final isAuth = Get.isRegistered<AuthService>() &&
            AuthService.to.isAuthenticated.value;
        if (!isAuth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.sideNavSelectedIndex.value ==
                HomeController.indexSettings) {
              controller.sideNavSelectedIndex.value = HomeController.indexHome;
              controller.showSignInSnackbar();
            }
          });
          return const SizedBox.shrink();
        }
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_settings'),
          loader: settings.loadLibrary,
          builder: () => settings.SettingsScreen(isDashboard: true),
        );
      case HomeController.indexFeedback:
        return DeferredWidget(
          key: const ValueKey('subpage_deferred_feedback'),
          loader: feedback.loadLibrary,
          builder: () => feedback.SendFeedbackPage(isDashboard: true),
        );
      case HomeController.indexPlaylistDetail:
        final p = controller.selectedPlaylist.value;
        if (p == null) {
          return DeferredWidget(
            key: const ValueKey('subpage_deferred_playlist_fallback'),
            loader: playlist.loadLibrary,
            builder: () => playlist.PlaylistScreen(isDashboard: true),
          );
        }
        return DeferredWidget(
          key: ValueKey('subpage_deferred_playlist_${p.id}'),
          loader: playlist_detail.loadLibrary,
          builder: () =>
              playlist_detail.PlaylistDetailScreen(
                key: ValueKey(p.id),
                playlist: p,
              ),
        );
      case HomeController.indexChannelDetail:
        final c = controller.selectedChannelForDetail.value;
        if (c == null) {
          return DeferredWidget(
            key: const ValueKey('subpage_deferred_channel_fallback'),
            loader: discover.loadLibrary,
            builder: () => discover.DiscoverChannelsPage(isDashboard: true),
          );
        }
        return DeferredWidget(
          key: ValueKey('subpage_deferred_channel_${c.channelId}'),
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            key: ValueKey(c.channelId),
            channel: c,
            isDashboard: true,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
