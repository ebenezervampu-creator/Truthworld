import 'package:get/get.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';

class NotificationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserNotificationController>(UserNotificationController.new);
    Get.lazyPut<VideoFeedNotificationController>(VideoFeedNotificationController.new);
  }
}
