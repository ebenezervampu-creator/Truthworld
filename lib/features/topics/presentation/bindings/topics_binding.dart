import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';

class TopicsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(TopicController.new, fenix: true);
    Get.lazyPut(ExploreTopicsController.new, fenix: true);
    Get.lazyPut(FollowingTopicsController.new, fenix: true);
    Get.lazyPut(CreateTopicController.new, fenix: true);
    Get.lazyPut(TopicManagementController.new, fenix: true);
  }
}
