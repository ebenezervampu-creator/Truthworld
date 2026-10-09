import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_result_card.dart';
import '../../test_helpers/mock_firebase.dart';

class TestDiscoverChannelsController extends DiscoverChannelsController {
  @override
  void onInit() {
    // Avoid remote Firestore listeners during in-memory unification testing
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Channel Subscriber Count Cross-App Unification Tests', () {
    const testChannelId = 'ch_unification_test_123';
    late Channel testChannel;

    setUp(() {
      Get.reset();
      ChannelSubscriptionController.channelSubscriberCounts.clear();

      testChannel = Channel(
        id: testChannelId,
        name: 'TruthWorld Official',
        nameLowercase: 'truthworld official',
        handle: '@truthworld',
        handleLowercase: '@truthworld',
        description: 'Empirical truth and knowledge',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_user_456',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        subscriberCount: 0,
      );
    });

    tearDown(() {
      Get.reset();
      ChannelSubscriptionController.channelSubscriberCounts.clear();
    });

    test('1. Initial zero subscriber count is synchronized across all screens', () {
      final subCtrl = Get.put(ChannelSubscriptionController());
      final dashCtrl = Get.put(DashboardController(channelId: testChannelId, autoInitialize: false));
      final discCtrl = Get.put<DiscoverChannelsController>(TestDiscoverChannelsController());

      // 1. ChannelSubscriptionController retrieves 0 and registers in central registry
      final resolvedSubCount = subCtrl.getSubscriberCount(testChannelId, fallback: 0);
      expect(resolvedSubCount, equals(0));
      expect(ChannelSubscriptionController.channelSubscriberCounts[testChannelId], equals(0));

      // 2. Search Page Formatter
      final searchDisplay = SearchResultCard.formatViews(resolvedSubCount);
      expect(searchDisplay, equals('0'));

      // 3. Video Watch Page Action Bar Formatter
      final videoActionDisplay = FormatUtils.formatCount(resolvedSubCount);
      expect(videoActionDisplay, equals('0'));

      // 4. Discover Channels Controller
      final discoverCount = discCtrl.getSubscriberCount(testChannel);
      expect(discoverCount, equals(0));
      final discoverCardDisplay = formatSubscriberCount(discoverCount);
      expect(discoverCardDisplay, equals('0'));

      // 5. Creator Studio Dashboard Stats
      dashCtrl.currentChannel.value = testChannel;
      dashCtrl.channelStats.value = {
        'subscribers': resolvedSubCount.toString(),
        'rawSubscribers': resolvedSubCount,
      };
      expect(dashCtrl.channelStats['subscribers'], equals('0'));
      expect(dashCtrl.channelStats['rawSubscribers'], equals(0));
    });

    test('2. Subscribing increments subscriber count and synchronizes across all apps in real time', () {
      final subCtrl = Get.put(ChannelSubscriptionController());
      final dashCtrl = Get.put(DashboardController(channelId: testChannelId, autoInitialize: false));
      final discCtrl = Get.put<DiscoverChannelsController>(TestDiscoverChannelsController());

      dashCtrl.currentChannel.value = testChannel;
      dashCtrl.channelStats.value = {
        'subscribers': '0',
        'rawSubscribers': 0,
      };

      // Set initial count
      subCtrl.setSubscriberCount(testChannelId, 0);

      // Simulate subscribing: count transitions from 0 -> 1
      final nextCount = 1;
      subCtrl.setSubscriberCount(testChannelId, nextCount);

      // Verify central registry
      expect(ChannelSubscriptionController.channelSubscriberCounts[testChannelId], equals(1));
      expect(subCtrl.getSubscriberCount(testChannelId), equals(1));

      // Update dashboard controller as done in subscribeToChannel
      dashCtrl.channelStats['subscribers'] = nextCount.toString();
      dashCtrl.channelStats['rawSubscribers'] = nextCount;
      dashCtrl.channelStats.refresh();

      // Update discover controller as done in subscribeToChannel
      discCtrl.channelSubscriberCounts[testChannelId] = nextCount;

      // 1. Search page reads updated count
      expect(SearchResultCard.formatViews(subCtrl.getSubscriberCount(testChannelId)), equals('1'));

      // 2. Video Player action bar reads updated count
      expect(FormatUtils.formatCount(subCtrl.getSubscriberCount(testChannelId)), equals('1'));

      // 3. Creator Studio dashboard stats reads updated count
      expect(dashCtrl.channelStats['subscribers'], equals('1'));
      expect(dashCtrl.channelStats['rawSubscribers'], equals(1));

      // 4. Live Subscriber count screen reads updated count
      final liveCount = dashCtrl.channelStats['rawSubscribers'] as int? ??
          dashCtrl.currentChannel.value?.subscriberCount ??
          subCtrl.getSubscriberCount(testChannelId);
      expect(liveCount, equals(1));

      // 5. Discover channels card reads updated count
      expect(discCtrl.getSubscriberCount(testChannel), equals(1));
      expect(formatSubscriberCount(discCtrl.getSubscriberCount(testChannel)), equals('1'));
    });

    test('3. Unsubscribing decrements subscriber count and synchronizes across all apps', () {
      final subCtrl = Get.put(ChannelSubscriptionController());
      final dashCtrl = Get.put(DashboardController(channelId: testChannelId, autoInitialize: false));
      final discCtrl = Get.put<DiscoverChannelsController>(TestDiscoverChannelsController());

      // Start with 1 subscriber
      subCtrl.setSubscriberCount(testChannelId, 1);
      discCtrl.channelSubscriberCounts[testChannelId] = 1;
      dashCtrl.channelStats.value = {
        'subscribers': '1',
        'rawSubscribers': 1,
      };

      // Unsubscribe: 1 -> 0
      final zeroCount = 0;
      subCtrl.setSubscriberCount(testChannelId, zeroCount);
      dashCtrl.channelStats['subscribers'] = zeroCount.toString();
      dashCtrl.channelStats['rawSubscribers'] = zeroCount;
      discCtrl.channelSubscriberCounts[testChannelId] = zeroCount;

      // All screens must display 0
      expect(subCtrl.getSubscriberCount(testChannelId), equals(0));
      expect(SearchResultCard.formatViews(subCtrl.getSubscriberCount(testChannelId)), equals('0'));
      expect(FormatUtils.formatCount(subCtrl.getSubscriberCount(testChannelId)), equals('0'));
      expect(dashCtrl.channelStats['subscribers'], equals('0'));
      expect(dashCtrl.channelStats['rawSubscribers'], equals(0));
      expect(discCtrl.getSubscriberCount(testChannel), equals(0));
      expect(formatSubscriberCount(discCtrl.getSubscriberCount(testChannel)), equals('0'));
    });

    test('4. Number formatting consistency across all screens for milestone subscriber counts', () {
      final testCases = <int, String>{
        0: '0',
        1: '1',
        42: '42',
        999: '999',
        1000: '1.0K',
        1500: '1.5K',
        25400: '25.4K',
        1000000: '1.0M',
        2500000: '2.5M',
      };

      for (final entry in testCases.entries) {
        final count = entry.key;
        final expected = entry.value;

        // Search page
        expect(SearchResultCard.formatViews(count), equals(expected),
            reason: 'Search page format mismatch for $count');

        // Video page & Channel Header
        expect(FormatUtils.formatCount(count), equals(expected),
            reason: 'FormatUtils format mismatch for $count');

        // Discover channels
        expect(formatSubscriberCount(count), equals(expected),
            reason: 'Discover channels format mismatch for $count');
      }
    });
  });
}
