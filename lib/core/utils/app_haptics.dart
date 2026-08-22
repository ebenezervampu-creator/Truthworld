import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

/// Centralized utility for haptic feedback that respects the user's
/// accessibility setting for haptic vibration.
class AppHaptics {
  AppHaptics._();

  static bool get _isEnabled {
    if (!Get.isRegistered<UserSettingsController>()) return true;
    return UserSettingsController.to.accessibility.value.hapticFeedback;
  }

  /// Light impact for standard button presses, chips, and small UI interactions
  static Future<void> lightImpact() async {
    if (!_isEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for confirmations, toggle switches, and list selections
  static Future<void> mediumImpact() async {
    if (!_isEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for destructive actions, alerts, or important state changes
  static Future<void> heavyImpact() async {
    if (!_isEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Selection click for slider scrubbing, picker wheel rotations, and tab switches
  static Future<void> selectionClick() async {
    if (!_isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Standard vibration
  static Future<void> vibrate() async {
    if (!_isEnabled) return;
    await HapticFeedback.vibrate();
  }
}
