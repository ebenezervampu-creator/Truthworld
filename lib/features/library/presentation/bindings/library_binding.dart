import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/library/presentation/controllers/library_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';

class LibraryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(LibraryController.new, fenix: true);
    if (!Get.isRegistered<HomeController>()) {
      Get.lazyPut(HomeController.new, fenix: true);
    }
    if (!Get.isRegistered<PlaylistController>()) {
      Get.lazyPut(PlaylistController.new, fenix: true);
    }
    if (!Get.isRegistered<WatchHistoryController>()) {
      Get.lazyPut(WatchHistoryController.new, fenix: true);
    }
  }
}
