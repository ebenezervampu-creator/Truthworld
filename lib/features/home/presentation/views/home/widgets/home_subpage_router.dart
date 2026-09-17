import 'package:flutter/material.dart';
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
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
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
          loader: trending.loadLibrary,
          builder: () => trending.TrendingVideosPage(isDashboard: true),
        );
      case HomeController.indexHistory:
        return DeferredWidget(
          loader: history.loadLibrary,
          builder: () => history.WatchHistory(isDashboard: true),
        );
      case HomeController.indexWatchLater:
        return DeferredWidget(
          loader: watchlater.loadLibrary,
          builder: () => watchlater.WatchLaterScreen(isDashboard: true),
        );
      case HomeController.indexYourVideos:
        return DeferredWidget(
          loader: my_videos.loadLibrary,
          builder: () => my_videos.MyVideos(isDashboard: true),
        );
      case HomeController.indexLikedVideos:
        return DeferredWidget(
          loader: liked_videos.loadLibrary,
          builder: () => liked_videos.LikedVideoScreen(isDashboard: true),
        );
      case HomeController.indexDownloads:
        return DeferredWidget(
          loader: downloads.loadLibrary,
          builder: () => downloads.DownloadsPage(isDashboard: true),
        );
      case HomeController.indexPlaylists:
        return DeferredWidget(
          loader: playlist.loadLibrary,
          builder: () => playlist.PlaylistScreen(isDashboard: true),
        );
      case HomeController.indexFollowingTopics:
        return DeferredWidget(
          loader: following_topics.loadLibrary,
          builder: () =>
              following_topics.FollowingTopicsPage(isDashboard: true),
        );
      case HomeController.indexClips:
        return DeferredWidget(
          loader: clips.loadLibrary,
          builder: () => clips.ClipsPage(isDashboard: true),
        );
      case HomeController.indexAbout:
        return DeferredWidget(
          loader: about.loadLibrary,
          builder: () => about.AboutPage(isDashboard: true),
        );
      case HomeController.indexPrivacy:
        return DeferredWidget(
          loader: privacy.loadLibrary,
          builder: () => privacy.PrivacyPolicyScreen(isDashboard: true),
        );
      case HomeController.indexTerms:
        return DeferredWidget(
          loader: terms.loadLibrary,
          builder: () => terms.TermsAndConditionsPage(isDashboard: true),
        );
      case HomeController.indexCommunityGuidelines:
        return DeferredWidget(
          loader: community_guidelines.loadLibrary,
          builder: () =>
              community_guidelines.CommunityGuidelinesPage(isDashboard: true),
        );
      case HomeController.indexSettings:
        return DeferredWidget(
          loader: settings.loadLibrary,
          builder: () => settings.SettingsScreen(isDashboard: true),
        );
      case HomeController.indexFeedback:
        return DeferredWidget(
          loader: feedback.loadLibrary,
          builder: () => feedback.SendFeedbackPage(isDashboard: true),
        );
      case HomeController.indexPlaylistDetail:
        final p = controller.selectedPlaylist.value;
        if (p == null) {
          return DeferredWidget(
            loader: playlist.loadLibrary,
            builder: () => playlist.PlaylistScreen(isDashboard: true),
          );
        }
        return DeferredWidget(
          loader: playlist_detail.loadLibrary,
          builder: () =>
              playlist_detail.PlaylistDetailScreen(key: ValueKey(p.id)),
        );
      case HomeController.indexChannelDetail:
        final c = controller.selectedChannelForDetail.value;
        if (c == null) {
          return DeferredWidget(
            loader: discover.loadLibrary,
            builder: () => discover.DiscoverChannelsPage(isDashboard: true),
          );
        }
        return DeferredWidget(
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
