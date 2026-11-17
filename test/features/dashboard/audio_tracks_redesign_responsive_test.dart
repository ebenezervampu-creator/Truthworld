import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_video_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  Video createSampleVideo({
    String id = 'video_zomato',
    String title = "Zomato's Big Transformation in India",
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Zomato transforming Indian food delivery ecosystem.',
      videoUrl: 'https://example.com/zomato.mp4',
      thumbnailUrl: 'https://example.com/zomato_thumb.jpg',
      ownerId: 'user_channel_1',
      channelId: 'channel_truth_1',
      channelName: 'TruthWorld Business',
      category: 'Business',
      tags: const ['business', 'zomato', 'india'],
      duration: '08:44',
      language: 'en',
      status: 'Published',
      visibility: 'Public',
      audioTracks: const {
        'en': 'https://example.com/zomato_en.mp3',
        'te': 'https://example.com/zomato_te.mp3',
        'hi': 'https://example.com/zomato_hi.mp3',
        'ta': 'https://example.com/zomato_ta.mp3',
      },
    );
  }

  group('Redesigned Audio Tracks Tab - UI & 100% Responsiveness', () {
    testWidgets('Desktop layout (1200x800) renders full studio UI matching mockup', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();

      final page = AudioTracksPage(
        channelId: 'channel_truth_1',
        isDarkMode: true,
      );

      controller.rxState.value = ViewState.idle;
      controller.videos.value = [sampleVideo];
      controller.filteredVideos.value = [sampleVideo];
      controller.selectedVideo.value = sampleVideo;
      controller.availableLanguages.value = ['en', 'te', 'hi', 'ta', 'kn'];

      // Populate tracks exactly as in mockup
      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'v_en',
          languageCode: 'en',
          languageName: 'English (Original)',
          audioUrl: 'https://example.com/en.mp3',
          isBaseTrack: true,
          status: 'Published',
          role: 'Original video audio',
        ),
        AudioTrackItem(
          id: 'v_te',
          languageCode: 'te',
          languageName: 'Telugu',
          audioUrl: 'https://example.com/te.mp3',
          isBaseTrack: false,
          status: 'Published',
          role: 'Dubbing',
        ),
        AudioTrackItem(
          id: 'v_hi',
          languageCode: 'hi',
          languageName: 'Hindi',
          audioUrl: 'https://example.com/hi.mp3',
          isBaseTrack: false,
          status: 'Published',
          role: 'Dubbing',
        ),
        AudioTrackItem(
          id: 'v_ta',
          languageCode: 'ta',
          languageName: 'Tamil',
          audioUrl: 'https://example.com/ta.mp3',
          isBaseTrack: false,
          status: 'Draft',
          role: 'Dubbing',
        ),
        AudioTrackItem(
          id: 'v_kn',
          languageCode: 'kn',
          languageName: 'Kannada',
          audioUrl: '',
          isBaseTrack: false,
          status: 'Not added',
          role: 'Dubbing',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: AudioTracksPage(
            channelId: 'channel_truth_1',
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();

      // 1. Header verification
      expect(find.text('Audio & Video'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);

      // 2. Underlined Tabs verification (Audio Tracks only, VideoTracks tab completely removed)
      expect(find.byType(AudioTracksUnderlineTabBar), findsOneWidget);
      expect(find.text('Audio Tracks'), findsWidgets);
      expect(find.text('VideoTracks'), findsNothing);

      // 4. Available Audio tracks header verification
      expect(find.text('Available Audio tracks'), findsOneWidget);
      expect(
        find.textContaining('Manage available multi-language audio and voiceover streams'),
        findsOneWidget,
      );

      // 5. Action buttons verification: + Audio button placed before Download button
      expect(find.text('Audio'), findsWidgets);
      expect(find.text('Download'), findsOneWidget);

      // 6. Audio progress bar above download button and in track cards are removed (only single video scrubber slider exists)
      expect(find.byType(Slider), findsOneWidget);

      // 7. Track items shown as language tabs in video player above
      expect(find.textContaining('English'), findsWidgets);
      expect(find.textContaining('Telugu'), findsWidgets);
      expect(find.textContaining('Hindi'), findsWidgets);
    });

    testWidgets('Mobile layout (375x812 iPhone SE) is 100% responsive without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();

      final page = AudioTracksPage(
        channelId: 'channel_truth_1',
        isDarkMode: true,
      );

      controller.rxState.value = ViewState.idle;
      controller.videos.value = [sampleVideo];
      controller.filteredVideos.value = [sampleVideo];
      controller.selectedVideo.value = sampleVideo;
      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'v_en',
          languageCode: 'en',
          languageName: 'English (Original)',
          audioUrl: 'https://example.com/en.mp3',
          isBaseTrack: true,
          status: 'Published',
        ),
        AudioTrackItem(
          id: 'v_kn',
          languageCode: 'kn',
          languageName: 'Kannada',
          audioUrl: '',
          isBaseTrack: false,
          status: 'Not added',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: AudioTracksPage(
            channelId: 'channel_truth_1',
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();

      // Ensure no overflow exception was caught
      expect(tester.takeException(), isNull);

      // Verify mobile components
      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
      expect(find.text('Audio Tracks'), findsWidgets);
      expect(find.text('VideoTracks'), findsNothing);
      expect(find.text('Audio'), findsWidgets);
      expect(find.text('Download'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('showAddAudioOptionsSheet opens bottom sheet with Generate Audio and Add files options', (tester) async {
      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.selectedVideo.value = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AudioTracksDialogs.showAddAudioOptionsSheet(
                  context: ctx,
                  controller: controller,
                  isDarkMode: true,
                ),
                child: const Text('Open Add Audio Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Add Audio Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Add Audio Track'), findsOneWidget);
      expect(find.text('Generate Audio tracks'), findsOneWidget);
      expect(find.text('Upload Audio track from device video/Audio'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
    });
  });
}
