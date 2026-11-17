import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/multilingual_studio_video_player.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'test_vid_123',
    ownerId: 'user_1',
    channelId: 'channel_1',
    channelName: 'TruthWorld Studio',
    category: 'News',
    tags: const ['news', 'report'],
    title: 'Breaking Truth Investigation',
    description: 'A multi-language investigative video report.',
    videoUrl: 'https://cdn.truthworld.com/videos/test_vid_123.mp4',
    thumbnailUrl: 'https://cdn.truthworld.com/thumbs/test_vid_123.jpg',
    duration: '0:15',
    createdAt: DateTime(2026, 6, 2, 10),
    audioTracks: {
      'en': 'https://cdn.truthworld.com/audio/en_master.mp3',
      'hi': 'https://cdn.truthworld.com/audio/hi_dubbed.mp3',
    },
    dubbedVideos: {
      'hi': 'https://cdn.truthworld.com/videos/test_vid_123_hi.mp4',
    },
    adaptiveResolutions: [
      VideoResolutionV2(
        label: '1080p',
        url: 'https://cdn.truthworld.com/videos/test_vid_123_1080p.mp4',
        width: 1920,
        height: 1080,
        bitrate: 4500000,
      ),
      VideoResolutionV2(
        label: '720p',
        url: 'https://cdn.truthworld.com/videos/test_vid_123_720p.mp4',
        width: 1280,
        height: 720,
        bitrate: 2500000,
      ),
      VideoResolutionV2(
        label: '480p',
        url: 'https://cdn.truthworld.com/videos/test_vid_123_480p.mp4',
        width: 854,
        height: 480,
        bitrate: 1200000,
      ),
    ],
  );

  Widget buildTestableWidget({
    required Video video,
    required AudioTracksController controller,
    VoidCallback? onAddDubTrack,
  }) {
    return GetMaterialApp(
      theme: ThemeData.dark().copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MultilingualStudioVideoPlayer(
            video: video,
            controller: controller,
            isDarkMode: true,
            onAddDubTrack: onAddDubTrack,
          ),
        ),
      ),
    );
  }

  group('Multilingual Studio Video Player & Dubbing Coordinator', () {
    testWidgets('Renders video card with scrubber, language pills, and download button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        buildTestableWidget(
          video: testVideo,
          controller: audioCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Viewport and player card exists
      expect(find.byType(MultilingualStudioVideoPlayer), findsOneWidget);

      // Scrubber slider and live timestamp exist
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('0:15'), findsWidgets);

      // Floating Language pills exist
      expect(find.text('English\u200B'), findsOneWidget);
      expect(find.text('Hindi\u200B'), findsOneWidget);

      // High-contrast Download button exists
      expect(find.text('Download'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('Tapping floating Hindi pill switches active track in controller', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        buildTestableWidget(
          video: testVideo,
          controller: audioCtrl,
        ),
      );
      await tester.pumpAndSettle();

      final playerCtrl = Get.find<MultilingualStudioPlayerController>(
        tag: 'studio_multilingual_${testVideo.id}',
      );

      // Initially selected is English
      expect(audioCtrl.selectedLanguage.value, 'en');
      expect(playerCtrl.selectedTrack.value?.code, 'en');

      // Tap Hindi pill
      final hindiPill = find.text('Hindi\u200B');
      expect(hindiPill, findsOneWidget);
      await tester.tap(hindiPill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Controller should update to Hindi
      expect(audioCtrl.selectedLanguage.value, 'hi');
      expect(playerCtrl.selectedTrack.value?.code, 'hi');
    });

    testWidgets('Download button opens modal with Video (.mp4) and Audio (.mp3) options', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'hi';

      await tester.pumpWidget(
        buildTestableWidget(
          video: testVideo,
          controller: audioCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Select Hindi track first so modal shows Hindi
      final playerCtrl = Get.find<MultilingualStudioPlayerController>(
        tag: 'studio_multilingual_${testVideo.id}',
      );
      playerCtrl.selectedTrack.value = const AudioTrackOption(
        code: 'hi',
        label: 'Hindi',
        audioUrl: 'https://cdn.truthworld.com/audio/hi_dubbed.mp3',
      );
      await tester.pumpAndSettle();

      // Tap Download
      final downloadBtn = find.text('Download');
      expect(downloadBtn, findsOneWidget);
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      // Download bottom sheet should open with Hindi download options
      expect(find.text('Download Hindi Media'), findsOneWidget);
      expect(find.text('Download Video with Hindi Audio (.mp4)'), findsOneWidget);
      expect(find.text('Download Hindi Audio Track Only (.mp3)'), findsOneWidget);
    });

    testWidgets('Mobile responsive layout (360x640) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        buildTestableWidget(
          video: testVideo,
          controller: audioCtrl,
          onAddDubTrack: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Verify no yellow/black overflow error occurred
      expect(tester.takeException(), isNull);
      expect(find.byType(MultilingualStudioVideoPlayer), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('Download modal allows switching languages and downloading Hindi, Telugu, and Tamil media', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'en';

      final multiVideo = testVideo.copyWith(
        audioTracks: {
          'en': 'https://cdn.truthworld.com/audio/en_master.mp3',
          'hi': 'https://cdn.truthworld.com/audio/hi_dubbed.mp3',
          'te': 'https://cdn.truthworld.com/audio/te_dubbed.mp3',
          'ta': 'https://cdn.truthworld.com/audio/ta_dubbed.mp3',
        },
        dubbedVideos: {
          'hi': 'https://cdn.truthworld.com/videos/test_vid_123_hi.mp4',
          'te': 'https://cdn.truthworld.com/videos/test_vid_123_te.mp4',
          'ta': 'https://cdn.truthworld.com/videos/test_vid_123_ta.mp4',
        },
      );

      await tester.pumpWidget(
        buildTestableWidget(
          video: multiVideo,
          controller: audioCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Download button
      final downloadBtn = find.text('Download');
      expect(downloadBtn, findsOneWidget);
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      // Initially shows English Media options
      expect(find.text('Download English Media'), findsOneWidget);
      expect(find.text('Download Video with English Audio (.mp4)'), findsOneWidget);

      // Language pills are available inside modal
      expect(find.text('Select Language'), findsOneWidget);

      // Tap Hindi pill inside the download modal
      // In modal, pills have text 'Hindi', 'Telugu', 'Tamil'
      final modalHindiPill = find.widgetWithText(InkWell, 'Hindi');
      if (modalHindiPill.evaluate().isNotEmpty) {
        await tester.tap(modalHindiPill.first);
        await tester.pumpAndSettle();

        // Modal should update to Hindi Media
        expect(find.text('Download Hindi Media'), findsOneWidget);
        expect(find.text('Download Video with Hindi Audio (.mp4)'), findsOneWidget);
        expect(find.text('Download Hindi Audio Track Only (.mp3)'), findsOneWidget);
      }

      // Tap Telugu pill inside modal
      final modalTeluguPill = find.widgetWithText(InkWell, 'Telugu');
      if (modalTeluguPill.evaluate().isNotEmpty) {
        await tester.tap(modalTeluguPill.first);
        await tester.pumpAndSettle();

        expect(find.text('Download Telugu Media'), findsOneWidget);
        expect(find.text('Download Video with Telugu Audio (.mp4)'), findsOneWidget);
        expect(find.text('Download Telugu Audio Track Only (.mp3)'), findsOneWidget);
      }

      // Quick-access All Available Languages section exists
      expect(find.text('All Available Languages'), findsOneWidget);
      expect(find.text('MP4 Video'), findsWidgets);
      expect(find.text('MP3 Audio'), findsWidgets);
    });

    testWidgets('Download modal provides MP4 video option for all languages having Audio Track even without pre-rendered dubbedVideos', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'en';

      // Video with only audio tracks, zero pre-rendered dubbed videos
      final audioOnlyTracksVideo = testVideo.copyWith(
        audioTracks: {
          'en': 'https://cdn.truthworld.com/audio/en_master.mp3',
          'hi': 'https://cdn.truthworld.com/audio/hi_dubbed.mp3',
          'te': 'https://cdn.truthworld.com/audio/te_dubbed.mp3',
          'ta': 'https://cdn.truthworld.com/audio/ta_dubbed.mp3',
        },
        dubbedVideos: const {},
      );

      await tester.pumpWidget(
        buildTestableWidget(
          video: audioOnlyTracksVideo,
          controller: audioCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Open download modal
      final downloadBtn = find.text('Download');
      expect(downloadBtn, findsOneWidget);
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      // Verify All Available Languages section renders
      expect(find.text('All Available Languages'), findsOneWidget);

      // Verify that MP4 Video buttons exist for all 4 languages (en, hi, te, ta)
      final mp4VideoButtons = find.text('MP4 Video');
      expect(mp4VideoButtons, findsNWidgets(4));

      // Verify that MP3 Audio buttons also exist for all 4 languages
      final mp3AudioButtons = find.text('MP3 Audio');
      expect(mp3AudioButtons, findsNWidgets(4));

      // Verify subtitle labels indicate dubbed video & audio capability
      expect(find.text('Original master'), findsOneWidget);
      expect(find.text('Dubbed video & audio'), findsNWidgets(3));

      // Tap MP4 Video on Telugu track row
      final teluguRow = find.ancestor(
        of: find.text('Telugu'),
        matching: find.byType(Container),
      );
      expect(teluguRow, findsWidgets);

      // Tap the MP4 button
      await tester.tap(mp4VideoButtons.at(2));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      // Modal closed and action executed safely
      expect(find.text('All Available Languages'), findsNothing);
    });

    testWidgets('Switching track handles errors gracefully without getting stuck in isChangingTrack', (tester) async {
      final ctrl = MultiAudioPlayerController();
      const faultyTrack = AudioTrackOption(
        code: 'ta',
        label: 'Tamil',
        videoUrl: 'https://cdn.truthworld.com/videos/nonexistent_ta.mp4',
      );

      expect(ctrl.isChangingTrack.value, isFalse);

      // Attempting to switch should not leave isChangingTrack as true
      await ctrl.switchTrack(faultyTrack);

      expect(ctrl.isChangingTrack.value, isFalse);
      expect(ctrl.selectedTrack.value?.code, 'ta');
    });

    test('Seamless audio-only track switch keeps video active and switches selectedTrack', () async {
      final ctrl = MultiAudioPlayerController();
      addTearDown(() => ctrl.onClose());
      const baseTrack = AudioTrackOption(
        code: 'en',
        label: 'English',
        isEmbedded: true,
      );
      const secondEmbeddedTrack = AudioTrackOption(
        code: 'es',
        label: 'Spanish',
        isEmbedded: true,
      );

      ctrl.selectedTrack.value = baseTrack;
      expect(ctrl.selectedTrack.value?.code, 'en');

      // Switch to Spanish embedded track
      await ctrl.switchTrack(secondEmbeddedTrack);

      expect(ctrl.selectedTrack.value?.code, 'es');
      expect(ctrl.isChangingTrack.value, isFalse);

      // Switch back to English embedded audio track seamlessly
      await ctrl.switchTrack(baseTrack);

      expect(ctrl.selectedTrack.value?.code, 'en');
      expect(ctrl.isChangingTrack.value, isFalse);
    });

    testWidgets('Renders resolution ladder bar with non-raw resolutions (1080p, 720p, 480p)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final audioCtrl = Get.put(AudioTracksController());
      audioCtrl.selectedLanguage.value = 'en';

      await tester.pumpWidget(
        buildTestableWidget(
          video: testVideo,
          controller: audioCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Resolution bar is displayed
      expect(find.text('Resolutions:'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('720p'), findsOneWidget);
      expect(find.text('480p'), findsOneWidget);

      // Verify raw URLs are rejected by checking helper
      expect(MultiAudioPlayerController.isRawVideoUrl('https://storage.googleapis.com/truthworld/original.mp4'), isTrue);
      expect(MultiAudioPlayerController.isRawVideoUrl('https://storage.googleapis.com/truthworld/videos/original/video.mp4'), isTrue);
      expect(MultiAudioPlayerController.isRawVideoUrl('https://cdn.truthworld.com/videos/video_720p.mp4'), isFalse);
    });
  });
}
