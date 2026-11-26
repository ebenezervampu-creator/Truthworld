import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_list_section.dart';
import 'package:truthworld/features/dubbing/data/dubbing_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/dubbing_studio_screen.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

class _TestDubbingStudioController extends DubbingStudioController {
  @override
  Future<void> refreshWallet() async {}

  @override
  Future<void> loadUserChannelAndVideos() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Dubbing Output Artifacts (Studio & Audio Tracks)', () {
    test('DubbingService.mergeJobWithVideoJobData maps all 7 output artifacts to exportUrls', () {
      final studioData = <String, dynamic>{
        'id': 'dub_1',
        'userId': 'u1',
        'title': 'Test Dub',
        'mode': 'dubbing',
        'status': 'processing',
        'progressPercent': 90,
        'currentStepMessage': 'Muxing...',
        'sourceMediaUrl': 'https://example.com/original.mp4',
        'sourceMediaType': 'video',
        'durationSeconds': 45,
        'characterCount': 500,
        'sourceLanguage': 'en',
        'targetLanguages': ['te'],
        'pipelineJobId': 'job_1',
        'createdAt': 1700000000000,
      };

      final merged = DubbingService.mergeJobWithVideoJobData(studioData, {
        'status': 'completed',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'completed', 'progress': 100},
        },
        'outputs': {
          'dubbedVideos': {'te': 'https://cdn.example.com/video_with_te_dub.mp4'},
          'audioTracks': {'te': 'https://cdn.example.com/dub_te.mp3'},
          'dialogueTracks': {'te': 'https://cdn.example.com/dialogue_te.mp3'},
          'translations': {'te': 'https://cdn.example.com/translation_te.json'},
          'subtitles': {'te': 'https://cdn.example.com/te.srt'},
          'dubbingReportUrl': 'https://cdn.example.com/report.json',
          'stems': {
            'vocals': 'https://cdn.example.com/vocals_stem.mp3',
            'background': 'https://cdn.example.com/background_stem.mp3',
          },
        },
      });

      expect(merged.status, DubbingJobStatus.completed);
      expect(merged.dubbedVideoByLanguage['te'], 'https://cdn.example.com/video_with_te_dub.mp4');
      expect(merged.dubbedAudioByLanguage['te'], 'https://cdn.example.com/dub_te.mp3');
      expect(merged.dialogueAudioByLanguage['te'], 'https://cdn.example.com/dialogue_te.mp3');
      expect(merged.translationJsonByLanguage['te'], 'https://cdn.example.com/translation_te.json');
      expect(merged.vocalsStemMp3, 'https://cdn.example.com/vocals_stem.mp3');
      expect(merged.backgroundStemMp3, 'https://cdn.example.com/background_stem.mp3');
      expect(merged.reportJson, 'https://cdn.example.com/report.json');
      expect(merged.subtitlesSrt['te'], 'https://cdn.example.com/te.srt');
    });

    test('DubbingService converts gs:// URLs and reads legacy dotted keys on video_jobs', () {
      final studioData = <String, dynamic>{
        'id': 'dub_2',
        'userId': 'u1',
        'title': 'Legacy Dotted Dub',
        'mode': 'dubbing',
        'status': 'completed',
        'progressPercent': 100,
        'currentStepMessage': 'Done',
        'sourceMediaUrl': 'https://example.com/original.mp4',
        'sourceMediaType': 'video',
        'durationSeconds': 25,
        'characterCount': 200,
        'sourceLanguage': 'en',
        'targetLanguages': ['te'],
        'pipelineJobId': 'job_2',
        'createdAt': 1700000000000,
      };

      final merged = DubbingService.mergeJobWithVideoJobData(studioData, {
        'status': 'completed',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'completed', 'progress': 100},
        },
        'outputs.dubbedVideos.te': 'gs://truthworld-bucket/videos/job_2/te-dubbed.mp4',
        'outputs.audioTracks.te': 'gs://truthworld-bucket/audio/job_2/te/master.mp3',
        'outputs.dialogueTracks.te': 'gs://truthworld-bucket/audio/job_2/te/stitched.mp3',
        'outputs.translations.te': 'gs://truthworld-bucket/translations/job_2/translation_te.json',
        'outputs.subtitles.te': 'gs://truthworld-bucket/subtitles/job_2/te.srt',
        'outputs.stems.vocals': 'gs://truthworld-bucket/audio/job_2/vocals_demucs.mp3',
        'outputs.stems.mne': 'gs://truthworld-bucket/audio/job_2/m_and_e.mp3',
        'outputs.dubbingReportUrl': 'gs://truthworld-bucket/dubbing/job_2/report.json',
      });

      expect(
        merged.dubbedVideoByLanguage['te'],
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/videos%2Fjob_2%2Fte-dubbed.mp4?alt=media',
      );
      expect(
        merged.dubbedAudioByLanguage['te'],
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/audio%2Fjob_2%2Fte%2Fmaster.mp3?alt=media',
      );
      expect(
        merged.dialogueAudioByLanguage['te'],
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/audio%2Fjob_2%2Fte%2Fstitched.mp3?alt=media',
      );
      expect(
        merged.translationJsonByLanguage['te'],
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/translations%2Fjob_2%2Ftranslation_te.json?alt=media',
      );
      expect(
        merged.vocalsStemMp3,
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/audio%2Fjob_2%2Fvocals_demucs.mp3?alt=media',
      );
      expect(
        merged.backgroundStemMp3,
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/audio%2Fjob_2%2Fm_and_e.mp3?alt=media',
      );
      expect(
        merged.reportJson,
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/dubbing%2Fjob_2%2Freport.json?alt=media',
      );
      expect(
        merged.subtitlesSrt['te'],
        'https://firebasestorage.googleapis.com/v0/b/truthworld-bucket/o/subtitles%2Fjob_2%2Fte.srt?alt=media',
      );
    });

    testWidgets('DubbingStudioScreen renders all 7 Output Artifacts for completed dub job', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = Get.put<AuthService>(AuthService(), permanent: true);
      authService.setAuthenticatedForTesting(isAuthenticated: true, uid: 'u1');
      authService.userDisplayName.value = 'Creator';

      final controller = Get.put<DubbingStudioController>(_TestDubbingStudioController());
      controller.activeJob.value = DubbingJob(
        id: 'dub_te_1',
        userId: 'u1',
        title: 'Telugu Dub Test',
        mode: DubbingMode.dubbing,
        status: DubbingJobStatus.completed,
        progressPercent: 100,
        currentStepMessage: 'Ready to download',
        sourceMediaUrl: 'https://example.com/orig.mp4',
        sourceMediaType: 'video',
        durationSeconds: 30,
        characterCount: 300,
        sourceLanguage: 'en',
        targetLanguages: ['te'],
        voiceCloningEnabled: false,
        twoStageReviewEnabled: false,
        publishToTruthworld: false,
        costUsd: 0.30,
        totalCharactersCharged: 300,
        speakers: const [],
        segmentsByLanguage: const {},
        createdAt: DateTime(2026),
        exportUrls: const {
          'dubbedVideoByLanguage': {'te': 'https://example.com/video_with_te_dub.mp4'},
          'dubbedAudioByLanguage': {'te': 'https://example.com/dub_te.mp3'},
          'dialogueAudioByLanguage': {'te': 'https://example.com/dialogue_te.mp3'},
          'translationJsonByLanguage': {'te': 'https://example.com/translation_te.json'},
          'vocalsStemMp3': 'https://example.com/vocals_stem.mp3',
          'backgroundStemMp3': 'https://example.com/background_stem.mp3',
          'reportJson': 'https://example.com/report.json',
          'subtitlesSrt': {'te': 'https://example.com/te.srt'},
        },
      );

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DubbingStudioScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Output Artifacts & Downloads'), findsOneWidget);
      expect(find.text('Dubbed MP4 (video_with_te_dub.mp4)'), findsOneWidget);
      expect(find.text('Master Audio (dub_te.mp3)'), findsOneWidget);
      expect(find.text('Dialogue-only TTS (dialogue_te.mp3)'), findsOneWidget);
      expect(find.text('Translation (translation_te.json)'), findsOneWidget);
      expect(find.text('Vocals Stem (vocals_stem.mp3)'), findsOneWidget);
      expect(find.text('Background Stem (background_stem.mp3)'), findsOneWidget);
      expect(find.text('Report (report.json)'), findsOneWidget);
      expect(find.text('Original (EN)'), findsOneWidget);
      expect(find.text('Dubbed • Telugu'), findsOneWidget);
      expect(find.text('Download Dubbed MP4'), findsOneWidget);
    });

    test('DubbingService.mergeJobWithVideoJobData merges late-arriving dubbedVideos into existing exportUrls', () {
      final studioData = <String, dynamic>{
        'id': 'dub_2',
        'userId': 'u1',
        'title': 'Late MP4 Test',
        'mode': 'dubbing',
        'status': 'completed',
        'progressPercent': 100,
        'currentStepMessage': 'Completed',
        'sourceMediaUrl': 'https://example.com/original.mp4',
        'sourceMediaType': 'video',
        'durationSeconds': 32,
        'characterCount': 500,
        'sourceLanguage': 'en',
        'targetLanguages': ['te'],
        'pipelineJobId': 'job_2',
        'createdAt': 1700000000000,
        'exportUrls': {
          'dubbedVideoByLanguage': <String, dynamic>{},
          'dubbedAudioByLanguage': {'te': 'https://cdn.example.com/dub_te.mp3'},
        },
      };

      final merged = DubbingService.mergeJobWithVideoJobData(studioData, {
        'status': 'completed',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'completed', 'progress': 100},
        },
        'outputs': {
          'dubbedVideos': {'te': 'https://cdn.example.com/video_with_te_dub.mp4'},
          'audioTracks': {'te': 'https://cdn.example.com/dub_te.mp3'},
        },
      });

      expect(merged.dubbedVideoUrlFor('te'), 'https://cdn.example.com/video_with_te_dub.mp4');
      expect(merged.dubbedAudioUrlFor('te'), 'https://cdn.example.com/dub_te.mp3');
    });

    testWidgets('AudioTracksListSection exposes Output Artifacts action on published dubbed track', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final video = Video(
        id: 'vid_te_1',
        title: 'Sample Video',
        description: 'Desc',
        videoUrl: 'https://example.com/orig.mp4',
        language: 'en',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel 1',
        category: 'Education',
        tags: const ['test'],
        audioTracks: const {
          'en': 'https://example.com/en.mp3',
          'te': 'https://example.com/dub_te.mp3',
        },
        dubbedVideos: const {
          'te': 'https://example.com/video_with_te_dub.mp4',
        },
      );

      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'vid_te_1_te',
          languageCode: 'te',
          languageName: 'Telugu',
          audioUrl: 'https://example.com/dub_te.mp3',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksListSection(
              video: video,
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              surfaceColor: const Color(0xFF141414),
              borderColor: const Color(0xFF262626),
              isDarkMode: true,
              onAddDubTrack: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Output Artifacts'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Output Artifacts'), findsOneWidget);
    });
  });
}
