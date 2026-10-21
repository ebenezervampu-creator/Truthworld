import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/category/presentation/bindings/category_binding.dart';
import 'package:truthworld/features/category/presentation/views/category/category_page.dart';
import 'package:truthworld/features/trending/presentation/bindings/trending_binding.dart';
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart';
import 'package:truthworld/features/video/presentation/views/claim_detail_screen.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
import 'package:truthworld/features/video/presentation/views/video_screen.dart'
    deferred as video_screen;
import 'package:truthworld/routes/app_routes.dart';

/// Video playback, feeds, and discovery routes.
class VideoRoutes {
  VideoRoutes._();

  static Widget _buildVideoPlayerScreen() {
    final video = Get.arguments?['video'];
    final videoId = video?.id ??
        (Get.arguments is Map ? (Get.arguments['videoId'] as String?) : null) ??
        (Get.arguments is Map
            ? (Get.arguments['targetVideoId'] as String?)
            : null) ??
        (Get.arguments is Map
            ? (Get.arguments['video_id'] as String?)
            : null) ??
        Get.parameters['v'] ??
        Get.parameters['videoId'] ??
        Get.parameters['id'];
    return DeferredWidget(
      loader: video_screen.loadLibrary,
      builder: () => video_screen.VideoScreen(videoTag: videoId as String?),
    );
  }

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.videoscreen,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard(), VideoScreenRedirectMiddleware()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.watch,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.watchWithId,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.videoShortLink,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.shorts,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.videoAlias,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.category,
      page: CategoryPage.new,
      middlewares: [ConsumerRouteGuard()],
      binding: CategoryBinding(),
    ),
    GetPage(
      name: AppRoutes.browse,
      page: CategoryPage.new,
      middlewares: [ConsumerRouteGuard()],
      binding: CategoryBinding(),
    ),
    GetPage(
      name: AppRoutes.trending,
      page: TrendingVideosPage.new,
      middlewares: [ConsumerRouteGuard()],
      binding: TrendingBinding(),
    ),
    GetPage(
      name: AppRoutes.clips,
      page: () => const ClipsPage(),
      middlewares: [ConsumerRouteGuard()],
      binding: BindingsBuilder(() {
        Get.lazyPut<UserClipsController>(UserClipsController.new);
      }),
    ),
    GetPage(
      name: AppRoutes.downloads,
      page: () => DeferredWidget(
        loader: downloads.loadLibrary,
        builder: () => downloads.DownloadsPage(),
      ),
      middlewares: [ConsumerRouteGuard()],
    ),
    GetPage(
      name: AppRoutes.videoAnalysis,
      page: VideoAnalysisScreen.new,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.analysis,
      page: VideoAnalysisScreen.new,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.claimDetail,
      page: ClaimDetailScreen.new,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.claim,
      page: ClaimDetailScreen.new,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.claimDetailScreen,
      page: ClaimDetailScreen.new,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
  ];
}
