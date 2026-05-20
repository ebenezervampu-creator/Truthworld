import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AppSettingsController extends GetxController {
  final _storage = GetStorage();

  // Dark Mode preference
  final isDarkMode = false.obs;

  // Language preference
  final selectedLanguage = 'English'.obs;

  // Privacy: Pause Watch History
  final pauseWatchHistory = false.obs;
  
  // Privacy: Pause Search History
  final pauseSearchHistory = false.obs;

  // Data Usage: Play on Wi-Fi only
  final wifiOnlyPlayback = false.obs;

  // Data Usage: Autoplay next video
  final autoplayNext = true.obs;

  // Default Download Quality preference
  final downloadQuality = 'Auto (720p)'.obs;

  @override
  void onInit() {
    super.onInit();
    // Load persisted settings
    isDarkMode.value = _storage.read<bool>('settings_dark_mode') ?? (Get.isPlatformDarkMode == true);
    selectedLanguage.value = _storage.read<String>('settings_language') ?? 'English';
    pauseWatchHistory.value = _storage.read<bool>('watch_history_paused') ?? false;
    pauseSearchHistory.value = _storage.read<bool>('search_history_paused') ?? false;
    wifiOnlyPlayback.value = _storage.read<bool>('wifi_only_playback') ?? false;
    autoplayNext.value = _storage.read<bool>('autoplay_next') ?? true;
    downloadQuality.value = _storage.read<String>('settings_download_quality') ?? 'Auto (720p)';
  }

  void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    _storage.write('settings_dark_mode', value);
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  void setLanguage(String lang) {
    selectedLanguage.value = lang;
    _storage.write('settings_language', lang);
  }

  void togglePauseWatchHistory(bool value) {
    pauseWatchHistory.value = value;
    _storage.write('watch_history_paused', value);
  }

  void togglePauseSearchHistory(bool value) {
    pauseSearchHistory.value = value;
    _storage.write('search_history_paused', value);
  }

  void toggleWifiOnly(bool value) {
    wifiOnlyPlayback.value = value;
    _storage.write('wifi_only_playback', value);
  }

  void toggleAutoplay(bool value) {
    autoplayNext.value = value;
    _storage.write('autoplay_next', value);
  }

  void setDownloadQuality(String quality) {
    downloadQuality.value = quality;
    _storage.write('settings_download_quality', quality);
  }
}
