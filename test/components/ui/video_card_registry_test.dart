import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller_registry.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    VideoCardControllerRegistry.clear();
  });

  tearDown(() {
    VideoCardControllerRegistry.clear();
    Get.reset();
  });

  Video createSampleVideo(String id) {
    return Video.fromMap({
      'title': 'Test Video $id',
      'channelId': '',
      'channelName': 'TruthWorld Test',
      'channelAvatarUrl': 'https://example.com/avatar.jpg',
      'videoUrl': 'https://example.com/video_$id.mp4',
      'thumbnailUrl': 'https://example.com/thumb_$id.jpg',
      'uploadedAt': Timestamp.now(),
    }, id);
  }

  group('VideoCardControllerRegistry LRU Eviction Tests', () {
    test('records access and limits active controllers to maxActiveControllers (40)', () {
      // Register 50 controllers
      for (var i = 1; i <= 50; i++) {
        final videoId = 'vid_$i';
        final tag = 'video_card_${videoId}_test';
        final video = createSampleVideo(videoId);

        Get.put(
          VideoCardController(video: video, heroPrefix: 'test'),
          tag: tag,
        );
        VideoCardControllerRegistry.recordAccess(tag);
      }

      // Should be capped at maxActiveControllers (40)
      expect(
        VideoCardControllerRegistry.activeCount,
        lessThanOrEqualTo(VideoCardControllerRegistry.maxActiveControllers),
      );

      // The earliest controllers (e.g. vid_1, vid_2) should have been evicted from GetX
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_1_test'), isFalse);
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_2_test'), isFalse);
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_10_test'), isFalse);

      // The most recent controllers should still be active
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_50_test'), isTrue);
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_49_test'), isTrue);
    });

    test('accessing an older card refreshes its LRU recency preventing eviction', () {
      for (var i = 1; i <= 40; i++) {
        final videoId = 'vid_$i';
        final tag = 'video_card_${videoId}_test';
        final video = createSampleVideo(videoId);

        Get.put(
          VideoCardController(video: video, heroPrefix: 'test'),
          tag: tag,
        );
        VideoCardControllerRegistry.recordAccess(tag);
      }

      // Re-access vid_1 to bring it to MRU
      VideoCardControllerRegistry.recordAccess('video_card_vid_1_test');

      // Now add 1 more controller (vid_41) -> vid_2 should be evicted, but vid_1 should survive!
      final video41 = createSampleVideo('vid_41');
      Get.put(
        VideoCardController(video: video41, heroPrefix: 'test'),
        tag: 'video_card_vid_41_test',
      );
      VideoCardControllerRegistry.recordAccess('video_card_vid_41_test');

      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_1_test'), isTrue);
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_2_test'), isFalse);
      expect(Get.isRegistered<VideoCardController>(tag: 'video_card_vid_41_test'), isTrue);
    });

    test('explicit unregister removes tag from registry', () {
      final video = createSampleVideo('vid_explicit');
      const tag = 'video_card_vid_explicit_test';

      Get.put(
        VideoCardController(video: video, heroPrefix: 'test'),
        tag: tag,
      );
      VideoCardControllerRegistry.recordAccess(tag);
      expect(VideoCardControllerRegistry.activeCount, equals(1));

      VideoCardControllerRegistry.unregisterTag(tag);
      expect(VideoCardControllerRegistry.activeCount, equals(0));
    });
  });
}
