import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_ctrl;
import 'package:truthworld/features/settings/data/models/accessibility_settings.dart';
import 'package:truthworld/features/settings/data/models/digital_wellbeing_settings.dart';
import 'package:truthworld/features/settings/data/models/download_settings.dart';
import 'package:truthworld/features/settings/data/models/playback_settings.dart';
import 'package:truthworld/features/settings/data/repositories/settings_repository.dart';

class UserSettingsController extends GetxController {
  static UserSettingsController get to {
    if (Get.isRegistered<UserSettingsController>()) {
      return Get.find<UserSettingsController>();
    }
    return Get.find<UserSettingsController>();
  }

  final SettingsRepository _repository = SettingsRepository();

  // --- Reactive Settings Models ---
  final Rx<DigitalWellbeingSettings> wellbeing = const DigitalWellbeingSettings().obs;
  final Rx<PlaybackSettings> playback = const PlaybackSettings().obs;
  final Rx<DownloadSettings> downloads = const DownloadSettings().obs;
  final Rx<AccessibilitySettings> accessibility = const AccessibilitySettings().obs;

  // --- Reactive Individual Preferences ---
  final RxBool pushNotificationsEnabled = true.obs;
  final RxString channelAlerts = 'Personalized'.obs;
  final RxBool isSearchHistoryPaused = false.obs;
  final RxList<String> blockedUsers = <String>[].obs;
  final RxList<String> mutedKeywords = <String>[].obs;

  // --- Dynamic Media Storage State ---
  final RxDouble cacheSizeMB = 0.0.obs;

  // --- Platform Feature Capabilities ---
  bool get isBackgroundPlaybackSupported => !kIsWeb;
  bool get isSDCardAvailable => false; // Dynamic check for Android SD cards

  @override
  void onInit() {
    super.onInit();
    loadAllSettings();
    calculateCacheSize();
  }

  void loadAllSettings() {
    wellbeing.value = _repository.getDigitalWellbeing();
    playback.value = _repository.getPlayback();
    downloads.value = _repository.getDownloads();
    accessibility.value = _repository.getAccessibility();

    pushNotificationsEnabled.value = _repository.getPushEnabled();
    channelAlerts.value = _repository.getChannelAlerts();
    isSearchHistoryPaused.value = _repository.getSearchHistoryPaused();
    blockedUsers.assignAll(_repository.getBlockedUsers());
    mutedKeywords.assignAll(_repository.getMutedKeywords());
  }

  // ================= DIGITAL WELLBEING =================

  void updateWellbeing(DigitalWellbeingSettings updated) {
    wellbeing.value = updated;
    _repository.updateDigitalWellbeing(updated);
  }

  void setBreakReminder(int minutes) {
    updateWellbeing(wellbeing.value.copyWith(breakReminderMinutes: minutes));
  }

  void toggleBedtimeReminder(bool enabled) {
    updateWellbeing(wellbeing.value.copyWith(bedtimeEnabled: enabled));
  }

  void setBedtimeSchedule(String start, String end, String days) {
    updateWellbeing(
      wellbeing.value.copyWith(
        bedtimeStartTime: start,
        bedtimeEndTime: end,
        bedtimeDaysSchedule: days,
      ),
    );
  }

  bool verifyParentalPin(String inputPin) {
    final current = wellbeing.value;

    // Check if locked out
    if (current.lockoutUntil != null) {
      final lockoutTime = DateTime.parse(current.lockoutUntil!);
      if (DateTime.now().isBefore(lockoutTime)) {
        return false;
      }
    }

    final isValid = current.verifyPin(inputPin);
    if (isValid) {
      updateWellbeing(current.copyWith(failedPinAttempts: 0));
      return true;
    } else {
      final attempts = current.failedPinAttempts + 1;
      String? newLockout;
      if (attempts >= 5) {
        newLockout = DateTime.now()
            .add(const Duration(minutes: 15))
            .toIso8601String();
      }
      updateWellbeing(
        current.copyWith(
          failedPinAttempts: attempts,
          lockoutUntil: newLockout,
        ),
      );
      return false;
    }
  }

  void setParentalPin(String rawPin) {
    final hashed = DigitalWellbeingSettings.hashPin(rawPin);
    updateWellbeing(
      wellbeing.value.copyWith(
        parentalPinEnabled: true,
        hashedPin: hashed,
        failedPinAttempts: 0,
      ),
    );
  }

  void disableParentalPin() {
    updateWellbeing(
      wellbeing.value.copyWith(
        parentalPinEnabled: false,
        failedPinAttempts: 0,
      ),
    );
  }

  // ================= PLAYBACK & MEDIA =================

  void updatePlayback(PlaybackSettings updated) {
    playback.value = updated;
    _repository.updatePlayback(updated);
  }

  void setWifiQuality(String quality) {
    updatePlayback(playback.value.copyWith(wifiQuality: quality));
  }

  void setCellularQuality(String quality) {
    updatePlayback(playback.value.copyWith(cellularQuality: quality));
  }

  void toggleAutoplayNext(bool value) {
    updatePlayback(playback.value.copyWith(autoplayNext: value));
  }

  void setSeekDuration(int seconds) {
    updatePlayback(playback.value.copyWith(seekDurationSeconds: seconds));
  }

  void setVolumeNormalization(String mode) {
    updatePlayback(playback.value.copyWith(volumeNormalizationMode: mode));
  }

  void setBackgroundPlayback(String mode) {
    updatePlayback(playback.value.copyWith(backgroundPlaybackMode: mode));
  }

  void toggleStatsForNerds(bool value) {
    updatePlayback(playback.value.copyWith(statsForNerdsEnabled: value));
  }

  // ================= SMART DOWNLOADS & STORAGE =================

  void updateDownloads(DownloadSettings updated) {
    downloads.value = updated;
    _repository.updateDownloads(updated);
  }

  void toggleSmartDownloads(bool enabled) {
    updateDownloads(downloads.value.copyWith(smartDownloadsEnabled: enabled));
  }

  void setMaxStorageLimit(String limit) {
    updateDownloads(downloads.value.copyWith(maxStorageLimit: limit));
  }

  void setDownloadLocation(String location) {
    updateDownloads(downloads.value.copyWith(downloadLocation: location));
  }

  void setDownloadQuality(String quality) {
    updateDownloads(downloads.value.copyWith(downloadQuality: quality));
  }

  Future<void> clearCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
          await tempDir.create();
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
    cacheSizeMB.value = 0.0;
  }

  Future<void> calculateCacheSize() async {
    if (kIsWeb) {
      cacheSizeMB.value = 0.0;
      return;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        var totalBytes = 0;
        await for (final entity in tempDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
        cacheSizeMB.value = totalBytes / (1024 * 1024);
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
  }

  // ================= ACCESSIBILITY & COMFORT =================

  void updateAccessibility(AccessibilitySettings updated) {
    accessibility.value = updated;
    _repository.updateAccessibility(updated);
  }

  void toggleReduceMotion(bool val) =>
      updateAccessibility(accessibility.value.copyWith(reduceMotion: val));
  void toggleHighContrastSubtitles(bool val) => updateAccessibility(
    accessibility.value.copyWith(highContrastSubtitles: val),
  );
  void toggleHapticFeedback(bool val) =>
      updateAccessibility(accessibility.value.copyWith(hapticFeedback: val));
  void setCaptionSize(String size) =>
      updateAccessibility(accessibility.value.copyWith(captionSize: size));
  void setColorBlindSupport(String mode) => updateAccessibility(
    accessibility.value.copyWith(colorBlindSupport: mode),
  );

  // ================= NOTIFICATIONS & PRIVACY =================

  void togglePushNotifications(bool value) {
    pushNotificationsEnabled.value = value;
    _repository.setPushEnabled(value);
  }

  void setChannelAlerts(String level) {
    channelAlerts.value = level;
    _repository.setChannelAlerts(level);
  }

  void toggleSearchHistoryPaused() {
    isSearchHistoryPaused.value = !isSearchHistoryPaused.value;
    _repository.setSearchHistoryPaused(isSearchHistoryPaused.value);
  }

  void clearSearchHistory() {
    _repository.clearSearchHistory();
    if (Get.isRegistered<search_ctrl.SearchController>()) {
      Get.find<search_ctrl.SearchController>().clearRecentSearches();
    }
  }

  void blockUser(String username) {
    final trimmed = username.trim();
    if (trimmed.isNotEmpty && !blockedUsers.contains(trimmed)) {
      blockedUsers.add(trimmed);
      _repository.setBlockedUsers(blockedUsers.toList());
    }
  }

  void unblockUser(String username) {
    blockedUsers.remove(username);
    _repository.setBlockedUsers(blockedUsers.toList());
  }

  void addMutedKeyword(String keyword) {
    final trimmed = keyword.trim().toLowerCase();
    if (trimmed.isNotEmpty && !mutedKeywords.contains(trimmed)) {
      mutedKeywords.add(trimmed);
      _repository.setMutedKeywords(mutedKeywords.toList());
    }
  }

  void removeMutedKeyword(String keyword) {
    mutedKeywords.remove(keyword);
    _repository.setMutedKeywords(mutedKeywords.toList());
  }

  // ================= RESET OPTIONS =================

  Future<void> resetWellbeing() async {
    await _repository.resetWellbeing();
    wellbeing.value = _repository.getDigitalWellbeing();
  }

  Future<void> resetPlayback() async {
    await _repository.resetPlayback();
    playback.value = _repository.getPlayback();
  }

  Future<void> resetDownloads() async {
    await _repository.resetDownloads();
    downloads.value = _repository.getDownloads();
  }

  Future<void> resetAccessibility() async {
    await _repository.resetAccessibility();
    accessibility.value = _repository.getAccessibility();
  }

  Future<void> resetAllSettings() async {
    await _repository.resetAll();
    loadAllSettings();
  }
}
