import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import '../../test_helpers/mock_firebase.dart';

class MockChannelSubscriptionController extends ChannelSubscriptionController {
  @override
  void listenSubscription(String channelId) {}

  @override
  void listenMembership(String channelId) {}

  @override
  void listenMembershipTiers(String channelId) {}

  @override
  void fetchSubscriberCount(String channelId) {}
}

class TestChannelController extends ChannelController {
  TestChannelController(MockChannelSubscriptionController mockSub) {
    subController = mockSub;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Channel Tab Content Visibility Logic Tests', () {
    late MockChannelSubscriptionController mockSub;
    late TestChannelController testController;

    setUp(() {
      Get.reset();
      Get.put<AuthService>(AuthService());
      mockSub = MockChannelSubscriptionController();
      Get.put<ChannelSubscriptionController>(mockSub);
      testController = TestChannelController(mockSub);
      Get.put<ChannelController>(testController);
    });

    tearDown(Get.reset);

    Channel createTestChannel({
      int videoCount = 0,
      bool hasMemberships = false,
    }) {
      return Channel(
        id: 'test_ch_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truthchannel',
        handleLowercase: '@truthchannel',
        description: 'Test channel description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        subscriberCount: 100,
        videoCount: videoCount,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        hasMemberships: hasMemberships,
      );
    }

    test('All 5 tabs shown when channel has videos, topics, playlists, and posts', () {
      final channel = createTestChannel(videoCount: 5);
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = true;
      testController.hasPlaylists.value = true;
      testController.hasPosts.value = true;

      expect(testController.activeTabs, [
        'Home',
        'Videos',
        'Topics',
        'Playlists',
        'Posts',
      ]);
    });

    test('Only Home and Videos tabs shown when channel has only videos', () {
      final channel = createTestChannel(videoCount: 5);
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      expect(testController.activeTabs, ['Home', 'Videos']);
      expect(testController.activeTabs.contains('Topics'), isFalse);
      expect(testController.activeTabs.contains('Playlists'), isFalse);
      expect(testController.activeTabs.contains('Posts'), isFalse);
    });

    test('Only Topics tab shown when channel has only topics', () {
      final channel = createTestChannel();
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = false;
      testController.videos.clear();
      testController.hasTopics.value = true;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      expect(testController.activeTabs, ['Topics']);
      expect(testController.activeTabs.contains('Home'), isFalse);
      expect(testController.activeTabs.contains('Videos'), isFalse);
      expect(testController.activeTabs.contains('Playlists'), isFalse);
      expect(testController.activeTabs.contains('Posts'), isFalse);
    });

    test('Only Home and Playlists tabs shown when channel has only playlists', () {
      final channel = createTestChannel();
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = false;
      testController.videos.clear();
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = true;
      testController.hasPosts.value = false;

      expect(testController.activeTabs, ['Home', 'Playlists']);
      expect(testController.activeTabs.contains('Videos'), isFalse);
      expect(testController.activeTabs.contains('Topics'), isFalse);
      expect(testController.activeTabs.contains('Posts'), isFalse);
    });

    test('Only Posts tab shown when channel has only posts', () {
      final channel = createTestChannel();
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = false;
      testController.videos.clear();
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = true;

      expect(testController.activeTabs, ['Posts']);
      expect(testController.activeTabs.contains('Home'), isFalse);
      expect(testController.activeTabs.contains('Videos'), isFalse);
      expect(testController.activeTabs.contains('Topics'), isFalse);
      expect(testController.activeTabs.contains('Playlists'), isFalse);
    });

    test('Home, Videos, and Topics shown when channel has videos and topics', () {
      final channel = createTestChannel(videoCount: 3);
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = true;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      expect(testController.activeTabs, ['Home', 'Videos', 'Topics']);
      expect(testController.activeTabs.contains('Playlists'), isFalse);
      expect(testController.activeTabs.contains('Posts'), isFalse);
    });

    test('Fallback to Home tab when channel has zero content across all categories', () {
      final channel = createTestChannel();
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = false;
      testController.videos.clear();
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      expect(testController.activeTabs, ['Home']);
    });

    test('Tabs visibility is independent of channel memberships', () {
      final noMembershipChannel = createTestChannel(
        videoCount: 2,
      );
      testController.selectedChannel.value = noMembershipChannel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = true;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = true;

      final tabsWithoutMemberships = List<String>.from(testController.activeTabs);
      expect(tabsWithoutMemberships, ['Home', 'Videos', 'Topics', 'Posts']);

      final withMembershipChannel = createTestChannel(
        videoCount: 2,
        hasMemberships: true,
      );
      testController.selectedChannel.value = withMembershipChannel;
      final tabsWithMemberships = List<String>.from(testController.activeTabs);

      expect(tabsWithMemberships, tabsWithoutMemberships);
    });

    test('Topic with community posts and 0 videos is recognized as valid topic', () {
      final topic = Topic(
        id: 'topic_1',
        slug: 'climate-change',
        handle: 'T/climate-change',
        handleLowercase: 't/climate-change',
        name: 'Climate Change',
        title: 'Climate Change',
        description: 'Global discussions',
        category: 'Science',
        postCount: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(topic.isValidTopic, isTrue);
    });
  });

  group('Channel TabBar Widget Rendering Tests', () {
    late MockChannelSubscriptionController mockSub;
    late TestChannelController testController;

    setUp(() {
      Get.reset();
      Get.put<AuthService>(AuthService());
      mockSub = MockChannelSubscriptionController();
      Get.put<ChannelSubscriptionController>(mockSub);
      testController = TestChannelController(mockSub);
      Get.put<ChannelController>(testController);
    });

    tearDown(Get.reset);

    testWidgets('TabBar dynamically excludes tabs with no content', (tester) async {
      final channel = Channel(
        id: 'test_ch_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truthchannel',
        handleLowercase: '@truthchannel',
        description: 'Test channel description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        subscriberCount: 100,
        videoCount: 10,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = true;

      final activeTabs = testController.activeTabs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: activeTabs.length,
              child: TabBar(
                isScrollable: true,
                tabs: activeTabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Topics'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
    });

    testWidgets('TabBar includes Topics tab when channel has at least one topic', (tester) async {
      final channel = Channel(
        id: 'test_ch_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truthchannel',
        handleLowercase: '@truthchannel',
        description: 'Test channel description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        subscriberCount: 100,
        videoCount: 10,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = true;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      final activeTabs = testController.activeTabs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: activeTabs.length,
              child: TabBar(
                isScrollable: true,
                tabs: activeTabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);
      expect(find.text('Playlists'), findsNothing);
      expect(find.text('Posts'), findsNothing);
    });

    testWidgets('TabBar dynamically adds Posts tab when hasPosts changes from false to true via Obx', (tester) async {
      final channel = Channel(
        id: 'test_ch_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truthchannel',
        handleLowercase: '@truthchannel',
        description: 'Test channel description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        subscriberCount: 100,
        videoCount: 10,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Obx(() {
              final activeTabs = testController.activeTabs;
              return DefaultTabController(
                key: ValueKey('tab-controller-${channel.channelId}-${activeTabs.join(",")}'),
                length: activeTabs.length,
                child: TabBar(
                  isScrollable: true,
                  tabs: activeTabs.map((t) => Tab(text: t)).toList(),
                ),
              );
            }),
          ),
        ),
      );

      // Initially only Home and Videos are visible
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Posts'), findsNothing);
      expect(find.text('Topics'), findsNothing);

      // Community post becomes available
      testController.hasPosts.value = true;
      await tester.pumpAndSettle();

      // Posts tab dynamically appears
      expect(find.text('Posts'), findsOneWidget);
    });

    testWidgets('TabBar dynamically adds Topics tab when hasTopics changes from false to true via Obx', (tester) async {
      final channel = Channel(
        id: 'test_ch_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truthchannel',
        handleLowercase: '@truthchannel',
        description: 'Test channel description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        subscriberCount: 100,
        videoCount: 10,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      testController.selectedChannel.value = channel;
      testController.hasVideos.value = true;
      testController.hasTopics.value = false;
      testController.hasPlaylists.value = false;
      testController.hasPosts.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Obx(() {
              final activeTabs = testController.activeTabs;
              return DefaultTabController(
                key: ValueKey('tab-controller-${channel.channelId}-${activeTabs.join(",")}'),
                length: activeTabs.length,
                child: TabBar(
                  isScrollable: true,
                  tabs: activeTabs.map((t) => Tab(text: t)).toList(),
                ),
              );
            }),
          ),
        ),
      );

      // Initially only Home and Videos
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Topics'), findsNothing);

      // Topic becomes available
      testController.hasTopics.value = true;
      await tester.pumpAndSettle();

      // Topics tab dynamically appears
      expect(find.text('Topics'), findsOneWidget);
    });
  });
}
