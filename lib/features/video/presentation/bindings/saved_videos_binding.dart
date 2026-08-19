import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/saved_videos_controller.dart';

class SavedVideosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SavedVideosController>(SavedVideosController.new, fenix: true);
  }
}
