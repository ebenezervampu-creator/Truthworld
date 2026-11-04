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
import 'package:truthworld/features/video/presentation/views/ask_ai_screen.dart';
import 'package:truthworld/features/video/presentation/views/claim_detail_screen.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
import 'package:truthworld/features/video/presentation/views/video_description_screen.dart';
import 'package:truthworld/features/video/presentation/views/video_screen.dart'
    deferred as video_screen;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

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
      opaque: false,
      transition: AppTransitions.mediaZoom,
      transitionDuration: AppTransitions.mediaZoomDuration,
      curve: AppTransitions.mediaZoomCurve,
      middlewares: [ConsumerRouteGuard(), VideoScreenRedirectMiddleware()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.watch,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      opaque: false,
      transition: AppTransitions.mediaZoom,
      transitionDuration: AppTransitions.mediaZoomDuration,
      curve: AppTransitions.mediaZoomCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.watchWithId,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      opaque: false,
      transition: AppTransitions.mediaZoom,
      transitionDuration: AppTransitions.mediaZoomDuration,
      curve: AppTransitions.mediaZoomCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.videoShortLink,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      opaque: false,
      transition: AppTransitions.mediaZoom,
      transitionDuration: AppTransitions.mediaZoomDuration,
      curve: AppTransitions.mediaZoomCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.shorts,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      transition: AppTransitions.verticalFeed,
      transitionDuration: AppTransitions.verticalFeedDuration,
      curve: AppTransitions.verticalFeedCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.videoAlias,
      page: _buildVideoPlayerScreen,
      preventDuplicates: false,
      opaque: false,
      transition: AppTransitions.mediaZoom,
      transitionDuration: AppTransitions.mediaZoomDuration,
      curve: AppTransitions.mediaZoomCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.category,
      page: CategoryPage.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: CategoryBinding(),
    ),
    GetPage(
      name: AppRoutes.browse,
      page: CategoryPage.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: CategoryBinding(),
    ),
    GetPage(
      name: AppRoutes.trending,
      page: TrendingVideosPage.new,
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: TrendingBinding(),
    ),
    GetPage(
      name: AppRoutes.clips,
      page: () => const ClipsPage(),
      transition: AppTransitions.verticalFeed,
      transitionDuration: AppTransitions.verticalFeedDuration,
      curve: AppTransitions.verticalFeedCurve,
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
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
    ),
    GetPage(
      name: AppRoutes.videoAnalysis,
      page: VideoAnalysisScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.videoDescription,
      page: VideoDescriptionScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.analysis,
      page: VideoAnalysisScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.askAi,
      page: AskAiScreen.new,
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.aiChat,
      page: AskAiScreen.new,
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.claimDetail,
      page: ClaimDetailScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.claim,
      page: ClaimDetailScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
    GetPage(
      name: AppRoutes.claimDetailScreen,
      page: ClaimDetailScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: VideoBinding(),
    ),
  ];
}
