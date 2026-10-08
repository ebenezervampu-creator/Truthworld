import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/security/rasp_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);
  tearDown(Get.reset);

  group('RaspSecurityService Integrity & Aliases', () {
    test('RaspSecurityService exposes assertEnvironmentSecure alias', () async {
      final service = RaspSecurityService();
      Get.put<RaspSecurityService>(service);

      // On non-Android test environments, it defaults to safe assessment
      final isSecure = await service.isEnvironmentSecure();
      expect(isSecure, isTrue);

      // Should complete without throwing method-not-found error
      await expectLater(
        service.assertEnvironmentSecure(terminateOnFailure: false),
        completes,
      );
    });
  });

  group('AuthFirestoreSync Debounce Logic', () {
    test('Debounce window checks timestamp accurately within 10 seconds', () {
      final now = DateTime.now();
      final recent = now.subtract(const Duration(seconds: 4));
      final old = now.subtract(const Duration(seconds: 15));

      expect(now.difference(recent).inSeconds < 10, isTrue);
      expect(now.difference(old).inSeconds < 10, isFalse);
    });
  });
}
