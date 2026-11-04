import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';

import '../../test_helpers/mock_firebase.dart';

class TestMainController extends MainController {
  final RxMap<String, int> _mockLikes = <String, int>{}.obs;
  final RxMap<String, int> _mockDislikes = <String, int>{}.obs;

  @override
  RxMap<String, int> get videoLikes => _mockLikes;

  @override
  RxMap<String, int> get videoDislikes => _mockDislikes;

  @override
  // ignore: must_call_super
  void onInit() {
    // Avoid triggering live Firestore/RTDB listeners in isolated unit test
  }


  @override
  Future<void> likeVideo(String videoId, String userId) async {
    // Simulated remote persistence
  }

  @override
  Future<void> dislikeVideo(String videoId, String userId) async {
    // Simulated remote persistence
  }
}

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
    Get.put<MainController>(TestMainController(), permanent: true);
  });

  tearDown(Get.reset);

  group('Video Engagement Like/Dislike Mutual Exclusion Tests', () {
    test('1. Liking a video sets isLiked to true and isDisliked to false', () async {
      final engagement = VideoEngagementController();
      AuthService.to.setAuthenticatedForTesting(isAuthenticated: true, uid: 'user_123');

      expect(engagement.isLiked.value, isFalse);
      expect(engagement.isDisliked.value, isFalse);

      await engagement.toggleLike('vid_test_1', 10, 2);

      expect(engagement.isLiked.value, isTrue);
      expect(engagement.isDisliked.value, isFalse);
    });

    test('2. Liking a previously disliked video clears dislike and sets like', () async {
      final engagement = VideoEngagementController();
      AuthService.to.setAuthenticatedForTesting(isAuthenticated: true, uid: 'user_123');

      // Set initially disliked
      engagement.isDisliked.value = true;
      engagement.isLiked.value = false;

      // User likes the video
      await engagement.toggleLike('vid_test_2', 5, 3);

      expect(engagement.isLiked.value, isTrue, reason: 'Video must be liked');
      expect(engagement.isDisliked.value, isFalse, reason: 'Video must no longer be disliked');
    });

    test('3. Unliking a video sets isLiked to false and never leaves it disliked', () async {
      final engagement = VideoEngagementController();
      AuthService.to.setAuthenticatedForTesting(isAuthenticated: true, uid: 'user_123');

      // Video was liked
      engagement.isLiked.value = true;
      engagement.isDisliked.value = false;

      // User toggles like off (unlike)
      await engagement.toggleLike('vid_test_3', 10, 0);

      expect(engagement.isLiked.value, isFalse, reason: 'Like should be toggled off');
      expect(engagement.isDisliked.value, isFalse, reason: 'Unliking must never transition to dislike');
    });

    test('4. Disliking a previously liked video clears like and sets dislike', () async {
      final engagement = VideoEngagementController();
      AuthService.to.setAuthenticatedForTesting(isAuthenticated: true, uid: 'user_123');

      // Set initially liked
      engagement.isLiked.value = true;
      engagement.isDisliked.value = false;

      // User dislikes the video
      await engagement.toggleDislike('vid_test_4', 10, 1);

      expect(engagement.isDisliked.value, isTrue, reason: 'Video must be disliked');
      expect(engagement.isLiked.value, isFalse, reason: 'Video must no longer be liked');
    });

    test('5. Undisliking a video sets isDisliked to false and never sets like', () async {
      final engagement = VideoEngagementController();
      AuthService.to.setAuthenticatedForTesting(isAuthenticated: true, uid: 'user_123');

      // Video was disliked
      engagement.isDisliked.value = true;
      engagement.isLiked.value = false;

      // User toggles dislike off (undislike)
      await engagement.toggleDislike('vid_test_5', 10, 1);

      expect(engagement.isDisliked.value, isFalse, reason: 'Dislike should be toggled off');
      expect(engagement.isLiked.value, isFalse, reason: 'Undisliking must not transition to like');
    });

    test('6. VideoController and VideoHydration share canonical engagement tag', () {
      final video = Video.fromMap({
        'title': 'Tag Test Video',
        'channelId': 'chan_tag_1',
        'videoUrl': 'https://example.com/v.mp4',
      }, 'vid_tag_canonical_1');

      final controller = VideoController(tag: 'vid_tag_canonical_1');
      controller.video = video;

      final engagement1 = controller.engagementController;
      expect(Get.isRegistered<VideoEngagementController>(tag: 'video_vid_tag_canonical_1'), isTrue);

      final engagement2 = controller.engagementController;
      expect(identical(engagement1, engagement2), isTrue);

      // Verify onClose properly deletes the engagement controller
      controller.onClose();
      expect(Get.isRegistered<VideoEngagementController>(tag: 'video_vid_tag_canonical_1'), isFalse);
    });
  });
}
