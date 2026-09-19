import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_sidebar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  final testChannel = Channel(
    id: 'test_channel_123',
    name: 'Truth Creator Studio Channel',
    nameLowercase: 'truth creator studio channel',
    handle: '@truthstudio',
    handleLowercase: '@truthstudio',
    description: 'Test channel description for dashboard testing',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'test_owner_123',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setMobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('DashboardFallbackLogin Tests', () {
    testWidgets('renders login screen with white icons and handles sign in tap',
        (tester) async {
      var signInTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardFallbackLogin(
            onSignIn: () => signInTapped = true,
          ),
        ),
      );

      expect(find.text('Creator Studio'), findsOneWidget);
      expect(
        find.text('Please sign in to access your Creator Studio dashboard.'),
        findsOneWidget,
      );
      expect(find.text('Sign In with Google'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.dashboard_rounded));
      expect(icon.color, equals(Colors.white));

      await tester.tap(find.text('Sign In with Google'));
      await tester.pump();
      expect(signInTapped, isTrue);
    });
  });

  group('DashboardViewController Tests', () {
    testWidgets(
        'initializes animations, resolves channel, and cleans up on close',
        (tester) async {
      final ctrl = Get.put(DashboardViewController());
      expect(ctrl.isSelectingDefault.value, isFalse);
      expect(ctrl.staggeredAnimationController, isNotNull);
      expect(ctrl.drawerAnimationController, isNotNull);
      expect(ctrl.statsAnimationController, isNotNull);
      expect(ctrl.chartAnimationController, isNotNull);

      expect(ctrl.getChannelId(testChannel), equals('test_channel_123'));
      expect(ctrl.getOwnerId(testChannel), equals('test_owner_123'));
      expect(ctrl.getChannelName(testChannel),
          equals('Truth Creator Studio Channel'));

      Get.delete<DashboardViewController>();
    });
  });

  group('DashboardScreen Responsive & Navigation Tests', () {
    testWidgets('renders unauthenticated fallback when authService is false',
        (tester) async {
      setDesktopSize(tester);
      AuthService.to.isAuthenticated.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(DashboardFallbackLogin), findsOneWidget);
    });

    testWidgets('renders desktop scaffold with app bar and sidebar',
        (tester) async {
      setDesktopSize(tester);
      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      final dashboardCtrl =
          Get.put(DashboardController(channelId: 'test_channel_123'));
      final viewCtrl = Get.put(DashboardViewController());
      viewCtrl.isSelectingDefault.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(DashboardCreatorAppBar), findsOneWidget);
      expect(find.byType(DashboardDesktopSidebar), findsOneWidget);
      expect(find.byType(DashboardViewRouter), findsOneWidget);
      expect(find.text('Creator Studio'), findsOneWidget);

      // Verify search field interaction
      await tester.enterText(find.byType(TextField).first, 'truth video');
      await tester.pump();
      expect(dashboardCtrl.searchQuery.value, equals('truth video'));
    });

    testWidgets('renders mobile layout without desktop sidebar',
        (tester) async {
      setMobileSize(tester);
      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      final viewCtrl = Get.put(DashboardViewController());
      viewCtrl.isSelectingDefault.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(DashboardCreatorAppBar), findsOneWidget);
      expect(find.byType(DashboardDesktopSidebar), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
    });

    testWidgets('switches to trash restore tab via DashboardViewRouter',
        (tester) async {
      setDesktopSize(tester);
      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      final dashboardCtrl =
          Get.put(DashboardController(channelId: 'test_channel_123'));
      final viewCtrl = Get.put(DashboardViewController());
      viewCtrl.isSelectingDefault.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      dashboardCtrl.selectedIndex.value = 13; // TrashRestoreScreen
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TrashRestoreScreen), findsOneWidget);
    });
  });
}
