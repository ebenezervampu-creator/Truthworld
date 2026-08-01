import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';

class TopicsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(TopicController.new, fenix: true);
    Get.lazyPut(ExploreTopicsController.new, fenix: true);
    Get.lazyPut(FollowingTopicsController.new, fenix: true);
  }
}
