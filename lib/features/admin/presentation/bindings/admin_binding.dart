import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';

/// Binding for the Admin panel feature.
///
/// Registers the admin controller lazily — only instantiated
/// when the admin route is navigated to.
class AdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(AdminController.new);
  }
}
