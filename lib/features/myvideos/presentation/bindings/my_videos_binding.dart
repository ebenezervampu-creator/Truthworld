import 'package:get/get.dart';
import 'package:truthworld/features/myvideos/presentation/controllers/my_videos_controller.dart';

class MyVideosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(MyVideosController.new, fenix: true);
  }
}
