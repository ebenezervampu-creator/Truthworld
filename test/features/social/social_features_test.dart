import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_community_posts_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('SubscriptionController Filter and State Tests', () {
    late SubscriptionController controller;

    setUp(() {
      Get.reset();
      controller = SubscriptionController();
    });

    test('initial filter states match defaults', () {
      expect(controller.selectedContentFilter.value, equals(ContentFilter.all.name));
      expect(controller.selectedSortFilter.value, equals(SortFilter.trending.name));
      expect(controller.selectedDurationFilter.value, equals(DurationFilter.all.name));
      expect(controller.selectedDateRangeFilter.value, equals(DateRangeFilter.all.name));
      expect(controller.allContent, isEmpty);
      expect(controller.filteredContent, isEmpty);
      expect(controller.subscribedChannels, isEmpty);
    });

    test('filter enums provide expected options', () {
      expect(ContentFilter.values, containsAll([
        ContentFilter.all,
        ContentFilter.videos,
        ContentFilter.playlists,
        ContentFilter.communityPosts,
        ContentFilter.topics,
      ]));

      expect(SortFilter.values, containsAll([
        SortFilter.trending,
        SortFilter.popular,
        SortFilter.newest,
        SortFilter.oldest,
      ]));
    });

    test('setting filters updates reactive properties', () {
      controller.selectedContentFilter.value = ContentFilter.videos.name;
      expect(controller.selectedContentFilter.value, equals(ContentFilter.videos.name));

      controller.selectedSortFilter.value = SortFilter.popular.name;
      expect(controller.selectedSortFilter.value, equals(SortFilter.popular.name));

      controller.selectedDurationFilter.value = DurationFilter.short.name;
      expect(controller.selectedDurationFilter.value, equals(DurationFilter.short.name));
    });
  });

  group('SavedCommunityPostsController Tests', () {
    late SavedCommunityPostsController controller;

    setUp(() {
      Get.reset();
      controller = SavedCommunityPostsController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('initial state and search properties work correctly', () {
      expect(controller.posts, isEmpty);
      expect(controller.isSearching.value, isFalse);
      expect(controller.searchQuery.value, isEmpty);

      controller.searchQuery.value = 'Quantum';
      expect(controller.searchQuery.value, equals('Quantum'));
    });

    test('filteredPosts filters loaded posts by search query', () {
      final post1 = CommunityPostModel(
        id: 'p1',
        title: 'Quantum Mechanics breakthroughs',
        description: 'New research discovered',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Science Daily',
        channelImage: '',
        uploadedAt: DateTime(2026),
      );

      final post2 = CommunityPostModel(
        id: 'p2',
        title: 'Cooking pasta properly',
        description: 'Chef tips',
        ownerId: 'u2',
        channelId: 'c2',
        channelName: 'Kitchen 101',
        channelImage: '',
        uploadedAt: DateTime(2026),
      );

      controller.posts.assignAll([post1, post2]);
      expect(controller.filteredPosts.length, equals(2));

      controller.searchQuery.value = 'quantum';
      expect(controller.filteredPosts.length, equals(1));
      expect(controller.filteredPosts.first.id, equals('p1'));

      controller.searchQuery.value = '';
      expect(controller.filteredPosts.length, equals(2));
    });

    test('handles unauthenticated state gracefully', () {
      // In unit test without auth user, rxErrorMessage is set
      controller.listenToSavedPosts();
      expect(controller.rxErrorMessage.value, equals('User not authenticated'));
      expect(controller.rxIsLoading.value, isFalse);
    });
  });
}
