import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_dialog_controller.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as app_search;
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';

export 'package:truthworld/features/dashboard/presentation/bindings/dashboard_binding.dart';

/// Home feature binding (Session lifecycle: fenix = true)
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(MainController.new, fenix: true);
    Get.lazyPut<HomeController>(HomeController.new, fenix: true);
    Get.lazyPut<ChannelController>(ChannelController.new, fenix: true);
    Get.lazyPut<ChannelSubscriptionController>(
      ChannelSubscriptionController.new,
      fenix: true,
    );
    Get.lazyPut<PlaylistController>(PlaylistController.new, fenix: true);
    Get.lazyPut<PlaylistDialogController>(
      PlaylistDialogController.new,
      fenix: true,
    );
    MiniplayerBinding().dependencies();
  }
}

/// Video detail / player binding (Disposable lifecycle: fenix = false)
class VideoBinding extends Bindings {
  @override
  void dependencies() {
    MiniplayerBinding().dependencies();
    final videoId =
        (Get.arguments is Map ? (Get.arguments['video']?.id as String?) : null) ??
        (Get.arguments is Map ? (Get.arguments['videoId'] as String?) : null) ??
        (Get.arguments is Map ? (Get.arguments['targetVideoId'] as String?) : null) ??
        (Get.arguments is Map ? (Get.arguments['video_id'] as String?) : null) ??
        (Get.arguments is Map ? (Get.arguments['id'] as String?) : null) ??
        Get.parameters['v'] ??
        Get.parameters['videoId'] ??
        Get.parameters['id'];
    Get.lazyPut<VideoController>(() => VideoController(tag: videoId), tag: videoId);
    Get.lazyPut<ChannelController>(ChannelController.new, tag: videoId);
    Get.lazyPut<ChannelSubscriptionController>(
      ChannelSubscriptionController.new,
    );
    Get.lazyPut<PlaylistController>(PlaylistController.new, fenix: true);
    Get.lazyPut<PlaylistDialogController>(
      PlaylistDialogController.new,
      fenix: true,
    );
    Get.lazyPut<VideoPlaybackQueueService>(
      VideoPlaybackQueueService.new,
      fenix: true,
    );
  }
}

/// Search feature binding (Disposable lifecycle: fenix = false)
class SearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<app_search.SearchController>(app_search.SearchController.new);
  }
}

/// Channel detail feature binding (Disposable lifecycle: fenix = false)
class ChannelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChannelController>(ChannelController.new);
    Get.lazyPut<ChannelSubscriptionController>(
      ChannelSubscriptionController.new,
    );
  }
}

/// Playlist feature binding (Disposable lifecycle: fenix = false)
class PlaylistBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlaylistController>(PlaylistController.new, fenix: true);
    Get.lazyPut<PlaylistDetailController>(PlaylistDetailController.new);
    Get.lazyPut<PlaylistDialogController>(PlaylistDialogController.new);
  }
}

/// Feedback feature binding (Disposable lifecycle: fenix = false)
class FeedbackBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SendFeedbackController>(SendFeedbackController.new);
  }
}

/// Admin feature binding (Session lifecycle: fenix = true)
class AdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminController>(AdminController.new, fenix: true);
  }
}

