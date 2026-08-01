import 'package:get/get.dart';
import 'package:truthworld/features/likedvideos/presentation/controllers/likedvideos_controller.dart';

class LikedVideosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LikedVideosController(), fenix: true);
  }
}
