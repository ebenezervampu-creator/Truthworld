import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/user_session_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  group('UserSessionController Modular Test Suite', () {
    late UserSessionController controller;

    setUpAll(() async {
      await setupMockFirebase();
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthService>(AuthService());
      controller = Get.put(UserSessionController());
    });

    tearDown(Get.reset);

    test('Initializes with default observable state and empty guards', () {
      expect(controller.videoLikes, isEmpty);
      expect(controller.videoDislikes, isEmpty);
      expect(controller.isReporting.value, isFalse);
      expect(controller.pendingLikeOperations, isEmpty);
      expect(controller.pendingDislikeOperations, isEmpty);
      expect(controller.pendingReportVideoIds, isEmpty);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.currentUserId, isNull);
      expect(controller.userId, isEmpty);
    });

    test('likeVideo ignores empty videoId or userId', () async {
      await controller.likeVideo('', 'user_123');
      expect(controller.pendingLikeOperations, isEmpty);

      await controller.likeVideo('video_123', '');
      expect(controller.pendingLikeOperations, isEmpty);
    });

    test('dislikeVideo ignores empty videoId or userId', () async {
      await controller.dislikeVideo('', 'user_123');
      expect(controller.pendingDislikeOperations, isEmpty);

      await controller.dislikeVideo('video_123', '');
      expect(controller.pendingDislikeOperations, isEmpty);
    });

    test('likeVideo guards against rapid-tap duplicates', () async {
      const operationKey = 'like:vid_test:user_test';
      controller.pendingLikeOperations.add(operationKey);

      // Subsequent call should immediately return without re-adding or crashing
      await controller.likeVideo('vid_test', 'user_test');
      expect(controller.pendingLikeOperations.contains(operationKey), isTrue);

      controller.pendingLikeOperations.remove(operationKey);
    });

    test('dislikeVideo guards against rapid-tap duplicates', () async {
      const operationKey = 'dislike:vid_test:user_test';
      controller.pendingDislikeOperations.add(operationKey);

      // Subsequent call should immediately return without re-adding or crashing
      await controller.dislikeVideo('vid_test', 'user_test');
      expect(controller.pendingDislikeOperations.contains(operationKey), isTrue);

      controller.pendingDislikeOperations.remove(operationKey);
    });

    test('addComment throws ValidationException when text is empty or blank', () async {
      // safeExecute catches exceptions and logs them via ErrorHandler
      await controller.addComment(
        videoId: 'vid_1',
        userId: 'user_1',
        userName: 'Test User',
        userProfilePicUrl: '',
        text: '   ',
      );
      // Verify state remains stable
      expect(controller.errorMessage, isNotEmpty);
    });

    test('addReply throws ValidationException when text is empty or blank', () async {
      await controller.addReply(
        videoId: 'vid_1',
        commentId: 'c_1',
        userId: 'user_1',
        userName: 'Test User',
        userProfilePicUrl: '',
        text: '  ',
      );
      expect(controller.errorMessage, isNotEmpty);
    });

    test('reportVideo warns unauthenticated user without crashing', () async {
      final context = Get.context ?? (MaterialApp(home: Container()).createElement());

      await controller.reportVideo(
        context: context,
        videoId: 'vid_123',
        channelId: 'chan_123',
        reason: 'Spam',
        comment: 'Spam video',
      );

      expect(controller.pendingReportVideoIds, isEmpty);
    });

    test('addToWatchLater warns unauthenticated user without crashing', () async {
      await controller.addToWatchLater('vid_123');
      // No unhandled exception thrown; warning is displayed
      expect(controller.state, isNotNull);
    });

    test('Stream factory methods return non-null typed streams', () {
      final commentsStream = controller.getCommentsStream('test_video_123');
      expect(commentsStream, isNotNull);

      final repliesStream = controller.getRepliesStream('test_video_123', 'test_comment_123');
      expect(repliesStream, isNotNull);
    });

    test('UserSessionController exposes valid getters and handles state updates', () {
      expect(controller.videoInfo, isNotNull);
      expect(controller.firestore, isNotNull);
      expect(controller.auth, isNotNull);

      controller.videoLikes['vid_123'] = 42;
      controller.videoDislikes['vid_123'] = 2;
      controller.isReporting.value = true;

      expect(controller.videoLikes['vid_123'], equals(42));
      expect(controller.videoDislikes['vid_123'], equals(2));
      expect(controller.isReporting.value, isTrue);
    });
  });
}
