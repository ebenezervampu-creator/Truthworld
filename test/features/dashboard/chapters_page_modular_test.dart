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

  final sampleVideo2 = Video.fromMap({
    'title': 'Second Video For Chapters',
    'channelId': 'chan_test_1',
    'channelName': 'TruthWorld Studio',
    'videoUrl': 'https://example.com/video2.mp4',
    'thumbnailUrl': 'https://example.com/thumb2.jpg',
    'duration': '05:30',
    'durationMs': (5 * 60 + 30) * 1000,
    'views': 120,
    'chapters': [],
  }, 'vid_002');

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

    testWidgets(
        '1b. ChaptersVideoListPane updates selection highlight when another video is tapped',
        (tester) async {
      final controller = Get.put(ChaptersController());
      controller.videos.addAll([sampleVideo, sampleVideo2]);
      controller.filteredVideos.addAll([sampleVideo, sampleVideo2]);
      controller.selectedVideo.value = sampleVideo;

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

      // Initially sampleVideo is selected
      expect(controller.selectedVideo.value?.id, equals('vid_001'));

      final card1ContainerBefore = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Investigative Fact Check'),
      );
      final border1Before =
          (card1ContainerBefore.decoration as BoxDecoration).border?.top;
      expect(border1Before?.width, equals(1.5));

      final card2ContainerBefore = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Second Video For Chapters'),
      );
      final border2Before =
          (card2ContainerBefore.decoration as BoxDecoration).border?.top;
      expect(border2Before?.width, equals(1.0));

      // Tap on second video card
      await tester.tap(find.text('Second Video For Chapters'));
      await tester.pumpAndSettle();

      expect(controller.selectedVideo.value?.id, equals('vid_002'));

      // Verify that selection highlight swapped to card 2
      final card1ContainerAfter = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Investigative Fact Check'),
      );
      final border1After =
          (card1ContainerAfter.decoration as BoxDecoration).border?.top;
      expect(border1After?.width, equals(1.0));

      final card2ContainerAfter = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Second Video For Chapters'),
      );
      final border2After =
          (card2ContainerAfter.decoration as BoxDecoration).border?.top;
      expect(border2After?.width, equals(1.5));
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

    testWidgets(
        '6. ChaptersTimelineView renders without overflow on narrow mobile screens (360px)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(ChaptersController());
      final longTitleChapter = VideoChapter(
        title:
            'Zomato’s Big Transformation: From Food Delivery to a Consumer Empire',
        startTime: Duration.zero,
      );
      controller.currentChapters.add(longTitleChapter);

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
                    chapter: longTitleChapter,
                    total: 1,
                    textColor: AppColors.textPrimary,
                    textSecondaryColor: AppColors.textSecondary,
                    borderColor: AppColors.bgDivider,
                    surfaceColor: AppColors.bgSurface,
                    isDarkMode: true,
                    isMobile: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify no exceptions were thrown and the title rendered
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Zomato’s Big Transformation: From Food Delivery to a Consumer Empire',
        ),
        findsOneWidget,
      );
      expect(find.text('00:00'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    test('7. ChaptersController supports custom and auto-resolved chapter thumbnails', () {
      final controller = Get.put(ChaptersController());
      final videoWithVariants = Video.fromMap({
        'title': 'Test Video with Variants',
        'videoUrl': 'https://example.com/v.mp4',
        'thumbnailUrl': 'https://example.com/main.jpg',
        'duration': '10:00',
        'durationMs': 600000,
        'thumbnailVariants': [
          'https://example.com/frame_0.jpg',
          'https://example.com/frame_1.jpg',
          'https://example.com/frame_2.jpg',
          'https://example.com/frame_3.jpg',
        ],
      }, 'vid_variants');

      controller.selectedVideo.value = videoWithVariants;

      // Add chapter with custom thumbnail
      controller.addChapter(
        'Custom Chapter',
        const Duration(minutes: 1),
        thumbnailUrl: 'https://example.com/custom_chapter.jpg',
      );

      expect(controller.currentChapters.length, equals(1));
      expect(controller.currentChapters.first.title, equals('Custom Chapter'));
      expect(controller.currentChapters.first.thumbnailUrl, equals('https://example.com/custom_chapter.jpg'));

      // Add chapter with auto-resolved thumbnail from variants
      controller.addChapter(
        'Auto Chapter Midpoint',
        const Duration(minutes: 5), // 50% through video -> index 2 (frame_2.jpg)
      );

      expect(controller.currentChapters.length, equals(2));
      final autoChapter = controller.currentChapters.firstWhere((c) => c.title == 'Auto Chapter Midpoint');
      expect(autoChapter.thumbnailUrl, equals('https://example.com/frame_2.jpg'));

      // Update chapter thumbnail
      final index = controller.currentChapters.indexOf(autoChapter);
      controller.updateChapter(
        index,
        thumbnailUrl: 'https://example.com/updated_frame.jpg',
      );
      expect(controller.currentChapters[index].thumbnailUrl, equals('https://example.com/updated_frame.jpg'));
    });

    test('8. ChaptersController captureHighQualityChapterFrame returns discrete frame or falls back', () async {
      final controller = Get.put(ChaptersController());
      final video = Video.fromMap({
        'title': 'Test Video',
        'videoUrl': 'https://example.com/v.mp4',
        'thumbnailUrl': 'https://example.com/main.jpg',
        'duration': '10:00',
        'durationMs': 600000,
        'thumbnailVariants': [
          'https://example.com/hd_frame_0.jpg',
          'https://example.com/hd_frame_1.jpg',
        ],
      }, 'vid_hd');

      controller.selectedVideo.value = video;

      final frame = await controller.captureHighQualityChapterFrame(
        videoId: video.id,
        startTime: const Duration(minutes: 5),
      );

      expect(frame, isNotNull);
      expect(frame, equals('https://example.com/hd_frame_1.jpg'));
    });
  });
}
