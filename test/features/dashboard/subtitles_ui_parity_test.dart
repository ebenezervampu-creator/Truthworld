import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/change_video_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_list_section.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
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
      title: 'Jesus Clips',
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
        'te': 'https://example.com/te.vtt',
      },
    );
  }

  group('Subtitles Page UI Parity with Audio & Video Tests', () {
    testWidgets(
      'SubtitlesPage top header shows filter icon before Subtitles headline and opens ChangeVideoDialog on tap',
      (tester) async {
        final controller = Get.put(SubtitlesController());
        final mockVideo = createMockVideo();
        controller.videos.assignAll([mockVideo]);
        controller.filteredVideos.assignAll([mockVideo]);
        controller.selectedVideo.value = mockVideo;

        await tester.pumpWidget(
          GetMaterialApp(
            home: SubtitlesPage(
              channelId: 'channel_123',
              isDarkMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Top Header has filter icon and Subtitles headline text
        final filterIconBtn = find.byTooltip('Select video');
        expect(filterIconBtn, findsOneWidget);
        expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);

        // Header text "Subtitles"
        expect(find.text('Subtitles'), findsWidgets);

        // 2. Tap filter icon and verify ChangeVideoDialog opens
        await tester.tap(filterIconBtn);
        await tester.pumpAndSettle();

        expect(find.byType(ChangeVideoDialog), findsOneWidget);
        expect(find.text('Select Video for Subtitles'), findsOneWidget);

        // Close dialog
        final closeBtn = find.byIcon(Icons.close_rounded);
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'SubtitlesListSection shows Available Subtitles, + Subtitles button, and opens Generate / Add files sheet',
      (tester) async {
        final controller = Get.put(SubtitlesController());
        final mockVideo = createMockVideo();
        controller.videos.assignAll([mockVideo]);
        controller.filteredVideos.assignAll([mockVideo]);
        controller.selectedVideo.value = mockVideo;
        controller.availableLanguages.assignAll(['en', 'te', 'hi']);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SubtitlesListSection(
                video: mockVideo,
                controller: controller,
                textColor: Colors.white,
                textSecondaryColor: Colors.white70,
                surfaceColor: const Color(0xFF161618),
                borderColor: const Color(0xFF27272A),
                isDarkMode: true,
                onAddSubtitles: () => showAddSubtitlesOptionsSheet(
                  context: Get.context!,
                  controller: controller,
                  isDarkMode: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Header row
        expect(find.text('Available Subtitles'), findsOneWidget);
        expect(
          find.text('Manage available multi-language subtitles and captions.'),
          findsOneWidget,
        );

        // 2. Verify "+ Subtitles" button with plus icon
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);

        // Find the button with label Subtitles
        final addSubtitlesBtn = find.widgetWithText(ElevatedButton, 'Subtitles');
        expect(addSubtitlesBtn, findsOneWidget);

        // 3. Tap "+ Subtitles" button and verify option sheet opens
        await tester.tap(addSubtitlesBtn);
        await tester.pumpAndSettle();

        expect(find.text('Add Subtitles'), findsWidgets);
        expect(find.text('Generate Subtitles'), findsOneWidget);
        expect(find.text('Add files'), findsOneWidget);

        // Close sheet
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'SubtitlesListSection displays available languages as cards similar to Audio & Video',
      (tester) async {
        final controller = Get.put(SubtitlesController());
        final mockVideo = createMockVideo();
        controller.videos.assignAll([mockVideo]);
        controller.filteredVideos.assignAll([mockVideo]);
        controller.selectedVideo.value = mockVideo;
        controller.availableLanguages.assignAll(['en', 'te', 'hi']);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SubtitlesListSection(
                video: mockVideo,
                controller: controller,
                textColor: Colors.white,
                textSecondaryColor: Colors.white70,
                surfaceColor: const Color(0xFF161618),
                borderColor: const Color(0xFF27272A),
                isDarkMode: true,
                onAddSubtitles: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify available cards
        expect(find.byType(AvailableSubtitleTrackCard), findsWidgets);

        // Primary base track
        expect(find.text('English (Original)'), findsOneWidget);
        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('Original video subtitles'), findsOneWidget);

        // Additional language track (Telugu)
        expect(find.text('Telugu (తెలుగు)'), findsOneWidget);
        expect(find.text('Subtitles'), findsWidgets);
        expect(find.text('Subtitles stream'), findsWidgets);

        // Verify Published badge exists
        expect(find.text('Published'), findsWidgets);

        // Verify action buttons inside published cards
        expect(find.text('Edit Cues'), findsWidgets);
        expect(find.text('Download'), findsWidgets);
      },
    );

    testWidgets(
      'Tapping Edit Cues on a card opens Subtitles Cues Editor modal',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = Get.put(SubtitlesController());
        final mockVideo = createMockVideo();
        controller.videos.assignAll([mockVideo]);
        controller.filteredVideos.assignAll([mockVideo]);
        controller.selectedVideo.value = mockVideo;
        controller.availableLanguages.assignAll(['en', 'te']);
        controller.selectedLanguage.value = 'en';
        controller.currentCues.assignAll([
          SubtitleCue(
            id: 'cue_1',
            startTime: '00:00:01.000',
            endTime: '00:00:04.000',
            text: 'Hello world',
          ),
        ]);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SubtitlesListSection(
                video: mockVideo,
                controller: controller,
                textColor: Colors.white,
                textSecondaryColor: Colors.white70,
                surfaceColor: const Color(0xFF161618),
                borderColor: const Color(0xFF27272A),
                isDarkMode: true,
                onAddSubtitles: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the first "Edit Cues" button
        final editCuesBtn = find.text('Edit Cues').first;
        await tester.tap(editCuesBtn);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        // Verify editor modal is opened
        expect(find.textContaining('Edit Subtitles:'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });
}
