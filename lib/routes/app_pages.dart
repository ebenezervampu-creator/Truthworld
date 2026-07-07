import 'package:get/get.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/help.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/features/home/presentation/views/home/home_binding.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart' deferred as liked_video;
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart' deferred as my_videos;
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_loader_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart' deferred as playlist_screen;
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/search/presentation/pages/search_page.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as app;

import 'package:truthworld/features/category/presentation/views/category/category_page.dart';
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart' deferred as channel_details;
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channelloader_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart' deferred as dashboard;
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart';
import 'package:truthworld/features/subscriptions/presentation/views/Subscriptions/subscriptions.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/upload_screen.dart' deferred as upload;
import 'package:truthworld/features/video/presentation/views/video_screen.dart' deferred as video_screen;
import 'package:truthworld/features/video/presentation/views/videoloader_screen.dart';
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart' deferred as history;
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';
import 'package:truthworld/features/watchtime/presentation/pages/watchtime_details_page.dart';
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/topics/presentation/pages/saved_topics_page.dart' deferred as saved_topics;
// import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart';

import 'package:truthworld/core/utils/route_redirect_middleware.dart';

class AppPages {
  static final routes = [
    GetPage(name: "/", page: () => Home(), binding: HomeBinding()),
    GetPage(
      name: "/studio",
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/home",
      page: () => Home(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: "/channelscreen",
      page: () => ChannelScreen(),
      middlewares: [ChannelCreationGuard()],
    ),
    GetPage(
      name: "/dashboard",
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/history",
      page: () => DeferredWidget(
        loader: history.loadLibrary,
        builder: () => history.WatchHistory(),
      ),
    ),
    GetPage(
      name: "/likedvideos",
      page: () => DeferredWidget(
        loader: liked_video.loadLibrary,
        builder: () => liked_video.LikedVideoScreen(),
      ),
    ),
    GetPage(
      name: "/playlistscreen",
      page: () => DeferredWidget(
        loader: playlist_screen.loadLibrary,
        builder: () => playlist_screen.PlaylistScreen(),
      ),
    ),
    GetPage(
      name: "/saved-topics",
      page: () => DeferredWidget(
        loader: saved_topics.loadLibrary,
        builder: () => saved_topics.SavedTopicsPage(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/myvideos",
      page: () => DeferredWidget(
        loader: my_videos.loadLibrary,
        builder: () => my_videos.MyVideos(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/channel-details",
      page: () => DeferredWidget(
        loader: channel_details.loadLibrary,
        builder: () => channel_details.ChannelDetailsPage(),
      ),
      middlewares: [ChannelDetailsRedirectMiddleware()],
    ),
    GetPage(
      name: "/videoscreen",
      page: () {
        final video = Get.arguments?['video'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () => video_screen.VideoScreen(videoTag: video?.id),
        );
      },
      preventDuplicates: false,
      middlewares: [VideoScreenRedirectMiddleware()],
      binding: BindingsBuilder(() {
        final video = Get.arguments?['video'];
        final videoId = video?.id;
        MiniplayerBinding().dependencies();
        Get.put<VideoController>(VideoController(), tag: videoId);
        Get.put<ChannelController>(ChannelController(), tag: videoId);
      }),
    ),
    GetPage(
      name: "/watch",
      page: () {
        final video = Get.arguments?['video'];
        if (video != null) {
          return DeferredWidget(
            loader: video_screen.loadLibrary,
            builder: () => video_screen.VideoScreen(videoTag: video.id),
          );
        } else {
          return VideoLoaderScreen();
        }
      },
      preventDuplicates: false,
      binding: BindingsBuilder(() {
        final video = Get.arguments?['video'];
        final videoId = video?.id ?? Get.parameters['v'] ?? Get.parameters['videoId'];
        MiniplayerBinding().dependencies();
        Get.put<VideoController>(VideoController(), tag: videoId);
        Get.put<ChannelController>(ChannelController(), tag: videoId);
      }),
    ),
    GetPage(
      name: "/uploadscreen",
      page: () => DeferredWidget(
        loader: upload.loadLibrary,
        builder: () => upload.EnhancedUploadScreen(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(name: '/library', page: () => const LibraryScreen()),
    GetPage(
      name: '/watch/:videoId',
      page: () => VideoLoaderScreen(),
    ),
    GetPage(
      name: '/playlist/:playlistId',
      page: () => PlaylistLoaderScreen(),
    ),
    GetPage(
      name: '/playlist-detail',
      page: () => const PlaylistDetailScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PlaylistDetailController>(() => PlaylistDetailController());
      }),
    ),
    GetPage(
      name: '/channel/:channelId',
      page: () {
        final channel = Get.arguments?['channel'];
        if (channel != null) {
          return DeferredWidget(
            loader: channel_details.loadLibrary,
            builder: () => channel_details.ChannelDetailsPage(channel: channel),
          );
        } else {
          return ChannelLoaderScreen();
        }
      },
      binding: BindingsBuilder(() {
        Get.lazyPut<ChannelController>(() => ChannelController());
      }),
    ),
    GetPage(
      name: "/category",
      page: () => CategoryPage(),
    ),
    GetPage(
      name: "/topic/:slug",
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
    ),
    GetPage(
      name: "/T/:slug",
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
    ),
    GetPage(
      name: "/settings",
      page: () => SettingsScreen(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/feedback',
      page: () => const SendFeedbackPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => SendFeedbackController());
      }),
    ),
    GetPage(
      name: "/help",
      page: () => HelpPage(),
    ),
    GetPage(
      name: "/notifications",
      page: () => VideoFeedNotificationScreen(),
    ),
    GetPage(
      name: "/downloads",
      page: () => DownloadsPage(),
    ),
    GetPage(
      name: "/privacy",
      page: () => PrivacyPolicyScreen(),
    ),
    GetPage(
      name: "/terms",
      page: () => TermsAndConditionsPage(),
    ),
    GetPage(
      name: "/community-guidelines",
      page: () => const CommunityGuidelinesPage(),
    ),
    GetPage(
      name: "/subscriptions",
      page: () => SubscriptionsPage(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/about",
      page: () => const AboutPage(),
    ),
    GetPage(
      name: "/search",
      page: () => const SearchPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => app.SearchController());
      }),
    ),
    GetPage(
      name: "/watchtimedetails",
      page: () => WatchtimeDetailsPage(
        channelId: '',
        isDarkMode: false,
      ), // channelId and isDarkMode should be set dynamically
    ),
    GetPage(
      name: "/trending",
      page: () => TrendingVideosPage(),
    ),
    GetPage(
      name: "/browse",
      page: () => CategoryPage(),
    ),
    GetPage(
      name: "/clips",
      page: () => const ClipsPage(),
    ),
    GetPage(
      name: '/:handle',
      page: () {
        final channel = Get.arguments?['channel'];
        if (channel != null) {
          return DeferredWidget(
            loader: channel_details.loadLibrary,
            builder: () => channel_details.ChannelDetailsPage(channel: channel),
          );
        } else {
          return ChannelLoaderScreen();
        }
      },
      binding: BindingsBuilder(() {
        Get.lazyPut<ChannelController>(() => ChannelController());
      }),
    ),
  ];
}
