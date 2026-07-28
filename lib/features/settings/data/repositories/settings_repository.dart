import 'package:flutter/foundation.dart';
import 'package:truthworld/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:truthworld/features/settings/data/models/accessibility_settings.dart';
import 'package:truthworld/features/settings/data/models/digital_wellbeing_settings.dart';
import 'package:truthworld/features/settings/data/models/download_settings.dart';
import 'package:truthworld/features/settings/data/models/playback_settings.dart';

class SettingsRepository {

  SettingsRepository({SettingsLocalDataSource? dataSource})
      : _dataSource = dataSource ?? SettingsLocalDataSource();
  final SettingsLocalDataSource _dataSource;

  // --- Digital Wellbeing ---
  DigitalWellbeingSettings getDigitalWellbeing() => _dataSource.loadDigitalWellbeing();
  Future<void> updateDigitalWellbeing(DigitalWellbeingSettings settings) async {
    await _dataSource.saveDigitalWellbeing(settings);
    _logAnalytics('wellbeing_settings_updated');
  }

  // --- Playback ---
  PlaybackSettings getPlayback() => _dataSource.loadPlayback();
  Future<void> updatePlayback(PlaybackSettings settings) async {
    await _dataSource.savePlayback(settings);
    _logAnalytics('playback_settings_updated');
  }

  // --- Downloads ---
  DownloadSettings getDownloads() => _dataSource.loadDownloads();
  Future<void> updateDownloads(DownloadSettings settings) async {
    await _dataSource.saveDownloads(settings);
    _logAnalytics('download_settings_updated');
  }

  // --- Accessibility ---
  AccessibilitySettings getAccessibility() => _dataSource.loadAccessibility();
  Future<void> updateAccessibility(AccessibilitySettings settings) async {
    await _dataSource.saveAccessibility(settings);
    _logAnalytics('accessibility_settings_updated');
  }

  // --- Notifications & Privacy ---
  bool getPushEnabled() => _dataSource.loadPushEnabled();
  Future<void> setPushEnabled(bool value) async {
    await _dataSource.savePushEnabled(value);
    _logAnalytics('push_notifications_toggled', {'enabled': value});
  }

  String getChannelAlerts() => _dataSource.loadChannelAlerts();
  Future<void> setChannelAlerts(String value) async {
    await _dataSource.saveChannelAlerts(value);
    _logAnalytics('channel_alerts_changed', {'level': value});
  }

  bool getSearchHistoryPaused() => _dataSource.loadSearchHistoryPaused();
  Future<void> setSearchHistoryPaused(bool value) async {
    await _dataSource.saveSearchHistoryPaused(value);
  }
  Future<void> clearSearchHistory() async {
    await _dataSource.clearSearchHistory();
  }

  List<String> getBlockedUsers() => _dataSource.loadBlockedUsers();
  Future<void> setBlockedUsers(List<String> users) => _dataSource.saveBlockedUsers(users);

  List<String> getMutedKeywords() => _dataSource.loadMutedKeywords();
  Future<void> setMutedKeywords(List<String> keywords) => _dataSource.saveMutedKeywords(keywords);

  // --- Reset Commands ---
  Future<void> resetWellbeing() async {
    await updateDigitalWellbeing(const DigitalWellbeingSettings());
  }

  Future<void> resetPlayback() async {
    await updatePlayback(const PlaybackSettings());
  }

  Future<void> resetDownloads() async {
    await updateDownloads(const DownloadSettings());
  }

  Future<void> resetAccessibility() async {
    await updateAccessibility(const AccessibilitySettings());
  }

  Future<void> resetAll() async {
    await _dataSource.clearAllSettings();
    _logAnalytics('settings_reset_all');
  }

  void _logAnalytics(String eventName, [Map<String, dynamic>? params]) {
    debugPrint('📊 [Analytics Event]: $eventName | Params: $params');
  }
}
