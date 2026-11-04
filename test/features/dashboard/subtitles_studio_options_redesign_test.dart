import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_ai_progress_banner.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_language_ribbon.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_workspace_top_bar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  Video createMockVideo() {
    return Video(
      id: 'vid_123',
      ownerId: 'user_1',
      channelId: 'channel_123',
      channelName: 'TruthWorld Channel',
      category: 'Education',
      tags: const ['truth', 'news'],
      title: 'Test Studio Video',
      description: 'Test description',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      duration: '05:00',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mediaSubtitles: const {'en': 'https://example.com/en.vtt'},
    );
  }

  group('Subtitles Studio Options Redesign Tests', () {
    testWidgets(
        'SubtitlesLanguageRibbon displays "Subtitles:" and "Add Subtitles", and opens options sheet on tap',
        (tester) async {
      final controller = Get.put(SubtitlesController());
      controller.availableLanguages.assignAll(['en', 'es']);
      controller.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SubtitlesLanguageRibbon(
              controller: controller,
              surfaceColor: const Color(0xFF1E1E1E),
              textColor: Colors.white,
              textSecondaryColor: Colors.white70,
              borderColor: const Color(0xFF2E2E2E),
              isDarkMode: true,
              isMobile: true,
            ),
          ),
        ),
      );

      // Verify "Subtitles:" label exists (not "Tracks:")
      expect(find.text('Subtitles:'), findsOneWidget);
      expect(find.text('Tracks:'), findsNothing);

      // Verify "Add Subtitles" chip exists (not "Add Track")
      expect(find.text('Add Subtitles'), findsOneWidget);
      expect(find.text('Add Track'), findsNothing);

      // Tap "Add Subtitles" chip
      await tester.tap(find.text('Add Subtitles'));
      await tester.pumpAndSettle();

      // Verify the bottom sheet displays "Generate Subtitles" and "Add files"
      expect(find.text('Generate Subtitles'), findsOneWidget);
      expect(find.text('Add files'), findsOneWidget);
    });

    testWidgets(
        'SubtitlesWorkspaceTopBar mobile layout removes Row 2 and More icon contains Download Subtitles',
        (tester) async {
      final controller = Get.put(SubtitlesController());
      final mockVideo = createMockVideo();
      controller.selectedVideo.value = mockVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SubtitlesWorkspaceTopBar(
              video: mockVideo,
              controller: controller,
              surfaceColor: const Color(0xFF1E1E1E),
              textColor: Colors.white,
              textSecondaryColor: Colors.white70,
              borderColor: const Color(0xFF2E2E2E),
              isDarkMode: true,
              isMobile: true,
            ),
          ),
        ),
      );

      // Verify prominent Row 2 buttons are removed
      expect(find.text('Generate with AI'), findsNothing);
      expect(find.text('Add Track'), findsNothing);

      // Open More Actions Menu
      final moreBtn = find.byIcon(Icons.more_vert_rounded);
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Verify More actions menu contains "Download Subtitles"
      expect(find.text('Download Subtitles'), findsOneWidget);
    });

    testWidgets(
        'GenerateAiSubtitlesPage shows category-style language selection with checkboxes and tags',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(SubtitlesController());
      final mockVideo = createMockVideo();
      controller.selectedVideo.value = mockVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: GenerateAiSubtitlesPage(
            controller: controller,
            isDarkMode: true,
          ),
        ),
      );

      // Check header and list elements
      expect(find.text('Generate Subtitles'), findsWidgets);
      expect(find.byType(Checkbox), findsWidgets);
      expect(find.textContaining('Generate Subtitles ('), findsOneWidget);
    });

    testWidgets(
        'GenerateAiSubtitlesPage switches to live progress and SubtitlesAiProgressBanner displays background reassurance',
        (tester) async {
      final controller = Get.put(SubtitlesController());
      final mockVideo = createMockVideo();
      controller.selectedVideo.value = mockVideo;
      controller.isGeneratingAI.value = true;
      controller.aiJobProgress.value = 45;
      controller.aiJobStatus.value = 'Generating multilingual subtitles...';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SubtitlesAiProgressBanner(controller: controller),
                Expanded(
                  child: GenerateAiSubtitlesPage(
                    controller: controller,
                    isDarkMode: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify progress UI renders with stage indicators and reassurance
      expect(find.text('Generating AI Subtitles...'), findsOneWidget);
      expect(find.text('45%'), findsWidgets);
      expect(
        find.textContaining('Runs safely in the cloud'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Runs in background • Safe to leave or close app'),
        findsOneWidget,
      );
    });
  });
}
