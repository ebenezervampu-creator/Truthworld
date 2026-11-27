import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
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

    testWidgets('DashboardCommentsHeaderBar renders title, subtitle, search action, and switches tabs', (tester) async {
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
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Held for review'), findsOneWidget);

      // Default tab is Published (index 1)
      expect(controller.selectedTab.value, equals(1));

      // Tap Videos tab (index 0)
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      expect(controller.selectedTab.value, equals(0));

      // Tap Held for review (index 2)
      await tester.tap(find.text('Held for review'));
      await tester.pumpAndSettle();
      expect(controller.selectedTab.value, equals(2));

      // Tap Published (index 1)
      await tester.tap(find.text('Published'));
      await tester.pumpAndSettle();
      expect(controller.selectedTab.value, equals(1));

      // Search button toggle expands search field in header
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(controller.isSearchExpanded.value, isTrue);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'testing query');
      await tester.pumpAndSettle();

      expect(controller.searchQuery.value, equals('testing query'));
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
    });

    test('Filter logic correctly segregates Responded vs Unanswered comments', () {
      final commentAnsweredDirectly = Comment(
        id: 'c_answered',
        videoId: 'v1',
        userId: 'u1',
        userName: 'User 1',
        userProfilePicUrl: '',
        channelId: 'ch1',
        text: 'Great video!',
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        hasCreatorReply: true,
        createdAt: Timestamp.now(),
      );

      final commentAnsweredViaLocalCheck = Comment(
        id: 'c_answered_local',
        videoId: 'v1',
        userId: 'u2',
        userName: 'User 2',
        userProfilePicUrl: '',
        channelId: 'ch2',
        text: 'Informative!',
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      final commentUnanswered = Comment(
        id: 'c_unanswered',
        videoId: 'v1',
        userId: 'u3',
        userName: 'User 3',
        userProfilePicUrl: '',
        channelId: 'ch3',
        text: 'Need help with this',
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      controller.allComments.value = [
        commentAnsweredDirectly,
        commentAnsweredViaLocalCheck,
        commentUnanswered,
      ];

      // Mark the second comment as locally answered (simulating creator reply detected in stream)
      controller.markCommentAsLocallyAnswered('c_answered_local', 'v1');

      // Test "Responded" filter
      controller.setCommentFilter('answered');
      final answered = controller.getFilteredComments();
      expect(answered.map((c) => c.id), containsAll(['c_answered', 'c_answered_local']));
      expect(answered.map((c) => c.id), isNot(contains('c_unanswered')));

      // Test "I haven't responded" filter
      controller.setCommentFilter('unanswered');
      final unanswered = controller.getFilteredComments();
      expect(unanswered.map((c) => c.id), contains('c_unanswered'));
      expect(unanswered.map((c) => c.id), isNot(contains('c_answered')));
      expect(unanswered.map((c) => c.id), isNot(contains('c_answered_local')));
    });

    testWidgets('DashboardCommentsVideosListView renders videos and switches to Published comments on tap', (tester) async {
      controller.videosWithComments.value = [
        CreatorVideoWithComments(
          videoId: 'v_zomato',
          title: "Zomato's Big Transformation",
          thumbnail: '',
          duration: '4:20',
          viewCount: 1500,
          commentCount: 3,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCommentsVideosListView(
              controller: controller,
              isMobile: false,
            ),
          ),
        ),
      );

      expect(find.text('All Videos'), findsOneWidget);
      expect(find.text("Zomato's Big Transformation"), findsOneWidget);
      expect(find.text('3 comments'), findsOneWidget);

      // Tapping video selects video and switches tab to Published (index 1)
      await tester.tap(find.text("Zomato's Big Transformation"));
      await tester.pumpAndSettle();

      expect(controller.selectedVideoId.value, equals('v_zomato'));
      expect(controller.selectedTab.value, equals(1));
    });

    testWidgets('DashboardCommentsVideosListView does not overflow on narrow mobile viewport with long metadata', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      controller.videosWithComments.value = [
        CreatorVideoWithComments(
          videoId: 'v_long_1',
          title: 'A very long video title that should ellipsize cleanly without overflowing',
          thumbnail: '',
          duration: '12:34',
          viewCount: 987654321,
          commentCount: 123456,
          createdAt: DateTime.now().subtract(const Duration(days: 35)),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCommentsVideosListView(
              controller: controller,
              isMobile: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
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

    testWidgets('DashboardCommentsLoadingSkeleton renders loading placeholder without shimmer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCommentsLoadingSkeleton(),
          ),
        ),
      );

      expect(find.byType(StudioLoadingIndicator), findsOneWidget);
      expect(find.byType(Shimmer), findsNothing);
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

    test('removeVideo evicts video, resets selection if matching, and purges its comments', () {
      controller.videosWithComments.value = [
        CreatorVideoWithComments(
          videoId: 'v_deleted_1',
          title: "jesus song's",
          thumbnail: '',
          duration: '1:10',
          viewCount: 0,
          commentCount: 2,
          createdAt: DateTime.now(),
        ),
        CreatorVideoWithComments(
          videoId: 'v_active_1',
          title: "Jio IPO 2026",
          thumbnail: '',
          duration: '4:33',
          viewCount: 1,
          commentCount: 1,
          createdAt: DateTime.now(),
        ),
      ];

      controller.selectedVideoId.value = 'v_deleted_1';
      controller.allComments.value = [
        Comment(
          id: 'c_del_1',
          videoId: 'v_deleted_1',
          userId: 'u1',
          userName: 'User 1',
          userProfilePicUrl: '',
          channelId: 'ch1',
          text: 'Comment on deleted video',
          likeCount: 0,
          dislikeCount: 0,
          reportCount: 0,
          createdAt: Timestamp.now(),
        ),
        Comment(
          id: 'c_act_1',
          videoId: 'v_active_1',
          userId: 'u2',
          userName: 'User 2',
          userProfilePicUrl: '',
          channelId: 'ch1',
          text: 'Comment on active video',
          likeCount: 0,
          dislikeCount: 0,
          reportCount: 0,
          createdAt: Timestamp.now(),
        ),
      ];

      // Evict deleted video
      controller.removeVideo('v_deleted_1');

      // Video should be removed from videosWithComments
      expect(controller.videosWithComments.any((v) => v.videoId == 'v_deleted_1'), isFalse);
      expect(controller.videosWithComments.length, equals(1));
      expect(controller.videosWithComments.first.videoId, equals('v_active_1'));

      // Selected video pointer should reset to null (All Videos)
      expect(controller.selectedVideoId.value, isNull);

      // Comments from deleted video should be purged
      expect(controller.allComments.any((c) => c.videoId == 'v_deleted_1'), isFalse);
      expect(controller.allComments.length, equals(1));
      expect(controller.allComments.first.videoId, equals('v_active_1'));
    });
  });
}
