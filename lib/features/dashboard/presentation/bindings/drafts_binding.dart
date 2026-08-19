import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';

/// Binding for Creator Studio Drafts feature.
class DraftsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DraftsController>(DraftsController.new, fenix: true);
  }
}
