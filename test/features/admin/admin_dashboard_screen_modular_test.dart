import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/admin_dashboard_screen.dart';

import '../../test_helpers/mock_firebase.dart';

class TestAdminController extends AdminController {
  bool refreshCalled = false;

  @override
  // ignore: must_call_super
  void onInit() {
    // Avoid starting live Firestore Pigeon streams in widget test environment
  }

  @override
  void ensureSubscriptionsStarted() {
    // Avoid starting live Firestore Pigeon streams in widget test environment
  }

  @override
  Future<void> refreshAllData() async {
    refreshCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  late TestAdminController controller;

  setUp(() {
    Get.reset();
    controller = Get.put<AdminController>(TestAdminController()) as TestAdminController;
    controller.isAdmin.value = true;
    controller.currentAdminEmail.value = 'admin@truthworld.com';
    controller.currentAdminRole.value = 'Super Admin';
    controller.currentAdminRoles.assignAll(['Super Admin']);
  });

  tearDown(Get.reset);

  group('AdminBulkActionBar Tests', () {
    testWidgets('Renders selected count and responds to clear selection', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      controller.selectedItemIds.assignAll(['item_1', 'item_2', 'item_3']);
      controller.currentTab.value = 'videos';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AdminBulkActionBar(controller: controller),
          ),
        ),
      );

      expect(find.text('3 selected'), findsOneWidget);
      expect(find.text('Deselect All'), findsOneWidget);
      expect(find.text('Bulk Reject'), findsOneWidget);
      expect(find.text('Bulk Approve'), findsOneWidget);

      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      expect(controller.selectedItemIds.isEmpty, isTrue);
    });
  });

  group('AdminMobileBottomNavBar Tests', () {
    testWidgets('Renders navigation items and handles drawer open callback', (tester) async {
      var drawerOpened = false;
      controller.pendingVideos.value = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AdminMobileBottomNavBar(
              controller: controller,
              onOpenDrawer: () => drawerOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Appeals'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      await tester.tap(find.text('More'));
      await tester.pump();
      expect(drawerOpened, isTrue);
    });
  });

  group('AdminHeader Tests', () {
    testWidgets('Renders dynamic title according to active tab and action icons', (tester) async {
      controller.currentTab.value = 'videos';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AdminHeader(
              controller: controller,
              isDesktop: true,
              onOpenDrawer: () {},
            ),
          ),
        ),
      );

      expect(find.text('Video Verification Queue'), findsOneWidget);
      expect(find.byIcon(Icons.key_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Reactively changes title
      controller.currentTab.value = 'channels';
      await tester.pump();
      expect(find.text('Channel Verification Queue'), findsOneWidget);
    });
  });

  group('AdminSidebar & NavItem Tests', () {
    testWidgets('Sidebar displays Console branding, sections, and user email', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      controller.pendingVideos.value = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSidebar(controller: controller),
          ),
        ),
      );

      expect(find.text('TruthWorld'), findsOneWidget);
      expect(find.text('Console'), findsOneWidget);
      expect(find.text('MANAGEMENT'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
      expect(find.text('admin@truthworld.com'), findsOneWidget);

      // Nav item selection changes tab
      await tester.tap(find.text('Topics Queue'));
      await tester.pump();
      expect(controller.currentTab.value, 'topics');
    });
  });

  group('AdminTabRouter Tests', () {
    testWidgets('Resolves tab widgets correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AdminTabRouter.buildTabForId('videos', context, controller),
            ),
          ),
        ),
      );

      expect(find.byType(VideoQueueTab), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AdminTabRouter.buildTabForId('dashboard', context, controller),
            ),
          ),
        ),
      );

      expect(find.byType(OverviewTab), findsOneWidget);
    });
  });

  group('AdminDashboardScreen Coordinator Tests', () {
    testWidgets('AdminDashboardScreen mounts cleanly without uncaught exceptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(),
        ),
      );

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byType(AdminHeader), findsOneWidget);
    });
  });
}
