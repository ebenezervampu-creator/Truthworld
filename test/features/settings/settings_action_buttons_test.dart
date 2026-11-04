import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/accessibility_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/advanced_diagnostics_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/downloads_storage_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/general_account_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/legal_about_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/playback_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/wellbeing_section.dart';
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

import '../../test_helpers/mock_firebase.dart';

class MockAuthService extends AuthService {
  @override
  final RxBool isAuthenticated = true.obs;
  @override
  String get uid => 'test_user_id';
  @override
  void onInit() {}
}

class MockHomeController extends GetxController implements HomeController {
  @override
  final RxInt sideNavSelectedIndex = 0.obs;

  @override
  void onSideNavItemSelect(int index) {
    sideNavSelectedIndex.value = index;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    final auth = MockAuthService();
    Get.put<AuthService>(auth, permanent: true);
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<UserSettingsController>(UserSettingsController(), permanent: true);

    auth.userEmail.value = 'user@example.com';
    auth.userDisplayName.value = 'Test User';
  });

  tearDown(Get.reset);

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Settings Action Buttons Audit Tests', () {
    testWidgets('1. SettingsScreen leading back button pops if canPop is true',
        (tester) async {
      setLargeScreen(tester);
      var didPop = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Navigator(
            pages: [
              const MaterialPage(child: Scaffold(body: Text('Previous Page'))),
              MaterialPage(
                child: const SettingsScreen(isDashboard: false),
                onPopInvoked: (didPopRoute, result) {
                  didPop = true;
                },
              ),
            ],
            onDidRemovePage: (page) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });

    testWidgets('2. LegalAboutSection pushes standalone routes when isDashboard is false',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          initialRoute: '/settings',
          getPages: [
            GetPage(
              name: '/settings',
              page: () => const Scaffold(
                body: SingleChildScrollView(
                  child: LegalAboutSection(isDashboard: false),
                ),
              ),
            ),
            GetPage(name: AppRoutes.about, page: () => const Scaffold(body: Text('About Page Content'))),
            GetPage(name: AppRoutes.privacy, page: () => const Scaffold(body: Text('Privacy Page Content'))),
            GetPage(name: AppRoutes.terms, page: () => const Scaffold(body: Text('Terms Page Content'))),
            GetPage(name: AppRoutes.communityGuidelines, page: () => const Scaffold(body: Text('Guidelines Page Content'))),
            GetPage(name: AppRoutes.feedback, page: () => const Scaffold(body: Text('Feedback Page Content'))),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap About TruthWorld
      await tester.tap(find.text('About TruthWorld'));
      await tester.pumpAndSettle();
      expect(find.text('About Page Content'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();

      // Tap Terms & Conditions
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();
      expect(find.text('Terms Page Content'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();

      // Tap Privacy Policy
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Page Content'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();

      // Tap Feedback
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback Page Content'), findsOneWidget);
    });

    testWidgets('3. GeneralAccountSection: Account Status dialog and Cancel action',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: GeneralAccountSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Account Deactivation & Status
      final statusTile = find.text('Account Deactivation & Status');
      expect(statusTile, findsOneWidget);
      await tester.tap(statusTile);
      await tester.pumpAndSettle();

      // Verify Account Status Options dialog opens
      expect(find.text('Account Status Options'), findsOneWidget);
      expect(find.text('Deactivate Account'), findsOneWidget);
      expect(find.text('Delete Account Permanently'), findsOneWidget);

      // Verify Cancel button exists and dismisses dialog
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Account Status Options'), findsNothing);
    });

    testWidgets('4. GeneralAccountSection: Deactivate Account confirmation dialog and Cancel action',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: GeneralAccountSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open status options
      await tester.tap(find.text('Account Deactivation & Status'));
      await tester.pumpAndSettle();

      // Select Deactivate Account
      await tester.tap(find.text('Deactivate Account'));
      await tester.pumpAndSettle();

      // Deactivation confirmation dialog
      expect(find.text('Deactivate Account'), findsWidgets);
      expect(find.text('Are you sure you want to deactivate your account? Your channel, public profile, and activity will be hidden until you sign back in. You can reactivate anytime simply by logging back in.'), findsOneWidget);

      // Tap Cancel
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to deactivate your account? Your channel, public profile, and activity will be hidden until you sign back in. You can reactivate anytime simply by logging back in.'), findsNothing);
    });

    testWidgets('5. GeneralAccountSection: Log Out confirmation dialog and Cancel action',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: GeneralAccountSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logoutTile = find.text('Log Out');
      expect(logoutTile, findsOneWidget);
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      // Verify Log Out Confirmation Dialog
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);

      // Verify Cancel button dismisses
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsNothing);
    });

    testWidgets('6. DownloadsStorageSection: Clear Cache confirmation dialog and Cancel action',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DownloadsStorageSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Clear Cached Media Data
      final clearCacheTile = find.text('Clear Cached Media Data');
      expect(clearCacheTile, findsOneWidget);
      await tester.tap(clearCacheTile);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Clear Cached Media Data?'), findsOneWidget);

      // Tap Cancel
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Clear Cached Media Data?'), findsNothing);
    });

    testWidgets('7. DownloadsStorageSection: Storage Limit and Download Quality dialog Cancel actions',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DownloadsStorageSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Download Quality
      await tester.tap(find.text('Download Quality'));
      await tester.pumpAndSettle();
      expect(find.text('Default Download Quality'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Default Download Quality'), findsNothing);

      // Tap Download Storage Limit
      await tester.tap(find.text('Download Storage Limit'));
      await tester.pumpAndSettle();
      expect(find.text('Max Storage Limit'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Max Storage Limit'), findsNothing);
    });

    testWidgets('8. WellbeingSection: Break Reminder and Parental Lock dialog Cancel actions',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: WellbeingSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Remind me to take a break
      await tester.tap(find.text('Remind me to take a break'));
      await tester.pumpAndSettle();
      expect(find.text('Take a Break Reminder'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Take a Break Reminder'), findsNothing);

      // Tap Parental Controls & PIN Lock
      await tester.tap(find.text('Parental Controls & PIN Lock'));
      await tester.pumpAndSettle();
      expect(find.text('Setup Parental PIN Lock'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Setup Parental PIN Lock'), findsNothing);
    });

    testWidgets('9. PlaybackSection: Volume Normalization, Background Playback, Seek Duration Cancel actions',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PlaybackSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Volume Normalization (Stable Volume)
      await tester.tap(find.text('Volume Normalization (Stable Volume)'));
      await tester.pumpAndSettle();
      expect(find.text('Stable Volume Normalization'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Stable Volume Normalization'), findsNothing);

      // Tap Double-Tap Seek Duration
      await tester.tap(find.text('Double-Tap Seek Duration'));
      await tester.pumpAndSettle();
      expect(find.text('Seek Duration'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Seek Duration'), findsNothing);
    });

    testWidgets('10. AccessibilitySection: Captions dialog Done action and Colorblind Cancel action',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AccessibilitySection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Subtitles & Captions Customization
      await tester.tap(find.text('Subtitles & Captions Customization'));
      await tester.pumpAndSettle();
      expect(find.text('Captions Customization'), findsOneWidget);

      // Tap Done
      final doneButton = find.widgetWithText(TextButton, 'Done');
      expect(doneButton, findsOneWidget);
      await tester.tap(doneButton);
      await tester.pumpAndSettle();
      expect(find.text('Captions Customization'), findsNothing);

      // Tap Color Blindness Filter Mode
      await tester.tap(find.text('Color Blindness Filter Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Color Blind Support Mode'), findsOneWidget);

      // Tap Cancel
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      expect(find.text('Color Blind Support Mode'), findsNothing);
    });

    testWidgets('11. AdvancedDiagnosticsSection: Reset Options and Factory Reset Cancel actions',
        (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AdvancedDiagnosticsSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reset Settings to Defaults
      await tester.tap(find.text('Reset Settings to Defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Settings Options'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Settings Options'), findsNothing);

      // Open again to test Factory Reset confirmation
      await tester.tap(find.text('Reset Settings to Defaults'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Factory Reset ALL Settings'));
      await tester.pumpAndSettle();

      // Factory reset confirmation dialog
      expect(find.text('Factory Reset All Settings?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Factory Reset All Settings?'), findsNothing);
    });
  });
}
