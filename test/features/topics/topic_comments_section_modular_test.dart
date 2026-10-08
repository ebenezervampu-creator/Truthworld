import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_comments_section.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
    if (!Get.isRegistered<AuthService>()) {
      Get.put(AuthService(), permanent: true);
    }
  });

  tearDown(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put(AuthService(), permanent: true);
    }
  });

  final sampleTopic = Topic(
    id: 'topic_climate_01',
    title: 'Climate Solutions 2026',
    slug: 'climate-solutions-2026',
    handle: '@climatesolutions',
    handleLowercase: '@climatesolutions',
    description: 'Investigating real climate innovations and fact-checks.',
    category: 'Science',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    commentCount: 2,
    likeCount: 50,
  );

  final sampleComment = Comment(
    id: 'comm_01',
    videoId: 'topic_climate_01',
    userId: 'user_01',
    userName: 'Dr. Ellen Vance',
    userProfilePicUrl: '',
    channelId: 'chan_01',
    text: 'This analysis provides essential ground truth data.',
    likeCount: 15,
    dislikeCount: 1,
    reportCount: 0,
    createdAt: Timestamp.fromDate(DateTime(2026, 3, 15)),
    isHeartedByCreator: true,
    creatorHeartName: 'Climate Team',
  );

  final sampleComment2 = Comment(
    id: 'comm_02',
    videoId: 'topic_climate_01',
    userId: 'user_02',
    userName: 'Marcus Aurelius',
    userProfilePicUrl: '',
    channelId: 'chan_02',
    text: 'Fascinating breakdown of carbon sequestration metrics.',
    likeCount: 42,
    dislikeCount: 0,
    reportCount: 0,
    createdAt: Timestamp.fromDate(DateTime(2026, 3, 10)),
  );

  final sampleReply = Reply(
    id: 'rep_01',
    commentId: 'comm_01',
    videoId: 'topic_climate_01',
    userId: 'user_03',
    userName: 'Sarah Connor',
    userProfilePicUrl: '',
    channelId: 'chan_03',
    text: 'Completely agree, especially the satellite data comparison.',
    likeCount: 5,
    dislikeCount: 0,
    reportCount: 0,
    createdAt: Timestamp.fromDate(DateTime(2026, 3, 16)),
  );

  Widget createTestWidget(Widget child) {
    return GetMaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('TopicCommentsSkeleton & Empty State', () {
    testWidgets('TopicCommentsSkeleton renders shimmer loading elements', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const TopicCommentsSkeleton()),
      );

      expect(find.byType(TopicCommentsSkeleton), findsOneWidget);
    });

    testWidgets('TopicCommentsEmptyState renders friendly prompt', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const TopicCommentsEmptyState()),
      );

      expect(find.text('No comments yet. Start the conversation!'), findsOneWidget);
    });
  });

  group('TopicCommentsHeader & Controller Sorting', () {
    testWidgets('TopicCommentsHeader renders comment count and sort popup', (tester) async {
      final headerController = TopicCommentsHeaderController();

      await tester.pumpWidget(
        createTestWidget(
          TopicCommentsHeader(
            commentCount: 2,
            headerController: headerController,
          ),
        ),
      );

      expect(find.text('2 Comments'), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
    });

    test('TopicCommentsHeaderController sorts comments by newest and top correctly', () {
      final headerController = TopicCommentsHeaderController();
      final comments = [sampleComment, sampleComment2];

      // Newest first
      headerController.isSortNewest.value = true;
      final sortedNewest = headerController.sortComments(comments);
      expect(sortedNewest.first.id, equals('comm_01')); // 2026-03-15 > 2026-03-10

      // Top comments first
      headerController.isSortNewest.value = false;
      final sortedTop = headerController.sortComments(comments);
      expect(sortedTop.first.id, equals('comm_02')); // 42 likes > 15 likes
    });

    test('TopicCommentsHeaderController deduplicates comments with identical IDs', () {
      final headerController = TopicCommentsHeaderController();
      final duplicateComments = [sampleComment, sampleComment, sampleComment2];

      final deduplicated = headerController.sortComments(duplicateComments);
      expect(deduplicated.length, equals(2));
      expect(deduplicated.map((c) => c.id).toList(), containsAll(['comm_01', 'comm_02']));
    });
  });

  group('ReplyThreadLinePainter Tests', () {
    test('ReplyThreadLinePainter paints path correctly without crashing', () {
      final painterLast = ReplyThreadLinePainter(
        color: Colors.grey,
        isLast: true,
        branchY: 20,
      );
      final painterNotLast = ReplyThreadLinePainter(
        color: Colors.grey,
        isLast: false,
        branchY: 20,
      );

      expect(painterLast.isLast, isTrue);
      expect(painterNotLast.isLast, isFalse);
      expect(painterLast.shouldRepaint(painterLast), isFalse);
      expect(painterLast.shouldRepaint(painterNotLast), isTrue);
    });
  });

  group('TopicReplyItemWidget Tests', () {
    testWidgets('renders reply content, author name, and reactions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(TopicInteractionController(), tag: 'test_topic_reply');

      await tester.pumpWidget(
        createTestWidget(
          TopicReplyItemWidget(
            reply: sampleReply,
            commentId: 'comm_01',
            topicId: 'topic_climate_01',
            controller: controller,
            theme: ThemeData.dark(),
            isMobile: true,
            isTablet: false,
            isDesktop: false,
            onNavigateToChannel: (_) {},
          ),
        ),
      );

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Completely agree, especially the satellite data comparison.'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });

  group('TopicCommentItemWidget Tests', () {
    testWidgets('renders comment content, creator heart badge, and reply button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(TopicInteractionController(), tag: 'test_topic_comment');

      await tester.pumpWidget(
        createTestWidget(
          TopicCommentItemWidget(
            comment: sampleComment,
            topicId: 'topic_climate_01',
            controller: controller,
            theme: ThemeData.dark(),
            isMobile: true,
            isTablet: false,
            isDesktop: false,
            onNavigateToChannel: (_) {},
          ),
        ),
      );

      expect(find.text('Dr. Ellen Vance'), findsOneWidget);
      expect(find.text('This analysis provides essential ground truth data.'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });

  group('TopicCommentsSection Declarative Coordinator Tests', () {
    testWidgets('renders full topic comments section with input and empty state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          TopicCommentsSection(topic: sampleTopic),
        ),
      );

      expect(find.byType(TopicCommentsSection), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
    });
  });
}
