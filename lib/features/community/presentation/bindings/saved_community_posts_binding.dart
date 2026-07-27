import 'package:get/get.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_community_posts_controller.dart';

class SavedCommunityPostsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SavedCommunityPostsController>(SavedCommunityPostsController.new);
  }
}
