import 'package:get/get.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';

class TrendingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TrendingController(), fenix: true);
  }
}
