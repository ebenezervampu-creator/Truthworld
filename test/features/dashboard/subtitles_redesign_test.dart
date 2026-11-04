import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_cues_table.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_header_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_languages_sidebar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_nav_tabs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_selected_video_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_transcripts_view.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Subtitles Tab Redesign - Controller & State Tests', () {
    test('UI Navigation state and CC toggle', () {
      final controller = Get.put(SubtitlesController());

      expect(controller.selectedMainTab.value, 0);
      controller.selectedMainTab.value = 1;
      expect(controller.selectedMainTab.value, 1);

      expect(controller.isCcEnabled.value, isTrue);
      controller.toggleCc();
      expect(controller.isCcEnabled.value, isFalse);
      controller.toggleCc();
      expect(controller.isCcEnabled.value, isTrue);
    });

    test('Zoom scale clamping and zooming methods', () {
      final controller = Get.put(SubtitlesController());

      expect(controller.cueZoomScale.value, 1.0);
      controller.zoomIn();
      expect(controller.cueZoomScale.value, 1.1);

      controller.setZoomScale(2.5);
      expect(controller.cueZoomScale.value, 1.5);

      controller.setZoomScale(0.2);
      expect(controller.cueZoomScale.value, 0.7);

      controller.zoomOut();
      expect(controller.cueZoomScale.value, 0.7);
    });

    test('Cues search expansion toggle', () {
      final controller = Get.put(SubtitlesController());

      expect(controller.isCuesSearchExpanded.value, isFalse);
      controller.toggleCuesSearch();
      expect(controller.isCuesSearchExpanded.value, isTrue);
      controller.toggleCuesSearch();
      expect(controller.isCuesSearchExpanded.value, isFalse);
    });

    test('Undo and Redo stack history for cue operations', () {
      final controller = Get.put(SubtitlesController());

      controller.currentCues.assignAll([
        SubtitleCue(
          id: 'cue_0',
          startTime: '00:00:00.000',
          endTime: '00:00:03.000',
          text: 'Initial Cue',
        ),
      ]);

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      controller.addNewCue();
      expect(controller.currentCues.length, 2);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.currentCues.length, 1);
      expect(controller.currentCues.first.text, 'Initial Cue');
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.currentCues.length, 2);
    });

    test('Cue selection and batch deletion', () {
      final controller = Get.put(SubtitlesController());

      controller.currentCues.assignAll([
        SubtitleCue(id: 'c1', startTime: '00:00:01.000', endTime: '00:00:03.000', text: 'One'),
        SubtitleCue(id: 'c2', startTime: '00:00:03.000', endTime: '00:00:06.000', text: 'Two'),
      ]);

      expect(controller.selectedCueIds, isEmpty);

      controller.toggleSelectCue('c1');
      expect(controller.selectedCueIds.contains('c1'), isTrue);

      controller.toggleSelectAllCues();
      expect(controller.selectedCueIds.length, 2);

      controller.deleteSelectedCues();
      expect(controller.currentCues, isEmpty);
      expect(controller.selectedCueIds, isEmpty);
    });

    test('Language track status resolver', () {
      final controller = Get.put(SubtitlesController());

      final video = Video.empty().copyWith(
        id: 'test_vid_1',
        title: "Zomato's Big Transformation in India",
        vDurationValue: const Duration(minutes: 8, seconds: 44),
        createdAt: Timestamp.now(),
        mediaSubtitles: {
          'en': 'https://storage.googleapis.com/sub_en.vtt',
          'te': 'https://storage.googleapis.com/sub_te.vtt',
        },
        languages: ['tamil'],
      );

      controller.selectedVideo.value = video;
      controller.availableLanguages.assignAll(['en', 'te', 'hi']);

      expect(controller.getLanguageStatus('en'), SubtitleTrackStatus.published);
      expect(controller.getLanguageStatus('te'), SubtitleTrackStatus.published);
      expect(controller.getLanguageStatus('hi'), SubtitleTrackStatus.draft);
      expect(controller.getLanguageStatus('kn'), SubtitleTrackStatus.notAdded);
    });
  });

  group('Subtitles Tab Redesign - Widget Rendering Tests', () {
    testWidgets('SubtitlesHeaderBar renders title and description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubtitlesHeaderBar(),
          ),
        ),
      );

      expect(find.text('Subtitles & Transcripts'), findsOneWidget);
      expect(
        find.text(
          'Add and manage subtitles and transcripts for your video. You can create subtitles manually, auto-generate with AI, or upload a file.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('SubtitlesNavTabs renders Subtitles and Transcripts tabs', (tester) async {
      final controller = Get.put(SubtitlesController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitlesNavTabs(controller: controller),
          ),
        ),
      );

      expect(find.text('Subtitles'), findsOneWidget);
      expect(find.text('Transcripts'), findsOneWidget);

      await tester.tap(find.text('Transcripts'));
      await tester.pump();
      expect(controller.selectedMainTab.value, 1);
    });

    testWidgets('SubtitlesSelectedVideoCard renders video title, duration, and Change video button', (tester) async {
      final controller = Get.put(SubtitlesController());
      final video = Video.empty().copyWith(
        id: 'vid_123',
        title: "Zomato's Big Transformation in India",
        vDurationValue: const Duration(minutes: 8, seconds: 44),
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitlesSelectedVideoCard(
              video: video,
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text("Zomato's Big Transformation in India"), findsOneWidget);
      expect(find.text('08:44'), findsOneWidget);
      expect(find.text('Change video'), findsOneWidget);
    });

    testWidgets('SubtitlesLanguagesSidebar renders Add language button and list', (tester) async {
      final controller = Get.put(SubtitlesController());
      controller.availableLanguages.assignAll(['en', 'te', 'hi']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 600,
              child: SubtitlesLanguagesSidebar(
                controller: controller,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Languages'), findsOneWidget);
      expect(find.text('Add language'), findsOneWidget);
      expect(find.text('English (Original)'), findsOneWidget);
    });

    testWidgets('SubtitlesCuesTable renders Action toolbar and Empty state', (tester) async {
      final controller = Get.put(SubtitlesController());
      controller.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: SubtitlesCuesTable(
                controller: controller,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Edit subtitles: English (Original)'), findsOneWidget);
      expect(find.text('Add caption'), findsOneWidget);
      expect(find.text('Generate with AI'), findsWidgets);
      expect(find.text('Import file'), findsOneWidget);
    });

    testWidgets('SubtitlesTranscriptsView renders search and actions', (tester) async {
      final controller = Get.put(SubtitlesController());
      controller.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: SubtitlesTranscriptsView(
                controller: controller,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Transcript: English (Original)'), findsOneWidget);
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Download TXT'), findsOneWidget);
    });
  });
}
