import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';

class TopicsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TopicController(), fenix: true);
  }
}
