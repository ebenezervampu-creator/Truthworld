import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';
import 'package:truthworld/features/settings/data/models/digital_wellbeing_settings.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

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

    test('handles bedtime snooze and dismiss lifecycle', () {
      final service = DigitalWellbeingService();
      Get.put(service);

      expect(service.isBedtimeSnoozed, isFalse);
      expect(service.activeBedtimeSessionKey, isNull);

      service.snoozeBedtimeReminder();
      expect(service.isBedtimeSnoozed, isTrue);

      service.resetBedtimeTracking();
      expect(service.isBedtimeSnoozed, isFalse);
      expect(service.activeBedtimeSessionKey, isNull);
    });

    test('returns correct autoplay and notification status based on settings', () {
      final settingsController = UserSettingsController();
      Get.put(settingsController);

      final service = DigitalWellbeingService();
      Get.put(service);

      // When bedtime is disabled
      settingsController.updateWellbeing(
        const DigitalWellbeingSettings(),
      );

      expect(service.isBedtimeActive(), isFalse);
      expect(service.shouldPauseAutoplayDuringBedtime(), isFalse);
      expect(service.shouldMuteNotificationsDuringBedtime(), isFalse);

      // When bedtime is enabled covering entire 24h
      settingsController.updateWellbeing(
        const DigitalWellbeingSettings(
          bedtimeEnabled: true,
          bedtimeStartTime: '00:00',
          bedtimeEndTime: '23:59',
        ),
      );

      expect(service.isBedtimeActive(), isTrue);
      expect(service.shouldPauseAutoplayDuringBedtime(), isTrue);
      expect(service.shouldMuteNotificationsDuringBedtime(), isTrue);

      // When options are toggled off
      settingsController.toggleBedtimeAutoplay(false);
      settingsController.toggleBedtimeMuteNotifications(false);

      expect(service.shouldPauseAutoplayDuringBedtime(), isFalse);
      expect(service.shouldMuteNotificationsDuringBedtime(), isFalse);
    });
  });
}
