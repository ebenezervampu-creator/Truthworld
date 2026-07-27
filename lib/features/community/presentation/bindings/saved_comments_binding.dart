import 'package:get/get.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';

class SavedCommentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SavedCommentsController>(SavedCommentsController.new);
  }
}
