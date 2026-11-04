import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart'
    deferred as trash_restore;
import 'package:truthworld/features/library/presentation/bindings/library_binding.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart';
import 'package:truthworld/features/likedvideos/presentation/bindings/liked_videos_binding.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart'
    deferred as liked_video;
import 'package:truthworld/features/notifications/presentation/bindings/notifications_binding.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';
import 'package:truthworld/features/onboarding/presentation/bindings/onboarding_profile_binding.dart';
import 'package:truthworld/features/onboarding/presentation/views/onboarding_profile_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart'
    deferred as playlist_screen;
import 'package:truthworld/features/settings/presentation/bindings/edit_profile_binding.dart';
import 'package:truthworld/features/settings/presentation/bindings/settings_binding.dart';
import 'package:truthworld/features/settings/presentation/views/settings/edit_profile_screen.dart';
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;
import 'package:truthworld/features/watchhistory/presentation/bindings/watch_history_binding.dart';
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as history;
import 'package:truthworld/features/watchlater/presentation/bindings/watchlater_binding.dart';
import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// User library, watch history, liked videos, watch later, playlists, and settings routes.
class UserLibraryRoutes {
  UserLibraryRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.library,
      page: () => const LibraryScreen(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      binding: LibraryBinding(),
    ),
    GetPage(
      name: AppRoutes.history,
      page: () => DeferredWidget(
        loader: history.loadLibrary,
        builder: () => history.WatchHistory(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: WatchHistoryBinding(),
    ),
    GetPage(
      name: AppRoutes.likedVideos,
      page: () => DeferredWidget(
        loader: liked_video.loadLibrary,
        builder: () => liked_video.LikedVideoScreen(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: LikedVideosBinding(),
    ),
    GetPage(
      name: AppRoutes.watchLater,
      page: () => const WatchLaterScreen(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: WatchLaterBinding(),
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.playlistScreen,
      page: () => DeferredWidget(
        loader: playlist_screen.loadLibrary,
        builder: () => playlist_screen.PlaylistScreen(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: AppRoutes.playlistWithId,
      page: () => const PlaylistDetailScreen(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: AppRoutes.playlistDetail,
      page: () => const PlaylistDetailScreen(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingProfileScreen(),
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: OnboardingProfileBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => DeferredWidget(
        loader: settings.loadLibrary,
        builder: () => settings.SettingsScreen(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [AuthGuard()],
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileScreen(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [AuthGuard()],
      binding: EditProfileBinding(),
    ),
    GetPage(
      name: AppRoutes.trash,
      page: () {
        final args = Get.arguments;
        final isConsumer = args is! Map || args['isConsumer'] != false;
        final channelId = args is Map && args['channelId'] is String
            ? args['channelId'] as String
            : '';
        return DeferredWidget(
          loader: trash_restore.loadLibrary,
          builder: () => trash_restore.TrashRestoreScreen(
            channelId: channelId,
            isConsumer: isConsumer,
            isDarkMode: Get.isDarkMode,
            showBackButton: true,
          ),
        );
      },
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.notifications,
      page: VideoFeedNotificationScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: NotificationsBinding(),
    ),
  ];
}
