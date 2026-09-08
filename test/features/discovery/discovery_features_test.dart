import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/hashtag/presentation/controllers/hashtag_controller.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('TrendingController Tests', () {
    late TrendingController controller;

    setUp(() {
      Get.reset();
      controller = TrendingController();
    });

    test('initial state has empty video list and default view state', () {
      expect(controller.trendingVideos, isEmpty);
      expect(controller.error.value, isEmpty);
    });

    test('inherits BaseController capabilities and transitions state', () {
      expect(controller.state, equals(ViewState.idle));
      controller.setViewState(ViewState.loading);
      expect(controller.isLoading, isTrue);
      controller.setViewState(ViewState.success);
      expect(controller.isSuccess, isTrue);
    });
  });

  group('DiscoverChannelsController Tests', () {
    late DiscoverChannelsController controller;

    setUp(() {
      Get.reset();
      controller = DiscoverChannelsController();
    });

    test('initial state and default filters are set correctly', () {
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.selectedLanguage.value, equals('All Languages'));
      expect(controller.selectedTopic.value, equals('All Topics'));
      expect(controller.selectedFilter.value, equals('Top Channels'));
      expect(controller.channels, isEmpty);
      expect(controller.rxIsLoading.value, isFalse);

      expect(controller.filters, containsAll([
        'Top Channels',
        'Emerging',
        'Verified Only',
        'Most Active',
      ]));

      expect(controller.languages, containsAll([
        'All Languages',
        'English',
        'Hindi',
        'Tamil',
        'Telugu',
      ]));
    });

    test('filter and category changes update reactive properties', () {
      controller.selectedCategory.value = 'Science';
      expect(controller.selectedCategory.value, equals('Science'));

      controller.selectedLanguage.value = 'English';
      expect(controller.selectedLanguage.value, equals('English'));

      controller.selectedFilter.value = 'Verified Only';
      expect(controller.selectedFilter.value, equals('Verified Only'));
    });

    test('subscription state tracking adds and removes channel IDs', () {
      controller.subscribedChannelIds.add('chan_101');
      expect(controller.subscribedChannelIds.contains('chan_101'), isTrue);

      controller.channelSubscriberCounts['chan_101'] = 1500;
      expect(controller.channelSubscriberCounts['chan_101'], equals(1500));

      controller.subscribedChannelIds.remove('chan_101');
      expect(controller.subscribedChannelIds.contains('chan_101'), isFalse);
    });
  });

  group('CategoryController Tests', () {
    late CategoryController controller;

    setUp(() {
      Get.reset();
      controller = CategoryController();
    });

    test('initial state defaults are initialized properly', () {
      expect(controller.selectedGenre.value, equals('All'));
      expect(controller.selectedSort.value, equals('Popularity'));
      expect(controller.selectedView.value, equals('Grid'));
      expect(controller.isSearchVisible.value, isFalse);
      expect(controller.searchQuery.value, isEmpty);
    });

    test('view and sort selection updates reactive properties', () {
      controller.selectedView.value = 'List';
      expect(controller.selectedView.value, equals('List'));

      controller.selectedSort.value = 'Upload Date';
      expect(controller.selectedSort.value, equals('Upload Date'));

      controller.selectedGenre.value = 'Tutorials';
      expect(controller.selectedGenre.value, equals('Tutorials'));
    });
  });

  group('HashtagController Tests', () {
    late HashtagController controller;

    setUp(() {
      Get.reset();
      controller = HashtagController();
    });

    test('controller initializes and disposes cleanly as BaseController', () {
      expect(controller.state, equals(ViewState.idle));
      controller.onInit();
      expect(controller.state, equals(ViewState.idle));
      controller.onClose();
    });
  });
}
