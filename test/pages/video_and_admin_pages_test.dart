import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/admin_dashboard_screen.dart';
import 'package:truthworld/features/admin/presentation/views/admin_login_screen.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/video/data/repositories/firestore_comments_repository.dart';
import 'package:truthworld/features/video/data/repositories/firestore_video_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_comments_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/video/presentation/views/video_screen.dart';
import 'package:truthworld/features/video/presentation/views/videoloader_screen.dart';

import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Group 7: Home, Video & Admin Pages', () {
    testWidgets('1. Home renders shell, navigation, and feed', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpPageInHarness(
        tester,
        const Home(),
        onBeforePump: () {
          if (!Get.isRegistered<HomeController>()) {
            Get.put(HomeController());
          }
          if (!Get.isRegistered<VideoFeedNotificationController>()) {
            Get.put(VideoFeedNotificationController());
          }
          if (!Get.isRegistered<UserNotificationController>()) {
            Get.put(UserNotificationController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Home), findsOneWidget);
    });

    testWidgets('2. VideoScreen renders video player and recommendation feed',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const VideoScreen(),
        onBeforePump: () {
          if (!Get.isRegistered<VideoRepository>()) {
            Get.put<VideoRepository>(FirestoreVideoRepository());
          }
          if (!Get.isRegistered<VideoCommentsRepository>()) {
            Get.put<VideoCommentsRepository>(FirestoreCommentsRepository());
          }
          if (!Get.isRegistered<DownloadsController>()) {
            Get.put(DownloadsController());
          }
          if (!Get.isRegistered<VideoController>()) {
            Get.put(
              VideoController(
                videoRepository: Get.find<VideoRepository>(),
              ),
            );
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(VideoScreen), findsOneWidget);
    });

    testWidgets('3. ClipsPage renders user clipped moments and controls',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const ClipsPage(),
        onBeforePump: () {
          if (!Get.isRegistered<UserClipsController>()) {
            Get.put(UserClipsController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ClipsPage), findsOneWidget);
    });

    testWidgets('4. AdminLoginScreen renders login form and security fields',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        AdminLoginScreen(),
        onBeforePump: () {
          if (!Get.isRegistered<AdminController>()) {
            Get.put(AdminController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });

    testWidgets('5. AdminDashboardScreen renders administration management portal',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        AdminDashboardScreen(),
        onBeforePump: () {
          if (!Get.isRegistered<AdminController>()) {
            Get.put(AdminController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('6. VideoLoaderScreen renders hydration animation and status',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const VideoLoaderScreen(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(VideoLoaderScreen), findsOneWidget);
    });
  });
}
