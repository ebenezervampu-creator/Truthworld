import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/data/models/subscriptions.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('SubscriptionController Modular Architecture Tests', () {
    late SubscriptionController controller;

    setUp(() {
      Get.reset();
      Get.put(AuthService());
      controller = Get.put(SubscriptionController());
    });

    tearDown(Get.reset);

    test('1. Architecture & Mixin Composition Verification', () {
      expect(controller, isA<SubscriptionStateBase>());
      expect(controller, isA<SubscriptionActionsMixin>());
      expect(controller, isA<SubscriptionContentIngestionMixin>());
      expect(controller, isA<SubscriptionFiltersMixin>());
    });

    test('2. Initial State Verification', () {
      expect(controller.allContent, isEmpty);
      expect(controller.filteredContent, isEmpty);
      expect(controller.subscriptions, isEmpty);
      expect(controller.subscribedChannels, isEmpty);
      expect(controller.selectedContentFilter.value, equals('all'));
      expect(controller.selectedSortFilter.value, equals('trending'));
      expect(controller.selectedDurationFilter.value, equals('all'));
      expect(controller.selectedDateRangeFilter.value, equals('all'));
      expect(controller.rxIsLoading.value, isFalse);
    });

    test('3. Filter Setters & Mutual Dependency Adjustments', () {
      // Setting duration filter automatically sets content filter to videos
      controller.setDurationFilter('short');
      expect(controller.selectedDurationFilter.value, equals('short'));
      expect(controller.selectedContentFilter.value, equals('videos'));

      // Setting content filter to playlists resets duration filter to all
      controller.setContentFilter('playlists');
      expect(controller.selectedContentFilter.value, equals('playlists'));
      expect(controller.selectedDurationFilter.value, equals('all'));

      // Sort filter updates correctly
      controller.setSortFilter('newest');
      expect(controller.selectedSortFilter.value, equals('newest'));

      // Date range filter updates correctly
      controller.setDateRangeFilter('today');
      expect(controller.selectedDateRangeFilter.value, equals('today'));
    });

    test('4. isSubscribed correctly inspects subscriptions list', () {
      expect(controller.isSubscribed('channel_123'), isFalse);

      controller.subscriptions.add(
        Subscription(
          userId: 'user_test',
          channelId: 'channel_123',
        ),
      );

      expect(controller.isSubscribed('channel_123'), isTrue);
      expect(controller.isSubscribed('channel_456'), isFalse);
    });

    test('5. applyFilters filters by content type and sorts by newest/oldest', () {
      final now = Timestamp.now();
      final earlier = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final videoContent = SubscriptionContent(
        id: 'c_video',
        type: ContentType.video,
        algorithmicScore: 10.0,
        createdAt: now,
        video: Video(
          id: 'v1',
          ownerId: 'u1',
          title: 'Test Video',
          description: 'Test description',
          thumbnailUrl: 'https://test.com/thumb.jpg',
          channelId: 'ch_1',
          channelName: 'Channel One',
          category: 'Education',
          tags: const ['test'],
          duration: '120',
          createdAt: DateTime.now(),
        ),
      );

      final postContent = SubscriptionContent(
        id: 'c_post',
        type: ContentType.communityPost,
        algorithmicScore: 5.0,
        createdAt: earlier,
      );

      controller.allContent.assignAll([postContent, videoContent]);

      // Filter by videos only
      controller.setContentFilter(ContentFilter.videos.name);
      expect(controller.filteredContent.length, equals(1));
      expect(controller.filteredContent.first.id, equals('c_video'));

      // Filter by community posts only
      controller.setContentFilter(ContentFilter.communityPosts.name);
      expect(controller.filteredContent.length, equals(1));
      expect(controller.filteredContent.first.id, equals('c_post'));

      // Reset to all and sort by newest
      controller.setContentFilter(ContentFilter.all.name);
      controller.setSortFilter(SortFilter.newest.name);
      expect(controller.filteredContent.length, equals(2));
      expect(controller.filteredContent.first.id, equals('c_video'));
      expect(controller.filteredContent.last.id, equals('c_post'));

      // Sort by oldest
      controller.setSortFilter(SortFilter.oldest.name);
      expect(controller.filteredContent.first.id, equals('c_post'));
      expect(controller.filteredContent.last.id, equals('c_video'));
    });
  });
}
