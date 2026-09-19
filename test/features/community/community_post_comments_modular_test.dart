import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/community/presentation/views/widgets/community_post_comments.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createWidgetUnderTest(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('CommunityPostComments Modular Presentation & Controller Tests', () {
    test('ReplyThreadLinePainter paints path correctly for last and middle items', () {
      const painterLast = ReplyThreadLinePainter(
        color: Colors.white24,
        isLast: true,
        branchY: 16,
      );
      const painterMiddle = ReplyThreadLinePainter(
        color: Colors.white24,
        isLast: false,
        branchY: 16,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(20, 100);

      expect(() => painterLast.paint(canvas, size), returnsNormally);
      expect(() => painterMiddle.paint(canvas, size), returnsNormally);

      expect(painterLast.shouldRepaint(painterLast), isFalse);
      expect(painterLast.shouldRepaint(painterMiddle), isTrue);
    });

    test('CommunityReplyItemController initializes reactive reaction state correctly', () {
      final controller = CommunityReplyItemController(
        postId: 'post_123',
        commentId: 'comment_456',
        replyData: {
          'id': 'reply_789',
          'text': 'Great insight!',
          'userName': 'Jane Doe',
          'likeCount': 8,
          'dislikeCount': 1,
          'likedBy': ['user_other'],
          'dislikedBy': [],
        },
        postOwnerId: 'creator_01',
      );

      controller.onInit();

      expect(controller.replyId, 'reply_789');
      expect(controller.likeCount.value, 8);
      expect(controller.dislikeCount.value, 1);
      expect(controller.isLiked.value, isFalse);
      expect(controller.isDisliked.value, isFalse);
      expect(controller.isOwner, isFalse);

      controller.onClose();
    });

    test('CommunityCommentItemController initializes state and prepares reply text correctly', () {
      final controller = CommunityCommentItemController(
        postId: 'post_100',
        commentData: {
          'id': 'comment_200',
          'text': 'Fascinating perspective.',
          'userName': 'Sam Creator',
          'likeCount': 12,
          'dislikeCount': 2,
          'likedBy': ['user_active'],
          'dislikedBy': [],
        },
        currentUid: 'user_active',
        postOwnerId: 'channel_admin',
      );

      controller.onInit();

      expect(controller.commentId, 'comment_200');
      expect(controller.likeCount.value, 12);
      expect(controller.dislikeCount.value, 2);
      expect(controller.isLiked.value, isTrue);
      expect(controller.isDisliked.value, isFalse);
      expect(controller.isReplying.value, isFalse);

      controller.prepareReplyToUser('Sam Creator');
      expect(controller.isReplying.value, isTrue);
      expect(controller.replyController.text, '@Sam Creator ');

      controller.onClose();
    });

    testWidgets('CommunityCommentReplyInput renders target, input field and action buttons', (tester) async {
      final textController = TextEditingController();
      var wasCancelled = false;
      var wasSubmitted = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          CommunityCommentReplyInput(
            userName: 'Alex',
            replyController: textController,
            onCancel: () => wasCancelled = true,
            onSubmit: () => wasSubmitted = true,
          ),
        ),
      );

      expect(find.text('Replying to @Alex'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Verify send icon is white
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.send_rounded));
      expect(iconWidget.color, Colors.white);

      await tester.tap(find.text('Cancel'));
      expect(wasCancelled, isTrue);

      await tester.tap(find.byIcon(Icons.send_rounded));
      expect(wasSubmitted, isTrue);
    });

    testWidgets('CommunityReplyItem renders user avatar, body and reacts to tap actions', (tester) async {
      var repliedUser = '';

      await tester.pumpWidget(
        createWidgetUnderTest(
          CommunityReplyItem(
            postId: 'post_1',
            commentId: 'comment_1',
            replyData: const {
              'id': 'reply_1',
              'text': 'This is a threaded reply.',
              'userName': 'Bob',
              'likeCount': 5,
              'dislikeCount': 0,
            },
            onReplyToUser: (target) => repliedUser = target,
            isLastReply: true,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('This is a threaded reply.'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Verify all icons are white or muted white
      final likeIcon = tester.widget<Icon>(find.byIcon(Icons.thumb_up_outlined));
      expect(likeIcon.color, Colors.white70);

      final dislikeIcon = tester.widget<Icon>(find.byIcon(Icons.thumb_down_outlined));
      expect(dislikeIcon.color, Colors.white70);

      final moreIcon = tester.widget<Icon>(find.byIcon(Icons.more_vert));
      expect(moreIcon.color, Colors.white54);

      await tester.tap(find.text('Reply'));
      expect(repliedUser, 'Bob');
    });

    testWidgets('CommunityCommentItemWidget renders comment details and toggles reply box', (tester) async {
      AuthService.to.isAuthenticated.value = true;

      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityCommentItemWidget(
            postId: 'post_main',
            commentData: {
              'id': 'comment_root',
              'text': 'Initial main comment text.',
              'userName': 'Alice',
              'likeCount': 10,
              'dislikeCount': 0,
            },
            currentUid: 'user_123',
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Initial main comment text.'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Reply box is initially hidden
      expect(find.byType(CommunityCommentReplyInput), findsNothing);

      // Tap reply button to reveal input box
      await tester.tap(find.text('Reply'));
      await tester.pump();

      expect(find.byType(CommunityCommentReplyInput), findsOneWidget);
      expect(find.text('Replying to @Alice'), findsOneWidget);

      // Tap cancel to close reply box
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.byType(CommunityCommentReplyInput), findsNothing);
    });

    testWidgets('CommunityCommentOptionsSheet renders comment sheet with white icons', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  CommunityCommentOptionsSheet.showCommentOptions(
                    context: context,
                    text: 'Sample comment text',
                    isOwner: false,
                    onSave: () {},
                    onDelete: () async {},
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Save comment'), findsOneWidget);
      expect(find.text('Copy comment text'), findsOneWidget);
      expect(find.text('Report comment'), findsOneWidget);

      // Verify all sheet icons are white
      final bookmarkIcon = tester.widget<Icon>(find.byIcon(Icons.bookmark_outline_rounded));
      expect(bookmarkIcon.color, Colors.white);

      final copyIcon = tester.widget<Icon>(find.byIcon(Icons.copy_rounded));
      expect(copyIcon.color, Colors.white);

      final flagIcon = tester.widget<Icon>(find.byIcon(Icons.flag_outlined));
      expect(flagIcon.color, Colors.white);
    });

    testWidgets('CommunityCommentOptionsSheet renders owner reply sheet with delete option', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  CommunityCommentOptionsSheet.showReplyOptions(
                    context: context,
                    text: 'Owner reply text',
                    isOwner: true,
                    onSave: () async {},
                    onDelete: () async {},
                  );
                },
                child: const Text('Open Reply Sheet'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Reply Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Save reply'), findsOneWidget);
      expect(find.text('Copy reply text'), findsOneWidget);
      expect(find.text('Delete reply'), findsOneWidget);

      // Verify delete icon is white
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded));
      expect(deleteIcon.color, Colors.white);
    });
  });
}
