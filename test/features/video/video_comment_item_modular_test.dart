import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_comment_item_widget.dart';

import '../../test_helpers/mock_firebase.dart';

class TestMainController extends MainController {
  final Stream<List<Reply>>? customRepliesStream;
  TestMainController({this.customRepliesStream});

  @override
  // ignore: must_call_super
  void onInit() {
    // Avoid triggering full app state in isolated widget tests
  }

  @override
  Stream<List<Reply>> getRepliesStream(String videoId, String commentId) {
    return customRepliesStream ?? Stream.value([]);
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
  });

  tearDown(Get.reset);

  Widget wrapWithMaterial(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  final sampleComment = Comment(
    id: 'comm_101',
    videoId: 'vid_202',
    userId: 'user_303',
    userName: 'TruthSeeker',
    userProfilePicUrl: 'https://example.com/avatar.jpg',
    channelId: 'chan_404',
    text: 'This video demonstrates clean modular architecture perfectly!',
    likeCount: 42,
    dislikeCount: 2,
    reportCount: 0,
    createdAt: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 5))),
    isHeartedByCreator: true,
    creatorHeartName: 'CreatorAdmin',
  );

  final sampleReply = Reply(
    id: 'rep_501',
    commentId: 'comm_101',
    videoId: 'vid_202',
    userId: 'user_777',
    userName: 'CodeReviewer',
    userProfilePicUrl: 'https://example.com/reviewer.jpg',
    channelId: 'chan_888',
    channelName: 'ReviewerChannel',
    channelProfilePicUrl: 'https://example.com/reviewer_ch.jpg',
    text: 'Completely agree, separation of concerns is top notch.',
    likeCount: 7,
    dislikeCount: 0,
    reportCount: 0,
    createdAt: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 2))),
  );

  group('VideoCommentItemWidget Modular Architecture Tests', () {
    testWidgets('1. CommentAuthorHeader renders handle and relative time',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          CommentAuthorHeader(
            comment: sampleComment,
            channelAvatarUrl: 'https://example.com/channel.jpg',
            videoChannelId: 'different_channel',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@TruthSeeker'), findsOneWidget);
    });

    testWidgets('2. CommentAuthorHeader renders verified badge when author is creator',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          CommentAuthorHeader(
            comment: sampleComment,
            channelAvatarUrl: 'https://example.com/channel.jpg',
            videoChannelId: 'chan_404',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('@TruthSeeker'), findsOneWidget);
    });

    testWidgets('3. CommentCreatorHeartBadge displays avatar and heart icon',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const CommentCreatorHeartBadge(
            channelAvatarUrl: 'https://example.com/creator.jpg',
            creatorHeartName: 'CreatorAdmin',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('4. CommentItemController manages reactive replying state',
        (tester) async {
      final controller = CommentItemController();
      expect(controller.isReplying.value, isFalse);
      expect(controller.isRepliesExpanded.value, isFalse);

      controller.setRepliesExpanded(true);
      expect(controller.isRepliesExpanded.value, isTrue);

      controller.toggleRepliesExpanded();
      expect(controller.isRepliesExpanded.value, isFalse);

      controller.cancelReplying();
      expect(controller.isReplying.value, isFalse);
    });

    testWidgets('5. CommentReplyInputBox updates text and triggers actions',
        (tester) async {
      final controller = Get.put(CommentItemController(), tag: 'test_reply_input');
      var submitted = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentReplyInputBox(
            commentId: 'comm_101',
            controller: controller,
            onSubmit: () {
              submitted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Great point!');
      expect(controller.replyText.value, equals('Great point!'));

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(submitted, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(controller.replyText.value, isEmpty);
    });

    testWidgets('6. ReplyThreadLinePainter paints without error', (tester) async {
      final painter = ReplyThreadLinePainter(
        color: Colors.white24,
        isLast: false,
        branchY: 20,
      );

      expect(painter.shouldRepaint(painter), isFalse);

      final otherPainter = ReplyThreadLinePainter(
        color: Colors.red,
        isLast: true,
        branchY: 30,
      );
      expect(painter.shouldRepaint(otherPainter), isTrue);
    });

    testWidgets('7. CommentItemWidget renders complete comment card and elements',
        (tester) async {
      final mainCtrl = TestMainController();
      final commentsCtrl = CommentsController();
      Get.put(commentsCtrl, tag: 'video_vid_202');

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentItemWidget(
            comment: sampleComment,
            videoId: 'vid_202',
            channelAvatarUrl: 'https://example.com/channel.jpg',
            mainController: mainCtrl,
            textSecondary: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(sampleComment.text), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('8. CommentItemWidget reply button toggles reply input box',
        (tester) async {
      final mainCtrl = TestMainController();
      final commentsCtrl = CommentsController();
      Get.put(commentsCtrl, tag: 'video_vid_202');

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentItemWidget(
            comment: sampleComment,
            videoId: 'vid_202',
            channelAvatarUrl: 'https://example.com/channel.jpg',
            mainController: mainCtrl,
            textSecondary: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommentReplyInputBox), findsNothing);

      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(find.byType(CommentReplyInputBox), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(CommentReplyInputBox), findsNothing);
    });

    testWidgets('9. CommentItemWidget more options opens actions bottom sheet',
        (tester) async {
      final mainCtrl = TestMainController();
      final commentsCtrl = CommentsController();
      Get.put(commentsCtrl, tag: 'video_vid_202');

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentItemWidget(
            comment: sampleComment,
            videoId: 'vid_202',
            channelAvatarUrl: 'https://example.com/channel.jpg',
            mainController: mainCtrl,
            textSecondary: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Save comment'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('10. CommentReplyItem renders reply text, author handle, and actions',
        (tester) async {
      final commentsCtrl = CommentsController();

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentReplyItem(
            reply: sampleReply,
            commentId: 'comm_101',
            isLastReply: true,
            commentsController: commentsCtrl,
            videoChannelId: 'chan_888',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(sampleReply.text), findsOneWidget);
      expect(find.text('@ReviewerChannel'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget); // creator badge
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });
}
