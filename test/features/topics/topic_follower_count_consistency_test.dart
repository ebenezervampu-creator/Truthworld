import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_featured_banner.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
  });

  tearDown(Get.reset);

  final zeroFollowerTopic = Topic(
    id: 'kerala_topic_id',
    name: 'Kerala',
    title: 'Kerala',
    slug: 'kerala',
    category: 'Travel',
    description: 'Kerala tourism',
    videoCount: 2,
    followerCount: 0,
    thumbnailUrl: 'https://example.com/kerala.jpg',
    coverImage: 'https://example.com/kerala_cover.jpg',
    handle: '#kerala',
    handleLowercase: '#kerala',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('Topic Follower Count Epistemic Consistency Tests', () {
    test('getFollowerCount returns at least 1 when topic is followed even if metadata followerCount is 0', () {
      final ctrl = FollowingTopicsController();
      Get.put(ctrl);

      // Initially not followed -> returns metadata 0
      expect(ctrl.getFollowerCount(zeroFollowerTopic), equals(0));

      // Mark topic as followed
      ctrl.followingStates['kerala_topic_id'] = true;

      // Epistemic consistency check: must be at least 1 when followed
      expect(ctrl.getFollowerCount(zeroFollowerTopic), equals(1));
    });

    test('updateTopicFollowerCount does not wipe follower count to 0 if topic is followed', () {
      final ctrl = FollowingTopicsController();
      Get.put(ctrl);

      ctrl.followingStates['kerala_topic_id'] = true;
      ctrl.updateTopicFollowerCount('kerala_topic_id', 0);

      // Must remain at least 1
      expect(ctrl.getFollowerCount(zeroFollowerTopic), equals(1));
      expect(ctrl.getFollowerCountById('kerala_topic_id'), equals(1));
    });

    test('getFollowerCount matches slug when followed by slug', () {
      final ctrl = FollowingTopicsController();
      Get.put(ctrl);

      ctrl.followingStates['kerala'] = true;

      // Must be at least 1
      expect(ctrl.getFollowerCount(zeroFollowerTopic), equals(1));
    });

    test('Topic.fromMap parses followers and followersCount fallback keys', () {
      final mapWithFollowers = {
        'id': 'topic_1',
        'name': 'Sample',
        'slug': 'sample',
        'followers': 42,
        'videoCount': 5,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final topic1 = Topic.fromMap(mapWithFollowers);
      expect(topic1.followerCount, equals(42));

      final mapWithFollowersCount = {
        'id': 'topic_2',
        'name': 'Sample 2',
        'slug': 'sample-2',
        'followersCount': 100,
        'videoCount': 5,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final topic2 = Topic.fromMap(mapWithFollowersCount);
      expect(topic2.followerCount, equals(100));
    });

    testWidgets('BannerFollowerCountBadge reactively renders 1 Follower when followed even if topic started with 0', (tester) async {
      final ctrl = FollowingTopicsController();
      Get.put(ctrl);

      // Initially not followed
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BannerFollowerCountBadge(
              topic: zeroFollowerTopic,
              formatCount: (c) => c.toString(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially 0 Followers
      expect(find.text('0 Followers'), findsOneWidget);

      // Now follow the topic reactively
      ctrl.followingStates['kerala_topic_id'] = true;
      await tester.pump();

      // Epistemic consistency: must update reactively to '1 Follower'
      expect(find.text('1 Follower'), findsOneWidget);
      expect(find.text('0 Followers'), findsNothing);
    });

    testWidgets('BannerFollowButton reactively updates from Follow to Following', (tester) async {
      final ctrl = FollowingTopicsController();
      Get.put(ctrl);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BannerFollowButton(
              topic: zeroFollowerTopic,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Follow'), findsOneWidget);

      ctrl.followingStates['kerala_topic_id'] = true;
      await tester.pump();

      expect(find.text('Following'), findsOneWidget);
    });
  });
}
