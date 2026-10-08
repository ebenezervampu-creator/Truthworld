import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/security/screen_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    ScreenSecurityService.enableNativeChannel = false;
  });

  tearDown(() {
    ScreenSecurityService.enableNativeChannel = true;
  });

  group('ScreenSecurityService (FLAG_SECURE) Tests', () {
    test('initializes with secure mode disabled by default', () {
      final service = Get.put(ScreenSecurityService());
      expect(service.isSecureMode.value, isFalse);
    });

    test('enableSecureMode activates secure mode', () async {
      final service = Get.put(ScreenSecurityService());
      final result = await service.enableSecureMode();
      expect(result, isTrue);
      expect(service.isSecureMode.value, isTrue);
    });

    test('disableSecureMode deactivates secure mode', () async {
      final service = Get.put(ScreenSecurityService());
      await service.enableSecureMode();
      expect(service.isSecureMode.value, isTrue);

      final result = await service.disableSecureMode();
      expect(result, isTrue);
      expect(service.isSecureMode.value, isFalse);
    });

    test('isSecureModeEnabled reflects current state', () async {
      final service = Get.put(ScreenSecurityService());
      expect(await service.isSecureModeEnabled(), isFalse);

      await service.enableSecureMode();
      expect(await service.isSecureModeEnabled(), isTrue);

      await service.disableSecureMode();
      expect(await service.isSecureModeEnabled(), isFalse);
    });

    test('protectSensitiveOperation enables secure mode during execution and restores state', () async {
      final service = Get.put(ScreenSecurityService());
      expect(service.isSecureMode.value, isFalse);

      var wasProtectedDuringExecution = false;

      final output = await service.protectSensitiveOperation(() async {
        wasProtectedDuringExecution = service.isSecureMode.value;
        return 'transaction_complete';
      });

      expect(output, equals('transaction_complete'));
      expect(wasProtectedDuringExecution, isTrue);
      expect(service.isSecureMode.value, isFalse);
    });

    test('protectSensitiveOperation restores secure mode state even on error', () async {
      final service = Get.put(ScreenSecurityService());
      expect(service.isSecureMode.value, isFalse);

      try {
        await service.protectSensitiveOperation(() async {
          throw Exception('Payment network drop');
        });
      } catch (_) {
        // Expected test exception
      }

      expect(service.isSecureMode.value, isFalse);
    });
  });
}
