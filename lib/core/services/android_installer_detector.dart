import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// The source from which the current APK/app was installed.
enum AndroidInstallerSource {
  /// Installed from Google Play Store — Cashfree native SDK works fine.
  playStore,

  /// Installed from Samsung Galaxy Store — Cashfree native SDK works fine.
  galaxyStore,

  /// Installed from Amazon Appstore — Cashfree native SDK works fine.
  amazonAppstore,

  /// Sideloaded (ADB, direct APK download, MDM, etc.) — Cashfree native SDK
  /// will reject with `installer_package_not_approved`.
  sideloaded,

  /// Platform is not Android, or channel call failed — treat as trusted.
  unknown,
}

/// Detects how the running Android APK was installed.
///
/// Used by [CashfreePaymentService] to proactively bypass the Cashfree native
/// SDK installer-package check in sideloaded release builds, without waiting
/// for the SDK to fire the error callback.
class AndroidInstallerDetector {
  static const _channel =
      MethodChannel('com.example.truthworld/installer');

  /// Cached result — installer source cannot change at runtime.
  static AndroidInstallerSource? _cached;

  /// Returns the installer source for the running app.
  ///
  /// Result is cached after the first call. Non-Android platforms return
  /// [AndroidInstallerSource.unknown].
  static Future<AndroidInstallerSource> getInstallerSource() async {
    if (_cached != null) return _cached!;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _cached = AndroidInstallerSource.unknown;
      return _cached!;
    }

    try {
      final raw = await _channel.invokeMethod<String>('getInstallerSource');
      _cached = _parse(raw ?? '');
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AndroidInstallerDetector');
      _cached = AndroidInstallerSource.unknown;
    }
    return _cached!;
  }

  /// Returns `true` when payments via the Cashfree native Android SDK will be
  /// rejected due to installer-package verification failure.
  static Future<bool> isSideloaded() async {
    final source = await getInstallerSource();
    return source == AndroidInstallerSource.sideloaded;
  }

  /// Clears the cached value — for use in tests only.
  @visibleForTesting
  static void clearCache() => _cached = null;

  static AndroidInstallerSource _parse(String raw) {
    switch (raw) {
      case 'play_store':
        return AndroidInstallerSource.playStore;
      case 'samsung_galaxy_store':
        return AndroidInstallerSource.galaxyStore;
      case 'amazon_appstore':
        return AndroidInstallerSource.amazonAppstore;
      case 'sideloaded':
        return AndroidInstallerSource.sideloaded;
      default:
        return AndroidInstallerSource.unknown;
    }
  }
}
