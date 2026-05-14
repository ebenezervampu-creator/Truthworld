import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/firestore_service.dart';
import 'package:truthworld/core/services/storage_service.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/features/presentation/views/network/network_listener.dart';
import 'package:truthworld/core/services/seo_listener.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Global binding for app-wide services and controllers
/// This should be used as the initial binding for the entire app
class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    // ========================================================================
    // SERVICES - Already initialized via GetxInitializer
    // But register them here for explicit dependency management
    // ========================================================================

    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }

    if (!Get.isRegistered<FirestoreService>()) {
      Get.put<FirestoreService>(FirestoreService());
    }

    if (!Get.isRegistered<StorageService>()) {
      Get.put<StorageService>(StorageService());
    }

    if (!Get.isRegistered<AppService>()) {
      Get.put<AppService>(AppService());
    }

    // ========================================================================
    // GLOBAL CONTROLLERS
    // ========================================================================

    // Network Status Controller - monitors network connectivity
    Get.lazyPut<NetworkStatusController>(
      () => NetworkStatusController(),
      fenix: true,
    );

    // SEO Route Listener - for web SEO purposes
    Get.lazyPut<SeoRouteListener>(() => SeoRouteListener(), fenix: true);

    // Home Controller - required for the home page
    if (!Get.isRegistered<HomeController>()) {
      Get.lazyPut<HomeController>(() => HomeController());
    }
  }
}
