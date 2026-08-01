import 'package:get/get.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';

class PremiumBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(PremiumController.new, fenix: true);
  }
}
