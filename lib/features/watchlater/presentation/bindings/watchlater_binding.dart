import 'package:get/get.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';

class WatchLaterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WatchLaterController>(WatchLaterController.new);
  }
}
