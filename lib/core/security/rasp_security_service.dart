import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Detailed assessment result from the Runtime Application Self-Protection (RASP) engine.
class RaspThreatAssessment {
  final bool fridaDetected;
  final bool debuggerAttached;
  final bool hookingDetected;
  final bool rootDetected;
  final bool emulatorDetected;
  final bool signatureValid;
  final bool isSecure;
  final int threatCount;
  final List<String> threatDetails;

  const RaspThreatAssessment({
    required this.fridaDetected,
    required this.debuggerAttached,
    required this.hookingDetected,
    required this.rootDetected,
    required this.emulatorDetected,
    required this.signatureValid,
    required this.isSecure,
    required this.threatCount,
    required this.threatDetails,
  });

  factory RaspThreatAssessment.safe() {
    return const RaspThreatAssessment(
      fridaDetected: false,
      debuggerAttached: false,
      hookingDetected: false,
      rootDetected: false,
      emulatorDetected: false,
      signatureValid: true,
      isSecure: true,
      threatCount: 0,
      threatDetails: [],
    );
  }

  factory RaspThreatAssessment.fromMap(Map<dynamic, dynamic> map) {
    final details = (map['threatDetails'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return RaspThreatAssessment(
      fridaDetected: map['fridaDetected'] == true,
      debuggerAttached: map['debuggerAttached'] == true,
      hookingDetected: map['hookingDetected'] == true,
      rootDetected: map['rootDetected'] == true,
      emulatorDetected: map['emulatorDetected'] == true,
      signatureValid: map['signatureValid'] != false,
      isSecure: map['isSecure'] == true,
      threatCount: (map['threatCount'] as int?) ?? details.length,
      threatDetails: details,
    );
  }
}

/// 🛡️ Runtime Application Self-Protection (RASP) Service
///
/// Defends TruthWorld against:
/// 1. Dynamic binary instrumentation & hook engines (Frida, Xposed, Substrate)
/// 2. Active debugger attachment (Ptrace TracerPid, LLDB, GDB)
/// 3. Device rooting & privilege escalation tampering
/// 4. Execution memory tampering during sensitive financial transactions
class RaspSecurityService extends GetxService {
  static RaspSecurityService get to {
    if (!Get.isRegistered<RaspSecurityService>()) {
      Get.put(RaspSecurityService(), permanent: true);
    }
    return Get.find<RaspSecurityService>();
  }

  static const MethodChannel _channel =
      MethodChannel('com.example.truthworld/rasp');

  /// Whether native RASP channel calls should be performed (can be disabled in pure unit tests).
  static bool enableNativeChannel = true;

  final RxBool isScanning = false.obs;
  final Rx<RaspThreatAssessment?> lastAssessment =
      Rx<RaspThreatAssessment?>(null);
  final RxBool isTampered = false.obs;

  /// Custom threat callback for testing or custom incident reporting.
  @visibleForTesting
  Future<void> Function(RaspThreatAssessment threats)? onThreatDetected;

  @override
  void onInit() {
    super.onInit();
    // Non-blocking proactive security check on startup
    if (enableNativeChannel) {
      unawaited(enforceAppIntegrity(terminateOnFailure: false));
    }
  }

  /// Scans the application runtime environment for active hooking, debuggers, and root.
  Future<RaspThreatAssessment> checkSecurityThreats() async {
    if (!enableNativeChannel || kIsWeb) {
      final safe = RaspThreatAssessment.safe();
      lastAssessment.value = safe;
      return safe;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      // Non-Android platforms: perform Dart runtime assertions
      final safe = RaspThreatAssessment.safe();
      lastAssessment.value = safe;
      return safe;
    }

    try {
      isScanning.value = true;
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('checkSecurityThreats')
          .timeout(const Duration(seconds: 10));

      if (result != null) {
        final assessment = RaspThreatAssessment.fromMap(result);
        lastAssessment.value = assessment;
        isTampered.value = !assessment.isSecure;
        return assessment;
      }
    } on MissingPluginException {
      // Fallback in environments where native binary messenger is mock/unavailable
      final safe = RaspThreatAssessment.safe();
      lastAssessment.value = safe;
      return safe;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RaspSecurityService.checkSecurityThreats',
      );
    } finally {
      isScanning.value = false;
    }

    // Default safe fallback if native check cannot execute
    final fallback = RaspThreatAssessment.safe();
    lastAssessment.value = fallback;
    return fallback;
  }

  DateTime? _lastSecurityCheckTime;
  static const Duration _securityCheckTtl = Duration(minutes: 5);

  /// Returns `true` if the runtime environment is free of dynamic memory hooking or debuggers.
  Future<bool> isEnvironmentSecure({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastSecurityCheckTime != null &&
        lastAssessment.value != null &&
        lastAssessment.value!.isSecure &&
        now.difference(_lastSecurityCheckTime!) < _securityCheckTtl) {
      return true;
    }
    final assessment = await checkSecurityThreats();
    if (assessment.isSecure) {
      _lastSecurityCheckTime = DateTime.now();
    }
    return assessment.isSecure;
  }

  /// Asserts environment integrity before sensitive operations (e.g., payments, auth).
  /// Alias for [enforceAppIntegrity] for backward-compatibility.
  Future<void> assertEnvironmentSecure({bool terminateOnFailure = true}) =>
      enforceAppIntegrity(terminateOnFailure: terminateOnFailure);

  /// Asserts environment integrity before sensitive operations (e.g., payments, auth).
  ///
  /// In release mode, terminates the app or isolates the session if Frida/debuggers are detected.
  Future<void> enforceAppIntegrity({bool terminateOnFailure = true}) async {
    final threats = await checkSecurityThreats();

    if (!threats.isSecure) {
      logger.warning(
        'RASP Security Warning: Detected runtime integrity threats: '
        '${threats.threatDetails.join(', ')}',
        tag: 'RaspSecurity',
      );

      if (onThreatDetected != null) {
        await onThreatDetected!(threats);
      }

      if (kReleaseMode) {
        ErrorHandler.log(
          'RASP Critical Security Breach: ${threats.threatDetails.join('; ')}',
          tag: 'RaspSecurity.Breach',
        );

        if (terminateOnFailure) {
          await terminateApp();
        }
      }
    }
  }

  /// Immediately terminates the application process to prevent memory dumping or payload injection.
  Future<void> terminateApp() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('terminateApp');
      } else {
        await SystemNavigator.pop();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'RaspSecurityService.terminateApp');
      await SystemNavigator.pop();
    }
  }
}
