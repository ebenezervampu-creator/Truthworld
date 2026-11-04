import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put(AuthService());
  });

  tearDown(Get.reset);

  group('Direct Platform Sign-In Tests (Welcome to TruthWorld Modal Removed)', () {
    testWidgets('Tapping sign in calls AuthService.prompt which triggers direct platform sign-in',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('test_signin_button'),
                onPressed: () {
                  AuthService.prompt(Get.context);
                },
                child: const Text('Sign In to Continue'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In button
      await tester.tap(find.byKey(const Key('test_signin_button')));
      await tester.pump();

      // Verify that the "Welcome to TruthWorld" modal is NOT presented anywhere
      expect(find.text('Welcome to TruthWorld'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Calling AuthService.to.triggerPlatformSignIn() never presents a bottom sheet',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('test_direct_button'),
                onPressed: () {
                  AuthService.to.triggerPlatformSignIn(
                    platformOverride: TargetPlatform.android,
                    isWebOverride: false,
                  );
                },
                child: const Text('Direct Sign In'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap direct sign in button
      await tester.tap(find.byKey(const Key('test_direct_button')));
      await tester.pump();

      expect(find.text('Welcome to TruthWorld'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
