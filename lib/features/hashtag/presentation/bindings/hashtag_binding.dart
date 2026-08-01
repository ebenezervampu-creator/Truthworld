import 'package:get/get.dart';
import 'package:truthworld/features/hashtag/presentation/controllers/hashtag_controller.dart';

class HashtagBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HashtagController(), fenix: true);
  }
}
