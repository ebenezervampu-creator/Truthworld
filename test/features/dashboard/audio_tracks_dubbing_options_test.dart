import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_track_dubbing_options_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_list_section.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  Video createSampleVideo({String duration = '00:45'}) {
    return Video(
      id: 'video_zomato_123',
      title: "Zomato's Food Transformation Story",
      description: 'Zomato transforming Indian food ecosystem.',
      videoUrl: 'https://example.com/zomato.mp4',
      thumbnailUrl: 'https://example.com/zomato_thumb.jpg',
      ownerId: 'user_1',
      channelId: 'channel_1',
      channelName: 'TruthWorld Business',
      category: 'Business',
      tags: const ['business', 'zomato'],
      duration: duration,
      language: 'en',
      status: 'Published',
      visibility: 'Public',
      audioTracks: const {
        'en': 'https://example.com/zomato_en.mp3',
      },
    );
  }

  group('Audio Track Dubbing Options & Studio Guide Tests', () {
    testWidgets('AudioTrackDubbingOptionsDialog renders AI Dubbing tab with all options', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.selectedVideo.value = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTrackDubbingOptionsDialog(
              controller: controller,
              initialLangCode: 'zh',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Language
      expect(find.text('Audio Track & Dubbing Options'), findsOneWidget);
      expect(find.text('Target Language:'), findsOneWidget);

      // Tab switcher
      expect(find.text('AI Voice Dubbing'), findsOneWidget);
      expect(find.text('Direct Audio Track'), findsOneWidget);

      // AI Dubbing options
      expect(find.text('1. Vocal Identity & Synthesis Style'), findsOneWidget);
      expect(find.text('Standard Neural Voice'), findsOneWidget);
      expect(find.text('Studio Voice Cloning'), findsOneWidget);

      // Diarization & Audio Ducking
      expect(find.text('Speaker Diarization (Multi-Person Videos)'), findsOneWidget);
      expect(find.textContaining('Smart Audio Ducking'), findsOneWidget);

      // Live Pricing Card & Button
      expect(find.text('AI Dubbing Flat Rate'), findsOneWidget);
      expect(find.text('Start AI Voice Dubbing'), findsOneWidget);
    });

    testWidgets('AudioTrackDubbingOptionsDialog switches pricing reactively between Standard Dubbing and Studio Voice Cloning', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo(duration: '00:45'); // duration 45s -> Shorts & Clips tier ($0.10 standard / $0.20 voice clone)
      controller.selectedVideo.value = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTrackDubbingOptionsDialog(
              controller: controller,
              initialLangCode: 'zh',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Standard Neural Voice is selected by default
      expect(find.text('AI Dubbing Flat Rate'), findsOneWidget);
      expect(find.text(r'$0.10'), findsOneWidget);

      // Tap Studio Voice Cloning
      await tester.ensureVisible(find.text('Studio Voice Cloning'));
      await tester.tap(find.text('Studio Voice Cloning'));
      await tester.pumpAndSettle();

      // Flat rate card updates to Studio Voice Cloning rate ($0.30 for shorts in 5-tier pricing)
      expect(find.text('Studio Voice Cloning Flat Rate'), findsOneWidget);
      expect(find.text(r'$0.30'), findsOneWidget);

      // Tap back to Standard Neural Voice
      await tester.ensureVisible(find.text('Standard Neural Voice'));
      await tester.tap(find.text('Standard Neural Voice'));
      await tester.pumpAndSettle();

      // Resets back to Standard Dubbing Flat Rate ($0.10)
      expect(find.text('AI Dubbing Flat Rate'), findsOneWidget);
      expect(find.text(r'$0.10'), findsOneWidget);
    });

    testWidgets('AudioTrackDubbingOptionsDialog respects Super Admin Free Dubbing waiver without balance errors', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo(duration: '00:45');
      controller.selectedVideo.value = sampleVideo;

      final dialog = AudioTrackDubbingOptionsDialog(
        controller: controller,
        initialLangCode: 'te',
        isDarkMode: true,
      );

      // Simulate Super Admin Free Dubbing benefit on the channel
      final freeChannel = Channel.fromMap({
        'name': 'TruthWorld Channel',
        'handle': '@truthworld',
        'dubbingDiscountType': 'free',
        'dubbingDiscountPercent': 100.0,
      }, 'channel_1');
      dialog.currentChannel.value = freeChannel;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: dialog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badges display FREE
      expect(find.text('Google Chirp 3: HD • FREE'), findsOneWidget);
      expect(find.text('Vocal Identity • FREE'), findsOneWidget);

      // Pricing card displays 100% FREE (Super Admin)
      expect(find.text('100% FREE (Super Admin)'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);

      // Verify no overflow banner exists
      expect(find.textContaining('OVERFLOWED'), findsNothing);

      // Tap 'Start AI Voice Dubbing' - must NOT show Insufficient channel wallet balance
      await tester.tap(find.text('Start AI Voice Dubbing'), warnIfMissed: false);
      await tester.pump();

      expect(find.textContaining('Insufficient channel wallet balance'), findsNothing);
    });

    testWidgets('AudioTrackDubbingOptionsDialog switches to Direct Audio Track tab and shows Studio Guide', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.selectedVideo.value = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTrackDubbingOptionsDialog(
              controller: controller,
              initialLangCode: 'zh',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Direct Audio Track tab
      await tester.tap(find.text('Direct Audio Track'));
      await tester.pumpAndSettle();

      // Studio Guide items
      expect(find.text('Where to Get Direct Audio Tracks (Studio Guide)'), findsOneWidget);
      expect(find.text('Download Original Audio'), findsOneWidget);
      expect(find.text('Download Reference Audio'), findsOneWidget);
      expect(find.text('Translate & Record in External Studio / DAW'), findsOneWidget);
      expect(find.text('Audio Specifications & Alignment Checklist'), findsOneWidget);

      // Direct Track Upload section
      expect(find.text('Upload Finished Direct Audio Track'), findsOneWidget);
      expect(find.text('Click to select audio file (.mp3, .wav, .m4a, .aac)'), findsOneWidget);
      expect(find.text('Upload & Attach Track'), findsOneWidget);
    });

    testWidgets('AudioTracksListSection displays Studio Direct Audio Guide and Add Dubbing Options', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.rxState.value = ViewState.idle;
      controller.selectedVideo.value = sampleVideo;

      // Add a track in Chinese with 'Not added' status matching user's screenshot
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
          id: 'v_zh',
          languageCode: 'zh',
          languageName: 'Chinese (中文 / Mandarin)',
          audioUrl: '',
          isBaseTrack: false,
          status: 'Not added',
          role: 'Dubbing',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksListSection(
              video: sampleVideo,
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: AppColors.textSecondary,
              surfaceColor: const Color(0xFF161618),
              borderColor: const Color(0xFF27272A),
              isDarkMode: true,
              onAddDubTrack: () {},
              onAddCommentary: () {},
              onPickAndUploadSingleDub: (lang) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Studio Guide banner on Audio Track page
      expect(find.text('Where to Get Direct Audio Tracks (Studio Guide)'), findsOneWidget);
      expect(find.text('Download Reference Audio'), findsOneWidget);

      // Chinese track with 'Not added' and 'Add' button
      expect(find.text('Chinese (中文 / Mandarin)'), findsOneWidget);
      expect(find.text('Not added'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // Tapping 'Add' opens AudioTrackDubbingOptionsDialog
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Audio Track & Dubbing Options'), findsOneWidget);
      expect(find.text('Start AI Voice Dubbing'), findsOneWidget);
    });

    testWidgets('Audio track displays Generating... badge when AI dubbing is in progress', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.rxState.value = ViewState.idle;
      controller.selectedVideo.value = sampleVideo;

      // Mark Chinese as currently generating AI dub
      controller.generatingDubLanguages.add('zh');
      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'v_zh',
          languageCode: 'zh',
          languageName: 'Chinese (中文 / Mandarin)',
          audioUrl: '',
          isBaseTrack: false,
          status: 'Generating...',
          role: 'Dubbing',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksListSection(
              video: sampleVideo,
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: AppColors.textSecondary,
              surfaceColor: const Color(0xFF161618),
              borderColor: const Color(0xFF27272A),
              isDarkMode: true,
              onAddDubTrack: () {},
              onAddCommentary: () {},
              onPickAndUploadSingleDub: (lang) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Chinese (中文 / Mandarin)'), findsOneWidget);
      expect(find.text('Generating...'), findsOneWidget);
    });

    testWidgets('AudioTrackDubbingOptionsDialog shows ONLY Cloud Chirp 3: HD supported languages when no voice cloning', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.selectedVideo.value = sampleVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTrackDubbingOptionsDialog(
              controller: controller,
              initialLangCode: 'te',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In standard mode (no voice cloning), Chirp 3: HD badge is shown
      expect(find.text('Chirp 3: HD'), findsOneWidget);

      // Verify dropdown items when no voice cloning
      final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      final displayedCodes = dropdown.items!.map((item) => item.value!).toSet();

      // Must contain Chirp 3: HD languages (Telugu, Hindi, Tamil, Kannada, Marathi, English, Spanish, etc.)
      expect(displayedCodes.contains('te'), isTrue);
      expect(displayedCodes.contains('hi'), isTrue);
      expect(displayedCodes.contains('ta'), isTrue);
      expect(displayedCodes.contains('kn'), isTrue);
      expect(displayedCodes.contains('mr'), isTrue);
      expect(displayedCodes.contains('en'), isTrue);

      // Must NOT contain languages unsupported by Chirp 3: HD (e.g. Urdu, Nepali, Assamese, Sindhi)
      expect(displayedCodes.contains('ur'), isFalse);
      expect(displayedCodes.contains('ne'), isFalse);
      expect(displayedCodes.contains('as'), isFalse);
      expect(displayedCodes.contains('sd'), isFalse);

      // Switch to Studio Voice Cloning
      await tester.ensureVisible(find.text('Studio Voice Cloning'));
      await tester.tap(find.text('Studio Voice Cloning'));
      await tester.pumpAndSettle();

      // Dropdown expands to include full supported languages (including Urdu, Nepali, etc.)
      final clonedDropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      final clonedCodes = clonedDropdown.items!.map((item) => item.value!).toSet();
      expect(clonedCodes.contains('ur'), isTrue);
      expect(clonedCodes.contains('ne'), isTrue);
    });
  });
}
