import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/features/community/community_post_upload_binding.dart';
import 'package:truthworld/features/community/community_post_upload_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/topics/presentation/bindings/topics_binding.dart';
import 'package:truthworld/features/topics/presentation/pages/create_topic_screen.dart';
import 'package:truthworld/features/video/presentation/bindings/video_feature_binding.dart';
import 'package:truthworld/features/video/presentation/views/upload/create_content_screen.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/upload_selection_screen.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Content creation, video uploading, subtitles, dubbing, and community creation routes.
class UploadRoutes {
  UploadRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.upload,
      page: () => const UploadSelectionScreen(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadVideo,
      page: () => const CreateContentScreen(
        uploadType: UploadType.video,
      ),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadSubtitles,
      page: () => const UploadSubtitlesPage(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadDubbing,
      page: () => const UploadDubbingPage(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadCommunity,
      page: () => const CommunityPostUploadScreen(),
      binding: CommunityPostUploadBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.createPost,
      page: () => const CommunityPostUploadScreen(),
      binding: CommunityPostUploadBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.createPlaylist,
      page: () => const CreatePlaylistScreen(),
      binding: PlaylistBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadPlaylist,
      page: () => const CreatePlaylistScreen(),
      binding: PlaylistBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.createTopic,
      page: () => const CreateTopicScreen(),
      binding: TopicsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadTopic,
      page: () => const CreateTopicScreen(),
      binding: TopicsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.uploadscreen,
      page: () => const UploadSelectionScreen(),
      binding: VideoFeatureBinding(),
      middlewares: [AuthGuard()],
    ),
  ];
}
