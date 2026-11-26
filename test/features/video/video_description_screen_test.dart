import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/video_description_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/video_description_box.dart';
import 'package:truthworld/routes/app_routes.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  final sampleVideo = Video.fromMap({
    'title': 'TruthWorld Fact Check & Analysis',
    'description': 'This is a full description of the video explaining everything.\nVisit https://truthworld.ai and follow @truthworld.',
    'channelId': 'chan_test_1',
    'channelName': 'TruthWorld News',
    'channelAvatarUrl': 'https://example.com/avatar.jpg',
    'likeCount': 1200,
    'views': 45000,
    'uploadedAt': DateTime(2026, 10, 27, 12, 0),
    'showLikeCount': true,
    'showDislikeCount': true,
  }, 'vid_test_101');

  group('VideoDescriptionBox and VideoDescriptionScreen Tests', () {
    testWidgets('1. isMobileSized returns true for narrow width and false when isDesktop is true',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              // Narrow width (< 900)
              final isMobileNarrow = VideoDescriptionBox.isMobileSized(context, isDesktop: false);
              // Explicit desktop
              final isDesktopExplicit = VideoDescriptionBox.isMobileSized(context, isDesktop: true);

              expect(isMobileNarrow, isTrue);
              expect(isDesktopExplicit, isFalse);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('2. VideoDescriptionScreen renders video details, channel and full description',
        (tester) async {
      final mainController = Get.put(MainController(), permanent: true);
      final videoController = Get.put(VideoController(), tag: sampleVideo.id);
      videoController.video = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.videoDescription,
          getPages: [
            GetPage(
              name: AppRoutes.videoDescription,
              page: () => VideoDescriptionScreen(
                video: sampleVideo,
                controller: videoController,
                mainController: mainController,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar Title
      expect(find.text('Description'), findsOneWidget);

      // Verify Video Title is rendered
      expect(find.text('TruthWorld Fact Check & Analysis'), findsOneWidget);

      // Verify Channel Name is rendered
      expect(find.text('TruthWorld News'), findsOneWidget);

      // Verify Description text contains the description content
      expect(find.textContaining('This is a full description'), findsOneWidget);

      // Verify Views and Likes metrics are displayed
      expect(find.text('45.0K'), findsOneWidget);
      expect(find.text('1.2K'), findsOneWidget);
    });

    testWidgets('3. Tapping description box on mobile opens VideoDescriptionScreen',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mainController = Get.put(MainController(), permanent: true);
      final videoController = Get.put(VideoController(), tag: sampleVideo.id);
      videoController.video = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoDescriptionBox(
              controller: videoController,
              mainController: mainController,
              isDesktop: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find '...more' in the description box and tap it
      final moreFinder = find.text('...more');
      expect(moreFinder, findsOneWidget);

      await tester.tap(moreFinder);
      await tester.pumpAndSettle();

      // Verify we navigated to VideoDescriptionScreen
      expect(find.byType(VideoDescriptionScreen), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });
  });
}
