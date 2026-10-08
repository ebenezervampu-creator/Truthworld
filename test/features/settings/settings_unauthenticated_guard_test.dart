import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/models/home_sidebar_visibility.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_side_navigation_rail.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_subpage_router.dart';
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart';
import 'package:truthworld/theme/app_theme.dart';

import '../../test_helpers/mock_firebase.dart';

class MockHomeController extends GetxController implements HomeController {
  @override
  final RxInt sideNavSelectedIndex = 0.obs;

  bool signInSnackbarShown = false;

  @override
  void showSignInSnackbar() {
    signInSnackbarShown = true;
  }

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
    Get.put<AuthService>(AuthService());
    Get.put<ConnectivityService>(ConnectivityService());
  });

  tearDown(Get.reset);

  group('Settings Unauthenticated Guard Tests across all devices', () {
    test('1. HomeSidebarVisibility completely hides Settings for unsigned users', () {
      final unsignedItems = HomeSidebarVisibility.getVisibleEntries(
        isAuthenticated: false,
      );
      expect(unsignedItems, isNot(contains('Settings')));

      final signedInItems = HomeSidebarVisibility.getVisibleEntries(
        isAuthenticated: true,
      );
      expect(signedInItems, contains('Settings'));
    });

    testWidgets('2. ModernSideNavigationRail never shows Settings under SUPPORT for unsigned users',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MockHomeController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ModernSideNavigationRail(
              selectedIndex: 0,
              onSelectItem: controller.onSideNavItemSelect,
              onShowSignInSnackbar: controller.showSignInSnackbar,
              currentUser: null,
              homeController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SUPPORT'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('About Truthworld'), findsOneWidget);
    });

    testWidgets('3. SettingsScreen renders SettingsUnauthenticatedView and never shows settings content or logout for unsigned users',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // User is explicitly not authenticated
      expect(AuthService.to.isAuthenticated.value, isFalse);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Must display unauthenticated barrier
      expect(find.byType(SettingsUnauthenticatedView), findsOneWidget);
      expect(find.text('Sign In to Access Settings'), findsOneWidget);
      expect(find.text('Sign In to Continue'), findsOneWidget);

      // Must NEVER display user account, fake LIVE status, or Log Out
      expect(find.text('Log Out'), findsNothing);
      expect(find.text('LIVE'), findsNothing);
      expect(find.text('General & Account'), findsNothing);
      expect(find.text('Free Account Tier'), findsNothing);
      expect(find.text('Digital Wellbeing & Screen Time'), findsNothing);
    });

    testWidgets('4. GeneralAccountSection returns SizedBox.shrink() when user is unsigned',
        (tester) async {
      expect(AuthService.to.isAuthenticated.value, isFalse);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: GeneralAccountSection(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('General & Account'), findsNothing);
      expect(find.text('Log Out'), findsNothing);
      expect(find.text('Age Group & Gender'), findsNothing);
    });

    testWidgets('5. HomeSubPageRouter blocks indexSettings and redirects to Home Feed for unsigned users',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MockHomeController();
      controller.sideNavSelectedIndex.value = HomeController.indexSettings;
      expect(AuthService.to.isAuthenticated.value, isFalse);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: HomeSubPageRouter.buildSubPage(
                  context,
                  controller,
                  HomeController.indexSettings,
                ),
              );
            },
          ),
        ),
      );
      // Pump frames to let post-frame callback execute
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Router must redirect controller back to indexHome and show sign in snackbar
      expect(controller.sideNavSelectedIndex.value, equals(HomeController.indexHome));
      expect(controller.signInSnackbarShown, isTrue);

      // Must never display Settings page content
      expect(find.text('General & Account'), findsNothing);
      expect(find.text('Log Out'), findsNothing);
    });
  });
}
