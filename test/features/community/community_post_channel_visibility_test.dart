import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_interaction_cache.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Community Post Channel Visibility & Not Interested Tests', () {
    late CommunityPostModel post;

    setUp(() {
      Get.reset();
      CommunityInteractionCache.reset();

      post = CommunityPostModel(
        id: 'sample_community_post_001',
        title: 'Weekly Community Discussion',
        description: 'Welcome to this week community discussion thread.',
        ownerId: 'oj3JOhUbOvZHjWmzFpXBVDB1vap1',
        channelId: 'SmaXftbr4DpDM60458Ig',
        channelName: 'Ebenezer Vampu',
        channelImage: 'https://example.com/avatar.png',
        uploadedAt: DateTime.now().subtract(const Duration(days: 7)),
        likes: 2,
        likedBy: const ['oj3JOhUbOvZHjWmzFpXBVDB1vap1', 'b7cIcNYXVtRRFtcqYwmqOatvI3I3'],
        images: const ['https://example.com/image.jpg'],
        isCommentsEnabled: false,
      );
    });

    tearDown(Get.reset);

    test('CommunityInteractionCache correctly tracks and untracks hidden posts and muted channels', () {
      expect(CommunityInteractionCache.isPostHidden(post.id), isFalse);
      expect(CommunityInteractionCache.isChannelMuted(post.channelId), isFalse);
      expect(CommunityInteractionCache.isFeedHidden(post.id, post.channelId), isFalse);

      // Mark post as hidden
      CommunityInteractionCache.markHidden(post.id);
      expect(CommunityInteractionCache.isPostHidden(post.id), isTrue);
      expect(CommunityInteractionCache.isFeedHidden(post.id, post.channelId), isTrue);

      // Unmark post as hidden
      CommunityInteractionCache.unmarkHidden(post.id);
      expect(CommunityInteractionCache.isPostHidden(post.id), isFalse);
      expect(CommunityInteractionCache.isFeedHidden(post.id, post.channelId), isFalse);

      // Mark channel as muted
      CommunityInteractionCache.markChannelMuted(post.channelId);
      expect(CommunityInteractionCache.isChannelMuted(post.channelId), isTrue);
      expect(CommunityInteractionCache.isFeedHidden(post.id, post.channelId), isTrue);

      // Unmark channel as muted
      CommunityInteractionCache.unmarkChannelMuted(post.channelId);
      expect(CommunityInteractionCache.isChannelMuted(post.channelId), isFalse);
      expect(CommunityInteractionCache.isFeedHidden(post.id, post.channelId), isFalse);
    });

    testWidgets('CommunityPostCard is hidden in feed context when isHidden is true', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: post),
        tag: post.id,
      );
      controller.isHidden.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: post,
            ),
          ),
        ),
      );

      // In feed context with isHidden true, it should collapse to SizedBox.shrink
      expect(find.text('hi every one'), findsNothing);
      expect(find.text('Ebenezer Vampu'), findsNothing);
    });

    testWidgets('CommunityPostCard remains VISIBLE on Channel Details Page even if marked not interested in feed', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: post),
        tag: post.id,
      );
      // Simulate user having marked it "not interested" while watching content
      controller.isHidden.value = true;
      controller.isPostHiddenInFeed.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: post,
              isChannelContext: true, // As passed by ChannelPostsTabView
            ),
          ),
        ),
      );

      // On channel details page, post must remain visible!
      expect(find.text('Ebenezer Vampu'), findsOneWidget);
      expect(find.text('Welcome to this week community discussion thread.'), findsOneWidget);
    });

    testWidgets('CommunityPostCard remains VISIBLE for the creator/owner everywhere', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: post),
        tag: post.id,
      );
      controller.isHidden.value = true;

      // When rendered, if the currentUid matches ownerId or channelId, it is not hidden
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: post,
              isChannelContext: true,
            ),
          ),
        ),
      );

      expect(find.text('Ebenezer Vampu'), findsOneWidget);
      expect(find.text('Welcome to this week community discussion thread.'), findsOneWidget);
    });

    testWidgets('Options menu in feed shows "Not interested" and "Don\'t recommend posts from this channel"', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: post),
        tag: post.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCommunityPostOptionsMenu(
                  context,
                  post,
                  controller,
                ),
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Not interested'), findsOneWidget);
      expect(find.text("Don't recommend posts from this channel"), findsOneWidget);
      expect(find.text('Save post'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('Options menu on Channel Details Page shows "Restore post recommendation" when hidden, not "Not interested"', (tester) async {
      final controller = Get.put(
        CommunityPostController(post: post),
        tag: post.id,
      );
      controller.isPostHiddenInFeed.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCommunityPostOptionsMenu(
                  context,
                  post,
                  controller,
                  isChannelContext: true,
                ),
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // "Not interested" must NOT appear on channel details page!
      expect(find.text('Not interested'), findsNothing);
      expect(find.text("Don't recommend posts from this channel"), findsNothing);

      // "Restore post recommendation" should appear since it was hidden in feed
      expect(find.text('Restore post recommendation'), findsOneWidget);
    });
  });
}
