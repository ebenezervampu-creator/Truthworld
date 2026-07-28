import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/settings/data/models/accessibility_settings.dart';
import 'package:truthworld/features/settings/data/models/digital_wellbeing_settings.dart';
import 'package:truthworld/features/settings/data/models/download_settings.dart';
import 'package:truthworld/features/settings/data/models/playback_settings.dart';

class SettingsLocalDataSource {

  SettingsLocalDataSource([GetStorage? storage])
      : _storage = storage ?? GetStorage();
  final GetStorage _storage;

  static const String _kKeyWellbeing = 'app_settings_wellbeing';
  static const String _kKeyPlayback = 'app_settings_playback';
  static const String _kKeyDownloads = 'app_settings_downloads';
  static const String _kKeyAccessibility = 'app_settings_accessibility';
  static const String _kKeyPushEnabled = 'app_settings_push_enabled';
  static const String _kKeyChannelAlerts = 'app_settings_channel_alerts';
  static const String _kKeySearchHistoryPaused = 'app_settings_search_history_paused';
  static const String _kKeyBlockedUsers = 'app_settings_blocked_users';
  static const String _kKeyMutedKeywords = 'app_settings_muted_keywords';

  // --- Wellbeing ---
  DigitalWellbeingSettings loadDigitalWellbeing() {
    final raw = _storage.read<Map<String, dynamic>>(_kKeyWellbeing);
    if (raw != null) {
      return DigitalWellbeingSettings.fromJson(raw);
    }
    return const DigitalWellbeingSettings();
  }

  Future<void> saveDigitalWellbeing(DigitalWellbeingSettings settings) async {
    await _storage.write(_kKeyWellbeing, settings.toJson());
  }

  // --- Playback ---
  PlaybackSettings loadPlayback() {
    final raw = _storage.read<Map<String, dynamic>>(_kKeyPlayback);
    if (raw != null) {
      return PlaybackSettings.fromJson(raw);
    }
    return const PlaybackSettings();
  }

  Future<void> savePlayback(PlaybackSettings settings) async {
    await _storage.write(_kKeyPlayback, settings.toJson());
  }

  // --- Downloads ---
  DownloadSettings loadDownloads() {
    final raw = _storage.read<Map<String, dynamic>>(_kKeyDownloads);
    if (raw != null) {
      return DownloadSettings.fromJson(raw);
    }
    return const DownloadSettings();
  }

  Future<void> saveDownloads(DownloadSettings settings) async {
    await _storage.write(_kKeyDownloads, settings.toJson());
  }

  // --- Accessibility ---
  AccessibilitySettings loadAccessibility() {
    final raw = _storage.read<Map<String, dynamic>>(_kKeyAccessibility);
    if (raw != null) {
      return AccessibilitySettings.fromJson(raw);
    }
    return const AccessibilitySettings();
  }

  Future<void> saveAccessibility(AccessibilitySettings settings) async {
    await _storage.write(_kKeyAccessibility, settings.toJson());
  }

  // --- Notifications & Privacy ---
  bool loadPushEnabled() => _storage.read<bool>(_kKeyPushEnabled) ?? true;
  Future<void> savePushEnabled(bool value) => _storage.write(_kKeyPushEnabled, value);

  String loadChannelAlerts() => _storage.read<String>(_kKeyChannelAlerts) ?? 'Personalized';
  Future<void> saveChannelAlerts(String value) => _storage.write(_kKeyChannelAlerts, value);

  bool loadSearchHistoryPaused() => _storage.read<bool>(_kKeySearchHistoryPaused) ?? false;
  Future<void> saveSearchHistoryPaused(bool value) => _storage.write(_kKeySearchHistoryPaused, value);

  List<String> loadBlockedUsers() {
    final raw = _storage.read<List>(_kKeyBlockedUsers);
    return raw?.cast<String>() ?? [];
  }
  Future<void> saveBlockedUsers(List<String> users) => _storage.write(_kKeyBlockedUsers, users);

  List<String> loadMutedKeywords() {
    final raw = _storage.read<List>(_kKeyMutedKeywords);
    return raw?.cast<String>() ?? ['spam', 'clickbait'];
  }
  Future<void> saveMutedKeywords(List<String> keywords) => _storage.write(_kKeyMutedKeywords, keywords);

  Future<void> clearSearchHistory() async {
    await _storage.remove('search_recent_history');
  }

  Future<void> clearAllSettings() async {
    await _storage.remove(_kKeyWellbeing);
    await _storage.remove(_kKeyPlayback);
    await _storage.remove(_kKeyDownloads);
    await _storage.remove(_kKeyAccessibility);
    await _storage.remove(_kKeyPushEnabled);
    await _storage.remove(_kKeyChannelAlerts);
    await _storage.remove(_kKeySearchHistoryPaused);
    await _storage.remove(_kKeyBlockedUsers);
    await _storage.remove(_kKeyMutedKeywords);
  }
}
