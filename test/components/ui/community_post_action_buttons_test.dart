import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Community Post Action Buttons & Interaction Audit Tests', () {
    late CommunityPostModel postWithPoll;
    late CommunityPostModel postDisabledComments;

    setUp(() {
      Get.reset();

      final now = DateTime.now();
      postWithPoll = CommunityPostModel(
        id: 'post_audit_poll',
        title: 'Community Poll Test',
        description: 'Which feature do you want next?',
        ownerId: 'owner_user_1',
        channelId: 'channel_123',
        channelName: 'TruthWorld Dev Channel',
        channelImage: 'https://example.com/channel.jpg',
        uploadedAt: now.subtract(const Duration(hours: 1)),
        likes: 10,
        dislikes: 2,
        commentCount: 5,
        poll: const PollModel(
          question: 'Which feature do you want next?',
          type: PollType.multiChoice,
          options: [
            PollOption(id: 'opt_1', text: 'Live Dubbing Studio', voteCount: 8, voterIds: ['voter_a']),
            PollOption(id: 'opt_2', text: 'Epistemic Fact Badges', voteCount: 12, voterIds: ['voter_b']),
            PollOption(id: 'opt_3', text: 'Decentralized Transcripts', voteCount: 4, voterIds: ['voter_c']),
          ],
        ),
      );

      postDisabledComments = CommunityPostModel(
        id: 'post_audit_no_comments',
        title: 'Announcement Post',
        description: 'Important platform announcement.',
        ownerId: 'owner_user_1',
        channelId: 'channel_123',
        channelName: 'TruthWorld Dev Channel',
        channelImage: 'https://example.com/channel.jpg',
        uploadedAt: now.subtract(const Duration(hours: 1)),
        isCommentsEnabled: false,
      );
    });

    tearDown(Get.reset);

    test('PollModel parses Timestamp expiresAt and options without crash', () {
      final nowTimestamp = Timestamp.fromDate(DateTime.now().add(const Duration(days: 3)));
      final map = {
        'question': 'Do you support epistemic fact-checking?',
        'type': 'yesNo',
        'expiresAt': nowTimestamp,
        'options': [
          {'id': 'yes', 'text': 'Yes', 'votes': 45, 'voterIds': ['user1', 'user2']},
          {'id': 'no', 'text': 'No', 'votes': 5, 'voterIds': ['user3']},
        ],
      };

      final poll = PollModel.fromMap(map);
      expect(poll.question, equals('Do you support epistemic fact-checking?'));
      expect(poll.type, equals(PollType.yesNo));
      expect(poll.options.length, equals(2));
      expect(poll.options[0].voteCount, equals(45));
      expect(poll.options[1].voteCount, equals(5));
      expect(poll.totalVotes, equals(50));
      expect(poll.isExpired, isFalse);
      expect(poll.hasVoted('user1'), isTrue);
      expect(poll.hasVoted('user99'), isFalse);
      expect(poll.selectedOptionId('user1'), equals('yes'));
    });

    testWidgets('CommunityPostCard renders interactive poll options and buttons', (tester) async {
      Get.put(
        CommunityPostController(post: postWithPoll),
        tag: postWithPoll.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(post: postWithPoll),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommunityPostPollWidget), findsOneWidget);
      expect(find.text('Live Dubbing Studio'), findsOneWidget);
      expect(find.text('Epistemic Fact Badges'), findsOneWidget);
      expect(find.text('Decentralized Transcripts'), findsOneWidget);
      expect(find.textContaining('24 votes'), findsOneWidget);
    });

    testWidgets('Reaction settings toggle reactively updates action bar like & dislike counts', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: postWithPoll),
        tag: postWithPoll.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostActionBar(
              post: postWithPoll,
              controller: controller,
              onOpenComments: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Hide like and dislike counts
      controller.showLikeCount.value = false;
      controller.showDislikeCount.value = false;
      await tester.pumpAndSettle();

      expect(find.text('10'), findsNothing);
      expect(find.text('2'), findsNothing);

      // Show counts again
      controller.showLikeCount.value = true;
      controller.showDislikeCount.value = true;
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Disabled comments post hides comment action button', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: postDisabledComments),
        tag: postDisabledComments.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostActionBar(
              post: postDisabledComments,
              controller: controller,
              onOpenComments: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.comment_outlined), findsNothing);
    });

    testWidgets('Owner moving post to trash hides the card immediately', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: postWithPoll),
        tag: postWithPoll.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(post: postWithPoll),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommunityPostCard), findsOneWidget);
      expect(find.text('Which feature do you want next?'), findsWidgets);

      // Trigger deletion / move to trash
      controller.isDeleted.value = true;
      await tester.pumpAndSettle();

      // Card must be shrunk (invisible)
      expect(find.text('Which feature do you want next?'), findsNothing);
    });
  });
}
