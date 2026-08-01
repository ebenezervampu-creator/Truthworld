import 'package:get/get.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';

class WatchHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => WatchHistoryController(), fenix: true);
  }
}
