import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

/// Binding for the Settings feature.
class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(UserSettingsController.new);
  }
}
