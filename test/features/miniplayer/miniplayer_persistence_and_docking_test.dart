import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupMockFirebase();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  group('Miniplayer Persistence & Docking Tests', () {
    late MiniplayerController controller;
    final testVideo = Video(
      id: 'cyclone_arnab_2026',
      title: 'Cyclone Arnab 2026 🌪️ | Storm Impact, Relief Operations',
      description: 'Coverage and factual breakdown of Cyclone Arnab relief efforts',
      thumbnailUrl: 'https://images.unsplash.com/photo-1527482797697-8795b05a13fe',
      videoUrl: 'https://example.com/cyclone.mp4',
      ownerId: 'owner_news',
      channelId: 'chan_news',
      channelName: 'Weather Truth Network',
      category: 'News',
      tags: const ['cyclone', 'weather', 'arnab'],
      vDurationValue: const Duration(seconds: 300), // 5 min
    );

    setUp(() {
      Get.testMode = true;
      Get.reset();
      try {
        GetStorage().erase();
      } catch (_) {}
      Get.put<AuthService>(AuthService(), permanent: true);
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
      Get.put<WatchHistoryService>(WatchHistoryService(), permanent: true);
      controller = Get.put(MiniplayerController(), tag: 'miniplayer');
    });

    tearDown(() {
      controller.dismiss();
      controller.onClose();
      Get.delete<MiniplayerController>(tag: 'miniplayer', force: true);
      VideoPlaybackHandoff.clear(testVideo.id);
      Get.reset();
    });

    test('dismiss() persists watch progress and resume position to WatchHistoryService', () async {
      final watchHistory = WatchHistoryService.to;
      expect(watchHistory.getProgress(testVideo.id), equals(0.0));

      // Simulate video loaded in miniplayer
      controller.currentVideo.value = testVideo;
      controller.videoInfo.value = MiniplayerVideoInfo.fromVideo(testVideo);
      controller.mode.value = MiniplayerMode.collapsed;

      // Simulate playback having progressed to 120s of 300s (40%)
      controller.currentPosition.value = const Duration(seconds: 120);
      controller.totalDuration.value = const Duration(seconds: 300);

      // Dismiss miniplayer (e.g. user taps close ✕)
      controller.dismiss();

      // Verify watch progress is immediately persisted into WatchHistoryService
      expect(watchHistory.watchProgressMap[testVideo.id], equals(40.0));
      expect(watchHistory.getProgress(testVideo.id), equals(40.0));
      expect(watchHistory.getLastPosition(testVideo.id), equals(120));

      // Verify VideoPlaybackHandoff resume timestamp is registered
      final resume = VideoPlaybackHandoff.peekPosition(testVideo.id);
      expect(resume, equals(const Duration(seconds: 120)));
    });

    test('showWithVideo() resets dragOffset to null so card docks to bottom-right', () async {
      const mobileScreen = Size(390.0, 844.0);
      const cardSize = Size(195.0, 110.0);

      // User drags the previous miniplayer card into the middle of the viewport
      controller.dragOffset.value = const Offset(50.0, 350.0);
      expect(controller.effectiveOffset(cardSize, mobileScreen), equals(const Offset(50.0, 350.0)));

      // When a new video is loaded into the miniplayer
      await controller.showWithVideo(testVideo);

      // Verify dragOffset is reset to null
      expect(controller.dragOffset.value, isNull);

      // Verify effectiveOffset returns the correct default bottom-right dock offset
      final defaultDock = controller.effectiveOffset(cardSize, mobileScreen);
      expect(
        defaultDock.dx,
        equals(mobileScreen.width - cardSize.width - MiniplayerConfig.mobileDockInset),
      );
      expect(
        defaultDock.dy,
        equals(mobileScreen.height - cardSize.height - MiniplayerConfig.mobileDockBottomInset),
      );
    });

    test('defaultDockOffset clamps cleanly within screen bounds on ultra-compact screens', () {
      const tinyScreen = Size(180.0, 200.0);
      const cardSize = Size(160.0, 90.0);

      final dock = controller.defaultDockOffset(cardSize, tinyScreen);
      expect(dock.dx >= 0.0, isTrue);
      expect(dock.dy >= 0.0, isTrue);
    });
  });
}
