import 'package:get/get.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/firestore_service.dart';
import 'package:truthworld/core/services/storage_service.dart';

/// GetX Dependency Injection Setup
/// Initialize all services at app startup
class GetxInitializer {
  /// Initialize all GetX services
  static Future<void> initializeServices() async {
    // Initialize services in order of dependency

    /// App Service (no dependencies)
    await Get.putAsync<AppService>(() async => AppService());

    /// Auth Service (no dependencies)
    await Get.putAsync<AuthService>(() async => AuthService());

    /// Firestore Service (depends on Auth Service)
    await Get.putAsync<FirestoreService>(() async => FirestoreService());

    /// Storage Service (no dependencies)
    await Get.putAsync<StorageService>(() async => StorageService());
  }

  /// Check if service is registered
  static bool isServiceRegistered<T>() {
    return Get.isRegistered<T>();
  }

  /// Get service instance
  static T getService<T>() {
    if (!Get.isRegistered<T>()) {
      throw Exception('Service ${T.runtimeType} is not registered');
    }
    return Get.find<T>();
  }

  /// Dispose all services
  static void disposeServices() {
    if (Get.isRegistered<AuthService>()) {
      Get.delete<AuthService>();
    }
    if (Get.isRegistered<FirestoreService>()) {
      Get.delete<FirestoreService>();
    }
    if (Get.isRegistered<StorageService>()) {
      Get.delete<StorageService>();
    }
    if (Get.isRegistered<AppService>()) {
      Get.delete<AppService>();
    }
  }
}





