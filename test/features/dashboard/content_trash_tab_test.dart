import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_sidebar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
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

  group('ContentScreen Trash Tab & Studio Sidebar Integration Tests', () {
    testWidgets('ContentScreen has 5 tabs and Trash is one of them',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      Get.put(VideoManagementController());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ContentScreen(
              channelId: 'test_channel_123',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify all 5 tab texts exist
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);

      // Verify TabBar length is 5
      final tabBars = tester.widgetList<TabBar>(find.byType(TabBar));
      expect(tabBars.first.tabs.length, equals(5));

      // Tap on Trash tab
      await tester.tap(find.text('Trash'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify TrashRestoreScreen is rendered inside ContentScreen
      expect(find.byType(TrashRestoreScreen), findsOneWidget);
      expect(find.text('Trash & Restoration'), findsOneWidget);

      // Verify Trash filter chips (All, Video, Post, Topic, Playlist) and absence of Channel filter
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Video'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Post'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Topic'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Playlist'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Channel'), findsNothing);

      // Verify description contains videos, community posts, topics, playlists
      expect(
        find.text(
          'Deleted videos, community posts, topics, and playlists are retained for 30 days before permanent deletion.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('DashboardSidebar no longer contains Trash & Recovery',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dashboardCtrl =
          Get.put(DashboardController(channelId: 'test_channel_123'));
      Get.put(DashboardViewController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DashboardSidebarMenu(
              controller: dashboardCtrl,
              isDarkMode: true,
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Verify 'Trash & Recovery' is NOT in sidebar
      expect(find.text('Trash & Recovery'), findsNothing);
    });

    test('TrashRestoreController calculates 30-day retention grace period correctly', () {
      final controller = TrashRestoreController(channelId: 'test_channel_123');

      final justDeleted = DateTime.now();
      expect(controller.getRemainingDays(justDeleted), equals(30));

      final deleted10DaysAgo = DateTime.now().subtract(const Duration(days: 10));
      expect(controller.getRemainingDays(deleted10DaysAgo), equals(20));

      final deleted30DaysAgo = DateTime.now().subtract(const Duration(days: 30));
      expect(controller.getRemainingDays(deleted30DaysAgo), equals(0));

      final deleted45DaysAgo = DateTime.now().subtract(const Duration(days: 45));
      expect(controller.getRemainingDays(deleted45DaysAgo), equals(0));
    });
  });
}
