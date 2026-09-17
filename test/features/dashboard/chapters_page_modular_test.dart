import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters/chapters_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/theme/app_colors.dart';
import '../../pages/page_test_harness.dart';
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

  final sampleVideo = Video.fromMap({
    'title': 'Investigative Fact Check',
    'channelId': 'chan_test_1',
    'channelName': 'TruthWorld Studio',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'duration': '10:45',
    'durationMs': (10 * 60 + 45) * 1000,
    'views': 450,
    'chapters': [
      {'title': 'Opening Statement', 'startTime': 0},
      {'title': 'Evidence Analysis', 'startTime': 180},
    ],
  }, 'vid_001');

  final sampleChapter = VideoChapter(
    title: 'Opening Statement',
    startTime: Duration.zero,
  );

  group('Chapters Page Modular Components Tests', () {
    testWidgets('1. ChaptersVideoListPane renders search and filter chips',
        (tester) async {
      final controller = Get.put(ChaptersController());
      controller.videos.add(sampleVideo);
      controller.filteredVideos.add(sampleVideo);

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: ChaptersVideoListPane(
            controller: controller,
            surfaceColor: AppColors.bgSurface,
            textColor: AppColors.textPrimary,
            textSecondaryColor: AppColors.textSecondary,
            borderColor: AppColors.bgDivider,
            isDarkMode: true,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Video Chapters'), findsOneWidget);
      expect(find.text('All Videos'), findsOneWidget);
      expect(find.text('With Chapters'), findsOneWidget);
      expect(find.text('No Chapters'), findsOneWidget);
      expect(find.text('Investigative Fact Check'), findsOneWidget);

      // Tap filter
      await tester.tap(find.text('With Chapters'));
      await tester.pump();
      expect(controller.filterType.value, equals('has_chapters'));
    });

    testWidgets('2. ChaptersEmptySelectionState renders prompt to select video',
        (tester) async {
      final controller = Get.put(ChaptersController());

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: ChaptersWorkspacePane(
            controller: controller,
            surfaceColor: AppColors.bgSurface,
            textColor: AppColors.textPrimary,
            textSecondaryColor: AppColors.textSecondary,
            borderColor: AppColors.bgDivider,
            isDarkMode: true,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Select a video to edit chapters'), findsOneWidget);
      expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
    });

    testWidgets('3. ChaptersTimelineView renders empty timeline state',
        (tester) async {
      final controller = Get.put(ChaptersController());

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ChaptersTimelineView.buildEmptyTimelineState(
              context,
              controller: controller,
              textColor: AppColors.textPrimary,
              textSecondaryColor: AppColors.textSecondary,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Timeline is Empty'), findsOneWidget);
      expect(find.text('Add Intro at 00:00'), findsOneWidget);
      expect(find.text('AI Auto-Detect'), findsOneWidget);
    });

    testWidgets('4. ChaptersTimelineView renders chapter row and add button',
        (tester) async {
      final controller = Get.put(ChaptersController());
      controller.currentChapters.add(sampleChapter);

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              child: Column(
                children: [
                  ChaptersTimelineView.buildTimelineRow(
                    context,
                    controller: controller,
                    index: 0,
                    chapter: sampleChapter,
                    total: 1,
                    textColor: AppColors.textPrimary,
                    textSecondaryColor: AppColors.textSecondary,
                    borderColor: AppColors.bgDivider,
                    surfaceColor: AppColors.bgSurface,
                    isDarkMode: true,
                  ),
                  ChaptersTimelineView.buildAddChapterButton(
                    context,
                    controller: controller,
                    borderColor: AppColors.bgDivider,
                    isDarkMode: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Opening Statement'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Add New Milestone Chapter'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('5. ChaptersPage renders full responsive studio layout',
        (tester) async {
      await pumpPageInHarness(
        tester,
        const ChaptersPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      );

      expect(find.byType(ChaptersPage), findsOneWidget);
    });
  });
}
