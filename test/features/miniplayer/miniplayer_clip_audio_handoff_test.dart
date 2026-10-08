import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/data/services/miniplayer_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_audio_stage.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });
  group('Miniplayer Clip & Audio-Only Handoff Tests', () {
    late MiniplayerController controller;
    final testVideo = Video(
      id: 'clip_audio_vid_1',
      title: 'Global Energy Transition',
      description: 'Documentary on renewable energy solutions',
      thumbnailUrl: 'https://images.unsplash.com/photo-1497435334941-8c899ee9e8e9',
      videoUrl: 'https://example.com/video.mp4',
      ownerId: 'owner_99',
      channelId: 'chan_99',
      channelName: 'Earth Science',
      category: 'Science',
      tags: const ['energy', 'climate'],
      vDurationValue: const Duration(minutes: 10),
    );

    final testClip = VideoClip(
      id: 'clip_solar_breakthrough',
      videoId: 'clip_audio_vid_1',
      userId: 'user_1',
      title: 'Solar Cell Efficiency Breakthrough',
      startTime: 60.0, // 1:00
      endTime: 95.0,   // 1:35 (duration: 35s)
      thumbnailUrl: 'https://images.unsplash.com/photo-1509391365360-2e959784a276',
      videoTitle: 'Global Energy Transition',
      channelName: 'Earth Science',
      createdAt: DateTime.now(),
    );

    setUp(() {
      Get.testMode = true;
      Get.reset();
      Get.put<ConnectivityService>(ConnectivityService());
      controller = Get.put(
        MiniplayerController(),
        tag: 'miniplayer',
      );
    });

    tearDown(() {
      controller.dismiss();
      controller.onClose();
      Get.delete<MiniplayerController>(tag: 'miniplayer', force: true);
      VideoPlaybackHandoff.clear(testVideo.id);
      Get.reset();
    });

    test('MiniplayerVideoInfo correctly captures clip and audioOnly state', () {
      final info = MiniplayerVideoInfo.fromVideo(
        testVideo,
        clip: testClip,
        isAudioOnly: true,
      );

      expect(info.id, equals(testVideo.id));
      expect(info.clip, equals(testClip));
      expect(info.isClip, isTrue);
      expect(info.clipTitle, equals('Solar Cell Efficiency Breakthrough'));
      expect(info.isAudioOnly, isTrue);
    });

    test('showWithVideo initializes relative duration and position for clip', () async {
      await controller.showWithVideo(
        testVideo,
        clip: testClip,
        resumeFromPosition: const Duration(seconds: 70), // 10s into the 35s clip
      );

      expect(controller.activeClip.value, equals(testClip));
      expect(controller.isClip, isTrue);
      expect(controller.isAudioOnly.value, isFalse);
      // Clip duration is 95s - 60s = 35s
      expect(controller.totalDuration.value, equals(const Duration(seconds: 35)));
      // Relative position is 70s - 60s = 10s
      expect(controller.currentPosition.value, equals(const Duration(seconds: 10)));
    });

    test('showWithVideo initializes with audioOnly mode', () async {
      await controller.showWithVideo(
        testVideo,
        isAudioOnly: true,
      );

      expect(controller.isAudioOnly.value, isTrue);
      expect(controller.videoInfo.value?.isAudioOnly, isTrue);
    });

    test('dismiss resets activeClip and isAudioOnly', () async {
      await controller.showWithVideo(
        testVideo,
        clip: testClip,
        isAudioOnly: true,
      );

      expect(controller.activeClip.value, isNotNull);
      expect(controller.isAudioOnly.value, isTrue);

      controller.dismiss();

      expect(controller.activeClip.value, isNull);
      expect(controller.isClip, isFalse);
      expect(controller.isAudioOnly.value, isFalse);
      expect(controller.videoInfo.value, isNull);
      expect(controller.currentPosition.value, equals(Duration.zero));
    });

    test('clearActiveClip resets duration to full video duration', () async {
      await controller.showWithVideo(
        testVideo,
        clip: testClip,
      );

      expect(controller.isClip, isTrue);
      expect(controller.totalDuration.value, equals(const Duration(seconds: 35)));

      controller.clearActiveClip();

      expect(controller.isClip, isFalse);
      expect(controller.activeClip.value, isNull);
      expect(controller.totalDuration.value, equals(testVideo.durationValue));
    });

    test('seekToRatio clamps seeking within clip boundary', () async {
      await controller.showWithVideo(
        testVideo,
        clip: testClip,
      );

      // Seek to 50% of the clip (35s * 0.5 = 17.5s)
      await controller.seekToRatio(0.5);

      expect(controller.currentPosition.value.inMilliseconds, closeTo(17500, 100));
    });

    testWidgets('MiniplayerAudioStage renders equalizer, album art, and badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: MiniplayerAudioStage(
                controller: controller,
                thumbnailUrl: testVideo.thumbnailUrl,
                isPlaying: true,
                isCompact: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MiniplayerAudioStage), findsOneWidget);
      expect(find.text('AUDIO ONLY'), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    });

    test('MiniplayerService forwards clip and isAudioOnly arguments', () async {
      final service = Get.put(MiniplayerService());

      await service.showWithVideo(
        testVideo,
        clip: testClip,
        isAudioOnly: true,
        resumeFromPosition: const Duration(seconds: 65),
      );

      expect(controller.activeClip.value, equals(testClip));
      expect(controller.isAudioOnly.value, isTrue);
      expect(controller.currentPosition.value, equals(const Duration(seconds: 5)));

      controller.dismiss();
      Get.delete<MiniplayerService>();
    });
  });
}
