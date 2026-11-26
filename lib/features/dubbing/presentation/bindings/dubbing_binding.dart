import 'package:get/get.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';

/// Bindings injecting dependencies for TruthWorld Dubbing Studio.
class DubbingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DubbingStudioController>(DubbingStudioController.new);
  }
}
