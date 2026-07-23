import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';

class CommunityPostUploadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommunityPostUploadController>(
      CommunityPostUploadController.new,
    );
  }
}
