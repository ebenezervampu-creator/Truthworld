import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
// import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart';

import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import 'package:truthworld/features/admin/presentation/views/admin_dashboard_screen.dart'
    deferred as admin_dashboard;
import 'package:truthworld/features/admin/presentation/views/admin_login_screen.dart'
    deferred as admin_login;
import 'package:truthworld/features/advertiser/presentation/views/advertiser_portal_screen.dart'
    deferred as advertiser_portal;
import 'package:truthworld/features/category/presentation/views/category/category_page.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart'
    deferred as channel_details;
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channelloader_screen.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_comments_binding.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_community_posts_binding.dart';
import 'package:truthworld/features/community/presentation/views/saved_comments_screen.dart';
import 'package:truthworld/features/community/presentation/views/saved_community_posts_screen.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart'
    deferred as dashboard;
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/help.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart'
    deferred as liked_video;
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_loader_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart'
    deferred as playlist_screen;
import 'package:truthworld/features/premium/presentation/views/premium_plans_screen.dart'
    deferred as premium_plans;
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as app;
import 'package:truthworld/features/search/presentation/pages/search_page.dart';
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;
import 'package:truthworld/features/subscriptions/presentation/views/Subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
import 'package:truthworld/features/video/presentation/views/upload/create_content_screen.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/upload_selection_screen.dart';
import 'package:truthworld/features/video/presentation/views/video_screen.dart'
    deferred as video_screen;
import 'package:truthworld/features/video/presentation/views/videoloader_screen.dart';
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as history;
import 'package:truthworld/features/watchtime/presentation/pages/watchtime_details_page.dart';

class AppPages {
  static final List<GetPage> routes = [
    GetPage(
      name: '/',
      page: () {
        if (kIsWeb) {
          final host = Uri.base.host.toLowerCase();
          if (host.startsWith('admin') ||
              Uri.base.queryParameters.containsKey('admin')) {
            return DeferredWidget(
              loader: admin_dashboard.loadLibrary,
              builder: () => admin_dashboard.AdminDashboardScreen(),
            );
          }
          if (host.startsWith('studio') ||
              Uri.base.queryParameters.containsKey('studio')) {
            return DeferredWidget(
              loader: dashboard.loadLibrary,
              builder: () => dashboard.DashboardScreen(),
            );
          }
        }
        return const Home();
      },
      binding: HomeBinding(),
    ),
    GetPage(
      name: '/studio',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/home',
      page: Home.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: '/channelscreen',
      page: ChannelScreen.new,
      middlewares: [ChannelCreationGuard()],
    ),
    GetPage(
      name: '/dashboard',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/history',
      page: () => DeferredWidget(
        loader: history.loadLibrary,
        builder: () => history.WatchHistory(),
      ),
    ),
    GetPage(
      name: '/likedvideos',
      page: () => DeferredWidget(
        loader: liked_video.loadLibrary,
        builder: () => liked_video.LikedVideoScreen(),
      ),
    ),
    GetPage(
      name: '/playlistscreen',
      page: () => DeferredWidget(
        loader: playlist_screen.loadLibrary,
        builder: () => playlist_screen.PlaylistScreen(),
      ),
    ),
    GetPage(
      name: '/following-topics',
      page: () => DeferredWidget(
        loader: following_topics.loadLibrary,
        builder: () => following_topics.FollowingTopicsPage(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/myvideos',
      page: () => DeferredWidget(
        loader: my_videos.loadLibrary,
        builder: () => my_videos.MyVideos(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/channel-details',
      page: () => DeferredWidget(
        loader: channel_details.loadLibrary,
        builder: () => channel_details.ChannelDetailsPage(),
      ),
      middlewares: [ChannelDetailsRedirectMiddleware()],
    ),
    GetPage(
      name: '/videoscreen',
      page: () {
        final video = Get.arguments?['video'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: video?.id as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [VideoScreenRedirectMiddleware()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/watch',
      page: () {
        final video = Get.arguments?['video'];
        if (video != null) {
          return DeferredWidget(
            loader: video_screen.loadLibrary,
            builder: () =>
                video_screen.VideoScreen(videoTag: video.id as String?),
          );
        } else {
          return const VideoLoaderScreen();
        }
      },
      preventDuplicates: false,
      binding: VideoBinding(),
    ),
    // New upload routes with deep link support
    GetPage(
      name: '/upload',
      page: () => const UploadSelectionScreen(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/video',
      page: () => const CreateContentScreen(
        uploadType: UploadType.video,
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/community',
      page: () => const CreateContentScreen(
        uploadType: UploadType.communityPost,
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/create-post',
      page: () => const CreateContentScreen(
        uploadType: UploadType.communityPost,
      ),
      middlewares: [AuthGuard()],
    ),
    // Backward compatibility - redirect old route to selection screen
    GetPage(
      name: '/uploadscreen',
      page: () => const UploadSelectionScreen(),
      middlewares: [AuthGuard()],
    ),
    GetPage(name: '/library', page: () => const LibraryScreen()),
    GetPage(
      name: '/premium',
      page: () => DeferredWidget(
        loader: premium_plans.loadLibrary,
        builder: () => premium_plans.PremiumPlansScreen(),
      ),
    ),
    GetPage(
      name: '/saved-community-posts',
      page: () => const SavedCommunityPostsScreen(),
      binding: SavedCommunityPostsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/saved-comments',
      page: () => const SavedCommentsScreen(),
      binding: SavedCommentsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/watch/:videoId',
      page: VideoLoaderScreen.new,
    ),
    GetPage(
      name: '/playlist/:playlistId',
      page: PlaylistLoaderScreen.new,
    ),
    GetPage(
      name: '/post/:postId',
      page: Home.new,
    ),
    GetPage(
      name: '/community/:postId',
      page: Home.new,
    ),
    GetPage(
      name: '/playlist-detail',
      page: () => const PlaylistDetailScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PlaylistDetailController>(PlaylistDetailController.new);
      }),
    ),
    GetPage(
      name: '/channel/:channelId',
      page: () {
        final channel = Get.arguments?['channel'];
        if (channel != null) {
          return DeferredWidget(
            loader: channel_details.loadLibrary,
            builder: () => channel_details.ChannelDetailsPage(
              channel: channel as Channel?,
            ),
          );
        } else {
          return const ChannelLoaderScreen();
        }
      },
      binding: BindingsBuilder(() {
        Get.lazyPut<ChannelController>(ChannelController.new);
      }),
    ),
    GetPage(
      name: '/category',
      page: CategoryPage.new,
    ),
    GetPage(
      name: '/topic/:slug',
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
    ),
    GetPage(
      name: '/T/:slug',
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
    ),
    GetPage(
      name: '/settings',
      page: () => DeferredWidget(
        loader: settings.loadLibrary,
        builder: () => settings.SettingsScreen(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/feedback',
      page: () => const SendFeedbackPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(SendFeedbackController.new);
      }),
    ),
    GetPage(
      name: '/help',
      page: HelpPage.new,
    ),
    GetPage(
      name: '/notifications',
      page: VideoFeedNotificationScreen.new,
    ),
    GetPage(
      name: '/downloads',
      page: () => DeferredWidget(
        loader: downloads.loadLibrary,
        builder: () => downloads.DownloadsPage(),
      ),
    ),
    GetPage(
      name: '/privacy',
      page: PrivacyPolicyScreen.new,
    ),
    GetPage(
      name: '/terms',
      page: TermsAndConditionsPage.new,
    ),
    GetPage(
      name: '/community-guidelines',
      page: () => const CommunityGuidelinesPage(),
    ),
    GetPage(
      name: '/subscriptions',
      page: () => DeferredWidget(
        loader: subscriptions.loadLibrary,
        builder: () => subscriptions.SubscriptionsPage(),
      ),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/about',
      page: () => const AboutPage(),
    ),
    GetPage(
      name: '/search',
      page: () => const SearchPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(app.SearchController.new);
      }),
    ),
    GetPage(
      name: '/watchtimedetails',
      page: () => const WatchtimeDetailsPage(
        channelId: '',
        isDarkMode: false,
      ), // channelId and isDarkMode should be set dynamically
    ),
    GetPage(
      name: '/trending',
      page: TrendingVideosPage.new,
    ),
    GetPage(
      name: '/browse',
      page: CategoryPage.new,
    ),
    GetPage(
      name: '/clips',
      page: () => const ClipsPage(),
    ),
    GetPage(
      name: '/admin',
      page: () => DeferredWidget(
        loader: admin_login.loadLibrary,
        builder: () => admin_login.AdminLoginScreen(),
      ),
    ),
    GetPage(
      name: '/admin/login',
      page: () => DeferredWidget(
        loader: admin_login.loadLibrary,
        builder: () => admin_login.AdminLoginScreen(),
      ),
    ),
    GetPage(
      name: '/admin/dashboard',
      page: () => DeferredWidget(
        loader: admin_dashboard.loadLibrary,
        builder: () => admin_dashboard.AdminDashboardScreen(),
      ),
    ),
    GetPage(
      name: '/advertiser',
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: '/advertisements',
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: '/ads',
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: '/:handle',
      page: () {
        final channel = Get.arguments?['channel'];
        if (channel != null) {
          return DeferredWidget(
            loader: channel_details.loadLibrary,
            builder: () => channel_details.ChannelDetailsPage(
              channel: channel as Channel?,
            ),
          );
        } else {
          return const ChannelLoaderScreen();
        }
      },
      binding: BindingsBuilder(() {
        Get.lazyPut<ChannelController>(ChannelController.new);
      }),
    ),
  ];
}
