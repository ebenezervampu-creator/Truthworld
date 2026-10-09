import 'package:get/get.dart';
import 'package:truthworld/features/onboarding/presentation/controllers/onboarding_profile_controller.dart';

class OnboardingProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OnboardingProfileController>(
      OnboardingProfileController.new,
    );
  }
}
