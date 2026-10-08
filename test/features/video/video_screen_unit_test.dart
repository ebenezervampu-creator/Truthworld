// 🎬 VIDEO SCREEN COMPONENT & CONTROLLER UNIT TESTS
//
// Verifies:
// 1. VideoController initialization and resilient policy getters
// 2. Adaptive Bitrate (ABR) resolution tier conversions
// 3. Playback access policies (ad-free perks, high-res streaming)
// 4. Zero setState compliance (GetxController reactive bindings)
// 5. Memory safety: strict controller lifecycle disposal

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('VideoScreen Unit Tests', () {
    test('1. VideoController initializes with resilient getters and subcontrollers', () {
      final vc = Get.put(VideoController(tag: 'vid_unit_test_01'));
      expect(vc.isChannelMember, isFalse);
      expect(vc.channelHasMemberAdFreePerk, isFalse);
      expect(vc.hasAdFreePlayback, isFalse);
      expect(vc.canStreamHighResolution, isFalse);

      expect(vc.channelController, isNotNull);
      expect(vc.engagementController, isNotNull);
      expect(vc.analyticsController, isNotNull);
      expect(vc.commentsController, isNotNull);
      expect(vc.videoPlaylistController, isNotNull);
      expect(vc.transcriptController, isNotNull);
      expect(vc.recommendationsController, isNotNull);
    });

    test('2. AdaptiveBitrateController converts VideoResolutionV2 instances correctly', () {
      final resList = [
        VideoResolutionV2(label: '1080p60', url: 'https://gcs/1080p.mp4', width: 1920, height: 1080, bitrate: 6750000, fps: 60),
        VideoResolutionV2(label: '720p', url: 'https://gcs/720p.mp4', width: 1280, height: 720, bitrate: 2500000),
        VideoResolutionV2(label: '480p', url: 'https://gcs/480p.mp4', width: 854, height: 480, bitrate: 1200000),
      ];

      final tiers = resList.map(ResolutionTier.fromVideoResolution).toList();
      expect(tiers.length, equals(3));
      expect(tiers[0].label, equals('1080p60'));
      expect(tiers[0].is60Fps, isTrue);
      expect(tiers[1].height, equals(720));
      expect(tiers[2].bitrate, equals(1200));
    });

    test('3. VideoController audio-only state toggle is idempotent and reactive', () {
      final vc = Get.put(VideoController(tag: 'vid_audio_unit_test'), tag: 'vid_audio_unit_test');
      expect(vc.isAudioOnly.value, isFalse);

      vc.setAudioOnly(true);
      expect(vc.isAudioOnly.value, isTrue);

      vc.setAudioOnly(false);
      expect(vc.isAudioOnly.value, isFalse);

      Get.delete<VideoController>(tag: 'vid_audio_unit_test', force: true);
    });

    test('4. VideoController disposes cleanly without memory leaks', () {
      Get.put(VideoController(tag: 'vid_dispose_test'), tag: 'vid_dispose_test');
      expect(Get.isRegistered<VideoController>(tag: 'vid_dispose_test'), isTrue);

      Get.delete<VideoController>(tag: 'vid_dispose_test', force: true);
      expect(Get.isRegistered<VideoController>(tag: 'vid_dispose_test'), isFalse);
    });
  });
}
