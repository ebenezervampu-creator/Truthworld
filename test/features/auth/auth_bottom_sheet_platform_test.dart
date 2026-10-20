import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/components/ui/auth/auth_sheet_controller.dart';
import 'package:truthworld/components/ui/auth/phone_verification_sheet.dart';
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

  Widget buildTestableWidget({
    TargetPlatform? platformOverride,
    bool? isWebOverride,
    TargetPlatform? themePlatform,
    AuthStep initialStep = AuthStep.options,
  }) {
    return GetMaterialApp(
      theme: ThemeData(
        platform: themePlatform ?? TargetPlatform.android,
      ),
      home: Scaffold(
        body: AuthBottomSheet(
          platformOverride: platformOverride,
          isWebOverride: isWebOverride,
          initialStep: initialStep,
        ),
      ),
    );
  }

  group('AuthBottomSheet Platform Sign Providers Tests', () {
    testWidgets('1. Android shows ONLY Google Sign-In (no Apple, no Phone button)',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(platformOverride: TargetPlatform.android),
      );
      await tester.pumpAndSettle();

      // Verify Google Sign-In button is present
      expect(find.byKey(const Key('auth_google_button')), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Verify Phone Sign-In button is NOT present
      expect(find.byKey(const Key('auth_phone_button')), findsNothing);
      expect(find.text('Continue with Phone'), findsNothing);

      // Verify Apple Sign-In button is NOT present
      expect(find.byKey(const Key('auth_apple_button')), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
    });

    testWidgets('2. iOS / iPhone shows ONLY Apple Sign-In (no Google, no Phone button)',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(platformOverride: TargetPlatform.iOS),
      );
      await tester.pumpAndSettle();

      // Verify Apple Sign-In button is present
      expect(find.byKey(const Key('auth_apple_button')), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);

      // Verify Phone Sign-In button is NOT present
      expect(find.byKey(const Key('auth_phone_button')), findsNothing);
      expect(find.text('Continue with Phone'), findsNothing);

      // Verify Google Sign-In button is NOT present
      expect(find.byKey(const Key('auth_google_button')), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('3. macOS shows ONLY Apple Sign-In (no Google, no Phone button)',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(platformOverride: TargetPlatform.macOS),
      );
      await tester.pumpAndSettle();

      // Verify Apple Sign-In button is present
      expect(find.byKey(const Key('auth_apple_button')), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);

      // Verify Phone Sign-In button is NOT present
      expect(find.byKey(const Key('auth_phone_button')), findsNothing);
      expect(find.text('Continue with Phone'), findsNothing);

      // Verify Google Sign-In button is NOT present
      expect(find.byKey(const Key('auth_google_button')), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('4. Web shows ONLY Google Sign-In (no Apple, no Phone button)',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(isWebOverride: true),
      );
      await tester.pumpAndSettle();

      // Verify Google Sign-In button is present
      expect(find.byKey(const Key('auth_google_button')), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Verify Phone Sign-In button is NOT present
      expect(find.byKey(const Key('auth_phone_button')), findsNothing);
      expect(find.text('Continue with Phone'), findsNothing);

      // Verify Apple Sign-In button is NOT present
      expect(find.byKey(const Key('auth_apple_button')), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
    });

    testWidgets('5. Automatically respects Theme.of(context).platform for Android',
        (tester) async {
      // Without explicit platformOverride, falls back to ambient theme platform (Android)
      await tester.pumpWidget(
        buildTestableWidget(themePlatform: TargetPlatform.android),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth_google_button')), findsOneWidget);
      expect(find.byKey(const Key('auth_phone_button')), findsNothing);
      expect(find.byKey(const Key('auth_apple_button')), findsNothing);
    });

    testWidgets('6. Automatically respects Theme.of(context).platform for iOS',
        (tester) async {
      // Without explicit platformOverride, falls back to ambient theme platform (iOS)
      await tester.pumpWidget(
        buildTestableWidget(themePlatform: TargetPlatform.iOS),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth_apple_button')), findsOneWidget);
      expect(find.byKey(const Key('auth_phone_button')), findsNothing);
      expect(find.byKey(const Key('auth_google_button')), findsNothing);
    });

    testWidgets('7. User can add and verify phone number later using PhoneVerificationSheet',
        (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: PhoneVerificationSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify phone verification screen is displayed with phone input and CTA
      expect(find.text('Verify Phone Number'), findsOneWidget);
      expect(
        find.text('Enter your mobile number to receive a 6-digit verification code.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('8. Default AuthBottomSheet displays language selection and progresses to Google on selecting English',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          platformOverride: TargetPlatform.android,
          initialStep: AuthStep.languageSelection,
        ),
      );
      await tester.pumpAndSettle();

      // Verify language selection view is displayed
      expect(find.text('Welcome to TruthWorld'), findsOneWidget);
      expect(find.text('Please select your primary language to continue.'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);

      // Tap English language tile
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Verify transitioned to options with Google Sign-In
      expect(find.byKey(const Key('auth_google_button')), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Primary Language: English'), findsOneWidget);
    });
  });
}
