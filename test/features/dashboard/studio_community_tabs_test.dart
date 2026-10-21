import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_sidebar.dart';
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
    id: 'SmaXftbr4DpDM60458Ig',
    name: 'Ebenezer Vampu',
    nameLowercase: 'ebenezer vampu',
    handle: '@ebenezervampu',
    handleLowercase: '@ebenezervampu',
    description: 'Creator channel for studio test',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'oj3JOhUbOvZHjWmzFpXBVDB1vap1',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  group('Studio ContentScreen Community & Sidebar Allocation Tests', () {
    testWidgets('ContentScreen has 5 clear tabs with Community tab at index 1',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      final vmController = Get.put(VideoManagementController());
      vmController.isLoadingPosts.value = false;
      vmController.isLoadingChannelVideos.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ContentScreen(
              channelId: 'SmaXftbr4DpDM60458Ig',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify all 5 tab texts exist cleanly in ContentScreen
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);

      // Verify TabBar is rendered without nested AppBar
      expect(find.byType(TabBar), findsOneWidget);

      final tabBars = tester.widgetList<TabBar>(find.byType(TabBar));
      expect(tabBars.first.tabs.length, equals(5));
      expect(tabBars.first.isScrollable, isTrue);
    });

    testWidgets('Studio DashboardSidebar does NOT contain standalone Community tab',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dashCtrl = Get.put(DashboardController(channelId: 'SmaXftbr4DpDM60458Ig'));

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DashboardSidebarMenu(
              controller: dashCtrl,
              isDarkMode: true,
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Standalone Community tab must NOT exist in the Studio sidebar
      expect(find.widgetWithText(DashboardSidebarItem, 'Community'), findsNothing);
      expect(find.widgetWithText(DashboardSidebarItem, 'Content'), findsOneWidget);
      expect(find.widgetWithText(DashboardSidebarItem, 'Studio Home'), findsOneWidget);

      dashCtrl.onClose();
    });

    testWidgets('ContentScreen Community tab renders valid posts and strictly filters mock text',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      final vmController = Get.put(VideoManagementController());
      vmController.isLoadingPosts.value = false;
      vmController.isLoadingChannelVideos.value = false;

      final validPost = CommunityPostModel.fromMap({
        'id': 'real_post_001',
        'category': 'General',
        'channelId': 'SmaXftbr4DpDM60458Ig',
        'channelName': 'Ebenezer Vampu',
        'channelImage': '',
        'title': 'Weekly Production Update',
        'description': 'Welcome to our verified channel community space.',
        'dislikes': 0,
        'likes': 5,
        'ownerId': 'oj3JOhUbOvZHjWmzFpXBVDB1vap1',
        'visibility': 'Public',
        'status': 'published',
        'images': <String>[],
        'isCommentsEnabled': true,
        'isDislikeEnabled': true,
        'isLikeEnabled': true,
        'showDislikeCount': true,
        'showLikeCount': true,
      });

      final mockPost = CommunityPostModel.fromMap({
        'id': '8Zq2KuYIgm9m8kgogAE3',
        'category': 'General',
        'channelId': 'SmaXftbr4DpDM60458Ig',
        'channelName': 'Ebenezer Vampu',
        'channelImage': '',
        'title': 'Our First Video',
        'description': 'hi every one',
        'dislikes': 0,
        'likes': 2,
        'ownerId': 'oj3JOhUbOvZHjWmzFpXBVDB1vap1',
        'visibility': 'Public',
        'status': 'published',
        'images': <String>[],
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ContentScreen(
              channelId: 'SmaXftbr4DpDM60458Ig',
              isDarkMode: true,
              initialIndex: 1, // Community tab
            ),
          ),
        ),
      );

      // Assign both valid post and mock post
      vmController.communityPosts.assignAll([validPost, mockPost]);
      vmController.isLoadingPosts.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Valid post renders cleanly
      expect(find.text('Weekly Production Update'), findsOneWidget);
      expect(find.text('Welcome to our verified channel community space.'), findsOneWidget);

      // Mock post 'Our First Video' is strictly filtered out and never appears
      expect(find.text('Our First Video'), findsNothing);
      expect(find.text('hi every one'), findsNothing);
    });
  });
}
