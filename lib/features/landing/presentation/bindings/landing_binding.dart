import 'package:get/get.dart';
import 'package:truthworld/features/landing/presentation/controllers/landing_controller.dart';

class LandingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LandingController(), fenix: true);
  }
}
