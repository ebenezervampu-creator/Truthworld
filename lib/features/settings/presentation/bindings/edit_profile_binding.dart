import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/edit_profile_controller.dart';

/// Binding for the Edit Profile Details screen.
class EditProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(EditProfileController.new);
  }
}
