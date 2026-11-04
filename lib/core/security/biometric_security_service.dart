import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// 🔐 Biometric & Device Credential Security Service
///
/// Enforces on-device biometric (Fingerprint, Face, Iris) or secure OS PIN / Pattern / Passcode
/// re-authentication prior to sensitive high-value actions:
/// 1. Creator revenue payouts & withdrawal requests (NEFT/IMPS/UPI)
/// 2. Bank account credentials & IFSC modifications
/// 3. High-value transactions or sensitive KYC data releases
class BiometricSecurityService extends GetxService {
  BiometricSecurityService({LocalAuthentication? auth})
      : _localAuth = auth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  static BiometricSecurityService get to {
    if (!Get.isRegistered<BiometricSecurityService>()) {
      Get.put(BiometricSecurityService(), permanent: true);
    }
    return Get.find<BiometricSecurityService>();
  }

  /// Master switch for native biometric authentication.
  /// Set to `false` during unit tests or headless test environments.
  static bool enableNativeAuth = true;

  /// Test hook to simulate authentication outcomes deterministically.
  @visibleForTesting
  static bool? mockAuthenticationResult;

  /// Check whether the current device supports local biometric or device credential verification.
  /// Fails closed on Web or when native authentication is unavailable.
  Future<bool> isDeviceSupported() async {
    if (kIsWeb || !enableNativeAuth) {
      return false;
    }

    try {
      return await _localAuth.isDeviceSupported();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'BiometricSecurityService.isDeviceSupported',
      );
      return false;
    }
  }

  /// Check whether biometric sensors can be checked on this hardware.
  /// Fails closed on Web or when native authentication is unavailable.
  Future<bool> canCheckBiometrics() async {
    if (kIsWeb || !enableNativeAuth) {
      return false;
    }

    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'BiometricSecurityService.canCheckBiometrics',
      );
      return false;
    }
  }

  /// Retrieve available enrolled biometric types (e.g. fingerprint, face, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (!enableNativeAuth || kIsWeb) {
      return const <BiometricType>[];
    }

    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'BiometricSecurityService.getAvailableBiometrics',
      );
      return const <BiometricType>[];
    }
  }

  /// Authenticates the user via biometric prompt or device lock screen credentials (PIN/Pattern/Passcode).
  ///
  /// Strictly fails closed: Returns `false` on Web or if the device lacks security hardware
  /// or when authentication is rejected/cancelled. Optionally executes [fallbackAuth]
  /// (e.g. Firebase Auth re-authentication) if provided. Never allows compatibility pass-throughs.
  Future<bool> authenticateForHighValueAction({
    required String reason,
    bool biometricOnly = false,
    bool showFriendlyWarningOnFailure = true,
    Future<bool> Function()? fallbackAuth,
  }) async {
    // 1. Deterministic test override
    if (mockAuthenticationResult != null) {
      return mockAuthenticationResult!;
    }

    // 2. Web platform: fail closed or execute secondary fallback
    if (kIsWeb) {
      logger.warning(
        'Biometric authentication is not supported on Web; failing closed or executing fallback verification',
        tag: 'BiometricSecurity',
      );
      if (fallbackAuth != null) {
        try {
          return await fallbackAuth();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'BiometricSecurityService.fallbackAuth.web',
          );
          return false;
        }
      }
      if (showFriendlyWarningOnFailure) {
        AppSnackbar.warning(
          'Device security verification is unavailable on Web. High-value actions must be performed on a secure mobile device.',
        );
      }
      return false;
    }

    // 3. Native authentication switch guard: fail closed or execute secondary fallback
    if (!enableNativeAuth) {
      if (fallbackAuth != null) {
        try {
          return await fallbackAuth();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'BiometricSecurityService.fallbackAuth.nativeDisabled',
          );
          return false;
        }
      }
      return false;
    }

    try {
      // 4. Unsupported hardware / missing screen lock: strictly fail closed or execute secondary fallback
      final supported = await isDeviceSupported();
      if (!supported) {
        logger.warning(
          'Device does not support local biometric or lock-screen authentication; failing closed or executing fallback verification',
          tag: 'BiometricSecurity',
        );
        if (fallbackAuth != null) {
          try {
            return await fallbackAuth();
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'BiometricSecurityService.fallbackAuth.unsupportedDevice',
            );
            return false;
          }
        }
        if (showFriendlyWarningOnFailure) {
          AppSnackbar.warning(
            'A secure device screen lock (PIN, Pattern, or Biometrics) is required to perform high-value actions.',
          );
        }
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated && showFriendlyWarningOnFailure) {
        AppSnackbar.warning(
          'Authentication was cancelled or could not be verified. Operation aborted for your security.',
        );
      }

      return authenticated;
    } on LocalAuthException catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'BiometricSecurityService.authenticateForHighValueAction',
      );

      if (showFriendlyWarningOnFailure) {
        final friendlyMessage = _resolveLocalAuthExceptionMessage(e.code);
        AppSnackbar.warning(friendlyMessage);
      }
      return false;
    } on PlatformException catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'BiometricSecurityService.authenticateForHighValueAction',
      );

      if (showFriendlyWarningOnFailure) {
        final friendlyMessage = _resolvePlatformErrorMessage(e.code);
        AppSnackbar.warning(friendlyMessage);
      }
      return false;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'BiometricSecurityService.authenticateForHighValueAction',
      );

      if (showFriendlyWarningOnFailure) {
        AppSnackbar.warning(
          'Security verification was unable to complete. Please try again.',
        );
      }
      return false;
    }
  }

  /// Maps [LocalAuthExceptionCode] into friendly, clear, user-facing English.
  /// Strictly prevents raw developer error leaks.
  String _resolveLocalAuthExceptionMessage(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.authInProgress:
        return 'Authentication is already in progress. Please complete the prompt on your screen.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Biometric authentication is temporarily locked due to multiple attempts. Please wait a moment or use your device PIN.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Biometrics are locked. Please unlock your device using your primary PIN or password in device settings.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'A screen lock (PIN, Pattern, or Password) is required for payout security. Please set up a screen lock in your device settings.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No biometric credentials are enrolled. Please enroll your fingerprint or face in device settings or use your device PIN.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Biometric authentication hardware is unavailable on this device.';
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Biometric authentication hardware is temporarily unavailable. Please try again.';
      case LocalAuthExceptionCode.timeout:
        return 'Authentication timed out. Please try again.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'Verification was cancelled. Payout request was not submitted.';
      case LocalAuthExceptionCode.uiUnavailable:
      default:
        return 'Biometric or device verification could not be completed. Please try again.';
    }
  }

  /// Fallback mapper for raw PlatformException codes.
  String _resolvePlatformErrorMessage(String code) {
    switch (code) {
      case 'auth_in_progress':
        return 'Authentication is already in progress. Please complete the prompt on your screen.';
      case 'LockedOut':
        return 'Biometric authentication is temporarily locked. Please wait a moment or use your device PIN.';
      case 'PermanentlyLockedOut':
        return 'Biometrics are locked. Please unlock your device using your primary PIN or password in device settings.';
      case 'PasscodeNotSet':
        return 'A screen lock (PIN, Pattern, or Password) is required for payout security. Please set up a screen lock in your device settings.';
      case 'NotEnrolled':
        return 'No biometric credentials enrolled. Please enroll your fingerprint or face in device settings.';
      case 'NotAvailable':
        return 'Biometric authentication hardware is currently unavailable.';
      case 'UserCancel':
      case 'SystemCancel':
        return 'Verification was cancelled. Payout request was not submitted.';
      default:
        return 'Biometric or device verification could not be completed. Please try again.';
    }
  }
}
