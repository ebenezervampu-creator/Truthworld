import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/admin_dashboard_screen.dart'
    deferred as admin_dashboard;
import 'package:truthworld/features/admin/presentation/views/admin_login_screen.dart'
    deferred as admin_login;
import 'package:truthworld/features/advertiser/presentation/bindings/advertiser_binding.dart';
import 'package:truthworld/features/advertiser/presentation/views/advertiser_portal_screen.dart'
    deferred as advertiser_portal;
import 'package:truthworld/features/analytics/presentation/bindings/analytics_binding.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/category/presentation/bindings/category_binding.dart';
import 'package:truthworld/features/category/presentation/views/category/category_page.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart'
    deferred as channel_details;
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/community/community_post_upload_binding.dart';
import 'package:truthworld/features/community/community_post_upload_screen.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_comments_binding.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_community_posts_binding.dart';
import 'package:truthworld/features/community/presentation/views/saved_comments_screen.dart';
import 'package:truthworld/features/community/presentation/views/saved_community_posts_screen.dart';
import 'package:truthworld/features/content/presentation/bindings/copyright_complaint_binding.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/copyright_complaint_screen.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart'
    deferred as dashboard;
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart'
    deferred as discover;
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/features/library/presentation/bindings/library_binding.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart';
import 'package:truthworld/features/likedvideos/presentation/bindings/liked_videos_binding.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart'
    deferred as liked_video;
import 'package:truthworld/features/myvideos/presentation/bindings/my_videos_binding.dart';
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/notifications/presentation/bindings/notifications_binding.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart'
    deferred as playlist_screen;
import 'package:truthworld/features/premium/presentation/bindings/premium_binding.dart';
import 'package:truthworld/features/premium/presentation/views/premium_plans_screen.dart'
    deferred as premium_plans;
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as app;
import 'package:truthworld/features/search/presentation/pages/search_page.dart';
import 'package:truthworld/features/settings/presentation/bindings/edit_profile_binding.dart';
import 'package:truthworld/features/settings/presentation/bindings/settings_binding.dart';
import 'package:truthworld/features/settings/presentation/views/settings/edit_profile_screen.dart';
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;
import 'package:truthworld/features/subscriptions/presentation/bindings/subscriptions_binding.dart';
import 'package:truthworld/features/subscriptions/presentation/views/Subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/topics/presentation/bindings/topics_binding.dart';
import 'package:truthworld/features/topics/presentation/pages/create_topic_screen.dart';
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/features/trending/presentation/bindings/trending_binding.dart';
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart';
import 'package:truthworld/features/video/presentation/bindings/video_feature_binding.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
import 'package:truthworld/features/video/presentation/views/upload/create_content_screen.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/upload_selection_screen.dart';
import 'package:truthworld/features/video/presentation/views/video_screen.dart'
    deferred as video_screen;
import 'package:truthworld/features/watchhistory/presentation/bindings/watch_history_binding.dart';
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as history;
import 'package:truthworld/features/watchlater/presentation/bindings/watchlater_binding.dart';
import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart';
import 'package:truthworld/features/watchtime/presentation/pages/watchtime_details_page.dart';

class AppPages {
  static final List<GetPage> routes = [
    GetPage(
      name: '/',
      page: () {
        if (AppFlavor.isStudio) {
          return DeferredWidget(
            loader: dashboard.loadLibrary,
            builder: () => dashboard.DashboardScreen(),
          );
        }
        if (AppFlavor.isAdmin) {
          final user = FirebaseAuth.instance.currentUser;
          final email = user?.email?.toLowerCase();
          final isOwner = email != null && (
            email == 'hello@truthworld.in' ||
            email == 'ebenezervampu4@gmail.com' ||
            email == 'admin@truthworld.com'
          );
          final hasAdminClaim = isOwner || (Get.isRegistered<AdminController>() && Get.find<AdminController>().isAdmin.value);
          if (hasAdminClaim) {
            return DeferredWidget(
              loader: admin_dashboard.loadLibrary,
              builder: () => admin_dashboard.AdminDashboardScreen(),
            );
          }
          return DeferredWidget(
            loader: admin_login.loadLibrary,
            builder: () => admin_login.AdminLoginScreen(),
          );
        }
        if (AppFlavor.isAdvertiser) {
          return DeferredWidget(
            loader: advertiser_portal.loadLibrary,
            builder: () => advertiser_portal.AdvertiserPortalScreen(),
          );
        }
        if (kIsWeb) {
          final host = Uri.base.host.toLowerCase();
          if (host.startsWith('admin') || host.contains('admin.truthworld.in')) {
            final user = FirebaseAuth.instance.currentUser;
            final email = user?.email?.toLowerCase();
            final isOwner = email != null && (
              email == 'hello@truthworld.in' ||
              email == 'ebenezervampu4@gmail.com' ||
              email == 'admin@truthworld.com'
            );
            final hasAdminClaim = isOwner || (Get.isRegistered<AdminController>() && Get.find<AdminController>().isAdmin.value);
            if (hasAdminClaim) {
              return DeferredWidget(
                loader: admin_dashboard.loadLibrary,
                builder: () => admin_dashboard.AdminDashboardScreen(),
              );
            }
            return DeferredWidget(
              loader: admin_login.loadLibrary,
              builder: () => admin_login.AdminLoginScreen(),
            );
          }
          if (host.startsWith('studio') ||
              host.contains('studio.truthworld.in')) {
            return DeferredWidget(
              loader: dashboard.loadLibrary,
              builder: () => dashboard.DashboardScreen(),
            );
          }
        }
        return const Home();
      },
      binding: BindingsBuilder(() {
        if (AppFlavor.isStudio) {
          DashboardBinding().dependencies();
          return;
        }
        if (AppFlavor.isAdmin) {
          AdminBinding().dependencies();
          return;
        }
        if (AppFlavor.isAdvertiser) {
          AdvertiserBinding().dependencies();
          return;
        }
        if (kIsWeb) {
          final host = Uri.base.host.toLowerCase();
          if (host.startsWith('admin') || host.contains('admin.truthworld.in')) {
            AdminBinding().dependencies();
            return;
          }
          if (host.startsWith('studio') ||
              host.contains('studio.truthworld.in')) {
            DashboardBinding().dependencies();
            return;
          }
        }
        HomeBinding().dependencies();
      }),
    ),
    GetPage(
      name: '/studio',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/studio/chapters',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/studio/trash',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/studio/drafts',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/home',
      page: () {
        if (AppFlavor.isStudio) {
          return DeferredWidget(
            loader: dashboard.loadLibrary,
            builder: () => dashboard.DashboardScreen(),
          );
        }
        return const Home();
      },
      middlewares: [HomeRedirectMiddleware()],
      binding: BindingsBuilder(() {
        if (AppFlavor.isStudio) {
          DashboardBinding().dependencies();
          return;
        }
        HomeBinding().dependencies();
      }),
    ),
    GetPage(
      name: '/channelscreen',
      page: ChannelScreen.new,
      middlewares: [ChannelCreationGuard()],
      binding: ChannelBinding(),
    ),
    GetPage(
      name: '/dashboard',
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [DashboardRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/history',
      page: () => DeferredWidget(
        loader: history.loadLibrary,
        builder: () => history.WatchHistory(),
      ),
      middlewares: [ConsumerRouteGuard()],
      binding: WatchHistoryBinding(),
    ),
    GetPage(
      name: '/likedvideos',
      page: () => DeferredWidget(
        loader: liked_video.loadLibrary,
        builder: () => liked_video.LikedVideoScreen(),
      ),
      middlewares: [ConsumerRouteGuard()],
      binding: LikedVideosBinding(),
    ),
    GetPage(
      name: '/watchlater',
      page: () => const WatchLaterScreen(),
      binding: WatchLaterBinding(),
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
    ),
    GetPage(
      name: '/playlistscreen',
      page: () => DeferredWidget(
        loader: playlist_screen.loadLibrary,
        builder: () => playlist_screen.PlaylistScreen(),
      ),
      middlewares: [ConsumerRouteGuard()],
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: '/following-topics',
      page: () => DeferredWidget(
        loader: following_topics.loadLibrary,
        builder: () => following_topics.FollowingTopicsPage(),
      ),
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: '/explore-topics',
      page: () => DeferredWidget(
        loader: explore_topics.loadLibrary,
        builder: () => explore_topics.ExploreTopicsPage(),
      ),
      middlewares: [ConsumerRouteGuard()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: '/myvideos',
      page: () => DeferredWidget(
        loader: my_videos.loadLibrary,
        builder: () => my_videos.MyVideos(),
      ),
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: MyVideosBinding(),
    ),
    GetPage(
      name: '/channel-details',
      page: () => DeferredWidget(
        loader: channel_details.loadLibrary,
        builder: () => channel_details.ChannelDetailsPage(),
      ),
      middlewares: [ConsumerRouteGuard(), ChannelDetailsRedirectMiddleware()],
      binding: ChannelBinding(),
    ),
    GetPage(
      name: '/videoscreen',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            (Get.arguments is Map ? (Get.arguments['videoId'] as String?) : null) ??
            (Get.arguments is Map ? (Get.arguments['targetVideoId'] as String?) : null) ??
            (Get.arguments is Map ? (Get.arguments['video_id'] as String?) : null) ??
            Get.parameters['v'] ??
            Get.parameters['videoId'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard(), VideoScreenRedirectMiddleware()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/watch',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            (Get.arguments is Map ? (Get.arguments['videoId'] as String?) : null) ??
            (Get.arguments is Map ? (Get.arguments['targetVideoId'] as String?) : null) ??
            (Get.arguments is Map ? (Get.arguments['video_id'] as String?) : null) ??
            Get.parameters['v'] ??
            Get.parameters['videoId'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/watch/:videoId',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            Get.parameters['videoId'] ??
            Get.parameters['v'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/v/:videoId',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            Get.parameters['videoId'] ??
            Get.parameters['v'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/shorts/:videoId',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            Get.parameters['videoId'] ??
            Get.parameters['v'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/video/:videoId',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            Get.parameters['videoId'] ??
            Get.parameters['v'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/v/:videoId',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            Get.parameters['videoId'] ??
            Get.parameters['v'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: '/shorts/:videoId',
      page: () {
        final video = Get.arguments?['video'];
        final videoId = video?.id ??
            Get.parameters['videoId'] ??
            Get.parameters['v'] ??
            Get.parameters['id'];
        return DeferredWidget(
          loader: video_screen.loadLibrary,
          builder: () =>
              video_screen.VideoScreen(videoTag: videoId as String?),
        );
      },
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    // New upload routes with deep link support
    GetPage(
      name: '/upload',
      page: () => const UploadSelectionScreen(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/video',
      page: () => const CreateContentScreen(
        uploadType: UploadType.video,
      ),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/subtitles',
      page: () => const UploadSubtitlesPage(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/dubbing',
      page: () => const UploadDubbingPage(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/community',
      page: () => const CommunityPostUploadScreen(),
      binding: CommunityPostUploadBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/create-post',
      page: () => const CommunityPostUploadScreen(),
      binding: CommunityPostUploadBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/create-playlist',
      page: () => const CreatePlaylistScreen(),
      binding: PlaylistBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/playlist',
      page: () => const CreatePlaylistScreen(),
      binding: PlaylistBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/create-topic',
      page: () => const CreateTopicScreen(),
      binding: TopicsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/upload/topic',
      page: () => const CreateTopicScreen(),
      binding: TopicsBinding(),
      middlewares: [AuthGuard()],
    ),
    // Backward compatibility - redirect old route to selection screen
    GetPage(
      name: '/uploadscreen',
      page: () => const UploadSelectionScreen(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: '/library',
      page: () => const LibraryScreen(),
      binding: LibraryBinding(),
    ),
    GetPage(
      name: '/premium',
      page: () => DeferredWidget(
        loader: premium_plans.loadLibrary,
        builder: () => premium_plans.PremiumPlansScreen(),
      ),
      binding: PremiumBinding(),
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
      name: '/playlist/:playlistId',
      page: () => const PlaylistDetailScreen(),
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: '/post/:postId',
      page: Home.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: '/community/:postId',
      page: Home.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: '/playlist-detail',
      page: () => const PlaylistDetailScreen(),
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: '/channel/:channelId',
      page: () {
        final channel = Get.arguments?['channel'];
        return DeferredWidget(
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            channel: channel as Channel?,
          ),
        );
      },
      binding: ChannelBinding(),
    ),
    GetPage(
      name: '/@:handle',
      page: () {
        final channel = Get.arguments?['channel'];
        return DeferredWidget(
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            channel: channel as Channel?,
          ),
        );
      },
      binding: ChannelBinding(),
    ),
    GetPage(
      name: '/category',
      page: CategoryPage.new,
      middlewares: [ConsumerRouteGuard()],
      binding: CategoryBinding(),
    ),
    GetPage(
      name: '/topic/:slug',
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: '/topics/:slug',
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: '/T/:slug',
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: '/t/:slug',
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: '/settings',
      page: () => DeferredWidget(
        loader: settings.loadLibrary,
        builder: () => settings.SettingsScreen(),
      ),
      middlewares: [AuthGuard()],
      binding: SettingsBinding(),
    ),
    GetPage(
      name: '/settings/edit-profile',
      page: () => const EditProfileScreen(),
      middlewares: [AuthGuard()],
      binding: EditProfileBinding(),
    ),
    GetPage(
      name: '/user-wallet',
      page: () => const SizedBox.shrink(),
      middlewares: [AuthGuard(), WalletRedirectMiddleware()],
    ),
    GetPage(
      name: '/wallet',
      page: () => const SizedBox.shrink(),
      middlewares: [AuthGuard(), WalletRedirectMiddleware()],
    ),
    GetPage(
      name: '/feedback',
      page: () => const SendFeedbackPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(SendFeedbackController.new);
      }),
    ),
    GetPage(
      name: '/notifications',
      page: VideoFeedNotificationScreen.new,
      binding: NotificationsBinding(),
    ),
    GetPage(
      name: '/downloads',
      page: () => DeferredWidget(
        loader: downloads.loadLibrary,
        builder: () => downloads.DownloadsPage(),
      ),
      middlewares: [ConsumerRouteGuard()],
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
      page: CommunityGuidelinesPage.new,
    ),
    GetPage(
      name: '/copyright-complaint',
      page: CopyrightComplaintScreen.new,
      binding: CopyrightComplaintBinding(),
    ),
    GetPage(
      name: '/dmca',
      page: CopyrightComplaintScreen.new,
      binding: CopyrightComplaintBinding(),
    ),
    GetPage(
      name: '/subscriptions',
      page: () => DeferredWidget(
        loader: subscriptions.loadLibrary,
        builder: () => subscriptions.SubscriptionsPage(),
      ),
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: SubscriptionsBinding(),
    ),
    GetPage(
      name: '/discover',
      page: () => DeferredWidget(
        loader: discover.loadLibrary,
        builder: () => discover.DiscoverChannelsPage(),
      ),
      middlewares: [ConsumerRouteGuard()],
    ),
    GetPage(
      name: '/explore-topics',
      page: () => DeferredWidget(
        loader: explore_topics.loadLibrary,
        builder: () => explore_topics.ExploreTopicsPage(),
      ),
      middlewares: [ConsumerRouteGuard()],
    ),
    GetPage(
      name: '/about',
      page: () => const AboutPage(),
    ),
    GetPage(
      name: '/search',
      page: () => const SearchPage(),
      middlewares: [ConsumerRouteGuard()],
      binding: BindingsBuilder(() {
        Get.lazyPut(app.SearchController.new);
      }),
    ),
    GetPage(
      name: '/watchtimedetails',
      page: () {
        final channelId = Get.parameters['channelId'] ??
            Get.parameters['id'] ??
            (Get.arguments is Map ? Get.arguments['channelId'] as String? : null) ??
            '';
        return WatchtimeDetailsPage(
          channelId: channelId,
          isDarkMode: Get.isDarkMode,
        );
      },
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: '/WatchTimePage',
      page: () => const WatchTimePage(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: '/watchtime',
      page: () => const WatchTimePage(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: '/views',
      page: () => const ViewsPage(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: '/subscribers',
      page: () => const SubscribersPage(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: '/analytics',
      page: () => const CreatorAnalyticsDashboard(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: '/trending',
      page: TrendingVideosPage.new,
      middlewares: [ConsumerRouteGuard()],
      binding: TrendingBinding(),
    ),
    GetPage(
      name: '/browse',
      page: CategoryPage.new,
      middlewares: [ConsumerRouteGuard()],
      binding: CategoryBinding(),
    ),
    GetPage(
      name: '/clips',
      page: () => const ClipsPage(),
      middlewares: [ConsumerRouteGuard()],
      binding: BindingsBuilder(() {
        Get.lazyPut<UserClipsController>(UserClipsController.new);
      }),
    ),
    GetPage(
      name: '/admin',
      binding: AdminBinding(),
      middlewares: [AdminRedirectMiddleware()],
      page: () => DeferredWidget(
        loader: admin_login.loadLibrary,
        builder: () => admin_login.AdminLoginScreen(),
      ),
    ),
    GetPage(
      name: '/admin/login',
      binding: AdminBinding(),
      middlewares: [AdminRedirectMiddleware()],
      page: () => DeferredWidget(
        loader: admin_login.loadLibrary,
        builder: () => admin_login.AdminLoginScreen(),
      ),
    ),
    GetPage(
      name: '/admin/dashboard',
      binding: AdminBinding(),
      middlewares: [AdminAuthGuardMiddleware()],
      page: () => DeferredWidget(
        loader: admin_dashboard.loadLibrary,
        builder: () => admin_dashboard.AdminDashboardScreen(),
      ),
    ),
    GetPage(
      name: '/advertiser',
      binding: AdvertiserBinding(),
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: '/advertisements',
      binding: AdvertiserBinding(),
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: '/ads',
      binding: AdvertiserBinding(),
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: '/:handle',
      page: () {
        final channel = Get.arguments?['channel'];
        return DeferredWidget(
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            channel: channel as Channel?,
          ),
        );
      },
      binding: ChannelBinding(),
    ),
  ];
}
