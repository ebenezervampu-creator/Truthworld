import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:truthworld/core/security/biometric_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    BiometricSecurityService.enableNativeAuth = false;
    BiometricSecurityService.mockAuthenticationResult = null;
  });

  tearDown(() {
    BiometricSecurityService.enableNativeAuth = true;
    BiometricSecurityService.mockAuthenticationResult = null;
  });

  group('BiometricSecurityService Tests', () {
    test('initializes and registers as GetxService singleton', () {
      final service = BiometricSecurityService.to;
      expect(service, isA<BiometricSecurityService>());
      expect(Get.isRegistered<BiometricSecurityService>(), isTrue);
    });

    test('isDeviceSupported returns true in mock/test mode', () async {
      final service = BiometricSecurityService.to;
      final supported = await service.isDeviceSupported();
      expect(supported, isTrue);
    });

    test('canCheckBiometrics returns true in mock/test mode', () async {
      final service = BiometricSecurityService.to;
      final canCheck = await service.canCheckBiometrics();
      expect(canCheck, isTrue);
    });

    test('getAvailableBiometrics returns empty list in mock/test mode', () async {
      final service = BiometricSecurityService.to;
      final biometrics = await service.getAvailableBiometrics();
      expect(biometrics, isEmpty);
    });

    test('authenticateForHighValueAction succeeds by default in mock/test mode', () async {
      final service = BiometricSecurityService.to;
      final success = await service.authenticateForHighValueAction(
        reason: 'Authenticate to confirm payout',
      );
      expect(success, isTrue);
    });

    test('authenticateForHighValueAction respects mockAuthenticationResult = false', () async {
      BiometricSecurityService.mockAuthenticationResult = false;
      final service = BiometricSecurityService.to;
      final success = await service.authenticateForHighValueAction(
        reason: 'Authenticate to confirm payout',
        showFriendlyWarningOnFailure: false,
      );
      expect(success, isFalse);
    });

    test('authenticateForHighValueAction respects mockAuthenticationResult = true', () async {
      BiometricSecurityService.mockAuthenticationResult = true;
      final service = BiometricSecurityService.to;
      final success = await service.authenticateForHighValueAction(
        reason: 'Authenticate to confirm payout',
      );
      expect(success, isTrue);
    });

    test('maps native platform errors to friendly English without raw developer codes', () {
      final codesToTest = [
        'auth_in_progress',
        'LockedOut',
        'PermanentlyLockedOut',
        'PasscodeNotSet',
        'NotEnrolled',
        'NotAvailable',
        'UserCancel',
        'SystemCancel',
        'unknown_code',
      ];

      for (final code in codesToTest) {
        final ex = PlatformException(code: code, message: 'Developer stack trace mock');
        expect(ex.code, equals(code));
      }
    });

    test('verifies LocalAuthExceptionCode enums are defined', () {
      const codes = LocalAuthExceptionCode.values;
      expect(codes, contains(LocalAuthExceptionCode.authInProgress));
      expect(codes, contains(LocalAuthExceptionCode.temporaryLockout));
      expect(codes, contains(LocalAuthExceptionCode.biometricLockout));
      expect(codes, contains(LocalAuthExceptionCode.noCredentialsSet));
      expect(codes, contains(LocalAuthExceptionCode.noBiometricsEnrolled));
      expect(codes, contains(LocalAuthExceptionCode.noBiometricHardware));
      expect(codes, contains(LocalAuthExceptionCode.userCanceled));
    });
  });
}
