import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/guest_playback_limit_service.dart';

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
    final storage = GetStorage();
    storage.erase();
  });

  tearDown(() {
    Get.reset();
  });

  group('GuestPlaybackLimitService', () {
    test('initializes with 10-minute (600s) default quota for guest user', () {
      final auth = Get.put(AuthService());
      auth.isAuthenticated.value = false;

      final service = Get.put(GuestPlaybackLimitService());

      expect(service.remainingSeconds.value, equals(600));
      expect(service.totalWatchedSeconds.value, equals(0));
      expect(service.isLimitReached.value, isFalse);
      expect(service.isPlaybackAllowed(), isTrue);
    });

    test('enforces limit when 600 seconds is reached', () {
      final auth = Get.put(AuthService());
      auth.isAuthenticated.value = false;

      final service = Get.put(GuestPlaybackLimitService());

      // Fast-forward watch time to 600s
      service.totalWatchedSeconds.value = 600;
      service.remainingSeconds.value = 0;
      service.isLimitReached.value = true;

      expect(service.isPlaybackAllowed(), isFalse);
      expect(service.remainingSeconds.value, equals(0));
    });

    test('signed-in users are permitted unlimited playback even if guest quota was exhausted', () {
      final auth = Get.put(AuthService());
      auth.isAuthenticated.value = false;

      final service = Get.put(GuestPlaybackLimitService());

      // Exhaust guest quota
      service.remainingSeconds.value = 0;
      service.isLimitReached.value = true;
      expect(service.isPlaybackAllowed(), isFalse);

      // User signs in
      auth.isAuthenticated.value = true;

      expect(service.isPlaybackAllowed(), isTrue);
      expect(service.isLimitReached.value, isFalse);
    });

    testWidgets('GuestPlaybackBarrierOverlay renders descending countdown timer after 5 minutes, then login barrier at 10 minutes', (tester) async {
      final auth = Get.put(AuthService());
      auth.isAuthenticated.value = false;

      final service = Get.put(GuestPlaybackLimitService());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GuestPlaybackBarrierOverlay(),
              ],
            ),
          ),
        ),
      );

      // Phase 1: First 5 minutes (e.g. 450s remaining) -> No timer, clean surface
      service.remainingSeconds.value = 450;
      await tester.pumpAndSettle();
      expect(find.textContaining('Preview ends in'), findsNothing);
      expect(find.text('10-Minute Free Preview Ended'), findsNothing);

      // Phase 2: After using > 5 minutes (<= 300s remaining, e.g. 240s = 04:00) -> Countdown timer pill visible
      service.remainingSeconds.value = 240;
      await tester.pumpAndSettle();
      expect(find.text('Preview ends in 04:00'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('10-Minute Free Preview Ended'), findsNothing);

      // Phase 3: At 10 minutes (remaining = 0, isLimitReached = true) -> Smooth transition to full barrier
      service.isLimitReached.value = true;
      service.remainingSeconds.value = 0;
      await tester.pumpAndSettle();

      // Countdown pill transitions into full login barrier
      expect(find.textContaining('Preview ends in'), findsNothing);
      expect(find.text('10-Minute Free Preview Ended'), findsOneWidget);
      expect(find.text('Sign In to Continue'), findsOneWidget);

      // Phase 4: User signs in -> All barriers disappear
      auth.isAuthenticated.value = true;
      await tester.pumpAndSettle();

      expect(find.text('10-Minute Free Preview Ended'), findsNothing);
      expect(find.textContaining('Preview ends in'), findsNothing);
    });
  });
}
