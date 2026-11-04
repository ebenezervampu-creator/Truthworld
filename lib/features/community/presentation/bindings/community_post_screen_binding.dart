import 'package:get/get.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_screen_controller.dart';

/// Bindings for dedicated Community Post screen.
class CommunityPostScreenBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommunityPostScreenController>(
      CommunityPostScreenController.new,
    );
  }
}
