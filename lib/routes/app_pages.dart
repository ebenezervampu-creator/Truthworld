import 'package:get/get.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
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
// import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart';

class AppPages {
  static final routes = [
    GetPage(name: "/", page: () => Home(), binding: HomeBinding()),
    GetPage(
      name: "/studio",
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/home",
      page: () => Home(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      binding: HomeBinding(),
    ),
    GetPage(
      name: "/channelscreen",
      page: () => ChannelScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/dashboard",
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: Transition.zoom,
      transitionDuration: const Duration(milliseconds: 300),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/history",
      page: () => DeferredWidget(
        loader: history.loadLibrary,
        builder: () => history.WatchHistory(),
      ),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/likedvideos",
      page: () => DeferredWidget(
        loader: liked_video.loadLibrary,
        builder: () => liked_video.LikedVideoScreen(),
      ),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/playlistscreen",
      page: () => DeferredWidget(
        loader: playlist_screen.loadLibrary,
        builder: () => playlist_screen.PlaylistScreen(),
      ),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/myvideos",
      page: () => DeferredWidget(
        loader: my_videos.loadLibrary,
        builder: () => my_videos.MyVideos(),
      ),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/channel-details",
      page: () => DeferredWidget(
        loader: channel_details.loadLibrary,
        builder: () => channel_details.ChannelDetailsPage(),
      ),
      transition: Transition.zoom,
      transitionDuration: const Duration(milliseconds: 300),
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
      transition: Transition.zoom,
      transitionDuration: const Duration(milliseconds: 300),
      preventDuplicates: false,
      binding: BindingsBuilder(() {
        final video = Get.arguments?['video'];
        final videoId = video?.id;
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
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      middlewares: [AuthGuard()],
    ),
    GetPage(name: '/library', page: () => const LibraryScreen()),
    GetPage(
      name: '/watch/:videoId',
      page: () => VideoLoaderScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: '/playlist/:playlistId',
      page: () => PlaylistLoaderScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: '/playlist-detail',
      page: () => const PlaylistDetailScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<PlaylistDetailController>(() => PlaylistDetailController());
      }),
    ),
    GetPage(
      name: '/channel/:channelId',
      page: () => ChannelLoaderScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<ChannelController>(() => ChannelController());
      }),
    ),
    GetPage(
      name: "/category",
      page: () => CategoryPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/topic/:slug",
      page: () => const TopicPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/settings",
      page: () => SettingsScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/feedback',
      page: () => const SendFeedbackPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => SendFeedbackController());
      }),
    ),
    GetPage(
      name: "/help",
      page: () => HelpPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/notifications",
      page: () => VideoFeedNotificationScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/downloads",
      page: () => DownloadsPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/privacy",
      page: () => PrivacyPolicyScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/terms",
      page: () => TermsAndConditionsPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/subscriptions",
      page: () => SubscriptionsPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: "/about",
      page: () => const AboutPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/search",
      page: () => const SearchPage(),
      transition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 400),
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
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/trending",
      page: () => TrendingVideosPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/browse",
      page: () => CategoryPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: "/clips",
      page: () => const ClipsPage(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 500),
    ),
  ];
}





