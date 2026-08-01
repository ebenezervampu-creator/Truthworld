import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(HomeController.new);
    if (!Get.isRegistered<VideoFeedNotificationController>()) {
      Get.put(VideoFeedNotificationController());
    }
  }
}
