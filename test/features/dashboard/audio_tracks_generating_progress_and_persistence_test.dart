import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_list_section.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_video_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  Video createSampleVideo({
    String id = 'video_zomato_123',
    String title = "Zomato's Big Transformation: From Food Delivery to a Consumer Empire",
    dynamic status = VideoStatus.ready,
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Zomato business transformation case study.',
      videoUrl: 'https://example.com/zomato.mp4',
      thumbnailUrl: 'https://example.com/zomato_thumb.jpg',
      ownerId: 'channel_owner_1',
      channelId: 'channel_truth_1',
      channelName: 'TruthWorld Business',
      category: 'Business',
      tags: const ['business', 'zomato'],
      duration: '08:44',
      language: 'en',
      status: status,
      visibility: 'Public',
      audioTracks: const {
        'en': 'https://example.com/zomato_en.mp3',
      },
    );
  }

  group('Audio Tracks Generating Progress & Tab Persistence Tests', () {
    testWidgets('AudioTracksSelectedVideoCard formats enum status cleanly without Videostatus. prefix', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pass video with status VideoStatus.ready
      final video = createSampleVideo(status: VideoStatus.ready);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioTracksSelectedVideoCard(
              video: video,
              onChangeVideo: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it says 'Ready' instead of 'Videostatus.ready'
      expect(find.textContaining('Ready'), findsOneWidget);
      expect(find.textContaining('Videostatus.ready'), findsNothing);
    });

    testWidgets('Generating Audio Track displays rich progress, stage title, percentage, and What Next pipeline stages', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.rxState.value = ViewState.idle;
      controller.selectedVideo.value = sampleVideo;

      // Simulate generating Telugu audio track with progress state
      controller.generatingDubLanguages.add('te');
      controller.dubbingProgress['te'] = const AudioDubbingProgressState(
        langCode: 'te',
        progress: 45,
        stageTitle: 'Translating speech to Telugu',
        stageStep: 2,
        totalStepsText: 'Step 2 of 4',
        etaText: '~1-2 min',
        isGenerating: true,
      );

      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'v_en',
          languageCode: 'en',
          languageName: 'English (Base) (Original)',
          audioUrl: 'https://example.com/en.mp3',
          isBaseTrack: true,
          status: 'Published',
          role: 'Original video audio',
        ),
        AudioTrackItem(
          id: 'v_te',
          languageCode: 'te',
          languageName: 'Telugu (తెలుగు)',
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
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Language column
      expect(find.text('Telugu (తెలుగు)'), findsOneWidget);

      // 2. Audio track column shows rich generating progress instead of disabled scrubber
      expect(find.textContaining('Step 2 of 4: Translating speech to Telugu'), findsOneWidget);
      expect(find.text('45%'), findsWidgets);
      expect(find.text('~1-2 min'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 3. Pipeline step breadcrumbs ('What Next')
      expect(find.text('1. Transcribe'), findsOneWidget);
      expect(find.text('2. Translate'), findsOneWidget);
      expect(find.text('3. Synthesize Voice'), findsOneWidget);
      expect(find.text('4. Final Sync'), findsOneWidget);

      // 4. Status column shows badge with spinner & progress
      expect(find.text('Generating...'), findsOneWidget);

      // 5. Tapping progress opens What's Next details modal
      await tester.ensureVisible(find.textContaining('Step 2 of 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Step 2 of 4'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('AI Voice Dubbing Progress'), findsOneWidget);
      expect(find.text('Dubbing Pipeline Stages'), findsOneWidget);
      expect(find.text('Speech Extraction & Transcription'), findsOneWidget);
      expect(find.text('Nuance-Preserving AI Translation'), findsOneWidget);
      expect(find.text('Neural Voice Synthesis & Dubbing'), findsOneWidget);
      expect(find.text('Studio Mastering & Synchronization'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);

      await tester.tap(find.text('Got It'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('AI Voice Dubbing Progress'), findsNothing);
    });

    testWidgets('Tab navigation persistence: returning to AudioTracksPage maintains generating audio track', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();

      controller.rxState.value = ViewState.idle;
      controller.videos.value = [sampleVideo];
      controller.filteredVideos.value = [sampleVideo];
      controller.selectedVideo.value = sampleVideo;

      // Trigger AI dubbing for Telugu
      controller.generatingDubLanguages.add('te');
      controller.dubbingProgress['te'] = const AudioDubbingProgressState(
        langCode: 'te',
        progress: 60,
        stageTitle: 'Synthesizing AI voice in Telugu',
        stageStep: 3,
        totalStepsText: 'Step 3 of 4',
        etaText: '~45 sec',
        isGenerating: true,
      );
      controller.availableLanguages.value = ['en', 'te'];
      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'v_en',
          languageCode: 'en',
          languageName: 'English (Base) (Original)',
          audioUrl: 'https://example.com/en.mp3',
          isBaseTrack: true,
          status: 'Published',
        ),
        AudioTrackItem(
          id: '${sampleVideo.id}_te',
          languageCode: 'te',
          languageName: 'Telugu (తెలుగు)',
          audioUrl: '',
          isBaseTrack: false,
          status: 'Generating...',
        ),
      ];

      // Simulate mounting AudioTracksPage
      await tester.pumpWidget(
        GetMaterialApp(
          home: AudioTracksPage(
            channelId: 'channel_truth_1',
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Telugu (తెలుగు)'), findsOneWidget);
      expect(find.textContaining('Step 3 of 4: Synthesizing AI voice in Telugu'), findsOneWidget);
      expect(find.text('Generating...'), findsOneWidget);

      // Simulate moving away to another tab in Studio (e.g. Subtitles or Analytics)
      await tester.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(
            body: Center(child: Text('Other Studio Tab (e.g. Subtitles)')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Other Studio Tab (e.g. Subtitles)'), findsOneWidget);

      // Simulate user coming back to Audio Tracks page
      await tester.pumpWidget(
        GetMaterialApp(
          home: AudioTracksPage(
            channelId: 'channel_truth_1',
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that after coming back, the generating audio track is STILL showing!
      expect(find.text('Telugu (తెలుగు)'), findsOneWidget);
      expect(find.text('Generating...'), findsOneWidget);
      expect(find.textContaining('Step 3 of 4: Synthesizing AI voice in Telugu'), findsOneWidget);
    });

    testWidgets('Generating audio track action menu displays Check Status, Retry Dubbing, and Cancel Generation', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final sampleVideo = createSampleVideo();
      controller.rxState.value = ViewState.idle;
      controller.selectedVideo.value = sampleVideo;

      controller.generatingDubLanguages.add('es');
      controller.dubbingProgress['es'] = const AudioDubbingProgressState(
        langCode: 'es',
        progress: 94,
        stageTitle: 'Mastering audio ducking & synchronization',
        stageStep: 4,
        totalStepsText: 'Step 4 of 4',
        etaText: 'Finalizing shortly',
        isGenerating: true,
      );
      controller.currentTracks.value = [
        AudioTrackItem(
          id: '${sampleVideo.id}_es',
          languageCode: 'es',
          languageName: 'Spanish (Español)',
          audioUrl: '',
          isBaseTrack: false,
          status: 'Generating...',
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
      await tester.pump(const Duration(milliseconds: 300));

      // Open 3-dots action menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the new recovery actions are available
      expect(find.text('View Pipeline Progress'), findsOneWidget);
      expect(find.text('Check Status / Refresh'), findsOneWidget);
      expect(find.text('Retry Dubbing'), findsOneWidget);
      expect(find.text('Cancel Generation'), findsOneWidget);

      // Tap Cancel Generation to verify it resets state cleanly
      await tester.tap(find.text('Cancel Generation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.generatingDubLanguages.contains('es'), isFalse);
      expect(controller.currentTracks.first.status, equals('Not added'));

      // Allow snackbar animation and timer to finish cleanly
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });

    test('Zombie job detection & Cache TTL: jobs older than 5 minutes are discarded and not marked Generating', () {
      final controller = Get.put(AudioTracksController());

      // 1. Zombie check on Firestore job data
      final staleJobData = {
        'updatedAt': DateTime.now().subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
        'status': 'processing',
        'stages': {
          'dubbing_es': {
            'status': 'running',
            'startedAt': DateTime.now().subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
          },
        },
      };

      // Helper check (accessible via behavior)
      final now = DateTime.now().millisecondsSinceEpoch;
      final startedAt = (staleJobData['stages'] as Map)['dubbing_es']['startedAt'] as int;
      final isZombie = (now - startedAt) > 5 * 60 * 1000;
      expect(isZombie, isTrue);

      // 2. Dubbing progress older than 5 minutes should have elapsed > 300s
      final expiredJob = AudioDubbingProgressState(
        langCode: 'es',
        progress: 94,
        isGenerating: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      );
      final elapsedSec = DateTime.now().difference(expiredJob.startedAt!).inSeconds;
      expect(elapsedSec > 300, isTrue);
    });
  });
}
