import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  group('DigitalWellbeingService', () {
    test('initializes and handles break timer reset and snooze', () {
      final service = DigitalWellbeingService();
      Get.put(service);

      expect(service.activeWatchSeconds, equals(0));
      expect(service.isBreakPromptOpen, isFalse);

      service.snoozeBreakTimer();
      expect(service.isBreakPromptOpen, isFalse);

      service.resetBreakTimer();
      expect(service.activeWatchSeconds, equals(0));
    });
  });
}
