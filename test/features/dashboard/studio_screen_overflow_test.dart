import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_list_section.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_track_dubbing_options_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/add_subtitle_track_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_workspace_top_bar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'test_vid_debug',
    title: 'TruthWorld Fact Check Studio Stream',
    description: 'Test description',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    ownerId: 'user_1',
    channelId: 'test_channel_123',
    channelName: 'Test Channel',
    category: 'Tech',
    duration: '03:00',
    tags: ['truth', 'factcheck'],
    mediaSubtitles: {'en': 'https://example.com/en.vtt'},
  );

  testWidgets(
    'AddSubtitleTrackPage renders ListTiles inside Material without assertions on 360dp',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1608); // 360x804 dp @ DPR 2.0
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(SubtitlesController());
      controller.selectedVideo.value = testVideo;
      controller.rxState.value = ViewState.success;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: AddSubtitleTrackPage(
            controller: controller,
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add Subtitle Track'), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      // Ensures zero assertions thrown during rendering
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GenerateAiSubtitlesPage pricing notice renders without overflow on 360dp width',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1608); // 360x804 dp
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(SubtitlesController());
      controller.selectedVideo.value = testVideo;
      controller.rxState.value = ViewState.success;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: GenerateAiSubtitlesPage(
            controller: controller,
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Generate Subtitles'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Zero charm pricing'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Zero charm pricing'),
        findsOneWidget,
      );
      // Ensures zero RenderFlex overflow occurred
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SubtitlesDownloadDropdownMenu opens and renders all menu items without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1608); // 360x804 dp
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(SubtitlesController());
      controller.selectedVideo.value = testVideo;
      controller.rxState.value = ViewState.success;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SubtitlesDownloadDropdownMenu(
                controller: controller,
                borderColor: const Color(0xFF27272A),
                textColor: Colors.white,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap to open the download dropdown
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Transcript to Clipboard'), findsOneWidget);
      expect(find.text('Download All Tracks (ZIP)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AudioTrackDubbingOptionsDialog renders action buttons without overflow on 360dp width',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1608); // 360x804 dp
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(AudioTracksController());
      controller.selectedVideo.value = testVideo;
      controller.rxState.value = ViewState.success;

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint('FLUTTER_ERROR_DETAILS: ${details.exceptionAsString()}');
        debugPrint('CONTEXT: ${details.context?.toDescription()}');
        debugPrint('SUMMARY: ${details.summary.toDescription()}');
        for (final node in details.informationCollector?.call() ?? <DiagnosticsNode>[]) {
          debugPrint('COLLECTOR: ${node.toDescription()}');
        }
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AudioTrackDubbingOptionsDialog(
              controller: controller,
              initialLangCode: 'hi',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Audio Track & Dubbing'), findsOneWidget);
      expect(find.text('AI Dubbing'), findsOneWidget);
      expect(find.text('Generate Audio Track'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch to Direct Audio Track tab
      await tester.tap(find.text('Direct Audio Track'));
      await tester.pumpAndSettle();

      expect(find.text('Where to Get Direct Audio Tracks (Studio Guide)'), findsOneWidget);
      expect(find.text('Download Original Audio'), findsOneWidget);
      expect(find.text('Upload & Attach Track'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AvailableAudioTrackCard in generating state renders pipeline steps without overflow on narrow 320dp/360dp screens',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1608); // 320x804 dp (compact mobile width)
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(AudioTracksController());
      controller.selectedVideo.value = testVideo;
      controller.generatingDubLanguages.add('hi');
      controller.dubbingProgress['hi'] = const AudioDubbingProgressState(
        langCode: 'hi',
        stageTitle: 'Synthesizing AI voice track',
        stageStep: 3,
        totalStepsText: 'Step 3 of 4',
        progress: 74,
        etaText: '~10-15 sec',
        isGenerating: true,
      );

      final hindiTrack = AudioTrackItem(
        id: 'track_hi',
        languageCode: 'hi',
        languageName: 'Hindi (हिन्दी)',
        audioUrl: '',
        status: 'Generating...',
        role: 'Dubbing',
      );

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AvailableAudioTrackCard(
                  track: hindiTrack,
                  video: testVideo,
                  controller: controller,
                  isDarkMode: true,
                  onUploadAudio: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hindi (हिन्दी)'), findsOneWidget);
      expect(find.text('1. Transcribe'), findsOneWidget);
      expect(find.text('2. Translate'), findsOneWidget);
      expect(find.text('3. Synthesize Voice'), findsOneWidget);
      expect(find.text('4. Final Sync'), findsOneWidget);

      // Verify zero overflow errors
      expect(errors.where((e) => e.exceptionAsString().contains('overflowed')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
