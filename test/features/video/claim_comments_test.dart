import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/claim_comment.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_comments_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('ClaimComment Model Tests', () {
    test('1. ClaimComment serialization and stance detection', () {
      final now = Timestamp.now();
      final comment = ClaimComment(
        id: 'comment_1',
        videoId: 'vid_123',
        claimIndex: 2,
        claimText: 'Earth orbits the Sun',
        userId: 'user_456',
        userName: 'Dr. Jane Doe',
        userProfilePicUrl: 'https://example.com/avatar.jpg',
        channelId: 'chan_789',
        text: 'Multiple astronomical observations confirm this heliocentric model.',
        stance: 'supports',
        sourceUrls: const ['https://nasa.gov/solar-system'],
        helpfulCount: 5,
        unhelpfulCount: 1,
        helpfulUserIds: const ['user_abc', 'user_def'],
        unhelpfulUserIds: const ['user_xyz'],
        createdAt: now,
      );

      expect(comment.isSupports, isTrue);
      expect(comment.isDisputes, isFalse);
      expect(comment.isContext, isFalse);
      expect(comment.isHelpfulBy('user_abc'), isTrue);
      expect(comment.isHelpfulBy('random_user'), isFalse);
      expect(comment.isUnhelpfulBy('user_xyz'), isTrue);

      final map = comment.toMap();
      expect(map['id'], 'comment_1');
      expect(map['videoId'], 'vid_123');
      expect(map['claimIndex'], 2);
      expect(map['stance'], 'supports');
      expect(map['sourceUrls'], contains('https://nasa.gov/solar-system'));
    });

    test('2. ClaimCommentStance parser handles diverse inputs', () {
      expect(ClaimCommentStance.fromString('supports'), ClaimCommentStance.supports);
      expect(ClaimCommentStance.fromString('agree'), ClaimCommentStance.supports);
      expect(ClaimCommentStance.fromString('disputes'), ClaimCommentStance.disputes);
      expect(ClaimCommentStance.fromString('contest'), ClaimCommentStance.disputes);
      expect(ClaimCommentStance.fromString('context'), ClaimCommentStance.context);
      expect(ClaimCommentStance.fromString('anything_else'), ClaimCommentStance.context);
    });
  });

  group('ClaimCommentsController Tests', () {
    late ClaimCommentsController controller;

    setUp(() {
      Get.reset();
      Get.put(AuthService());
      controller = Get.put(ClaimCommentsController());
    });

    tearDown(() {
      Get.reset();
    });

    test('3. Stance filtering & counts calculate correctly', () {
      final now = Timestamp.now();
      final list = [
        ClaimComment(
          id: 'c1',
          videoId: 'v1',
          claimIndex: 0,
          claimText: 'Claim 1',
          userId: 'u1',
          userName: 'User 1',
          userProfilePicUrl: '',
          channelId: 'u1',
          text: 'Agreed',
          stance: 'supports',
          createdAt: now,
        ),
        ClaimComment(
          id: 'c2',
          videoId: 'v1',
          claimIndex: 0,
          claimText: 'Claim 1',
          userId: 'u2',
          userName: 'User 2',
          userProfilePicUrl: '',
          channelId: 'u2',
          text: 'I dispute this finding',
          stance: 'disputes',
          createdAt: now,
        ),
        ClaimComment(
          id: 'c3',
          videoId: 'v1',
          claimIndex: 0,
          claimText: 'Claim 1',
          userId: 'u3',
          userName: 'User 3',
          userProfilePicUrl: '',
          channelId: 'u3',
          text: 'Here is some historical context',
          stance: 'context',
          createdAt: now,
        ),
      ];

      controller.comments.assignAll(list);

      expect(controller.comments.length, 3);
      expect(controller.supportsCount, 1);
      expect(controller.disputesCount, 1);
      expect(controller.contextCount, 1);

      // Default 'all'
      expect(controller.filteredComments.length, 3);

      // Filter by 'supports'
      controller.setStanceFilter('supports');
      expect(controller.filteredComments.length, 1);
      expect(controller.filteredComments.first.id, 'c1');

      // Filter by 'disputes'
      controller.setStanceFilter('disputes');
      expect(controller.filteredComments.length, 1);
      expect(controller.filteredComments.first.id, 'c2');

      // Filter by 'context'
      controller.setStanceFilter('context');
      expect(controller.filteredComments.length, 1);
      expect(controller.filteredComments.first.id, 'c3');
    });

    test('4. Source URL addition and removal', () {
      controller.addAttachedSource('https://nature.com/articles/s41586-020');
      expect(controller.attachedSources.length, 1);
      expect(controller.attachedSources.first, contains('nature.com'));

      // Remove source
      controller.removeAttachedSource(0);
      expect(controller.attachedSources.isEmpty, isTrue);
    });
  });
}
