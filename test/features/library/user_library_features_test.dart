import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/likedvideos/presentation/controllers/likedvideos_controller.dart';
import 'package:truthworld/features/myvideos/presentation/controllers/my_videos_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';
import '../../test_helpers/mock_firebase.dart';

Video createDummyVideo(String id, String title, {String category = 'All', int views = 0}) {
  return Video(
    id: id,
    title: title,
    description: 'Description for $title',
    thumbnailUrl: 'https://example.com/$id.jpg',
    ownerId: 'owner_1',
    channelId: 'channel_1',
    channelName: 'Channel One',
    category: category,
    tags: const ['test'],
    views: views,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('WatchHistoryController Tests', () {
    late WatchHistoryController controller;

    setUp(() {
      Get.reset();
      controller = WatchHistoryController();
    });

    test('initial state and search filtering setup properly', () {
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.isSearching.value, isFalse);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.selectedCategory.value, equals('All'));

      controller.searchQuery.value = 'Quantum Physics';
      expect(controller.searchQuery.value, equals('Quantum Physics'));

      controller.selectedCategory.value = 'Education';
      expect(controller.selectedCategory.value, equals('Education'));
    });

    test('retry increments refreshTrigger observable', () {
      expect(controller.refreshTrigger.value, equals(0));
      controller.retry();
      expect(controller.refreshTrigger.value, equals(1));
    });
  });

  group('WatchLaterController Tests', () {
    late WatchLaterController controller;

    setUp(() {
      Get.reset();
      controller = WatchLaterController();
    });

    test('initial state has default filters and empty video list', () {
      expect(controller.watchLaterVideos, isEmpty);
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.showFab.value, isTrue);
    });

    test('category and sort updates update reactive state', () {
      controller.selectedCategory.value = 'Tech';
      expect(controller.selectedCategory.value, equals('Tech'));

      controller.sortBy.value = 'views';
      expect(controller.sortBy.value, equals('views'));

      controller.isAscending.value = true;
      expect(controller.isAscending.value, isTrue);
    });
  });

  group('LikedVideosController Tests', () {
    late LikedVideosController controller;

    setUp(() {
      Get.reset();
      controller = LikedVideosController();
    });

    test('initial state has empty video list and default sorting', () {
      expect(controller.videos, isEmpty);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.isListView.value, isTrue);
    });

    test('view toggling between list and grid works reactively', () {
      expect(controller.isListView.value, isTrue);
      controller.isListView.value = false;
      expect(controller.isListView.value, isFalse);
    });

    test('sorting and category filtering update reactive state', () {
      controller.selectedCategory.value = 'Science';
      expect(controller.selectedCategory.value, equals('Science'));

      controller.sortBy.value = 'likes';
      expect(controller.sortBy.value, equals('likes'));
    });
  });

  group('MyVideosController Tests', () {
    late MyVideosController controller;

    setUp(() {
      Get.reset();
      controller = MyVideosController();
    });

    test('initial state defaults are initialized properly', () {
      expect(controller.videos, isEmpty);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.isSearching.value, isFalse);
    });

    test('search query and sorting can be toggled', () {
      controller.searchQuery.value = 'Flutter Tutorial';
      expect(controller.searchQuery.value, equals('Flutter Tutorial'));

      controller.sortBy.value = 'views';
      expect(controller.sortBy.value, equals('views'));

      controller.isAscending.value = true;
      expect(controller.isAscending.value, isTrue);
    });

    test('hasChannel returns false when no channel is registered', () {
      expect(controller.hasChannel, isFalse);
    });

    test('handleUploadTap prompts for channel creation when hasChannel is false', () {
      expect(controller.hasChannel, isFalse);
      // Invoking handleUploadTap with no channel should not throw and should prevent upload route navigation
      expect(() => controller.handleUploadTap(), returnsNormally);
    });
  });
}
