import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Community Post Modular Tests', () {
    late CommunityPostModel samplePost;

    setUp(() {
      Get.reset();
      samplePost = CommunityPostModel(
        id: 'post_test_1',
        title: 'Community Announcement',
        description: 'Check out our latest update with exciting features! https://truthworld.in',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'TruthWorld Official',
        channelImage: 'https://example.com/avatar.jpg',
        uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 42,
        dislikes: 3,
        commentCount: 15,
        images: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
      );
    });

    tearDown(Get.reset);

    testWidgets('CommunityPostHeader renders channel name and trigger options', (tester) async {
      var optionsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostHeader(
              post: samplePost,
              onOpenOptions: () => optionsOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('TruthWorld Official'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(optionsOpened, isTrue);
    });

    testWidgets('CommunityPostContent renders description text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostContent(
              description: samplePost.description,
            ),
          ),
        ),
      );

      expect(find.textContaining('Check out our latest update'), findsOneWidget);
    });

    testWidgets('CommunityPostActionBar renders like, dislike, comment, and share buttons', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: samplePost),
        tag: samplePost.id,
      );

      var commentsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostActionBar(
              post: samplePost,
              controller: controller,
              onOpenComments: () => commentsOpened = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.byIcon(Icons.comment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);

      expect(find.text('42'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.comment_outlined));
      await tester.pumpAndSettle();

      expect(commentsOpened, isTrue);
    });

    testWidgets('CommunityPostCard full widget renders declaratively', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: samplePost,
            ),
          ),
        ),
      );

      expect(find.text('TruthWorld Official'), findsOneWidget);
      expect(find.textContaining('Check out our latest update'), findsOneWidget);
      expect(find.byType(CommunityPostHeader), findsOneWidget);
      expect(find.byType(CommunityPostContent), findsOneWidget);
      expect(find.byType(CommunityPostActionBar), findsOneWidget);
    });
  });
}
