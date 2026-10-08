import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// 🛡️ Screen Security Service (FLAG_SECURE)
///
/// Prevents sensitive payment, wallet, KYC, and credential screens from:
/// 1. Spyware and background screenshot tools
/// 2. Screen recording / broadcast stream capturing
/// 3. OS Task Switcher / Recent Apps thumbnail preview leaks (memory snapshots)
class ScreenSecurityService extends GetxService {
  static ScreenSecurityService get to {
    if (!Get.isRegistered<ScreenSecurityService>()) {
      Get.put(ScreenSecurityService(), permanent: true);
    }
    return Get.find<ScreenSecurityService>();
  }

  static const MethodChannel _channel =
      MethodChannel('com.example.truthworld/screen_security');

  /// Whether native screen security calls should be performed (mockable in unit tests).
  static bool enableNativeChannel = true;

  final RxBool isSecureMode = false.obs;

  /// Enables Android `FLAG_SECURE` to block screenshots, screen recordings,
  /// and recent app snapshot previews.
  Future<bool> enableSecureMode() async {
    isSecureMode.value = true;

    if (!enableNativeChannel || kIsWeb) {
      return true;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final success = await _channel.invokeMethod<bool>('enableSecureMode');
      return success ?? true;
    } on MissingPluginException {
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'ScreenSecurityService.enableSecureMode',
      );
      return false;
    }
  }

  /// Disables `FLAG_SECURE`, allowing normal screen captures on non-sensitive surfaces.
  Future<bool> disableSecureMode() async {
    isSecureMode.value = false;

    if (!enableNativeChannel || kIsWeb) {
      return true;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final success = await _channel.invokeMethod<bool>('disableSecureMode');
      return success ?? true;
    } on MissingPluginException {
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'ScreenSecurityService.disableSecureMode',
      );
      return false;
    }
  }

  /// Checks whether `FLAG_SECURE` is currently active.
  Future<bool> isSecureModeEnabled() async {
    if (!enableNativeChannel || kIsWeb) {
      return isSecureMode.value;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return isSecureMode.value;
    }

    try {
      final active = await _channel.invokeMethod<bool>('isSecureModeEnabled');
      final result = active ?? isSecureMode.value;
      isSecureMode.value = result;
      return result;
    } on MissingPluginException {
      return isSecureMode.value;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'ScreenSecurityService.isSecureModeEnabled',
      );
      return isSecureMode.value;
    }
  }

  /// Wraps a sensitive asynchronous operation (such as checkout, KYC, or PIN entry)
  /// with automatic `FLAG_SECURE` lifecycle protection.
  Future<T> protectSensitiveOperation<T>(Future<T> Function() operation) async {
    final previousState = isSecureMode.value;
    await enableSecureMode();
    try {
      return await operation();
    } finally {
      if (!previousState) {
        await disableSecureMode();
      }
    }
  }
}
