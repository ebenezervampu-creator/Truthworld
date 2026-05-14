import 'package:get/get.dart';
import 'package:truthworld/features/splash/presentation/controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // This will create your SplashController (with all the animation
    // and auth logic) when the /splash route is called.
    Get.lazyPut<SplashController>(() => SplashController());
  }
}





