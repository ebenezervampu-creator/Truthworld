import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comments_widgets.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Dashboard Comments Modular Tests', () {
    late DashboardCommentsController controller;

    setUp(() {
      Get.reset();
      controller = Get.put(DashboardCommentsController());
    });

    tearDown(Get.reset);

    testWidgets('DashboardCommentsHeaderBar renders title, subtitle, and switches tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCommentsHeaderBar(
              controller: controller,
              isMobile: false,
            ),
          ),
        ),
      );

      expect(find.text('Channel comments'), findsOneWidget);
      expect(find.text('Manage and reply to viewer comments across all your videos'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Held for review'), findsOneWidget);

      expect(controller.selectedTab.value, equals(0));

      await tester.tap(find.text('Held for review'));
      await tester.pumpAndSettle();

      expect(controller.selectedTab.value, equals(1));

      await tester.tap(find.text('Published'));
      await tester.pumpAndSettle();

      expect(controller.selectedTab.value, equals(0));
    });

    testWidgets('DashboardCommentsFilterToolbar renders filter chips and triggers filter changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCommentsFilterToolbar(
              controller: controller,
              isMobile: false,
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text("I haven't responded"), findsOneWidget);
      expect(find.text('Responded'), findsOneWidget);
      expect(find.text('With Creator Heart'), findsOneWidget);

      await tester.tap(find.text("I haven't responded"));
      await tester.pumpAndSettle();

      expect(controller.commentsFilter.value, equals('unanswered'));

      await tester.tap(find.text('Responded'));
      await tester.pumpAndSettle();

      expect(controller.commentsFilter.value, equals('answered'));

      await tester.enterText(find.byType(TextField), 'testing query');
      await tester.pumpAndSettle();

      expect(controller.searchQuery.value, equals('testing query'));
    });

    testWidgets('DashboardCommentsEmptyState renders context-aware empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCommentsEmptyState(isHeldTab: false),
          ),
        ),
      );

      expect(find.text('No comments found'), findsOneWidget);
      expect(find.text('Try adjusting your search query or filter chips.'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCommentsEmptyState(isHeldTab: true),
          ),
        ),
      );

      expect(find.text('No comments held for review'), findsOneWidget);
      expect(find.text('Comments that need review will appear here.'), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_outlined), findsOneWidget);
    });

    testWidgets('DashboardCommentsLoadingSkeleton renders shimmer placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCommentsLoadingSkeleton(),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsWidgets);
    });

    testWidgets('DashboardCommentReplyDrawer populates text with quick suggestions', (tester) async {
      final comment = Comment(
        id: 'c1',
        videoId: 'v1',
        userId: 'u1',
        userName: 'Test User',
        userProfilePicUrl: '',
        channelId: 'ch1',
        text: 'Awesome video!',
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.fromDate(DateTime.now()),
      );

      controller.toggleReplyBox('c1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCommentReplyDrawer(
              comment: comment,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Thanks for watching! 🙏'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);

      // Tap quick suggestion chip
      await tester.tap(find.text('Thanks for watching! 🙏'));
      await tester.pumpAndSettle();

      final replyCtrl = controller.getReplyController('c1');
      expect(replyCtrl.text, equals('Thanks for watching! 🙏'));

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.activeReplyBoxes['c1'], isFalse);
      expect(replyCtrl.text, isEmpty);
    });

    test('replyToCommentAsChannel rejects invalid or empty videoId safely', () async {
      final success = await controller.replyToCommentAsChannel(
        videoId: '',
        commentId: 'nonexistent-comment',
        replyText: 'Replying to nothing',
      );
      expect(success, isFalse);
    });

    test('replyToCommentAsChannel rejects channel_all without falling back to random video', () async {
      final success = await controller.replyToCommentAsChannel(
        videoId: 'channel_all',
        commentId: 'unknown_comment_id',
        replyText: 'Replying safely',
      );
      expect(success, isFalse);
    });

    test('replyToCommentAsChannel rejects comments that do not exist under valid video', () async {
      final success = await controller.replyToCommentAsChannel(
        videoId: 'f37dd18e-209b-4d35-b872-a6e651351382',
        commentId: 'nonexistent-comment-id',
        replyText: 'Replying to missing comment',
      );
      expect(success, isFalse);
    });
  });
}
