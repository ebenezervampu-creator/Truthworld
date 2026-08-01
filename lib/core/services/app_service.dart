import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Global application service for managing persistent settings and app-wide state.
/// This service is permanent and shared across all features.
class AppService extends GetxService {
  final _storage = GetStorage();

  // Persistent settings
  final RxBool isDarkMode = true.obs;
  final RxString languageCode = 'en'.obs;
  final RxBool hasFinishedOnboarding = false.obs;

  Future<AppService> init() async {
    // Load initial values from persistent storage
    isDarkMode.value = _storage.read('isDarkMode') ?? true;
    languageCode.value = _storage.read('languageCode') ?? 'en';
    hasFinishedOnboarding.value =
        _storage.read('hasFinishedOnboarding') ?? false;

    // Listen for changes and persist them
    ever(isDarkMode, (val) => _storage.write('isDarkMode', val));
    ever(languageCode, (val) => _storage.write('languageCode', val));
    ever(
      hasFinishedOnboarding,
      (val) => _storage.write('hasFinishedOnboarding', val),
    );

    return this;
  }

  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  void setOnboardingComplete() {
    hasFinishedOnboarding.value = true;
  }
}
