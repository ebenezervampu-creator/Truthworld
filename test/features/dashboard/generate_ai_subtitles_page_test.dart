import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
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
      title: 'Real Face of Gandhi',
      description: 'Test description',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      duration: '05:00',
      language: 'en',
      languages: const ['Telugu', 'Hindi'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mediaSubtitles: const {
        'en': 'https://example.com/en.vtt',
      },
    );
  }

  testWidgets(
    'GenerateAiSubtitlesPage builds without GetX improper use exception',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(SubtitlesController());
      final mockVideo = createMockVideo();
      controller.videos.assignAll([mockVideo]);
      controller.filteredVideos.assignAll([mockVideo]);
      controller.selectedVideo.value = mockVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: GenerateAiSubtitlesPage(
            controller: controller,
            isDarkMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the page renders successfully without throwing Obx exception
      expect(find.byType(GenerateAiSubtitlesPage), findsOneWidget);
      expect(find.text('Generate Subtitles'), findsOneWidget);
      expect(find.text('Real Face of Gandhi'), findsWidgets);
      expect(find.text('Subtitle Plan'), findsOneWidget);
      expect(find.text('Ultra Subtitles'), findsOneWidget);
      expect(find.text('Target Languages (0 Selected)'), findsOneWidget);
    },
  );
}
