import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('CommentsController Modular Architecture Tests', () {
    late CommentsController controller;
    late Video testVideo;

    setUp(() {
      Get.reset();
      Get.put(AuthService());

      testVideo = Video(
        id: 'vid_test_1',
        ownerId: 'owner_1',
        title: 'Test Video',
        description: 'Test description',
        thumbnailUrl: 'https://test.com/thumb.jpg',
        channelId: 'chan_1',
        channelName: 'Test Channel',
        category: 'Tech',
        tags: const ['test'],
        createdAt: DateTime.now(),
      );

      controller = Get.put(
        CommentsController(
          video: testVideo,
          isOffline: true,
        ),
      );
    });

    tearDown(Get.reset);

    test('1. Architecture & Mixin Composition Verification', () {
      expect(controller, isA<CommentsStateBase>());
      expect(controller, isA<CommentsQueryAndSortMixin>());
      expect(controller, isA<CommentsCrudMixin>());
      expect(controller, isA<CommentInteractionsMixin>());
      expect(controller, isA<ReplyOperationsMixin>());
    });

    test('2. Initial State Verification in Offline Mode', () {
      expect(controller.comments, isEmpty);
      expect(controller.isLoadingComments.value, isFalse);
      expect(controller.hasMoreComments.value, isTrue);
      expect(controller.commentsError.value, isNull);
      expect(controller.isSortNewest.value, isFalse);
      expect(controller.isCounterArgumentFlipped.value, isFalse);
      expect(controller.isSubmittingComment.value, isFalse);
      expect(controller.userCommentInteractions, isEmpty);
      expect(controller.isOffline, isTrue);
    });

    test('3. sortComments sorts by newest or like count correctly', () {
      final now = DateTime.now();
      final c1 = Comment(
        id: 'c1',
        videoId: 'vid_test_1',
        userId: 'u1',
        userName: 'User 1',
        userProfilePicUrl: '',
        channelId: 'chan_1',
        reportCount: 0,
        text: 'First comment',
        likeCount: 5,
        dislikeCount: 0,
        createdAt: Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
      );
      final c2 = Comment(
        id: 'c2',
        videoId: 'vid_test_1',
        userId: 'u2',
        userName: 'User 2',
        userProfilePicUrl: '',
        channelId: 'chan_1',
        reportCount: 0,
        text: 'Second comment with more likes',
        likeCount: 50,
        dislikeCount: 0,
        createdAt: Timestamp.fromDate(now.subtract(const Duration(minutes: 2))),
      );

      controller.comments.assignAll([c1, c2]);

      // Sort by popular (highest likeCount first)
      controller.sortComments(false);
      expect(controller.comments.first.id, equals('c2'));
      expect(controller.comments.last.id, equals('c1'));

      // Sort by newest
      controller.sortComments(true);
      expect(controller.comments.first.id, equals('c2'));
      expect(controller.isSortNewest.value, isTrue);
    });

    test('4. toggleCounterArgumentSort prioritizes contrast keywords', () {
      final now = Timestamp.now();
      final standardComment = Comment(
        id: 'c_normal',
        videoId: 'vid_test_1',
        userId: 'u1',
        userName: 'User 1',
        userProfilePicUrl: '',
        channelId: 'chan_1',
        reportCount: 0,
        text: 'Great video very nice',
        likeCount: 100,
        dislikeCount: 0,
        createdAt: now,
      );

      final counterComment = Comment(
        id: 'c_counter',
        videoId: 'vid_test_1',
        userId: 'u2',
        userName: 'User 2',
        userProfilePicUrl: '',
        channelId: 'chan_1',
        reportCount: 0,
        text: 'However I disagree because the evidence shows otherwise',
        likeCount: 10,
        dislikeCount: 0,
        createdAt: now,
      );

      controller.comments.assignAll([standardComment, counterComment]);

      // Initially standard comment has more likes and would be first
      controller.sortComments(false);
      expect(controller.comments.first.id, equals('c_normal'));

      // Toggle counter argument sort
      controller.toggleCounterArgumentSort();
      expect(controller.isCounterArgumentFlipped.value, isTrue);
      expect(controller.comments.first.id, equals('c_counter'));

      // Toggle off restores standard sort
      controller.toggleCounterArgumentSort();
      expect(controller.isCounterArgumentFlipped.value, isFalse);
      expect(controller.comments.first.id, equals('c_normal'));
    });

    test('5. getLikedByText formats user like count strings', () {
      final c0 = Comment(
        id: 'c0',
        videoId: 'v1',
        userId: 'u1',
        userName: 'User',
        userProfilePicUrl: '',
        channelId: 'chan_1',
        reportCount: 0,
        text: 'Text',
        likeCount: 0,
        dislikeCount: 0,
        createdAt: Timestamp.now(),
      );
      expect(controller.getLikedByText(c0), equals(''));

      final c1 = c0.copyWith(likeCount: 1);
      expect(controller.getLikedByText(c1), equals('Liked by 1 user'));

      final c15 = c0.copyWith(likeCount: 15);
      expect(controller.getLikedByText(c15), equals('Liked by 15 users'));
    });

    test('6. User interaction status helpers return accurate flags', () {
      controller.currentUserIdOverride = 'u1';

      final comment = Comment(
        id: 'c_test_interaction',
        videoId: 'v1',
        userId: 'u1',
        userName: 'User',
        userProfilePicUrl: '',
        channelId: 'chan_1',
        reportCount: 0,
        text: 'Text',
        likeCount: 1,
        dislikeCount: 0,
        createdAt: Timestamp.now(),
      );

      expect(controller.isCommentLikedByUser(comment), isFalse);
      expect(controller.isCommentDislikedByUser(comment), isFalse);

      controller.userCommentInteractions[comment.id] = {
        'isLiked': true,
        'isDisliked': false,
      };

      expect(controller.isCommentLikedByUser(comment), isTrue);
      expect(controller.isCommentDislikedByUser(comment), isFalse);

      expect(controller.isReplyLikedByUser('reply_99'), isFalse);
      controller.userCommentInteractions['reply_99'] = {
        'isLiked': false,
        'isDisliked': true,
      };
      expect(controller.isReplyDislikedByUser('reply_99'), isTrue);
    });
  });
}
