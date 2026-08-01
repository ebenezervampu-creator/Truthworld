import 'package:get/get.dart';
import 'package:truthworld/features/community/presentation/controllers/community_controller.dart';

class CommunityBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CommunityController(), fenix: true);
  }
}
