import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';

import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/feedback/presentation/controllers/feedback_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';

/// Main presentation layer binding
/// Initializes all controllers for main features
class MainPresentationBinding extends Bindings {
  @override
  void dependencies() {
    // Home
    Get.lazyPut<HomeController>(() => HomeController());

    // Channel
    Get.lazyPut<ChannelController>(() => ChannelController());

    // Main Controller
    Get.lazyPut<MainController>(() => MainController());

    // Watch History
    Get.lazyPut<WatchHistoryController>(() => WatchHistoryController());

    // Playlist
    Get.lazyPut<PlaylistController>(() => PlaylistController());
    Get.lazyPut<PlaylistDetailController>(() => PlaylistDetailController());

    // Feedback
    Get.lazyPut<FeedbackController>(() => FeedbackController());

    // Subscription
    Get.lazyPut<SubscriptionController>(() => SubscriptionController());
  }
}





